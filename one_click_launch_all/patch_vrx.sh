#!/bin/bash
# Safety-net for VRX issue #876 (LiDAR-at-origin: publish_model_pose=false
# disables the pose-to-TF bridge). Already fixed in Ghostzero00018/vrx
# autoboat/main since 06/05/2026; this script detects fix-in-place and
# exits no-op. Retained against inadvertent revert. Idempotent: safe on
# every launch.

set -e

# Detect workspace root dynamically (same logic as launch_autoboat_complete.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WS_ROOT="$SCRIPT_DIR"
while [ "$WS_ROOT" != "/" ]; do
    if [ -f "$WS_ROOT/install/setup.bash" ]; then break; fi
    WS_ROOT="$(dirname "$WS_ROOT")"
done
if [ ! -f "$WS_ROOT/install/setup.bash" ]; then
    echo "[patch_vrx] WARN: Could not find workspace root — skipping patch"
    exit 0
fi

XACRO="$WS_ROOT/src/vrx/vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro"

if [[ ! -f "$XACRO" ]]; then
    echo "[patch_vrx] WARN: $XACRO not found — skipping patch"
    exit 0
fi

if grep -q '<publish_model_pose>true</publish_model_pose>' "$XACRO"; then
    echo "[patch_vrx] OK: publish_model_pose already true"
    exit 0
fi

echo "[patch_vrx] Applying publish_model_pose=true (VRX issue #876 workaround)"
sed -i 's|<publish_model_pose>false</publish_model_pose>|<publish_model_pose>true</publish_model_pose>|' "$XACRO"

cd "$WS_ROOT"
colcon build --packages-select wamv_gazebo --merge-install > /tmp/patch_vrx_build.log 2>&1 \
    && echo "[patch_vrx] wamv_gazebo rebuilt" \
    || { echo "[patch_vrx] ERROR: rebuild failed, see /tmp/patch_vrx_build.log"; exit 1; }
