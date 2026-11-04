# Camera integration

MEMORA includes a development RTSP sampler. It is started through the
authenticated camera API and runs as an in-process background thread; it is
not an always-on, production-grade camera service.

## Configure a stream

1. Register a camera in the workspace with a `connection_ref`.
2. Add a mapping from that reference to an RTSP URL in the backend environment:

   ```dotenv
   MEMORA_CAMERA_STREAMS_JSON={"garage":"rtsp://192.168.1.20:8554/live"}
   ```

3. Ensure the backend host can reach the camera and its stream is compatible
   with OpenCV/FFmpeg.
4. Start the camera from the app or call `POST /api/v1/cameras/{camera_id}/start`.

The stream URL is resolved on the backend, not supplied by the Flutter app.
Use a private network address and protect `.env`; do not commit stream
credentials. The currently supported sampler protocols are `rtsp://` and
`rtsps://`. Although the registry accepts other protocol labels for metadata,
those protocols do not have stream workers here.

## Runtime behavior

The sampler reads one frame per configured interval, with a minimum interval
of 15 seconds. Each saved frame becomes a photo capture and is submitted to the
same processing function as other captures. Worker state and the last error
are held in process memory.

`CAMERA_INGESTION_ENABLED` is currently a reserved setting and is not checked
by the start endpoint. Restarting the backend stops in-process workers;
workers are not coordinated across multiple server processes.

## Not included

- ONVIF camera discovery
- Vendor cloud camera APIs
- A supervised, durable worker queue or multi-process coordination
- Motion-triggered sampling
- Production retention enforcement and camera-specific quotas

For production, put stream credentials in a secrets manager and run camera
sampling in a supervised worker service with access controls, retention
enforcement, health monitoring, and audit logging.
