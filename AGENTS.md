# AGENTS.md — FlyWithLua Citation X Suite

This repository is checked out **inside the live FlyWithLua installation** at
`X-Plane 12/Resources/plugins/FlyWithLua`. The working tree is the production runtime: any edit
to `Scripts/CitationX_*.lua` takes effect the next time X-Plane loads or reloads Lua scripts.

Read `CONTEXT.md` before making changes; it records why the current code looks the way it does.

## Repository scope

Tracked (see `.gitignore`):

```
Scripts/CitationX_CabinOps.lua
Scripts/CitationX_EFB.lua
Scripts/CitationX_FailureTrainer.lua
Scripts/CitationX_MasterSuite.lua
Scripts/CitationX_Realism.lua
Scripts/CitationX_Callouts/*.wav
tests/check_datarefs.lua
tests/check_kpcrew_modules.lua
tests/probe_kpcrew.lua
tests/smoke_efb.lua
tests/smoke_hud_toggles.lua
tests/smoke_mastersuite.lua
tests/smoke_panel_geometry.lua
tests/smoke_realism.lua
tools/joymap.py
tools/joymap_gui.py
README.md  AGENTS.md  CONTEXT.md  SCRIPT_STATUS.md
.opencode/agents/citationx.md
```

The mission generator was **deleted** on 2026-10-21 at the user's request. Third-party add-ons
(`Scripts/kpcrew*.lua`, `Scripts/Sim_Rate.lua`, `Modules/kpcrew*`) are untracked runtime files —
never edit or commit them.

Everything else in the FlyWithLua folder is third-party or runtime state and must stay
untracked: plugin binaries (`mac_x64/`, `win_x64/`, `lin_x64/`), `Modules/`, `Internals/`,
`Documentation/`, `Scripts (disabled)/`, `Scripts (Quarantine)/`, preference/INI files,
`CitationX_MissionProgress.txt`, CSV logs, `.DS_Store`.

## Environment

- X-Plane 12 on macOS (arm64), FlyWithLua NG+ 2.8.x (LuaJIT, Lua 5.1 API in-sim).
- Local `lua`/`luac` are Lua 5.5 — fine for syntax checks, but **not** for behaviour: Lua 5.2+
  removed `module()` and makes loop variables const, so KPCrew modules abort under `lua` while
  they run fine in-sim. Use `luajit` (installed via Homebrew, same Lua 5.1 semantics as the
  plugin) for anything that actually loads a script. `tests/probe_load_order.lua` is the
  authoritative runtime test.
- Avoid 5.2+-only syntax in the scripts and keep `math.atan2` fallbacks.
- The Citation X registers ~220 `laminar/CitX/...` commands and ~300 runtime datarefs from
  `Aircraft/Laminar Research/Cessna Citation X/plugins/xlua/scripts/*.lua`.

## Non-negotiable rules

1. **Every DataRef must exist.** Core datarefs are listed in
   `Resources/plugins/DataRefs.txt`; aircraft datarefs are registered at runtime by the
   Citation X xlua scripts. Never invent a DataRef name.
2. **Every command must exist.** Core commands are in `Resources/plugins/Commands.txt`;
   `laminar/CitX/...` commands must match the aircraft's xlua `create_command` calls.
3. **A single bad DataRef quarantines the whole script** and forces FlyWithLua to restart its
   Lua engine. This is a release blocker.
4. **FlyWithLua's screen origin is bottom-left.** `draw_string`/`glRectf` y grows upward.
   Bottom-anchored panels must extend upward (`top = bottom + height`), never downward.
5. **One shared Lua state.** All scripts run in the same globals namespace. Keep per-script
   prefixes (`CONFIG`, `SUITE_STYLE`, `SUITE_MODULES`, `REAL_CONFIG`, `real_*`, `ST`, `CS`,
   `CAB_CONFIG`, `TRAINER_CONFIG`, `cab_*`, `ft_*`, `citationx_*`, `la_*`). Do not redefine
   another script's globals.
6. **Use only the FlyWithLua NG+ 2.8 API already present** in these scripts (`dataref`,
   `dataref_table`, `create_command`, `add_macro`, `do_every_*`, `draw_string`,
   `measure_string`, `command_once`, `logMsg`, ...). Do not add third-party Lua modules.
7. **Match the house style:** banner comments, glass-panel palette, `mx_`/`mg_` helpers,
   clickable panels with `RESUME_MOUSE_CLICK`, commands + macros for every subsystem.
   **Never add a telemetry HUD or an aircraft-systems readback** — the Citation X's PFD, EICAS
   and synoptics already show airspeed, altitude, heading, Mach, G, fuel flow, electrics, fuel
   and anti-ice. The only allowed on-screen surface is the control panel, plus explicitly
   switched-on diagnostics (AXIS MONITOR, LEARN MODE) and transient 2 s toasts.
8. **Never modify** third-party plugin files, `Modules/`, `Internals/`, `Documentation/`, or
   the aircraft's xlua scripts. Treat `Scripts (disabled)/`, `Scripts (Quarantine)/` as
   read-only reference.
9. **Third-party add-ons are not ours.** KPCrew (`Scripts/kpcrew*.lua`, `Modules/kpcrew*`) and
   SimRateMonitor (`Scripts/Sim_Rate.lua`) are upstream. Do not modify, reformat or commit
   them; keep the suite's global prefixes separate. The one sanctioned exception is the
   `C750/*Definitions.lua` repair documented in `CONTEXT.md` §12 — KPCrew 2.3-alpha11 shipped
   those files missing, so without them every C750 script is quarantined.

## Validation workflow (required)

Run from the repository root before reporting work as done:

```sh
luac -p Scripts/*.lua

# every dataref() binding is legal (exists, and array refs carry an index)
for f in Scripts/CitationX_*.lua; do
  lua tests/check_datarefs.lua ../../plugins/DataRefs.txt "$f"
done

# every require() reachable for the C750 resolves on disk (--all sweeps every aircraft)
lua tests/check_kpcrew_modules.lua C750

# THE authoritative test: load all of Scripts/ in one shared LuaJIT state,
# in the same alphabetical order FlyWithLua uses.
luajit tests/probe_load_order.lua ../../plugins/DataRefs.txt Scripts

# mock-FlyWithLua smoke tests
export TMPDIR="$(mktemp -d)/"
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_hud_toggles.lua Scripts/CitationX_MasterSuite.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_efb.lua Scripts/CitationX_EFB.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_realism.lua Scripts/CitationX_Realism.lua

# panel layout: fits the screen, no overlapping/colliding text, rows clickable
luajit tests/smoke_panel_geometry.lua
```

`probe_load_order.lua` must end with `0 load failure(s), 0 binding problem(s)`. It is the only
harness that reproduces the real runtime: KPCrew's scripts depend on globals created by
`kpcrew23.lua`, so loading them in isolation produces false failures.

`tests/check_datarefs.lua` catches the failure mode that quarantines a script: a `dataref()`
on a missing ref, or on a `float[N]`/`int[N]` array without an explicit index.
`tests/check_kpcrew_modules.lua` does the same for KPCrew's runtime-built `require()` paths;
it computes DFLT-module inheritance from disk so the count is exact per aircraft (C750: 0).

Then verify datarefs/commands explicitly. Example DataRef check:

```sh
for f in Scripts/CitationX_*.lua; do
  perl -ne 'while (/dataref\s*\(\s*"[^"]+"\s*,\s*"([^"]+)"/g) { print "$1\n" }' "$f" |
  sort -u |
  while read -r p; do
    grep -qF "$p" Resources/plugins/DataRefs.txt || echo "MISSING: $p in $f"
  done
done
```

For `laminar/CitX/...` names, grep the aircraft folder:

```sh
XLUA="Aircraft/Laminar Research/Cessna Citation X/plugins/xlua/scripts"
grep -rhoE 'create_command\("[^"]+"' "$XLUA" | sed -E 's/create_command\("//; s/"$//' | sort -u
```

If X-Plane is installed here, also check `Log.txt` for `FlyWithLua Error` / `Moved Bad Script`.
Tell the user to reload Lua scripts after modifying files.

## Deploy

Deployment is the live install plus GitHub:

1. Edit `Scripts/CitationX_*.lua` in place.
2. Validate.
3. Commit only tracked suite files; push to `origin main`.
4. In X-Plane: FlyWithLua → *Reload all Lua script files* (or restart).

Remote: `https://github.com/ModernAmusements/citationx-suite` (private).

## Known gotchas

- "The DataRef ... is already handled in variable ..." log lines are informational; do not
  "fix" them by deleting datarefs.
- The DS4 is enumerated twice (USB + Bluetooth). The heading knob tolerates interface loss via
  a 6 s stale-slot watchdog; see `CitationX_MasterSuite.lua`.
- Mission generation is ground-only (< 25 kt). The clock starts at wheels up.
- The mission generator was deleted on 2026-10-21; the mission panel, `MissionGen/*`
  commands and the cruise time warp no longer exist.
- KPCrew 2.3 + SimRateMonitor are installed as untracked add-ons. KPCrew's `kphardware.lua`
  (171 commands, Honeycomb/Saitek profiles) is deliberately not installed.
- KPCrew 2.3-alpha11 shipped the C750 system modules without their `C750/*Definitions.lua`
  files, so every C750 script died in `require()` and got quarantined. The eight missing files
  were added on 2026-10-21 as thin wrappers over the DFLT tables; see `CONTEXT.md`.
- zsh treats `path` as a special variable bound to `$PATH`; never use it as a loop variable.
