#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${1:-$SCRIPT_DIR/live_dashboard_preflight.sh}"
CASE_COUNT=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass_case() {
  CASE_COUNT=$((CASE_COUNT + 1))
}

require_literal() {
  local literal="$1"
  grep -Fq -- "$literal" "$PREFLIGHT" || fail "missing contract: $literal"
}

extract_function() {
  local name="$1"
  awk -v start="${name}() {" '
    $0 == start { capture = 1 }
    capture { print }
    capture && $0 == "}" { exit }
  ' "$PREFLIGHT"
}

[ -r "$PREFLIGHT" ] || fail "preflight script missing: $PREFLIGHT"
bash -n "$PREFLIGHT"

require_literal "EXPECTED_HELPER_SHA256='b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12'"
require_literal "EXPECTED_SSID='IMT Nord Europe 5G'"
require_literal 'reject_conflicting_processes workstation "${WORKSTATION_CONFLICT_PATTERNS[@]}"'
require_literal 'reject_conflicting_processes Pi "${PI_CONFLICT_PATTERNS[@]}"'
require_literal 'pgrep -af -- "$pattern"'
require_literal 'case "$pattern" in'
require_literal 'process pattern contains alternation'
require_literal '"$HELPER" --preflight-only'
require_literal 'W1_PREFLIGHT=PASS'
require_literal 'P1_PREFLIGHT=PASS'
require_literal '1:workstation) run_workstation_preflight ;;'
require_literal '2:pi) run_pi_preflight "$2" ;;'
pass_case

WORKSTATION_ARRAY="$(sed -n '/^WORKSTATION_CONFLICT_PATTERNS=(/,/^)/p' "$PREFLIGHT")"
PI_ARRAY="$(sed -n '/^PI_CONFLICT_PATTERNS=(/,/^)/p' "$PREFLIGHT")"
[ -n "$WORKSTATION_ARRAY" ] || fail 'workstation conflict array missing'
[ -n "$PI_ARRAY" ] || fail 'Pi conflict array missing'
! grep -Fq '|' <<<"$WORKSTATION_ARRAY" \
  || fail 'workstation conflict array uses a combined alternation'
! grep -Fq '|' <<<"$PI_ARRAY" \
  || fail 'Pi conflict array uses a combined alternation'
eval "$WORKSTATION_ARRAY"
eval "$PI_ARRAY"
EXPECTED_WORKSTATION_PATTERNS=(
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
EXPECTED_PI_PATTERNS=(
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'pi_live_hailo_mavlink_dashboard.sh'
)
[ "${#WORKSTATION_CONFLICT_PATTERNS[@]}" -eq "${#EXPECTED_WORKSTATION_PATTERNS[@]}" ] \
  || fail 'workstation conflict-pattern count changed'
[ "${#PI_CONFLICT_PATTERNS[@]}" -eq "${#EXPECTED_PI_PATTERNS[@]}" ] \
  || fail 'Pi conflict-pattern count changed'
for index in "${!EXPECTED_WORKSTATION_PATTERNS[@]}"; do
  [ "${WORKSTATION_CONFLICT_PATTERNS[$index]}" = "${EXPECTED_WORKSTATION_PATTERNS[$index]}" ] \
    || fail "workstation conflict pattern changed at index $index"
done
for index in "${!EXPECTED_PI_PATTERNS[@]}"; do
  [ "${PI_CONFLICT_PATTERNS[$index]}" = "${EXPECTED_PI_PATTERNS[$index]}" ] \
    || fail "Pi conflict pattern changed at index $index"
done
pass_case

CONFLICT_FUNCTION="$(extract_function reject_conflicting_processes)"
[ -n "$CONFLICT_FUNCTION" ] || fail 'conflict function was not extractable'

NO_MATCH_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  pgrep() { return 1; }
  reject_conflicting_processes workstation rosbridge mavros pi_live_hailo_mavlink_dashboard.sh
  printf "NO_MATCH=PASS\n"
' _ "$CONFLICT_FUNCTION")"
grep -Fxq 'NO_MATCH=PASS' <<<"$NO_MATCH_OUTPUT" \
  || fail 'no-match process scan did not pass'
pass_case

TRACE="$(mktemp)"
trap 'rm -f "$TRACE"' EXIT
set +e
MATCH_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  TRACE_PATH="$2"
  pgrep() {
    local pattern="${*: -1}"
    printf "%s\n" "$pattern" >>"$TRACE_PATH"
    if [ "$pattern" = mavproxy ]; then
      printf "4242 mavproxy.py --master=/dev/ttyAMA0\n"
      return 0
    fi
    return 1
  }
  reject_conflicting_processes workstation rosbridge mavproxy pi_live_hailo_mavlink_dashboard.sh
' _ "$CONFLICT_FUNCTION" "$TRACE" 2>&1)"
MATCH_RC=$?
set -e
[ "$MATCH_RC" -eq 17 ] || fail "matching process scan exited $MATCH_RC instead of 17"
grep -Fq '4242 mavproxy.py --master=/dev/ttyAMA0' <<<"$MATCH_OUTPUT" \
  || fail 'matching process was not reported'
[ "$(wc -l <"$TRACE")" -eq 3 ] \
  || fail 'matching scan did not inspect each separate pattern'
pass_case

set +e
ERROR_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  pgrep() { return 2; }
  reject_conflicting_processes Pi mavros
' _ "$CONFLICT_FUNCTION" 2>&1)"
ERROR_RC=$?
set -e
[ "$ERROR_RC" -eq 17 ] || fail "pgrep-error case exited $ERROR_RC instead of 17"
grep -Fq 'cannot inspect Pi processes for pattern: mavros' <<<"$ERROR_OUTPUT" \
  || fail 'pgrep inspection error was treated as no match'
pass_case

for bad_pattern in '' 'rosbridge|mavros' $'rosbridge\nmavros'; do
  set +e
  BAD_OUTPUT="$(bash -c '
    eval "$1"
    fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
    pgrep() { printf "PGREP_MUST_NOT_RUN\n"; return 0; }
    reject_conflicting_processes workstation "$2"
  ' _ "$CONFLICT_FUNCTION" "$bad_pattern" 2>&1)"
  BAD_RC=$?
  set -e
  [ "$BAD_RC" -eq 17 ] || fail "invalid-pattern case exited $BAD_RC instead of 17"
  ! grep -Fq 'PGREP_MUST_NOT_RUN' <<<"$BAD_OUTPUT" \
    || fail 'invalid process pattern reached pgrep'
  pass_case
done

[ "$CASE_COUNT" -eq 8 ] || fail "executed $CASE_COUNT cases instead of 8"
printf 'PASS: live-dashboard preflight contracts cases=%s\n' "$CASE_COUNT"
