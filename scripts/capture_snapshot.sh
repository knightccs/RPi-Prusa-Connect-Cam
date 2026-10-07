#!/bin/bash
# Capture snapshots for Prusa Connect without opening a local MJPEG stream.

set -u
CONFIG_FILE="${CONFIG_FILE:-/etc/prusa_cam-multi-worker.conf}"
SNAPSHOT_FILE="${SNAPSHOT_FILE:-/tmp/stream_snapshot.jpg}"
source "$CONFIG_FILE"

CAPTURE_INTERVAL="${CAPTURE_INTERVAL:-10}"
CAPTURE_WIDTH="${CAPTURE_WIDTH:-1920}"
CAPTURE_HEIGHT="${CAPTURE_HEIGHT:-1080}"
STREAM_QUALITY="${STREAM_QUALITY:-70}"

capture_rpi() {
    local camera_tool
    if command -v rpicam-still >/dev/null 2>&1; then
        camera_tool="rpicam-still"
    elif command -v libcamera-still >/dev/null 2>&1; then
        camera_tool="libcamera-still"
    else
        echo "ERROR: no RPi still-image capture tool found" >&2
        return 1
    fi
    "$camera_tool" --camera "$CAMERA_ID" --width "$CAPTURE_WIDTH" \
        --height "$CAPTURE_HEIGHT" --quality "$STREAM_QUALITY" \
        --nopreview --timeout 1000 --output "$SNAPSHOT_FILE.tmp" >/dev/null 2>&1 \
        && mv -f "$SNAPSHOT_FILE.tmp" "$SNAPSHOT_FILE"
}

capture_usb() {
    ffmpeg -y -f v4l2 -input_format mjpeg \
        -video_size "${STREAM_WIDTH:-1280}x${STREAM_HEIGHT:-720}" \
        -framerate "${STREAM_FRAMERATE:-5}" -i "$CAMERA_DEVICE" \
        -frames:v 1 -f image2 "$SNAPSHOT_FILE.tmp" >/dev/null 2>&1 \
        && mv -f "$SNAPSHOT_FILE.tmp" "$SNAPSHOT_FILE"
}

while true; do
    case "$CAMERA_TYPE" in
        RPI) capture_rpi ;;
        USB) capture_usb ;;
        *) echo "ERROR: unknown camera type: $CAMERA_TYPE" >&2; exit 1 ;;
    esac
    sleep "$CAPTURE_INTERVAL"
done
