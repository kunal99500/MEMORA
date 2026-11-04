from __future__ import annotations
import hashlib
import json
import logging
import threading
import time
import uuid
from datetime import datetime, timezone
import cv2
from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models.entities import Camera, Workspace, Capture, MediaAsset, Event
from app.services.processing import process_capture

log = logging.getLogger(__name__)

class CameraManager:
    """Single-process development RTSP sampler. URLs are resolved from .env by reference."""
    def __init__(self):
        self.threads = {}
        self.stops = {}
        self.states = {}
        self.lock = threading.Lock()

    def _resolve_url(self, connection_ref):
        try:
            mapping = json.loads(get_settings().camera_streams_json or "{}")
        except json.JSONDecodeError as exc:
            raise ValueError("MEMORA_CAMERA_STREAMS_JSON must be valid JSON") from exc
        url = mapping.get(connection_ref)
        if not url:
            raise ValueError(
                f"No stream configured for '{connection_ref}'. Add it to MEMORA_CAMERA_STREAMS_JSON in .env."
            )
        if not str(url).startswith(("rtsp://", "rtsps://")):
            raise ValueError("Only RTSP/RTSPS stream URLs are supported")
        return str(url)

    def start(self, camera_id):
        db = SessionLocal()
        try:
            cam = db.get(Camera, camera_id)
            if not cam:
                raise ValueError("Camera not found")
            url = self._resolve_url(cam.connection_ref)
        finally:
            db.close()
        with self.lock:
            existing = self.threads.get(camera_id)
            if existing and existing.is_alive():
                return
            stop_event = threading.Event()
            self.stops[camera_id] = stop_event
            self.states[camera_id] = {"worker_state": "starting", "frames_saved": 0}
            thread = threading.Thread(
                target=self._run, args=(camera_id, url, stop_event),
                daemon=True, name=f"memora-camera-{camera_id}"
            )
            self.threads[camera_id] = thread
            thread.start()

    def stop(self, camera_id):
        event = self.stops.get(camera_id)
        if event:
            event.set()
        self.states.setdefault(camera_id, {})["worker_state"] = "stopping"

    def status(self, camera_id):
        with self.lock:
            return dict(self.states.get(camera_id, {"worker_state": "not_running"}))

    def _set(self, camera_id, **kwargs):
        with self.lock:
            self.states.setdefault(camera_id, {}).update(kwargs)

    def _run(self, camera_id, url, stop_event):
        interval = max(15, int(get_settings().camera_sample_interval_seconds))
        while not stop_event.is_set():
            cap = None
            try:
                self._set(camera_id, worker_state="connecting", last_error=None)
                cap = cv2.VideoCapture(url, cv2.CAP_FFMPEG)
                cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, 8000)
                cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, 8000)
                if not cap.isOpened():
                    raise RuntimeError("Cannot open stream. Check RTSP URL, Wi-Fi and firewall.")
                self._set(camera_id, worker_state="online")
                while not stop_event.is_set():
                    ok, frame = cap.read()
                    if not ok or frame is None:
                        raise RuntimeError("Stream stopped returning frames")
                    self._save_frame(camera_id, frame)
                    current = self.status(camera_id)
                    self._set(camera_id, worker_state="online",
                              last_frame_at=datetime.now(timezone.utc).isoformat(),
                              frames_saved=current.get("frames_saved", 0) + 1,
                              last_error=None)
                    stop_event.wait(interval)
            except Exception as exc:
                log.exception("Camera worker error: %s", camera_id)
                self._set(camera_id, worker_state="error", last_error=str(exc))
                stop_event.wait(5)
            finally:
                if cap is not None:
                    cap.release()
        self._set(camera_id, worker_state="stopped")

    def _save_frame(self, camera_id, frame):
        settings = get_settings()
        db = SessionLocal()
        try:
            cam = db.get(Camera, camera_id)
            if not cam or not cam.enabled:
                return
            workspace = db.get(Workspace, cam.workspace_id)
            if not workspace:
                return
            ok, encoded = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 88])
            if not ok:
                raise RuntimeError("Could not encode sampled camera frame")
            payload = encoded.tobytes()
            digest = hashlib.sha256(payload).hexdigest()
            capture_id = "cap_" + uuid.uuid4().hex
            media_id = "med_" + uuid.uuid4().hex
            folder = settings.media_path / cam.workspace_id / capture_id
            folder.mkdir(parents=True, exist_ok=True)
            image_path = folder / f"{media_id}.jpg"
            image_path.write_bytes(payload)
            capture = Capture(
                id=capture_id, workspace_id=cam.workspace_id, location_id=cam.location_id,
                created_by=workspace.owner_id, label=f"Camera: {cam.name}",
                domain=workspace.domain, media_type="photo", status="queued"
            )
            db.add(capture)
            db.flush()
            db.add(MediaAsset(
                id=media_id, capture_id=capture_id, original_name=f"{cam.name}.jpg",
                stored_path=str(image_path), mime_type="image/jpeg", media_kind="photo",
                size_bytes=len(payload), sha256=digest
            ))
            db.add(Event(
                workspace_id=cam.workspace_id, capture_id=capture_id,
                event_type="camera_frame_ingested",
                details={"camera_id": cam.id, "camera_name": cam.name,
                         "captured_at": datetime.now(timezone.utc).isoformat()},
                source="camera"
            ))
            db.commit()
            process_capture(db, capture_id, settings.media_path)
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

camera_manager = CameraManager()
