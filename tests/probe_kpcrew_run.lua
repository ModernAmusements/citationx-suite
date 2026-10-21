--[[
  probe_kpcrew_run.lua — drive a KPCrew script through a mock FlyWithLua API and
  report whether the chunk completes, plus every dataref it binds.

  Unlike probe_kpcrew.lua this also preloads a working LuaSocket shim so the
  SimBrief/HTTP paths do not mask later failures.

  Usage:
    lua tests/probe_kpcrew_run.lua <DataRefs.txt> <script.lua>
--]]

local datarefs_path = arg[1]
local script_path   = arg[2]
if not script_path then
  io.stderr:write("usage: lua tests/probe_kpcrew_run.lua <DataRefs.txt> <script.lua>\n")
  os.exit(2)
end

------------------------------------------------------------- dataref table ---
local types = {}
do
  local fh = io.open(datarefs_path, "r")
  for line in fh:lines() do
    local name, typ = line:match("^(%S+)%s+(%S+)%s+[yn]%s+")
    if name then types[name] = typ end
  end
  fh:close()
end
local function is_array(t) return t and t:find("%[%d+%]") ~= nil end

------------------------------------------------------------ mock FlyWithLua --
local bound, commands, macros = {}, {}, {}
SCRIPT_DIRECTORY      = "./Scripts/"
PLUGIN_MAIN_DIRECTORY = "./"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"
MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = 0, 0

function dataref(varname, path, mode, index)
  bound[#bound + 1] = { name = varname, path = path, mode = mode, index = index }
  _G[varname] = 0
end
function dataref_table(path)
  bound[#bound + 1] = { name = "<table>", path = path, mode = "table" }
  return setmetatable({}, { __index = function() return 0 end })
end
function get(p, i) return 0 end
function set(p, v, i) end
function logMsg(s) print("LOG   " .. tostring(s)) end
function create_command(n, d, a, b, c) commands[#commands + 1] = n; return {} end
function add_macro(n) macros[#macros + 1] = n end
function do_every_draw() end
function do_every_frame() end
function do_often() end
function do_sometimes() end
function do_every_second() end
function do_on_exit() end
function draw_string() end
function draw_string_Helvetica_10() end
function draw_string_Helvetica_12() end
function draw_string_Helvetica_18() end
function measure_string(t) return #tostring(t) * 7 end
function command_once() end
function command_begin() end
function command_end() end
function toast() end
function float_wnd_create() return {} end
function float_wnd_set_title() end
function float_wnd_set_imgui_builder() end
function float_wnd_set_onclose() end
function float_wnd_set_ondraw() end
function float_wnd_set_onclick() end
function float_wnd_destroy() end
function XPLMFindDataRef(p) return { path = p } end
function XPLMGetDataf() return 0 end
function XPLMGetDatai() return 0 end
function XPLMSetDataf() end
function XPLMSetDatai() end
function XPLMSetGraphicsState() end
function XPLMGetScreenSize() return 2560, 1440 end
function XPLMFindNavAid() return 0 end
function XPLMGetNavAidInfo() return 0,0,0,0,0,0,"XXXX","Mock Airport" end
function XPLMSetFMSEntryLatLon() end
function XPLMCountFMSEntry() return 0 end
function glColor4f() end
function glRectf() end
function kc_file_exists() return false end
function load_preferences() end
function save_preferences() end

-- imgui: KPCrew calls a lot of it; return a permissive table
_G.imgui = setmetatable({}, { __index = function() return function() return false end end })
-- NOTE: FlyWithLua's real imgui is a table of functions, mirrored above.

------------------------------------------------------ LuaSocket shim (preload)
package.preload["socket.core"] = function() return {} end
package.preload["socket"] = function()
  local s = {}
  s.tcp = function() return { connect = function() return 1, "ok" end, close = function() end } end
  s.gettime = function() return 0 end
  s.sleep  = function() end
  return s
end
package.preload["socket.http"] = function()
  return { request = function() return "", 200 end }
end
package.preload["mime"] = function() return { } end
package.preload["mime.core"] = function() return {} end
package.preload["ltn12"] = function() return { source = {}, sink = {} } end

--------------------------------------------------- FlyWithLua-style require --
table.insert(package.searchers or package.loaders, function(name)
  local rel = name:gsub("%.", "/")
  for _, prefix in ipairs({ "Modules/", "./", "" }) do
    local path = prefix .. rel .. ".lua"
    local fh = io.open(path, "r")
    if fh then fh:close() return function() return dofile(path) end end
  end
  return "\n\tno file '" .. rel .. ".lua'"
end)

--------------------------------------------------------------------- run ------
print("=== " .. script_path .. " ===")
local chunk, err = loadfile(script_path)
if not chunk then print("SYNTAX ERROR: " .. tostring(err)) os.exit(1) end

local ok, run_err = pcall(chunk)
if ok then
  print("RESULT: chunk COMPLETED")
else
  print("RESULT: chunk ABORTED")
  print("        " .. tostring(run_err):gsub("\n.*", ""))
end

----------------------------------------------------------------- analyse ------
local problems = 0
print(string.format("\n-- datarefs bound: %d --", #bound))
for _, b in ipairs(bound) do
  local typ = types[b.path]
  local where = string.format("%s [%s]", tostring(b.name), tostring(b.path))
  if b.mode == "table" then
    if typ and not is_array(typ) then
      print("  PROBLEM  dataref_table on a scalar: " .. where .. "  (" .. typ .. ")"); problems = problems + 1
    end
  elseif typ == nil then
    if not (b.path:match("^laminar/") or b.path:match("^kp/")) then
      print("  PROBLEM  not in DataRefs.txt: " .. where); problems = problems + 1
    end
  elseif is_array(typ) and not b.index then
    print("  PROBLEM  array bound without index: " .. where .. "  (" .. typ .. ")"); problems = problems + 1
  end
end

print(string.format("\ncommands=%d macros=%d datarefs=%d problems=%d",
  #commands, #macros, #bound, problems))
os.exit((ok and problems == 0) and 0 or 1)
