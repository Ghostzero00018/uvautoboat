# Thursday 18/06/2026 - Block C attribution follow-up

## Purpose

Follow up the 17/06/2026 Block C mixed-topology observations with a narrower attribution check.

Default focus: capture the QGC vehicle / link / forwarding details that were still missing after the second Herelink-hotspot run, without starting upload, control, or implementation work.

## Starting context

- 17/06 Block C was approved and attempted twice.
- First run: clean local visual pull, but no mixed topology.
- Second run: Linux was on `IMT-Aquatic-drone`, real vehicle sysid `1` was visible and selected in Linux QGC, Herelink console QGC was running, and the bridge served one clean 9-item visual mission.
- The 11/06 count-only loops, triplicated counts, clear bursts, and QGC retry warnings did not reproduce.
- H1-H3 are weakened but not closed because bridge sysid attribution, QGC comm-link list, MAVLink forwarding state, and incoming `target_system` evidence were not captured.
- H4 has no evidence from 17/06: both runs had one mission activation and one coherent download.
- Same-session refresh remains separate from mixed-topology contention.
- After the 17/06 wrap, approved docs-sync cleanup landed in `a491b48` (docs only, no code/config/live-path change).

## Boundaries

- This is attribution / observation only.
- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, Pi upload, real-FCU command, or real-vehicle command path.
- If Linux QGC has real sysid `1` selected while the simulated route is visible, QGC Upload is specifically unsafe.
- QGC / Herelink / real-vehicle GUI steps are user-run by default; capture output and interpret it here.
- Code, launch, YAML, package, or bridge debug edits need separate explicit approval.
- Packet capture needing interactive sudo must be run by the user in a real terminal and pasted back.

## 18/06 actual scope pivot

- QGC mixed-topology attribution follow-up is deferred to next week. No QGC / Herelink / real-vehicle observation, no dashboard Generate -> Confirm, no QGC Upload, and no command/write path were run today.
- The missing Block C attribution evidence remains open: QGC vehicle attribution, comm-link list, MAVLink forwarding state, Herelink console mission visibility, and incoming `target_system` evidence still need to be captured before any future Generate -> Confirm if possible.
- Actual work shifted to dashboard hygiene and RealSense camera-feed preparation. The workstation `~/.bashrc` was updated locally to export `ROS_DOMAIN_ID=12` for new interactive shells; already-open shells still need `source ~/.bashrc`.
- Dashboard camera-topic hygiene was updated: syntactically invalid topics are still blocked, while valid topics outside the discovered image-topic list now warn but still try the MJPEG stream. This preserves the late-starting / restarted camera escape hatch and does not change mission, thruster, auth, TLS, or real-FCU behavior.
- User-run Pipeline A passed for dashboard-only branch behavior.
- User-run Pipeline B passed on the workstation with loopback-only services: `127.0.0.1:9090` for rosbridge, `127.0.0.1:8080` for `web_video_server`, and `127.0.0.1:8002` for the dashboard. The synthetic image topic `/camera/camera/color/image_raw` was visible and stable at about `30.305 Hz`; `web_video_server` handled requests for the default sim camera, the RealSense-style topic, and the valid-but-nonexistent warning-path topic.
- The first-time guide popup difference was explained as browser-origin storage: `http://localhost:8002` and `http://127.0.0.1:8002` have separate `localStorage`, so the tutorial flag is not shared between them. No dashboard code change is needed for that behavior.
- Local checks passed after the dashboard/doc edits: `node --check web_dashboard/autoboat/app.js`, `git diff --check`, conflict-marker grep, and the public-repo visibility sweep.

Next steps:

- Commit and push the dashboard camera-topic warning fix while still on internet WiFi.
- Resume QGC Block C attribution next week as observation-only work, with the original upload/control prohibitions still active.
- Treat the Pi / IoT RealSense acceptance run as a separate live-network check; if used, bind exposure deliberately and stop `rosbridge`, `web_video_server`, and the dashboard when finished.

## Block A - Repo and source refresh

- [ ] Run repo guard:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If the tree is dirty or refs diverge, stop and report before practical work.
- [ ] Re-read:
  - `working_diary/2026-06-17_wednesday_block_c_mixed_topology_observation.md`
  - `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md` Block B / Block C / Next steps
  - `Board.md` Phase 5.2+ QGC paragraph
  - `wiki/Roadmap.md` Phase 5.2+ QGC bullet

## Block B - Go / no-go

- [ ] Confirm equipment and network availability:
  - Linux workstation
  - QGC on Linux
  - Herelink console QGC
  - real vehicle visible in Linux QGC
  - dashboard / rosbridge stack, only if another Generate / Confirm is needed
- [ ] Confirm whether the goal is inventory-only or one more Generate / Confirm observation.
- [ ] Ask for explicit approval before any live QGC / Herelink observation.

Decision:

- [ ] Approved - proceed to Block C.
- [ ] Not approved / equipment unavailable - stop here and record deferral.

## Block C - Attribution capture

Record before any Generate / Confirm if possible:

- [ ] QGC vehicle list:
  - real vehicle sysid:
  - bridge sysid:
  - any duplicate / stale vehicle entries:
- [ ] Which vehicle QGC attributes the displayed mission to.
- [ ] Selected vehicle in Plan View before and after the route appears.
- [ ] QGC comm-link list:
  - local UDP `14550`
  - Herelink / real link
  - any extra UDP endpoints
- [ ] Network-side UDP view, e.g. `ss -unp | grep 14550`, to capture established QGC / real-vehicle paths that listener-only checks miss.
- [ ] QGC MAVLink forwarding state.
- [ ] Herelink console QGC running state and whether it displays the simulated route.
- [ ] Capture method for incoming `target_system` evidence:
  - UI / QGC logs only
  - user-run packet capture
  - bridge debug logging, only after explicit code approval

If a Generate / Confirm observation is explicitly approved:

- [ ] Start stack, Linux QGC, and bridge in separate terminals.
- [ ] Save logs under a new timestamped folder in `/home/ghostzero/Desktop/test_logs_folder/`.
- [ ] Use dashboard Generate -> Confirm only.
- [ ] Do not use QGC Upload or any control/write path.
- [ ] Copy `/tmp/autoboat_tab_*.log` into the run folder after observation.

## Block D - Interpretation

- [ ] Compare against 12/06 clean local-only A/B and 17/06 mixed-topology evidence.
- [ ] Classify H1 selected-vehicle mismatch as confirmed, weakened, or still unresolved.
- [ ] Classify H2/H3 wrong-target / multi-GCS interference as confirmed, weakened, or still unresolved.
- [ ] Classify H4 mid-transaction replacement only if a mission replacement happens during a live transaction.
- [ ] Keep Herelink console visibility separate from Linux-local bridge display.
- [ ] Do not claim Herelink acceptance, real-FCU upload, bidirectional sync, or upload/control validation.

## Block E - Optional QGC / dashboard sync design check

Start only if explicitly approved after the attribution capture.

- [ ] Re-read the 12/06 Block D v2 design before proposing any sync path.
- [ ] Check direct ways to keep waypoint data synced between QGC and the dashboard:
  - QGC upload transaction into the planner mission authority
  - dashboard-generated mission refresh back into connected QGC
  - manual redownload / reconnect fallback
  - opaque-id / mission-version refresh path where supported
- [ ] Keep water-quality data dashboard-only unless explicitly redesigned.
- [ ] Keep real-FCU upload and command/write paths separate from visual mission sync.
- [ ] No code/config edits and no live QGC upload unless separately approved.

## Block F - Optional follow-ups

- [ ] Known docs-cleanup carry-over is closed by `a491b48`; only start new docs cleanup if fresh stale docs are found and explicitly approved.
- [ ] Implementation only if explicitly approved, with upload transaction tests before any live QGC upload test.

## Wrap

- [ ] Record whether the missing attribution evidence was captured.
- [ ] Record exact evidence paths / terminal snippets used for any claim.
- [ ] Run wrap checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-18_thursday_block_c_attribution_followup.md
  ```

- [ ] Run the public-repo visibility sweep before any commit.
- [ ] Next steps are bounded to the actual outcome above.
