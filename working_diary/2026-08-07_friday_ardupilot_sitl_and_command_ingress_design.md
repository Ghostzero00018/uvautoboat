# Friday 07/08/2026 - ArduPilot SITL and command-ingress design

> **Prepared as a pre-diary, moved unchanged in substance from the 06/08/2026
> pre-diary that was deferred because that day went to the internship report.
> Gate 0 and Blocks A, B and C have since run; the sections appended below
> record what happened and supersede parts of the plan.** Block D has not
> started. No FCU write, no arming, no motor or thrust command to real hardware,
> and no edit to `tools/pi_live_hailo_mavlink_dashboard.sh`.
> **Scope correction:** the blocks above were planned and executed
> workstation-only, and the day-close commit `6645b29` recorded the day as having
> no Pi work. After that commit the operator directed a view-only live run with
> the Pi and control box, and a set of view-only dashboard telemetry
> improvements. Both are recorded in the sections at the end of this file, which
> supersede the workstation-only statement for the day as a whole.

## Starting state

- Expected clean `main` with `HEAD == main == origin/main` and divergence
  `0/0`. **Certify before starting.** The expected parent is the commit that
  closed 06/08/2026; no hash is pinned here because this file was written
  before that commit existed. If `HEAD` is later than the 06/08 day-close
  revision, inspect every intervening commit first.
- Production pins unchanged since 04/08/2026:
  `tools/pi_live_hailo_mavlink_dashboard.sh` at `71,501` bytes /
  `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`, and
  `tools/live_dashboard_preflight.sh` at `28,647` bytes /
  `958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877`.
  Re-verify rather than assume.
- The batched MAVROS source view was exercised live on 05/08/2026 and is
  feasible at shipped defaults. The graph race recurred under it, so no fix is
  demonstrated. That workstream is parked; today does not touch it.
- ArduPilot SITL, `sim_vehicle.py` and workstation MAVProxy were **absent** as
  of 05/08/2026, and `~/ardupilot` did not exist. Nothing since then was
  expected to change that, but Block A re-checks it rather than assuming.
- **Host figures below are two days old and must be re-measured in Block A.**
  On 05/08/2026 the workstation `/` was at `94%` with `13 GB` free, and the
  machine was on `IoT IMT Nord Europe`, which carries the Pi ROS/SSH link and
  is not the campus internet path.

## Objective and non-goals

Open a **workstation-to-FCU thrust command path** in the only order that is
safe to open it: simulator first, real autopilot never today.

The agreed sequence is ArduPilot SITL on the workstation, then verification of
the simulator MAVLink graph, then the design of a small isolated command-ingress
bridge with explicit dead-man and safety checks. Helper integration is revisited
only after all three.

### Structural decision, binding

An outbound command path lives in a **separate bridge service or tool**, never as
an edit to `tools/pi_live_hailo_mavlink_dashboard.sh`. That helper is
deliberately view-only: `reject_command_services` (`:535`),
`reject_unexpected_command_subscribers` (`:902`) and `check_command_sentinel`
(defined at `:965`, referenced at `31` call sites) abort a live run when a
command service, unexpected command subscriber, or monitored command message
appears. Weakening a proven safety boundary to add a write path is not an
acceptable route.

The browser dashboard likewise stays view-only. Note the mechanism precisely:
`LIVE_MAVLINK_VIEW_ONLY` is **not an environment variable**. It is a source
constant, `const LIVE_MAVLINK_VIEW_ONLY = true;` at
`web_dashboard/autoboat/app.js:263`, guarded by a test that asserts that exact
source line (`web_dashboard/autoboat/test/mavlink_telemetry.test.js:234`). It
cannot be flipped at runtime, and changing it fails the suite. Do not describe
it as a toggle.

### Not in scope today

Real-FCU thrust, arming, mode change, parameter write, mission upload, any
serial or MAVLink write toward the control box, Pi-side work of any kind,
helper or supervisor edits, VRX or Gazebo runs, detector or dataset work, and
the parked graph-query workstream.

Real-boat thrust remains behind the standing powered-off, propellers-removed
wiring gate, plus `ARMING_REQUIRE=1` and the safety switch.

## Direction check before anything else

`tools/servo_command_bridge.py` runs the **opposite** direction: it reads
MAVLink `SERVO_OUTPUT_RAW` from an autopilot and publishes
`/wamv/thrusters/{left,right}/thrust` into the simulator. Today's path is
workstation into the autopilot. It is a different data flow, so treat that file
as reference and prior art, not as the thing being extended. It has never been
run against any autopilot, and its PWM defaults are stock-SITL `1100/1500/1900`
while the real boat's rail is `800/800/2200` - two opposite and silent hazards.

`tools/servo_command.cpp` remains an intentionally unbuilt, non-authoritative
reference.

## Scheduling note

This is the last working day of the week and the four blocks are not equally
sized. Block B is the long pole: a submodule clone plus a SITL build is the only
step whose duration is not under our control, and it sits behind a disk verdict
that may itself require a separate cleanup gate. Treat A and B as the day's
realistic target. C and D proceed only if B finishes with margin; carrying D
into next week is the expected outcome, not a failure, and is preferable to a
rushed contract.

## Block A - prerequisites, read-only

Certify the revision, then confirm the three things that decide whether the rest
of the day is possible at all:

1. **Disk.** Re-measure; do not reuse the 05/08 figure. An ArduPilot clone with
   submodules plus SITL build artifacts is multi-GB against a partition that was
   at `94%` two days ago. Measure the requirement before committing to it.
   Regenerable-data cleanup is a **separate user-run gate**, not part of this
   block, and historical run evidence is retained.
2. **Network.** The clone needs real internet. Confirm the current SSID rather
   than assuming; on 05/08 the workstation was on `IoT IMT Nord Europe`, which
   is the Pi link. Campus internet is `IMT Nord Europe 5G`. Decide and record
   which SSID the install runs on, and note that switching drops the Pi link for
   the duration - acceptable today because no Pi work is planned.
3. **Existing surfaces.** Read `tools/servo_command_bridge.py` and
   `tools/servo_command.cpp` before proposing anything new.

Block A starts no service, installs nothing, and changes no file.

## Block B - ArduPilot SITL install, workstation only

Explicit approval required, and only after Block A shows disk and network are
adequate.

Install and build ArduPilot SITL on the **workstation**. Not on the Pi. The real
FCU already runs ArduRover `4.6.3`, so no firmware work is implied or permitted
today.

Vehicle target is Rover, matching the real boat's skid-steer configuration.

Record the exact clone source, revision, submodule state, build command, disk
consumed before and after, and any package the build pulled in. A package
installation is a user-run step; provide the command list and interpret the
output rather than running it.

Stop condition: `sim_vehicle.py` starts a Rover SITL instance and reaches a
steady state. Nothing beyond that in this block.

## Block C - simulator MAVLink graph verification

Explicit approval required, and only after a clean Block B.

Verify what the simulator actually exposes before designing against it:
the MAVLink endpoint and port, the heartbeat, the vehicle type and autopilot
identifiers, the servo output rail, and which messages the boat's skid-steer
configuration produces. Compare the observed PWM rail against both the stock
SITL `1100/1500/1900` and the real boat's `800/800/2200`, and record which one
this instance uses.

Any ROS-side work in this block must not use the Pi's live domain. That domain
is whatever the helper resolves at `:16`, `DOMAIN="${LIVE_ROS_DOMAIN_ID:-12}"`,
exported as `ROS_DOMAIN_ID` at `:1343` - so it is `12` unless
`LIVE_ROS_DOMAIN_ID` was overridden for the session. Check which value the last
live run actually used rather than assuming the default, then pick a different
domain explicitly and record it.

Read-only observation. No command is sent to the simulator in this block.

## Block D - command-ingress bridge, design only

Explicit approval required. **Design only - no implementation today.**

Define, before any code exists:

- exact payload, units and rail, and the mapping to servo or thrust output;
- recipient, transport, port, and rate/QoS;
- acknowledgement and timeout semantics;
- **dead-man behaviour**: what happens on loss of the command stream, and the
  neutral value it falls back to;
- arming interaction, and why the bridge cannot arm;
- failure semantics, and the fail-closed default;
- the explicit boundary that prevents this path from ever addressing the real
  FCU without a separate approved gate.

State the non-goals and the over-design traps avoided. Prefer the existing
contracts and a narrow interface over a new abstraction.

## Acceptance

- Block A produces a disk and network verdict and a read of both existing
  command-path surfaces.
- Block B either has SITL running on the workstation or records exactly why not.
- Block C records the simulator's real MAVLink surface and its PWM rail.
- Block D produces a written contract, not code.

A day that closes after A and B with C and D carried forward meets the week's
objective. A day that reaches D by rushing B does not.

## Non-claims to retain

- A working SITL says nothing about the real boat. The autopilot, the rail, the
  wiring and the safety interlocks all differ.
- No command has been sent to any autopilot, simulated or real.
- The Pi helper's view-only posture is unchanged, and its pins are unchanged.
- The graph-race workstream is parked, not closed: its lower DDS/RMW/network
  trigger is unidentified, browser-last ordering is unobtained, the
  `live_dashboard_20260724_175832` cumulative timing cause is open, and the
  terminal data-plane probe has never fired.
- Task 2 remains retired.

**Next steps:** after approval, certify, run Block A, and gate Block B on its
disk and network verdict.

## Gate 0 certification (07/08/2026)

`HEAD == main == origin/main == 032d6988841dd4e3e23e55105aac3667d99d01a8`,
subject `docs(diary): write the 06/08 report-work record and the 07/08 plan`,
divergence `0/0`, worktree and index clean.

Production pins re-verified rather than assumed:
`tools/pi_live_hailo_mavlink_dashboard.sh` at `71,501` bytes /
`31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`, and
`tools/live_dashboard_preflight.sh` at `28,647` bytes /
`958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877`.

The six source claims this plan depends on were re-read in the same turn as the
claim. All were exact: `DOMAIN="${LIVE_ROS_DOMAIN_ID:-12}"` at `:16` and its
export as `ROS_DOMAIN_ID` at `:1343`; `reject_command_services` at `:535`;
`reject_unexpected_command_subscribers` at `:902`; `check_command_sentinel`
defined at `:965` with `32` matching lines, so `31` call sites beyond the
definition; `const LIVE_MAVLINK_VIEW_ONLY = true;` at
`web_dashboard/autoboat/app.js:263`; and the literal assertion of that line at
`web_dashboard/autoboat/test/mavlink_telemetry.test.js:234`.

## Block A executed - prerequisites, read-only (07/08/2026)

### Disk

Re-measuring was necessary, and the stale figure was optimistic. `/` is a single
`ext4` partition `/dev/nvme0n1p4`, `203G` total.

| Point in time | Used | Free | Use |
| --- | ---: | ---: | ---: |
| 05/08/2026, carried into the plan | `182G` | `13G` | `94%` |
| 07/08/2026, first Block A measurement | `182G` | `11G` | `95%` |
| 07/08/2026, later the same session | `183G` | `9.4G` | `96%` |

Two days cost `2 GB`, and it fell a further `1.6 GB` during the session itself.
Inodes were never a constraint at `15%` used.

An unprivileged `du` measured `115G` against `df`'s `183G` used. The `68G` gap is
mostly `/var/lib/docker`, unreadable without privilege. `docker system df`
reports `34.84GB` of images with `160.5MB` reclaimable, while
`docker image inspect` reports `17173558507` bytes for the same image. Those two
figures disagree, so no single size is claimed here.

### Network

The active SSID was confirmed rather than assumed: `IoT IMT Nord Europe`, the
link that also carries the Pi, with a default route via `10.120.2.1`.

The plan treated that SSID as not being the campus internet path. That is true
of what it is, but it is not a statement about reachability, and reachability
turned out to be fine: DNS resolved `github.com` to `140.82.121.4`,
`https://github.com/` returned `HTTP 200` in `0.212322s`,
`https://codeload.github.com/` returned `HTTP 301` in `0.215977s`, and a bounded
transfer sustained `13444775` B/s over `201687040` bytes in `15.001s`.

**Decision recorded: the whole day ran on `IoT IMT Nord Europe`. No switch to
`IMT Nord Europe 5G` was needed and the Pi link stayed up throughout.** At that
rate the clone was never the long pole.

### Existing surfaces and toolchain

`git` `2.43.0`, `python3` `3.12.3`, `pip3`, `gcc`, `g++`, `make` and `ccache` all
present on Ubuntu `24.04.4 LTS`. `mavproxy.py`, `sim_vehicle.py` and
`~/ardupilot` were all absent, confirming the 05/08/2026 state unchanged.
`pymavlink` `2.4.49` was already present at
`~/.local/lib/python3.12/site-packages/pymavlink`.

Capacity: `16` cores against `14Gi` total RAM with `6.9Gi` available. Build
parallelism was capped at `-j4` on that headroom rather than run at full width.

`tools/servo_command_bridge.py` and `tools/servo_command.cpp` were both read
before anything was proposed. The direction check in the plan holds: the Python
file reads `SERVO_OUTPUT_RAW` out of an autopilot and publishes thrust into the
simulator, which is the mirror of today's target path. The C++ file additionally
announces itself as an armed `MAV_TYPE_SURFACE_BOAT`, the impersonation the
Python file deliberately rejects in favour of an onboard-controller identity
with `base_mode 0`.

### An unusable archive in `~/Downloads`

`ardupilot-Rover-4.6.3.tar.gz`, `201687660` bytes, passed `gzip -t` as a complete
valid archive. It is nonetheless unusable for a build: a tag archive carries
empty submodule directories. `modules/` holds `17` entries - the submodule
directory names and `COLCON_IGNORE` - with `.gitmodules` present but no
submodule contents, so `modules/waf` has nothing to run and `modules/mavlink`
cannot generate headers. It was classified as cleanup material, not a shortcut.

### Bounded Block A non-claims

- The ArduPilot footprint estimate of `5-8 GB` used before the clone was an
  estimate, not a measurement, and the real figure came in far below it.
- No cleanup, install or build happened in this block.

## Cleanup gate executed (07/08/2026)

A separate user-run gate, run because Block A closed with a disk blocker.
Reclaimed `12.6 GB`, taking `/` from `9.4G` free at `96%` to `22G` free at `89%`.

| Target | Reclaimed | Nature |
| --- | ---: | --- |
| `~/.gz/sim/log` | `5.6G` | `648` automatic simulator console logs, Nov 2025 to 05/08/2026 |
| `~/.npm/_cacache` | `3.3G` | package cache |
| `~/.cache/pip` | `3.0G` | wheel cache |
| `~/seal_ws/src/.vscode/browse.vc.db` | `1.3G` | editor symbol index, outside the git repository |
| `~/.cache/uv` | `1.2G` | orphaned - the `uv` command is not installed on this machine |
| `~/.cache/vscode-cpptools` | `636M` | editor C++ index |
| `~/Downloads/ardupilot-Rover-4.6.3.tar.gz` | `193M` | the unusable archive above |

Each target was inspected before deletion. The simulator logs were confirmed to
contain one `server_console.log` per timestamped run directory and nothing else.

Retained untouched and verified intact afterwards: the
`hailo8_ai_sw_suite_2026-07` image, `~/hailo_artifacts` at `9.5G`, `~/venvs` at
`7.0G`, `~/Desktop/pi_run_evidence`, and `~/.cache/QGCMapCache300`.

### Why the Hailo suite image was retained

Removing it was considered on the reasoning that the Pi already holds a working
model. The two are not interchangeable. The Pi holds the runtime and the
compiled `yolo26n_route_a_six_heads.hef`; the workstation image holds the
Dataflow Compiler that produced it, and `wiki/Hailo_HAT_Workstream.md:249`
records that this export is x86_64-only, so the Pi cannot host it. `Board.md:277`
still lists a retrain as the precondition for the next Hailo gate, and the only
route from a new checkpoint to the Pi runs through that image. The installer
archive `hailo8_ai_sw_suite_2026-07_docker.zip` is no longer on disk; only its
checksum survives in the wiki. Retained deliberately.

## Block B executed - ArduPilot SITL install (07/08/2026)

### B1 - clone

```bash
git clone --depth 1 --branch Rover-4.6.3 --single-branch \
  --recurse-submodules --shallow-submodules \
  https://github.com/ArduPilot/ardupilot.git ~/ardupilot
```

`1m01.882s`, `1.2G` on disk, `df` moving only `22G` to `21G` free. The shallow
strategy is what kept it to `1 GB` against a multi-GB full checkout.

`HEAD` is `3fc7011a7d3dc047cbb17d8bd98ee94577d144c6`, grafted and detached, with
all `14` top-level submodules plus nested ones checked out at pinned revisions -
including `modules/waf` at `35eadbb` and `modules/mavlink` at `bb87bc7` with
`modules/mavlink/pymavlink` at `8ba6707`.

The shallow-graft risk to version generation was tested rather than assumed:
`git rev-parse --is-shallow-repository` is `true` and the commit count is `1`,
yet `git describe --tags` resolves, because the tag sits on `HEAD`.

One naming detail worth recording so it is not misread later:
`git describe --tags --exact-match HEAD` returns **`Plane-4.6.3`**, not
`Rover-4.6.3`. Three vehicle tags - `Rover-4.6.3`, `Plane-4.6.3` and
`Tracker-4.6.3` - sit on the same release commit, whose subject is
`Plane: version to 4.6.3`, and `git` returns one of them. The checkout is
correct; only the generated label differs.

### B2 - read of the tree before proposing commands

`Tools/environment_install/install-prereqs-ubuntu.sh` is `504` lines and supports
`noble` explicitly. Four findings changed the install that was actually run.

- `maybe_prompt_user()` at `:248` begins `if $ASSUME_YES; then return 0`, so
  `-y` auto-answers **yes** to every prompt. Passing it would have installed the
  STM32 ARM toolchain into `/opt` and appended four lines across `~/.profile`
  and `~/.bashrc`. The install was run **without** `-y`.
- `sudo usermod -a -G dialout $USER` at `:262` is unconditional, with no prompt
  and no opt-out.
- `apt-get remove modemmanager` and `brltty` run if those packages are present.
  Neither was installed, so the prompt never appeared.
- On `noble` the script builds `~/venv-ardupilot` with `--system-site-packages`
  and installs into it, so PEP 668 is handled properly. Declining the
  make-default prompt means the venv must be activated by hand.

`wxpython` reaches the pip list on `noble` and has no wheel for this Python, so
it would have compiled from source. `SKIP_AP_GRAPHIC_ENV=1` removed it together
with `matplotlib`, `scipy`, `opencv-python` and the SFML packages. The cost is
MAVProxy's `--console` and `--map`, neither of which Block C needed.

Build path taken from source rather than memory: `BUILD.md:75` gives
`./waf configure --board sitl`, and `Rover/wscript` declares
`program_name='ardurover'` in `program_groups=['bin', 'rover']`.

`Tools/autotest/sim_vehicle.py --help` runs without the venv and lists
**`motorboat-skid`** among the Rover frames - the configuration matching the real
boat, so the observed servo rail would be representative rather than generic.

### Prerequisite install

```bash
SKIP_AP_EXT_ENV=1 SKIP_AP_GRAPHIC_ENV=1 SKIP_AP_COV_ENV=1 \
SKIP_AP_COMPLETION_ENV=1 SKIP_AP_GIT_CHECK=1 \
DO_AP_STM_ENV=0 DO_PYTHON_VENV_ENV=0 \
Tools/environment_install/install-prereqs-ubuntu.sh
```

Both PATH prompts answered `N`. Verified from the run output: no STM32
toolchain, no `~/.profile` or `~/.bashrc` write, no graphics stack, no submodule
re-fetch against the shallow tree, no package removal, and disk unchanged at
`21G`. The `dialout` group change ran as expected and needs a sign-out to take
effect; nothing today depended on it, since SITL is UDP and TCP only.

`~/venv-ardupilot` is `238M`. System `numpy` stayed at `1.26.4` in
`/usr/lib/python3/dist-packages`, while the venv carries `2.5.1` separately -
the pip conflict warnings during the run were about shadowing, not modification.
`MAVProxy` `1.8.74` installed into the venv; `pymavlink` resolves from
`~/.local` at `2.4.49` rather than from the venv.

### Build

```bash
source ~/venv-ardupilot/bin/activate
export PATH=/usr/lib/ccache:$PATH
ccache -M 2G
./waf configure --board sitl
./waf rover -j4
```

`'rover' finished successfully (2m51.885s)`, `1299/1299` targets, link and symbol
check clean. `build/sitl/bin/ardurover` is `4939888` bytes, text `3829969`, data
`175445`, bss `223136`. `configure` selected `/usr/lib/ccache/g++` and the venv
`python3`, confirming both the per-shell `PATH` and the venv took effect without
anything being persisted. `ccache` ended at `0.0 / 2.0 GB` against its `2 GB`
cap. Disk was unchanged at `21G` free, so the build cost under `1 GB`.

### SITL start

```bash
Tools/autotest/sim_vehicle.py -v Rover -f motorboat-skid -N --no-configure
```

A first attempt from a non-interactive shell reached `Waiting for heartbeat` and
then exited at the `MAV>` prompt on stdin EOF, tearing `ardurover` down with it.
That was a limitation of how it was launched, not of the build. Re-run from an
interactive terminal it reached steady state: `Detected vehicle 1:1 on link 0`,
`Mode INITIALISING` then `Mode MANUAL`, `AP: ArduRover V4.6.3 (3fc7011a)`,
barometer and INS calibration complete, `EKF3 IMU0`/`IMU1` initialised and
aligned, origin set, u-blox GPS detected, `AHRS: EKF3 active`, and
`Received 1283 parameters (ftp)`.

The autopilot self-identifies as ArduRover `4.6.3` with the git hash of the exact
commit cloned, and `4.6.3` is the firmware line the real controller runs. The
vehicle remained disarmed for the whole session.

### Two known noise sources, both diagnosed

- A `NumPy 1.x` / `NumPy 2.5.1` `ImportError` prints when MAVProxy starts. The
  venv carries `numpy` `2.5.1` while `matplotlib` resolves to
  `/usr/lib/python3/dist-packages`, compiled against the older line. It is
  caught: `mavproxy.py:48-52` wraps those imports in `try` / `except Exception`,
  and execution continues to `Connect tcp:127.0.0.1:5760` and beyond. It is a
  direct consequence of `SKIP_AP_GRAPHIC_ENV=1` leaving no `matplotlib` inside
  the venv. Cosmetic, and `pip install matplotlib` inside the venv would silence
  it if that is ever wanted.
- `paramftp: bad count 1283 should be 1273`. At
  `MAVProxy/modules/lib/param_ftp.py:96-98` a decode whose item count disagrees
  with the declared total is discarded and returns `None`. A later pass
  succeeded, `mav_param` was populated with `1283` entries and written to
  `mav.parm`, and no fallback to the slow per-parameter fetch occurred. The
  `10`-parameter discrepancy is **not explained**, so the bulk table is
  cross-checked against on-disk defaults below rather than trusted on its own.

### Bounded Block B non-claims

- A working SITL says nothing about the real boat. Autopilot instance, rail,
  wiring and interlocks all differ.
- The build was never run at `-j16`; the `-j4` cap was not compared against
  anything and no build-time conclusion is drawn from it.

## Block C executed - simulator MAVLink graph (07/08/2026)

Read-only. **No command and no parameter request was sent to the simulator.**
The values below come from `mav.parm`, which MAVProxy wrote to disk at startup,
and from the frame default files in the tree.

### MAVLink surface

| Endpoint | Purpose |
| --- | --- |
| `tcp:127.0.0.1:5760` | vehicle MAVLink master |
| `127.0.0.1:14550` UDP | MAVProxy rebroadcast output |
| `127.0.0.1:5501` | simulator interface |

`ardurover` additionally listened on TCP `5762` and `5763`. The invocation
loaded `Tools/autotest/default_params/rover.parm`, `motorboat.parm` and
`rover-skid.parm` in that order.

### Parameter reconciliation

Every value predicted from the on-disk defaults matched the live table. `TRIM`
is set by neither of the three default files and was the one value only the
running instance could supply.

| Parameter | Predicted from defaults | Live value |
| --- | --- | --- |
| `FRAME_CLASS` | `2` | `2` |
| `SERVO1_FUNCTION` | `73` | `73` |
| `SERVO3_FUNCTION` | `74` | `74` |
| `SERVO1_MIN` / `SERVO1_MAX` | `1000` / `2000` | `1000` / `2000` |
| `SERVO3_MIN` / `SERVO3_MAX` | `1000` / `2000` | `1000` / `2000` |
| `SERVO1_TRIM` / `SERVO3_TRIM` | not set anywhere | `1500` / `1500` |
| `SYSID_THISMAV` | - | `1` |
| `MOT_PWM_TYPE` | - | `0` |
| `ARMING_REQUIRE` | - | `1` |
| `SERVO1_REVERSED` / `SERVO3_REVERSED` | - | `0` / `0` |

Of `16` `SERVO*_FUNCTION` parameters, only `SERVO1` and `SERVO3` carry a
throttle function; the other `14` channels are unassigned.

`MOT_PWM_TYPE`, `ARMING_REQUIRE`, `SYSID_THISMAV` and both `REVERSED` flags match
the real boat's recorded values.

### The channel inversion

`libraries/SRV_Channel/SRV_Channel.h:117-118` defines `k_throttleLeft = 73` and
`k_throttleRight = 74`.

| | LEFT | RIGHT |
| --- | --- | --- |
| SITL, measured | `SERVO1_FUNCTION 73` | `SERVO3_FUNCTION 74` |
| Real boat, recorded | `SERVO3_FUNCTION 73` | `SERVO1_FUNCTION 74` |

The real-boat row is quoted from
`working_diary/2026-08-03_monday_ros2_graph_query_hardening.md:64` and
`working_diary/2026-07-24_friday_window_trim_and_dashboard_motor_command_prep.md:291`,
both re-read today rather than recalled.

Both platforms use the same function convention. **The channel numbers carrying
those functions are swapped.** Anything that addresses a thruster by channel
number is therefore correct on exactly one of the two. `servo_command_bridge.py`
defaults to `left_servo_channel 3` and `right_servo_channel 1`, which is right
for the boat and inverted against this simulator.

### The PWM rail, and why the difference is not merely numeric

| Source | min / trim / max | Neutral sits at |
| --- | --- | --- |
| SITL, measured | `1000` / `1500` / `2000` | middle - bidirectional, reverse available |
| Real boat, recorded | `800` / `800` / `2200` | bottom - unidirectional, no reverse |
| `servo_command_bridge.py` default | `1100` / `1500` / `1900` | middle |

Three rails, not two. The bridge's stated stock-SITL profile matches **neither**
platform, so that assumption in its docstring is now known to be wrong.

The more important point is topological rather than numeric. Stop is `1500` on
the simulator and `800` on the boat, where `1500` is roughly half throttle. A
bridge that emits the simulator's neutral at the real boat would **command
substantial thrust while believing it commanded zero.** `pwm_to_normalised()`
already branches on `pwm_neutral <= pwm_min` and handles both topologies
correctly, so the defect is confined to the defaults, not the logic.

### Bounded Block C non-claims

- No byte was sent to the simulator in this block, and the vehicle was never
  armed.
- The `1283`-entry parameter table carries the unexplained count discrepancy
  above. The values relied on here were each cross-checked against the on-disk
  default files; nothing was taken from the bulk table alone.
- `status` output was not captured. `Mode MANUAL` is evidenced from the startup
  log instead.
- Nothing here is a statement about the real boat's current parameter values;
  the real-boat column is quoted from earlier recorded readings, not re-measured
  today.

## Carried into next week

Block D was not started. It remains design-only, and today produced two
constraints it must satisfy:

- **Address thrusters by SERVO function (`73` left, `74` right), never by
  channel number.** The function is invariant across simulator and boat; the
  channel number is not.
- **Read the PWM rail from live parameters. Never hard-code one.** Three
  different rails are already in evidence, and the neutral-at-bottom versus
  neutral-at-middle distinction makes a wrong default actively dangerous rather
  than merely inaccurate.

Unchanged and still open: the graph-query workstream stays parked, not closed;
Task 2 stays retired; real-boat thrust stays behind the powered-off,
propellers-removed wiring gate plus `ARMING_REQUIRE=1` and the safety switch. The
Pi helper's view-only posture and both production pins are untouched, and no
file under `tools/` was modified today.

**Next steps:** Block D, the command-ingress contract, design only and gated on
explicit approval.

## Live view-only run executed after the day-close commit (07/08/2026)

This section is a forward correction. It records work carried out after commit
`6645b29`, which had recorded the day as having no Pi work. That statement was
true when written and is superseded here rather than rewritten.

The operator directed a **view-only** live run with the Pi and control box. No
command path was built, no FCU write was attempted, and the vehicle stayed
disarmed throughout.

### One aborted start, and its cause

A first workstation supervisor run (`live_dashboard_workstation_20260807_154342`)
was started and then stopped in `arrival` without a Pi stack, exiting
`status=0 trigger=signal signal=INT cleanup_rc=0` with `WORKSTATION_TEARDOWN=PASS`.

The Pi side had not started because the compound launch command was routed
through a chat transcript, where it wrapped and corrupted: the closing `)` of the
subshell landed on top of the `H` of `HAILO_LOCAL_WINDOW_MODE`, leaving
`exec env VAR=... VAR=...` with no command argument. `env` with no command prints
its environment and exits, so the helper never ran. The checksum verification,
`chmod +x`, and `PI_TEMP_START_MC=56750` before that point all succeeded.

**Method note:** a paste-sensitive multi-line command must be copied directly
from the terminal that printed it, or transferred as a checksum-pinned file and
invoked by a short single line. Re-transcribing it through an intermediate
surface is what failed here.

### The completed run

Workstation `live_dashboard_workstation_20260807_154942`, Pi
`live_dashboard_20260807_154959`, on `IoT IMT Nord Europe` with workstation IPv4
`10.120.2.168` and the Pi at `10.120.2.249`.

Gates reached in order: `WORKSTATION_RUNTIME_PREFLIGHT=PASS` with the helper pin
verified, `WORKSTATION_SERVICES=UP ports=8002,8080,9090`,
`PI_SOURCE_STACK_READY=PASS`, `HAILO_LOCAL_DISPLAY=ENABLED window_mode=fullscreen`,
six-topic arrival, and all six rate probes.

| Topic | N | Mean | Interval mean/std |
| --- | ---: | ---: | --- |
| `/hailo/overlay/image_raw` | `73` | `7.32 Hz` | `136.58`/`29.31` ms |
| `/mavros/state` | `10` | `1.00 Hz` | `998.25`/`19.66` ms |
| `/mavros/global_position/raw/fix` | `10` | `1.00 Hz` | `1001.72`/`25.34` ms |
| `/mavros/imu/data` | `10` | `1.00 Hz` | `996.54`/`24.66` ms |
| `/mavros/battery` | `10` | `1.01 Hz` | `993.98`/`32.21` ms |
| `/mavros/rc/in` | `10` | `1.00 Hz` | `1002.92`/`20.91` ms |

Source window and view-only posture:

```text
COMMAND_SENTINEL=PASS topics=5; safety monitor publishers=0
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=128s elapsed=248s peak=66C
PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C
```

The monitored window was not truncated. Final verification took `128 s` against
its `180 s` budget; with `115 s` on 04/08/2026 and `85 s` on 05/08/2026 these are
three single samples and support no timing conclusion. Run-wide thermal peak was
`67200` mC, `67.2 C`, against the `80 C` abort; the `66C` in the window marker is
the peak at window close, not the run maximum.

### The run did not close cleanly, and the cause is the shutdown order

`PI_SUPERVISOR_EXIT status=1 trigger=failure signal=none stop_phase=live-hold
failed_phase=live-hold cleanup_rc=0`, preceded by
`STOP: workstation rosbridge node is not visible from the Pi` after
`hold_elapsed=812s`.

The workstation was stopped first. `rosbridge.log` records
`[WARNING] [launch]: user interrupted with ctrl-c (SIGINT)` and all three
workstation service logs end at `16:12:22`-`16:12:27`, so rosbridge was
interrupted rather than lost. The Pi, still in its monitored hold, detected the
missing node and failed closed as designed.

Both teardowns passed with `cleanup_rc=0`, but a Pi that stops because rosbridge
disappeared is not a clean Pi-first operator stop. **No normal-lifecycle claim
comes out of this run.** The required order remains Ctrl+C in the Pi terminal,
wait for Pi `TEARDOWN=PASS`, then Ctrl+C on the workstation.

### Graph-query control data point

`MAVROS_SOURCE_PROBE_RUN` occurrences: `0`. The batched source view was off, so
this is a **flag-off control run**.

`10` non-verifying readings, recorded as `20` `MAVROS_SOURCE_EVIDENCE` lines in
verdict/raw pairs: `/mavros/imu/data` `5`, `/mavros/rc/in` `3`,
`/mavros/battery` `2`. Every one was `query_rc=0` with
`verdict=publisher count 0`, the publisher-count-zero mode also seen on
04/08/2026 rather than 05/08's identity-unknown mode. No reading reached
`attempt=3`.

Per-run flag-off control counts are now `11`, `3`, `2` and `10`. That widened
range reinforces the existing conclusion: the control variance exceeds any effect
a handful of enabled runs could resolve, and no reduction claim is available from
run counts.

### Evidence copied back

The Pi run directory was copied to
`~/Desktop/test_logs_folder/live_dashboard_20260807_154959` - `18` files plus
`mavproxy_home/`, including `supervisor.log`, `thermal_peak_mc.txt`, the five
MAVROS source YAML captures and `hailo.log`. The workstation run directory
remains at `~/Desktop/live_dashboard_workstation_20260807_154942` with its six
arrival samples and `w5_live_rates.log`.

## Dashboard telemetry improvements, view-only (07/08/2026)

Directed by the operator during the run. `web_dashboard/` is served as static
files and is not covered by the supervisor's helper pin, so these took effect on
a browser refresh without disturbing the running session.

| Field | Before | After |
| --- | --- | --- |
| GPS position | not displayed | `mavlink-gps-position`, latitude and longitude to `7` decimals |
| GPS accuracy | not displayed | `mavlink-gps-accuracy`, horizontal RMS from `position_covariance`, `N/A` when `position_covariance_type` is `0` |
| GPS fix | `Fix (0)` | `Fix (standard) (0)`, plus `Fix (SBAS)`, `Fix (GBAS)`, `No fix` |
| System status | bare integer | `Critical (5)` by `MAV_STATE` name, warning badge at `5`, critical badge at `>= 6` |

The system-status change is the substantive one. This vehicle reports
`system_status: 5`, which is `MAV_STATE_CRITICAL` and has been an open item in
earlier records; the panel had been rendering it as an uninformative integer.

`LIVE_MAVLINK_VIEW_ONLY` remains `true` at `web_dashboard/autoboat/app.js:263`
and no write path was added, enabled or implemented. Both new fields were added
to the topic clear/stale specification so they blank correctly on disconnect and
staleness, and to the DOM contract in the focused suite.

Verification: `31`/`31` across `camera_viewer`, `gps_fix`, `mavlink_telemetry`
and `view_only_feedback`. The `mavlink_telemetry` DOM-contract and diagnostic
tests were extended to cover the new fields and the renamed system-status output.
No file under `tools/` changed and both production pins are unchanged.

### Bounded non-claims for this section

- The live run proves telemetry delivery and view-only posture. It is **not** a
  normal-lifecycle acceptance, and browser-last ordering was not obtained.
- No command was sent to the FCU, and no command path exists to send one with.
- The dashboard changes are display-layer only and were not exercised against a
  fixed GPS; `mavlink-gps-accuracy` renders `N/A` whenever covariance type is
  unknown, which is the expected reading without a fix.

**Next steps:** Block D, the command-ingress contract, still design only and
still gated on explicit approval. A clean Pi-first lifecycle run remains
unobtained.
