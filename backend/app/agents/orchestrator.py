"""Deterministic orchestration entrypoint. LangGraph can wrap these nodes after provider contracts are stable."""
from app.services.processing import process_capture

def run_capture(db,capture_id,media_root):
    return process_capture(db,capture_id,media_root)
