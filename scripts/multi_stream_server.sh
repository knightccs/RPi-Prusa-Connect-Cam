#!/bin/bash
# Start one isolated stream server per detected camera.

set -u
CONFIG_FILE="${CONFIG_FILE:-/etc/prusa_cam-multi.conf}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/prusa-cam-multi"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"
mkdir -p "$WORK_DIR"
children=()
configs=()

cleanup() {
    trap - TERM INT EXIT
    for pid in "${children[@]}"; do
        # Each worker gets its own session so FFmpeg and Python descendants are
        # stopped together when systemd restarts this service.
        kill -TERM -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    done
    for file in "${configs[@]}"; do rm -f "$file"; done
}
trap cleanup TERM INT EXIT

for ((i=1; i<=CAMERA_COUNT; i++)); do
    type_key="CAMERA_${i}_TYPE"; id_key="CAMERA_${i}_ID"; device_key="CAMERA_${i}_DEVICE"
    name_key="CAMERA_${i}_NAME"; port_key="CAMERA_${i}_PORT"
    worker_config="$WORK_DIR/camera_${i}.conf"
    cat > "$worker_config" <<EOF
CAMERA_TYPE="${!type_key}"
CAMERA_ID="${!id_key}"
CAMERA_DEVICE="${!device_key}"
CAMERA_NAME="${!name_key}"
STREAM_PORT="${!port_key}"
STREAM_WIDTH="${STREAM_WIDTH:-1280}"
STREAM_HEIGHT="${STREAM_HEIGHT:-720}"
STREAM_FRAMERATE="${STREAM_FRAMERATE:-5}"
STREAM_QUALITY="${STREAM_QUALITY:-70}"
EOF
    configs+=("$worker_config")
    echo "Starting ${!name_key} on port ${!port_key}"
    if command -v setsid >/dev/null 2>&1; then
        setsid env CONFIG_FILE="$worker_config" \
            SNAPSHOT_FILE="/tmp/stream_snapshot_${i}.jpg" \
            "$SCRIPT_DIR/stream_server.sh" &
    else
        CONFIG_FILE="$worker_config" \
            SNAPSHOT_FILE="/tmp/stream_snapshot_${i}.jpg" \
            "$SCRIPT_DIR/stream_server.sh" &
    fi
    children+=("$!")
done

wait
