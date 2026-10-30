# Citation X Suite for FlyWithLua (X-Plane 12)

Five FlyWithLua NG+ scripts for the Laminar Research Cessna Citation X (C750), plus a
standalone landing-performance scorer.

## Scripts

| File | Purpose |
| --- | --- |
| `Scripts/CitationX_MasterSuite.lua` | 1 Hz flight recorder CSV, axis optimizer, key/button input mapper, spring-loaded heading-bug knob on the PS4 right stick (L2/R2 triggers explicitly ignored), 3-D cockpit look on right-stick click (R3) + right-stick movement, free-controller-button autobind (only buttons X-Plane reports unassigned), simulated bleed-air/pressurization emergency, and the draggable control panel that toggles every suite subsystem. No telemetry HUD. |
| `Scripts/CitationX_FailureTrainer.lua` | QRH-style failure scenarios (engine fire, generator trip, bleed air, boost pump, flameout, APU fire, hydraulics) with checklists that self-check against the aircraft's own datarefs. |
| `Scripts/CitationX_CabinOps.lua` | Boarding / ground-power / cabin-lights flow with a clickable panel, passenger progress and automatic phase handling. |
| `Scripts/CitationX_EFB.lua` | Electronic flight bag panel: PERF (density altitude, wind components, V1/VR/V2/Vref, takeoff and landing distance by runway condition), CHECK (interactive 8-phase checklists) and FUEL (trip/contingency/alternate/reserve/endurance). Advisory data only. |
| `Scripts/CitationX_Realism.lua` | Realism pack with one black, sans-serif (Helvetica) panel: live state of every realism subsystem plus clickable toggles. Behind it: audio callouts (V1, rotate, positive rate, gear up/down, 1000/500/100, minimums, stable/unstable, fuel imbalance, crosswind, overweight) on FlyWithLua's FMOD master bus; pilot-input handling curve (deadzone/expo/smoothing); flight-controls check; takeoff trim/flap gate; fuel-balance monitor; MTOW/MLW weight limits; electrical load manager that drives the aircraft's own LOAD SHED switch; brake-energy monitor that runs the brake fan; Vmo/Mmo overspeed, takeoff-config, flap/gear overspeed, anti-ice-off, icing, cabin-altitude and crosswind advisories (each also raises a 2 s toast). |
| `Scripts/LandingPerformance.lua` | Standalone landing scoring and debrief card (third-party, untracked in git). |

## Control panel

**Two panels are on screen at load: the black realism panel and the Master Suite hub.**
The suite does not touch the pilot's input map — no keystroke is consumed at load, so every key
binding belongs to X-Plane's own profile. The one exception is the DS4 right-stick **STICK HDG
KNOB** (X-Plane "Axis 3"), which turns the heading bug and draws nothing. The keyboard mapper,
the joystick-button map, the mouse thumb-button ALT SEL keys, the R3 cockpit look, the axis
optimizer and the realism handling curve all start OFF. Every panel starts hidden and is opened
from a hub row, the FlyWithLua macro menu or the commands below.
Two macros flip the whole suite: `CitationX Suite: enable all modules` /
`disable all modules`.

All five panels share the realism panel's language: black body, grey 1 px border, white
Helvetica 18 title, grey 10 px sub-header, 12 px rows, 21 px row pitch and a 34 px footer with
a **HIDE PANEL** button. **Drag any panel by its header** to move it; the position is kept for
the session. The hub and the realism panel start side by side at the top-left.

The hub lists every subsystem with a live state. Click a row to toggle it.
The same toggles are available as X-Plane commands (`CitationXSuite/toggle_<key>`) and as
FlyWithLua macro menu entries.

The MasterSuite panel is the only surface *it* draws. There is no telemetry HUD and no C750
systems readback: the aircraft's PFD, EICAS and synoptics already show airspeed, altitude,
heading, Mach, G, fuel flow, electrics, fuel and anti-ice, so duplicating them on screen adds
nothing. The realism pack's own black panel is separate and is described above.

| Row | Key | What it toggles |
| --- | --- | --- |
| CONTROL PANEL | `status` | This panel itself |
| AXIS OPTIMIZER | `axis` | Custom pitch/roll response curve |
| FLIGHT RECORDER | `log` | 1 Hz CSV recorder |
| EMERGENCY GEN | `emerg` | Bleed-air / pressurization emergency triggers |
| INPUT MAPPER | `input` | Keyboard/mouse/joystick binding engine |
| LEARN MODE | `learn` | Input probe overlay |
| STICK HDG KNOB | `stick` | Heading bug on the right stick |
| AXIS MONITOR | `axmon` | Raw axis overlay |
| COCKPIT LOOK | `look` | R3 + right stick 3-D cockpit look |
| CABIN OPS | `cabin` | `CitationX_CabinOps` panel |
| QRH TRAINER | `qrh` | `CitationX_FailureTrainer` panel |
| LANDING PERF | `landperf` | `LandingPerformance` result card |
| EFB | `efb` | `CitationX_EFB` panel (PERF / CHECK / FUEL) |
| REALISM PACK | `realism` | `CitationX_Realism` callouts and load manager |

The sibling rows are nil-guarded: if that script is not installed the row shows
`ABSENT` and clicking it does nothing.

### 3-D cockpit look

Hold the right stick click (DS4 **R3**, button 11) and move the right stick: the view pans in
the 3-D cockpit, and pressing R3 from a 2-D view switches to the 3-D cockpit first. While R3 is
held the stick does **not** move the heading bug; release it and the knob resumes exactly where
it was. The look axes are auto-detected as the spring-centred pair the stick belongs to
(DS4 raw 2/3); pin them with `view_pan_axis_x` / `view_pan_axis_y` if your pad differs.
`view_pan_button` selects a different button, and `view_pan_invert_x` / `view_pan_invert_y`
flip the direction. R3 is excluded from free-button autobind.

## Requirements

- X-Plane 12
- FlyWithLua NG+ 2.8 or newer (mac / win / lin build)
- Laminar Research Cessna Citation X (most features degrade gracefully in other aircraft)

## Install

Copy the `Scripts/CitationX_*.lua` files into:

```
X-Plane 12/Resources/plugins/FlyWithLua/Scripts/
```

Then **restart X-Plane** (or reload the scripts from the FlyWithLua menu). This
repository is designed to live directly inside that folder: git tracks only the first-party
suite, while the rest of the FlyWithLua install (binaries, Modules, Internals, Documentation)
stays untracked via `.gitignore`.

> **FlyWithLua 2.8.16 and older:** *Reload all Lua script files* can crash X-Plane while it
> tears down the realism pack's FMOD sounds. This install is on **2.8.20** (2026-10-23), which
> contains the upstream fix; if you ever roll the plugin back, quit and restart the sim after
> changing scripts instead of reloading.

## Configuration

- `CitationX_MasterSuite.lua` — `CONFIG` table: flight recorder, axis optimizer,
  emergency generator, input mapper, `joy_autobind_enabled` / `joy_map_enabled` (the
  free-controller-button map), the right-stick heading knob
  (`stick_hdg_*`: `stick_hdg_axes = { 3, 28 }` pins DS4 Axis 3 over USB/Bluetooth,
  `stick_hdg_exclude_axes` adds vetoes) and the 3-D cockpit look
  (`view_pan_*`: button, axis pair, rate, inversion, 3-D switch). No keystroke is
  captured while the input mapper is off.
  Panel layout lives in `SUITE_STYLE` (`row_h`, `header_h`, `footer_h`, `pad`, `x`/`top`).
- `CitationX_CabinOps.lua` — `CAB_CONFIG` (`row_h` controls row spacing).
- `CitationX_FailureTrainer.lua` — `TRAINER_CONFIG` (`row_h` controls row spacing).
- `CitationX_Realism.lua` — `REAL_CONFIG`: callout speeds (V1/Vr/Vref/Vfe/Vle), Vmo/Mmo,
  minima, load-shed threshold, brake-energy limits, icing window, anti-ice/cabin-altitude
  triggers, stabilised-approach gate, takeoff trim/flap gate (`to_flap_*`,
  `to_trim_tolerance`), fuel balance (`fuel_imbalance_lb`, `fuel_rearm_lb`,
  `fuel_imbalance_delay_s`), weight limits (`mtow_lb`, `mlw_lb`), crosswind
  (`crosswind_limit_kt`), handling curve (`handling_deadzone`, `handling_exponent`,
  `handling_smoothing`), control-check travel, `audio_backend` (`auto`/`fmod`/`wav`) and
  `toasts_enabled`.

## Bindable commands

```
CitationXSuite/toggle_status
CitationXSuite/toggle_axis     CitationXSuite/toggle_log      CitationXSuite/toggle_emerg
CitationXSuite/toggle_input    CitationXSuite/toggle_learn    CitationXSuite/toggle_stick
CitationXSuite/toggle_axmon    CitationXSuite/toggle_look     CitationXSuite/toggle_cabin
CitationXSuite/toggle_qrh      CitationXSuite/toggle_landperf CitationXSuite/toggle_efb
CitationXSuite/toggle_realism

CitationXQRH/*                 CabinOps/*                    CitationXRealism/*
```

## Development and validation

```sh
# syntax check every script in Scripts/
luac -p Scripts/*.lua

# every dataref() binding is legal: the ref exists and array refs carry an index
for f in Scripts/CitationX_*.lua; do
  lua tests/check_datarefs.lua ../../Resources/plugins/DataRefs.txt "$f"
done

# every require() reachable for the C750 resolves on disk (--all sweeps every aircraft)
lua tests/check_kpcrew_modules.lua C750

# mock-FlyWithLua smoke tests
export TMPDIR="$(mktemp -d)/"
HOME="$TMPDIR" TMPDIR="$TMPDIR" lua tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" lua tests/smoke_hud_toggles.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" lua tests/smoke_realism.lua Scripts/CitationX_Realism.lua
```

Every DataRef used by the scripts must exist in
`Resources/plugins/DataRefs.txt` (or be a runtime `laminar/CitX/...` dataref registered by the
aircraft's xlua plugin). A single invalid DataRef makes FlyWithLua quarantine the whole script.

If X-Plane is available, load a flight and check `Log.txt` for `FlyWithLua Error`. The
"DataRef ... is already handled in variable ..." lines are informational, not errors.

See `CONTEXT.md` for the engineering history and `AGENTS.md` for contribution rules.

## Offline joystick mapper

`tools/joymap.py` reads and writes the saved X-Plane joystick profile, so a controller can be
re-mapped **with X-Plane closed** — the in-sim LEARN MODE can only record while the sim runs.
It also knows every control of the aircraft: the 220 `laminar/CitX/...` commands the Citation X
registers from its xlua scripts, plus the core `sim/...` commands from `Commands.txt`.

```sh
python3 tools/joymap.py list                       # devices + every assignment
python3 tools/joymap.py show 0                     # one device
python3 tools/joymap.py set 0 hat_up sim/general/hat_switch_up
python3 tools/joymap.py set 0 btn13 laminar/CitX/lights/cmd_taxi_toggle
python3 tools/joymap.py commands                   # the 220 Citation X controls
python3 tools/joymap.py commands lights            # search names + descriptions
python3 tools/joymap.py commands --unbound         # what is still free
python3 tools/joymap.py commands gear --core       # core sim/ commands
python3 tools/joymap.py axes                       # axis assignments
python3 tools/joymap.py clear 0 btn13
python3 tools/joymap.py check                      # every binding exists in the catalog
python3 tools/joymap.py log                        # hardware X-Plane last enumerated
python3 tools/joymap.py restore                    # undo the last write (repeatable)
```

A `*` in the `commands` listing marks a command that is already bound. Inputs are `hat_up`,
`hat_up_right`, `hat_right`, `hat_down_right`, `hat_down`, `hat_down_left`, `hat_left`,
`hat_up_left`, `btn0`..`btn31`, or a raw `slotN`. Each device owns 160 slots: `0..7` is the
8-position hat, `8..39` the physical buttons. The tool refuses to write while X-Plane is
running (the sim rewrites the profile on exit) and takes a timestamped `.bak-*` copy first.
The aircraft folder is auto-detected from `Aircraft/*/Cessna_CitationX.acf`; override it with
`--aircraft PATH`.

### GUI

```sh
python3 tools/joymap_gui.py          # opens http://127.0.0.1:8765/ in the browser
python3 tools/joymap_gui.py --self-test
```

A DualShock 4 and a mouse are drawn on one page: every bound control is green, clicking one
shows its command and opens the catalog search, and picking a command writes the binding
(backup first, undo button included). It is served by Python's standard library — no packages,
no tkinter (Homebrew Python ships without Tk). X-Plane must be closed; the page says so and
refuses to write while the sim runs.

## Repository

Private: <https://github.com/ModernAmusements/citationx-suite>
