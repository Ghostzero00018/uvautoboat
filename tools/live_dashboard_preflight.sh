#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DASHBOARD_DIR="$REPO_ROOT/web_dashboard/autoboat"
HELPER="$SCRIPT_DIR/pi_live_hailo_mavlink_dashboard.sh"
EXPECTED_HELPER_SHA256='b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12'
EXPECTED_SSID='IMT Nord Europe 5G'

WORKSTATION_CONFLICT_PATTERNS=(
  'rosbridge'
  'web_video_server'
  'serve_dashboard.py'
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'gazebo'
  'gz sim'
  'waypoint_planner'
  'pi_live_hailo_mavlink_dashboard.sh'
)

PI_CONFLICT_PATTERNS=(
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'pi_live_hailo_mavlink_dashboard.sh'
)

WORKSTATION_PORTS=(8002 8080 9090)
PI_DEVICES=(/dev/ttyAMA0 /dev/video4 /dev/hailo0)
THERMAL_PATH='/sys/class/thermal/thermal_zone0/temp'

log() {
  printf '[live-dashboard-preflight] %s\n' "$*"
}

fail() {
  printf '[live-dashboard-preflight] FAIL: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf 'usage: %s workstation\n' "${0##*/}" >&2
  printf '       %s pi WORKSTATION_IP\n' "${0##*/}" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

check_helper_pin() {
  [ -r "$HELPER" ] || fail "helper missing: $HELPER"
  printf '%s  %s\n' "$EXPECTED_HELPER_SHA256" "$HELPER" | sha256sum -c -
}

reject_conflicting_processes() {
  local context="$1" pattern output rc
  local found=0
  shift

  for pattern in "$@"; do
    [ -n "$pattern" ] || fail "$context process pattern is empty"
    case "$pattern" in
      *'|'*) fail "$context process pattern contains alternation: $pattern" ;;
      *$'\n'*|*$'\r'*) fail "$context process pattern contains a line break" ;;
    esac

    if output="$(pgrep -af -- "$pattern")"; then
      printf '%s\n' "$output" >&2
      found=1
    else
      rc=$?
      [ "$rc" -eq 1 ] \
        || fail "cannot inspect $context processes for pattern: $pattern"
    fi
  done

  [ "$found" -eq 0 ] || fail "$context conflicting process found"
}

reject_listening_tcp_ports() {
  local state port matches
  local found=0
  state="$(ss -H -ltn)" || fail 'cannot inspect workstation TCP listeners'

  for port in "$@"; do
    matches="$(awk -v target="$port" '
      {
        local_address = $4
        sub(/^.*:/, "", local_address)
        if (local_address == target) print
      }
    ' <<<"$state")"
    if [ -n "$matches" ]; then
      printf '%s\n' "$matches" >&2
      found=1
    fi
  done

  [ "$found" -eq 0 ] || fail 'workstation dashboard port already in use'
}

reject_device_owners() {
  local device owners rc
  for device in "$@"; do
    if owners="$(fuser "$device" 2>/dev/null)"; then
      [ -z "$owners" ] || fail "$device already in use by:$owners"
    else
      rc=$?
      [ "$rc" -eq 1 ] || fail "cannot inspect device owner: $device"
    fi
  done
}

run_workstation_preflight() {
  local wifi_state ip_state

  for command in node sha256sum nmcli ip ss pgrep awk grep; do
    require_command "$command"
  done

  check_helper_pin
  "$SCRIPT_DIR/test_pi_live_hailo_mavlink_dashboard.sh" "$HELPER"
  "$SCRIPT_DIR/test_live_dashboard_preflight.sh" "$SCRIPT_DIR/live_dashboard_preflight.sh"
  node --test --test-isolation=none "$DASHBOARD_DIR"/test/*.test.js
  node --check "$DASHBOARD_DIR/app.js"

  wifi_state="$(nmcli -t -f ACTIVE,SSID dev wifi)" \
    || fail 'cannot inspect workstation Wi-Fi state'
  grep -Fxq "yes:$EXPECTED_SSID" <<<"$wifi_state" \
    || fail "workstation is not on SSID: $EXPECTED_SSID"

  ip_state="$(ip -4 -brief address)" \
    || fail 'cannot inspect workstation IPv4 addresses'
  printf '%s\n' "$ip_state"

  reject_listening_tcp_ports "${WORKSTATION_PORTS[@]}"
  reject_conflicting_processes workstation "${WORKSTATION_CONFLICT_PATTERNS[@]}"
  log 'W1_PREFLIGHT=PASS tests=dashboard,helper,preflight ports=8002,8080,9090'
}

run_pi_preflight() {
  local workstation_ip="$1" device port_state route pi_interface ssid

  [[ "$workstation_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] \
    || fail "invalid workstation IPv4 address: $workstation_ip"

  for command in sha256sum pgrep fuser ss ip iwgetid awk; do
    require_command "$command"
  done

  check_helper_pin
  reject_conflicting_processes Pi "${PI_CONFLICT_PATTERNS[@]}"

  for device in "${PI_DEVICES[@]}"; do
    [ -e "$device" ] || fail "required Pi device missing: $device"
  done
  [ -c /dev/hailo0 ] || fail '/dev/hailo0 is not a character device'
  [ -r /dev/ttyAMA0 ] && [ -w /dev/ttyAMA0 ] \
    || fail '/dev/ttyAMA0 is not readable and writable'
  [ -r "$THERMAL_PATH" ] || fail "thermal sensor unreadable: $THERMAL_PATH"

  reject_device_owners "${PI_DEVICES[@]}"
  port_state="$(ss -H -ulnp 'sport = :14550' 2>&1)" \
    || fail 'cannot inspect Pi UDP port 14550'
  [ -z "$port_state" ] || fail "Pi UDP port 14550 already in use: $port_state"

  route="$(ip -4 route get "$workstation_ip")" \
    || fail "no route to workstation: $workstation_ip"
  [ -n "$route" ] || fail "empty route to workstation: $workstation_ip"
  case " $route " in
    *' via '*) fail "workstation route crosses a gateway: $route" ;;
  esac
  pi_interface="$(awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}' \
    <<<"$route")"
  [ -n "$pi_interface" ] || fail 'cannot derive Pi network interface'
  ssid="$(iwgetid "$pi_interface" --raw)" \
    || fail "cannot read SSID on Pi interface: $pi_interface"
  [ "$ssid" = "$EXPECTED_SSID" ] || fail "unexpected Pi SSID: ${ssid:-NONE}"

  "$HELPER" --preflight-only
  log "P1_PREFLIGHT=PASS workstation=$workstation_ip dev=$pi_interface ssid=$ssid"
}

main() {
  case "$#:${1:-}" in
    1:workstation) run_workstation_preflight ;;
    2:pi) run_pi_preflight "$2" ;;
    *) usage ;;
  esac
}

main "$@"
