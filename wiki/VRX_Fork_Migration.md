# VRX Fork Migration

Migration guide for teammates who set up `~/seal_ws/src/vrx/` before 06/05/2026 — i.e., whose current VRX checkout points at the upstream `osrf/vrx` repo and runs `patch_vrx.sh` at every launch to apply the LiDAR-at-origin workaround.

The project moved to a fork (`Ghostzero00018/vrx`) on 06/05/2026 to bake the workaround into a real commit and to give the project a clean home for future inside-VRX modifications (mesh adds/removes, sensor-config tweaks, hydrodynamics tuning, etc.). See [Roadmap.md §8](Roadmap) for the full rationale + two-branch model + sync workflow.

This page covers only the migration: how to repoint your local checkout from upstream → fork.

---

## When you need this

Run the verification check first; it tells you if you need to migrate at all.

```bash
cd ~/seal_ws/src/vrx
git remote -v
```

| What you see | What it means |
|:--|:--|
| `origin → git@github.com:osrf/vrx.git` (or `https://github.com/osrf/vrx.git`) | **You need to migrate.** Pick Path A or Path B below. |
| `origin → git@github.com:Ghostzero00018/vrx.git` + `upstream → git@github.com:osrf/vrx.git` | Already migrated. Confirm branch is `autoboat/main` (`git branch --show-current`); if not, `git checkout autoboat/main`. |
| Anything else | Custom setup. Stop and ask before touching it. |

---

## Pre-migration checklist

- **Sim not running.** Stop any active launcher (`Ctrl+C` in the launcher terminal, or `pkill -9 gz && pkill -9 ros2 && pkill -9 rosbridge`). The migration touches source files; running processes shouldn't see them shift mid-flight.
- **Backup any custom uncommitted work in `~/seal_ws/src/vrx/`.** If you've done more than just letting `patch_vrx.sh` apply its sed substitution, `git stash` it first — Path A's `git checkout` would otherwise discard it. Most teammates have nothing custom here; only the runtime patch in `vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro`, which is fine to discard because the same change is committed on the fork's `autoboat/main`.
- **Workspace builds today.** If your current setup is broken before migration, fix that first — don't compound issues.

---

## Path A — Repoint existing checkout (~2 min, preserves git history)

```bash
cd ~/seal_ws/src/vrx
git status   # if you see uncommitted changes (typically wamv_gazebo.urdf.xacro modified by a previous patch_vrx.sh run), that's expected — we'll discard it below

# Swap the remotes
git remote rename origin upstream                            # current osrf/vrx remote → upstream
git remote add origin git@github.com:Ghostzero00018/vrx.git  # fork → origin
git fetch origin
git checkout autoboat/main                                    # the workspace-consumed branch
git remote set-head origin -a                                 # refresh origin/HEAD to autoboat/main

# If git status still shows wamv_gazebo.urdf.xacro modified, discard the runtime-patch state — the same change is now committed on autoboat/main:
git checkout -- vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro

# Rebuild — source content shifted from your local-build perspective, so artifacts may be stale
cd ~/seal_ws && colcon build --merge-install
```

---

## Path B — Fresh clone (~5 min including rebuild, clean slate)

Use this if Path A surfaces anything unexpected, or if you'd rather start clean.

```bash
# Backup the existing checkout
mv ~/seal_ws/src/vrx ~/seal_ws/src/vrx.OLD-$(date +%Y%m%d)

# Fresh clone of the fork's autoboat/main branch
cd ~/seal_ws/src
git clone --branch autoboat/main https://github.com/Ghostzero00018/vrx.git

# Add upstream remote for future syncing per Roadmap §8.7
cd vrx && git remote add upstream git@github.com:osrf/vrx.git

# Rebuild from scratch — fresh clone has no install/ artifacts for vrx packages
cd ~/seal_ws && colcon build --merge-install

# Once you've launched the sim and confirmed it works, delete the backup:
# rm -rf ~/seal_ws/src/vrx.OLD-*
```

---

## Verification (run after either path)

```bash
cd ~/seal_ws/src/vrx
git remote -v                  # expect: origin → Ghostzero00018/vrx, upstream → osrf/vrx
git branch --show-current      # expect: autoboat/main
git log --oneline -1           # expect: e384cd65 fix: enable publish_model_pose for LiDAR TF bridge (issue #876)
git symbolic-ref refs/remotes/origin/HEAD   # expect: refs/remotes/origin/autoboat/main
grep '<publish_model_pose>' vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro
# expect: <publish_model_pose>true</publish_model_pose>
```

Then launch the sim:

```bash
source ~/seal_ws/install/setup.bash
cd ~/seal_ws/src/uvautoboat
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
```

Watch the launcher output for **`[patch_vrx] OK: publish_model_pose already true`** — that's the signal the bake-in is being consumed correctly (the script's idempotency check sees the patch in source and short-circuits without re-applying). If you see `[patch_vrx] Applying publish_model_pose=true ...` instead, the bake-in isn't where it should be — re-check the verification commands above.

---

## Don't forget the `uvautoboat` side

While you're updating things, pull the latest project repo too — today's 06/05 commit batch includes the VRX install-doc updates, Roadmap §8 rewrite, and Board.md fork-landing entry:

```bash
cd ~/seal_ws/src/uvautoboat
git pull origin main
```

Nothing in this batch breaks anything; it's just docs + the Wed diary. Safe to pull at any time.

---

## After migration: maintenance pointers

- **Going forward:** plain `git pull` from `~/seal_ws/src/vrx/` pulls from the fork's `autoboat/main`. Same workflow as before, different source.
- **`patch_vrx.sh` still runs at every launch** — that's intentional. Post-migration it short-circuits cleanly because the source already has the change. It stays as a no-op safety net for ≥2 release cycles per [Roadmap §8.6](Roadmap).
- **Upstream sync workflow** (when `osrf/vrx jazzy` ships new commits worth pulling): see [Roadmap §8.7](Roadmap) for the two-branch sync recipe (`upstream/jazzy → fork/jazzy → fork/autoboat/main`).
- **Future inside-VRX modifications** (mesh adds/removes, sensor tweaks, etc.) land on `autoboat/main`. Coordinate with the maintainer — these are commits on the fork that affect everyone's workspace.
- **You don't need push access to the fork** for normal use. Cloning + pulling work without it. Push access is needed only if you're landing new bake-in commits or upstream-sync merges, which is the maintainer's job.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|:--|:--|:--|
| Path A: `git fetch origin` errors with "Permission denied (publickey)" | Your SSH key isn't authorized on the fork repo | Use HTTPS instead: `git remote set-url origin https://github.com/Ghostzero00018/vrx.git` |
| Verification: `git log` shows a different top commit | You ended up on `jazzy` instead of `autoboat/main` (both currently at the same HEAD, but they will diverge once the first inside-VRX mod lands) | `git checkout autoboat/main` |
| Verification: `grep` returns `<publish_model_pose>false</publish_model_pose>` | The bake-in isn't in your working tree — branch is wrong, or rebuild stale | Verify branch → `git checkout autoboat/main` → rebuild |
| Launcher: `[patch_vrx] Applying publish_model_pose=true ...` instead of "OK" | Working tree was reset to upstream-clean state somehow (manual `git checkout`, accidental reset) | Re-check `git status` — if file is missing the patch, `git checkout autoboat/main` should restore it; if branch is correct, the patch script will re-apply on next launch and self-correct |
| Launcher fails to find `vrx_gz` packages | colcon build wasn't run after migration | `cd ~/seal_ws && colcon build --merge-install` |
| `git pull` from `vrx` errors with "fatal: refusing to merge unrelated histories" | Likely you're on a branch other than `autoboat/main` and pulling from a different remote/branch combo | `git checkout autoboat/main && git pull origin autoboat/main` |

---

## See also

- [Roadmap.md §8](Roadmap) — full fork rationale, two-branch model, sync workflow, fresh-machine onboarding caveat
- [Installation_Guide.md](Installation_Guide) — install steps for fresh-machine setup (uses `git clone --branch autoboat/main` directly, skipping this migration page)
- `Board.md` 06/05/2026 entry — landing summary of the fork migration day
