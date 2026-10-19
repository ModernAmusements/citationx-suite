# AGENTS.md — FlyWithLua Citation X Suite

This repository is checked out **inside the live FlyWithLua installation** at
`X-Plane 12/Resources/plugins/FlyWithLua`. The working tree is the production runtime: any edit
to `Scripts/CitationX_*.lua` takes effect the next time X-Plane loads or reloads Lua scripts.

Read `CONTEXT.md` before making changes; it records why the current code looks the way it does.

## Repository scope

Tracked (see `.gitignore`):

```
Scripts/CitationX_CabinOps.lua
Scripts/CitationX_FailureTrainer.lua
Scripts/CitationX_MasterSuite.lua
Scripts/CitationX_MissionGenerator.lua
tests/smoke_mission.lua
tests/smoke_mastersuite.lua
README.md  AGENTS.md  CONTEXT.md
.opencode/agents/citationx.md
```

Everything else in the FlyWithLua folder is third-party or runtime state and must stay
untracked: plugin binaries (`mac_x64/`, `win_x64/`, `lin_x64/`), `Modules/`, `Internals/`,
`Documentation/`, `Scripts (disabled)/`, `Scripts (Quarantine)/`, preference/INI files,
`CitationX_MissionProgress.txt`, CSV logs, `.DS_Store`.

## Environment

- X-Plane 12 on macOS (arm64), FlyWithLua NG+ 2.8.x (LuaJIT, Lua 5.1 API in-sim).
- Local `lua`/`luac` are Lua 5.4 — fine for syntax checks and the mock harnesses; avoid
  5.4-only syntax in the scripts and keep `math.atan2` fallbacks.
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
   prefixes (`CONFIG`, `HUD_STYLE`, `ST`, `CS`, `CAB_CONFIG`, `TRAINER_CONFIG`, `MG_CONFIG`,
   `mg_*`, `cab_*`, `ft_*`, `citationx_*`). Do not redefine another script's globals.
6. **Use only the FlyWithLua NG+ 2.8 API already present** in these scripts (`dataref`,
   `dataref_table`, `create_command`, `add_macro`, `do_every_*`, `draw_string`,
   `measure_string`, `command_once`, `logMsg`, ...). Do not add third-party Lua modules.
7. **Match the house style:** banner comments, glass-panel palette, `mx_`/`mg_` helpers,
   clickable panels with `RESUME_MOUSE_CLICK`, commands + macros for every subsystem.
8. **Never modify** third-party plugin files, `Modules/`, `Internals/`, `Documentation/`, or
   the aircraft's xlua scripts. Treat `Scripts (disabled)/`, `Scripts (Quarantine)/` as
   read-only reference.

## Validation workflow (required)

Run from the repository root before reporting work as done:

```sh
luac -p Scripts/CitationX_*.lua

export TMPDIR="$(mktemp -d)/"
lua tests/smoke_mission.lua Scripts/CitationX_MissionGenerator.lua
HOME="$TMPDIR" TMPDIR="$TMPDIR" lua tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
```

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
- The mission generator's emergency objective calls `qrh_inject_by_key("flameout_l")` when the
  Failure Trainer is loaded, otherwise it writes `sim/operation/failures/rel_engfla0` directly.
- zsh treats `path` as a special variable bound to `$PATH`; never use it as a loop variable.
