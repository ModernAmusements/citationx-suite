# FlyWithLua / Citation X Suite — session context

Last updated: 2026-10-31

## Session handoff — read this first

**2026-10-30 — bindings fully native.** The pilot wants X-Plane's own keyboard/mouse mapping
back. The last Lua keystroke layer (`CONFIG.alt_keys_enabled`, which turned the mouse thumb
buttons `Ctrl+Shift+9` / `Ctrl+Shift+0` into ALT SEL steps) is **removed**: while the input
mapper is OFF the suite consumes no key at all, so every key binding belongs to X-Plane. The
only input the suite still reads is the heading bug on the DS4 **Axis 3** (right stick up/down,
raw axes 3/28, USB + Bluetooth). Realism pack, panels and the heading knob are untouched.

All X-Plane and Logi files touched on 2026-10-30 were reverted: the global
`X-Plane Joystick Settings.prf` and the active `PS4-CitationX - Joysticks.prf` match their
pre-session backups, the Logi X-Plane profile is back to gesture `Do Nothing` / thumb wheel
unchanged, and `citX - Joysticks.prf` (used by the stock Citation X) was restored from
`…bak2-2026-10-27`, undoing the two button edits made today. The active aircraft
(`Cessna Citation X AviTab_mods`) uses `PS4-CitationX`, so the pilot's own pad mapping is
unchanged. Pushed as `876a219`, on top of the earlier `64c1412` revert.

Historical note: the 2026-10-24 session turned the realism pack into the suite's only active
script (callouts, monitors, one black panel). See §21.

### What changed 2026-10-24

| Area | Change |
| --- | --- |
| Realism audio | `play_sound` (OpenAL, silent in XP12) → `load_fmod_sound` + `play_sound_on_master_bus`; legacy kept as fallback |
| Realism UX | generator loss / load shed / hot brakes / overspeed / icing raise a 2 s toast via the new `citationx_toast()` |
| Realism logic | GEAR UP no longer fires while the gear is still fully down |
| Panels | all four suite panels default to hidden — the only thing drawn is the realism pack's own black panel |
| Modules | every MasterSuite input layer defaults OFF; only the DS4 Axis-3 heading knob and the REALISM PACK stay active at init |
| Stick HDG | right stick re-enabled, and its learned rest no longer latches X-Plane's `-0.01` pre-enumeration value (it never locked before) |
| Controller | `JOY_BINDINGS` built at runtime from `sim/joystick/joystick_button_assignments`; only buttons X-Plane reports as unassigned are used |
| Handling | pilot-input curve (deadzone/expo/smoothing) + flight-controls check, part of the realism pack |
| Realism panel | one black, Helvetica realism panel with every control and live state (default on) |

### What changed 2026-10-23

| Area | Change |
| --- | --- |
| HUD | Telemetry body, alert pills and the C750 systems readback **deleted**; one 13-row control panel left |
| Realism | New `CitationX_Realism.lua`: audio callouts, load-shed manager, brake fan, overspeed/icing advisories. Now also draws the one black realism panel |
| Input | DS4 button scan widened to both device slots (`0–127`), so Bluetooth works |
| Textures | Cockpit panel: 8K dark Cascade 3 PNG + 8K DDS; cockpit overall/cabin 8K, seat 4K; `plain white` fuselage sharpened |
| Tests | `smoke_realism.lua` added; control-panel and geometry harnesses updated |

### Verification status (last run 2026-10-30)

```
syntax ........................ ok
runtime load (LuaJIT, shared) .. 104 bindings, 0 failures, 0 problems
dataref bindings .............. ok (5 suite scripts)
kpcrew require graph (C750) ... 0 missing
mastersuite smoke ............. PASSED (Axis 3/28, triggers/yaw rejected, watchdog, R3 hand-off)
control panel smoke ........... PASSED (14 rows; every key passes through with the mapper off)
realism smoke ................. PASSED (handling OFF at load, curve on demand)
efb smoke ..................... PASSED
panel geometry ................ PASSED (65 checks, incl. drag and active QRH)
```

### Open item — verify the native input map in-sim

**No in-sim run has happened since the 2026-10-30 binding revert.** Reload Lua in X-Plane
(*FlyWithLua → Reload all Lua script files*), then:

1. `Log.txt`: no `FlyWithLua Error:`, no `Moved Bad Script`, and **no**
   `Citation X Suite: axis optimizer engaged/released` lines.
2. A key bound in X-Plane's own keyboard settings must work; the suite must not swallow it.
   `Ctrl+Shift+9` / `Ctrl+Shift+0` (the mouse thumb buttons) are no longer read by the suite.
3. Push the DS4 right stick **up/down** → HDG SEL turns. If the direction is backwards, set
   `CONFIG.stick_hdg_invert = true`; if it is too fast/slow, `CONFIG.stick_hdg_rate_dps` (30).
4. Roll the **mouse wheel** → the view must still zoom (the suite must not consume it).
5. Confirm yaw, triggers, pitch/roll, the D-pad and the arrow keys are handled only by X-Plane.

Textures still need *Developer → Reload Aircraft* (or a restart), not a Lua reload.

## Current runtime state (2026-10-31)
- **Suite scripts (tracked):** `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`, `CitationX_EFB.lua`, `CitationX_Realism.lua` plus
  `CitationX_Callouts/*.wav` (19 files). All load clean; no `FlyWithLua Error:` lines.
- **The suite reads exactly one pilot input: the heading bug on DS4 Axis 3.** Every other input
  layer is OFF at load — no keyboard map, no joystick-button map, no analog-trigger throttle, no
  arrow-key view tilt, no stick ALT SEL, no axis optimizer, no R3 cockpit look, no realism
  handling curve. X-Plane's own profile is the single source of truth for the pad, the keyboard
  and the mouse wheel. Re-enable any layer from the control panel, the macro menu
  (`CitationX Suite: <row>`, `enable all modules`) or `CitationXSuite/toggle_<key>`.
- **Panels:** the realism panel and the MasterSuite hub (`status`) are the only two drawn at
  load; CabinOps, QRH, EFB and LandingPerformance start hidden.
- **Mission Generator: deleted 2026-10-21** at the user's request, together with
  `tests/smoke_mission.lua`. The `MissionGen/*` commands, the briefing panel and the cruise
  time warp no longer exist. Do not resurrect it without being asked.
- **Third-party add-ons (untracked, now loading):** KPCrew 2.3 (`kpcrew23.lua`, `kppanels.lua`,
  `kpxbrief.lua`, `kpsoundmute.lua`, `kpredline.lua`; modules in `Modules/kpcrew*`),
  `LandingPerformance.lua` (landing scoring), `Sim_Rate.lua` (ground-speed compression).
- **Panel spacing** was widened on 2026-10-21 (`row_h` 17 → 22, `status_row_h` 15 → 20,
  `sys_row_h` 15 → 19) because the text was too cramped. `sys_row_h` is gone with the C750 panel.
- **Not installed:** karlvr Citation X patches, Saitek panel config (Xsaitekpanels absent),
  Long Flights Compression and Smart Time Accelerator (both login-gated).

## Environment
- X-Plane 12: `/Users/modernamusmenet/X-Plane 12` (macOS, arm64)
- FlyWithLua NG+ 2.8.16 (mac_x64)
- Active scripts in `Scripts/`: `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`, `CitationX_EFB.lua`, `CitationX_Realism.lua`,
  `LandingPerformance.lua`, `Sim_Rate.lua`, `kpcrew23.lua`,
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
- `Aircraft/Cessna Citation X AviTab_mods` was built from a copy of the stock aircraft plus the
  mod's AviTab layer only: `AviTab.json`, `objects/ipad/*`, `plugins/xlua/scripts/avitab_guard`
  and acf objects 25/26 (`xPad_arm.obj`, `Ipad.obj`, both hidden by `citationx/gtnxi/hide_avitab`).
  The GTN object (obja 27), `TDSGTN.ini`, the GTN bezel meshes and the 14 TDS manipulator blocks
  in `cockpit_panel_interactive.obj` were stripped; the two now-orphaned `vrconfig` blocks
  (`map_zoom`, `map_copilot_zoom`) were removed as well. X-Plane aborts vrconfig parsing
  ("minor problem parsing the VRCONFIG") when a `BEGIN_MANIP` has no matching object
  manipulator, so every remaining block was re-checked against the object (56/56 match).
  Those two FMC zoom knobs simply have no VR manipulator any more.
- `acf/_name` = `Cessna Citation X AviTab` (renamed to `..._mods` on 2026-10-26, see §26),
  `acf/_ICAO` stays `C750` so the suite and KPCrew
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

## 19. Telemetry HUD and C750 systems readback removed (2026-10-23)

Requested: *"there is no reason for HUDs because the plane has already all information… I only
want the HUD where I can control the other HUDs."*

Removed from `CitationX_MasterSuite.lua`:

- the 8-row telemetry body (MACH LIM / AIRSPEED / ALTITUDE / ALT SEL / HDG SEL / G-LOAD /
  FUEL FLOW / ATTITUDE) — all of it is on the Pro Line 21 PFD;
- the alert pills (mach limit, structural G, emergency warning) — same reason;
- the whole right-hand `C750 SYSTEMS` readback (58 `laminar/CitX/...` datarefs via
  `XPLMFindDataRef`) — the synoptics and EICAS already show AP, electrics, fuel, ice and APU;
- `CONFIG.hud_enabled`, `systems_panel_enabled`, `show_when_hud_off`, `mach_warn`,
  `g_warn_high`, `g_warn_low`;
- `SYSTEMS_PANEL` / `SYSTEMS_ITEMS` / `SYSTEMS_GROUPS` / `SYS_REF` / `SYS_VAL` / `poll_systems`;
- `citationx_set_hud()`, `citationx_set_systems()`, `draw_systems_panel()`,
  `draw_status_section()`, `systems_panel_height()`.

What remains on screen is exactly one panel: `CONTROL PANEL`, 13 clickable rows, top-left
(hidden at load since 2026-10-24; the realism panel is the only thing painted then).
`HUD_STYLE` became `SUITE_STYLE` (only the panel, axis monitor, learn box and toast use it).
`citationx_hud()` became `citationx_overlay()`; `do_every_draw` still draws every frame but
emits nothing unless the panel, axis monitor, learn mode or a toast is active.

Contract change: `SUITE_MODULES[i].state()` now returns **one** string (`"ON"`, `"OFF"`,
`"REC"`, `"TRIGGERED"`, `"ABSENT"`, …). Colour is derived in `state_color()`. The command and
macro names for the removed rows are gone: `CitationXSuite/toggle_hud`,
`CitationXSuite/toggle_systems`, `HUD display`, `C750 systems panel`, `status panel` (renamed
`control panel`).

The emergency generator now announces itself with a toast on trigger and on clear, plus the
`EMERGENCY GEN` row showing `TRIGGERED`; it no longer needs a HUD pill.

Tests updated: `tests/smoke_hud_toggles.lua` now asserts the 13 expected keys, that `hud` /
`systems` do not exist, that `state()` returns a single value, and that the overlay draws
**zero** primitives with every display off. `tests/smoke_panel_geometry.lua` renders the control
panel, keeps the 40-check layout sweep, and adds the "draws nothing when off" assertion.

Validation: `78 dataref binding(s), 0 load failure(s), 0 binding problem(s)`; control-panel
smoke, MasterSuite stick smoke, EFB smoke, realism smoke, panel geometry (40 checks) and
`check_kpcrew_modules C750` all pass.

## 20. Realism pack + texture pass (2026-10-23)

Requested: *"a script that makes the flying more realistic, not add as many HUDs as possible"*,
covering all four areas (systems, handling, ops flow, weather), plus sharper aircraft textures.

### `Scripts/CitationX_Realism.lua`

New fifth suite script. It originally registered **no draw callback at all**; since
2026-10-24 it owns the one black realism panel (see §21, sixth request).
Everything is audio or Log.txt.

- **Callouts** (`CitationX_Callouts/*.wav`, now 19 files, generated with macOS `say`): V ONE,
  ROTATE, POSITIVE RATE, GEAR UP, ONE THOUSAND, FIVE HUNDRED, ONE HUNDRED, MINIMUMS, BRAKES HOT,
  FLAP OVERSPEED, GEAR SPEED, ICING CONDITIONS. Missing WAVs or a missing sound API degrade to
  Log.txt lines, never an error.
- **Speeds** come from the aircraft's own POM (`Citation_X_Pilot_Operating_Manual.pdf`,
  Operating-Speeds page): Vr 145, Vref 132, Vfe 180, Vle/Vlo 210, Vmo 270 below 8000 ft / 350
  above, Mmo 0.935, Vso 115, Vs1 136. V1 is **not** published by the POM; `REAL_CONFIG.v1_kt`
  defaults to 135 and is explicitly advisory.
- **Electrical load manager**: watches `generator_on[0..1]` and `bus_volts[0]`. When a generator
  is lost and the bus collapses below 24 V it fires the aircraft's real
  `laminar/CitX/electrical/cmd_load_shed_dwn` every 2.5 s, up to 4 steps. It never restores
  automatically. The LOAD SHED position is read lazily via `XPLMFindDataRef` (a `dataref()`
  binding would quarantine the script before the C750 loads).
- **Brake energy**: `sim/flightmodel2/gear/brake_absorbed_J` per wheel. Above 5 MJ it switches
  `sim/cockpit2/controls/brake_fan_on` on and calls BRAKES HOT; below 1 MJ it switches the fan
  off again.
- **Overspeed advisories**: flap Vfe (180 full, 250 at the 15° detent) and gear Vle 210, each
  latched once per event.
- **Icing**: OAT −20…+5 °C with `sim/weather/region/rain_percent` > 0, repeated at most every
  120 s.
- Commands/macros: `CitationXRealism/toggle`, `/test_callout`, `/status`.
- Added as row 13 of the MasterSuite control panel (`REALISM PACK`, `realism`), nil-guarded so
  the panel still works without the script.
- `tests/smoke_realism.lua` drives a full takeoff, approach, generator loss, hot brakes, flap
  overspeed and icing. The "no draw callback" assertion is gone: the pack now draws its own
  black panel, and the test drives that instead.

Note: `sim/weather/region/rain_percent` is a **scalar**, not an array. `probe_load_order`
caught the first version binding it with `dataref_table` (`PROBLEM dataref_table on scalar`).

### Textures

There was no resolution headroom: the aircraft ships 4096² albedos (Cascade 3 livery: 8192²
fuselage/cabin/cockpit_overall), `_tex_res` is 5 and `renopt_tex_res_04` is 4 (max), with 16×
anisotropic filtering on an M1 Max. So the pass was **sharpening**, not upscaling:

- `objects/cockpit_panel/cockpit_panel.dds` (DXT1, 4096) — unsharp mask `0x1.0+1.4+0.02`.
- `liveries/*/objects/cockpit_panel/cockpit_panel.dds` — all six livery panel copies were
  byte-identical, so they all received the same sharpened texture.
- `liveries/plain white/objects/fuselage_wing/fuselage.dds` (DXT5, 4096) — unsharp mask
  `0x1.2+1.0+0.02`. `plain white` is the active livery (`_livery_req 5`).
- Re-encoded as DXT1/DXT5 with 13 mip levels. Originals preserved in
  `Aircraft/Cessna Citation X AviTab_mods/_original_textures/` (mirrors the folder structure).

**Textures load when the aircraft loads, not when Lua reloads.** A FlyWithLua *Reload all Lua
script files* will not show them; use Developer → Reload Aircraft or restart X-Plane.

## 21. Realism callouts were silent — wrong sound API (2026-10-24)

Reported: *"you told me you developed realism lua scripts i noticed no difference at all."*

The pack **was** running. `Log.txt` from the 2026-10-23 flight proves it:

```
Citation X Realism: CALLOUT V ONE
Citation X Realism: CALLOUT ROTATE
Citation X Realism: CALLOUT POSITIVE RATE
Citation X Realism: CALLOUT GEAR UP
Citation X Realism: CALLOUT FLAP OVERSPEED
Citation X Realism: CALLOUT ONE THOUSAND
Citation X Realism: CALLOUT FIVE HUNDRED / MINIMUMS / ONE HUNDRED
Citation X Realism: LOAD SHED step 1..4
Citation X Realism: brake fan ON (5.1 MJ)
```

Two reasons nothing could be noticed:

1. **The audio never came out.** The script used the legacy FlyWithLua path
   `load_WAV_file()` + `play_sound()`, which is the OpenAL path. It loads happily
   (`12/12 callout sounds loaded`) and returns valid indices, but on X-Plane 12 the sim owns
   the audio device through FMOD, so the legacy player is inaudible. In the whole log there is
   not one `In LuaPlayFmodSoundOn…Bus()` line, because nothing ever touched FMOD.
   Fix: **`load_fmod_sound()` + `play_sound_on_master_bus()`** — the documented NG+ path
   (`Scripts (disabled)/Fmod_Demo.lua`). The legacy pair stays as a fallback, selected by
   `REAL_CONFIG.audio_backend = "auto" | "fmod" | "wav"`.
   Load now logs `N/12 callout sounds loaded (fmod bus)` and the master-group volume/mute, and
   lifts the master group back to 1.00 if it was at zero. `pcall` no longer swallows errors:
   a failed `play_sound_on_master_bus` writes the error to Log.txt.
2. **Everything else only fires in abnormal situations** (generator loss, hot brakes,
   overspeed, icing) and only wrote to Log.txt — invisible in the cockpit. Those events now
   raise a **2 s toast** through `citationx_toast()`, a new nil-guarded global in
   `CitationX_MasterSuite.lua`. Since 2026-10-24 `CitationX_Realism.lua` draws the one black
   realism panel itself (see the sixth-request section below); without the MasterSuite the
   notices stay in Log.txt.

Also fixed while in there:

- **GEAR UP called with the gear still down.** The condition was `gear > 0.05`, i.e. true
  while the gear was fully extended, so two seconds after liftoff it announced "gear up"
  whether or not the pilot had retracted. It now requires `prev_gear >= 0.95 and gear < 0.95`
  (retraction actually started). `tests/smoke_realism.lua` asserts both the silent and the
  calling case.
- `real_test_callout()` logs the backend and index before playing, so the macro
  **Citation X Realism: test callout** is a one-click audibility check.

Tests: `smoke_realism.lua` now mocks both sound APIs, asserts FMOD is preferred when present,
that every callout goes out on the master bus, that the load toast is raised, and re-loads the
script without the FMOD API to prove the legacy fallback still works.

### Panels now start hidden (2026-10-24, second request)

*"but still all huds windows open i only want the realism"* — every suite panel defaulted to
`true`, so the control panel, QRH, cabin and EFB were all painted at once. Flipped to `false`:

| Script | Flag | Line |
| --- | --- | --- |
| `CitationX_MasterSuite.lua` | `CONFIG.status_enabled` | ~36 |
| `CitationX_CabinOps.lua` | `CAB_CONFIG.panel_enabled` | ~24 |
| `CitationX_FailureTrainer.lua` | `TRAINER_CONFIG.panel_enabled` | ~31 |
| `CitationX_EFB.lua` | `EFB_CONFIG.panel_enabled` | ~34 |

Nothing else changed: the scripts still load and their logic (boarding flow, QRH scenarios,
EFB pages, heading knob, recorder) still works, they just do not paint until switched on.
Re-open any panel from the FlyWithLua macro menu — `CitationX Suite: control panel`,
`Citation X QRH: toggle panel`, `Cabin Ops: toggle panel`, `CitationX Suite: EFB panel` — or
from the matching command.

What remains on screen at load is the realism pack's own black panel (added later the same day,
see the sixth-request section) plus its 2 s `REALISM PACK READY` toast.
`LandedPerformance.lua` defaults to `la_displayMode = LA_DISPLAY_NONE`, so it is silent too.

Tests updated: `smoke_hud_toggles.lua` asserts `status_enabled`, `axis_monitor` and
`input_learn_mode` are all false at load, and that **no** `SUITE_MODULES` row reports `ON`;
`smoke_efb.lua` asserts the panel starts hidden and then opens via `efb_toggle_panel(true)`;
`smoke_panel_geometry.lua` switches each panel on explicitly before measuring it (layout checks
unchanged at the time, later raised to 47 checks when the realism panel joined the sweep);
`smoke_mastersuite.lua` enables the heading knob before driving it.

### Only the realism pack is enabled on init (2026-10-24, third request)

*"i want them disabled on int and enable them i want only realism should be enabled on init"*.
Hiding the panels was not enough — the MasterSuite's background modules were still armed. The
`CONFIG` defaults are now all off:

| Flag | Was | Now |
| --- | --- | --- |
| `status_enabled` | true | **false** |
| `log_enabled` (flight recorder CSV) | true | **false** |
| `emergency_enabled` (random bleed/press warning) | true | **false** |
| `input_map_enabled` (custom key/button bindings) | true | **false** (re-enabled 2026-10-26: losing the keyboard layers on reload was a regression; the layer draws nothing) |
| `stick_hdg_enabled` (DS4 right-stick heading bug) | true | **true** (the one exception, re-enabled 2026-10-24 on request) |
| `axis_optimizer_enabled`, `axis_monitor`, `input_learn_mode` | false | false |

`REAL_CONFIG.enabled` stays `true`, and the DS4 right-stick heading bug stays on because it is
how the user flies. Everything else is inert until switched on. CabinOps, QRH and EFB are inert
because their panels are hidden and they only start on a click or macro.

Nothing is lost: every row keeps its `set()` path, so the macros
`CitationX Suite: <row>` and `CitationXSuite/toggle_<key>` still switch each module on, and two
new macros flip the lot — `CitationX Suite: enable all modules` /
`CitationX Suite: disable all modules` (`citationx_set_all()`, which skips the panel row so
enabling everything does not paint the panel on top).

Consequence to be aware of: the suite's custom **keyboard** bindings (`input_map_enabled`) are
on at load again (2026-10-26) — they are a control layer and draw nothing, so "only realism on
init" still holds for every drawing module. The DS4 heading knob is the other deliberate
exception.

### More realism (2026-10-24, fourth request)

*"can you do more realism"* — the pack grew from five monitors to eleven, seven new WAVs
(19 total). Nothing new draws except the existing 2 s toast.

| Monitor | Trigger | Callout |
| --- | --- | --- |
| **Takeoff config** | on the ground, thrust lever ≥ 0.70, with park brake > 0.1, speedbrake > 0.1 or flaps > 0.80. Fires once per thrust application, re-arms below 0.2. | `TAKEOFF CONFIG` + toast naming the item(s) |
| **Vmo / Mmo** | IAS > Vmo + 3 (270 kt below 8 000 ft, 350 above) or M > Mmo + 0.01 (0.935); latched until 5 kt / 0.01 back inside | `OVERSPEED` |
| **Stabilised approach** | crossing 1 000 ft AGL descending > 200 fpm with gear or flaps already out. Criteria: gear down, flaps ≥ 0.30, spoiler retracted, bank ≤ 30°, VS ≥ −1 200 fpm, IAS within Vref −5/+25. Re-arms 500 ft above the gate | `STABLE` / `UNSTABLE` + toast with the failing item(s) |
| **Gear confirmation** | gear reaches down-and-locked (ratio ≥ 0.99) after being < 0.95, airborne | `GEAR DOWN` |
| **Anti-ice off** | airborne, OAT −20…+5 °C, rain > 1 %, `ice_surface_hot_bleed_air_on` = 0, at most every 60 s | `ANTI ICE` + `ICING - ANTI-ICE OFF` |
| **Cabin altitude** | airborne, cabin altitude ≥ 10 000 ft, at most every 60 s | `CABIN ALTITUDE` |

Changes to existing behaviour:

- The ICING CONDITIONS callout now only fires when the wing anti-ice is **on**; with it off the
  ANTI-ICE advisory owns the message (no double audio in the same tick).
- Icing and anti-ice advisories now require the aircraft to be **airborne**; a parked aircraft in
  cold rain is not in airframe icing conditions.
- The one-shot state (`stable_checked`, `to_config_armed`, `overspeed_warned`,
  `gear_down_called`) re-arms on touchdown / go-around / thrust reduction, so consecutive
  approaches and touch-and-gos behave.

New datarefs (all verified in `DataRefs.txt`): `sim/flightmodel/position/elevation`,
`.../position/phi`, `sim/flightmodel/controls/parkbrake`,
`sim/cockpit2/controls/speedbrake_ratio`,
`sim/cockpit2/engine/actuators/throttle_ratio_all`,
`sim/cockpit2/ice/ice_surface_hot_bleed_air_on`,
`sim/cockpit2/pressurization/indicators/cabin_altitude_ft`. The C750's `CitX_ice.lua` uses
`ice_surface_hot_bleed_air_on` for its slat deice, so the anti-ice advisory follows the real
cockpit switch.

New WAVs (same 22 050 Hz/16-bit mono recipe, `say -v Samantha`): `overspeed`, `to_config`,
`stable`, `unstable`, `gear_down`, `anti_ice`, `cabin_alt`.

Validation: `probe_load_order` 97 bindings, 0 failures; `check_datarefs` 34 declarations,
0 problems; `smoke_realism` now also drives takeoff config, Vmo, stable/unstable, gear-down,
anti-ice-off and cabin-altitude.

### Handling realism (2026-10-24, fifth request)

*"yes lets do that"* — accepting the control-response option. Two additions, both in
`CitationX_Realism.lua`:

**1. Pilot-input shaping (`REAL_CONFIG.handling_enabled`, default on).**
Reads `sim/joystick/joy_mapped_axis_value` 1/2 (pitch/roll), applies deadzone 0.02, expo 1.35
and smoothing 0.55, and writes the result to `sim/joystick/yoke_pitch_ratio` /
`yoke_roll_ratio` with `override_joystick_pitch` / `_roll` = 1. This is the same mechanism the
MasterSuite's axis optimizer uses; it makes a short-throw pad precise near neutral without
touching the flight model. `CitationXRealism/handling` and the macro *Citation X Realism:
handling curve* toggle it.

- It runs **before** the 10 Hz gate, every frame — smoothing at 10 Hz would be unusable.
- Only one script may own those two overrides. If `CONFIG.axis_optimizer_enabled` is true the
  realism curve releases and **does not write 0** (that would leave the optimizer driving an
  override it no longer owns). Same guard in `release_handling()`.
- The overrides are released when the pack is disabled, when the axes disappear, and in
  `real_shutdown()` (FlyWithLua runs the exit hook on reload, so a reload cannot leave the
  axes hijacked).

**2. Flight-controls check before takeoff (`control_check_enabled`, default on).**
While on the ground, pitch, roll and rudder (`sim/cockpit2/controls/yoke_*_ratio`) must each
reach 60 % of travel. On success: `CONTROLS CHECKED` toast, once. If the thrust levers go
forward first, the takeoff-config warning adds `CONTROL CHECK` to the list. It re-arms when the
engines spool down on the ground, so it is asked once per flight, not once per session.

**What it does not do, deliberately:** it does not inject turbulence. X-Plane already applies
the weather's turbulence/gusts, and adding random chop from a script would be fake and would
fight the weather engine. It also does not touch the flight model, trim, or control
effectiveness — those are X-Plane's.

New datarefs (all verified): `sim/joystick/joy_mapped_axis_value` (idx 1/2),
`sim/joystick/joy_mapped_axis_avail` (idx 1/2), `sim/joystick/yoke_pitch_ratio`,
`sim/joystick/yoke_roll_ratio`, `sim/operation/override/override_joystick_pitch`,
`.../override_joystick_roll`, `sim/cockpit2/controls/yoke_pitch_ratio`,
`.../yoke_roll_ratio`, `.../yoke_heading_ratio`,
`sim/cockpit2/engine/indicators/engine_speed_rpm`.

Validation: `probe_load_order` now 97 bindings, 0 failures; `check_datarefs` 34 declarations,
0 problems; `smoke_realism` covers engage/release/re-engage, the shape itself, the hand-off
guard and the control check.

### One black realism panel (2026-10-24, sixth request)

*"for all the realism controll and info i want one hud black and with a sans font"*.

`CitationX_Realism.lua` now draws exactly one panel and nothing else:

- **Black** (`0,0,0` at 90 % alpha) with a 1 px grey border, **Helvetica only**: 18 px title,
  12 px rows, 10 px footer — the `draw_string_Helvetica_*` family, i.e. actual sans-serif
  glyphs rather than FlyWithLua's default bitmap font.
- Top-left, 430 px wide, 12 rows, so it sits where the (hidden) MasterSuite control panel used
  to be. Bottom-anchored maths still follows the bottom-left origin: the panel is computed from
  the top edge and extends downward, all coordinates positive.
- Rows: **REALISM PACK**, **CALLOUTS**, **AUDIO** (backend + sounds loaded), **HANDLING CURVE**,
  **CTRL CHECK**, **LOAD SHED** (steps + bus volts), **BRAKES** (fan + hottest MJ), **ICING**
  (clear / protected / PROT OFF), **OVERSPEED**, **TAKEOFF CFG** (last item list),
  **APPROACH** (STABLE / UNSTABLE + reason), **LAST** event.
- Clickable: the four `*` rows toggle their subsystem (the CTRL CHECK row re-arms the check),
  plus footer buttons **TEST CALLOUT** and **HIDE HUD**. `RESUME_MOUSE_CLICK` is set only when
  a row is actually hit, so clicks elsewhere pass through.
- `REAL_CONFIG.hud_enabled` (default **on**), command `CitationXRealism/hud`, macro
  *Citation X Realism: realism panel*.

This is the control-panel surface AGENTS.md rule 7 allows, not a telemetry HUD: it shows the
realism pack's own state (load shed, brake energy, icing, overspeed, config, approach), never
airspeed/altitude/heading/fuel — the PFD and EICAS already show those. The MasterSuite control
panel stays hidden and its overlay still draws nothing.

Tests: `smoke_realism.lua` asserts one draw callback, >40 primitives, the title and the four
control rows, row-click toggling, and zero primitives when the panel is hidden.
`smoke_panel_geometry.lua` now renders the realism panel too — 47 checks, including the panel
fitting 1280×720.

### Heading knob on the right stick was dead (2026-10-24)

Reported: *"heading on the right stick does not work"*. Two causes:

1. **It had been switched off** with the "only realism at init" pass
   (`stick_hdg_enabled = false`). Now **true**: it is the one MasterSuite module that is on at
   load, because it is how the aircraft is flown.
2. **It could never detect the axis anyway.** The 2026-10-23 `Log.txt` has 323 `HDG scan`
   lines and **no** `heading knob locked` line. Every axis reported a learned rest of `-0.01`:
   `stick_baseline_update()` adopted the first raw value it saw, and X-Plane publishes `-0.01`
   for axes whose device has not enumerated yet. The axis then looked deflected by `1.00`
   (rest `-0.01`, raw `0.50`), so the baseline was frozen (`|d| > deadzone`) and
   `stick_axis_is_centered()` — which requires a rest within `0.25` of `0.5` — never passed.
   Detection therefore never ran, on any axis, for the whole session.

**Fix** in `stick_baseline_update()`:

- adopt a first value only if it is within `0.35` of `stick_hdg_center`; `-0.01`, `0` and `1`
  are rejected, so triggers (which rest at 0/1) simply never get a rest and stay excluded;
- repair an existing rest latched at a hard extreme (`< 0.05` or `> 0.95`) once the axis
  reports a plausible centre and is more than `0.35` away from the bad rest.

A/B proven with `tests/smoke_mastersuite.lua`: its new "late-enumerating right stick still
locks" case fails on the old baseline (`-> 0`) and passes on the new one. That harness now
publishes assignments/axes *after* reloading the script with `-0.01`, which is exactly the
startup order X-Plane uses.

### Controller bindings use only the free buttons (2026-10-24)

The blueprint prompt initially described the keyboard layers without checking what the user
already has mapped. `initial_assignments.txt` (FlyWithLua's dump for the C750) plus the HID lines
in `Log.txt` give the real picture:

- **Axes:** DS4 raw `25/26/27/28` = left stick X/Y (roll/pitch), right stick X (yaw), right stick
  Y (free → the heading knob locks here). `L2/R2` are analog axes 29/30, unused by the suite.
- **Buttons 0–7** are the D-pad hat; **9/11** are the L2/R2 digitals; **12–15** aileron trim,
  **16** cockpit look, **18** spot view, **19** thrust reversers. Only **8, 10, 17** and the
  high indices are free on that dump.

`CitationX_MasterSuite.lua` now fills `JOY_BINDINGS` at runtime instead of shipping a fixed map:

- reads `sim/joystick/joystick_button_assignments` (int[3200], 64 per device);
- scans buttons **8–17** on device slots 0 and 1 (0–127), i.e. face/shoulder buttons only — the
  D-pad hat (0–7) and non-physical 18+ are skipped;
- binds **only** indices whose assignment is `0` (X-Plane "unassigned"), so nothing the pilot has
  mapped is ever overwritten;
- the same physical button on the USB and Bluetooth slots gets the same action, so a reconnect
  does not lose it;
- order: `CONTROL PANEL`, `REALISM PANEL`, `TEST CALLOUT`, `FLIGHT RECORDER`, `EMERGENCY GEN`,
  `AXIS MONITOR`;
- logs `Citation X Suite: free joy button N -> LABEL` for each, and
  `no free controller buttons to bind` when there are none.

Gates: `CONFIG.joy_autobind_enabled` (default true) and `CONFIG.joy_map_enabled` (default true).
The latter is separate from `input_map_enabled`, which gates the keyboard layers — so the pad
works without silently enabling Ctrl+Shift+digit.

Test: `smoke_mastersuite.lua` section 8 marks a whole second slot as assigned and checks that it
is left untouched, while the free slot gets `CONTROL PANEL` / `REALISM PANEL` in order and the
bound action actually runs.

## 22. Realism pack quarantined — duplicate writable DataRefs (2026-10-26)

Reported: *"nothing works"*. The realism pack was missing from `Scripts/`; the only surviving
copy sat in `Scripts (Quarantine)/CitationX_Realism.lua` (moved 2026-10-24 18:43, byte-identical
to the committed version). With the pack gone, **no suite panel painted at all** — it is the one
surface enabled at init — and the quarantine popup appeared on every load.

`Log-2026-10-25-0109.txt` (Output/Log Archive) names the failure:

```
FlyWithLua Error: The variable "real_yoke_pitch" wants to write a DataRef, that is already handled by another variable.
... real_yoke_roll / real_ovr_pitch / real_ovr_roll ...
FlyWithLua Info: 2nd Moved Bad Script to .../Scripts (Quarantine)/CitationX_Realism.lua
```

Both scripts bound the same four refs writable:

| DataRef | MasterSuite | Realism (old) |
| --- | --- | --- |
| `sim/joystick/yoke_pitch_ratio` | `yoke_pitch_ratio` | `real_yoke_pitch` |
| `sim/joystick/yoke_roll_ratio` | `yoke_roll_ratio` | `real_yoke_roll` |
| `sim/operation/override/override_joystick_pitch` | `ovr_joystick_pitch` | `real_ovr_pitch` |
| `sim/operation/override/override_joystick_roll` | `ovr_joystick_roll` | `real_ovr_roll` |

FlyWithLua allows one **writable** owner per DataRef; a second writable `dataref()` quarantines
the later script (names sort MasterSuite before Realism). The logic guard that made the realism
curve back off while the axis optimizer was on never mattered — the binding itself is fatal.

Fix: `CitationX_Realism.lua` no longer binds those four refs. It resolves them lazily with
`XPLMFindDataRef` and writes through `XPLMSetDatai` / `XPLMSetDataf`, the same pattern already
used for `laminar/CitX/electrical/load_shed`. The MasterSuite keeps the writable bindings and the
axis optimizer; the realism curve still backs off when it is enabled.

Regression guard: `tests/probe_load_order.lua` now reports
`PROBLEM duplicate writable binding: <script>: <var> [<ref>] (already writable in <script>)`.
Verified against the old quarantined file (4 problems) and against the fixed tree (0 problems).

Validation after the fix: `94 dataref binding(s), 0 load failure(s), 0 binding problem(s)`;
realism smoke, MasterSuite stick/panel, EFB, panel geometry (47 checks) and
`check_kpcrew_modules C750` all pass.

## 23. More realism: takeoff trim, fuel balance, weight and crosswind (2026-10-26)

Requested after the quarantine fix: *"lets improve on that"* → more realism. All four new
monitors are sourced from the aircraft's own checklist/POM, not invented:

| Monitor | Source | Trigger | Output |
| --- | --- | --- | --- |
| **Takeoff trim** | `clist.txt` BEFORE TAXI: flaps 5 → trim −0.43…0, flaps 15 → −0.21…+0.42; aileron/rudder neutral | thrust ≥ 0.70 with trim outside the band for the selected flap detent | `STAB TRIM` / `LATERAL TRIM` added to the existing `TAKEOFF CONFIG` call |
| **Fuel balance** | `clist.txt` BEFORE TAXI: imbalance < 200 lb | left/right wing tank difference > 200 lb for 5 s with an engine running or airborne | `FUEL IMBALANCE` call + toast |
| **Weight** | `clist.txt` limits: MTOW 36 100 lb, MLW 31 800 lb | weight > MTOW at takeoff thrust; weight > MLW at touchdown | `WEIGHT` in `TAKEOFF CONFIG`; `OVERWEIGHT` at landing |
| **Crosswind** | POM Operating-Speeds: maximum demonstrated crosswind 10 kt | crosswind component > 10 kt during the takeoff roll (IAS > 40) or below 1 200 ft AGL on approach | `CROSSWIND` call + toast |

Implementation notes:

- `sim/cockpit2/fuel/fuel_quantity` is **kg[9]**, and the C750's `acf/_tank_name` order is
  **0 center, 1 left, 2 right**. The checklist compares [1] and [2]; the script converts the
  difference to lb (`×2.2046226`) before applying the 200 lb limit.
- The trim bands use `sim/cockpit2/controls/elevator_trim` and the checklist's own ratios;
  `aileron_trim` / `rudder_trim` must be within 0.02 of neutral.
- Takeoff flaps must be in the 5°/15° range (0.45–0.80); clean or full flaps now raise
  `FLAPS` in the takeoff-config warning, matching the checklist's "Flaps 5 or 15".
- The weight monitor reads `sim/flightmodel/weight/m_total` (kg) and compares in lb.
- Crosswind uses `wind_heading_deg_mag`, `wind_speed_kts` and the AHARS magnetic heading;
  it is an advisory, because "demonstrated" is not a hard limitation.
- **Vfe corrected**: the old code used 250 kt for the 15° detent and 180 kt for anything above
  0.60. The checklist gives **250 kt at flaps 5, 210 kt at flaps 15, 180 kt at full flaps**, so
  the overspeed monitor now selects by detent (`flap5_ratio_max` 0.60,
  `flap15_ratio_max` 0.85).
- Three new callout WAVs (`fuel_imbalance`, `crosswind`, `overweight`) were generated with
  `say -v Samantha --data-format=LEI16@22050`; the pack now loads 22.
- The realism panel grew from 12 to 16 rows (`TAKEOFF TRIM`, `FUEL BAL`, `WEIGHT`, `CROSSWIND`).
  It still fits 1280×720 (`smoke_panel_geometry.lua`, 47 checks).

Validation: `probe_load_order` → `101 dataref binding(s), 0 load failure(s), 0 binding
problem(s)`; realism smoke (including the four new sections and the 210 kt flap-15 case),
MasterSuite stick/panel, EFB, panel geometry and `check_kpcrew_modules C750` all pass.

## 24. Keyboard layer restored at load (2026-10-26)

Reported: *"and now all the keyboard bindings are gone"* — after the reload, none of the
`Ctrl+Shift` / `Ctrl+Alt` C750 system layers responded. Root cause was the 2026-10-24
"only realism at init" sweep: it set `CONFIG.input_map_enabled = false`, and
`citationx_keystroke()` returns early when that flag is off.

That was the wrong trade. The keyboard map is a **control layer**, not a drawing module — it
adds no HUD and no panel. The default is now `input_map_enabled = true`; `status_enabled`,
`log_enabled`, `emergency_enabled`, the axis optimizer, axis monitor and learn mode all stay
off. Two modules are deliberately live at init: the DS4 heading knob and the keyboard layer.
`tests/smoke_hud_toggles.lua` now asserts exactly `input + stick` are ON at load.

## 25. Cockpit texture pass: 8K panel and high-res interior (2026-10-26)

Asked how to improve the cockpit texture after the realism work. Inspection found a complete
high-resolution interior already on disk but unused by the active livery:
`objects/as/Cascade 3/objects/` contains **8192²** `cockpit_panel.dds`, `cockpit_overall/cockpit.dds`
and `cabin.dds`, plus a **4096²** `cockpit_seat.dds`. The base `objects/` tree used by
`plain white` had 4096/4096/4096/1024 versions. The high-res panel is the darker Cascade 3
finish (the other assets are colour-identical, mean difference ~1–2 %).

The bigger discovery: `objects/cockpit_panel/cockpit_panel.obj` line 5 already says
`TEXTURE cockpit_panel.png`, but only a **DXT1** `.dds` was shipped. X-Plane's own guidance is
that **the cockpit object's texture is exempt from compression** precisely to protect label
readability — so the panel was being shown through a compressed 4K DXT1 texture with no
uncompressed source. That is why the labels looked blocky even after the 2026-10-23 sharpening.

What was done:

- **Panel (plain white look preserved):** the 8192² dark panel was used as a detail source, not
  a colour source. Frequency separation —
  `out = hi + blur(current) - blur(hi)` — transfers the 8K high-frequency detail onto the
  current light panel's low-frequency tone. Then a light unsharp mask
  (`0x1.0+0.8+0.02`) and a 2× downscale.
  - `objects/cockpit_panel/cockpit_panel.png` — new **8192² lossless PNG** (62 MB), the file the
    OBJ already referenced.
  - `objects/cockpit_panel/cockpit_panel.dds` — **4096² DXT1, 13 mips** fallback.
  - `liveries/plain white/objects/cockpit_panel/cockpit_panel.png` — the same 8K PNG; its old
    DDS override was removed so the livery does not mask the lossless file.
  - the other five livery panel DDS copies were replaced with the improved 4K DDS.
- **Interior:** copied the high-res assets into the base object tree used by `plain white`:
  `cockpit_overall/cockpit.dds` → **8192² DXT5**, `cabin/cabin.dds` → **8192² DXT5**,
  `cockpit_seat/cockpit_seat.dds` → **4096² DXT5**.
- **Backups:** `Aircraft/Cessna Citation X AviTab_mods/_texture_backups/2026-10-26_cockpit_highres/`
  mirrors every replaced path (current sharpened panel, old overall/seat/cabin, all six livery
  panel DDS files).

The dark 8192² Cascade 3 panel is still available if a dark cockpit finish is wanted later; the
current install only borrows its detail.

### Dark panel installed (2026-10-26, follow-up)

*"go"* — the dark 8K panel was installed directly, replacing the light detail-transplant:

- `objects/cockpit_panel/cockpit_panel.png` — 8192² RGB, 32 MB.
- `objects/cockpit_panel/cockpit_panel.dds` — 8192² DXT5, 14 mips, 85 MB.
- `liveries/plain white/objects/cockpit_panel/cockpit_panel.png` — same dark PNG.
- the five remaining livery `cockpit_panel.dds` overrides were removed, so the base dark panel
  applies to every livery (all six had been byte-identical anyway).
- the previous **light** 8K PNG/4K DDS and every removed livery DDS are in
  `_texture_backups/2026-10-26_dark_panel/`. To restore the light look, copy them back and
  reload the aircraft.
- `cockpit_overall`, `cabin` and `cockpit_seat` remain the high-res light-beige set, which is
  the intended combination in the Cascade 3 asset pack (dark panel, light surroundings).
- Preview: `~/Desktop/CitationX_panel_light_vs_dark.png`.

**Textures load when the aircraft loads.** Use *Developer → Reload Aircraft* (or restart), not
FlyWithLua's Lua reload. In-sim confirmation of the 8K panel (texture cap, VRAM, label
readability) is still pending.

## 26. Edited aircraft renamed to `Cessna Citation X AviTab_mods` (2026-10-26)

There are four C750 copies under `Aircraft/`: the stock `Laminar Research/Cessna Citation X`,
`Laminar Research/Cessna Citation X GTNXi`, `Laminar Research/Cessna Citation X avi`, and the
one this project actually edits. To make the edit target unmistakable the folder was renamed
from `Aircraft/Cessna Citation X AviTab` to **`Aircraft/Cessna Citation X AviTab_mods`**, and
`P acf/_name` in `Cessna_CitationX.acf` was changed to match (`acf/_ICAO` stays `C750`).

- All §16 and §25 work (AviTab rect + guard, 8K/dark cockpit textures, backups) lives in that
  folder; no file was moved between copies.
- The stock `Laminar Research/Cessna Citation X` is still the canonical source for
  `laminar/CitX/...` dataref/command validation, and remains untouched.
- FlyWithLua scripts are aircraft-agnostic: they live in `Resources/plugins/FlyWithLua` and
  bind to whichever C750 is loaded, so the rename needs no script change.
- X-Plane was running with the **stock** Citation X loaded when the rename happened (Log.txt
  `Loading airplane ... Laminar Research/Cessna Citation X`); the renamed folder is picked up
  on the next aircraft selection. Stale `_loads_crc32 _AircraftCessnaCitationXAviTab...`
  bookkeeping in `Output/preferences/Freeflight.prf` is harmless.

## 27. Panel reskin, drag & drop, R3 cockpit look (2026-10-26)

Requested in one pass: every panel should look like the realism panel, be draggable, the load
state should show only the realism panel plus one hub, and right-stick click + movement should
pan the 3-D cockpit.

- **One visual language.** `SUITE_STYLE`, `CS`, `EFB_STYLE` and `ST` now carry the realism
  palette (`bg` 0/0/0 0.90, `header_bg` 0.04, `border` 0.32, white title, 0.55 sub, 0.80
  label) and 34/21/34/14 geometry (header / row / footer / pad). Titles use
  `draw_string_Helvetica_18`, sub-headers `_10`, rows `_12`; the old blue glass palette is
  gone. Every panel draws the same 1 px border, header strip, divider and footer button
  (**HIDE PANEL**); the realism panel keeps its TEST CALLOUT / HIDE HUD pair.
- **Drag & drop.** Each script stores its absolute top edge (`panel_top`, realism uses
  `REAL_STYLE.y`) and handles `MOUSE_STATUS == "drag"` in its own `do_on_mouse_click`
  callback: press the header, move, release. `MOUSE_STATUS` is `"down"`, `"drag"` or `"up"`
  in FlyWithLua NG+, so no per-frame polling is needed. Positions are session-only and are
  clamped to the screen. **Offsets are per script** (`cab_drag`, `efb_drag`, `qrh_drag`,
  `panel_drag`, `real_drag`) so a missing sibling cannot break another panel.
- **Load state.** `CONFIG.status_enabled` is now `true`: the realism panel (top-left) and the
  Master Suite hub (right of it, `SUITE_STYLE.x = 470`) are the only surfaces at load. EFB,
  cabin, QRH, landing report and axis monitor stay off; the keyboard layer, heading knob and
  the new look module stay on because they draw nothing.
- **R3 cockpit look.** Hold the right-stick click (DS4 R3 = 0-based button 11, `view_pan_button`)
  and move the stick: `sim/graphics/view/pilots_head_psi` / `_the` are integrated at
  `view_pan_rate_dps` per second, with a deadzone, pitch clamp and per-axis inversion. From a
  2-D view the press first fires `sim/view/3d_cockpit_cmnd_look`. While R3 is held the heading
  knob block is skipped, so the same stick cannot move the bug; releasing R3 resumes it. The
  axis pair is auto-detected from the most-deflected spring-centred axis plus its adjacent
  hardware partner (DS4 raw 2/3); `view_pan_axis_x/y` pin it. R3 is excluded from
  `citationx_autobind_joy`, which otherwise would have claimed it for a free-button action.
  The hub gains a **COCKPIT LOOK** row (`CitationXSuite/toggle_look`).
- **Tests.** `smoke_panel_geometry.lua` now drags all five panels and checks the new default
  positions and the active QRH (65 checks); `smoke_mastersuite.lua` proves R3 yaws/pitches, suppresses the heading
  bug, resumes it on release and holds the view at centre; `smoke_hud_toggles.lua` asserts the
  new load state and the 14th module.
- **Not verified in-sim:** the look datarefs are writable per `DataRefs.txt`, but whether
  X-Plane 12.4.3 lets a plugin hold the head offset while the aircraft is flown has not been
  seen yet. If the view snaps back, pin `view_pan_axis_x/y` first, then check Log.txt for the
  `cockpit look axes` line to confirm the button/axis detection.

## 28. Script reload CTD — FlyWithLua 2.8.16 FMOD teardown (2026-10-26)

At 19:53 on 2026-10-26 a `FlyWithLua: User forced a script reload` crashed X-Plane. The log
ends in `deinitFmodSupport() ... FmodSounds.size = 0` followed by
`--=={This application has crashed!}==--`, **before any script was loaded again**. The session
started at 19:30, i.e. it was still running the pre-change scripts; the new panel code was
never executed in that run. The crash is in the plugin's script-unload path.

- Installed plugin: **FlyWithLua NG+ 2.8.16, build 2026-08-13**.
- Upstream fixed exactly this class of CTD after that build:
  - `9d4e68db` (2026-10-20) *Prevent CTD on plugin reload by safely recycling FMOD channel groups*
  - `be39ff21` (2026-10-21) *Prevent FMOD mixer race on reload by stopping groups and flushing queue*
- Upstream `master` is **2.8.20 build 2026-10-23** (universal x86_64/arm64, ad-hoc signed) and
  contains the stop/flush fix in `fmod_uninitialize()` plus a redundant-call guard in
  `deinitFmodSupport()`.
- **Resolved on 2026-10-26:** the live plugin was updated to **2.8.20 build 2026-10-23**
  (`mac_x64/FlyWithLua.xpl`, universal x86_64/arm64), taken from upstream `master` at the
  commit that carries the FMOD reload fixes. The 2.8.16 binary is kept next to it as
  `mac_x64/FlyWithLua.xpl.2.8.16.bak` (untracked). File hashes:
  `0c3c0537…` (2.8.20) vs `5cc54d43…` (2.8.16). Reloading scripts is expected to be safe
  again; still verify the first reload in-sim.
- **Workaround if the plugin is ever rolled back:** after editing scripts, quit and restart
  X-Plane. Do **not** use *Reload all Lua script files* on 2.8.16 while the realism pack has
  its 22 FMOD callouts loaded. There is no Lua-side workaround: FlyWithLua exposes no
  `unload_fmod_sound`, and the crash happens inside the plugin's own unload after our
  `do_on_exit` handlers have run.
- The cockpit-look writes are additionally gated on `sim/graphics/view/panel_render_type ~= 0`
  (3-D view), so no head-offset dataref is written from a 2-D panel.

## 29. Dark interior pass, texture gallery, AviTab screen check (2026-10-26)

After the texture gallery the request was **"dark and all"** — the panel was already dark, so the
three interior atlases were darkened to match it.

- **Files changed:** `objects/cockpit_overall/cockpit.dds`, `objects/cabin/cabin.dds`,
  `objects/cockpit_seat/cockpit_seat.dds`. RGB ×0.55 (sRGB multiply; alpha untouched), DXT5,
  mip chains preserved (14 levels at 8192², 13 at 4096²).
- **Livery copies:** `liveries/Cascade 3/objects/{cockpit_overall,cabin,cockpit_seat}/*.dds` were
  byte-identical to the base, so the darkened files were copied there too. Other liveries have no
  interior overrides and inherit the base.
- **Backup:** `_texture_backups/2026-10-26_dark_interior/` (the light-beige 8K set plus the
  Cascade 3 duplicates, 384 MB). The pre-8K originals remain in `_texture_backups/2026-10-26_cockpit_highres/`
  and `_original_textures/`.
- **Result (mean sRGB):** overall 0.202, cabin 0.189, seat 0.205 — the dark panel is 0.209. Stock
  was 0.357 / 0.355 / 0.689.
- **Gallery:** `~/Desktop/CitationX_textures_before_after/index.html` (+ full-page PNG), regenerated
  with the dark interior. Textures and galleries are outside the repo, so they are not committed.
- **AviTab digital screen:** the in-cockpit screen is AviTab's panel integration, not a Mac PFD/PDF
  feature. The 19:30 log loaded the **stock** `Laminar Research/Cessna Citation X`, whose
  `AviTab.json` still has the old `left 1358` rect, outside the 1024 panel. The mod has
  `679 / 208 / 344×206`; geometry verified: `TRIS 57651` in `cockpit_panel_interactive.obj` maps
  to UV 679..1023 × 208..414 of `cockpit_3d/-PANELS-/Panel.png` (1024², byte-identical to stock).
  AviTab 0.7.1 is universal and loads. **Pending in-sim:** load `Cessna Citation X AviTab_mods`;
  if the screen is blank, toggle AviTab off/on in Plugin Admin to force `createPanel()`, then
  consider TeamAvitab 1.1.0 (signature change; back up 0.7.1 first).
- **Unrelated to the screen:** the dark pass did not touch `-PANELS-/Panel.png`, `Ipad.png` or
  `xPad_arm.dds`.

## 30. Input reset: only the heading knob (2026-10-29)

*"RESET ALL YOUR LUA INPUT OVERWRITE I ONLY WANT TO BE ABLE TO CHANGE THE HEADING WITH AXIS 3
UP AND DOWN"* — the user's PS4 profile already maps every control in X-Plane, and the suite's
parallel layers were fighting it.

| Input layer | Flag | Was | Now |
| --- | --- | --- | --- |
| Keyboard / MX layers | `CONFIG.input_map_enabled` | true | **false** |
| Joystick-button map | `CONFIG.joy_map_enabled` | true | **false** |
| Analog L2/R2 throttle | `CONFIG.trigger_throttle_enabled` | true | **false** |
| Arrow-key view tilt | `CONFIG.view_tilt_enabled` | true | **false** |
| Stick ALT SEL | `CONFIG.stick_alt_enabled` | true | **false** |
| Axis optimizer | `CONFIG.axis_optimizer_enabled` | false | false |
| R3 cockpit look | `CONFIG.view_pan_enabled` | false | false |
| Realism handling curve | `REAL_CONFIG.handling_enabled` | true | **false** |

- **The one input kept:** the heading bug on **DS4 Axis 3** (right stick up/down). X-Plane's
  profile leaves Axis 3 unassigned, which is why it is the free spring-centred axis.
- **Mouse thumb buttons (added later the same day, removed 2026-10-30):** the Logitech MX
  back/forward buttons used to drive ALT SEL via `Ctrl+Shift+9` / `Ctrl+Shift+0`
  (`CONFIG.alt_keys_enabled`). That layer is gone; the keys now pass straight through to
  X-Plane like every other keystroke. The mouse **wheel** was never consumed —
  `thumbwheel_altitude` stays false, so view zoom is intact.
- **Both device slots are pinned:** `CONFIG.stick_hdg_axes = { 3, 28 }`. The pad enumerates
  twice, so Axis 3 is raw 3 in the first slot and raw 28 in the second (USB vs Bluetooth).
  `stick_hdg_axes` selects the most-deflected listed axis each frame; an axis must have been
  seen centred at least once (`stick_base_raw`), so a dead interface parked at raw 0 never
  turns the bug. The 6 s extreme watchdog still applies and vetoes a stuck slot.
- **Arrow keys are no longer consumed.** `citationx_keystroke` used to set `RESUME_KEY` for the
  view-tilt handler even with the input map off; the tilt block is now gated on
  `CONFIG.view_tilt_enabled` too, so the keys pass through to X-Plane.
- **ALT SEL moved off the stick:** one axis must never drive two bugs. `stick_alt_tick` stays
  in the file (config + `citationx_set_stick_alt`) but has no panel row; the `stick` row is now
  **STICK HDG KNOB** wired to `citationx_set_stick_hdg`.
- **Pinned look-pair bug fixed in passing:** on R3 release the "wait for the stick to centre"
  guard read the auto-detected axis locals, which stay `-1` when `view_pan_axis_x/y` are pinned.
  It now calls `view_pan_pair()`, so a pinned pair also suppresses the heading knob until the
  stick re-centres (`smoke_mastersuite.lua` covers it).

Verification (2026-10-29): `luac -p` clean; `check_datarefs.lua` 0 problems across 5 scripts;
`check_kpcrew_modules.lua C750` 0 missing; `probe_load_order.lua` 104 bindings, 0 failures;
`smoke_mastersuite` (Axis 3/28 drive the bug, triggers/yaw/dead-slot never do, watchdog,
late-enumeration, R3 hand-off), `smoke_hud_toggles` (only `status` + `stick` ON at load),
`smoke_realism` (handling OFF at load), `smoke_efb` and `smoke_panel_geometry` (65 checks) all
pass. **In-sim check pending:** reload Lua, confirm the log has no `axis optimizer engaged/released`
lines, then push the right stick up/down — HDG SEL turns; yaw, triggers, arrow keys and the D-pad
do nothing in the suite. The thumb-button ALT SEL keys were removed on 2026-10-30 (§32); the
wheel must still zoom. If the heading direction feels inverted, set
`CONFIG.stick_hdg_invert = true`.

## 31. D-pad is a HID hat; 160-slot device stride (2026-10-30)

The PS4 D-pad never appeared in learn mode because it is not a button. X-Plane enumerates the
DS4 as 6 axes + 1 hat switch (8 positions) + 14 buttons (`Log.txt`, HID lines) and stores the
hat in the same `_joy_BUTN_use` range as the buttons:

```
device base = dev * 160
base +  0..7     hat, clockwise from up (up, up_right, right, ... up_left)
base +  8..39    physical buttons
base + 40..159   unused
```

Two consequences:

- **The suite's device stride was wrong.** It read `slot * 64 + b`, but the profile, the
  dataref (`sim/joystick/joystick_button_values` int[3200] = 20 devices x 160) and
  `initial_assignments.txt` (`(dev*160)+btn`) all use 160. Fixed in `view_pan_button_held()`,
  `citationx_autobind_joy()` and both frame scans; learn mode now logs buttons 0..319 and raw
  axes 0..31 instead of 0..127 / 0..15 (the DS4's axes arrive at 25..30).
- **The two DS4 profile blocks had diverged.** USB (device 0) had hat up/right/down/left on
  flaps/gear and only the diagonals on the view; Bluetooth (device 1) had the full 8-way hat
  view but no trim, brakes or reversers. X-Plane binds the connected pad to the lowest free
  slot, so the Bluetooth pad ran on the USB block: D-pad up retracted flaps (hence the
  `FLAP OVERSPEED 253 kt` callout during the input sweep) and never moved the view.

Fixed on 2026-10-30 with X-Plane closed, by rewriting both blocks of
`Output/preferences/X-Plane Joystick Settings.prf` identically:

| Input | Binding |
| --- | --- |
| D-pad (8 positions) | `sim/general/hat_switch_*` — native cockpit look |
| L1 | `sim/flight_controls/pitch_trim_down` |
| R1 | `sim/flight_controls/pitch_trim_up` |
| L2 / R2 | `sim/engines/throttle_down` / `throttle_up` |
| □ | `sim/flight_controls/landing_gear_toggle` |
| ○ | `sim/flight_controls/brakes_regular` (hold) |
| △ / ✕ | `sim/flight_controls/flaps_up` / `flaps_down` |
| Share | `sim/flight_controls/speed_brakes_toggle` |
| Options | `sim/engines/thrust_reverse_toggle` (all engines) |
| Touchpad | `laminar/CitX/autopilot/cmd_ap_toggle` |
| PS | `sim/flight_controls/aileron_trim_left` |
| L3 / R3 | `sim/view/3d_cockpit_cmnd_look` / `sim/view/still_spot` |

Aileron trim right has no button any more (R3 gave it up for the outside view); trim left is
still on PS. Everything else on the pad is a hard requirement from the pilot.

The button labels follow the order X-Plane gives this pad (shoulders first: L1, L2, R1, R2 =
buttons 0..3, face buttons 4..7), which is what makes L2/R2 the throttle in the live profile.

**Mouse layer** (Logi MX Master 3, keys come from Logi Options+' X-Plane profile):
thumb back `Ctrl+Shift+9`, forward `Ctrl+Shift+0`, gesture `Do Nothing`, thumb wheel unchanged.
The suite used to consume back/forward (ALT SEL) and, briefly, the gesture button and thumb
wheel (landing/taxi lights). **All of that is gone since 2026-10-30:** the Logi profile matches
its pre-session backup and the script no longer listens for any of those keys, so they reach
X-Plane and can be bound natively. `tools/joymap_gui.py` still reads the profile out of
`~/Library/Application Support/LogiOptionsPlus/settings.db` and shows what each mouse input
currently sends.

The Logi agent (`com.logi.cp-dev-mgr`) rewrites that file from memory, so editing it needs
`launchctl bootout gui/$UID/com.logi.cp-dev-mgr` first, then
`launchctl bootstrap gui/$UID /Library/LaunchAgents/com.logi.optionsplus.plist`. Backups:
`settings.db.bak-2026-10-30-231926` and `…-232106`.

**X-Plane 12 stores the mapping per aircraft.** `Miscellaneous.prf` maps the aircraft folder to a
control profile (`P acf_profile Cessna___Citation___X_mods PS4-CitationX`), and that profile lives
in `Output/preferences/control profiles/<name> - Joysticks.prf`. Editing
`X-Plane Joystick Settings.prf` — the global "User Profile" — does nothing while the aircraft has a
profile of its own; that cost a whole test cycle. `joymap.default_profile()` now resolves the
active profile from `Miscellaneous.prf` and both tools default to it. The profiles also carry
different **axis** assignments, so never swap an aircraft to "User Profile" to pick up buttons:
`PS4-CitationX` has roll/pitch/yaw on 25/26/27, the global file has throttle/roll/pitch there.

Backup: `X-Plane Joystick Settings.prf.bak-before-dpad-view-2026-10-30` next to the profile.
`tools/joymap.py` performs the same edits from the command line, refuses to run while the sim
is open and backs up before every write.

The tool also carries the full control catalog: it parses `create_command("laminar/CitX/...")`
out of `Aircraft/Cessna Citation X_mods/plugins/xlua/scripts/**/*.lua` (220 commands) and merges
it with `Resources/plugins/Commands.txt` (3144 core commands), so `commands --unbound` shows
what is still free on the pad and `set` validates against both. The gear has **no** CitX
commands — its lever is dataref-driven — so gear stays on `sim/flight_controls/landing_gear_*`.

`tools/joymap_gui.py` wraps the same library in a local web GUI (stdlib `http.server`, no
tkinter — Homebrew Python ships without Tk): a drawn DualShock 4 and mouse, green controls for
bound inputs, click-to-reassign with catalog search, undo, and a hard refusal to write while
X-Plane is running. `--self-test` exercises the page and both API endpoints headlessly.

**In-sim check pending:** the D-pad must tilt/pan the 3-D cockpit, and the button order must be
confirmed. X-Plane numbers this pad with the shoulders first — L1, L2, R1, R2 = buttons 0..3,
□ ✕ ○ △ = 4..7, Share/Options/L3/R3/PS/Touchpad = 8..13 — because L2/R2 carry throttle
down/up in the live profile, which only fits that order. If a label is off in the cockpit, it
is one table in `tools/joymap_gui.py` (`CONTROLS`).

**Reverted the same evening (pilot's request).** All of the bindings above are gone again: the two
X-Plane files were restored from `X-Plane Joystick Settings.prf.bak-before-dpad-view-2026-10-30`
and `control profiles/PS4-CitationX - Joysticks.prf.bak-2026-10-30-233044`, the Logi profile from
`settings.db.bak-2026-10-30-231926`, and `MOUSE_KEY_ACTIONS` was removed from the script. Only the
suite itself (realism pack, panels, heading knob) stays as it was. The tooling
(`tools/joymap.py`, `tools/joymap_gui.py`) and the 160-slot scan fix are kept.

## 32. Every keystroke belongs to X-Plane (2026-10-30, later)

*"ich will mein natives xplane key binding benutzen"* — the last Lua keystroke listener had to
go. `CONFIG.alt_keys_enabled` and the `Ctrl+Shift+9` / `Ctrl+Shift+0` ALT SEL block were removed
from `citationx_keystroke()`. With the input mapper OFF the function now consumes **nothing**:
`RESUME_KEY` is only set by the opt-in keyboard map (`input_map_enabled`) and the opt-in
arrow-key view tilt (`view_tilt_enabled`), both false at load. The mouse wheel was already
untouched (`thumbwheel_heading` / `thumbwheel_altitude` are false).

Profile audit after the revert:

| File | State |
| --- | --- |
| `Output/preferences/X-Plane Joystick Settings.prf` | byte-identical to `.bak-before-dpad-view-2026-10-30` |
| `control profiles/PS4-CitationX - Joysticks.prf` | byte-identical to `.bak-2026-10-30-233044` (active aircraft profile, the pilot's own mapping) |
| `control profiles/citX - Joysticks.prf` | restored from `…bak2-2026-10-27`; the two edits made today (`_joy_BUTN_use162/167`) are gone |
| Logi X-Plane profile | matches `settings.db.bak-2026-10-30-231926`: gesture `Do Nothing`, thumb wheel unchanged, back/forward still `Ctrl+Shift+9/0` |

The heading knob on DS4 Axis 3 stays (the pilot's explicit 2026-10-29 request); it reads an axis,
not a key, and `_joy_AXIS_use3` / `_joy_AXIS_use28` are unassigned in the profile so it cannot
fight a native binding. Turn it off with `CitationXSuite/toggle_stick_hdg` or
`CONFIG.stick_hdg_enabled = false` if even that should be native.

Validation: `luac -p` clean; `check_datarefs` 0 problems; `probe_load_order` 104 bindings, 0
failures; `smoke_hud_toggles` now asserts the ALT SEL layer is gone and `Ctrl+Shift+0/9` pass
through; mastersuite, realism, EFB and panel geometry all pass.

## Not yet verified in-sim

Everything below passed offline harnesses but has **never been seen in X-Plane**. Do not
record these as confirmed working:

- The **visual result** of the 14-row control panel (telemetry body and C750 systems panel
  removed). Geometry is measured, not assumed (`tests/smoke_panel_geometry.lua`: 65 checks —
  panels fit the screen, no vertical text collisions, no text overflowing its panel, drag moves
  each panel, click sweep reaches every row). What remains unproven is purely aesthetic:
  whether `row_h = 21` reads well and whether the panels still clear each other at other
  resolutions.
- The **realism pack in flight**: callout timing (V1/rotate/positive rate/gear up/1000/500/100/
  minimums/stable/unstable), whether the synthesized WAVs are audible over engine noise, whether
  the load-shed/brake-fan thresholds match what the aircraft actually does, and whether the new
  Vmo/takeoff-config/gear-down/anti-ice/cabin-altitude triggers are free of false positives.
- The **black realism panel**: 16 rows at 430 px, Helvetica glyphs, and its click targets. The
  geometry harness measures it, but no human has looked at it in the 3D cockpit.
- The **handling curve**: whether deadzone 0.02 / expo 1.35 / smoothing 0.55 feels right on the
  DS4, and whether the control check is asked at a sensible moment (it needs 60 % travel on all
  three axes before the thrust levers advance).
- The **8K cockpit textures**: the panel is a 8192² dark Cascade 3 PNG with an 8192² DXT5
  fallback, the overall/cabin are 8192² DXT5 and the seat is 4096² DXT5. File dimensions, mip
  counts and 1:1 crops were verified, but nothing has been seen in the 3D cockpit or with the
  simulator's texture-resolution cap. The dark panel is a deliberate finish change, not just a
  resolution upgrade; the light 8K transplant is backed up.
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

In-sim status: the suite loaded cleanly on 2026-10-21 at 18:22 and again on 2026-10-23 01:00
(`All script files loaded successfully`, 0 `FlyWithLua Error`). The 2026-10-23 load also logged
`Citation X Realism: loaded` with `12/12 callout sounds loaded`. **No clean load has happened
since the 2026-10-26 duplicate-writable and keyboard fixes**, so the current 22-sound load, the
16-row black panel, the new monitors, the panel reskin/drag and the R3 cockpit look have never
run in X-Plane. What has **not** been reviewed by eye/ear: the control panel without the
telemetry body, the callouts during a real takeoff/approach, the load-shed/brake-fan behaviour,
the dark interior pass, the AviTab in-cockpit screen on `..._AviTab_mods`, and whether the
head-offset datarefs actually pan in 12.4.3.

## Validation performed
- `luac -p` on every script in `Scripts/`, including the KPCrew ones.
- Every `dataref(...)` declaration in `Scripts/CitationX_*.lua` checked with
  `tests/check_datarefs.lua`: 0 problems across 5 suite scripts (104 bindings, including the
  three cockpit-look refs).
- Every `require()` reachable for the C750 checked with
  `tests/check_kpcrew_modules.lua C750`: 0 missing (`--all` sweeps every aircraft).
- Every `laminar/CitX/...` command and runtime dataref checked against the Citation X's own
  `plugins/xlua/scripts/*.lua`.
- Mock-FlyWithLua smoke tests, all run under **luajit** (the sim's Lua, see below):
  - `tests/smoke_mastersuite.lua` — DS4 heading: triggers ignored, sticky lock, dead-slot
    recovery, and the late-enumeration regression (rest `-0.01` before the pad is live); plus
    R3 cockpit look (yaw, pitch, heading suppression, resume, hold at centre).
  - `tests/smoke_hud_toggles.lua` — 14 rows well formed, unique keys, sibling toggles safe
    with the other scripts absent, overlay draws zero primitives when everything is off, and
    only the realism panel + hub are visible at load.
  - `tests/smoke_realism.lua` — takeoff/approach callouts fire once, gear-up delay, load-shed
    command after generator loss, brake fan on/off, flap overspeed, icing, Vmo, takeoff config,
    stabilised approach, gear-down, anti-ice, cabin altitude, the handling curve and the HUD's
    draw/click/drag behaviour.
  - `tests/smoke_panel_geometry.lua` — renders all five panels into a recording canvas and
    asserts: everything fits 2560×1440 (and the realism panel at 1280×720), no vertical text
    collisions, no text overflows its panel, the default positions do not collide, a click
    sweep reaches every row, and every header drag moves its panel by the mouse delta
    (65 checks).
  - `tests/probe_load_order.lua` — loads all of `Scripts/` in one shared LuaJIT state in
    FlyWithLua's alphabetical order. The authoritative load test.

## Gotchas / facts
- A bad DataRef anywhere in a script makes FlyWithLua quarantine the whole file and reload Lua.
  Check `Log.txt` for `FlyWithLua Error:` and `Moved Bad Script`.
- Two scripts may not bind the same DataRef **writable**; the later script is quarantined even
  if its logic would never write. Read-only duplicates are fine. `probe_load_order.lua` now
  flags this.
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
- `sim/operation/override/override_joystick_pitch` / `_roll` have exactly **one owner at a
  time**. The realism handling curve and the MasterSuite axis optimizer both want them; the
  realism curve backs off when `CONFIG.axis_optimizer_enabled` is true **and must not write 0
  in that state**, or the optimizer is left driving an override it no longer owns.
- The realism panel and the Master Suite hub are the suite's drawn surfaces at load. They show
  realism/subsystem state (load shed, brake energy, icing, overspeed, config, approach, handling,
  panel toggles), never airspeed/altitude/heading/fuel — those stay on the PFD/EICAS. Every
  other panel is opt-in; axis monitor and learn mode remain explicit diagnostics.

## Repo, agent & deployment
- Git initialized in place in the FlyWithLua folder; `.gitignore` tracks only the five
  Citation X scripts, `CitationX_Callouts/*.wav`, `tests/`, docs (`README.md`, `AGENTS.md`,
  `CONTEXT.md`) and the project agent. Plugin binaries, Modules, Internals, Documentation and
  runtime files stay untracked.
- Private remote: <https://github.com/ModernAmusements/citationx-suite>
- Project agent: `.opencode/agents/citationx.md` (mode `all`), rules in `AGENTS.md`.
- Test harnesses (all under `tests/`): `check_datarefs.lua`, `check_kpcrew_modules.lua`,
  `probe_kpcrew.lua`, `probe_kpcrew_run.lua`, `probe_load_order.lua`,
  `smoke_mastersuite.lua`, `smoke_hud_toggles.lua`, `smoke_realism.lua`,
  `smoke_efb.lua`, `smoke_panel_geometry.lua`.
- Deploy = edit live scripts in place, validate, commit and push; reload FlyWithLua in-sim.
  Textures are outside the repo and need an aircraft reload, not a Lua reload.

## Tuning knobs
- Control panel: `SUITE_STYLE` (`x`, `top`, `row_h`, `header_h`, `footer_h`, `pad`, `width`) in
  `CitationX_MasterSuite.lua`; `CAB_CONFIG.row_h` / `panel_x` / `panel_top` in
  `CitationX_CabinOps.lua`; `TRAINER_CONFIG.row_h` / `panel_x` / `panel_top` in
  `CitationX_FailureTrainer.lua`; `EFB_CONFIG.row_h` / `panel_x` / `panel_top` in
  `CitationX_EFB.lua`; `REAL_STYLE.x` / `y` in `CitationX_Realism.lua`.
- 3-D cockpit look: `CONFIG.view_pan_*` — `view_pan_button` (0-based, default 11 = R3),
  `view_pan_axis_x` / `view_pan_axis_y` (-1 auto, DS4 2/3), `view_pan_rate_dps`,
  `view_pan_deadzone`, `view_pan_invert_x` / `view_pan_invert_y`, `view_pan_pitch_limit`,
  `view_pan_force_3d`.
- Heading knob: `CONFIG` in `CitationX_MasterSuite.lua`; `stick_hdg_axis` can be pinned to a
  RAW index shown by AXIS MONITOR, or slots vetoed via `stick_hdg_exclude_axes`.
- Realism pack: `REAL_CONFIG` in `CitationX_Realism.lua` — `v1_kt`/`vr_kt`/`vref_kt`/`vfe_kt`/
  `vle_kt`, `minima_ft`, `elec_min_bus_v`/`elec_shed_interval`/`elec_max_sheds`,
  `brake_hot_j`/`brake_cool_j`, `flap15_vfe_kt`, `ice_oat_min_c`/`ice_oat_max_c`,
  `vmo_low_kt`/`vmo_high_kt`/`mmo`, `to_throttle_ratio`/`to_flap_max_ratio`,
  `stable_agl_ft`/`stable_vref_plus`/`stable_max_vs_fpm`, `anti_ice_repeat_s`,
  `cabin_alt_limit_ft`, `handling_deadzone`/`handling_exponent`/`handling_smoothing`,
  `control_check_travel`.
- Realism panel: `REAL_STYLE` in `CitationX_Realism.lua` — `x`, `top`, `width`, `pad`,
  `header_h`, `row_h`, `footer_h` and the black/white/green/amber/red palette.
  `REAL_CONFIG.hud_enabled` hides it; `CitationXRealism/hud` and the macro *realism panel*
  toggle it.
- Textures: the pre-2026-10-26 sharpened originals and pre-8K interior are in
  `Aircraft/Cessna Citation X AviTab_mods/_texture_backups/2026-10-26_cockpit_highres/`; the light
  8K panel (and every removed livery panel DDS) is in
  `_texture_backups/2026-10-26_dark_panel/`; pre-sharpening originals are in
  `_original_textures/`. Restore a set and reload the aircraft to undo.

## 2026-10-31 — v3.0: no keyboard layer, EFB checklist/route, AviTab

### What changed
- **Every Lua input path is gone.** `CitationX_MasterSuite.lua` v3.0 has no
  `do_on_keystroke`, no controller-button map, no mouse-thumb-button ALT SEL layer, no
  autobind, no R3 view pan and no axis-to-heading-bug knob. `CONFIG.stick_hdg_*`,
  `INPUT_BINDINGS`, `CITX_BINDINGS`, `JOY_BINDINGS`, `joy_autobind_enabled`,
  `alt_keys_enabled`, `input_map_enabled` and `learn_mode` no longer exist; the smoke tests
  assert their absence so they cannot creep back.
- **The one input the suite reads is the mouse wheel** (`do_on_mouse_wheel`), because the
  pilot asked for it explicitly: main wheel → `sim/cockpit2/autopilot/altitude_dial_ft`
  (±100 ft), thumbwheel → `sim/cockpit2/autopilot/heading_dial_deg_mag_pilot` (±1°). X-Plane
  reports which wheel moved in `MOUSE_WHEEL_NUMBER`; `wheel_altitude_number` /
  `wheel_heading_number` (1 / 2 by default) plus `CitationXSuite/wheel_map_swap` and
  `CitationXSuite/wheel_report` cover a mouse that enumerates them the other way round.
  `RESUME_MOUSE_WHEEL = true` stops the notch from also zooming the view.
- **Mouse actions are commands, not captures.** `CitationXSuite/taxi_light_toggle` and
  `CitationXSuite/landing_lights_toggle` run `sim/lights/taxi_lights_toggle` /
  `sim/lights/landing_lights_toggle`. FlyWithLua cannot see individual mouse buttons, so a
  middle click or gesture has to be pointed at these commands by the mouse driver (Logi
  Options+, SteerMouse) or bound in X-Plane. Do not add a keystroke handler for them.
- **Aircraft texture cycler.** Panel row `texture` runs X-Plane's own
  `sim/operation/next_livery` / `prev_livery`; the label comes from `acf_livery_path`, which is
  a *slow* dataref, so it is cached and refreshed at 1 Hz (`livery_label(true)` forces it).
- **EFB v2.** Four pages. CHECK parses the pilot's real `clist.txt`
  (`Aircraft/Cessna Citation X_mods/clist.txt`, the file Xchecklist loads): 188 `sw_item`
  lines → 15 phases, 128 items carry a dataref expression. `efb_eval_expr` is a small
  recursive evaluator for the Xchecklist grammar (`&&`, `||`, parentheses, `= ! < > <= >=`,
  `a|b` intervals); history tests (`+>`, `-<`, `><`, `a:b`) deliberately never auto-tick.
  ROUTE is the flight-plan maker: on-screen 40-key ICAO keypad (`efb_route_press`), great-circle
  distance/track/time, and `efb_route_build` writes a 1100-format `.fms` to
  `Output/FMS plans/<DEP>-<DEST>.fms` (or `EFB_CONFIG.route_out_dir`). The airport index is
  `Scripts/CitationX_Airports.csv`, 16,398 rows generated from
  `Global Scenery/Global Airports/Earth nav data/apt.dat` (`ICAO,lat,lon,elev`); it is loaded
  lazily on the first ROUTE use, not at script load.
- **Realism panel is instruments, not numbers.** Every row leads with a state LED; trim, fuel
  balance, weight, crosswind, brake energy and bus voltage draw a bar gauge (`hud_gauge`) with
  a green band and a red limit tick. The words are status only (`GREEN`, `OUT`, `BAL`,
  `IMBAL`, `OK`, `OVER`, `XWIND`, `HOT`, `COOL`, `SHED`); the numbers moved to Log.txt.
- **AviTab 0.7.1 installed** in `Resources/plugins/AviTab/` (universal binary, arm64 OK). The
  suite only forwards to AviTab's API (`AviTab/app_charts|app_maps|app_routes|app_airports`,
  `AviTab/toggle_tablet|recentre|zoom_in|zoom_out`) and reports its map position/zoom from
  `avitab/map/*`. There is **no** AviTab API to host or control a third-party app, so FlyCharts
  (an Electron app that reads X-Plane over UDP 49000) can only run beside the sim.

### Gotchas found this session
- `luac` (Lua 5.5) rejects `for line in fd:lines() do line = ...` — loop variables are const
  from 5.2. Rename the loop variable (`for raw in ... do local line = trim(raw)`).
- `line:sub(1, 9) == "sw_item:"` can never match: the prefix is 8 characters. Use
  `line:match("^sw_item:")`.
- `byte[]` datarefs (`acf_livery_path`, `acf_relative_path`) are read with `dataref_table`
  but never need an index; `tests/probe_load_order.lua` now treats `byte[]` as table-able
  (`needs_index` only matches `[N]`).
- `function control_panel_height()` assigned to a `local control_panel_height` forward
  declaration stays local. The public mirror is `citationx_panel_height()`.
- A toast stays on screen for 2 s of *sim* time; tests that assert "nothing is drawn" must
  advance `citationx_sim_time` first.
