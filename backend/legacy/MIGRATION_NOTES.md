# Existing backend migration notes

Original supplied source files are preserved in `original_backend/`.

Known issues from review:
- Original scan endpoint did not pass `analyze_n`, so ingestion defaulted to one analyzed frame.
- Original ingestion deduplicated by exact label per scan, dropping repeated physical instances.
- Original SAM helper selected only the largest mask.
- Original Q&A used text-only context, without original image evidence.
- Original frame-serving endpoint lacked visible workspace authorization.
- Original auth secret had an insecure development fallback.
- Original scan response omitted detailed processing diagnostics.

The new application does not silently import the legacy implementation. Port useful features incrementally with tests. Existing SAM 3.1 source is preserved but requires provider-specific integration tests before activation.
