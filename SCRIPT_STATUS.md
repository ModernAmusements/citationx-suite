# Script status — verified 2026-10-24, input reset 2026-10-30

Evidence: `Log.txt` last Lua cycle, `luac -p`, `tests/check_datarefs.lua`,
`tests/check_kpcrew_modules.lua`, `tests/smoke_mastersuite.lua`,
`tests/smoke_hud_toggles.lua`, `tests/smoke_realism.lua`,
`tests/smoke_panel_geometry.lua`.

## Live in `Scripts/`

| Script | State | Evidence / purpose |
| --- | --- | --- |
| `CitationX_MasterSuite.lua` | ✅ works* | `status report`; smoke tests pass. At load the suite shows exactly two panels: the realism panel and the Master Suite hub (`status` is ON). Every other drawing module is OFF. **Input: the only pilot input the suite reads is the heading bug on DS4 Axis 3 (`stick_hdg_axes = { 3, 28 }`, USB/Bluetooth); no keystroke is consumed — native X-Plane key bindings work, and the keyboard layer, joystick-button map, mouse thumb-button ALT SEL keys, L2/R2 analog throttle, arrow-key tilt, stick ALT SEL, axis optimizer, R3 look and realism handling curve are all OFF at load** (2026-10-30 reset, §32). The mouse wheel stays with X-Plane (view zoom). The knob's learned rest no longer latches X-Plane's `-0.01` pre-enumeration value. R3 + right stick pans `pilots_head_psi/the` only when COCKPIT LOOK is switched on; it then suppresses the heading knob while held. Free controller buttons are auto-bound only when the input mapper is switched on. |
| `CitationX_FailureTrainer.lua` | ✅ works* | `Citation X Failure Trainer + QRH loaded` |
| `CitationX_CabinOps.lua` | ✅ works* | `Cabin & Ground Ops loaded` |
| `CitationX_Realism.lua` | ✅ tests | one black Helvetica realism panel (16 rows, clickable), audio callouts (FMOD master bus), handling curve, control check, takeoff trim/flap gate, fuel balance, MTOW/MLW weight limits, load-shed manager, brake fan, Vmo/Mmo overspeed, takeoff config, stabilised approach, gear-down confirmation, flap/gear overspeed, crosswind, icing/anti-ice and cabin-altitude advisories. `tests/smoke_realism.lua` drives all of it; `smoke_panel_geometry.lua` renders the panel |
| `CitationX_EFB.lua` | ✅ tests | PERF / CHECK / FUEL pages; `tests/smoke_efb.lua` and the geometry sweep pass, not yet used in a flight |
| `LandingPerformance.lua` | ✅ works* | `Landing Performance: C750 \| GOOD \| Score 76 \| -220 FPM \| 1.42 G` — scored a real landing |
| `Sim_Rate.lua` | ✅ works | `Sim Rate Monitor Loaded`, `Setting Sim Rate to 4x/1x` |
| `kpredline.lua` | ✅ works | FSX-style Shift-Z line (see below); draws only after `kp/redline/toggle` |
| `kpsoundmute.lua` | ✅ works | noise-cancelling headset mute (see below) |
| `kpcrew23.lua` | ✅ loads | was quarantined; missing C750 Definitions files restored |
| `kppanels.lua` | ✅ loads | was quarantined; same root cause |
| `kpxbrief.lua` | ✅ loads | was a cascade of `kpcrew23`; needs `kpcrew23.lua` present |

> **`works`** = confirmed in a real `Log.txt` run. **`works*`** = confirmed in that run but the
> file has been edited since (control-panel relayout / HUD removal), so the current code is only
> proven to load, not yet observed on screen.
> **`loads`** = chunk executes with no error in the LuaJIT shared-state harness; no functional
> test. The KPCrew copilot UI, SOP checklists and SimBrief import have **not** been exercised.

## Deleted

| File | Reason |
| --- | --- |
| `CitationX_MissionGenerator.lua` | removed on request 2026-10-21 |
| `tests/smoke_mission.lua` | tested the deleted script |
| `Scripts (Quarantine)/CitationX_MissionGenerator.lua` | stale 32 KB copy from Oct 19 |
| `CitationX_MissionProgress.txt` | mission-generator state file |

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

`tests/smoke_panel_geometry.lua` renders all five panels into a recording canvas and asserts
65 properties: everything fits 2560×1440 (the realism panel also at 1280×720), no vertical text
collisions, no text overflows its panel, the EFB clears the QRH and cabin panels, the default
panel positions do not collide, a vertical click sweep reaches every control-panel row, and
every panel's header drag moves it by the mouse delta and keeps the new position.

It also proves the MasterSuite overlay draws **nothing at all** when its control panel is
switched off — there is no telemetry HUD and no C750 systems readback any more. At load the
suite draws exactly two surfaces: the realism panel and the Master Suite hub. The other three
panels are opened from the hub and share the same black/Helvetica shell.

This does not prove the panels *look* good — only that they are mathematically well formed.

## How to reproduce

The local `lua` is 5.5 while FlyWithLua runs LuaJIT (5.1). Lua 5.2+ removed `module()` and makes
loop variables const, so KPCrew aborts under `lua` for reasons that never happen in-sim. Use
`luajit` for anything that loads a script.

```sh
luac -p Scripts/*.lua

for f in Scripts/CitationX_*.lua; do
  lua tests/check_datarefs.lua ../../Resources/plugins/DataRefs.txt "$f"
done
lua tests/check_kpcrew_modules.lua

# authoritative: shared-state, alphabetical, same Lua as the plugin
luajit tests/probe_load_order.lua ../../Resources/plugins/DataRefs.txt Scripts

export TMPDIR="$(mktemp -d)/"
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_hud_toggles.lua Scripts/CitationX_MasterSuite.lua
luajit tests/smoke_panel_geometry.lua
```
