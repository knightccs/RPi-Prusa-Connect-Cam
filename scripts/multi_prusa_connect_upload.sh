#!/bin/bash
# Upload the latest snapshot from every configured camera.

set -u
CONFIG_FILE="${CONFIG_FILE:-/etc/prusa_cam-multi.conf}"
source "$CONFIG_FILE"
HTTP_URL="https://connect.prusa3d.com/c/snapshot"
DELAY_SECONDS="${UPLOAD_INTERVAL:-10}"

echo "Uploading $CAMERA_COUNT camera snapshots every ${DELAY_SECONDS}s"

# Set each camera's display name in Prusa Connect once at startup.
for ((i=1; i<=CAMERA_COUNT; i++)); do
    name_key="CAMERA_${i}_NAME"
    fingerprint_key="CAMERA_${i}_FINGERPRINT"
    token_key="CAMERA_${i}_TOKEN"
    camera_name="${!name_key}"
    fingerprint="${!fingerprint_key}"
    token="${!token_key}"
    info_response=$(curl -sS -o /dev/null -w "%{http_code}" -X PUT "https://connect.prusa3d.com/c/info" \
        -H "accept: application/json" \
        -H "content-type: application/json" \
        -H "fingerprint: $fingerprint" \
        -H "token: $token" \
        --data "{\"config\":{\"name\": \"$camera_name\"}}" \
        --no-progress-meter)
    echo "Camera $i registration response: HTTP $info_response"
done

while true; do
    for ((i=1; i<=CAMERA_COUNT; i++)); do
        fingerprint_key="CAMERA_${i}_FINGERPRINT"
        token_key="CAMERA_${i}_TOKEN"
        fingerprint="${!fingerprint_key}"
        token="${!token_key}"
        snapshot="/tmp/stream_snapshot_${i}.jpg"

        if [[ -f "$snapshot" ]]; then
            age=$(($(date +%s) - $(stat -c %Y "$snapshot" 2>/dev/null || echo 0)))
            if [[ "$age" -lt 30 ]]; then
                response=$(curl -s -w "%{http_code}" -X PUT "$HTTP_URL" \
                    -H "accept: */*" -H "content-type: image/jpg" \
                    -H "fingerprint: $fingerprint" -H "token: $token" \
                    --data-binary "@$snapshot" --no-progress-meter \
                    --compressed -o /dev/null --max-time 30)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - camera $i upload: HTTP $response"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - camera $i snapshot is ${age}s old"
            fi
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - camera $i snapshot not ready"
        fi
    done
    sleep "$DELAY_SECONDS"
done
