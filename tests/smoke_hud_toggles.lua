--[[
  smoke_hud_toggles.lua — verify the MasterSuite control panel.

  The suite no longer draws a telemetry HUD or a C750 systems readback (the
  aircraft's own PFD/EICAS/synoptics already show that data). What must keep
  working is the control panel: one clickable row per subsystem, plus the
  sibling-panel toggles that reach into CabinOps, FailureTrainer, the EFB and
  LandingPerformance.

  Usage:
    HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_hud_toggles.lua Scripts/CitationX_MasterSuite.lua
--]]

local script = arg[1] or "Scripts/CitationX_MasterSuite.lua"
local fails = 0
local function check(ok, label, detail)
  if ok then
    print("PASS  " .. label)
  else
    print("FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    fails = fails + 1
  end
end

-- ---------- mock FlyWithLua ----------
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
VKEY, CKEY, MOUSE_X, MOUSE_Y = 0, "", 0, 0
MOUSE_STATUS, MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = "up", 0, 0
PLANE_ICAO = "C750"
Control = {} ; Menu = {}

local datarefs, commands, macros = {}, {}, {}
local draw_cb
local primitives = 0

function dataref(name, path, mode, index)
  datarefs[#datarefs + 1] = { name = name, path = path, mode = mode, index = index }
  _G[name] = 0
  return _G[name]
end
function dataref_table(path) return setmetatable({}, { __index = function() return 0 end }) end
function get() return 0 end
function set() end
function logMsg(s) if os.getenv("VERBOSE") then print("      [log] " .. tostring(s)) end end
function create_command(name, desc, act, on, off)
  commands[#commands + 1] = { name = name, act = act, on = on, off = off }
  return { name = name }
end
function add_macro(name, act, on, off) macros[#macros + 1] = { name = name } end
function do_every_draw(f)
  if type(f) == "function" then draw_cb = f
  elseif type(f) == "string" then draw_cb = assert(load(f)) end
end
function do_every_frame(f) end
function do_often(f) end
function do_sometimes(f) end
function do_every_second(f) end
function draw_string() primitives = primitives + 1 end
function draw_string_Helvetica_10() primitives = primitives + 1 end
function draw_string_Helvetica_12() primitives = primitives + 1 end
function draw_string_Helvetica_18() primitives = primitives + 1 end
function measure_string(t) return #tostring(t) * 7 end
function command_once() end
function toast() end
function XPLMFindDataRef(p) return { path = p } end
function XPLMGetDataf() return 0 end
function XPLMGetDatai() return 0 end
function XPLMSetDataf() end
function XPLMSetDatai() end
function XPLMSetGraphicsState() end
function glColor4f() end
function glRectf() primitives = primitives + 1 end
function load_preferences() end
function save_preferences() end
function read_preferences() end
function do_on_exit() end
function do_on_keystroke() end
function do_on_mouse_click() end
function do_on_mouse_wheel() end
function do_every_draw_sometimes() end
function float_wnd_create(...) return {} end
function float_wnd_set_title() end
function float_wnd_set_imgui_builder() end
function float_wnd_set_onclose() end
function float_wnd_destroy() end
function XPLMGetScreenSize() return 2560, 1440 end
function XPLMGetMouseLocationGlobal() return 0, 0 end
function XPLMGetVirtualKeyDescription() return "" end

-- ---------- load ----------
-- FlyWithLua loads Scripts/ alphabetically; the shared core always comes first.
local core = (script:match("^(.*/)") or "") .. "CitationX_00_Core.lua"
local core_chunk = assert(loadfile(core))
core_chunk()
local chunk = assert(loadfile(script))
chunk()

check(type(SUITE_MODULES) == "table", "SUITE_MODULES exists")
check(type(SUITE_STYLE) == "table", "SUITE_STYLE exists")

-- ---------- at load only the ImGui Control Center is on screen -------------
check(CONFIG.status_enabled == false, "legacy hub is hidden at load")
check(CONFIG.axis_monitor == false, "axis monitor starts hidden")
check(CONFIG.flow_tab == "control", "the hub starts on the CONTROL page")
check(type(citationx_set_flow_tab) == "function", "the FLOWS page has a public tab switch")
check(type(citationx_debrief_poll) == "function", "the debrief poll is registered")

local command_names = {}
for _, c in ipairs(commands) do command_names[c.name] = true end
for _, name in ipairs({
  "CitationXSuite/flows_toggle", "CitationXSuite/flows_next",
  "CitationXSuite/flows_back", "CitationXSuite/flows_reset",
  "CitationXSuite/debrief_write", "CitationXSuite/debrief_report",
}) do
  check(command_names[name] == true, "command exists: " .. name)
end

-- ---------- and nothing else is switched on -------------------------------
local on_at_load = {}
for i = 1, #SUITE_MODULES do
  local m = SUITE_MODULES[i]
  if m.state() == "ON" then on_at_load[#on_at_load + 1] = m.key end
end
table.sort(on_at_load)
check(#on_at_load == 1 and on_at_load[1] == "wheel",
  "only the wheel row starts ON",
  table.concat(on_at_load, ","))

-- ---------- the duplicate cockpit readouts must not come back ----------
check(rawget(_G, "SYSTEMS_PANEL") == nil, "no C750 systems readback table")
check(rawget(_G, "SYSTEMS_ITEMS") == nil, "no C750 systems item list")
check(rawget(_G, "HUD_STYLE") == nil, "no HUD palette left behind")

-- ---------- every module row is complete ----------
local expected = {
  "status", "axis", "log", "emerg", "axmon", "texture", "wheel",
  "avitab", "cabin", "qrh", "instructor", "landperf", "realism",
}
local seen = {}
for i, m in ipairs(SUITE_MODULES) do
  local tag = "module[" .. i .. "] " .. tostring(m.key)
  check(type(m.key) == "string" and m.key ~= "", tag .. " has key")
  check(type(m.label) == "string", tag .. " has label")
  check(type(m.get) == "function", tag .. " has get()")
  check(type(m.set) == "function", tag .. " has set()")
  check(type(m.state) == "function", tag .. " has state()")
  check(not seen[m.key], tag .. " key is unique", m.key)
  seen[m.key] = true

  local ok_get, val = pcall(m.get)
  check(ok_get, tag .. " get() runs", val)
  local ok_state, text, extra = pcall(m.state)
  check(ok_state, tag .. " state() runs", text)
  check(ok_state and type(text) == "string" and text ~= "", tag .. " state() returns text")
  check(ok_state and extra == nil, tag .. " state() returns a single value")
end

check(#SUITE_MODULES == #expected, "module count matches the control panel",
  #SUITE_MODULES .. " vs " .. #expected)
for _, key in ipairs(expected) do
  check(seen[key] == true, "expected module present: " .. key)
end
for _, key in ipairs({ "hud", "systems" }) do
  check(seen[key] == nil, "display-only module removed: " .. key)
end

-- The realism row is now a panel switch for the Control Center; the background
-- pack stays armed independently, so silencing the panel cannot kill callouts.
local realism_module
for _, m in ipairs(SUITE_MODULES) do
  if m.key == "realism" then realism_module = m end
end
check(realism_module ~= nil, "realism module exists")
if realism_module then
  check(realism_module.label == "REALISM PANEL", "realism row is the panel switch",
    realism_module.label)
  REAL_CONFIG = { enabled = true, hud_enabled = false }
  function real_set_hud(on) REAL_CONFIG.hud_enabled = (on == true) end
  check(realism_module.state() == "OFF", "realism panel starts OFF")
  realism_module.set(true)
  check(REAL_CONFIG.hud_enabled == true, "realism row opens the panel")
  check(REAL_CONFIG.enabled == true, "realism row leaves the pack armed")
  realism_module.set(false)
end

-- ---------- sibling-panel toggles present ----------
for _, key in ipairs({ "cabin", "qrh", "instructor", "landperf" }) do
  local found
  for _, m in ipairs(SUITE_MODULES) do if m.key == key then found = m end end
  check(found ~= nil, "sibling toggle present: " .. key)
  if found then
    local ok_state, text = pcall(found.state)
    check(ok_state, "sibling toggle " .. key .. " state() runs", text)
    check(ok_state and (text == "ABSENT" or text == "ON" or text == "OFF" or text == "SHOWN" or text == "HIDDEN"),
      "sibling toggle " .. key .. " reports a known state", text)
    -- toggling with the other script absent must not throw
    local ok_set = pcall(found.set, true)
    check(ok_set, "sibling toggle " .. key .. " set() is safe when the script is absent")
  end
end

-- ---------- toggling through the public entry point ----------
for _, key in ipairs(expected) do
  local ok, err = pcall(citationx_toggle_module, key)
  check(ok, "citationx_toggle_module('" .. key .. "') runs", err)
end
-- restore defaults for everything that was flipped
for _, key in ipairs(expected) do pcall(citationx_toggle_module, key) end

-- ---------- everything can be switched back on ----------
citationx_set_all(true)
check(CONFIG.log_enabled and CONFIG.emergency_enabled and CONFIG.axis_optimizer_enabled
  and CONFIG.axis_monitor, "enable all modules arms the hidden modules")
citationx_set_all(false)
check(not (CONFIG.log_enabled or CONFIG.emergency_enabled or CONFIG.axis_optimizer_enabled
  or CONFIG.axis_monitor), "disable all modules turns them off again")

-- ---------- every key and button belongs to X-Plane -----------------------
-- v3.0 registers no keystroke handler, no wheel handler and no input map, so
-- there is nothing that could consume a pilot input.
check(rawget(_G, "INPUT_BINDINGS") == nil, "no input binding table")
check(rawget(_G, "CITX_BINDINGS") == nil, "no keystroke binding table")
check(type(rawget(_G, "citationx_keystroke")) ~= "function", "no keystroke handler exists")
check(type(rawget(_G, "citationx_mouse_wheel")) == "function", "the mouse wheel handler exists")

check(CONFIG.alt_keys_enabled == nil, "the ALT SEL keystroke layer is gone")
check(CONFIG.input_map_enabled == nil, "the input mapper is gone")
check(CONFIG.stick_hdg_enabled == nil, "the stick heading knob is gone")

-- ---------- the control panel is the only thing drawn ----------
CONFIG.status_enabled     = false
CONFIG.axis_monitor       = false
citationx_sim_time        = 100.0   -- expire the toggle toasts
primitives = 0
citationx_overlay()
check(primitives == 0, "overlay draws nothing when every display is off", primitives .. " primitive(s)")

CONFIG.status_enabled = true
primitives = 0
citationx_overlay()
check(primitives > 20, "control panel draws content", primitives .. " primitive(s)")

-- ---------- nothing draws on another aircraft ------------------------------
PLANE_ICAO = "B738"
citationx_frame()
primitives = 0
citationx_overlay()
check(primitives == 0, "overlay draws nothing on a non-C750", primitives .. " primitive(s)")
PLANE_ICAO = "C750"
citationx_frame()
primitives = 0
citationx_overlay()
check(primitives > 20, "control panel returns on the C750", primitives .. " primitive(s)")

-- ---------- draw callback survives ----------
check(type(draw_cb) == "function", "draw callback registered")
if draw_cb then
  local ok, err = pcall(draw_cb)
  check(ok, "draw callback runs without error", err)
end

-- ---------- status report still works without a HUD ----------
local ok_report, err_report = pcall(citationx_status_report)
check(ok_report, "citationx_status_report() runs", err_report)

-- ---------- report ----------
print("")
if fails == 0 then
  print("ALL CONTROL PANEL TESTS PASSED")
  os.exit(0)
else
  print(fails .. " FAILURE(S)")
  os.exit(1)
end
