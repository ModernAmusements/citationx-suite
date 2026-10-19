# Citation X Suite for FlyWithLua (X-Plane 12)

Four FlyWithLua NG+ scripts for the Laminar Research Cessna Citation X (C750), plus a
random-mission generator that turns free flight into a scored challenge.

## Scripts

| File | Purpose |
| --- | --- |
| `Scripts/CitationX_MasterSuite.lua` | Telemetry HUD, C750 systems readback, 1 Hz flight recorder CSV, axis optimizer, key/button input mapper, spring-loaded heading-bug knob on the PS4 right stick (L2/R2 triggers explicitly ignored). |
| `Scripts/CitationX_FailureTrainer.lua` | QRH-style failure scenarios (engine fire, generator trip, bleed air, boost pump, flameout, APU fire, hydraulics) with checklists that self-check against the aircraft's own datarefs. |
| `Scripts/CitationX_CabinOps.lua` | Boarding / ground-power / cabin-lights flow with a clickable panel, passenger progress and automatic phase handling. |
| `Scripts/CitationX_MissionGenerator.lua` | Random scored missions: out-and-back to a generated fix, clock, difficulty levels, hard rules, fuel/altitude/mach objectives, emergency sorties via the QRH trainer. Persists best score and streak. |

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

## Mission Generator quick start

1. Park on the ground (below 25 kt) and click **GENERATE MISSION** on the bottom-center panel,
   press the assigned command `MissionGen/generate`, or use the FlyWithLua macro menu.
2. The clock starts at wheels up. Fly to the generated fix point (bearing + distance shown on
   the panel), then return and come to a full stop within 3 NM of home.
3. Obey the mission's rules. Violations subtract points; landing clean and fast scores more.
4. Progress (streak, best score, missions flown) is saved to
   `Scripts/CitationX_MissionProgress.txt`.

Mission types: TURNAROUND, ALTITUDE RUN, FAST LANE (mach hold), FUEL DISCIPLINE, EMERGENCY
SORTIE. Difficulties: EASY, NORMAL, HARD, BRUTAL.

Bindable commands:

```
MissionGen/generate      MissionGen/abort
MissionGen/toggle_panel  MissionGen/report
CitationXSuite/*         CitationXQRH/*        CabinOps/*
```

## Configuration

- `CitationX_MasterSuite.lua` — `CONFIG` table: HUD, flight recorder, axis optimizer,
  emergency generator, input mapper and the right-stick heading knob
  (`stick_hdg_*`, including `stick_hdg_exclude_axes` and a fixed `stick_hdg_axis` pin).
- `CitationX_MissionGenerator.lua` — `MG_CONFIG` table: cruise speed used for clock math,
  reserve fuel, radii and the `MG_DIFF_*` difficulty tables.
- `CitationX_CabinOps.lua` — `CAB_CONFIG`; `CitationX_FailureTrainer.lua` — `TRAINER_CONFIG`.

## Development and validation

```sh
# syntax check every tracked script
luac -p Scripts/CitationX_*.lua

# mock-FlyWithLua smoke tests (Lua 5.4 available locally)
export TMPDIR="$(mktemp -d)/"
lua tests/smoke_mission.lua Scripts/CitationX_MissionGenerator.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" lua tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
```

Every DataRef used by the scripts must exist in
`Resources/plugins/DataRefs.txt` (or be a runtime `laminar/CitX/...` dataref registered by the
aircraft's xlua plugin). A single invalid DataRef makes FlyWithLua quarantine the whole script.

If X-Plane is available, load a flight and check `Log.txt` for `FlyWithLua Error`. The
"DataRef ... is already handled in variable ..." lines are informational, not errors.

See `CONTEXT.md` for the engineering history and `AGENTS.md` for contribution rules.

## Repository

Private: <https://github.com/ModernAmusements/citationx-suite>
