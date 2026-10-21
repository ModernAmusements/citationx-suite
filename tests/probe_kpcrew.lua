--[[
  probe_kpcrew.lua — load a FlyWithLua script against a mock API and report
  every dataref it binds plus where it dies.

  Usage:
    lua tests/probe_kpcrew.lua <DataRefs.txt> <script.lua>
--]]

local datarefs_path = arg[1]
local script_path   = arg[2]
if not script_path then
  io.stderr:write("usage: lua tests/probe_kpcrew.lua <DataRefs.txt> <script.lua>\n")
  os.exit(2)
end

-- ---- authoritative types ----
local types = {}
do
  local fh = io.open(datarefs_path, "r")
  for line in fh:lines() do
    local name, typ = line:match("^(%S+)%s+(%S+)%s+[yn]%s+")
    if name then types[name] = typ end
  end
  fh:close()
end

local function is_array(typ) return typ and typ:find("%[%d+%]") ~= nil end

-- ---- mock FlyWithLua ----
local bound = {}          -- { name=..., path=..., mode=..., index=... }
SCRIPT_DIRECTORY     = "./Scripts/"
PLUGIN_MAIN_DIRECTORY = "./"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"

local function stub_ok() return 0 end

function dataref(varname, path, mode, index)
  bound[#bound + 1] = { name = varname, path = path, mode = mode, index = index }
  return { path = path, name = varname }
end
function dataref_table(path)
  bound[#bound + 1] = { name = "<table>", path = path, mode = "table" }
  return {}
end
function get(p, i) return 0 end
function set(p, v, i) end
function logMsg(s) print("LOG   " .. tostring(s)) end
function create_command(a, b, c, d, e) return {} end
function add_macro(a, b) end
function do_every_draw(f) end
function do_every_frame(f) end
function do_often(f) end
function do_sometimes(f) end
function do_every_second(f) end
function draw_string(x, y, t) end
function draw_string_Helvetica_10(x, y, t) end
function draw_string_Helvetica_12(x, y, t) end
function draw_string_Helvetica_18(x, y, t) end
function measure_string(t) return #tostring(t) * 7 end
function command_once(c) end
function command_begin(c) end
function command_end(c) end
function float_wnd_create(...) return {} end
function float_wnd_set_title(...) end
function float_wnd_set_imgui_builder(...) end
function float_wnd_set_onclose(...) end
function float_wnd_set_ondraw(...) end
function float_wnd_set_onclick(...) end
function float_wnd_set_imgui_builder(...) end
function XPLMFindDataRef(p) return { path = p } end
function XPLMGetDataf(r) return 0 end
function XPLMGetDatai(r) return 0 end
function XPLMSetDataf(r, v) end
function XPLMSetDatai(r, v) end
function XPLMFindNavAid(...) return nil end
function XPLMSetFMSEntryLatLon(...) end
function XPLMCountFMSEntry(...) return 0 end
function XPLMGetScreenSize() return 2560, 1440 end
function XPLMSetGraphicsState(...) end
function glColor4f(...) end
function glRectf(...) end
function toast(s) end
function sim_time() end
function kc_file_exists(p) return false end
function SCRIPT_DIRECTORY_exists() end

-- imgui shim (KPCrew uses a lot of it)
local imgui = setmetatable({}, { __index = function() return function() return false end end })
_G.imgui = imgui

-- module path so FlyWithLua-style require() finds Modules/
local ok, extra = pcall(function() return package end)

-- FlyWithLua uses "Modules" as the root for require. Mirror it with a searcher.
table.insert(package.searchers or package.loaders, function(name)
  local rel = name:gsub("%.", "/")
  for _, prefix in ipairs({ "Modules/", "./", "" }) do
    local path = prefix .. rel .. ".lua"
    local fh = io.open(path, "r")
    if fh then fh:close() return function() return dofile(path) end end
  end
  return "\n\tno file '" .. rel .. ".lua'"
end)

-- Trace every module load so the last successful require is visible.
do
  local searchers = package.searchers or package.loaders
  for i = #searchers, 1, -1 do
    local orig = searchers[i]
    searchers[i] = function(name)
      local r = orig(name)
      if type(r) == "function" then
        if os.getenv("PROBE_TRACE") then print("REQUIRE " .. name) end
      end
      return r
    end
  end
end

-- ---- run ----
print("=== loading " .. script_path .. " ===")
local chunk, err = loadfile(script_path)
if not chunk then print("SYNTAX ERROR: " .. tostring(err)) os.exit(1) end
local ok_run, run_err = pcall(chunk)
print("RESULT: " .. (ok_run and "chunk completed" or ("chunk aborted -> " .. tostring(run_err))))

-- ---- analyse bindings ----
local problems = 0
for _, b in ipairs(bound) do
  local typ = types[b.path]
  local line = string.format("  %-28s %s", b.name, b.path)
  if b.mode == "table" then
    if typ and not is_array(typ) then
      print(line .. "   <-- dataref_table on a SCALAR (" .. typ .. ")")
      problems = problems + 1
    end
  elseif typ == nil and not b.path:match("^laminar/") and not b.path:match("^sim/") then
    print(line .. "   <-- unknown namespace")
    problems = problems + 1
  elseif typ == nil and (b.path:match("^laminar/")) then
    -- runtime aircraft ref, assume fine
  elseif typ == nil then
    print(line .. "   <-- NOT IN DataRefs.txt")
    problems = problems + 1
  elseif is_array(typ) and not b.index then
    print(line .. "   <-- ARRAY (" .. typ .. ") bound WITHOUT an index")
    problems = problems + 1
  end
end
print(string.format("RESULT: %d dataref binding(s), %d problem(s)", #bound, problems))
