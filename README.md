# MEMORA

**Capture. Remember. Find.**

MEMORA is a visual-memory app for real-world spaces. Add a photo or video to a
room, garden, garage, or another space, then ask questions about what was
recorded and where it was seen.

The project has two parts:

| Folder | Responsibility |
| --- | --- |
| [`frontend/`](./frontend/README.md) | Flutter app for Android, iOS, and web |
| [`backend/`](./backend/README.md) | FastAPI service, authentication, workspace data, media storage, and processing |

## What users can do

- Create an account, sign in, remember a session, and recover a forgotten
  password by email.
- Organize information in personal, family, or business workspaces and named
  spaces such as rooms, gardens, garages, zones, or shelves.
- Upload one or more images or videos to a space, capture an image, or record a
  video using a supported device camera.
- Review saved scans, remove them, and ask questions about captured objects
  and their locations.
- Use Ask MEMORA with typed questions or supported speech input and spoken
  replies.
- Create separate space timelines and add or remove timeline media there.
- Register and manage camera metadata.

Answers are grounded in the workspace information MEMORA has saved. They
cannot reliably describe a space or item that has not been captured and
processed.

## How a space scan works

1. The user opens **Scan a space**, selects a space, then uploads an image or
   video or captures one using the in-app camera.
2. The Flutter app sends the media to the FastAPI capture endpoints.
3. The backend stores the upload and starts background processing.
4. When configured, the Muse-compatible vision model analyzes image frames
   and returns scene descriptions and structured object observations.
5. MEMORA stores the capture, observations, and evidence in the workspace.
6. Ask MEMORA uses saved scene and object information to answer questions and
   can return related image evidence.

Processing is asynchronous: a newly uploaded image can appear before its
analysis is complete. A processing warning or missing AI provider may mean
that a scan is stored without object observations.

## Technology

- **Flutter / Dart** — cross-platform application interface and media flows.
- **Python / FastAPI** — authenticated API, uploads, processing, and question
  answering.
- **SQLAlchemy** — database access and persistence.
- **SQLite** — default local database; PostgreSQL can be configured.
- **Muse-compatible model API** — optional scene and object analysis and
  memory-based question answering.
- **OpenCV** — image/video frame extraction and image processing utilities.

### Model and integration status

The configured Muse-compatible API is the active model integration for visual
analysis and question answering when credentials are provided. The default
model setting is `muse-spark-1.3`.

SAM 3.1 is **not part of the active capture-processing path**. The project
contains a preserved legacy client/adapter seam, but segmentation is not
currently required to process a scan, and the app does not claim to save or
display segmentation masks. Do not describe SAM masks as a live feature unless
that integration is separately completed and verified.

OCR, barcode reading, YOLO, and other optional providers depend on their
configuration and installed dependencies; do not assume they are enabled in a
given deployment.

## Run locally

### 1. Start the backend

In Windows PowerShell, from the project directory:

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Set `MEMORA_SECRET` in `backend/.env` to a private random value of at least 32
characters. Start the service:

```powershell
uvicorn app.main:app --reload
```

The API is available at `http://127.0.0.1:8000`; interactive API documentation
is at `http://127.0.0.1:8000/docs`.

### 2. Start the Flutter app

Open another PowerShell window:

```powershell
cd frontend
flutter pub get
flutter run --dart-define=MEMORA_API=http://127.0.0.1:8000
```

Use the matching backend address for the runtime:

| Runtime | Backend URL |
| --- | --- |
| Web/desktop on the backend computer | `http://127.0.0.1:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone | `http://<backend-computer-LAN-address>:8000` |

For web, add the app's origin to `ALLOWED_ORIGINS` in `backend/.env`. Use an
HTTPS backend for release deployments.

## Three-minute demo

### 0:00–0:25 — Introduction

“Hi, I’m Kunal Malik. I’m interested in building practical applications with
AI. MEMORA grew from a familiar problem: sometimes we forget where we put
everyday things. I wanted to explore how AI could make the spaces around us
easier to search.”

Adjust the description of how the idea began to match your own experience.

### 0:25–0:50 — Introduce MEMORA

“MEMORA turns captured spaces into visual memories. I can upload a photo or
take one with the in-app camera, then ask questions about information that
MEMORA has actually saved.”

### 0:50–1:20 — Capture a space

Open **Scan a space**, choose a space, and show **Upload image** and
**Capture image**. Select or take a clear photo, then submit it. Explain that
uploads are stored first and processed asynchronously.

### 1:20–1:55 — Explain processing

“The app is built with Flutter. Its Python and FastAPI backend stores captures
and their evidence. When the model provider is configured, Muse Spark 1.3
analyzes the image and supplies scene and object information. That information
becomes part of the space's saved memory.”

“SAM 3.1 segmentation is not active in this version, so I won't claim that the
app generates or displays segmentation masks.”

### 1:55–2:35 — Ask a grounded question

After processing finishes, ask something clearly supported by the captured
image, such as “Where are the glass jars?” or “What items are visible on the
kitchen counter?” Show the answer and any evidence image.

“MEMORA uses the saved visual information as context. The answer depends on
what has been captured and processed.”

### 2:35–3:00 — Stack and close

“MEMORA uses Flutter, Python, FastAPI, SQLAlchemy, and SQLite for local
development. Muse Spark 1.3 provides optional visual understanding when its
provider is configured. The goal is to make everyday spaces easier to
remember and search. MEMORA: Capture. Remember. Find.”

## Demo checklist

- Confirm the backend is running and the app points to the correct backend URL.
- Use a device/browser where camera permission is available; verify a captured
  image reaches the backend.
- Wait for the selected scan to finish processing before asking about its
  contents.
- Ask a question whose answer is clearly visible in the selected image.
- Do not present an inferred or unsupported location as a confirmed fact.
- Do not claim SAM masks, production-grade always-on camera ingestion, or
  optional OCR and barcode features unless they are enabled and visible in the
  build being demonstrated.

## Important configuration

The backend reads settings from `backend/.env`. Important settings include:

| Setting | Purpose |
| --- | --- |
| `MEMORA_SECRET` | Required authentication-token signing secret |
| `DATABASE_URL` | Database connection; defaults to local SQLite |
| `MEDIA_ROOT` | Local media and derived-file directory |
| `MAX_UPLOAD_MB` | Maximum size of an individual uploaded file |
| `META_API_KEY` | Enables the configured Muse-compatible provider |
| `META_API_BASE` | Provider API base URL |
| `MUSE_SPARK_MODEL` | Model identifier; defaults to `muse-spark-1.3` |
| `SMTP_HOST`, `SMTP_FROM_EMAIL` | Enable password-recovery email |
| `ALLOWED_ORIGINS` | Allowed browser origins for API requests |

See the [backend guide](./backend/README.md) and
[Flutter guide](./frontend/README.md) for component-specific setup and
configuration.

## Deployment and security

- Keep environment files, model keys, SMTP credentials, and signing keys
  private.
- Use HTTPS for deployed services.
- For production, use PostgreSQL, durable object storage, backups, and managed
  secrets.
- Local media processing uses FastAPI background tasks and local storage; it
  is a development foundation, not a distributed processing queue.
- Camera registration is metadata management, not proof of an active camera
  stream. A development RTSP sampler is available when explicitly configured,
  but it is not a durable production service. Do not put raw camera passwords
  or RTSP credentials in the client.
