# MEMORA Flutter app

The Flutter client provides MEMORA's Android, iOS, and web interface. It
connects to the FastAPI backend for sign-in, workspaces, media uploads,
processing status, saved memories, and question answering.

## Requirements

- Flutter SDK installed and available on `PATH`
- A running MEMORA backend
- Android SDK for Android builds
- macOS and Xcode for iOS builds

## Run locally

From this directory:

```powershell
flutter pub get
flutter run --dart-define=MEMORA_API=http://127.0.0.1:8000
```

Set `MEMORA_API` to the backend base URL. Common local addresses:

| Runtime | Backend URL |
| --- | --- |
| Web/desktop on the backend computer | `http://127.0.0.1:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone | `http://<backend-computer-LAN-address>:8000` |

The backend computer and physical phone must be able to reach each other over
the local network. For web, configure the page's origin in the backend's
`ALLOWED_ORIGINS`. Development mode also permits localhost origins.

Use an HTTPS backend URL for release deployments. Local Android debug builds
may use cleartext HTTP; production services should not.

## Main features

### Sign-in and account recovery

The app supports account sign-in, a **Remember me** preference, and a
**Forgot password?** flow. Password recovery sends a one-time code to the
account email and requires the backend to have SMTP configured. See the
[backend guide](../backend/README.md#configuration).

### Spaces and scans

Open **Scan a space**, select a space, then choose **Scan this space**. The
menu supports:

- **Upload image** — select one or more images.
- **Capture image** — take a photo using the device camera.
- **Upload video** — select one or more videos.
- **Record video** — record a video using a supported device camera.

Uploads are associated with the selected space. The backend accepts one file
per capture; when several files are selected, the app uploads them as
individual captures. Processing happens asynchronously, so a saved image may
appear before its analysis is complete.

### Ask MEMORA

Ask questions about saved workspace memory. Responses may include related
image evidence. Speech recognition and text-to-speech depend on platform,
device permissions, and installed voices.

### Timelines

The Timeline area creates a timeline for an existing or new space. It has
separate upload and camera actions for images and videos. Timeline media is
associated with the timeline rather than the ordinary space-scan flow; entries
can be removed from the timeline.

### Cameras

The Cameras area manages registered camera metadata and provides controls to
start, stop, pause, or resume a camera. The backend has a development RTSP
sampler that can save sampled frames into space memory when configured and
reachable. It runs inside the backend process and is not a durable,
production-grade streaming service. Do not enter raw camera passwords or RTSP
credentials in the client; use a server-side connection reference.

## Image handling and gallery

Images selected from the device photo library are left unchanged on the
device. MEMORA creates a separate upload copy, corrects orientation, and
resizes it to at most 1920 pixels on its longest side before JPEG encoding.
This reduces upload size.

On supported Android and iOS devices, images and videos captured by the app
are also saved to the device gallery when permission is available. Gallery
permissions or camera availability may differ by device and browser.

## Windows projects on exFAT

Flutter may need filesystem symlinks for desktop plugins. exFAT does not
support those symlinks, so dependency setup can fail even if the Flutter SDK
and Pub cache are on another drive. If Windows and Linux desktop builds are not
needed, disable those targets for the local Flutter installation:

```powershell
flutter config --no-enable-windows-desktop --no-enable-linux-desktop
flutter pub get
```

This changes desktop support for the local Flutter installation. To build
Windows or Linux desktop apps, keep those targets enabled and move the project
to an NTFS drive.

## Build

Install the Android SDK required by your Flutter version. Before distributing
an Android release, configure a private release keystore in the Gradle
signing setup.

```powershell
flutter build apk --dart-define=MEMORA_API=https://<your-api-host>
flutter build web --dart-define=MEMORA_API=https://<your-api-host>
```

iOS builds require macOS and Xcode. Configure the deployed HTTPS backend URL
for every release target.

## Related documentation

- [Project overview and demo script](../README.md)
- [Backend setup and API overview](../backend/README.md)
