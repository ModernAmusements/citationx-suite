# FlyWithLua / Citation X Suite — session context

Last updated: 2026-10-19

## Environment
- X-Plane 12: `/Users/modernamusmenet/X-Plane 12` (macOS, arm64)
- FlyWithLua NG+ 2.8.16 (mac_x64)
- Active scripts in `Scripts/`: `CitationX_MasterSuite.lua`, `CitationX_FailureTrainer.lua`,
  `CitationX_CabinOps.lua`, `CitationX_MissionGenerator.lua`, `LandingPerformance.lua`
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
- Out-and-back: reach a generated fix (bearing + distance), return home, full stop within 3 NM.
- Mission types: TURNAROUND, ALTITUDE RUN, FAST LANE (mach hold), FUEL DISCIPLINE, EMERGENCY
  SORTIE (uses `qrh_inject_by_key("flameout_l")` if Failure Trainer is loaded, otherwise fires
  `sim/operation/failures/rel_engfla0` directly and clears it afterwards).
- Rules (2–4 random): speed ≤ 250 KT below 10K, bank ≤ 35°, g-load −0.3…+2.5, mach ≤ 0.87,
  touchdown ≥ −300 fpm, reserve fuel on landing.
- Four difficulties scale distance/clock/score. Streak, best score, completed count persist in
  `Scripts/CitationX_MissionProgress.txt`.
- Commands/macros: `MissionGen/generate`, `MissionGen/abort`, `MissionGen/toggle_panel`,
  `MissionGen/report`.

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

## Validation performed
- `luac -p` on every active script.
- Every `dataref(...)` path checked against `Resources/plugins/DataRefs.txt`.
- Every `laminar/CitX/...` command and runtime dataref checked against the Citation X's own
  `plugins/xlua/scripts/*.lua`.
- Mock-FlyWithLua smoke tests (Lua 5.4) for mission generate/takeoff/fix/landing/scoring/
  persistence/emergency and for the DS4 heading logic (triggers ignored, sticky lock, dead-slot
  recovery).

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
