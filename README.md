# Citation X Suite for FlyWithLua (X-Plane 12)

Three FlyWithLua NG+ scripts for the Laminar Research Cessna Citation X (C750), plus a
standalone landing-performance scorer.

## Scripts

| File | Purpose |
| --- | --- |
| `Scripts/CitationX_MasterSuite.lua` | 1 Hz flight recorder CSV, axis optimizer, key/button input mapper, spring-loaded heading-bug knob on the PS4 right stick (L2/R2 triggers explicitly ignored), simulated bleed-air/pressurization emergency, and the control panel that toggles every suite subsystem. No telemetry HUD. |
| `Scripts/CitationX_FailureTrainer.lua` | QRH-style failure scenarios (engine fire, generator trip, bleed air, boost pump, flameout, APU fire, hydraulics) with checklists that self-check against the aircraft's own datarefs. |
| `Scripts/CitationX_CabinOps.lua` | Boarding / ground-power / cabin-lights flow with a clickable panel, passenger progress and automatic phase handling. |
| `Scripts/CitationX_EFB.lua` | Electronic flight bag panel: PERF (density altitude, wind components, V1/VR/V2/Vref, takeoff and landing distance by runway condition), CHECK (interactive 8-phase checklists) and FUEL (trip/contingency/alternate/reserve/endurance). Advisory data only. |
| `Scripts/CitationX_Realism.lua` | Invisible realism pack: audio takeoff/approach callouts (V1, rotate, positive rate, gear up, 1000/500/100, minimums), electrical load manager that drives the aircraft's own LOAD SHED switch after a generator loss, brake-energy monitor that runs the brake fan, flap/gear overspeed and icing callouts. No on-screen drawing. |
| `Scripts/LandingPerformance.lua` | Standalone landing scoring and debrief card (third-party, untracked in git). |

## Control panel

The left-hand panel lists every subsystem with a live state. Click a row to toggle it.
The same toggles are available as X-Plane commands (`CitationXSuite/toggle_<key>`) and as
FlyWithLua macro menu entries.

This is the **only** thing the suite draws. There is no telemetry HUD and no C750 systems
readback: the aircraft's PFD, EICAS and synoptics already show airspeed, altitude, heading,
Mach, G, fuel flow, electrics, fuel and anti-ice, so duplicating them on screen adds nothing.

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
| CABIN OPS | `cabin` | `CitationX_CabinOps` panel |
| QRH TRAINER | `qrh` | `CitationX_FailureTrainer` panel |
| LANDING PERF | `landperf` | `LandingPerformance` result card |
| EFB | `efb` | `CitationX_EFB` panel (PERF / CHECK / FUEL) |
| REALISM PACK | `realism` | `CitationX_Realism` callouts and load manager |

The sibling rows are nil-guarded: if that script is not installed the row shows
`ABSENT` and clicking it does nothing.

## Requirements

- X-Plane 12
- FlyWithLua NG+ 2.8 or newer (mac / win / lin build)
- Laminar Research Cessna Citation X (most features degrade gracefully in other aircraft)

## Install

Copy the `Scripts/CitationX_*.lua` files into:

```
X-Plane 12/Resources/plugins/FlyWithLua/Scripts/
```

Then reload the scripts from the FlyWithLua menu (*Reload all Lua script files*). This
repository is designed to live directly inside that folder: git tracks only the first-party
suite, while the rest of the FlyWithLua install (binaries, Modules, Internals, Documentation)
stays untracked via `.gitignore`.

## Configuration

- `CitationX_MasterSuite.lua` — `CONFIG` table: flight recorder, axis optimizer,
  emergency generator, input mapper and the right-stick heading knob
  (`stick_hdg_*`, including `stick_hdg_exclude_axes` and a fixed `stick_hdg_axis` pin).
  Panel layout lives in `SUITE_STYLE` (`status_row_h` and the panel geometry).
- `CitationX_CabinOps.lua` — `CAB_CONFIG` (`row_h` controls row spacing).
- `CitationX_FailureTrainer.lua` — `TRAINER_CONFIG` (`row_h` controls row spacing).
- `CitationX_Realism.lua` — `REAL_CONFIG`: callout speeds (V1/Vr/Vref/Vfe/Vle),
  minima, load-shed threshold, brake-energy limits, icing window.

## Bindable commands

```
CitationXSuite/toggle_status
CitationXSuite/toggle_axis     CitationXSuite/toggle_log      CitationXSuite/toggle_emerg
CitationXSuite/toggle_input    CitationXSuite/toggle_learn    CitationXSuite/toggle_stick
CitationXSuite/toggle_axmon    CitationXSuite/toggle_cabin    CitationXSuite/toggle_qrh
CitationXSuite/toggle_landperf CitationXSuite/toggle_efb    CitationXSuite/toggle_realism

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

## Repository

Private: <https://github.com/ModernAmusements/citationx-suite>
