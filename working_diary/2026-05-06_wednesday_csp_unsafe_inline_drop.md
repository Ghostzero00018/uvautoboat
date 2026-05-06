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

**Outcome.** Thu scaffold ready at `working_diary/2026-05-07_thursday_first_field_test.md` (349 lines, vs 423 for Tue source). Stripped: entire `## Fallback queue progress` section (Tue PM commit-history narrative, including the post-A-slip subsection). Preserved with re-blanked placeholders: Block A-F Outcomes, Verification summary checkboxes, "Field-test confirmation timing" entry in Known unknowns. Updated: header date `2026-05-05` → `2026-05-07`, weekday Tuesday → Thursday, week-shape recap (Mon/Tue/Wed all history; Thu = today; Fri = V-E Day holiday); Block A re-cast as "AM confirmation re-check"; Block B "B4 — VRX HOLD periodic re-eval" condensed to a 2-line "weekly cadence covered by Wed Block A.5; skip unless trigger event fires today" note; Block F commit-message templates updated to 07/05; Verification summary date updated to 07/05; Next steps section restructured for Thu's POV (Active branch = today; Fri 08/05 = V-E Day; conditional on today's Block D outcome). Pre-commit `§1.6` grep clean. Followup correction surfaced by review pass: Thu L12 commit-count claim "ten commits total" was incorrect (Tue had 16 commits per `git log --since='2026-05-05 00:00' --until='2026-05-06 00:00'`); fixed to "16 commits total (10 work commits narrated below + 6 docs/scaffold meta-commits)".

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

**Outcome.** 0/4 triggers fired — HOLD stands. Trigger 1 (patch growth): not fired — 1 patch (`one_click_launch_all/patch_vrx.sh`), same as Tue baseline. Trigger 2 (custom worlds / sensors / WAM-V mods): not fired — 2 files in `test_environment/` (`sydney_regatta_DEFAULT.sdf`, `wamv_3d_lidar.xacro`), same as Tue baseline. Trigger 3 (Phase 5+ sim-side incompatibility): not fired — first wet test still pending Thu 07/05; passive trigger, fires only on field-test outcome. Trigger 4 (upstream-release flag since Mon-evening): not fired — no signal received; passive check (`gh` CLI not installed on workstation, network API blocked from this session env, falling back to "no signal received"). Next scheduled re-eval: Mon 11/05 AM (weekly cadence; Thu skipped per the Thu B4 carry-over note).

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

**Outcome.** 8 sites migrated; all `\.style\.color\s*=` + `\.style\.background\s*=` + `\.style\.animation\s*=` direct writes dropped to 0. Drift uncertainty (1) → `data-drift-level="high|mid|low"` attribute + `#drift-uncertainty[data-drift-level="..."]` CSS rules — chose data-attribute over CSS-variable-via-`setProperty` because pure DOM mutation isn't subject to `style-src` enforcement (more robust under tightened CSP). Warn span (2) → `.text-warn` via `classList.toggle('text-warn', !matches)` (also clears class on revert to canonical, cleaner than the original which only set color on mismatch). Status warn (3) → `.text-warn` (canonicalised `#f39c12` → `#ff9800`; visual diff <5%, resolved the Tue Known Unknown). Status ok (4) → `.text-ok` with explicit `remove('text-warn')` → `add('text-ok')` toggle pair. Grid-toggle btn (5+6) → single `classList.toggle('is-active', gridEnabled)` call replaces the bg+fg pair; **C1's grid-btn cssText folded into Block B** (since coupled to the bg/fg state) — width/height/border/cursor/font-size/line-height/padding moved to `.grid-toggle-btn` base class + `.grid-toggle-btn.is-active` modifier flips to active-state colors (`#fff`/`#333`), inactive defaults baked in (`#ddd`/`#999`); C1's planned 3 sites narrowed to 2. Emergency-flash start/clear (7+8) → `classList.add('is-flashing')` / `classList.remove('is-flashing')`. New CSS section appended at end of `style_merged.css`: `STATE / TEXT-COLOR CLASSES (CSP-prep, 06/05/2026)`, ~50 LOC. **Follow-up specificity fix surfaced by browser test:** `.is-flashing` (selector specificity 0,1,0) lost to the existing `.mission-btn.emergency` rule (0,2,0), which has its own `animation: emergency-btn-glow 2s ease-in-out infinite`; original inline `style.animation = ...` had implicit inline-style specificity that masked the conflict. Fix: bump `.is-flashing` selector to `.mission-btn.emergency.is-flashing` (0,3,0). Verified via browser computed-style: `emergency-flash | 0.5s | 6`.

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
| `app.js:1125`, `:3895` | `bar.style.width = percentage + '%'` (mission progress bar dynamic width) | CSS variable: `bar.style.setProperty('--progress',`${percentage}%`)` + CSS rule `.mission-progress-bar { width: var(--progress, 0%); }`. Same CSSOM caveat as `setProperty` in Block B — verify under `style-src 'self'` |
| `app.js:4365-4366` | `ta.style.position = 'fixed'; ta.style.opacity = '0'` (clipboard fallback textarea) | `.clipboard-fallback-textarea` class with `position: fixed; opacity: 0; left: -10000px;` (off-screen but still in DOM) |
| (other) | residual `.style.X = …` mutations remaining post-runtime-1 | Class-based or CSS variable migration; re-grep `\.style\.[a-zA-Z]+\s*=` at start of Wed to find any I missed |

**Pass criteria:** `node --check app.js` OK; all `\.style\.X\s*=` writes in `app.js` reduced to **0** (or whatever residual count is justified by CSSOM-via-setProperty paths); browser-test confirms toast appearance + animation, Leaflet waypoint markers (colours per state), grid-toggle button, mission progress bar fill, export-button header layout, clipboard-fallback flow all still work.

**Outcome.** All `cssText =` writes + generated `style="..."` strings dropped to 0; 17 misc `\.style\.X\s*=` direct writes dropped to 0 (with 2 justified residuals via CSSOM `setProperty('--bar-width', ...)` for thrust + mission progress bar dynamic widths, deemed acceptable per the pre-diary's "0 residual modulo setProperty paths" criterion). Browser test confirmed all paths behave normally.

- **C1 (cssText, 2 sites — grid-btn folded into Block B):** Toast container (3349) → `.toast-container` class. Toast item (3385) → `.toast` base + `.toast-info | -success | -warning | -error` modifier classes for bg + border-left-color, plus `.toast.toast--leaving` for slideOut. Removed dead switch statement that was computing `bgColor` / `borderColor`.
- **C2 (generated style strings, 4 sites):** Onboarding back-btn `style="visibility: hidden;"` → `.is-invisible` utility class (distinct from `.is-hidden` since it preserves layout flow). Onboarding flex-row → `.onboarding-flex-row`. Leaflet `L.divIcon` waypoint marker → `waypoint-marker waypoint-marker--{passed,target,pending}` className + inner `.waypoint-marker-dot` carries the visible styling (border + shadow + cursor + `box-sizing: border-box` so `iconSize` controls the visible footprint, not border-expanded). Popup span color → `.wp-status--{passed,target,pending}` modifiers. Popup `<hr style="margin: 4px 0; border-color: #ddd;">` → updated existing `.waypoint-tooltip hr` CSS rule (added margin + changed border-color from #eee to #ddd to preserve the original inline visual).
- **C3 (misc layout writes, 7 sites):** Thrust bar width + mission progress bar width (1136, 3843) → `bar.style.setProperty('--bar-width', X + '%')` + CSS `width: var(--bar-width, 0%)` on `.thrust-fill` and `.mission-progress-bar`. Export-button header layout (4274-4276) → `.panel-header-with-export` class (single `classList.add` replaces 3 inline writes). Clipboard fallback textarea (4313-4314) → `.clipboard-fallback-textarea` class with `position: fixed; top: 0; left: -10000px; opacity: 0` (added `top` + `left` for proper off-screen placement). Toast slideOut animation (3408 — extra residual not in pre-diary's 7 sites) → `classList.add('toast--leaving')` (handled in C1's CSS rule).

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

**Outcome.** PASS. Final CSP shape that landed:

```text
default-src 'self';
script-src 'self';                                          (no 'unsafe-inline')
style-src 'self';                                           (no 'unsafe-inline')
font-src 'self' data:;
img-src 'self' data: https://*.tile.openstreetmap.org
        http://localhost:8080 http://127.0.0.1:8080
        http://<host>:8080;                                  (per-request derived)
connect-src 'self' ws://localhost:9090 ws://127.0.0.1:9090
            ws://<host>:9090;                                (per-request derived)
frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none';
```

`<host>` derived per-request from HTTP `Host` header — see Block F audit-fixes section for context (Fix #1 was originally a startup-time `detect_host()`, replaced with per-request `parse_request_host()` after review pass surfaced LAN-network-shape edge cases). 4 curl tests against fabricated Host headers all passed: `Host: localhost:8002` → `ws://localhost:9090`; `Host: 10.1.163.158:8002` → `ws://10.1.163.158:9090`; `Host: boat-pi.local:8002` → `ws://boat-pi.local:9090`; `Host: evil; rm -rf /` → fallback to `ws://localhost:9090` (regex validation rejects malformed input). Browser test on Firefox/Chrome (workstation): all 11 interactive paths green after the Block B `.is-flashing` follow-up fix; **Leaflet's internal CSSOM `transform: translate3d(...)` writes NOT blocked under `style-src 'self'`** (the critical risk anticipated in Known Unknowns) — map pan/zoom + waypoint marker positioning all work normally; both `setProperty('--bar-width', ...)` calls also work (CSS-custom-property writes via CSSOM are accepted by Firefox + Chrome under tightened CSP, at least on their current versions). Zero CSP violations in DevTools console.

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

**Outcome.** DEFERRED — sim was not launched from this session. Browser test for Block D was driven via direct `serve_dashboard.py` + manual paths exercise, not via a full sim run. Pre-Thu sim health_check + fallback queue picks carry forward to Thu AM as part of Block B1 (sim sanity post-Wed-CSP-drop). No fallback work picked.

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

**Outcome.** Final commit stack today (06/05), **19 substantive commits in three phases + N diary/meta cleanup commits** (the day grew well beyond Block F closure with three successive scope expansions — Option B reverse-proxy doc polish, the late-afternoon VRX fork migration, and an evening newcomer/teammate onboarding-hardening pass; the diary/meta cleanups are this Block F update itself plus markdownlint or count-framing passes that landed after, which would otherwise force a recursive "diary count of count" update). User sequencing of the 19 substantive commits in three phases:

**Phase 1 — CSP arc + audit fixes (commits 1-7, the originally-planned Block F shape):**

1. `docs(diary): scaffold 07/05 Thu first field test (copy from Tue)` — Block A
2. `refactor(dashboard): runtime-2 color/state → classes (D-runtime-2)` — Block B portion (carries the original `.is-flashing` specificity bug — fixed in #3)
3. `refactor(dashboard): runtime-3 + .is-flashing fix (D-runtime-3)` — C1+C2+C3 combined plus the Block B follow-up specificity bump on `.is-flashing` (one-line CSS edit, folded in since it touches the same file as runtime-3 changes; bisect note in Block B outcome above)
4. `docs(diary): correct Tue 05/05 commit count (10 narrated → 16 total)` — Tue diary fix
5. `chore(vendor): add LICENSE_NOTICES for vendored CDN libs` — vendor compliance
6. `refactor(dashboard): drop CSP 'unsafe-inline' + per-request Host` — serve_dashboard.py + wiki/Dashboard_Security.md (browser-test-gated, gate passed)
7. `docs(diary): close 06/05 — CSP drop + Thu scaffold + audit fixes` — this diary (initial close)

**Phase 2 — Post-close scope expansions (commits 8-13):**

1. `docs(diary): note Wed per-request Host CSP in Thu scaffold` — small follow-up to the Thu scaffold (Wed-reference accuracy at L13/L25/L58/L62)
2. `refactor(diary): update mission progress bar dynamic width to use CSS variables` — your inline diary edit (1-line wording fix, intentional per system reminder)
3. `docs(security): polish Option B reverse-proxy + A→B triggers` — wiki/Dashboard_Security.md row L214 expanded from 1-line stub to depth-matched cell + L142/L143 cross-references + new A→B triggers paragraph (drafted via /ultraplan, applied locally after the remote session timed out)
4. `docs(vrx): swap install/clone URLs to Ghostzero00018/vrx fork` — VRX fork landed (`Ghostzero00018/vrx` with bake-in commit `e384cd65` on the fork's `jazzy` branch); 5 install/clone URLs swapped + 1 dual-link entry rewritten with both arrows
5. `docs(roadmap): VRX §8 rewrite (executed) + Board.md flip → ✅` — §8 narrative rewritten as executed-plan + new §8.6 Migration log + §8.7 Sync workflow; Board TBD `🔜` → ✅
6. `docs(roadmap): two-branch fork model (jazzy + autoboat/main)` — added `autoboat/main` branch on the fork as the workspace-consumed branch; §8.6/§8.7 + Board updated for the two-branch sync workflow

**Phase 3 — Newcomer / teammate onboarding hardening (commits 14-19, evening):** triggered by reviewer-flagged onboarding gap (fork's GitHub default branch was still `jazzy`, would land newcomers on the wrong branch after a plain `git clone`) and follow-up question about how to migrate two existing teammates still using upstream `osrf/vrx`.

14. `docs: Wed diary count framing fix + §8.7 fresh-machine note` — adopted reviewer's "13 substantive + N meta cleanup" framing at L233 + L254 to break the recursive-count update problem; added a §8.7 paragraph clarifying that fresh-machine onboarding requires `colcon build --merge-install` mandatorily (existing-workstation case is optional because `install/` already had the runtime-patched state).
15. `docs(install): pin VRX clones to fork's autoboat/main branch` — all 4 install snippets (`README.md:62`, `USER_MANUAL.md:357`, `wiki/Installation_Guide.md:51 + 55 + 94`; line numbers shifted +1/+2 with the inline comment + Note paragraph) re-pinned to `git clone --branch autoboat/main https://github.com/Ghostzero00018/vrx.git` to insulate the doc-followed install path from any future GitHub default-branch state. Closes the onboarding gap.
16. `docs: polish §8.6 + Board entry — note --branch pin + default flip` — Roadmap §8.6 + Board.md L301 updated with the --branch pin commit (`427f4b4`) + GitHub default-branch flip (`jazzy` → `autoboat/main`, web action by user) + local `origin/HEAD` refresh via `git remote set-head origin -a`. Fixes maintainer-history accuracy; the original §8.6 reference-surface line numbers were also stale post-pin.
17. `docs(wiki): add VRX_Fork_Migration page + xrefs from §8 + Install guide` — new ~150-line wiki page `wiki/VRX_Fork_Migration.md` with two migration paths (Path A in-place repoint, Path B fresh clone), pre-migration checklist, post-migration verification, 6-row troubleshooting table, "see also" cross-links. Cross-references added from `Roadmap.md §8` status banner ("Teammates with a pre-06/05/2026 VRX checkout — see VRX_Fork_Migration") and `Installation_Guide.md` Step 3 Note ("If you have an existing pre-06/05/2026 checkout — use VRX_Fork_Migration").
18. `docs: fork-aware troubleshooting + wiki HTTPS/pkill polish` — 5 doc surfaces reworded from "patch_vrx.sh fixes X" to "pre-fixed in source via fork bake-in commit `e384cd65`; patch_vrx.sh short-circuits with 'OK: ...'; if you see 'Applying ...', VRX checkout is stale → see VRX_Fork_Migration" (`README.md:225`, `USER_MANUAL.md:1362 + L1491`, `Board.md:216 + L335`). Wiki migration page polish: Path A switched SSH → HTTPS for consistency with Path B and lower friction (teammates may not have SSH keys configured); pkill chain in pre-migration checklist switched `&&` → `;` so each kill runs independently regardless of previous exit code.
19. `docs(wiki): scope SSH troubleshooting row to opt-in case` — re-scoped the "Permission denied (publickey)" row in `wiki/VRX_Fork_Migration.md` from a generic SSH issue to "Path A (SSH variant only)" with both fix paths (set up SSH key OR revert to HTTPS); the row was a leftover from when Path A defaulted to SSH (now HTTPS-default per commit `6485a0a`).

**Plus a process artefact (no commit):** drafted teammate-facing migration email in formal register, pointing at `wiki/VRX_Fork_Migration` page + `git pull origin main` for uvautoboat. Sent to the two team members still using upstream `osrf/vrx` per the fork-migration thread.

§1.6 invisibility sweep clean across all 19 substantive commits and the diary/meta cleanups that followed. Sim NOT left alive (wasn't launched from this session); Thu AM Block B1 needs fresh sim launch — the launcher will see the same effective sim source (fork's `autoboat/main` HEAD = old `jazzy` HEAD = upstream `7609d1bd` + bake-in `e384cd65`), just sourced from the fork instead of `osrf/vrx` upstream.

---

## Mid-session audit pass — pre-Block-D review

A review pass run between Block C completion and Block D's CSP drop surfaced 4 findings + 1 follow-up regression. All addressed before the live browser test.

| # | Finding | Fix |
|--:|:--|:--|
| 1 | CSP allowlist hardcoded `localhost`/`127.0.0.1` only — broke LAN access (`http://<workstation-IP>:8002` would fail because `app.js` uses `window.location.hostname` for rosbridge + camera URLs). Regression introduced by Tue's `50ae2af` CSP wrapper. | Refactored `serve_dashboard.py` to derive host **per-request** from the HTTP `Host` header via `parse_request_host()` — validated by regex (alphanumeric + dot + hyphen, length ≤253; falls back to `localhost` on bad input). Argv override available for explicit lock. Cleaner than the v1 fix (startup-time `detect_host()` UDP-routing trick) — handles all field-network shapes (LAN IP, mDNS hostnames like `boat-pi.local`, direct AP IP) without launcher changes. |
| 2 | `wiki/Dashboard_Security.md` stale across 9 sections after the CSP `'unsafe-inline'` drop + per-request Host changes (L60, L173-175, L182-191, L197-198, L200-201, L211, L217-222). | Refreshed (post-change doc audit pattern). Section heading "Proposed Content Security Policy (research, 05/05/2026)" → "Content Security Policy". Updated CSP code block to deployed shape. Updated directive table for `script-src` / `style-src` / `img-src` / `connect-src`. Updated Option A description for the per-request Host model. Rewrote "Tightening status" + "remaining hardening passes" (item 2 done, removed; only OSM-tile vendoring remains as Path B). Updated `app.js` line refs (354 / 518 / 1432). |
| 3 | `vendor/LICENSE_NOTICES` missing — `wiki/Roadmap.md:88` explicitly committed to adding it; vendored Leaflet (BSD-2) + roslibjs (BSD-3) + Roboto (Apache-2.0) had no notices file. Compliance gap, no runtime impact. | Added `web_dashboard/autoboat/vendor/LICENSE_NOTICES` (~295 lines) with verbatim upstream license texts + per-asset attribution + modification log. Apache 2.0 full text included for Roboto. |
| 4 | Tue 05/05 diary "ten commits" claim inaccurate at L213 + L252 + L356 — Tue's `git log` count is 16. The diary's narrative explicitly enumerates 10 work commits (3 + 3 + 4 in three batches); the 6 unnarrated are docs/scaffold meta-commits (`9b5e879`, `473c195`, `9cbddc9`, `4aa15e0`, `6244691`, `ff7d55c`). | User authorised override of §1.3 frozen-diary rule for this factual correction. Updated all 3 sites to "16 commits total (10 work commits narrated + 6 docs/scaffold meta)". |

**Block B follow-up (surfaced by Block D's browser test):** `.is-flashing` CSS rule lost specificity battle to the existing `.mission-btn.emergency` rule (which has its own persistent `animation: emergency-btn-glow ...`). Original inline `style.animation = ...` had implicit inline-style specificity that masked the conflict. Fixed by bumping selector to `.mission-btn.emergency.is-flashing` (specificity 0,3,0 > the existing rule's 0,2,0). Verified via browser computed-style — `emergency-flash | 0.5s | 6`.

**Audit-pass meta:** 2 review rounds. Round 1 surfaced findings #1, #2, #3, #4 + flagged staging discipline (untracked + unstaged files between commits). Round 2 verified the v1 fixes + raised "residual field-access risk in CSP host detection" (auto-detect's no-route fallback to localhost wouldn't help LAN clients) → drove the v2 per-request fix. Round 3 confirmed all fixes hold. Browser test then surfaced the `.is-flashing` regression as the only remaining issue.

---

## Verification summary — 06/05 (check at end of day)

- [x] Block A: Thu scaffold copy-forward complete; placeholders re-blanked; dates updated
- [x] Block A.5: 0/4 VRX §8.2 triggers fired; HOLD stands; next re-eval Mon 11/05 AM
- [x] Block B: (D)-runtime-2 landed; `\.style\.color\s*=` + `\.style\.background\s*=` + `\.style\.animation\s*=` direct writes all = 0; `.is-flashing` specificity follow-up applied
- [x] Block C: (D)-runtime-3 landed; `\.style\.X\s*=` writes in `app.js` = 0 except 2 justified CSSOM `setProperty('--bar-width', ...)` paths; cssText + generated `style="..."` strings = 0
- [x] Block D: CSP `'unsafe-inline'` drop PASS; final CSP `script-src 'self'` + `style-src 'self'` + per-request `<host>` derivation in `img-src` / `connect-src`
- [skip] Block E: pre-Thu health_check + fallback queue deferred to Thu AM Block B1 (sim wasn't launched from this session)
- [x] Block F: diary filled; pre-commit sweep clean; Thu scaffold confirmed ready; mid-session audit pass folded in (4 fixes + 1 follow-up)

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
