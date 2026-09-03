# AutoBoat Wiki Documentation

This directory contains wiki pages for the AutoBoat GitHub Wiki at <https://github.com/Ghostzero00018/uvautoboat/wiki>.

---

## Wiki Pages (synced to GitHub Wiki)

The following pages are published to the wiki by `scripts/sync_wiki.sh`:

| Page | Description |
|:-----|:------------|
| **Home.md** | Wiki landing page with navigation |
| **Installation_Guide.md** | Complete setup instructions |
| **Quick_Start.md** | 5-minute getting started guide |
| **System_Overview.md** | Architecture and design philosophy |
| **Glossary.md** | Plain-language definitions of every technical term |
| **Design_Rationale.md** | Why each architecture / algorithm / parameter choice was made |
| **Digital_Twin_Architecture.md** | Standards positioning (ISO/IEC 30141:2024 + ISO 23247:2021) for the project's digital-twin framing; layer mapping for the aquatic-monitoring adaptation |
| **Roadmap.md** | Internship objectives, scope clarifications, Phase 5 prep, research extensions, open questions, sim-infrastructure VRX-fork scheme |
| **SASS.md** | Simple Anti-Stuck recovery system (active) |
| **3D_LIDAR_Processing.md** | LiDAR Perception system explained (VFH + threshold rationale) |
| **Pi5_Bringup_Smoke_Test.md** | Manual procedure to verify Pi 5 ↔ flight-controller serial link via MAVProxy + a `pymavlink` script, before `mavros2` enters the picture |
| **RealSense_Dashboard_Testing.md** | Camera-only procedure for showing the Pi 5 RealSense feed in the workstation dashboard, with loopback-only browser services and explicit non-goals |
| **YOLO_Dataset_Plan.md** | Object-detection dataset plan for Pi 5 RealSense frames, workstation GPU training, NCNN export, and Pi-side validation gates |
| **Hailo_HAT_Workstream.md** | Hailo AI HAT+ 13 TOPS / Hailo-8L accelerator branch: version and runtime pin sheet, proven runtime baseline, host-side decode contract, and next integration gates |
| **Real_FCU_Digital_Twin_Runbook.md** | Operator runbook for the real-FCU digital twin: Pi 5 + Cube Orange+ + Hailo-8L, one command per machine, start/stop order, evidence, verdict reading, ESC reference, advisory mode, Pi window, bundle governance |
| **Live_Hailo_MAVLink_Dashboard_Testing.md** | Older two-command view-only live procedure (`live_dashboard_preflight.sh` + `pi_live_hailo_mavlink_dashboard.sh`) and its acceptance records |
| **MP_QGC_Update_Procedures.md** | Host-local update workflow for Mission Planner (under Mono on Linux) + QGroundControl (AppImage), including the SkiaSharp/libdl fix re-apply step after MP updates |
| **VRX_Fork_Migration.md** | Repoint guide for teammates with a pre-06/05/2026 VRX checkout from `osrf/vrx` to the fork `Ghostzero00018/vrx` branch `autoboat/main` |
| **Common_Issues.md** | Troubleshooting guide |
| **Dashboard_Security.md** | Security assessment, vulnerabilities, and mitigation recommendations |
| **Node_Naming_Refactor_Plan.md** | Completed rename of OKO / SPUTNIK / BURAN → functional names (16/04/2026) |
| **README_WIKI.md** (this file) | Wiki-meta page — listing of synced pages + sync workflow + content sourcing |

### Repo-only files (NOT synced to wiki)

| File | Description | Why excluded |
|:-----|:------------|:-------------|
| **UPLOAD_INSTRUCTIONS.md** | Manual / git-based upload steps for the wiki repo | Explicitly removed by both `scripts/sync_wiki.sh` (`EXCLUDE_FILE`) and `.github/workflows/sync-wiki.yml` (`rm -f wiki-repo/UPLOAD_INSTRUCTIONS.md`) — repo-only meta documentation |

---

## Sync Workflow

Two equivalent paths sync `wiki/*.md` to the published wiki, both excluding only `UPLOAD_INSTRUCTIONS.md`:

- **Manual:** `scripts/sync_wiki.sh` — clones the wiki repo (or pulls if the clone already exists), copies `wiki/*.md`, removes `UPLOAD_INSTRUCTIONS.md`, and pushes.
- **Automatic:** `.github/workflows/sync-wiki.yml` — runs on every push to `main` that touches `wiki/**`; same copy + exclude logic via the GitHub Action runner.

To run the manual path:

```bash
# From uvautoboat repo root:
scripts/sync_wiki.sh                     # default commit message
scripts/sync_wiki.sh "Custom message"    # custom commit message
```

The script clones to `../uvautoboat.wiki/` (sibling of the main repo) on first run, pulls + rebases on subsequent runs, and skips the push if no diff resulted from the copy. Requires SSH access to `git@github.com`.

For manual upload steps (without the script), see **[UPLOAD_INSTRUCTIONS.md](UPLOAD_INSTRUCTIONS.md)**.

---

## Content Sources

Wiki content originates from the active code, the launch YAML, the dashboard, the working diary, and the repo-root [README.md](https://github.com/Ghostzero00018/uvautoboat/blob/main/README.md) and [USER_MANUAL.md](https://github.com/Ghostzero00018/uvautoboat/blob/main/USER_MANUAL.md). Page sourcing is per-page rather than from a fixed inventory of intermediate guides.

---

## Wiki Structure Philosophy

### What Stays in README

- Quick project overview
- Installation quickstart
- Basic usage (2-terminal setup)
- Links to wiki for details
- Project status and key features

### What Goes in Wiki

- Detailed explanations
- Architecture deep-dives
- Comprehensive tutorials
- Troubleshooting guides
- API documentation
- Development guidelines

---

## Maintaining the Wiki

### Adding New Pages

1. Create `.md` file in `wiki/` directory
2. Follow existing page format:
   - Title as H1
   - Navigation links at bottom
   - Code examples with syntax highlighting
   - Tables for structured data
3. Add to `Home.md` navigation
4. Upload using git method

### Updating Existing Pages

1. Edit `.md` file locally
2. Test markdown rendering
3. Upload changes:

   ```bash
   cd wiki-repo
   git add <modified-file>.md
   git commit -m "Update: description"
   git push origin master
   ```

### Adding Images

1. Add image to `images/` in main repo
2. Reference in wiki:

   ```markdown
   ![Alt](https://raw.githubusercontent.com/Ghostzero00018/uvautoboat/main/images/file.png)
   ```

---

## Contribution Guidelines

When contributing to the wiki:

1. **Clarity**: Write for users new to ROS 2 and autonomous systems
2. **Examples**: Include code examples and expected output
3. **Links**: Cross-reference related pages
4. **Structure**: Use consistent heading hierarchy
5. **Testing**: Verify commands work before documenting
6. **Images**: Add diagrams for complex concepts
7. **Tables**: Use tables for comparisons and parameters

---

## Questions?

- Check [UPLOAD_INSTRUCTIONS.md](UPLOAD_INSTRUCTIONS.md)
- See [GitHub Wiki Docs](https://docs.github.com/en/communities/documenting-your-project-with-wikis)
- Open an issue on the repository

---

**Last Updated**: 09/07/2026
**Maintained By**: AutoBoat Development Team
