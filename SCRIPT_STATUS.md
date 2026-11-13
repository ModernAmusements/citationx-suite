# Script status — verified 2026-11-14 (v3.0, MA dark theme, no EFB, 14 QRH scenarios)

Evidence: `Log.txt` last Lua cycle, `luac -p`, `tests/check_datarefs.lua`,
`tests/check_kpcrew_modules.lua`, `tests/smoke_mastersuite.lua`, `tests/smoke_hud_toggles.lua`,
`tests/smoke_realism.lua`, `tests/smoke_panel_geometry.lua`.

## Live in `Scripts/`

| Script | State | Evidence / purpose |
| --- | --- | --- |
| `CitationX_00_Core.lua` | ✅ tests | Shared core, loaded first: the MA dark palette (`CX`) and the `cx_*` bar/text/fit/footer primitives every panel uses. No datarefs, commands or callbacks, so it cannot quarantine a panel. |
| `CitationX_MasterSuite.lua` | ✅ tests | v3.0 hub. `status report` says `input layer = mouse wheel -> ALT SEL`. **No `do_on_keystroke`, no wheel/button map, no axis-to-heading knob any more** — the only pilot input the suite reads is the mouse wheel: the thumbwheel (wheel 1) moves the heading bug and wheel 2 moves ALT SEL; the main wheel stays with X-Plane's view zoom. The wheel numbers and steps are configurable. Axis optimizer ON (pitch/roll deadzone + expo + smoothing, no key mapping), flight recorder, emergency generator, opt-in axis monitor, texture cycler (`sim/operation/next_livery`), AviTab app shortcuts, and the 12-row draggable hub at `SUITE_STYLE.x = 470`. `smoke_mastersuite.lua` pins the whole contract; `smoke_hud_toggles.lua` checks the registry; `smoke_panel_geometry.lua` renders the panel. |
| `CitationX_FailureTrainer.lua` | ✅ works* | 14 QRH-style scenarios: engine fire L, generator L trip, bleed air L, boost pump L, flameout L, APU fire, hydraulic A/B, flap actuator, gear indication, APU fail-to-start, pitot/static, elevator trim runaway and slow cabin decompression, plus RANDOM. Every step self-checks against `sim/...` and `laminar/CitX/...`; `rel_flap_act` is written through XPLM because the Realism pack owns that writable binding. |
| `CitationX_CabinOps.lua` | ✅ works* | `Cabin & Ground Ops loaded` |
| `CitationX_Realism.lua` | ✅ tests | one MA-dark Helvetica panel, a bank of **LEDs and bar gauges** instead of numbers: trim band, fuel balance, weight against MTOW/MLW, crosswind against the demonstrated limit, brake energy, bus voltage. Behind it: audio callouts (FMOD master bus), control check, takeoff trim/flap gate, fuel balance, weight limits, load-shed manager, brake fan, Vmo/Mmo overspeed, takeoff config, stabilised approach, gear-down confirmation, flap/gear overspeed, crosswind, icing/anti-ice and cabin-altitude advisories. Sustained flap overspeed tears off one flap (default right) and fails the actuator, sustained gear overspeed fails the gear actuator (`rel_gear_act`); `CitationXRealism/repair` clears both. `tests/smoke_realism.lua` drives all of it; `smoke_panel_geometry.lua` renders the panel |
| `LandingPerformance.lua` | ✅ works* | `Landing Performance: C750 \| GOOD \| Score 76 \| -220 FPM \| 1.42 G` — scored a real landing |
| `Sim_Rate.lua` | ✅ works | `Sim Rate Monitor Loaded`, `Setting Sim Rate to 4x/1x` |
| `kpredline.lua` | ✅ works | FSX-style Shift-Z line (see below); draws only after `kp/redline/toggle` |
| `kpsoundmute.lua` | ✅ works | noise-cancelling headset mute (see below) |

> **`works`** = confirmed in a real `Log.txt` run. **`works*`** = confirmed in that run but the
> file has been edited since (control-panel relayout / HUD removal), so the current code is only
> proven to load, not yet observed on screen.

KPCrew's own `kpcrew23.lua`, `kppanels.lua` and `kpxbrief.lua` are **not** in `Scripts/` any
more — they were moved to `Scripts (disabled)/` on 2026-11-12. They are not running, but they
do load cleanly (verified in one shared state), and `Scripts (Quarantine)/` is now empty, so
FlyWithLua no longer shows its quarantine popup.

## Deleted

| File | Reason |
| --- | --- |
| `CitationX_MissionGenerator.lua` | removed on request 2026-10-21 |
| `tests/smoke_mission.lua` | tested the deleted script |
| `Scripts (Quarantine)/CitationX_MissionGenerator.lua` | stale 32 KB copy from Oct 19 |
| `CitationX_MissionProgress.txt` | mission-generator state file |
| `CitationX_EFB.lua` | removed on request 2026-11-12 ("too many scripts") |
| `CitationX_Airports.csv` | airport index, only the EFB ROUTE page read it |
| `tests/smoke_efb.lua`, `tests/smoke_checklist.lua` | tested the deleted EFB |
| `docs/img/panels/efb.png` | screenshot of the deleted panel |

## What `kpredline.lua` is

A KPCrew utility: the FSX-style **Shift-Z red overlay line** at the top-left of the screen.
When toggled on it draws two lines:

```
LAT: N 47 25' 12" LON: E 8 33' 41"  ALT: 1654 FT MSL  HDG: 214 MAG  IAS: 120 KTS  GS: 128 KTS  WIND: 270/12
FRAMES/SEC: 46.2  FUEL: 62%  SIMRATE: 1.0  SIMSPEED: 1  A/T: OFF  A/T SPD: 0  A/P HDG: 214  A/P ALT: 12000
```

Toggle with the FlyWithLua macro **KPRedline Toggle Display** or the command
`kp/redline/toggle`. It starts hidden, which is why the log shows it loading silently.

## What `kpsoundmute.lua` is

A KPCrew utility that fakes **noise-cancelling headphones**: it lowers the interior, weather and
exterior volume ratios while you are in the cockpit and restores them outside.

- Load time: `ks_switch_mute()` runs once.
- Manual mode: `kp/soundmute/toggle` (or the macro) flips muted/unmuted.
- Auto mode: `kp/soundmute/auto` makes it follow the camera view — inside views
  (1000/1023/1024/1026) mute, outside views (tower/runway/chase/circle/spot/linear/free/ride-along)
  unmute.

## Why kpcrew23 / kppanels / kpxbrief were failing

Proven by A/B with `tests/probe_load_order.lua`, not inferred:

1. KPCrew 2.3-alpha11 shipped `Modules/kpcrew/systems/C750/sys*.lua` **without** the matching
   `C750/*Definitions.lua` files. Every DFLT system module ends with
   `require("kpcrew.systems." .. kc_acf_icao .. ".sysLightsDefinitions")`, so for the C750 that
   resolved to a file that did not exist.
2. `kpcrew23.lua` aborted there → FlyWithLua reported `CopyDataRefsToLua() failed` → quarantined.
3. `kppanels.lua` requires the same `C750.sysLights` module → same abort → quarantined.
4. `kpxbrief.lua` is a **cascade**: it never requires `defaultPrefs` itself, it uses the globals
   `activePrefSet` / `activeBckVars` created by `kpcrew23.lua`. With `kpcrew23` quarantined those
   were nil, so it died at line 1640. Fixing `kpcrew23` fixes it automatically.

A/B evidence — with the 8 `C750/*Definitions.lua` files removed:

```
FAIL  kpcrew23.lua   Modules/kpcrew/systems/DFLT/sysLights.lua:90:
                     module 'kpcrew.systems.C750.sysLightsDefinitions' not found
FAIL  kppanels.lua   Scripts/kppanels.lua:35:
                     loop or previous error loading module 'kpcrew.systems.C750.sysLights'
```

With them restored: `52 dataref binding(s), 0 load failure(s), 0 binding problem(s)`.

Exact count: **8 distinct modules**, verified by removing them and running
`lua tests/check_kpcrew_modules.lua` (`8 missing`), then restoring (`0 missing`).

This gap is **not C750-specific**. `lua tests/check_kpcrew_modules.lua --all` shows 28 of 34
aircraft directories missing the same 8 files. Only 5 dirs ship `*Definitions.lua` at all
(B737, C510, C750, DFLT, DHC8). KPCrew 2.3-alpha11 is incomplete upstream; only the C750 path
was repaired here.

Also fixed in `Modules/kpcrew/metargen.lua`: two `float[13]` weather arrays were bound with a
scalar `dataref()` (FlyWithLua warned `should have an index`), and
`sim/weather/visibility_reported_m` was bound although `DataRefs.txt` marks it **REPLACED**.

**Caveat:** `kpxbrief.lua` still requires `kpcrew23.lua` to be present and loaded first. That is
upstream's design — do not test it in isolation and treat the failure as a bug.

## Panel geometry (measured, not eyeballed)

`tests/smoke_panel_geometry.lua` renders all four panels into a recording canvas and asserts
that everything fits 2560×1440 (the realism panel also at 1280×720), that no vertical text
collisions or text overflows its panel occur, that the default panel positions do not collide,
that a vertical click sweep reaches every control-panel row, and that every panel's header drag
moves it by the mouse delta and keeps the new position. It also injects, renders, measures and
clears **every QRH scenario** (117 checks).

It also proves the MasterSuite overlay draws **nothing at all** when its control panel is
switched off — there is no telemetry HUD and no C750 systems readback any more. At load the
suite draws exactly two surfaces: the realism panel and the Master Suite hub. The other two
panels are opened from the hub and share the same MA dark shell.

This does not prove the panels *look* good — only that they are mathematically well formed.

## How to reproduce

The local `lua` is 5.5 while FlyWithLua runs LuaJIT (5.1). Lua 5.2+ removed `module()` and makes
loop variables const, so KPCrew aborts under `lua` for reasons that never happen in-sim. Use
`luajit` for anything that loads a script.

```sh
luac -p Scripts/*.lua

for f in Scripts/CitationX_*.lua; do
  lua tests/check_datarefs.lua ../DataRefs.txt "$f"
done
lua tests/check_kpcrew_modules.lua

# authoritative: shared-state, alphabetical, same Lua as the plugin
luajit tests/probe_load_order.lua ../DataRefs.txt Scripts

export TMPDIR="$(mktemp -d)/"
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_hud_toggles.lua Scripts/CitationX_MasterSuite.lua
luajit tests/smoke_panel_geometry.lua
```
