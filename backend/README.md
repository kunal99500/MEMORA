# MEMORA FastAPI backend

The backend provides the authenticated API and data services used by the
MEMORA Flutter app. It manages users, workspaces, spaces, captures, media,
evidence, observations, timelines, and questions over saved visual memory.

The service is a local development foundation. External model APIs and
optional integrations require their own credentials and configuration.

## Requirements

- Python 3.11 or newer
- Windows PowerShell, macOS Terminal, or a Linux shell
- Optional: a Muse-compatible API key for image analysis and question
  answering
- Optional: SMTP service credentials for password recovery emails

## Install and run

From the project directory, create and activate a virtual environment:

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

In `backend/.env`, set `MEMORA_SECRET` to a private random value of at least 32
characters. Then start the API:

```powershell
uvicorn app.main:app --reload
```

The service listens on `http://127.0.0.1:8000`. Interactive OpenAPI
documentation is available at `http://127.0.0.1:8000/docs`; the health
endpoint is `http://127.0.0.1:8000/health`.

The application loads its `.env` relative to the backend source directory, so
the server can be started from another current working directory.

## Configuration

Settings are defined in `app/core/config.py` and loaded from `.env` or the
process environment.

| Variable | Purpose |
| --- | --- |
| `APP_ENV` | Environment mode; use `production` for deployed services |
| `MEMORA_SECRET` | Required authentication-token signing secret, at least 32 characters |
| `DATABASE_URL` | SQLAlchemy database URL; defaults to `sqlite:///./data/memora.db` |
| `MEDIA_ROOT` | Root directory for original uploads and derived media |
| `MAX_UPLOAD_MB` | Maximum accepted size for an individual media file |
| `ALLOWED_ORIGINS` | Comma-separated browser origins permitted by CORS |
| `META_API_KEY` | Enables the configured Muse-compatible model provider |
| `META_API_BASE` | Provider API base URL |
| `MUSE_SPARK_MODEL` | Model name sent to the provider; defaults to `muse-spark-1.3` |
| `SMTP_HOST`, `SMTP_PORT` | SMTP server and port for password-recovery email |
| `SMTP_USERNAME`, `SMTP_PASSWORD` | Optional SMTP authentication |
| `SMTP_FROM_EMAIL` | Sender address for password-recovery messages |
| `SMTP_STARTTLS` | Enable STARTTLS for SMTP |
| `YOLO_ENABLED`, `YOLO_MODEL_PATH` | Optional YOLO provider settings |
| `OCR_ENABLED` | Optional OCR provider toggle |
| `BARCODE_ENABLED` | Optional barcode reader toggle |
| `CAMERA_INGESTION_ENABLED` | Reserved setting; it does not currently gate the camera start endpoint |
| `CAMERA_SAMPLE_INTERVAL_SECONDS` | Camera sampling interval setting |
| `MEMORA_CAMERA_STREAMS_JSON` | Server-side map of camera connection references to stream URLs for local development |

Never commit `.env` or place model, mail, or camera credentials in the
Flutter app. For a physical phone, configure the backend host and firewall so
the phone can reach the API over the local network.

### Password recovery

Password reset requests send an eight-digit one-time code that expires after
10 minutes. Configure `SMTP_HOST` and `SMTP_FROM_EMAIL`; if the mail server
requires authentication, also configure `SMTP_USERNAME` and `SMTP_PASSWORD`.
`SMTP_PORT` and `SMTP_STARTTLS` control the connection. Reset requests return
the same response whether or not an account exists.

## Data and media processing

### Local storage

SQLite is the default database, and uploads are stored under `MEDIA_ROOT`.
For SQLite, the backend enables WAL mode and a busy timeout to better handle
concurrent local requests. For deployed systems, configure a production
database such as PostgreSQL.

### Upkeep documents

Upkeep accepts PDF and DOCX documents with a required description. The backend
stores the original file under `MEDIA_ROOT/<workspace-id>/documents`; questions
extract text locally and return matching passages without calling the AI
provider. Scanned/image-only PDFs may not be searchable, and legacy DOC files
must be converted to DOCX.

On Render or another ephemeral-filesystem host, configure a persistent disk
mounted at the path used by `MEDIA_ROOT`; otherwise uploaded documents and
other local media can be lost when the service restarts or redeploys.

### Capture lifecycle

1. Create a capture and associate it with a workspace and optionally a space
   or timeline.
2. Upload a supported image or video file to the capture.
3. Request processing; FastAPI schedules a background task.
4. Processing extracts image frames, stores frame/evidence records, and, when
   configured, requests scene and object analysis.
5. Query the capture status and retrieve saved evidence or observations.

Each frame uses a Muse-compatible vision request for structured object
observations and a scene description. Video processing samples frames; it does
not analyze every frame. Uploaded photos can be listed before analysis
finishes, using the original uploaded media as the preview. Analyzed evidence
becomes available as processing completes.

When the provider is not configured or a model request fails, media can still
be stored, but object observations or useful AI answers may not be available.
MEMORA should not infer facts that are absent from saved memory.

## API overview

All application endpoints use the `/api/v1` prefix. See `/docs` for request
schemas and response details.

| Area | Routes |
| --- | --- |
| Authentication | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` |
| Password recovery | `POST /auth/password-reset/request`, `POST /auth/password-reset/confirm` |
| Workspaces | `GET /workspaces`, `POST /workspaces`, `GET /workspaces/{id}/overview` |
| Spaces | `GET /workspaces/{id}/locations`, `POST /workspaces/{id}/locations`, `GET /workspaces/{id}/rooms-summary` |
| Capture/media | `POST /captures`, `POST /captures/{id}/media`, `POST /captures/{id}/process`, `GET /captures/{id}` |
| Saved scans | `GET /workspaces/{id}/scan-images`, `DELETE /captures/{id}` |
| Evidence | `GET /evidence/{id}`, `GET /evidence/{id}/file`, `GET /evidence/{id}/preview` |
| Questions | `POST /ask` |
| Upkeep documents | `GET /documents`, `POST /documents`, `POST /documents/{id}/ask`, `GET /documents/{id}/file`, `DELETE /documents/{id}` |
| AI privacy consent | `GET /privacy/ai-consent`, `POST /privacy/ai-consent`, `DELETE /privacy/ai-consent` |
| Chat history | `GET /workspaces/{id}/chat-history`, `GET /workspaces/{id}/chat-conversations`, `DELETE /workspaces/{id}/chat-history` |
| Timelines | `POST /workspaces/{id}/timelines`, `GET /workspaces/{id}/timelines`, `GET /workspaces/{id}/timeline` |
| Camera registry | `/cameras` routes for authenticated camera metadata and controls |

## Model and optional provider status

The active visual-analysis and reasoning integration is the configured
Muse-compatible API, enabled with `META_API_KEY`. Its default model name is
`muse-spark-1.3`. The configured provider must support the OpenAI-compatible
chat-completions interface used by the backend.

SAM 3.1 is **not wired into the active capture-processing path**. A legacy
client/adapter seam exists, but current scans do not depend on it and do not
save or display segmentation masks. Do not treat segmentation as an available
feature until its provider integration and user-facing behavior are completed.

YOLO, OCR, and barcode functions are optional and depend on configuration and
their required packages/models. A setting alone does not supply a missing
model or provider credential.

## Connected cameras

The API and Flutter interface support registering and managing camera
metadata. The backend also has an explicitly started, single-process RTSP
sampler in `app/cameras/manager.py`. To connect a camera, save a server-side
`connection_ref`, map that reference to an `rtsp://` or `rtsps://` URL in
`MEMORA_CAMERA_STREAMS_JSON`, ensure the backend host can reach the camera,
and start the camera from the Cameras screen. The worker samples frames at
`CAMERA_SAMPLE_INTERVAL_SECONDS` (with a 15-second minimum), saves them as
captures, and sends them through the normal processing pipeline.

The sampler runs only in the current backend process; it is not a durable,
supervised production service and it stops when that process stops. The
`CAMERA_INGESTION_ENABLED` setting is currently not checked by the start
endpoint. ONVIF discovery, vendor cloud integrations, multi-process worker
coordination, motion-triggered sampling, and production retention enforcement
are not provided. Never send raw stream credentials to the Flutter client.

## Production considerations

Before deploying, use HTTPS, PostgreSQL, durable object storage, backups,
managed secrets, and a supervised background processing queue. The current
media worker uses FastAPI background tasks and local storage, which are
intended for development and small deployments rather than a distributed
production workload.

Review model and dependency licenses before commercial distribution. In
particular, review the applicable Ultralytics licensing terms before enabling
YOLO in a commercial product.

## Related documentation

- [Project overview and demo script](../README.md)
- [Flutter client guide](../frontend/README.md)
- [Camera integration boundary](app/cameras/README.md)
