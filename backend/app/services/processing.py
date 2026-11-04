from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from app.models.entities import (
    Capture,
    Evidence,
    Frame,
    MediaAsset,
    ObjectIdentity,
    Observation,
    SceneNote,
)
from app.vision.muse import analyze_image
from app.vision.providers import barcode_read, ocr_read
from app.vision.quality import assess_image
from app.vision.video import extract_frames


def process_capture(db: Session, capture_id: str, media_root: Path) -> dict:
    cap = db.get(Capture, capture_id)
    if not cap:
        raise ValueError('Capture not found')
    capture_context = {
        'id': cap.id,
        'workspace_id': cap.workspace_id,
        'location_id': cap.location_id,
        'domain': cap.domain,
        'label': cap.label,
    }
    cap.status = 'processing'
    db.commit()
    report = {
        'media_processed': 0,
        'frames_processed': 0,
        'observations_created': 0,
        'warnings': [],
        'quality': [],
        'ocr': [],
        'barcodes': [],
    }
    try:
        media_rows = db.query(MediaAsset).filter_by(capture_id=capture_id).all()
        media_data = [
            (media.id, media.original_name, media.stored_path)
            for media in media_rows
        ]
        db.commit()

        for media_id, original_name, stored_path in media_data:
            report['media_processed'] += 1
            frames = extract_frames(
                stored_path,
                str(media_root / 'derived' / capture_id / media_id),
            )
            if not frames:
                report['warnings'].append(f'No readable frames: {original_name}')
                continue

            for fr in frames:
                quality = assess_image(fr['path'])
                report['frames_processed'] += 1
                report['quality'].append(
                    {'frame_index': fr['index'], **quality}
                )

                vision_result = None
                try:
                    vision_result = analyze_image(
                        fr['path'],
                        {
                            'domain': capture_context['domain'],
                            'label': capture_context['label'],
                        },
                    )
                except Exception as exc:
                    report['warnings'].append(
                        f'Vision unavailable/failed for frame '
                        f'{fr["index"]}: {type(exc).__name__}: {exc}'
                    )

                try:
                    report['ocr'].extend(ocr_read(fr['path']))
                    report['barcodes'].extend(barcode_read(fr['path']))
                except Exception as exc:
                    report['warnings'].append(
                        f'Identifier extraction failed: {exc}'
                    )

                frame = Frame(
                    capture_id=capture_context['id'],
                    media_id=media_id,
                    stored_path=fr['path'],
                    timestamp_ms=fr['timestamp_ms'],
                    frame_index=fr['index'],
                    width=fr['width'],
                    height=fr['height'],
                    sharpness=fr['sharpness'],
                )
                db.add(frame)
                db.flush()
                original_evidence = Evidence(
                    capture_id=capture_context['id'],
                    frame_id=frame.id,
                    media_id=media_id,
                    timestamp_ms=frame.timestamp_ms,
                    source_type='original_frame',
                )
                db.add(original_evidence)
                db.flush()

                for item in (vision_result or {}).get('objects', []):
                    label = str(item.get('label') or '').strip()
                    if not label:
                        continue
                    obj = ObjectIdentity(
                        workspace_id=capture_context['workspace_id'],
                        canonical_label=label,
                        category=str(item.get('category') or 'other'),
                        domain=capture_context['domain'],
                        identity_status='unresolved',
                    )
                    db.add(obj)
                    db.flush()
                    object_evidence = Evidence(
                        capture_id=capture_context['id'],
                        frame_id=frame.id,
                        media_id=media_id,
                        bbox=item.get('bbox'),
                        timestamp_ms=frame.timestamp_ms,
                        source_type='model_bbox',
                    )
                    db.add(object_evidence)
                    db.flush()
                    db.add(
                        Observation(
                            capture_id=capture_context['id'],
                            object_id=obj.id,
                            evidence_id=object_evidence.id,
                            location_id=capture_context['location_id'],
                            label=label,
                            location_text=str(item.get('location') or ''),
                            condition_text=str(item.get('condition') or ''),
                            attributes=item.get('attributes') or {},
                            confidence={'detection': item.get('confidence')},
                            verification_status='unverified',
                        )
                    )
                    report['observations_created'] += 1

                description = str(
                    (vision_result or {}).get('scene') or ''
                ).strip()
                if description:
                    db.add(
                        SceneNote(
                            capture_id=capture_context['id'],
                            workspace_id=capture_context['workspace_id'],
                            frame_id=frame.id,
                            evidence_id=original_evidence.id,
                            text=description,
                        )
                    )

                db.commit()

        if not report['frames_processed']:
            raise RuntimeError('No frames could be extracted from uploaded media')
        if not report['observations_created']:
            report['warnings'].append(
                'No object observations created. Configure META_API_KEY or a vision provider.'
            )
        cap.status = (
            'completed_with_warnings' if report['warnings'] else 'completed'
        )
        cap.report = report
        cap.completed_at = datetime.now(timezone.utc)
        db.commit()
        return report
    except Exception:
        db.rollback()
        cap = db.get(Capture, capture_id)
        if cap:
            cap.status = 'failed'
            cap.report = {'error': 'Processing failed; inspect worker logs'}
            db.commit()
        raise
