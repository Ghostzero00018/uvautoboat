# 2026-05-06 — Wednesday: CSP `'unsafe-inline'` drop + Thursday scaffold handoff

## Context

Pre-scaffold drafted Tue 05/05 evening at the (D)-runtime-1 boundary close. Today's lead item is **completion of the CSP `'unsafe-inline'` removal arc** started yesterday afternoon — landing (D)-runtime-2 (color/state mutations) + (D)-runtime-3 (`cssText` blocks + Leaflet marker template + onboarding template + misc layout writes) + the final CSP drop. Plus a Block F wrap-up: copy yesterday's Tuesday-scaffolded field-test diary forward to Thursday's date with placeholders re-blanked (the field test slipped from Tue PM → Thu 07/05/2026 weather-driven, per Tue Block A Outcome).

**Week shape recap:**

- **Mon 04/05** — RTF investigation root-caused (`--use-nvidia` prime-offload, RTF 0.32 → 0.88); evening lint cleanup + dashboard XSS rewrite. Ten daytime + evening commits.
- **Tue 05/05 (yesterday)** — A=GO weather call slipped to Thu mid-day; AM landed Fallback #2 + #3 + Roadmap §1.3 path A vendoring; PM landed (C) + (D)-static + (D)-runtime-1 CSP-prep refactors + a Leaflet source-map cleanup; day closed with 05/05 diary wrap at HEAD `9b5e879`.
- **Wed 06/05 (today)** — finish the CSP unsafe-inline arc; copy Tue's scaffold forward to Thu; if time, P1 pier/bank stuck investigation or Roadmap §1.3 path B (offline tile server) prep.
- **Thu 07/05 (tomorrow)** — first field test (slipped from Tue), small artificial lake in a park, narrowed scope per Tue's AM refinement: D1 float + D2 tethered console teleop + propeller direction check only. D3-D5 + autonomy `/planning/emergency_stop` latching + full autonomy-stack network validation deferred.
- **Fri 08/05** — V-E Day public holiday, no work.
- **Pending all week:** formal joint supervisor presentation reschedule; three Asks to teammate maintainer (Phase A parameter subset, CA placement, validation methodology).

**Why today matters:**

The CSP `'unsafe-inline'` drop is the closing piece of the Tue-afternoon hardening arc. Without it, the dashboard's CSP still allows inline scripts and inline styles — the protection from `script-src 'self'` and `style-src 'self'` only takes effect once the inline surfaces are fully migrated and `'unsafe-inline'` removed. Today's work pays that final mile.

The Thursday scaffold copy-forward is a hard requirement before Thu AM — without it, Thu's diary opens blank and the operator has no ready-to-fill scaffold for the wet test. Cheap to do; do it first thing.

**Active blocks:**

1. **Block A — Thu scaffold copy-forward** (~10 min, AM): copy Tue diary to Thu file, re-blank `[To fill]` placeholders, update date references throughout.
2. **Block A.5 — VRX §8.2 trigger re-eval** (~5 min, AM): periodic HOLD-maintenance check matching Tue B4 pattern. Verify 0/4 triggers still hold; if any flipped, escalate per `wiki/Roadmap.md` §8.2.
3. **Block B — (D)-runtime-2: color/state mutations** (~30-45 min, AM): 5 `.style.color` writes + 3 misc state writes → state classes (`.text-warn`, `.text-ok`) + CSS variable for the dynamic drift-uncertainty color.
4. **Block C — (D)-runtime-3: cssText + generated styles + misc** (~1.5-2 h, AM-PM): 3 `.style.cssText` blocks + 5 generated `style="…"` template literals + ~10 misc layout writes → class-driven.
5. **Block D — CSP `'unsafe-inline'` drop** (~10 min + browser-test gate, PM): edit `serve_dashboard.py` CSP to drop `'unsafe-inline'` from `script-src` AND `style-src`. Browser-test gated.
6. **Block E — Pre-Thu sim sanity + fallback queue picks** (~30-60 min, PM, time-permitting): re-run health_check post-CSP-drop. If time, P1 pier/bank stuck investigation OR Roadmap §1.3 path B prep.
7. **Block F — Day wrap + Thu pre-deployment readiness** (~30 min, evening): final commits, push, diary close-out, confirm Thu scaffold ready, sim left alive.

**Fallback if Block B/C run into trouble:**

- If runtime-2 or runtime-3 hit a regression that takes long to diagnose: fallback runtime boundary is commit `2b2cc8f` (the (D)-runtime-1 commit); preserve later source-map fix `ed088df`, the 05/05 diary wrap `9b5e879`, and any Wed-AM scaffold copy-forward / diary commits as applicable; ship CSP `'unsafe-inline'` removal as a Thu+1 task. Thu field test isn't blocked by CSP drop — current state with `'unsafe-inline'` works fine for the field operator.
- If browser test for CSP drop fails (CSSOM writes blocked under `style-src 'self'`): fall back to keeping `'unsafe-inline'` for `style-src` only; document the failure shape; consider `'unsafe-hashes'` as an alternative for CSSOM compatibility.

**Note on line numbers:** All `app.js` line numbers below are **post-(D)-runtime-1 EOD-Tue**. Re-grep at Wed AM start to confirm current values — the runtime-1 helper insert at L36-46 plus collapsed if/else patterns may have shifted some sites. Use the `\.style\.[a-zA-Z]+\s*=` pattern to confirm + pick up any sites I may have missed.

---

## Block A — Thu scaffold copy-forward (~10 min, AM)

Mechanical task to set up Thu's diary scaffold from Tue's already-mature template (which has the Block A-F field-test structure + AM scope refinement + B3 deployment-bundle fill-in form + Known Unknowns).

```bash
cd ~/seal_ws/src/uvautoboat
cp working_diary/2026-05-05_tuesday_first_field_test.md \
   working_diary/2026-05-07_thursday_first_field_test.md
# Then edit the Thu file to:
# - Update header date: 2026-05-05 → 2026-05-07
# - Update day: Tuesday → Thursday
# - Re-blank [To fill] / [x] placeholders in Block A Outcome, B3 form items, Block C-F Outcomes, Verification summary
# - Update Week shape recap (Wed = today done; Thu = today)
# - Strip the "Fallback queue progress" section (Tue-specific PM work history; not relevant to Thu)
# - Re-anchor the AM scope refinement (D1 + D2 only) — already correct on Tue, just re-confirm
# - Strip the "post-A-slip PM commits" subsection (Tue-specific)
# - Update the "Active branch" subsection in Next Steps (Thu IS the active day; not "slipped to Thu")
```

**Pass criteria:** Thu diary file exists, has `[To fill]` placeholders re-blanked, dates updated, no Tue-specific narrative (Fallback queue progress + post-A-slip subsections removed), pre-commit grep clean.

**Outcome.** [To fill — confirmation that Thu scaffold is ready, what was stripped vs preserved.]

---

## Block A.5 — VRX §8.2 trigger re-eval (~5 min, AM)

Periodic HOLD-maintenance check matching Tue B4 pattern. Confirms whether any of the four §8.2 triggers from `wiki/Roadmap.md` §8 has fired since the last re-eval (Tue 05/05 AM, 0/4 fired). If still 0/4 → HOLD stands; if any flipped → escalate per §8.2 (re-open the fork-or-don't decision with the now-fresh evidence). Re-eval cadence: weekly during active development, or whenever a candidate trigger event happens (new patch, new custom world, sim-incompat surfaced, upstream release).

```bash
# Trigger 1 — patch count growth (Tue baseline: 1 patch — `one_click_launch_all/patch_vrx.sh`)
find . -maxdepth 3 \( -name 'patch_vrx*' -o -name '*.patch' \) -not -path './legacy/*' -not -path './.git/*' 2>/dev/null

# Trigger 2 — custom worlds / sensors / WAM-V mods (Tue baseline: 2 files in test_environment/)
ls test_environment/

# Trigger 3 — Phase 5+ sim-side incompatibility surfaced
# (passive — no automatic check; if Thu field test exposes a sim-incompat, that fires this)

# Trigger 4 — upstream-release flag since Mon-evening
# (passive — check `osrf/vrx` releases tab if internet available; OR `gh release list -R osrf/vrx --limit 5`)
```

**Pass criteria:** 0/4 triggers still fired → HOLD stands; record in Outcome below. If any trigger flipped, document which one + the evidence + the escalation path (re-open §8.2 fork-or-don't decision; do **not** auto-fork — the actual fork operation is a ~3-4 h dedicated task per Tue's evening estimate, not a Wed inline action).

**Outcome.** [To fill — trigger states (1=?, 2=?, 3=?, 4=?) + HOLD/escalate decision + brief evidence per trigger.]

---

## Block B — (D)-runtime-2: color/state mutations (~30-45 min, AM)

Continuation of yesterday's CSP-prep arc. 5 `.style.color` writes + 3 misc state writes → state classes / CSS variables.

**Sites (post-(D)-runtime-1 line numbers; re-grep at Wed AM):**

| # | Line | Pattern | Migration |
|--:|:--|:--|:--|
| 1 | `app.js:1374` | `driftUncertainty.style.color = uncColor` (string-driven, dynamic value) | CSS variable: `el.style.setProperty('--drift-uncertainty-color', uncColor)` + CSS rule `color: var(--drift-uncertainty-color, …)`. Note: `setProperty` is CSSOM, not inline `style=`; verify in Block D's browser test that this works under `style-src 'self'` |
| 2 | `app.js:1749` | `span.style.color = '#ff9800'` (constant) | `.text-warn` class — choose canonical orange between `#ff9800` and `#f39c12` (see Known Unknowns) |
| 3 | `app.js:3110` | `statusEl.style.color = '#f39c12'` (constant) | Same `.text-warn` (or two distinct classes if the colors are intentionally different) |
| 4 | `app.js:3149` | `statusEl.style.color = '#27ae60'` (constant) | `.text-ok` class |
| 5 | `app.js:496` | `btn.style.background = gridEnabled ? '#fff' : '#ddd'` | Paired with #6 (same condition). Use `.btn-grid-active` / `.btn-grid-inactive` pair, OR an `.is-active` toggle on the button |
| 6 | `app.js:497` | `btn.style.color = gridEnabled ? '#333' : '#999'` | Same pair as #5 |
| 7 | `app.js:2504` | `emergencyBtn.style.animation = 'emergency-flash 0.5s ease-in-out 6'` | `.is-flashing` class with the animation in CSS; class added on flash trigger |
| 8 | `app.js:2506` | `emergencyBtn.style.animation = ''` (clear) | `el.classList.remove('is-flashing')` |

**New CSS classes (~5):** `.text-warn`, `.text-ok`, `.btn-grid-active` / `.btn-grid-inactive`, `.is-flashing`. Plus `--drift-uncertainty-color` CSS variable for dynamic drift color. Append to `style_merged.css` under a new `/* ========== STATE / TEXT-COLOR CLASSES (D-runtime-2) ========== */` section.

**Pass criteria:** `node --check app.js` OK; `\.style\.color\s*=` writes count drops to 0 (verify via grep); `\.style\.background\s*=` + `\.style\.animation\s*=` writes also down to 0 (modulo runtime-3 scope); browser-test confirms drift-uncertainty color, status colors, grid-toggle button styling, emergency-flash animation all still work.

**Outcome.** [To fill — count of mutations migrated, any tricky cases, pre-existing color values reused vs new.]

---

## Block C — (D)-runtime-3: cssText + generated styles + misc (~1.5-2 h, AM-PM)

The biggest sub-batch. Three sub-areas — recommend committing as 3 separate sub-commits for narrower bisect surface if anything breaks.

### C1 — `.style.cssText = …` blocks (3 sites)

| Line | Element | Migration |
|:--|:--|:--|
| `app.js:492` | Map grid-toggle button initial style (width/height/background/border/cursor/font-size/line-height/padding) | `.map-grid-toggle-btn` class in CSS; remove the cssText assignment; let class style apply |
| `app.js:3345` | Toast container (positioning: fixed, z-index, etc.) | `.toast-container` class; check if existing `.toast-container` rule needs extending |
| `app.js:3381` | Individual toast item (background, border, padding, animation) with conditional values per type | `.toast` base + `.toast--info` / `.toast--warn` / `.toast--error` modifier classes |

### C2 — Generated `style="…"` in template literals (5 sites)

| Line | Template | Migration |
|:--|:--|:--|
| `app.js:234-235` | Onboarding tour back-button (`style="visibility: hidden;"` conditional) + flex container (`style="display: flex; gap: 8px;"`) | `.onboarding-back-btn` + conditional `.is-hidden` (use `setHidden()` helper if first-step) + `.onboarding-flex-row` for the wrapper |
| `app.js:2716` + `:2733-2734` | Leaflet `L.divIcon` waypoint marker (dynamic background-color + width/height + border + box-shadow + cursor) | `L.divIcon({ className: 'waypoint-marker waypoint-marker--${state}', iconSize: [size, size] })` + 3 state classes in CSS (`--passed` green, `--target` orange, `--pending` blue) |

### C3 — Misc layout writes (~10 sites)

| Lines | Pattern | Migration |
|:--|:--|:--|
| `app.js:4326-4328` | `header.style.display = 'flex'; header.style.justifyContent = 'space-between'; header.style.alignItems = 'center';` (export-button injection) | `.panel-header-with-export` class; single `header.classList.add(...)` |
| `app.js:1125`, `:3895` | `bar.style.width = percentage + '%'` (mission progress bar dynamic width) | CSS variable: `bar.style.setProperty('--progress', `${percentage}%`)` + CSS rule `.mission-progress-bar { width: var(--progress, 0%); }`. Same CSSOM caveat as `setProperty` in Block B — verify under `style-src 'self'` |
| `app.js:4365-4366` | `ta.style.position = 'fixed'; ta.style.opacity = '0'` (clipboard fallback textarea) | `.clipboard-fallback-textarea` class with `position: fixed; opacity: 0; left: -10000px;` (off-screen but still in DOM) |
| (other) | residual `.style.X = …` mutations remaining post-runtime-1 | Class-based or CSS variable migration; re-grep `\.style\.[a-zA-Z]+\s*=` at start of Wed to find any I missed |

**Pass criteria:** `node --check app.js` OK; all `\.style\.X\s*=` writes in `app.js` reduced to **0** (or whatever residual count is justified by CSSOM-via-setProperty paths); browser-test confirms toast appearance + animation, Leaflet waypoint markers (colours per state), grid-toggle button, mission progress bar fill, export-button header layout, clipboard-fallback flow all still work.

**Outcome.** [To fill — count migrated per sub-area; any residuals that couldn't be migrated; browser-test result.]

---

## Block D — CSP `'unsafe-inline'` drop (~10 min + browser-test gate, PM)

Final piece of the CSP-prep arc. Edit `web_dashboard/autoboat/serve_dashboard.py` CSP string:

```text
script-src 'self' 'unsafe-inline';     →  script-src 'self';
style-src  'self' 'unsafe-inline';     →  style-src  'self';
```

Browser-test gate (verify-not-assume — the user's earlier review insisted on this):

1. Restart launcher (or kill + restart dashboard tab) to pick up the new CSP header
2. Hard-refresh dashboard (`Ctrl+Shift+R`)
3. Watch DevTools → Console for any `Refused to apply inline style` / `Refused to execute inline script` / `Content Security Policy: ...` violations
4. Test all interactive paths in turn:
   - Visibility toggles (perception/controller, history, A* advanced, validation panel, mission progress)
   - Drift-uncertainty color update (wait for sim mission with anti-stuck activity)
   - Status colors (warn/ok)
   - Grid-toggle button (map panel)
   - Emergency-flash button animation (click E-Stop)
   - Toast notifications (warning + error)
   - Mission progress bar fill (run a sim mission)
   - Leaflet waypoint markers (generate + start mission)
   - Onboarding tour (if first visit; otherwise skip)
   - Clipboard fallback (copy something on a non-secure context)
5. If any CSP violation fires → revert the CSP edit; investigate which CSSOM API path triggered `style-src` enforcement; consider `'unsafe-hashes'` as a partial relaxation if needed

**Pass criteria:** dashboard fully functional with `script-src 'self'` + `style-src 'self'`; zero new CSP violations in console; all the above interactive paths behave identically to today.

**Outcome.** [To fill — pass/fail of browser test; if pass, the final CSP shape that landed; if fail, what triggered the violation and what alternative shape was used.]

---

## Block E — Pre-Thu sim sanity + fallback queue picks (~30-60 min, PM, time-permitting)

Once Block D lands cleanly, do a final sim health-check before Thu AM:

```bash
cd ~/seal_ws/src/uvautoboat
bash one_click_launch_all/health_check_autoboat.sh
# Expect 49/49 PASS at IDLE; or 46 + 3 TUNED if a mission was run during Block D test
```

If health check passes + time remains, pick from fallback queue:

- **P1 pier/bank stuck investigation** — diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A. Sim is still up. Interrupt-safe, naturally pauseable.
- **Roadmap §1.3 path B prep** — research MBTiles tile-server options (TileServer GL + pre-generated MBTiles for the test region). Not strictly blocking for Thu (the test site likely has internet via hotspot), but it's the next strategic-value pick before the Thu field test.
- **Mock water-quality sensor (Phase A)** — blocked on supervisor reply; skip if that's still pending.

**Outcome.** [To fill — health check result; fallback work picked + how far it got.]

---

## Block F — Day wrap + Thu pre-deployment readiness (~30 min, evening)

1. `git log --oneline -10` — sanity check today's commits.
2. Pre-commit grep — sweep for blocklist matches; expect 0.
3. Diary fill — populate all `[To fill]` placeholders in Block A-E Outcomes + Verification summary.
4. Working diary commit; subject template:
   - All CSP work landed cleanly: `refactor(dashboard): drop CSP 'unsafe-inline' (script-src + style-src)` — final commit name; or stage as series. (`refactor` matches the runtime-1/2/3 staging style; switch to `chore(security)` only if you want the tightening framed as a user-visible security feature.)
   - Partial CSP work (e.g., runtime-3 partial): `refactor(dashboard): runtime-3 partial; CSP drop deferred`
   - Diary close-out: `docs(diary): close 06/05 — CSP drop + Thu scaffold ready`
5. Confirm `working_diary/2026-05-07_thursday_first_field_test.md` exists with re-blanked placeholders + correct dates.
6. Sim left alive for Thu AM re-verification (no need to tear down).

**Outcome.** [To fill at end of day.]

---

## Verification summary — 06/05 (check at end of day)

- [ ] Block A: Thu scaffold copy-forward complete; placeholders re-blanked; dates updated
- [ ] Block A.5: VRX §8.2 trigger states recorded (1-4); HOLD/escalate decision logged
- [ ] Block B: (D)-runtime-2 landed; `\.style\.color\s*=` writes = 0
- [ ] Block C: (D)-runtime-3 landed; `\.style\.X\s*=` writes in `app.js` reduced to expected residual (only CSSOM `setProperty` calls if any)
- [ ] Block D: CSP `'unsafe-inline'` drop pass-or-fail recorded; final CSP shape committed in `serve_dashboard.py`
- [ ] Block E: pre-Thu health_check pass; fallback work picked (or skipped — note which)
- [ ] Block F: diary filled; pre-commit sweep clean across all today's commits; Thu scaffold confirmed ready

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Thu scaffold ready | None — purely setup; if skipped, Thu opens with no diary |
| Block A.5 | VRX trigger states recorded | None — purely periodic HOLD-maintenance |
| Block B | runtime-2 mutations migrated | Low — color/state writes are localized |
| Block C | runtime-3 mutations migrated | Medium — toast + Leaflet + onboarding are visible features; regressions easy to spot in browser test |
| Block D | CSP `'unsafe-inline'` drop pass | Hard requirement for the day's headline goal — if browser test fails, document the alternative shape and ship the partial improvement |
| Block E | Pre-Thu sim health verified | Low — opportunistic |
| Block F | Day closed; Thu scaffold ready | Hard requirement — Thu opens with the scaffold |

---

## Known unknowns to record during the day

- Exact match between `.text-warn` semantic and the two slightly-different orange values (`#ff9800` at `app.js:1749` vs `#f39c12` at `app.js:3110`) — choose canonical or two distinct classes.
- Whether browsers other than Firefox / Chrome behave identically under `style-src 'self'` (no `'unsafe-inline'`) for `.style.X = …` CSSOM writes. Production target is Firefox + Chrome on Linux (campus workstation); other browsers irrelevant for Thu.
- Whether the Leaflet `L.divIcon` className-only approach preserves visual fidelity vs the current dynamic-html-string approach. Background-color via state class should match exactly, but worth visual confirmation against today's behaviour.
- Whether toast animations behave identically as a class-based `.toast` + transitions vs the current `cssText` + `style.animation` write pattern.
- Whether the generated `style="…"` in onboarding tour template (`app.js:234-235`) interacts with the tour's step-transition logic in any way the simple class-replacement would miss. Onboarding tour is rarely-triggered (first-visit only); risk is low but visual-confirm at least the back-button visibility on Step 1.
- Whether CSSOM `setProperty('--var', value)` writes work cleanly under `style-src 'self'` — used by drift-uncertainty color in Block B and progress-bar width in Block C. If they fail, fall back to data-attributes + CSS attribute selectors (e.g., `[data-progress="42"] { width: 42%; }`) which is more verbose but pure-class.

---

## Next steps — Thu 07/05 + later

### Active branch: field test Thu 07/05/2026

Today's CSP work flips Thu's dashboard from "CSP allows inline / unsafe-inline" to "CSP `'self'`-only" (assuming Block D passes). Re-run Block B (B1 sim sanity + B2 rosbag dry-run + B3 bundle inventory) Thu AM as fresh pre-deployment check. Block C → D (D1 + D2 only per Tue's AM scope refinement) → E → F if Block C passes.

### Conditional on Thu 07/05 Block D outcome

Same shape as Tue's diary section (3 bullets — clean / aborted / deferred). See Tue's `2026-05-05_tuesday_first_field_test.md` Next Steps section + the Thu scaffold copy of same.

### Pending all week

- **Formal joint supervisor presentation** — rescheduled per 30/04; date pending IMT Mines Alès availability + power restoration.
- **Three Asks to teammate maintainer** — Phase A water-quality parameter subset; CA model compute placement (Linux vs Pi 5); validation methodology.
- **V-E Day Fri 08/05** — public holiday, no work.

### Deferred (carried over from 04/05 + 05/05)

- P1 pier/bank stuck investigation (diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A).
- Mock water-quality sensor implementation (Phase A) — blocked on supervisor reply.
- Roadmap §1.3 path B (offline tile server, pre-generated MBTiles for test area) — required before first IoT-network field deployment; path A landed 05/05.
- Dashboard CSP Option B (reverse-proxy header injection) and Option C (Caddy / external static webserver) — long-term, gated on auth landing.
- 24/04 housekeeping carry-overs: `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory.
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware double-reverse symptom.
- Real no-regression test for `launch/remap.launch.yaml` — needs first real-hardware bench (Thu's deployment may exercise this if the field stack uses the remap layer).
