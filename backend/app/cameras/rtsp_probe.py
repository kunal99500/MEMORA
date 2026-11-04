"""Optional RTSP connectivity probe.

The caller must resolve a camera URL from a secret manager and pass it in memory.
Never persist/log the URL because it may contain credentials.
Requires opencv-python-headless (already in base requirements).
"""
from __future__ import annotations
import cv2

def read_probe_frame(stream_url: str, timeout_ms: int = 5000):
    if not stream_url.startswith(("rtsp://", "rtsps://")):
        raise ValueError("Only RTSP/RTSPS URLs are supported by this adapter")
    cap = cv2.VideoCapture(stream_url, cv2.CAP_FFMPEG)
    try:
        cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, timeout_ms)
        cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, timeout_ms)
        ok, frame = cap.read()
        if not ok or frame is None:
            return {"connected": False, "reason": "No frame received"}
        height, width = frame.shape[:2]
        return {"connected": True, "width": int(width), "height": int(height)}
    finally:
        cap.release()
