# Test MEMORA with your Android phone as an RTSP camera

This guide assumes your Android phone and Windows laptop are on the same Wi-Fi network.

## A. Start an RTSP server on Android

1. Install **IP Webcam** on Android (the app is a phone-to-IP-camera streaming app).
2. Connect the phone to the same Wi-Fi network as the laptop.
3. Open IP Webcam and choose a moderate resolution such as 1280x720.
4. Scroll down and tap **Start server**. Grant camera permission.
5. Keep the server running and note the phone's LAN IP and port shown by the app.
6. The common RTSP path for IP Webcam is `/h264_pcm.sdp`; verify the exact RTSP URL shown/used by your app version.

Example only:
`rtsp://192.168.1.105:8080/h264_pcm.sdp`

Do not use `localhost` or `127.0.0.1`: the stream host is the PHONE's Wi-Fi IP.

## B. Verify the stream before MEMORA

On the laptop, open VLC → Media → Open Network Stream and enter the RTSP URL.
If VLC cannot play it, MEMORA cannot read it yet. Check both devices are on the same subnet,
the phone server is running, and Windows Firewall permits VLC/Python on Private networks.

For FFmpeg/OpenCV RTSP-over-TCP compatibility, in the same PowerShell window used to start
FastAPI, run:

```powershell
$env:OPENCV_FFMPEG_CAPTURE_OPTIONS = "rtsp_transport;tcp"
```

## C. Configure the backend secret reference

In `backend/.env`, add/update:

```dotenv
CAMERA_INGESTION_ENABLED=true
CAMERA_SAMPLE_INTERVAL_SECONDS=30
MEMORA_CAMERA_STREAMS_JSON={"phonecam":"rtsp://192.168.1.105:8080/h264_pcm.sdp"}
```

Replace the sample IP and path with the exact URL that VLC successfully plays. This is a local
development convenience. The raw URL is kept in `.env`, not in the camera database record.
Do not commit `.env` to Git. For production, replace this mapping with a secrets manager.

Restart FastAPI after changing `.env`:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
$env:OPENCV_FFMPEG_CAPTURE_OPTIONS = "rtsp_transport;tcp"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

`--host 0.0.0.0` is needed only if Flutter on a physical phone also needs to reach the laptop.
For the current test, the MEMORA Flutter app can run on your laptop/emulator as before.

## D. Register and start the phone camera

1. Sign in to MEMORA and select the workspace you want.
2. Open **Cameras** → **Add camera**.
3. Name: `Android Phone Camera`.
4. Protocol: `RTSP`.
5. Secret reference: `phonecam` (must match the JSON key exactly).
6. Save.
7. Press the blue **Start stream ingestion** play icon on the camera card.
8. Check the API status:
   `GET /api/v1/cameras/{camera_id}/status`
9. A successful worker reports `worker_state: online` and updates `last_frame_at`.

The worker samples one frame every `CAMERA_SAMPLE_INTERVAL_SECONDS` (minimum 15 seconds),
stores it as a normal MEMORA photo capture, and sends it through the existing processing
pipeline. Objects/evidence should then appear in MEMORA's existing object and capture APIs.

## E. Stop the camera

Press the stop icon in the Cameras screen, or call:
`POST /api/v1/cameras/{camera_id}/stop`

Stop the IP Webcam server on Android when finished.

## Troubleshooting

- **No stream configured for phonecam:** the JSON key in `.env` must exactly match the
  Connection reference entered in MEMORA; restart FastAPI after editing `.env`.
- **Could not open stream:** verify in VLC first; check the phone IP has not changed.
- **VLC works but OpenCV fails:** set `OPENCV_FFMPEG_CAPTURE_OPTIONS` to RTSP TCP before
  launching FastAPI and verify OpenCV was installed with FFmpeg support.
- **Phone stream drops:** disable Android battery optimization for the camera app, keep the
  phone plugged in, prevent screen sleep if the app requires it, and reconnect on the same Wi-Fi.
- **No objects are detected:** camera frame ingestion may work while vision analysis is
  unavailable. Configure the existing vision provider credentials (for example `META_API_KEY`)
  or an enabled local vision provider, then inspect `GET /captures/{capture_id}` and backend logs.
- **Can't reach FastAPI from a physical Android Flutter app:** use the laptop's LAN IPv4 address
  as the API base URL, not `127.0.0.1`, and allow Python through Windows Firewall on Private networks.

## Current scope and limitations

This is a local development worker running inside the FastAPI process. It is not a resilient
production streaming service: worker state is in memory, workers do not automatically resume
after server restarts, and multiple Uvicorn workers would create coordination problems. Use one
Uvicorn worker for this test. It samples still frames; it does not save continuous video or
perform real-time tracking. Camera frames are processed using the existing MEMORA processing
pipeline. Secure secret-manager integration, a supervised external worker, ONVIF discovery,
retention enforcement, and cross-camera identity tracking remain future production work.
