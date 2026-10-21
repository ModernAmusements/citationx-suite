# Citation X Suite for FlyWithLua (X-Plane 12)

Three FlyWithLua NG+ scripts for the Laminar Research Cessna Citation X (C750), plus a
standalone landing-performance scorer.

## Scripts

| File | Purpose |
| --- | --- |
| `Scripts/CitationX_MasterSuite.lua` | Telemetry HUD, C750 systems readback, 1 Hz flight recorder CSV, axis optimizer, key/button input mapper, spring-loaded heading-bug knob on the PS4 right stick (L2/R2 triggers explicitly ignored), and the master status panel that toggles every suite subsystem by clicking a row. |
| `Scripts/CitationX_FailureTrainer.lua` | QRH-style failure scenarios (engine fire, generator trip, bleed air, boost pump, flameout, APU fire, hydraulics) with checklists that self-check against the aircraft's own datarefs. |
| `Scripts/CitationX_CabinOps.lua` | Boarding / ground-power / cabin-lights flow with a clickable panel, passenger progress and automatic phase handling. |
| `Scripts/LandingPerformance.lua` | Standalone landing scoring and debrief card (third-party, untracked in git). |

## HUD status panel

The left-hand panel lists every subsystem with a live ON/OFF state. Click a row to toggle it.
The same toggles are available as X-Plane commands (`CitationXSuite/toggle_<key>`) and as
FlyWithLua macro menu entries.

| Row | Key | What it toggles |
| --- | --- | --- |
| HUD DISPLAY | `hud` | The telemetry body (MACH / IAS / ALT / G-LOAD …) |
| STATUS PANEL | `status` | This panel itself |
| C750 PANEL | `systems` | The right-hand C750 systems readback |
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

The three sibling rows are nil-guarded: if that script is not installed the row shows
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

- `CitationX_MasterSuite.lua` — `CONFIG` table: HUD, flight recorder, axis optimizer,
  emergency generator, input mapper and the right-stick heading knob
  (`stick_hdg_*`, including `stick_hdg_exclude_axes` and a fixed `stick_hdg_axis` pin).
  Panel layout lives in `HUD_STYLE` (`row_h`, `status_row_h`, `sys_row_h`, and the
  C750 panel's `sys_*` values).
- `CitationX_CabinOps.lua` — `CAB_CONFIG` (`row_h` controls row spacing).
- `CitationX_FailureTrainer.lua` — `TRAINER_CONFIG` (`row_h` controls row spacing).

## Bindable commands

```
CitationXSuite/toggle_hud      CitationXSuite/toggle_status   CitationXSuite/toggle_systems
CitationXSuite/toggle_axis     CitationXSuite/toggle_log      CitationXSuite/toggle_emerg
CitationXSuite/toggle_input    CitationXSuite/toggle_learn    CitationXSuite/toggle_stick
CitationXSuite/toggle_axmon    CitationXSuite/toggle_cabin    CitationXSuite/toggle_qrh
CitationXSuite/toggle_landperf

CitationXQRH/*                 CabinOps/*
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
```

Every DataRef used by the scripts must exist in
`Resources/plugins/DataRefs.txt` (or be a runtime `laminar/CitX/...` dataref registered by the
aircraft's xlua plugin). A single invalid DataRef makes FlyWithLua quarantine the whole script.

If X-Plane is available, load a flight and check `Log.txt` for `FlyWithLua Error`. The
"DataRef ... is already handled in variable ..." lines are informational, not errors.

See `CONTEXT.md` for the engineering history and `AGENTS.md` for contribution rules.

## Repository

Private: <https://github.com/ModernAmusements/citationx-suite>
