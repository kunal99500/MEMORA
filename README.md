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
- Store upkeep records and private PDF/DOCX documents with a required
  description, then search document text locally for matching passages.
- Create separate space timelines and add or remove timeline media there.
- Register and manage camera metadata.

Answers are grounded in the workspace information MEMORA has saved. They
cannot reliably describe a space or item that has not been captured and
processed.

### Upkeep documents and AI privacy

Upkeep accepts PDF and DOCX files; each upload requires a description.
Document questions search extracted text locally and return matching passages
without sending document text to the AI provider. Scanned/image-only PDFs may
not be searchable; convert legacy `.doc` files to `.docx`.

Image analysis and Ask MEMORA require acceptance of the in-app AI privacy
notice. Relevant images or saved visual-memory context may be sent to the
configured third-party AI provider. The provider controls its own data
handling, so MEMORA cannot guarantee its retention or training practices.
Users can withdraw consent in Upkeep's AI privacy settings.

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

## Connect an RTSP camera

MEMORA has a development RTSP sampler. This can connect an Android phone
running an IP-camera app or another RTSP/RTSPS camera to a workspace. The
backend must be able to reach the camera over the network.

### 1. Start the camera stream

For an Android phone, install an IP-camera app such as IP Webcam, connect the
phone and backend computer to the same Wi-Fi network, grant camera permission,
and start its server. Note the phone's Wi-Fi IP address, port, and RTSP path.
For a dedicated camera, find its RTSP/RTSPS stream URL in the camera's
authorized configuration.

An example URL might look like this:

```text
rtsp://192.168.1.105:8080/h264_pcm.sdp
```

Use the actual URL and path shown for your device; this example is not
universal. Use the camera device's LAN IP, not `localhost` or `127.0.0.1`.
Before configuring MEMORA, verify the URL from the backend computer with VLC
or another RTSP player. If that player cannot open the stream, MEMORA will not
be able to read it either.

### 2. Configure the backend

In `backend/.env`, map a short reference name to the stream URL:

```dotenv
CAMERA_SAMPLE_INTERVAL_SECONDS=30
MEMORA_CAMERA_STREAMS_JSON={"phonecam":"rtsp://192.168.1.105:8080/h264_pcm.sdp"}
```

Replace the sample URL with the stream URL you verified. Keep stream URLs and
credentials private; do not commit `.env` or enter raw passwords in the app.
The app's **Secret reference** field must contain the mapping key (`phonecam`
in this example), not the RTSP URL.

If OpenCV/FFmpeg has trouble opening the RTSP stream, set this environment
variable in the same PowerShell window before starting FastAPI:

```powershell
$env:OPENCV_FFMPEG_CAPTURE_OPTIONS = "rtsp_transport;tcp"
```

Restart the backend after changing `.env`:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
$env:OPENCV_FFMPEG_CAPTURE_OPTIONS = "rtsp_transport;tcp"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Use `--host 0.0.0.0` only when another device, such as a physical phone
running the MEMORA app, needs to connect to the backend computer. Allow Python
through Windows Firewall on a trusted Private network if prompted. Avoid
exposing the development server to the public internet.

### 3. Register and start it in MEMORA

1. Sign in and select the workspace that should own the camera captures.
2. Open **Cameras** and choose **Add camera**.
3. Give it a name, select **RTSP**, and enter the matching reference name
   (for example, `phonecam`) as the secret reference.
4. Save the camera and choose **Start stream ingestion**.
5. Check the camera status. A connected worker reports `worker_state: online`
   and updates `last_frame_at`.

The worker saves sampled still frames as ordinary photo captures and sends
them through the existing processing pipeline. The configured interval has a
15-second minimum. Stop the worker from the camera card or call
`POST /api/v1/cameras/{camera_id}/stop`; stop the phone's camera server when
finished.

### Troubleshooting and limitations

- **No stream configured:** ensure the app's secret reference exactly matches
  the key in `MEMORA_CAMERA_STREAMS_JSON`, then restart FastAPI.
- **Cannot open the stream:** verify it in VLC, check the device IP and RTSP
  path, and confirm both devices can communicate on the network.
- **VLC works but MEMORA does not:** try the FFmpeg TCP setting above and
  confirm the OpenCV build has FFmpeg support.
- **No objects appear:** a saved frame does not guarantee vision analysis.
  Configure `META_API_KEY` and check capture status and backend logs.
- **Phone stream stops:** keep the phone powered, check the camera app's
  background/battery settings, and prevent it from being stopped by the OS.

This is a development worker that runs inside the FastAPI process. It keeps
worker state in memory, stops when the backend stops, and is not coordinated
across multiple server workers. It samples still frames; it does not save
continuous video or provide real-time tracking. For production, use a
supervised worker service and a secrets manager. See the
[backend camera integration guide](./backend/app/cameras/README.md).

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
- Mount persistent storage at `MEDIA_ROOT` when using a host with an
  ephemeral filesystem, or uploaded documents and other media may be lost on
  restart or redeploy.
- Local media processing uses FastAPI background tasks and local storage; it
  is a development foundation, not a distributed processing queue.
- Camera registration is metadata management, not proof of an active camera
  stream. A development RTSP sampler is available when explicitly configured,
  but it is not a durable production service. Do not put raw camera passwords
  or RTSP credentials in the client.
