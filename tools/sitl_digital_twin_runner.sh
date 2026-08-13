#!/usr/bin/env bash

# Sourced only by live_dashboard_preflight.sh for its explicit `sitl` branch.

SITL_ARDUPILOT_ROOT='/home/ghostzero/ardupilot'
SITL_ROVER_BINARY='/home/ghostzero/ardupilot/build/sitl/bin/ardurover'
SITL_MAVPROXY='/home/ghostzero/venv-ardupilot/bin/mavproxy.py'
SITL_ROVER_DEFAULT_PARAMS=(
  '/home/ghostzero/ardupilot/Tools/autotest/default_params/rover.parm'
  '/home/ghostzero/ardupilot/Tools/autotest/default_params/motorboat.parm'
  '/home/ghostzero/ardupilot/Tools/autotest/default_params/rover-skid.parm'
)
SITL_EXPECTED_ARDUPILOT_HEAD='3fc7011a7d3dc047cbb17d8bd98ee94577d144c6'
SITL_EXPECTED_ROVER_SIZE='4939888'
SITL_EXPECTED_ROVER_SHA256='569412d6843e6b1ecfd2cfd6106ea4f60559ff440100f3b6dca94a02bf750169'
SITL_BASELINE_REVISION='d911f8a7cbe52b6c08cdd71391fcac823d9d79c4'
SITL_PLUGIN_YAML="$REPO_ROOT/config/mavros_real_fcu_digital_twin_plugins.yaml"
SITL_BRIDGE="$SCRIPT_DIR/real_fcu_rc_command_bridge.py"
SITL_OPERATOR="$SCRIPT_DIR/sitl_operator_once.py"
SITL_EVIDENCE="$SCRIPT_DIR/sitl_digital_twin_evidence.py"
SITL_APM_CONFIG='/opt/ros/jazzy/share/mavros/launch/apm_config.yaml'
SITL_DOMAIN_ID='42'
SITL_DISCOVERY_RANGE='LOCALHOST'
SITL_LOCALHOST_ONLY='1'
SITL_MIN_FREE_KB=$((10 * 1024 * 1024))
SITL_READY_TIMEOUT_SECONDS="${SITL_READY_TIMEOUT_SECONDS:-45}"
SITL_OPERATOR_TIMEOUT_SECONDS="${SITL_OPERATOR_TIMEOUT_SECONDS:-300}"
SITL_SHUTDOWN_FRAME_TIMEOUT_SECONDS="${SITL_SHUTDOWN_FRAME_TIMEOUT_SECONDS:-10}"

SITL_TCP_PORTS=(5760 5762 8002 9090)
SITL_UDP_PORTS=(14600)
SITL_CONFLICT_PATTERNS=(
  'ardurover'
  'sim_vehicle.py'
  'mavproxy.py'
  'MAVProxy'
  'mavros_node'
  'real_fcu_rc_command_bridge.py'
  'sitl_digital_twin_evidence.py'
  'sitl_operator_once.py'
  'rosbridge'
  'serve_dashboard.py'
  'real_fcu_digital_twin_workstation.sh'
  'real_fcu_digital_twin_pi.sh'
)

declare -A SITL_CHILD_INDEX=()
declare -A SITL_CHILD_ACTIVE=()
declare -a SITL_STOP_ORDER=()
declare -a SITL_SITL_COMMAND=()
declare -a SITL_MAVPROXY_COMMAND=()
declare -a SITL_MAVROS_COMMAND=()
declare -a SITL_BRIDGE_COMMAND=()
declare -a SITL_EVIDENCE_COMMAND=()
declare -a SITL_ROSBRIDGE_COMMAND=()
declare -a SITL_DASHBOARD_COMMAND=()

SITL_SESSION_COMPLETE=0
SITL_OPERATOR_GATE_OPEN=0
SITL_ENDPOINT_GUARD_ACTIVE=0
SITL_ARM_GATE_OPENED=0
SITL_CHILDREN_STARTED=0

sitl_validate_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer"
}

sitl_configure_ros_environment() {
  local source_rc=0
  [ -r "$ROS_SETUP" ] || fail "ROS Jazzy setup missing: $ROS_SETUP"

  export ROS_DOMAIN_ID="$SITL_DOMAIN_ID"
  export ROS_AUTOMATIC_DISCOVERY_RANGE="$SITL_DISCOVERY_RANGE"
  export ROS_LOCALHOST_ONLY="$SITL_LOCALHOST_ONLY"
  unset ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
  unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
  unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI

  set +u
  # shellcheck disable=SC1091
  source "$ROS_SETUP" || source_rc=$?
  set -u
  [ "$source_rc" -eq 0 ] || fail "cannot source ROS Jazzy setup: $ROS_SETUP"

  [ "$ROS_DOMAIN_ID" = 42 ] || fail 'ROS_DOMAIN_ID did not remain 42'
  [ "$ROS_AUTOMATIC_DISCOVERY_RANGE" = LOCALHOST ] \
    || fail 'ROS_AUTOMATIC_DISCOVERY_RANGE did not remain LOCALHOST'
  [ "$ROS_LOCALHOST_ONLY" = 1 ] || fail 'ROS_LOCALHOST_ONLY did not remain 1'
  [ -z "${ROS_STATIC_PEERS:-}" ] || fail 'ROS_STATIC_PEERS must be unset'
  [ -z "${ROS_DISCOVERY_SERVER:-}" ] || fail 'ROS_DISCOVERY_SERVER must be unset'
  [ -z "${RMW_IMPLEMENTATION:-}" ] || fail 'RMW_IMPLEMENTATION must be unset'
  [ -z "${FASTDDS_DEFAULT_PROFILES_FILE:-}" ] \
    || fail 'FASTDDS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${FASTRTPS_DEFAULT_PROFILES_FILE:-}" ] \
    || fail 'FASTRTPS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${CYCLONEDDS_URI:-}" ] || fail 'CYCLONEDDS_URI must be unset'
}

sitl_reject_listening_udp_ports() {
  local state port matches found=0
  state="$(ss -H -uln)" || fail 'cannot inspect workstation UDP listeners'
  for port in "$@"; do
    matches="$(awk -v target="$port" '
      {
        local_address = $(NF - 1)
        sub(/^.*:/, "", local_address)
        if (local_address == target) print
      }
    ' <<<"$state")"
    if [ -n "$matches" ]; then
      printf '%s\n' "$matches" >&2
      found=1
    fi
  done
  [ "$found" -eq 0 ] || fail 'SITL UDP port already in use'
}

sitl_verify_repository_state() {
  local status head upstream
  status="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)" \
    || fail 'cannot inspect repository worktree'
  [ -z "$status" ] || fail 'SITL runner requires a clean repository worktree'
  head="$(git -C "$REPO_ROOT" rev-parse HEAD)" || fail 'cannot read repository HEAD'
  git -C "$REPO_ROOT" merge-base --is-ancestor "$SITL_BASELINE_REVISION" "$head" \
    || fail 'repository HEAD does not descend from the approved SITL baseline'
  upstream="$(git -C "$REPO_ROOT" rev-parse refs/remotes/origin/main)" \
    || fail 'cannot read origin/main'
  [ "$head" = "$upstream" ] || fail 'repository HEAD does not match origin/main'
}

sitl_verify_ardupilot_pin() {
  local head size digest identity checkout_status parameter_file
  [ -x "$SITL_ROVER_BINARY" ] || fail "Rover binary missing: $SITL_ROVER_BINARY"
  [ -x "$SITL_MAVPROXY" ] || fail "MAVProxy missing: $SITL_MAVPROXY"
  for parameter_file in "${SITL_ROVER_DEFAULT_PARAMS[@]}"; do
    [ -r "$parameter_file" ] || fail "Rover default parameter file missing: $parameter_file"
  done
  head="$(git -C "$SITL_ARDUPILOT_ROOT" rev-parse HEAD)" \
    || fail 'cannot read ArduPilot checkout revision'
  [ "$head" = "$SITL_EXPECTED_ARDUPILOT_HEAD" ] \
    || fail "unexpected ArduPilot revision: $head"
  checkout_status="$(git -C "$SITL_ARDUPILOT_ROOT" status --porcelain=v1 --untracked-files=no)" \
    || fail 'cannot inspect ArduPilot checkout'
  [ -z "$checkout_status" ] || fail 'ArduPilot tracked worktree is not clean'
  size="$(stat -c '%s' "$SITL_ROVER_BINARY")" || fail 'cannot measure Rover binary'
  [ "$size" = "$SITL_EXPECTED_ROVER_SIZE" ] \
    || fail "unexpected Rover binary size: $size"
  digest="$(sha256sum "$SITL_ROVER_BINARY" | awk '{print $1}')" \
    || fail 'cannot hash Rover binary'
  [ "$digest" = "$SITL_EXPECTED_ROVER_SHA256" ] \
    || fail "unexpected Rover binary digest: $digest"
  identity="$(strings "$SITL_ROVER_BINARY" | awk '
    $0 == "ArduRover V4.6.3 (3fc7011a)" { identity = $0 }
    END {
      if (identity == "") exit 1
      print identity
    }
  ')" \
    || fail 'Rover binary embedded identity is missing'
  [ "$identity" = 'ArduRover V4.6.3 (3fc7011a)' ] \
    || fail "unexpected Rover embedded identity: $identity"
}

sitl_verify_free_disk() {
  local available
  [ -d "$WORKSTATION_LOG_ROOT" ] \
    || fail "workstation log root missing: $WORKSTATION_LOG_ROOT"
  [ -w "$WORKSTATION_LOG_ROOT" ] \
    || fail "workstation log root is not writable: $WORKSTATION_LOG_ROOT"
  available="$(df -Pk "$WORKSTATION_LOG_ROOT" | awk 'NR == 2 {print $4}')" \
    || fail 'cannot inspect free disk space'
  [[ "$available" =~ ^[0-9]+$ ]] || fail 'free-disk result is not numeric'
  [ "$available" -ge "$SITL_MIN_FREE_KB" ] \
    || fail "less than 10 GB free under $WORKSTATION_LOG_ROOT"
}

sitl_static_preflight() {
  local command
  sitl_validate_positive_integer SITL_READY_TIMEOUT_SECONDS "$SITL_READY_TIMEOUT_SECONDS"
  sitl_validate_positive_integer SITL_OPERATOR_TIMEOUT_SECONDS "$SITL_OPERATOR_TIMEOUT_SECONDS"
  sitl_validate_positive_integer SITL_SHUTDOWN_FRAME_TIMEOUT_SECONDS \
    "$SITL_SHUTDOWN_FRAME_TIMEOUT_SECONDS"
  for command in awk bash cat curl date df env git grep mkdir od pgrep ps readlink \
    sed setsid sha256sum sleep ss stat strings tr wc; do
    require_command "$command"
  done
  [ -r "$SITL_PLUGIN_YAML" ] || fail "MAVROS plugin YAML missing: $SITL_PLUGIN_YAML"
  [ -r "$SITL_APM_CONFIG" ] || fail "MAVROS APM config missing: $SITL_APM_CONFIG"
  [ -r "$SITL_BRIDGE" ] || fail "command bridge missing: $SITL_BRIDGE"
  [ -r "$SITL_OPERATOR" ] || fail "operator helper missing: $SITL_OPERATOR"
  [ -r "$SITL_EVIDENCE" ] || fail "evidence helper missing: $SITL_EVIDENCE"
  [ -r "$DASHBOARD_DIR/serve_dashboard.py" ] \
    || fail "dashboard server missing: $DASHBOARD_DIR/serve_dashboard.py"
  sitl_verify_repository_state
  sitl_verify_ardupilot_pin
  sitl_verify_free_disk
  reject_listening_tcp_ports "${SITL_TCP_PORTS[@]}"
  sitl_reject_listening_udp_ports "${SITL_UDP_PORTS[@]}"
  reject_conflicting_processes SITL "${SITL_CONFLICT_PATTERNS[@]}"
  sitl_configure_ros_environment
  require_command ros2
  ros2 pkg prefix mavros >/dev/null || fail 'mavros package missing'
  ros2 pkg prefix rosbridge_server >/dev/null || fail 'rosbridge_server package missing'
  /usr/bin/python3 -c 'import mavros_msgs, rclpy, rosidl_runtime_py, sensor_msgs, std_msgs' \
    || fail 'ROS Python imports required by the SITL runner are unavailable'
  /home/ghostzero/venv-ardupilot/bin/python -c 'from pymavlink import mavutil' \
    || fail 'pymavlink is unavailable in the ArduPilot virtual environment'
}

sitl_init_supervisor_state() {
  local timestamp
  CHILD_NAMES=()
  CHILD_PIDS=()
  CHILD_PGIDS=()
  EMITTED_MARKERS=()
  SITL_CHILD_INDEX=()
  SITL_CHILD_ACTIVE=()
  SITL_STOP_ORDER=()
  SERVICES_UP=0
  CLEANING=0
  STOP_REQUESTED=0
  FINAL_RC=0
  ARRIVAL_ELAPSED_SECONDS=0
  RATE_LOG=''
  SUPERVISOR_LOG=''
  SUPERVISOR_PHASE=initialization
  SUPERVISOR_STOP_TRIGGER=none
  SUPERVISOR_STOP_SIGNAL=none
  SUPERVISOR_STOP_PHASE=none
  SUPERVISOR_FAILED_PHASE=none
  SITL_SESSION_COMPLETE=0
  SITL_OPERATOR_GATE_OPEN=0
  SITL_ENDPOINT_GUARD_ACTIVE=0
  SITL_ARM_GATE_OPENED=0
  SITL_CHILDREN_STARTED=0

  SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')" \
    || fail 'cannot determine SITL supervisor process group'
  [[ "$SUPERVISOR_PGID" =~ ^[1-9][0-9]*$ ]] \
    || fail 'invalid SITL supervisor process group'
  timestamp="$(date +%Y%m%d_%H%M%S)" || fail 'cannot create SITL run timestamp'
  RUN_DIR="$WORKSTATION_LOG_ROOT/sitl_digital_twin_$timestamp"
  [ ! -e "$RUN_DIR" ] || fail "SITL run directory already exists: $RUN_DIR"
  mkdir -m 700 "$RUN_DIR"
  mkdir -m 700 "$RUN_DIR/captures" "$RUN_DIR/control" "$RUN_DIR/evidence" \
    "$RUN_DIR/logs" "$RUN_DIR/manifest" "$RUN_DIR/operator" "$RUN_DIR/sitl_state"
  SUPERVISOR_LOG="$RUN_DIR/supervisor.log"
  : >"$SUPERVISOR_LOG" || {
    SUPERVISOR_LOG=''
    fail "cannot create SITL supervisor log: $RUN_DIR/supervisor.log"
  }
  log "SITL_SUPERVISOR_START pid=$BASHPID pgid=$SUPERVISOR_PGID phase=$SUPERVISOR_PHASE"
}

sitl_write_parameter_file() {
  local path="$RUN_DIR/manifest/sitl.params"
  printf '%s\n' \
    'RC_OVERRIDE_TIME 0.5' \
    'ARMING_RUDDER 0' \
    'BRD_SAFETY_DEFLT 1' >"$path"
  [ "$(wc -l <"$path")" -eq 3 ] || fail 'SITL parameter overlay is not three lines'
  [ "$(sed -n '1p' "$path")" = 'RC_OVERRIDE_TIME 0.5' ] \
    || fail 'SITL parameter overlay line 1 changed'
  [ "$(sed -n '2p' "$path")" = 'ARMING_RUDDER 0' ] \
    || fail 'SITL parameter overlay line 2 changed'
  [ "$(sed -n '3p' "$path")" = 'BRD_SAFETY_DEFLT 1' ] \
    || fail 'SITL parameter overlay line 3 changed'
}

sitl_build_commands() {
  local rover_defaults
  rover_defaults="$(IFS=,; printf '%s' "${SITL_ROVER_DEFAULT_PARAMS[*]}")"
  SITL_SITL_COMMAND=(
    env
    "--chdir=$RUN_DIR/sitl_state"
    -u ROS_DOMAIN_ID -u ROS_AUTOMATIC_DISCOVERY_RANGE -u ROS_LOCALHOST_ONLY
    -u ROS_STATIC_PEERS -u ROS_DISCOVERY_SERVER -u RMW_IMPLEMENTATION
    -u FASTDDS_DEFAULT_PROFILES_FILE -u FASTRTPS_DEFAULT_PROFILES_FILE
    -u CYCLONEDDS_URI
    "$SITL_ROVER_BINARY"
    -S --model motorboat-skid
    # The Rover default is tcp:0:wait, which blocks initialization before
    # SERIAL1 opens. Keep both listener endpoints explicit and non-blocking.
    --serial0 tcp:0 --serial1 tcp:2
    --speedup 1 --slave 0
    --defaults "$rover_defaults,$RUN_DIR/manifest/sitl.params"
    --sim-address=127.0.0.1 -I0
  )
  SITL_MAVPROXY_COMMAND=(
    "$SITL_MAVPROXY"
    '--master=tcp:127.0.0.1:5760:{"autoreconnect":false}'
    '--out=udp:127.0.0.1:14600'
    '--source-system=254' '--source-component=190'
    '--target-system=1' '--target-component=1'
    '--streamrate=-1' '--heartbeat-rate=1' '--retries=0'
    '--default-modules=' '--no-state' '--non-interactive'
  )
  SITL_MAVROS_COMMAND=(
    ros2 run mavros mavros_node --ros-args
    --params-file "$SITL_APM_CONFIG"
    --params-file "$SITL_PLUGIN_YAML"
    -p 'fcu_url:=udp://127.0.0.1:14600@'
    -p 'gcs_url:=""'
    -p 'system_id:=255' -p 'component_id:=191'
    -p 'target_system_id:=1' -p 'target_component_id:=1'
  )
  SITL_BRIDGE_COMMAND=(
    /usr/bin/python3 "$SITL_BRIDGE" --ros-args
    -p 'allow_real_fcu:=true'
    -p 'expected_domain_id:="42"'
    -p 'max_steering:=0.20'
    -p 'max_throttle:=0.12'
  )
  SITL_EVIDENCE_COMMAND=(
    /usr/bin/python3 "$SITL_EVIDENCE" record --run-dir "$RUN_DIR"
  )
  SITL_ROSBRIDGE_COMMAND=(
    ros2 launch rosbridge_server rosbridge_websocket_launch.xml
    'address:=127.0.0.1' 'port:=9090'
  )
  SITL_DASHBOARD_COMMAND=(
    bash -c 'cd -- "$1" && shift && exec "$@"' _ "$DASHBOARD_DIR"
    python3 serve_dashboard.py 8002 127.0.0.1
  )
}

sitl_record_command() {
  local name="$1" argument
  shift
  printf '%s' "$name" >>"$RUN_DIR/manifest/commands.tsv"
  for argument in "$@"; do
    printf '\t%q' "$argument" >>"$RUN_DIR/manifest/commands.tsv"
  done
  printf '\n' >>"$RUN_DIR/manifest/commands.tsv"
}

sitl_write_manifest() {
  local head branch status
  head="$(git -C "$REPO_ROOT" rev-parse HEAD)" || fail 'cannot record repository HEAD'
  branch="$(git -C "$REPO_ROOT" branch --show-current)" || fail 'cannot record repository branch'
  status="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)" \
    || fail 'cannot record repository status'
  [ -z "$status" ] || fail 'repository changed during SITL initialization'
  {
    printf 'repository=%s\n' "$REPO_ROOT"
    printf 'revision=%s\n' "$head"
    printf 'branch=%s\n' "$branch"
    printf 'origin_main=%s\n' "$(git -C "$REPO_ROOT" rev-parse refs/remotes/origin/main)"
    printf 'baseline=%s\n' "$SITL_BASELINE_REVISION"
    printf 'worktree=clean\n'
  } >"$RUN_DIR/manifest/repository.txt"
  {
    printf 'ROS_DOMAIN_ID=%s\n' "$ROS_DOMAIN_ID"
    printf 'ROS_AUTOMATIC_DISCOVERY_RANGE=%s\n' "$ROS_AUTOMATIC_DISCOVERY_RANGE"
    printf 'ROS_LOCALHOST_ONLY=%s\n' "$ROS_LOCALHOST_ONLY"
    printf 'ROS_STATIC_PEERS=unset\n'
    printf 'ROS_DISCOVERY_SERVER=unset\n'
    printf 'RMW_IMPLEMENTATION=unset\n'
    printf 'FASTDDS_DEFAULT_PROFILES_FILE=unset\n'
    printf 'FASTRTPS_DEFAULT_PROFILES_FILE=unset\n'
    printf 'CYCLONEDDS_URI=unset\n'
  } >"$RUN_DIR/manifest/environment.txt"
  sha256sum "$SCRIPT_DIR/live_dashboard_preflight.sh" \
    "$SCRIPT_DIR/sitl_digital_twin_runner.sh" "$SITL_OPERATOR" "$SITL_EVIDENCE" \
    "$SITL_BRIDGE" "$SITL_PLUGIN_YAML" "$SITL_ROVER_BINARY" \
    >"$RUN_DIR/manifest/artifacts.sha256"
  stat -c '%s  %n' "$SCRIPT_DIR/live_dashboard_preflight.sh" \
    "$SCRIPT_DIR/sitl_digital_twin_runner.sh" "$SITL_OPERATOR" "$SITL_EVIDENCE" \
    "$SITL_BRIDGE" "$SITL_PLUGIN_YAML" "$SITL_ROVER_BINARY" \
    >"$RUN_DIR/manifest/artifacts.size"
  : >"$RUN_DIR/manifest/commands.tsv"
  sitl_record_command sitl "${SITL_SITL_COMMAND[@]}"
  sitl_record_command mavproxy "${SITL_MAVPROXY_COMMAND[@]}"
  sitl_record_command mavros "${SITL_MAVROS_COMMAND[@]}"
  sitl_record_command bridge "${SITL_BRIDGE_COMMAND[@]}"
  sitl_record_command evidence "${SITL_EVIDENCE_COMMAND[@]}"
  sitl_record_command rosbridge "${SITL_ROSBRIDGE_COMMAND[@]}"
  sitl_record_command dashboard "${SITL_DASHBOARD_COMMAND[@]}"
  ! grep -Eq '/dev/(tty|serial|cu\.)' "$RUN_DIR/manifest/commands.tsv" \
    || fail 'a serial-device endpoint entered the SITL command manifest'
}

sitl_start_child() {
  local name="$1" logfile="$2" index
  shift 2
  start_child "$name" "$logfile" "$@"
  index=$((${#CHILD_NAMES[@]} - 1))
  SITL_CHILD_INDEX[$name]="$index"
  SITL_CHILD_ACTIVE[$name]=1
  SITL_CHILDREN_STARTED=1
}

sitl_child_is_active() {
  [ "${SITL_CHILD_ACTIVE[$1]:-0}" -eq 1 ]
}

sitl_monitor_children_once() {
  local name index
  for name in "${CHILD_NAMES[@]}"; do
    sitl_child_is_active "$name" || continue
    index="${SITL_CHILD_INDEX[$name]}"
    if ! kill -0 "${CHILD_PIDS[$index]}" 2>/dev/null; then
      log_error "SITL_CHILD_EXITED name=$name pid=${CHILD_PIDS[$index]}"
      return 1
    fi
    if ! group_alive "${CHILD_PGIDS[$index]}"; then
      log_error "SITL_CHILD_GROUP_EXITED name=$name pgid=${CHILD_PGIDS[$index]}"
      return 1
    fi
  done
  [ ! -e "$RUN_DIR/control/capture_fault.json" ] || {
    log_error "SITL_CAPTURE_FAULT file=$RUN_DIR/control/capture_fault.json"
    return 1
  }
  [ "$SITL_ENDPOINT_GUARD_ACTIVE" -eq 0 ] || sitl_verify_mavlink_peers
}

sitl_verify_mavlink_peers() {
  local state serial0_count serial1_count
  state="$(ss -H -nt state established '( sport = :5760 or sport = :5762 )')" \
    || return 1
  if awk '
    {
      local_address = $(NF - 1)
      peer_address = $NF
      if (local_address !~ /^127[.]0[.]0[.]1:/ || peer_address !~ /^127[.]0[.]0[.]1:/) {
        exit 1
      }
    }
  ' <<<"$state"; then
    :
  else
    log_error 'SITL_ENDPOINT_FAULT non-loopback MAVLink peer'
    return 1
  fi
  serial0_count="$(awk '$(NF - 1) ~ /:5760$/ {count++} END {print count+0}' <<<"$state")"
  serial1_count="$(awk '$(NF - 1) ~ /:5762$/ {count++} END {print count+0}' <<<"$state")"
  [ "$serial0_count" -eq 1 ] || {
    log_error "SITL_ENDPOINT_FAULT serial0_pairs=$serial0_count expected=1"
    return 1
  }
  if [ "$SITL_OPERATOR_GATE_OPEN" -eq 1 ]; then
    [ "$serial1_count" -le 1 ] || {
      log_error "SITL_ENDPOINT_FAULT serial1_pairs=$serial1_count expected=0_or_1"
      return 1
    }
  else
    [ "$serial1_count" -eq 0 ] || {
      log_error "SITL_ENDPOINT_FAULT serial1_pairs=$serial1_count outside_gate"
      return 1
    }
  fi
}

sitl_wait_until() {
  local phase="$1" timeout="$2" predicate="$3" deadline rc
  deadline=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$deadline" ]; do
    [ "$STOP_REQUESTED" -eq 0 ] || return 1
    sitl_monitor_children_once || return 1
    if "$predicate"; then
      return 0
    fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  log_error "SITL_PHASE_FAIL phase=$phase rc=1 reason=timeout"
  return 1
}

sitl_udp_loopback_listener_ready() {
  local state
  state="$(ss -H -uln 'sport = :14600')" || return 1
  awk '$5 == "127.0.0.1:14600" || $4 == "127.0.0.1:14600" {found=1}
       END {exit found ? 0 : 1}' <<<"$state"
}

sitl_process_provenance_ready() {
  local index pgid pids pid executable cwd command listener_state listener_pid
  index="${SITL_CHILD_INDEX[sitl]}"
  pgid="${CHILD_PGIDS[$index]}"
  pids="$(ps -eo pid=,pgid=,comm= | awk -v expected="$pgid" \
    '$2 == expected && $3 == "ardurover" {print $1}')" || return 1
  [ "$(wc -w <<<"$pids")" -eq 1 ] || return 1
  pid="$(tr -d ' ' <<<"$pids")"
  executable="$(readlink -f "/proc/$pid/exe")" || return 1
  [ "$executable" = "$SITL_ROVER_BINARY" ] || return 1
  cwd="$(readlink -f "/proc/$pid/cwd")" || return 1
  [ "$cwd" = "$RUN_DIR/sitl_state" ] || return 1
  command="$(tr '\0' ' ' <"/proc/$pid/cmdline")" || return 1
  [[ "$command" == *'--model motorboat-skid'* ]] || return 1
  listener_state="$(ss -H -ltnp '( sport = :5760 or sport = :5762 )')" || return 1
  [ "$(wc -l <<<"$listener_state")" -eq 2 ] || return 1
  while IFS= read -r listener_pid; do
    [ "$listener_pid" = "$pid" ] || return 1
  done < <(sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' <<<"$listener_state")
  [ "$(sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' <<<"$listener_state" | wc -l)" -eq 2 ]
}

sitl_mavproxy_ready() {
  local state
  state="$(ss -H -nt state established 'sport = :5760')" || return 1
  [ "$(awk 'NF {count++} END {print count+0}' <<<"$state")" -eq 1 ] || return 1
  grep -Fq 'online system 1' "$RUN_DIR/logs/mavproxy.log"
}

sitl_log_has_bridge_guard() {
  [ "$(grep -Fc 'live guard resolved:' "$RUN_DIR/logs/bridge.log")" -eq 1 ]
}

sitl_capture_ready() {
  grep -Fq 'SITL_CAPTURE=READY subscriptions=5' "$RUN_DIR/logs/evidence.log"
}

sitl_web_ready() {
  loopback_listener_ready 9090 || return 1
  loopback_listener_ready 8002 || return 1
  curl --fail --silent --show-error --max-time 3 --output /dev/null \
    http://127.0.0.1:8002/
}

sitl_wait_for_file() {
  local phase="$1" path="$2" timeout="${3:-$SITL_OPERATOR_TIMEOUT_SECONDS}"
  SITL_WAIT_PATH="$path"
  sitl_wait_until "$phase" "$timeout" sitl_wait_for_selected_file
}

sitl_wait_for_selected_file() {
  [ -f "$SITL_WAIT_PATH" ]
}

sitl_wait_for_cleanup_file() {
  local phase="$1" path="$2" timeout="${3:-$SITL_OPERATOR_TIMEOUT_SECONDS}"
  local deadline=$((SECONDS + timeout)) index
  while [ "$SECONDS" -lt "$deadline" ]; do
    [ -f "$path" ] && return 0
    if sitl_child_is_active sitl; then
      index="${SITL_CHILD_INDEX[sitl]}"
      kill -0 "${CHILD_PIDS[$index]}" 2>/dev/null || return 1
      group_alive "${CHILD_PGIDS[$index]}" || return 1
    fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  log_error "SITL_PHASE_FAIL phase=$phase rc=1 reason=cleanup-timeout"
  return 1
}

sitl_parse_bridge_mapping() {
  local line parsed steering throttle left right
  line="$(grep -F 'live guard resolved:' "$RUN_DIR/logs/bridge.log")" \
    || fail 'bridge guard line is missing'
  parsed="$(sed -n \
    's/.*steering=RC\([0-9][0-9]*\) throttle=RC\([0-9][0-9]*\) left=SERVO\([0-9][0-9]*\) right=SERVO\([0-9][0-9]*\).*/\1 \2 \3 \4/p' \
    <<<"$line")"
  read -r steering throttle left right <<<"$parsed"
  for value in "$steering" "$throttle" "$left" "$right"; do
    [[ "$value" =~ ^([1-9]|1[0-6])$ ]] || fail 'bridge mapping is missing or out of range'
  done
  [ "$steering" != "$throttle" ] || fail 'bridge resolved duplicate RC channels'
  [ "$left" != "$right" ] || fail 'bridge resolved duplicate servo channels'
  SITL_STEERING_RC="$steering"
  SITL_THROTTLE_RC="$throttle"
  SITL_LEFT_SERVO="$left"
  SITL_RIGHT_SERVO="$right"
  SITL_BENCH_URL="http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=$left&thrust_right_servo=$right"
}

sitl_create_operator_gate() {
  local action="$1" now_ns deadline_ns nonce gate_path
  gate_path="$RUN_DIR/operator/$action.gate.json"
  [ ! -e "$gate_path" ] \
    || { log_error "operator gate already exists: $action"; return 1; }
  [ ! -e "$RUN_DIR/operator/$action.claim.json" ] \
    || { log_error "operator action already claimed: $action"; return 1; }
  [ ! -e "$RUN_DIR/operator/$action.json" ] \
    || { log_error "operator action already completed: $action"; return 1; }
  now_ns="$(date +%s%N)" \
    || { log_error 'cannot create operator gate timestamp'; return 1; }
  deadline_ns=$((now_ns + SITL_OPERATOR_TIMEOUT_SECONDS * 1000000000))
  nonce="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')" \
    || { log_error 'cannot create operator gate nonce'; return 1; }
  [ "${#nonce}" -eq 32 ] \
    || { log_error 'operator gate nonce is invalid'; return 1; }
  /usr/bin/python3 -c '
import json, os, pathlib, sys
path = pathlib.Path(sys.argv[1])
payload = {
    "schema": "uvautoboat.sitl.operator.v1",
    "action": sys.argv[2],
    "run_dir": sys.argv[3],
    "endpoint": "tcp:127.0.0.1:5762",
    "source_system": 254,
    "source_component": 190,
    "target_system": 1,
    "target_component": 1,
    "deadline_unix_ns": int(sys.argv[4]),
    "nonce": sys.argv[5],
}
temporary = path.with_name("." + path.name + ".tmp")
with temporary.open("x", encoding="utf-8") as stream:
    json.dump(payload, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
    stream.write("\n")
    stream.flush()
    os.fsync(stream.fileno())
os.replace(temporary, path)
' "$gate_path" "$action" "$RUN_DIR" "$deadline_ns" "$nonce" \
    || { log_error "cannot create operator gate: $action"; return 1; }
  SITL_OPERATOR_GATE_OPEN=1
  [ "$action" != arm ] || SITL_ARM_GATE_OPENED=1
  printf '\nWorkstation operator terminal (new, one-shot, no ROS source):\n'
  printf 'cd %q\n' "$REPO_ROOT"
  printf '%q %q --run-dir %q --action %q\n\n' \
    '/home/ghostzero/venv-ardupilot/bin/python' "$SITL_OPERATOR" "$RUN_DIR" "$action"
  printf 'Do NOT interrupt that command. It claims the gate before it opens the\n'
  printf 'link, and the claim outlives Ctrl+C, so a re-run is refused and this\n'
  printf 'phase can only time out. Let it finish or fail on its own.\n\n'
  log "SITL_OPERATOR_GATE=OPEN action=$action deadline_unix_ns=$deadline_ns"
}

sitl_operator_result_success() {
  local path="$1" action="$2"
  /usr/bin/python3 -c '
import json, pathlib, sys
payload = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
raise SystemExit(0 if payload.get("action") == sys.argv[2] and payload.get("success") is True else 1)
' "$path" "$action"
}

sitl_wait_operator_action() {
  local action="$1" mode="${2:-normal}" result rc state
  result="$RUN_DIR/operator/$action.json"
  if [ "$mode" = cleanup ]; then
    sitl_wait_for_cleanup_file "operator-$action" "$result"
    rc=$?
  elif sitl_wait_for_file "operator-$action" "$result"; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    :
  else
    SITL_OPERATOR_GATE_OPEN=0
    return "$rc"
  fi
  SITL_OPERATOR_GATE_OPEN=0
  sitl_operator_result_success "$result" "$action" \
    || { log_error "SITL_PHASE_FAIL phase=operator-$action rc=1"; return 1; }
  if [ "$mode" = cleanup ]; then
    state="$(ss -H -nt state established 'sport = :5762')" || return 1
    [ -z "$state" ] || return 1
  else
    sitl_verify_mavlink_peers || return 1
  fi
  log "SITL_OPERATOR_ACTION=PASS action=$action result=$result"
}

sitl_stop_named_child() {
  local name="$1" index
  sitl_child_is_active "$name" || return 0
  index="${SITL_CHILD_INDEX[$name]}"
  if stop_group "$name" "${CHILD_PGIDS[$index]}" "${CHILD_PIDS[$index]}"; then
    SITL_CHILD_ACTIVE[$name]=0
    SITL_STOP_ORDER+=("$name")
    return 0
  fi
  SITL_CHILD_ACTIVE[$name]=0
  SITL_STOP_ORDER+=("$name-failed")
  return 1
}

sitl_register_untracked_children() {
  local index name
  for ((index=0; index<${#CHILD_NAMES[@]}; index++)); do
    name="${CHILD_NAMES[$index]}"
    if [ -z "${SITL_CHILD_INDEX[$name]+present}" ]; then
      SITL_CHILD_INDEX[$name]="$index"
      SITL_CHILD_ACTIVE[$name]=1
    fi
  done
  [ "${#CHILD_NAMES[@]}" -eq 0 ] || SITL_CHILDREN_STARTED=1
}

sitl_latest_state_rc() {
  /usr/bin/python3 "$SITL_EVIDENCE" latest-state --run-dir "$RUN_DIR" \
    >>"$SUPERVISOR_LOG" 2>&1
}

sitl_cleanup_disarm_if_needed() {
  local state_rc=4
  [ "$SITL_ARM_GATE_OPENED" -eq 1 ] || return 0
  [ ! -f "$RUN_DIR/evidence/disarm.json" ] || return 0
  if sitl_latest_state_rc; then
    state_rc=0
  else
    state_rc=$?
  fi
  [ "$state_rc" -ne 0 ] || return 0
  log_error "SITL_CLEANUP_DISARM=REQUIRED state_rc=$state_rc"
  sitl_stop_named_child dashboard || true
  sitl_stop_named_child rosbridge || true
  sitl_create_operator_gate disarm || return 1
  sitl_wait_operator_action disarm cleanup || return 1
  sitl_wait_for_cleanup_file cleanup-disarm "$RUN_DIR/evidence/disarm.json" \
    "$SITL_READY_TIMEOUT_SECONDS" || return 1
  sitl_wait_for_cleanup_file cleanup-disarm-release \
    "$RUN_DIR/control/disarm_release_frames.json" "$SITL_READY_TIMEOUT_SECONDS"
}

sitl_write_teardown_request() {
  local path="$RUN_DIR/control/teardown_requested.json" now_ns
  [ -e "$path" ] && return 0
  now_ns="$(date +%s%N)" || return 1
  /usr/bin/python3 -c '
import json, os, pathlib, sys
path = pathlib.Path(sys.argv[1])
temporary = path.with_name("." + path.name + ".tmp")
payload = {
    "schema": "uvautoboat.sitl.evidence.v1",
    "requested_unix_ns": int(sys.argv[2]),
}
with temporary.open("x", encoding="utf-8") as stream:
    json.dump(payload, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
    stream.write("\n")
    stream.flush()
    os.fsync(stream.fileno())
os.replace(temporary, path)
' "$path" "$now_ns"
}

sitl_wait_shutdown_frames() {
  local deadline=$((SECONDS + SITL_SHUTDOWN_FRAME_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    [ -f "$RUN_DIR/control/shutdown_frames.json" ] && return 0
    sitl_child_is_active evidence || return 1
    local index="${SITL_CHILD_INDEX[evidence]}"
    kill -0 "${CHILD_PIDS[$index]}" 2>/dev/null || return 1
    sleep 0.1 || true
  done
  return 1
}

sitl_children_stopped_once() {
  local i
  for ((i=0; i<${#CHILD_PGIDS[@]}; i++)); do
    group_alive "${CHILD_PGIDS[$i]}" && return 1
  done
  return 0
}

sitl_ports_free_once() {
  local port state
  for port in "${SITL_TCP_PORTS[@]}"; do
    state="$(ss -H -ltn "sport = :$port")" || return 1
    [ -z "$state" ] || return 1
  done
  state="$(ss -H -uln 'sport = :14600')" || return 1
  [ -z "$state" ]
}

sitl_write_teardown_runtime() {
  local cleanup_rc="$1" children_stopped=false ports_free=false order
  sitl_children_stopped_once && children_stopped=true
  sitl_ports_free_once && ports_free=true
  if [ "$children_stopped" != true ] || [ "$ports_free" != true ]; then
    cleanup_rc=1
  fi
  order="$(IFS=,; printf '%s' "${SITL_STOP_ORDER[*]}")"
  /usr/bin/python3 -c '
import json, os, pathlib, sys, time
path = pathlib.Path(sys.argv[1])
payload = {
    "schema": "uvautoboat.sitl.evidence.v1",
    "captured_unix_ns": time.time_ns(),
    "cleanup_rc": int(sys.argv[2]),
    "children_stopped": sys.argv[3] == "true",
    "ports_free": sys.argv[4] == "true",
    "stop_order": [item for item in sys.argv[5].split(",") if item],
}
temporary = path.with_name("." + path.name + ".tmp")
with temporary.open("x", encoding="utf-8") as stream:
    json.dump(payload, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
    stream.write("\n")
    stream.flush()
    os.fsync(stream.fileno())
os.replace(temporary, path)
' "$RUN_DIR/control/teardown_runtime.json" "$cleanup_rc" \
    "$children_stopped" "$ports_free" "$order"
  [ "$children_stopped" = true ] && [ "$ports_free" = true ]
}

sitl_cleanup() {
  local incoming_rc=$? cleanup_rc=0 finalize_rc=0 final_rc
  [ "$CLEANING" -eq 0 ] || exit "$incoming_rc"
  CLEANING=1
  trap - EXIT ERR
  trap ':' INT TERM
  set +e
  if [ "$SUPERVISOR_STOP_TRIGGER" = none ]; then
    SUPERVISOR_STOP_TRIGGER=exit
    SUPERVISOR_STOP_SIGNAL=none
    SUPERVISOR_STOP_PHASE="$SUPERVISOR_PHASE"
    log "SITL_SUPERVISOR_STOP trigger=exit phase=$SUPERVISOR_STOP_PHASE incoming_status=$incoming_rc"
  fi
  set_supervisor_phase sitl-teardown
  sitl_register_untracked_children

  if [ "$SITL_CHILDREN_STARTED" -eq 1 ]; then
    sitl_cleanup_disarm_if_needed || cleanup_rc=1
    sitl_stop_named_child dashboard || cleanup_rc=1
    sitl_stop_named_child rosbridge || cleanup_rc=1
    sitl_write_teardown_request || cleanup_rc=1
    sitl_stop_named_child bridge || cleanup_rc=1
    if [ -n "${SITL_CHILD_INDEX[bridge]+present}" ]; then
      if ! sitl_wait_shutdown_frames; then
        log_error 'SITL_SHUTDOWN_FRAMES=FAIL expected=3'
        cleanup_rc=1
      fi
    fi
    sitl_stop_named_child evidence || cleanup_rc=1
    sitl_stop_named_child mavros || cleanup_rc=1
    sitl_stop_named_child mavproxy || cleanup_rc=1
    sitl_stop_named_child sitl || cleanup_rc=1
  fi
  sitl_write_teardown_runtime "$cleanup_rc" || cleanup_rc=1
  /usr/bin/python3 "$SITL_EVIDENCE" finalize --run-dir "$RUN_DIR" \
    --session-complete "$SITL_SESSION_COMPLETE" --cleanup-rc "$cleanup_rc" \
    || finalize_rc=$?

  final_rc="$incoming_rc"
  [ "$final_rc" -ne 0 ] || final_rc="$FINAL_RC"
  [ "$final_rc" -ne 0 ] || final_rc="$cleanup_rc"
  [ "$final_rc" -ne 0 ] || final_rc="$finalize_rc"
  [ -z "$RUN_DIR" ] || log "SITL_LOGS=$RUN_DIR"
  log "SITL_SUPERVISOR_EXIT status=$final_rc trigger=$SUPERVISOR_STOP_TRIGGER signal=$SUPERVISOR_STOP_SIGNAL stop_phase=$SUPERVISOR_STOP_PHASE failed_phase=$SUPERVISOR_FAILED_PHASE cleanup_rc=$cleanup_rc finalize_rc=$finalize_rc"
  exit "$final_rc"
}

sitl_on_interrupt() {
  record_stop_trigger INT
  STOP_REQUESTED=1
  if [ "$SITL_CHILDREN_STARTED" -eq 0 ]; then
    FINAL_RC=130
    exit 130
  fi
  [ "$FINAL_RC" -ne 0 ] || FINAL_RC=1
  log 'SITL_STOP_REQUESTED signal=INT verdict=FAIL orderly_teardown=pending'
  exit 1
}

sitl_on_term() {
  record_stop_trigger TERM
  STOP_REQUESTED=1
  FINAL_RC=143
  if [ "$SITL_CHILDREN_STARTED" -eq 0 ]; then
    exit 143
  fi
  log 'SITL_STOP_REQUESTED signal=TERM verdict=FAIL orderly_teardown=pending'
  exit 143
}

run_sitl_digital_twin() {
  local rc
  sitl_static_preflight
  sitl_init_supervisor_state
  trap sitl_cleanup EXIT
  trap sitl_on_interrupt INT
  trap sitl_on_term TERM
  sitl_write_parameter_file
  sitl_build_commands
  sitl_write_manifest
  export ROS_LOG_DIR="$RUN_DIR/logs/ros"
  mkdir -m 700 "$ROS_LOG_DIR"
  emit_marker_once SITL_PREFLIGHT \
    "SITL_PREFLIGHT=PASS domain=42 discovery=LOCALHOST localhost_only=1 run_dir=$RUN_DIR"

  set_supervisor_phase sitl-start
  sitl_start_child sitl "$RUN_DIR/logs/sitl.log" "${SITL_SITL_COMMAND[@]}"
  sitl_wait_until sitl-listener "$SITL_READY_TIMEOUT_SECONDS" \
    sitl_process_provenance_ready || exit 1
  emit_marker_once SITL_PROCESS \
    "SITL_PROCESS=READY frame=motorboat-skid instance=0 ports=5760,5762"

  set_supervisor_phase mavproxy-start
  sitl_start_child mavproxy "$RUN_DIR/logs/mavproxy.log" \
    "${SITL_MAVPROXY_COMMAND[@]}"
  sitl_wait_until mavproxy "$SITL_READY_TIMEOUT_SECONDS" sitl_mavproxy_ready || exit 1
  SITL_ENDPOINT_GUARD_ACTIVE=1
  emit_marker_once SITL_MAVPROXY \
    'SITL_MAVPROXY=READY master=tcp:127.0.0.1:5760 out=udp:127.0.0.1:14600 source=254.190 target=1.1 reconnect=false'

  set_supervisor_phase mavros-start
  sitl_start_child mavros "$RUN_DIR/logs/mavros.log" "${SITL_MAVROS_COMMAND[@]}"
  sitl_wait_until mavros-udp "$SITL_READY_TIMEOUT_SECONDS" \
    sitl_udp_loopback_listener_ready || exit 1
  if /usr/bin/python3 "$SITL_EVIDENCE" snapshot --run-dir "$RUN_DIR" \
      --timeout "$SITL_READY_TIMEOUT_SECONDS" \
      >"$RUN_DIR/logs/mavros_snapshot.log" 2>&1; then
    cat "$RUN_DIR/logs/mavros_snapshot.log"
  else
    rc=$?
    log_error "SITL_PHASE_FAIL phase=mavros-snapshot rc=$rc log=$RUN_DIR/logs/mavros_snapshot.log"
    exit "$rc"
  fi

  set_supervisor_phase bridge-start
  sitl_start_child bridge "$RUN_DIR/logs/bridge.log" "${SITL_BRIDGE_COMMAND[@]}"
  sitl_wait_until bridge-guard "$SITL_READY_TIMEOUT_SECONDS" \
    sitl_log_has_bridge_guard || exit 1
  sitl_parse_bridge_mapping
  emit_marker_once SITL_BRIDGE_GUARD \
    "SITL_BRIDGE_GUARD=PASS steering=RC$SITL_STEERING_RC throttle=RC$SITL_THROTTLE_RC left=SERVO$SITL_LEFT_SERVO right=SERVO$SITL_RIGHT_SERVO"

  set_supervisor_phase capture-start
  sitl_start_child evidence "$RUN_DIR/logs/evidence.log" \
    "${SITL_EVIDENCE_COMMAND[@]}"
  sitl_wait_until capture "$SITL_READY_TIMEOUT_SECONDS" sitl_capture_ready || exit 1
  sitl_wait_for_file startup-evidence "$RUN_DIR/evidence/startup.json" \
    "$SITL_READY_TIMEOUT_SECONDS" || exit 1
  emit_marker_once SITL_CAPTURE "SITL_CAPTURE=READY logs=$RUN_DIR/captures"

  set_supervisor_phase safety-off
  sitl_create_operator_gate safety-off
  sitl_wait_operator_action safety-off || exit 1
  sitl_wait_for_file ready-disarmed "$RUN_DIR/evidence/ready_disarmed.json" \
    "$SITL_READY_TIMEOUT_SECONDS" || exit 1
  emit_marker_once SITL_DISARMED_READY 'SITL_DISARMED_READY=PASS state=READY_DISARMED'

  set_supervisor_phase web-start
  sitl_start_child rosbridge "$RUN_DIR/logs/rosbridge.log" \
    "${SITL_ROSBRIDGE_COMMAND[@]}"
  sitl_start_child dashboard "$RUN_DIR/logs/dashboard.log" \
    "${SITL_DASHBOARD_COMMAND[@]}"
  sitl_wait_until web "$SITL_READY_TIMEOUT_SECONDS" sitl_web_ready || exit 1
  emit_marker_once SITL_WEB 'SITL_WEB=READY rosbridge=127.0.0.1:9090 dashboard=127.0.0.1:8002'
  printf '\nOpen this exact loopback URL in one browser tab:\n%s\n\n' "$SITL_BENCH_URL"
  printf 'After Connected appears, click Neutral Now once to emit the required disabled frame.\n'
  log "SITL_BROWSER_WAIT url=$SITL_BENCH_URL requirement=one-publisher-plus-disabled-frame"
  sitl_wait_for_file browser "$RUN_DIR/evidence/browser_ready.json" || exit 1
  emit_marker_once SITL_BROWSER 'SITL_BROWSER=READY publisher=1 disabled_frame=observed'
  emit_marker_once SITL_SESSION "SITL_SESSION=READY url=$SITL_BENCH_URL"

  set_supervisor_phase arm
  sitl_create_operator_gate arm
  sitl_wait_operator_action arm || exit 1
  sitl_wait_for_file arm-evidence "$RUN_DIR/evidence/arm.json" \
    "$SITL_READY_TIMEOUT_SECONDS" || exit 1

  set_supervisor_phase positive
  printf 'Browser phase: tick the bench-condition box, then hold Apply at steering +0.10 and throttle 0.08.\n'
  sitl_wait_for_file positive "$RUN_DIR/evidence/positive.json" || exit 1
  set_supervisor_phase release
  printf 'Browser phase: release Apply and leave both requested axes at zero.\n'
  sitl_wait_for_file release "$RUN_DIR/evidence/release.json" || exit 1
  set_supervisor_phase negative
  printf 'Browser phase: hold Apply at steering -0.04 and throttle 0.09.\n'
  sitl_wait_for_file negative "$RUN_DIR/evidence/negative.json" || exit 1
  set_supervisor_phase estop
  printf 'Browser phase: release Apply, then press EMERGENCY STOP once.\n'
  printf '  The E-Stop is in the Mission Control panel (btn-emergency-stop), or the\n'
  printf '  header/footer E-STOP badge. The FCU Bench panel has no E-Stop button.\n'
  sitl_wait_for_file estop "$RUN_DIR/evidence/estop.json" || exit 1

  set_supervisor_phase disarm
  sitl_create_operator_gate disarm
  sitl_wait_operator_action disarm || exit 1
  sitl_wait_for_file disarm-evidence "$RUN_DIR/evidence/disarm.json" \
    "$SITL_READY_TIMEOUT_SECONDS" || exit 1
  sitl_wait_for_file disarm-release-frames \
    "$RUN_DIR/control/disarm_release_frames.json" "$SITL_READY_TIMEOUT_SECONDS" \
    || exit 1
  SITL_SESSION_COMPLETE=1
  set_supervisor_phase acceptance-complete
  log 'SITL_ACCEPTANCE=COMPLETE teardown=pending'
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'usage: tools/live_dashboard_preflight.sh sitl\n' >&2
  exit 2
fi
