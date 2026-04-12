#!/bin/bash
# Patches upstream VRX in-tree to work around issue #876
# (LiDAR renders at world origin because publish_model_pose=false disables
# the pose-to-TF bridge). Idempotent: safe to re-run on every launch.

set -e

XACRO="$HOME/seal_ws/src/vrx/vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro"

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

cd "$HOME/seal_ws"
colcon build --packages-select wamv_gazebo --merge-install > /tmp/patch_vrx_build.log 2>&1 \
    && echo "[patch_vrx] wamv_gazebo rebuilt" \
    || { echo "[patch_vrx] ERROR: rebuild failed, see /tmp/patch_vrx_build.log"; exit 1; }
