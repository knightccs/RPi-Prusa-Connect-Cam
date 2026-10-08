# RPi-Prusa-Connect-Multi-Cam

A simple setup script for connecting a Raspberry Pi camera to Prusa Connect. Works with both Raspberry Pi Camera Modules and USB webcams.

## Features

- **Auto-detection** of RPi Camera Modules and USB webcams
- **Live MJPEG stream** viewable in your browser
- **Prusa Connect integration** - automatic snapshot uploads
- **Auto-start on boot** via systemd services
- **One-command installation**

## Requirements

- Raspberry Pi (any model with camera support)
- Raspberry Pi OS Lite (or Desktop)
- Camera:
  - Raspberry Pi Camera Module (any version), or
  - USB Webcam
- Internet connection
- Prusa Connect account with a registered printer

## Quick Install

Run this single command on your Raspberry Pi:

```bash
wget -qO- https://raw.githubusercontent.com/knightccs/RPi-Prusa-Connect-Multi-Cam/main/install.sh | sudo bash
```

Or, if you prefer to review the script first:

```bash
wget https://raw.githubusercontent.com/knightccs/RPi-Prusa-Connect-Multi-Cam/main/install.sh
cat install.sh  # Review the script
sudo bash install.sh
```

## Multi-camera setup

The `multi-camera` branch supports multiple Raspberry Pi cameras and USB
webcams on one Pi. It detects all usable camera devices, asks for each camera's
Prusa Connect token separately, and gives each camera its own fingerprint,
snapshot file, and upload loop.

### Install the multi-camera branch

Clone your fork and select the branch:

```bash
git clone -b multi-camera https://github.com/knightccs/RPi-Prusa-Connect-Multi-Cam.git
cd RPi-Prusa-Connect-Multi-Cam
sudo bash install-multi.sh
```

Before running the installer, create one camera in Prusa Connect for each
camera you want to upload:

1. Open the printer in [Prusa Connect](https://connect.prusa3d.com).
2. Open the **Camera** tab.
3. Choose **Add new other camera**.
4. Copy the token.
5. Repeat for every camera.

The installer then detects the cameras and asks, in order, for each token. It
also asks whether each camera should have a local live stream:

```text
Enable local live stream for this camera? [Y/n]
```

Answer `Y` to serve an MJPEG stream, or `n` to use capture-only mode. Capture-
only cameras still upload snapshots to Prusa Connect but use much less CPU.

### Local stream ports

Streams start at port `8090`:

```text
Camera 1: http://<pi-ip>:8090
Camera 2: http://<pi-ip>:8091
Camera 3: http://<pi-ip>:8092
```

If a camera is capture-only, its port is intentionally unused.

### Avoid conflicts with the original service

If the original single-camera version was installed on the Pi, disable its
services before starting the multi-camera version. Otherwise two services may
try to open the same camera device:

```bash
sudo systemctl disable --now camera-stream.service
sudo systemctl disable --now prusa-connect-upload.service
```

The multi-camera services are:

```bash
sudo systemctl enable --now camera-stream-multi.service
sudo systemctl enable --now prusa-connect-upload-multi.service
```

### Multi-camera configuration

The configuration is stored in `/etc/prusa_cam-multi.conf`. Each camera has
its own settings, including `CAMERA_1_TOKEN`, `CAMERA_2_TOKEN`, and so on.
`CAMERA_N_STREAM=1` enables a local stream; `CAMERA_N_STREAM=0` enables
capture-only uploads.

The default stream settings are deliberately modest for Raspberry Pi hardware:

```text
STREAM_WIDTH=1280
STREAM_HEIGHT=720
STREAM_FRAMERATE=5
STREAM_QUALITY=70
```

Lower `STREAM_WIDTH`, `STREAM_HEIGHT`, or `STREAM_FRAMERATE` if CPU usage is
high. USB cameras that already provide MJPEG frames are copied without
re-encoding.

### Update an existing multi-camera installation

Updating the scripts does not require entering the tokens again:

```bash
cd RPi-Prusa-Connect-Multi-Cam
git pull origin multi-camera
sudo cp scripts/*.sh /opt/prusa-cam-multi/scripts/
sudo chmod +x /opt/prusa-cam-multi/scripts/*.sh
sudo systemctl restart camera-stream-multi
sudo systemctl restart prusa-connect-upload-multi
```

### Multi-camera logs and status

```bash
sudo systemctl status camera-stream-multi --no-pager
sudo systemctl status prusa-connect-upload-multi --no-pager
journalctl -u camera-stream-multi -f
journalctl -u prusa-connect-upload-multi -f
```

Successful uploads normally appear as `camera N upload: HTTP 200` or `HTTP
204`. `snapshot not ready` means the capture worker is not producing a file;
check the camera-stream service log and `/tmp/stream_snapshot_N.jpg`.

## Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/knightccs/RPi-Prusa-Connect-Multi-Cam.git
   cd RPi-Prusa-Connect-Multi-Cam
   ```

2. Run the installer:
   ```bash
   sudo bash install.sh
   ```

## Getting Your Prusa Connect Token

1. Go to [Prusa Connect](https://connect.prusa3d.com)
2. Select your printer
3. Navigate to the **Camera** tab
4. Click **Add new other camera**
5. Copy the **Token** shown

You'll need this token during installation.

## After Installation

### View Camera Stream

Open your browser and go to:
```
http://<raspberry-pi-ip>:8080
```

### View Logs

```bash
# Upload service logs
journalctl -u prusa-connect-upload -f

# Stream service logs
journalctl -u camera-stream -f
```

### Service Commands

```bash
# Restart services
sudo systemctl restart prusa-connect-upload
sudo systemctl restart camera-stream

# Stop services
sudo systemctl stop prusa-connect-upload
sudo systemctl stop camera-stream

# Start services
sudo systemctl start prusa-connect-upload
sudo systemctl start camera-stream

# Check status
sudo systemctl status prusa-connect-upload
sudo systemctl status camera-stream
```

### Edit Configuration

```bash
sudo nano /etc/prusa_cam.conf
```

After editing, restart the services:
```bash
sudo systemctl restart prusa-connect-upload
sudo systemctl restart camera-stream
```

## Configuration Options

The configuration file `/etc/prusa_cam.conf` contains:

| Setting | Description | Default |
|---------|-------------|---------|
| `CAMERA_TYPE` | Camera type: `RPI` or `USB` | Auto-detected |
| `CAMERA_ID` | Camera index (RPi) or device path (USB) | Auto-detected |
| `CAPTURE_WIDTH` | Snapshot width for Prusa Connect | 1920 |
| `CAPTURE_HEIGHT` | Snapshot height for Prusa Connect | 1080 |
| `UPLOAD_INTERVAL` | Seconds between uploads | 10 |
| `STREAM_PORT` | Local stream server port | 8080 |
| `STREAM_WIDTH` | Stream resolution width | 1280 |
| `STREAM_HEIGHT` | Stream resolution height | 720 |

## Uninstall

```bash
sudo /opt/prusa-cam/uninstall.sh
```

Or run:
```bash
wget -qO- https://raw.githubusercontent.com/knightccs/RPi-Prusa-Connect-Multi-Cam/main/uninstall.sh | sudo bash
```

## Troubleshooting

### Camera not detected

**RPi Camera Module:**
- Ensure the camera is properly connected
- Enable camera in raspi-config: `sudo raspi-config` -> Interface Options -> Camera
- Reboot after enabling

**USB Webcam:**
- Try a different USB port
- Check if detected: `v4l2-ctl --list-devices`
- Some webcams require additional drivers

### Stream not loading

- Check if the service is running: `sudo systemctl status camera-stream`
- Check logs: `journalctl -u camera-stream -f`
- Verify the port is not blocked by firewall

### Uploads failing

- Verify your token is correct in `/etc/prusa_cam.conf`
- Check logs: `journalctl -u prusa-connect-upload -f`
- Ensure internet connection is working

### RPi Camera not working after OS update

Newer Raspberry Pi OS versions use `rpicam-*` commands instead of `libcamera-*`. The script automatically detects and uses the correct commands.

## How It Works

1. **Camera Detection**: Uses `rpicam-hello`/`libcamera-hello` for RPi cameras and `v4l2-ctl` for USB cameras
2. **Live Stream**: Lightweight Python MJPEG server streams video and saves snapshots to RAM (`/tmp`)
3. **Snapshot Upload**: Uploads snapshots to Prusa Connect API every 10 seconds
4. **Auto-start**: systemd services ensure everything starts on boot

**Note**: All temporary files are stored in `/tmp` (tmpfs/RAM) to avoid SD card wear.

## Credits

Inspired by [cannikin's gist](https://gist.github.com/cannikin/4954d050b72ff61ef0719c42922464e5).

## License

MIT License - feel free to modify and share!
