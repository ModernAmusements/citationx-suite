--[[
  check_kpcrew_modules.lua — resolve every runtime-built `require()` reachable
  when KPCrew loads for ONE aircraft, and report modules missing on disk.

  Why this matters: KPCrew builds most require paths at runtime as

      require("kpcrew.systems." .. kc_acf_icao .. ".sysLightsDefinitions")

  If that file is absent, FlyWithLua aborts the host script, reports
  "CopyDataRefsToLua() failed" and quarantines the whole file.

  Scope: an aircraft reaches a DFLT system module only when its own
  systems/<ICAO>/<sys>.lua does require("kpcrew.systems.DFLT.<sys>").
  That inheritance is computed from disk, so the result is exact for the
  selected aircraft rather than "some module somewhere might be missing".

  Usage:
    lua tests/check_kpcrew_modules.lua [ICAO] [--all]

    ICAO     aircraft to check (default C750)
    --all    check every aircraft directory that has a SOP

  Exit 0 when every reachable require resolves.
--]]

local ROOT = "Modules"
local target = arg[1] or "C750"
local check_all = false
for _, a in ipairs(arg) do if a == "--all" then check_all = true end end
if target == "--all" then target, check_all = "C750", true end

------------------------------------------------------------------ indexing ----
local modules, files = {}, {}

do
  local p = io.popen('find "' .. ROOT .. '" -name "*.lua" 2>/dev/null')
  for path in p:lines() do
    files[#files + 1] = path
    local rel = path:gsub("^" .. ROOT .. "/", ""):gsub("%.lua$", "")
    modules[(rel:gsub("/", "."))] = path
  end
  p:close()
end

-- the KPCrew entry scripts, wherever they currently live
for _, extra in ipairs({
  "Scripts/kpcrew23.lua", "Scripts/kppanels.lua", "Scripts/kpxbrief.lua",
  "Scripts (Quarantine)/kpcrew23.lua", "Scripts (Quarantine)/kppanels.lua",
  "Scripts (Quarantine)/kpxbrief.lua",
}) do
  local fh = io.open(extra, "r")
  if fh then fh:close() files[#files + 1] = extra end
end

------------------------------------------------ aircraft inheritance graph ----
-- For each aircraft, which DFLT system modules does it pull in?
-- inherit[icao] = { [dfltSysName] = true }
local inherit = {}
do
  local p = io.popen('find "' .. ROOT .. '/kpcrew/systems" -name "*.lua" 2>/dev/null')
  for path in p:lines() do
    local icao = path:match("systems/([%w]+)/[^/]+%.lua$")
    if icao and icao ~= "DFLT" then
      inherit[icao] = inherit[icao] or {}
      local fh = io.open(path, "r")
      if fh then
        for line in fh:lines() do
          for sys in line:gmatch('require%s*%(?%s*"kpcrew%.systems%.DFLT%.([%w_]+)"') do
            inherit[icao][sys] = true
          end
        end
        fh:close()
      end
    end
  end
  p:close()
end

------------------------------------------------------------ collect calls ---
-- Collect as (file -> list of {line, literal|dynamic}).
local sites, seen = {}, {}
local function add(site)
  local key = site.file .. ":" .. site.line .. "|" .. (site.text or "")
  if not seen[key] then seen[key] = true; sites[#sites + 1] = site end
end

for _, path in ipairs(files) do
  local fh = io.open(path, "r")
  if fh then
    local lineno = 0
    for line in fh:lines() do
      lineno = lineno + 1
      -- dynamic: require("prefix." .. <var> .. ".suffix")
      --   group 1 = "kpcrew.systems."   group 2 = ".sysLightsDefinitions"
      for prefix, suffix in
        line:gmatch('require%s*%(?%s*"([%w%.]+%.)"%s*%.%.%s*[%w_%.]+%s*%.%.%s*"(%.?[%w_%.]+)"')
      do
        add({ file = path, line = lineno, dynamic = true,
              prefix = prefix, suffix = (suffix:gsub("^%.", "")), text = prefix .. suffix })
      end
      -- literal: require("kpcrew.x.y"), skipping concatenated forms
      for name, tail in line:gmatch('require%s*%(?%s*"([%w%.]+)"(.-)$') do
        if not tail:match("^%s*%.%.") then
          add({ file = path, line = lineno, name = name, text = name })
        end
      end
    end
    fh:close()
  end
end

------------------------------------------------------------ resolution ------
-- A file is "reachable" for aircraft A when:
--   * it lives in systems/A/
--   * it lives in systems/DFLT/ AND A inherits it
--   * it is a SOP for A, a briefing for A, or a shared non-systems module
local function reachable(path, icao)
  local own = path:match("systems/([%w]+)/[^/]+%.lua$")
  if own then
    if own == icao then return true end
    if own == "DFLT" then
      local name = path:match("systems/DFLT/([%w_]+)%.lua$")
      return name ~= nil and inherit[icao] ~= nil and inherit[icao][name] == true
    end
    return false
  end
  local sop = path:match("sops/SOP_([%w]+)%.lua$")
  if sop then return sop == icao end
  local brf = path:match("briefings/briefings_([%w]+)%.lua$")
  if brf then return brf == icao end
  -- Modules/kpcrew/*.lua shared helpers, hardware/, preferences/: always loadable
  return true
end

local function check_one(icao)
  local missing, checked, unresolved = 0, 0, 0
  for _, r in ipairs(sites) do
    if reachable(r.file, icao) then
      if r.dynamic then
        checked = checked + 1
        local want = r.prefix .. icao .. "." .. r.suffix
        if not modules[want] then
          print(string.format("  MISSING  %s:%d", r.file, r.line))
          print(string.format("           require \"%s\"", want))
          print(string.format("           no file Modules/%s.lua", (want:gsub("%.", "/"))))
          missing = missing + 1
        end
      elseif r.name:match("^kpcrew") then
        checked = checked + 1
        if not modules[r.name] then
          print(string.format("  MISSING  %s:%d  require \"%s\"", r.file, r.line, r.name))
          missing = missing + 1
        end
      end
    end
  end
  return missing, checked, unresolved
end

------------------------------------------------------------------ run --------
local targets = {}
if check_all then
  local p = io.popen('ls -d "' .. ROOT .. '/kpcrew/systems"/*/ 2>/dev/null')
  for line in p:lines() do
    local icao = line:match("systems/([%w]+)/$")
    if icao then targets[#targets + 1] = icao end
  end
  p:close()
  table.sort(targets)
else
  targets = { target }
end

local total_missing = 0
for _, icao in ipairs(targets) do
  print(string.format("aircraft %s", icao))
  local missing, checked = check_one(icao)
  print(string.format("  %d require() site(s) checked, %d missing", checked, missing))
  if missing == 0 then print("  OK") end
  total_missing = total_missing + missing
  print("")
end

print(string.format("TOTAL: %d missing across %d aircraft", total_missing, #targets))
os.exit(total_missing == 0 and 0 or 1)
