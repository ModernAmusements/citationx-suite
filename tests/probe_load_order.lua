--[[
  probe_load_order.lua — load every script in Scripts/ in FlyWithLua's
  alphabetical order, in ONE shared Lua state, the way X-Plane does.

  This is the only harness that reproduces the real runtime: KPCrew's scripts
  depend on globals created by kpcrew23.lua (activePrefSet, kc_* modules), so
  testing them in isolation gives false failures.

  Usage: luajit tests/probe_load_order.lua <DataRefs.txt> <Scripts dir>
--]]

local datarefs_path = arg[1]
local scripts_dir   = arg[2] or "Scripts"

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
-- byte[] datarefs (acf paths, strings) are arrays without an index: they are
-- read with dataref_table() but never need an explicit subscript.
local function is_array(t) return t and t:find("%[") ~= nil end
local function needs_index(t) return t and t:find("%[%d+%]") ~= nil end

------------------------------------------------------------ mock FlyWithLua --
-- Every dataref()/dataref_table() is attributed to the script being loaded.
local current_script = "?"
local bound = {}          -- { script=, name=, path=, mode=, index= }

SCRIPT_DIRECTORY      = "./Scripts/"
PLUGIN_MAIN_DIRECTORY = "./"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"
MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = 0, 0

function dataref(varname, path, mode, index)
  bound[#bound + 1] = { script = current_script, name = varname, path = path, mode = mode, index = index }
  _G[varname] = 0
end
function dataref_table(path)
  bound[#bound + 1] = { script = current_script, name = "<table>", path = path, mode = "table" }
  return setmetatable({}, { __index = function() return 0 end })
end
function get() return 0 end
function set() end
function logMsg() end
function create_command() return {} end
function add_macro() end
function do_every_draw() end
function do_every_frame() end
function do_often() end
function do_sometimes() end
function do_every_second() end
function do_on_exit() end
function do_on_keystroke() end
function do_on_mouse_click() end
function do_on_mouse_wheel() end
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
function XPLMGetNavAidInfo() return 0,0,0,0,0,0,"XXXX","Mock" end
function XPLMSetFMSEntryLatLon() end
function XPLMCountFMSEntry() return 0 end
function glColor4f() end
function glRectf() end
function kc_file_exists() return false end
function load_preferences() end
function save_preferences() end

_G.imgui = setmetatable({}, { __index = function() return function() return false end end })

------------------------------------------------ LuaSocket / mime preload ----
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
package.preload["mime"] = function() return {} end
package.preload["mime.core"] = function() return {} end
package.preload["ltn12"] = function() return { source = {}, sink = {} } end

--------------------------------------------------- FlyWithLua-style require --
table.insert(package.searchers or package.loaders, function(name)
  local rel = name:gsub("%.", "/")
  for _, prefix in ipairs({ "Modules/", "Internals/", "./", "" }) do
    local path = prefix .. rel .. ".lua"
    local fh = io.open(path, "r")
    if fh then
      fh:close()
      -- Pass the module name so `module(..., package.seeall)` works, the way
      -- the standard Lua 5.1 loader does.
      return function(modname)
        local chunk = assert(loadfile(path))
        return chunk(modname, path)
      end
    end
  end
  return "\n\tno file '" .. rel .. ".lua'"
end)

--------------------------------------------------------------------- run ------
-- FlyWithLua loads Scripts/ alphabetically.
local list = {}
local p = io.popen('ls -1 "' .. scripts_dir .. '"/*.lua 2>/dev/null')
for line in p:lines() do list[#list + 1] = line end
p:close()
table.sort(list)

print("loading " .. #list .. " script(s) in one shared state\n")
local failed = 0
for _, path in ipairs(list) do
  local name = path:match("([^/]+)$")
  current_script = name
  local chunk, err = loadfile(path)
  if not chunk then
    print(string.format("  SYNTAX  %-28s %s", name, err))
    failed = failed + 1
  else
    local ok, run_err = pcall(chunk)
    if ok then
      print(string.format("  ok      %s", name))
    else
      print(string.format("  FAIL    %-28s %s", name, tostring(run_err):gsub("\n.*", "")))
      failed = failed + 1
    end
  end
end

----------------------------------------------------------------- analyse ------
local problems = 0
local first_writable = {}
for _, b in ipairs(bound) do
  local typ = types[b.path]
  local where = string.format("%s: %s [%s]", b.script, tostring(b.name), tostring(b.path))
  if b.mode == "writable" then
    local owner = first_writable[b.path]
    if owner then
      print("  PROBLEM  duplicate writable binding: " .. where .. " (already writable in " .. owner .. ")"); problems = problems + 1
    else
      first_writable[b.path] = b.script
    end
  end
  if b.mode == "table" then
    if typ and not is_array(typ) then
      print("  PROBLEM  dataref_table on scalar: " .. where .. " (" .. typ .. ")"); problems = problems + 1
    end
  elseif typ == nil then
    if not (b.path:match("^laminar/") or b.path:match("^kp/")) then
      print("  PROBLEM  not in DataRefs.txt: " .. where); problems = problems + 1
    end
  elseif is_array(typ) and needs_index(typ) and not b.index then
    print("  PROBLEM  array without index: " .. where .. " (" .. typ .. ")"); problems = problems + 1
  end
end

print(string.format("\n%d dataref binding(s), %d load failure(s), %d binding problem(s)",
  #bound, failed, problems))
os.exit((failed == 0 and problems == 0) and 0 or 1)
