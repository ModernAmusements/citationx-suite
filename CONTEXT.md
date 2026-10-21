# FlyWithLua / Citation X Suite — session context

Last updated: 2026-10-21

## Session handoff — read this first

This session repaired the panel layout and un-quarantined KPCrew. Everything below passed
offline harnesses; **the one thing still outstanding is a single in-sim confirmation run.**

### What changed this session

| Area | Change |
| --- | --- |
| Mission generator | **Deleted** (script, test, progress file, quarantine copy) |
| Panel spacing | `row_h` 17→22, `status_row_h` 15→20, `sys_row_h` 15→19; panels widened |
| HUD | 3 new clickable rows: `CABIN OPS`, `QRH TRAINER`, `LANDING PERF` (13 total) |
| KPCrew | 8 missing `C750/*Definitions.lua` added; `metargen.lua` dataref bugs fixed |
| Tooling | 6 offline harnesses; `luajit` installed for correct Lua semantics |

### Verification status

```
syntax ........................ ok
runtime load (LuaJIT, shared) .. 52 bindings, 0 failures, 0 problems
dataref bindings .............. ok
kpcrew require graph (C750) ... 0 missing
mastersuite smoke ............. PASSED
hud toggles smoke ............. PASSED
panel geometry ................ PASSED (21 checks)
```

### The one open item

**No in-sim run has happened since these edits.** Reload Lua in X-Plane
(*FlyWithLua → Reload all Lua script files*), then check `Log.txt` for
`FlyWithLua Error:` and `Moved Bad Script`. Expected: neither appears, and
`All script files loaded successfully.` is the last loading line.

If something does appear, the harnesses below reproduce the load path offline —
add the failing script to `Scripts/` and run `luajit tests/probe_load_order.lua`.

## Current runtime state (2026-10-21, after the KPCrew repair)
- **Suite scripts (tracked):** `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`. All three load clean; no `FlyWithLua Error:` lines.
- **Mission Generator: deleted 2026-10-21** at the user's request, together with
  `tests/smoke_mission.lua`. The `MissionGen/*` commands, the briefing panel and the cruise
  time warp no longer exist. Do not resurrect it without being asked.
- **Third-party add-ons (untracked, now loading):** KPCrew 2.3 (`kpcrew23.lua`, `kppanels.lua`,
  `kpxbrief.lua`, `kpsoundmute.lua`, `kpredline.lua`; modules in `Modules/kpcrew*`),
  `LandingPerformance.lua` (landing scoring), `Sim_Rate.lua` (ground-speed compression).
  All five KPCrew scripts were in quarantine at the start of the session and now load.
- **Panel spacing** was widened on request (`row_h` 17 → 22, `status_row_h` 15 → 20,
  `sys_row_h` 15 → 19) because the text was too cramped.
- **Not installed:** karlvr Citation X patches, Saitek panel config (Xsaitekpanels absent),
  Long Flights Compression and Smart Time Accelerator (both login-gated).

## Environment
- X-Plane 12: `/Users/modernamusmenet/X-Plane 12` (macOS, arm64)
- FlyWithLua NG+ 2.8.16 (mac_x64)
- Active scripts in `Scripts/`: `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`, `LandingPerformance.lua`, `Sim_Rate.lua`, `kpcrew23.lua`,
  `kppanels.lua`, `kpxbrief.lua`, `kpredline.lua`, `kpsoundmute.lua`.
- Controller: Sony DUALSHOCK 4 (VID 054c:09cc), enumerated twice — USB and Bluetooth

## Work completed (2026-10-19)

### 1. FlyWithLua quarantine errors fixed
- `CitationX_CabinOps.lua`: `sim/cockpit2/engine/indicators/N1_ratio` → `N1_percent`
- `CitationX_FailureTrainer.lua`: `sim/cockpit2/engine/actuators/throttle_lever_ratio` → `throttle_ratio`
- Both scripts were being moved to `Scripts (Quarantine)` on load; now they stay loaded.

### 2. DS4 heading mapping (MasterSuite)
- Cause: the "stick heading knob" auto-detected any unassigned raw axis. L2/R2 are analog
  trigger axes that rest at an extreme and deflect fully when squeezed, so they were being
  latched as heading controls alongside the right stick.
- Fix: only spring-centered axes (rest within `stick_hdg_center_tol` of center) are eligible;
  triggers can never be picked. Detection is sticky: the right stick stays locked until the
  module is toggled or scripts reload.
- Extra: dead-slot watchdog (`stick_hdg_stale_hold_s`, default 6 s) vetoes an axis stuck at a
  hard extreme — protects against the USB interface going silent while Bluetooth stays live.
  Vetoed axes revive when their value returns to center.
- New config options in `CONFIG`: `stick_hdg_sticky`, `stick_hdg_exclude_axes`,
  `stick_hdg_center_tol`, `stick_hdg_stale_hold_s`.
- Log line when locked: `Citation X Suite: heading knob locked to raw axis N (right stick)`.

### 3. Mission generator (`CitationX_MissionGenerator.lua`)

> **ARCHIVED — this script no longer exists.** Sections 3, 5, 8, 9 and 11 below describe work
> done on the mission generator between 2026-10-19 and 2026-10-21. It was deleted at the user's
> request; see §11. They are kept only as history of what was tried.

- Bottom-center panel. Missions only generate on the ground (< 25 kt); the clock starts at
  wheels up.
- Story missions with briefing → accept/skip → flight → debrief pages. See the 2026-10-20
  section below for the story-mission redesign.
- Rules (2–4 random): speed ≤ 250 KT below 10K, bank ≤ 35°, g-load −0.3…+2.5, mach ≤ 0.87,
  touchdown ≥ −300 fpm, reserve fuel on landing.
- Four difficulties scale distance/clock/score. Streak, best score, completed count persist in
  `Scripts/CitationX_MissionProgress.txt`.
- Commands/macros: `MissionGen/generate`, `MissionGen/accept`, `MissionGen/skip`,
  `MissionGen/abort`, `MissionGen/lesson`, `MissionGen/toggle_panel`, `MissionGen/warp`,
  `MissionGen/warp_auto`, `MissionGen/load_fms`, `MissionGen/report`.

### 4. Panel anchoring fixed
- FlyWithLua's y-axis starts at the **bottom** (`draw_string` docs). CabinOps and FailureTrainer
  anchored panels at y=60 and extended downward, leaving them mostly off-screen. All three
  panels now anchor at the bottom offset and extend upward. Overlap-free on 2560×1440:
  Failure Trainer bottom-left, Mission Gen bottom-center, Cabin Ops bottom-right.

## Work completed (2026-10-20)

### 5. Mission Generator no longer quarantined
- Log: `The variable "mg_engfla0" wants to write a DataRef, that is already handled by another
  variable` → FlyWithLua moved the script to `Scripts (Quarantine)` on every load.
- Cause: both FailureTrainer (`ft_fail_engfla0`) and MissionGenerator (`mg_engfla0`) bound
  `sim/operation/failures/rel_engfla0` as **writable**. Only one writable handle is allowed.
- Fix: MissionGenerator reuses `ft_fail_engfla0` when the trainer is loaded and only binds its
  own ref when it is absent; all writes go through `mg_set_engfla()`.

### 6. MasterSuite draw callback crash fixed
- Log: `...CitationX_MasterSuite.lua:1281: bad argument #1 to 'abs' (number expected, got boolean)`.
- Cause: two different functions were both named `stick_axis_centered`; the later boolean
  predicate shadowed the numeric re-centering helper, so AXIS MONITOR called `math.abs()` on a
  boolean and the whole draw callback aborted every frame.
- Fix: boolean predicate renamed `stick_axis_is_centered`; the numeric helper keeps its name.

### 7. Input probe noise removed
- Every script load appended `=== LEARN MODE STOP ===` because FlyWithLua runs the macro's
  deactivate chunk on load. The file therefore looked like a session had run when it had not.
- `citationx_set_input_learn(false)` now logs/toasts only when a session was actually open.

### 8. Mission Generator: story missions redesign
- GENERATE now opens a **briefing page** (client, payload, story, flight plan, goals, rules)
  with ACCEPT / SKIP; aborting from briefing discards silently, aborting in flight fails.
- Missions are **multi-leg** (2–4 short legs, 12–48 NM each per difficulty) with generated
  fix names (`mg_fix_name` syllables); the last leg is always HOME. Legs are checked off in
  order within `fix_radius_nm` (home leg uses `home_radius_nm`).
- Seven archetypes drive the goals: `MG_ARCHETYPES` (charter/airtaxi/medevac/ferry/survey/
  testflight/reliability). `setup(m, diff)` returns the story lines and sets goals
  (touchdown limit, comfort-G extra rule, door-to-pad clock, fuel budget, altitude or mach
  targets, emergency). Extra story rules live in `m.extra_rules` and flow through the same
  violation engine via `m.rule_defs`.
- Altitude profile is evaluated against `m.max_alt_ft` (peak altitude during the flight),
  mach hold only counts while airborne.
- States: `MG_IDLE=0, MG_BRIEF=1, MG_ARMED=2, MG_ACTIVE=3, MG_DONE=4`.
- FLIGHT SCHOOL lessons (steep turns / pattern work / precision approach / climb & level) carry
  an instructor grade A-F: every rule bust or missed maneuver costs one letter, a clean ride
  pays +100. `MissionGen/lesson` forces a school briefing via `MG_CONFIG.force_archetype`.
- Story promises are always enforced: a mission that sets `m.touchdown_min` forces the
  touchdown rule; ferry forces the reserve rule. Don't assume the random rule draw covers them.

## Work completed (2026-10-21)

### 9. Mission Generator: airport-aware legs, time warp, FMS loading
- **Root cause of "it does nothing":** the generated legs were synthetic lat/lon points with
  invented names, checked within 2 NM. There was nothing to see on the map or enter in the
  FMS, so flying to the "right airport" never counted. The panel now uses XPLMNavigation
  (`XPLMFindNavAid` / `XPLMGetNavAidInfo`) to snap every leg to a **real airport** near the
  projected point and to identify the departure airport (`m.home_icao`, `m.home_name`).
  Synthetic fixes remain as a fallback when navdata is unavailable.
- Radii widened: `fix_radius_nm` 2 → 3, `home_radius_nm` 3 → 5.
- Bearing readouts are **magnetic** (true bearing minus `sim/flightmodel/position/
  magnetic_variation`), matching the HSI. Briefing and flight plan show `MAG`, the airport
  ICAOs and the airport names (UTF-8-safe truncation).
- **Time warp:** `sim/time/sim_speed` is written only while the script owns it. Auto mode
  engages `warp_cruise` (4x) in stable cruise (AGL ≥ 1500 ft, bank ≤ 15°, |VS| ≤ 1200 fpm)
  more than `warp_engage_nm` from the next fix, holds through the leg and drops to 1x within
  `warp_drop_nm`. `MissionGen/warp` cycles 1x/2x/4x/8x by hand; `MissionGen/warp_auto`
  returns to automatic; the panel has a TIME WARP button on the flight page. It never fights
  a speed set by the pilot or another script, and resets to 1x on finish/abort/new mission.
- **FMS loading:** `MissionGen/load_fms` (and a briefing-page button) clears the default FMS
  and writes every leg as a lat/lon entry via `XPLMSetFMSEntryLatLon`.
- The mission clock now tolerates accelerated sim time (`dt` clamp 2 → 10 s).
- New `MG_CONFIG` knobs: `home_airport_max_nm`, `leg_airport_snap_nm`, `leg_airport_min_nm`,
  `warp_enabled`, `warp_auto`, `warp_cruise`, `warp_max`, `warp_engage_nm`, `warp_drop_nm`,
  `warp_min_agl_ft`, `warp_max_bank_deg`, `warp_max_vs_fpm`.
- Smoke tests extended for airport snapping, magnetic bearings, FMS loading, auto/manual warp,
  warp drop near the fix, warp reset after completion and the no-navdata fallback.

### 10. Third-party add-ons installed (2026-10-21)
- **KPCrew 2.3-alpha11** (`prokopiu/kpcrew`): `Scripts/kpcrew23.lua` plus the optional
  `kppanels.lua`, `kpxbrief.lua`, `kpsoundmute.lua`, `kpredline.lua`; modules in
  `Modules/kpcrew` and `Modules/kpcrew_prefs` (including `SOP_C750.lua`). The 171-command
  `kphardware.lua` hardware profile was deliberately **not** installed (DS4 controller, no
  Honeycomb/Saitek hardware; the kpcrew README warns about the `create_command` limit).
- **SimRateMonitor** (`N1K340/SimRateMonitor`): `Scripts/Sim_Rate.lua`, ground-speed
  acceleration 1x/2x/4x via macros and `FlyWithLUA/SimRateBuddy/*` commands. Note: this is
  **ground-speed compression** (`sim/time/ground_speed_flt`), not sim-time acceleration.
- **Not installed:** `karlvr/x-plane-citation-x` (patches the aircraft's own xlua files and is
  built for Honeycomb/Saitek hardware), the Saitek panel configuration (the Xsaitekpanels
  plugin is not installed), *Long Flights Compression* (x-plane.org login required) and
  *Smart Time Accelerator* (x-plane.to login required).
- Validation done before install: every kpcrew `dataref` path exists in `DataRefs.txt`; all
  172 `laminar/CitX/...` refs in the C750 SOP exist in the aircraft's xlua scripts; no
  duplicate command names and no duplicate writable DataRefs with the suite. The add-ons are
  ignored by git and are **not** part of the citationx-suite repository.

### 11. Mission Generator disabled, then deleted (2026-10-21)
- First disabled behind `MG_CONFIG.enabled = false`, then **deleted outright** at the user's
  request together with `tests/smoke_mission.lua` and the stale quarantine copy.
- Nothing in the repo references `MissionGen` any more. The remaining suite is the HUD, the
  QRH trainer and the cabin-ops flow.

### 12. KPCrew 2.3 C750 scripts un-quarantined (2026-10-21)

`kpcrew23.lua`, `kppanels.lua` and `kpxbrief.lua` were all being moved to
`Scripts (Quarantine)` on every load with

```
FlyWithLua Error: CopyDataRefsToLua() failed, can't execute script file: .../kpcrew23.lua
```

**Root cause (proven, not guessed).** Every DFLT system module ends with

```lua
local def = require("kpcrew.systems." .. kc_acf_icao .. ".sysLightsDefinitions")
```

KPCrew 2.3-alpha11 ships `Modules/kpcrew/systems/C750/sys*.lua` but **never shipped the matching
`C750/*Definitions.lua` files**. Every C750 module requires the DFLT module first, and with
`kc_acf_icao == "C750"` that `require` resolved to a non-existent file. It aborted the whole
script chunk, which FlyWithLua reports as the misleading `CopyDataRefsToLua() failed` message.

Eight requires were unresolvable: `sysAice`, `sysAir`, `sysControls`, `sysElectric`,
`sysEngines`, `sysFuel`, `sysHydraulic`, `sysLights` — all `…Definitions`.

**This is not C750-specific.** Sweeping every aircraft with
`lua tests/check_kpcrew_modules.lua --all` shows the same gap on 28 of the 34 aircraft
directories: A306, A33L, A3TL, ADC3, B46X, B738, B742, B744, B748, B7x7, C172, E1FF, E1XX,
E55P, EPIC, ER1X, EVIC, MD82, MD88, PC12, SF34, SF50, TMPL and more, each missing 8. Only five
directories ship `*Definitions.lua` at all (B737, C510, C750, DFLT, DHC8). KPCrew 2.3-alpha11 is
incomplete upstream; only the C750 path was repaired here because that is the aircraft this
install flies.

**Fix.** Added the eight missing `Modules/kpcrew/systems/C750/<sys>Definitions.lua` files as thin
wrappers: `return require("kpcrew.systems.DFLT.<sys>Definitions")`. That is correct because the
C750 system modules override every switch they care about immediately after loading the DFLT
module, and requiring the DFLT table also sets the `kc_has_*` / `kc_num_*` capability globals
that the DFLT module reads.

**Second defect, same file chain.** `Modules/kpcrew/metargen.lua` bound two `float[13]` arrays as
scalars:

```
dataref("temperatures_aloft_deg_c","sim/weather/aircraft/temperatures_aloft_deg_c","readonly")
dataref("dewpoint_deg_c",         "sim/weather/aircraft/dewpoint_deg_c",         "readonly")
```

FlyWithLua logged `should have an index. I set it to 0.` for both. They are now `dataref_table`
bindings, and the METAR builder reads element `[0]` into locals instead of writing the formatted
string back into the dataref. `sim/weather/visibility_reported_m` was marked **REPLACED** in
`DataRefs.txt`; it is no longer bound and the ceiling check uses the statute-mile ref.

**Verification.** Three offline harnesses were added so this is reproducible without launching
X-Plane:

- `tests/check_datarefs.lua` — parses `DataRefs.txt`, flags `dataref()` on a missing path or on
  an array without an index, and accepts the legal 4th-argument form.
- `tests/check_kpcrew_modules.lua` — walks the module tree, computes which DFLT
  system modules each aircraft actually inherits from disk, and reports modules that do not
  exist. For C750: 8 missing before the fix, 0 after. Takes an ICAO argument
  (`lua tests/check_kpcrew_modules.lua B738`) or `--all` to sweep every aircraft.
- `tests/probe_kpcrew.lua` — loads a KPCrew script against a mock FlyWithLua API and reports the
  exact `require`/line that aborted the chunk.
- `tests/probe_load_order.lua` — **the authoritative one.** Loads every script in `Scripts/` in
  FlyWithLua's alphabetical order in one shared LuaJIT state, exactly like X-Plane.

**Causation proven by A/B, not assumed.** Removing the eight `C750/*Definitions.lua` files and
re-running `probe_load_order.lua` reproduces the original failure verbatim:

```
FAIL  kpcrew23.lua   Modules/kpcrew/systems/DFLT/sysLights.lua:90:
                     module 'kpcrew.systems.C750.sysLightsDefinitions' not found
FAIL  kppanels.lua   Scripts/kppanels.lua:35:
                     loop or previous error loading module 'kpcrew.systems.C750.sysLights'
```

Restoring them yields `0 load failure(s), 0 binding problem(s)` across all 10 scripts.

**Why `kpxbrief.lua` failed too — it was a cascade, not its own bug.** `kpxbrief` never requires
`kpcrew.preferences.defaultPrefs`; it uses the globals `activePrefSet` and `activeBckVars` that
`kpcrew23.lua` creates. FlyWithLua loads `Scripts/` alphabetically, so `kpcrew23` normally runs
first and defines them. Once `kpcrew23` was quarantined, `kpxbrief` then died at line 1640 with
`attempt to index global 'activePrefSet' (a nil value)`. Fixing `kpcrew23` fixes `kpxbrief`
automatically. **Caveat:** `kpxbrief` still will not load on its own without `kpcrew23.lua`
present — that is upstream's design, and the `kpxbrief` test in isolation must not be used as a
pass/fail signal.

**Lua version matters for the harnesses.** FlyWithLua runs LuaJIT (Lua 5.1). The local `lua` is
5.5, which removed `module()` and makes loop variables const, so KPCrew modules abort under it
with errors like `attempt to call a nil value (global 'module')` and
`attempt to assign to const variable 'k'` — neither of which happens in-sim. `luajit` was
installed via Homebrew and is what `probe_load_order.lua` and the smoke tests should be run
with.

### 13. Panel spacing widened (2026-10-21)
- `CitationX_MasterSuite.lua`: `HUD_STYLE.row_h` 17 → 22, `status_row_h` 15 → 20,
  `sys_row_h` 15 → 19, plus matching header/group/pill/axis-monitor offsets.
- `CitationX_CabinOps.lua`: `CAB_CONFIG.row_h` 17 → 22, panel width 340 → 360, inner offsets
  retuned so nothing clips.
- `CitationX_FailureTrainer.lua`: `TRAINER_CONFIG.row_h` 17 → 22, panel width 430 → 460, same
  treatment.
- The rows are still anchored bottom-up, per FlyWithLua's bottom-left origin.

### 14. HUD toggles every control (2026-10-21)
- `SUITE_MODULES` grew from 10 to 13 rows: `cabin`, `qrh`, `landperf` were added so the three
  sibling scripts' panels are switchable from the HUD without leaving the cockpit.
- Each new row is nil-guarded (`type(CAB_CONFIG) == "table"`, `type(qrh_toggle_panel) ==
  "function"`, …), so a missing script shows `ABSENT` and clicking it is a no-op instead of a
  Lua error.
- `tests/smoke_hud_toggles.lua` asserts every row has `key`/`label`/`get`/`set`/`state`, that
  keys are unique, that `state()` returns a string plus a colour, that the sibling rows are safe
  with the other scripts absent, and that the draw callback runs.

### 15. Global `sim_time` collided with FlyWithLua's welcome script (2026-10-21)

The quarantine popup ("found bad lua scripts that have been quarantined look in Log dot text
file for more information") was real, and it was our fault:

```
FlyWithLua Error: The variable "sim_time" is still defined as DataRef "sim/time/total_running_time_sec".
FlyWithLua Info: 2nd Moved Bad Script to .../Scripts (Quarantine)/please read the manual.lua
```

`Scripts (Quarantine)/please read the manual.lua` is FlyWithLua's own bundled welcome script.
It declares `DataRef("sim_time", "sim/network/misc/network_time_sec")` — the same **global**
name the MasterSuite bound to `sim/time/total_running_time_sec` at line 230. The moment that
file is returned from quarantine (or on a fresh FlyWithLua install, where it ships in
`Scripts/`), FlyWithLua errors and quarantines it.

Fix: MasterSuite's global renamed to `citationx_sim_time` (dataref + 4 uses). No other script
bound a bare `sim_time`; `cab_sim_time` / `ft_sim_time` were already prefixed.
`tests/smoke_mastersuite.lua` drives time through `citationx_sim_time` now.

This is exactly AGENTS.md rule 5: an unprefixed global in a shared Lua state. Any new
FlyWithLua helper script that declares `sim_time` will collide again — keep the prefix.

### 16. Citation X mods: GTNXi replaced by AviTab-only (2026-10-21)

- The "Cessna Citation X GTNXi Retrofit Mod" (borisd) was installed per its README as
  `Aircraft/Cessna Citation X GTNXi`. It is **Windows-only** (TDS GTNXi plugin; the README
  says so) and its GTN screen stays dead on macOS, while both FMCs are inoperable. Removed
  (Trash) after the user chose the AviTab-only variant.
- `Aircraft/Cessna Citation X AviTab` was built from a copy of the stock aircraft plus the
  mod's AviTab layer only: `AviTab.json`, `objects/ipad/*`, `plugins/xlua/scripts/avitab_guard`
  and acf objects 25/26 (`xPad_arm.obj`, `Ipad.obj`, both hidden by `citationx/gtnxi/hide_avitab`).
  The GTN object (obja 27), `TDSGTN.ini`, the GTN bezel meshes and the 14 TDS manipulator blocks
  in `cockpit_panel_interactive.obj` were stripped; the two now-orphaned `vrconfig` blocks
  (`map_zoom`, `map_copilot_zoom`) were removed as well. X-Plane aborts vrconfig parsing
  ("minor problem parsing the VRCONFIG") when a `BEGIN_MANIP` has no matching object
  manipulator, so every remaining block was re-checked against the object (56/56 match).
  Those two FMC zoom knobs simply have no VR manipulator any more.
- `acf/_name` = `Cessna Citation X AviTab`, `acf/_ICAO` stays `C750` so the suite and KPCrew
  treat it like the stock aircraft. Stock `Cessna Citation X` untouched.
- **AviTab panel rect was wrong and is now fixed.** AviTab's panel coordinates live in a
  **1024×1024 space** (proved from AviTab's own sample: JSON 800×600 ↔ UV 0.781×0.586), but the
  mod shipped `left 1358, bottom 235, width 688, height 775` — 2048-texture pixels. At 1024 scale
  that rect starts at x=1358, i.e. outside the panel, so AviTab drew nothing on the iPad quad and
  the screen stayed blank. The iPad screen quad in `cockpit_panel_interactive.obj`
  (TRIS 57651/57657) maps to `679,208 → 344×206`, and `AviTab.json` now carries exactly that.
  `"enabled": true` makes AviTab call `enableAndPowerPanel()` itself, so `avitab/panel_enabled`
  is 1 and both the guard and `Ipad.obj`'s `ANIM_hide 0 0 avitab/panel_enabled` keep it visible.
- **The GTN monitor art was removed from the cockpit.** The mod's `Panel.png` was a 2048²
  replacement with the GTN screen painted in. It was swapped back to the stock 1024²
  `Panel.png` (normal map, LIT and DDS were already byte-identical to stock), so the centre
  console shows the normal Laminar FMCs again. UVs are normalised, so the AviTab quad and the
  1024-space rect still line up.

## 17. Session 2026-10-21 (evening): quarantine popup, Little Navmap, maps

- **The quarantine popup was two separate things.** FlyWithLua shows
  "found bad lua scripts that have been quarantined look in Log dot text file for more
  information" whenever `Scripts (Quarantine)/` is **non-empty at the end of a load** — it is not
  only a per-failure message. The folder had held FlyWithLua's own `please read the manual.lua`
  since Aug 13. It was moved to the Trash; the folder now has no `.lua` files and the popup is
  gone. The `sim_time` fix in §15 is what prevents it from being re-quarantined if it returns
  (e.g. after a FlyWithLua reinstall or "Return all quarantined Lua scripts").
- **Little Navmap 3.0.18** installed at `/Applications/Little Navmap.app` (x86_64 Qt build; runs
  under Rosetta 2, which is present). **Little Xpconnect 1.2.2** (universal arm64+x86_64) installed
  to `Resources/plugins/Little Xpconnect/`, quarantine flag cleared. Not yet connected in-sim.
- **AviTab maps:** `OpenStreetMap` re-enabled in `Resources/plugins/AviTab/online-maps/mapconfig.json`
  (it was explicitly disabled; OpenTopoMap was the only active one). The 333 MB Germany tile set
  was removed — it was the **512 px** variant nested under `512/latest/`, and AviTab's own
  `MapTiles/EPSG-3857/readme.txt` says 512 is unsupported. Correct source for Germany is
  openflightmaps.org → Downloads → ED → **merged / 256@2x / latest**, unpacked so the numbered
  zoom folders sit directly in `MapTiles/EPSG-3857/Germany/`. ChartFox is installed but not
  logged in (free account; gives real AIP plates). Navigraph folders exist but need a paid sub.
- **TDS GTNXi cannot be ported to macOS** (asked explicitly): closed-source commercial plugin
  wrapping Garmin's Windows-only trainer, no macOS build, and X-Plane 12 on Apple Silicon is a
  native arm64 process that cannot load Windows DLLs. The only routes are a Windows PC or the
  Windows X-Plane under CrossOver/Parallels.

### 18. Citation X EFB added (2026-10-21)

Requested as "the Zibo tablet for the Cessna". The Zibo EFB could not be reused (§17): it is
25,668 lines of aircraft-specific XLua bound to 776 `laminar/B738/...` datarefs plus the
`zibomod` plugin, and its licence forbids reuse. A native FlyWithLua EFB was written instead:

- **`Scripts/CitationX_EFB.lua`** (fourth suite script, prefix `EFB_CONFIG` / `EFB_STYLE` /
  `efb_*`), bottom-centre panel, 470 px wide, three pages:
  - **PERF** — gross weight, fuel, field alt/QNH, OAT/ISA, pressure + density altitude, wind
    (head/cross), V1/VR/V2/Vref, takeoff and landing distance, runway condition
    DRY/WET/CONTAM. Model: V1 = 104 + 16·f, VR = V1+5, V2 = V1+14, Vref = 112 + 10·f with
    f = (W−MLW)/(MTOW−MLW); distances scale with (W/ref)², +10 %/+7 % per 1000 ft density
    altitude, wind factor 1 − 0.015·headwind, condition multipliers. **Advisory only, not AFM.**
  - **CHECK** — 8 phases (before start → shutdown), 8 items each, click to check, per-phase
    progress and reset, next/previous phase.
  - **FUEL** — distance, cruise level, wind, taxi fuel; TAS/burn model vs level (420–470 KT,
    820–1320 kg/h), trip, 5 % contingency, 10 min alternate, 45 min reserve, block fuel and
    endurance from the current fuel load.
- 15 commands (`CitationXSuite/efb_*`) and 6 macros. HUD row 14 (`efb`) toggles the panel and
  shows `ABSENT` when the script is missing.
- Tests: new `tests/smoke_efb.lua` (panel, three pages, tab clicks, checklist counting, all
  clamps, condition cycling, hidden panel). `smoke_hud_toggles.lua` now covers 14 rows;
  `smoke_panel_geometry.lua` renders the EFB and checks it clears the QRH and cabin panels
  (40 checks total).
- Validation after the change: `62 dataref binding(s), 0 load failure(s), 0 binding problem(s)`,
  all smoke tests green.

## Not yet verified in-sim (as of 2026-10-21)

Everything below passed offline harnesses but has **never been seen in X-Plane**. Do not
record these as confirmed working:

- The **visual result** of the spacing change. Geometry is now *measured*, not assumed
  (`tests/smoke_panel_geometry.lua`: 21 checks — panels fit the screen, no vertical text
  collisions, no text overflowing its panel, click sweep reaches every row). What remains
  unproven is purely aesthetic: whether 22 px rows look right to the eye and whether the three
  panels still avoid each other on other resolutions.
- The HUD rows' live readouts (`ABSENT` / `ON` / `SHOWN`) as rendered text. Clickability and
  toggle wiring are proven by the click sweep.
- The KPCrew copilot, panels and briefings. Only the *loading* path was fixed; the KPCrew UI,
  the SOP checklists and the SimBrief import have had no functional test.
- The `metargen.lua` METAR fix (array weather refs → `dataref_table`, visibility in statute
  miles). Statically clean, but the METAR string it builds has not been read in flight.

- The **AviTab tablet** after the §16 `AviTab.json` rect fix and the stock `Panel.png` swap. The
  aircraft loaded cleanly before those edits; the tablet itself has not been looked at since.
- Little Navmap ↔ Little Xpconnect live connection (both installed, never run together).
- The **EFB** (§18): all pages pass the mock harness and the geometry sweep, but nothing has been
  clicked or read in X-Plane yet. In particular the advisory numbers have not been compared to
  the aircraft's real performance, and the checklist pages have not been used in a flight.

In-sim status: the suite loaded cleanly on 2026-10-21 at 18:22 (`LUA_RUN` 1–3,
`All script files loaded successfully`, 0 `FlyWithLua Error`). The only in-sim complaints were the
quarantine popup (caused by a stock FlyWithLua file, §17) and the blank AviTab screen (§16). The
visual result of the panel spacing and the HUD readouts still have not been reviewed by eye.

## Validation performed
- `luac -p` on every script in `Scripts/`, including the three KPCrew ones.
- Every `dataref(...)` declaration in `Scripts/CitationX_*.lua` checked with
  `tests/check_datarefs.lua`: 0 problems.
- Every `require()` reachable for the C750 checked with
  `tests/check_kpcrew_modules.lua C750`: 0 missing (`--all` sweeps every aircraft).
- Every `laminar/CitX/...` command and runtime dataref checked against the Citation X's own
  `plugins/xlua/scripts/*.lua`.
- Mock-FlyWithLua smoke tests, all run under **luajit** (the sim's Lua, see below):
  - `tests/smoke_mastersuite.lua` — DS4 heading: triggers ignored, sticky lock, dead-slot
    recovery.
  - `tests/smoke_hud_toggles.lua` — 13 rows well formed, unique keys, sibling toggles safe
    with the other scripts absent, draw callback clean.
  - `tests/smoke_panel_geometry.lua` — renders all three panels into a recording canvas and
    asserts: everything fits 2560×1440, no vertical text collisions, no text overflows its
    panel, the HUD and C750 panels do not overlap, and a click sweep reaches every row.
  - `tests/probe_load_order.lua` — loads all of `Scripts/` in one shared LuaJIT state in
    FlyWithLua's alphabetical order. The authoritative load test.

## Gotchas / facts
- A bad DataRef anywhere in a script makes FlyWithLua quarantine the whole file and reload Lua.
  Check `Log.txt` for `FlyWithLua Error:` and `Moved Bad Script`.
- FlyWithLua shows the "found bad lua scripts that have been quarantined" popup whenever
  `Scripts (Quarantine)/` is non-empty at the end of a load — even if nothing failed in that run.
  Keep the folder free of `.lua` files unless you actually want the popup.
- AviTab's `AviTab.json` panel rect is in a **1024×1024 panel space**, independent of the
  aircraft's `Panel.png` resolution. A 2048-pixel rect silently draws off-panel (blank tablet).
- "The DataRef ... is already handled in variable ..." log lines are informational, not errors.
- `laminar/CitX/...` commands/datarefs exist only at runtime via the aircraft's xlua plugin, so
  they do not appear in `Commands.txt` / `DataRefs.txt`.
- Flight recorder CSV is written to `~/Desktop/XPlane_CitationX_FlightLog.csv`.
- In zsh, `path` is a special array tied to `$PATH`; never use it as a loop variable.

## Repo, agent & deployment
- Git initialized in place in the FlyWithLua folder; `.gitignore` tracks only the four
  Citation X scripts, `tests/`, docs (`README.md`, `AGENTS.md`, `CONTEXT.md`) and the project
  agent. Plugin binaries, Modules, Internals, Documentation and runtime files stay untracked.
- Private remote: <https://github.com/ModernAmusements/citationx-suite>
- Project agent: `.opencode/agents/citationx.md` (mode `all`), rules in `AGENTS.md`.
- Test harnesses (all under `tests/`): `check_datarefs.lua`, `check_kpcrew_modules.lua`,
  `probe_kpcrew.lua`, `probe_kpcrew_run.lua`, `probe_load_order.lua`,
  `smoke_mastersuite.lua`, `smoke_hud_toggles.lua`, `smoke_panel_geometry.lua`.
- Deploy = edit live scripts in place, validate, commit and push; reload FlyWithLua in-sim.

## Tuning knobs
- Panel spacing: `HUD_STYLE` (`row_h`, `status_row_h`, `sys_row_h`) in
  `CitationX_MasterSuite.lua`; `CAB_CONFIG.row_h` in `CitationX_CabinOps.lua`;
  `TRAINER_CONFIG.row_h` in `CitationX_FailureTrainer.lua`.
- Heading knob: `CONFIG` in `CitationX_MasterSuite.lua`; `stick_hdg_axis` can be pinned to a
  RAW index shown by AXIS MONITOR, or slots vetoed via `stick_hdg_exclude_axes`.
