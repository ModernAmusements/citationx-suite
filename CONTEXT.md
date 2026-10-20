# FlyWithLua / Citation X Suite — session context

Last updated: 2026-10-21

## Environment
- X-Plane 12: `/Users/modernamusmenet/X-Plane 12` (macOS, arm64)
- FlyWithLua NG+ 2.8.16 (mac_x64)
- Active scripts in `Scripts/`: `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`, `CitationX_MissionGenerator.lua`, `LandingPerformance.lua`;
  third-party add-ons `kpcrew23.lua` (+ optional kpcrew tools) and `Sim_Rate.lua` are also
  installed (see section 10).
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

## Validation performed
- `luac -p` on every active script.
- Every `dataref(...)` path checked against `Resources/plugins/DataRefs.txt`.
- Every `laminar/CitX/...` command and runtime dataref checked against the Citation X's own
  `plugins/xlua/scripts/*.lua`.
- Mock-FlyWithLua smoke tests (Lua 5.4): mission briefing/accept/skip, leg-by-leg progression,
  landing, scoring, persistence and both emergency paths; DS4 heading logic (triggers ignored,
  sticky lock, dead-slot recovery); FailureTrainer+MissionGenerator load order with a strict
  duplicate-writable-dataref check.
- Mission-generator tests also cover airport snapping and magnetic bearings (mocked
  XPLMNavigation), FMS loading, auto/manual time warp, warp drop near the fix, warp reset
  after completion and the no-navdata fallback.

## Gotchas / facts
- A bad DataRef anywhere in a script makes FlyWithLua quarantine the whole file and reload Lua.
  Check `Log.txt` for `FlyWithLua Error:` and `Moved Bad Script`.
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
- Test harnesses: `tests/smoke_mission.lua`, `tests/smoke_mastersuite.lua`.
- Deploy = edit live scripts in place, validate, commit and push; reload FlyWithLua in-sim.

## Tuning knobs
- Mission balance: `MG_CONFIG` at the top of `CitationX_MissionGenerator.lua`
  (`cruise_tas_kt`, `reserve_kg`, radii, `MG_DIFF_*` tables).
- Heading knob: `CONFIG` in `CitationX_MasterSuite.lua`; `stick_hdg_axis` can be pinned to a
  RAW index shown by AXIS MONITOR, or slots vetoed via `stick_hdg_exclude_axes`.
