--[[
  smoke_mastersuite.lua — mock-FlyWithLua smoke test for the Master Suite hub.

  v3.0 has no keyboard or controller-button layer. The main mouse wheel stays
  with X-Plane for view zoom; only the second wheel drives ALT SEL. This test
  pins that contract and then exercises what is left: the pitch/roll axis
  optimizer, the flight recorder, the emergency generator, the livery cycler
  and the panel.

  Usage:
    HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_mastersuite.lua Scripts/CitationX_MasterSuite.lua
--]]

local TMP = os.getenv("TMPDIR") or "/tmp/"
SCRIPT_DIRECTORY = TMP
PLANE_ICAO = "C750"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
MOUSE_X, MOUSE_Y, MOUSE_STATUS = -1, -1, "up"
RESUME_MOUSE_CLICK = false

-- ---------- mock FlyWithLua ----------
local defaults = {
    mach_no = 0, g_nrml = 1, elevation_m = 0, ias_kts = 0,
    pitch_deg = 0, roll_deg = 0, citationx_sim_time = 0,
    joy_pitch = 0, joy_roll = 0, joy_avail_pitch = 1, joy_avail_roll = 1,
    yoke_pitch_ratio = 0, yoke_roll_ratio = 0,
    ovr_joystick_pitch = 0, ovr_joystick_roll = 0,
    citationx_livery_index = 0,
}

function dataref(name)
    _G[name] = defaults[name] or 0
end

local livery_bytes = {}
local axis_values, axis_assign
function dataref_table(path)
    local t = setmetatable({}, { __index = function() return 0 end })
    if path == "sim/joystick/joystick_axis_values" then
        axis_values = t
    elseif path == "sim/joystick/joystick_axis_assignments" then
        axis_assign = t
    elseif path == "sim/aircraft/view/acf_livery_path" then
        return livery_bytes
    end
    return t
end

local logs = {}
function logMsg(s) logs[#logs + 1] = tostring(s) end
local function logged(text)
    for _, l in ipairs(logs) do
        if l:find(text, 1, true) then return true end
    end
    return false
end

local commands, macros = {}, {}
function create_command(name, description, function_body) commands[name] = true end
function add_macro(label) macros[label] = true end
function command_once(name) commands[#commands + 1] = name; commands.executed[#commands.executed + 1] = name end
commands.executed = {}

local frame_cb, draw_cb, exit_cb, click_cb
local keystroke_cb, wheel_cb
local function as_fn(f)
    if type(f) == "function" then return f end
    return assert(loadstring(f))
end
function do_every_frame(f) frame_cb = as_fn(f) end
function do_every_draw(f) draw_cb = as_fn(f) end
function do_on_exit(f) exit_cb = as_fn(f) end
function do_on_mouse_click(f) click_cb = as_fn(f) end
function do_on_keystroke(f) keystroke_cb = as_fn(f) end
function do_on_mouse_wheel(f) wheel_cb = as_fn(f) end

local drawn = {}
function draw_string(x, y, text) drawn[#drawn + 1] = tostring(text) end
draw_string_Helvetica_10 = draw_string
draw_string_Helvetica_12 = draw_string
draw_string_Helvetica_18 = draw_string
function measure_string(t) return #tostring(t) * 7 end
function glColor4f() end
function glRectf() end
function XPLMSetGraphicsState() end
function XPLMFindDataRef() return nil end
function XPLMGetDataf() return 0 end

local SCRIPT = arg[1] or "Scripts/CitationX_MasterSuite.lua"
dofile(SCRIPT)

local fails = 0
local function check(ok, label, detail)
    if ok then
        print("PASS  " .. label)
    else
        print("FAIL  " .. label .. (detail ~= nil and ("  -> " .. tostring(detail)) or ""))
        fails = fails + 1
    end
end

local function frame(t)
    citationx_sim_time = t
    citationx_frame()
end

-- ---------- keyboard layer gone, mouse wheel is the only reader ----------
check(keystroke_cb == nil, "no do_on_keystroke handler is registered")
check(wheel_cb ~= nil, "the mouse wheel handler is registered")
for _, g in ipairs({ "INPUT_BINDINGS", "CITX_BINDINGS", "JOY_BINDINGS",
                     "INPUT_BINDING_LIST", "VIEW_PAN" }) do
    check(_G[g] == nil, "no " .. g .. " global")
end
for _, k in ipairs({ "stick_hdg_enabled", "alt_keys_enabled", "joy_autobind_enabled",
                     "view_pan_enabled", "trigger_throttle_enabled", "learn_mode" }) do
    check(CONFIG[k] == nil, "CONFIG." .. k .. " no longer exists")
end
check(CONFIG.axis_optimizer_enabled == true, "the axis optimizer is ON by default")
check(not logged("heading bug"), "no heading-bug engine in the log")

-- ---------- mouse wheel: main wheel zooms, thumbwheel -> heading ----------
check(CONFIG.mouse_wheel_altitude == true, "wheel 2 drives ALT SEL by default")
check(CONFIG.wheel_altitude_number == 2, "ALT SEL listens on the third wheel")
check(CONFIG.wheel_heading_number == 1, "heading listens on the thumbwheel")
check(CONFIG.wheel_heading_fast == true, "the heading wheel uses the big step")
citationx_alt_sel_ft, citationx_alt_legacy_ft = 10000, 10000
citationx_hdg_sel_deg = 100

-- the main scroll wheel (0) is never used and never consumed
MOUSE_WHEEL_NUMBER = 0
MOUSE_WHEEL_CLICKS = 3
RESUME_MOUSE_WHEEL = false
wheel_cb()
check(citationx_alt_sel_ft == 10000, "the main wheel leaves ALT SEL alone", citationx_alt_sel_ft)
check(citationx_hdg_sel_deg == 100, "the main wheel leaves heading alone", citationx_hdg_sel_deg)
check(RESUME_MOUSE_WHEEL == false, "the main wheel still reaches X-Plane (view zoom)")

-- the thumbwheel (1) steps the heading bug by 10 degrees per notch
MOUSE_WHEEL_NUMBER = 1
MOUSE_WHEEL_CLICKS = 4
RESUME_MOUSE_WHEEL = false
wheel_cb()
check(citationx_hdg_sel_deg == 140, "four thumbwheel notches add 40 deg", citationx_hdg_sel_deg)
check(RESUME_MOUSE_WHEEL == true, "the thumbwheel notch is consumed (no view zoom)")
MOUSE_WHEEL_CLICKS = -2
wheel_cb()
check(citationx_hdg_sel_deg == 120, "thumbwheel backward subtracts 20 deg", citationx_hdg_sel_deg)

-- the third wheel (2) moves ALT SEL
MOUSE_WHEEL_NUMBER = 2
MOUSE_WHEEL_CLICKS = 3
RESUME_MOUSE_WHEEL = false
wheel_cb()
check(citationx_alt_sel_ft == 10300, "three altitude-wheel notches add 300 ft", citationx_alt_sel_ft)
check(citationx_alt_legacy_ft == 10300, "the legacy altitude dial follows", citationx_alt_legacy_ft)
check(RESUME_MOUSE_WHEEL == true, "the altitude wheel notch is consumed")
MOUSE_WHEEL_CLICKS = -5
wheel_cb()
check(citationx_alt_sel_ft == 9800, "altitude wheel backward subtracts", citationx_alt_sel_ft)
citationx_alt_sel_ft = 49800
MOUSE_WHEEL_CLICKS = 10
wheel_cb()
check(citationx_alt_sel_ft == 50000, "ALT SEL clamps at the ceiling", citationx_alt_sel_ft)
citationx_alt_sel_ft = 100
MOUSE_WHEEL_CLICKS = -10
wheel_cb()
check(citationx_alt_sel_ft == 0, "ALT SEL clamps at the floor", citationx_alt_sel_ft)

citationx_set_wheel_altitude(false)
MOUSE_WHEEL_CLICKS = 2
RESUME_MOUSE_WHEEL = false
local alt_before = citationx_alt_sel_ft
wheel_cb()
check(citationx_alt_sel_ft == alt_before, "the wheel row can switch it off")
check(RESUME_MOUSE_WHEEL == false, "a switched-off wheel is not consumed")
citationx_set_wheel_altitude(true)

citationx_wheel_map_swap()
check(CONFIG.wheel_altitude_number == 1 and CONFIG.wheel_heading_number == 2,
    "the wheel map can be swapped")
citationx_wheel_map_swap()
citationx_wheel_report()
check(logged("last wheel event"), "the wheel report logs")
MOUSE_WHEEL_NUMBER = nil

-- big-step heading commands
citationx_hdg_sel_deg = 355
citationx_hdg_fast_up()
check(citationx_hdg_sel_deg == 5, "fast heading up adds 10 deg and wraps", citationx_hdg_sel_deg)
citationx_hdg_fast_down()
check(citationx_hdg_sel_deg == 355, "fast heading down subtracts 10 deg", citationx_hdg_sel_deg)

-- ---------- heading bug and the two light commands ----------
citationx_hdg_sel_deg = 359
citationx_hdg_up()
check(citationx_hdg_sel_deg == 0, "heading bug wraps forward past north", citationx_hdg_sel_deg)
citationx_hdg_down()
check(citationx_hdg_sel_deg == 359, "heading bug wraps backward past north", citationx_hdg_sel_deg)

local n0 = #commands.executed
citationx_taxi_light()
check(commands.executed[#commands.executed] == "sim/lights/taxi_lights_toggle",
    "taxi light uses X-Plane's own toggle", commands.executed[#commands.executed])
citationx_landing_lights()
check(commands.executed[#commands.executed] == "sim/lights/landing_lights_toggle",
    "landing lights use X-Plane's own toggle", commands.executed[#commands.executed])
check(#commands.executed == n0 + 2, "each action fires exactly one command")

-- ---------- axis optimizer ----------
frame(1.0)
check(ovr_joystick_pitch == 1 and ovr_joystick_roll == 1,
    "optimizer takes the pitch/roll axes", tostring(ovr_joystick_pitch) .. "/" .. tostring(ovr_joystick_roll))

joy_pitch, joy_roll = 0.5, -0.5
for i = 1, 40 do frame(1.0 + i / 60) end
check(yoke_pitch_ratio > 0.30 and yoke_pitch_ratio < 0.50,
    "half stick is shaped, not passed through", yoke_pitch_ratio)
check(yoke_roll_ratio < -0.30 and yoke_roll_ratio > -0.50,
    "roll is shaped symmetrically", yoke_roll_ratio)
table.insert(logs, "")
check(logged("axis optimizer engaged"), "engaging the optimizer is logged")

-- deadzone: a 1 % input never reaches the controls
joy_pitch, joy_roll = 0.01, -0.01
for i = 1, 200 do frame(2.0 + i / 60) end
check(math.abs(yoke_pitch_ratio) < 0.002, "deadzone swallows a 1 % input", yoke_pitch_ratio)

-- full deflection still reaches the stop
joy_pitch, joy_roll = 1.0, -1.0
for i = 1, 200 do frame(5.0 + i / 60) end
check(yoke_pitch_ratio > 0.99, "full pitch reaches the stop", yoke_pitch_ratio)
check(yoke_roll_ratio < -0.99, "full roll reaches the stop", yoke_roll_ratio)

-- switching it off hands the axes straight back to X-Plane
citationx_set_axis(false)
check(CONFIG.axis_optimizer_enabled == false, "citationx_set_axis(false) disables it")
frame(10.0)
check(ovr_joystick_pitch == 0 and ovr_joystick_roll == 0,
    "releasing the optimizer clears both overrides")
check(logged("axis optimizer released"), "release is logged")

citationx_set_axis(true)
frame(11.0)
check(ovr_joystick_pitch == 1, "re-enabling it takes the axes again")

-- a missing stick must not leave X-Plane overridden
joy_avail_pitch, joy_avail_roll = 0, 0
frame(12.0)
check(ovr_joystick_pitch == 0 and ovr_joystick_roll == 0,
    "no mapped stick releases the override")
joy_avail_pitch, joy_avail_roll = 1, 1
frame(13.0)

-- ---------- flight recorder ----------
check(CONFIG.log_enabled == false, "the recorder starts off")
citationx_set_logging(true)
check(CONFIG.log_enabled == true, "citationx_set_logging(true) arms it")
local rec = io.open(TMP .. "XPlane_CitationX_FlightLog.csv", "r")
check(rec ~= nil, "the recorder creates its CSV")
if rec then rec:close() end
frame(20.0)
frame(21.5)
citationx_set_logging(false)
local rec2 = io.open(TMP .. "XPlane_CitationX_FlightLog.csv", "r")
local body = rec2 and rec2:read("*a") or ""
if rec2 then rec2:close() end
check(body:find("Time_Sec,Altitude_FT", 1, true) ~= nil, "the CSV has a header")
check(select(2, body:gsub("\n", "")) >= 2, "at least one sample was written", body)

-- ---------- emergency generator ----------
citationx_set_emergency(true)
check(CONFIG.emergency_enabled == true, "the emergency generator arms")
citationx_test_emergency()
check(logged("TEST bleed air"), "the test command logs")
frame(30.0)
citationx_set_emergency(false)
frame(31.0)

-- ---------- livery cycler ----------
citationx_texture_next()
check(commands.executed[#commands.executed] == "sim/operation/next_livery",
    "texture_next runs X-Plane's own next_livery", commands.executed[#commands.executed])
citationx_texture_prev()
check(commands.executed[#commands.executed] == "sim/operation/prev_livery",
    "texture_prev runs X-Plane's own prev_livery", commands.executed[#commands.executed])
citationx_texture_report()
check(logged("texture = "), "the texture is reported to the log")
CONFIG.texture_cycle_enabled = false
local before = #commands.executed
citationx_texture_next()
check(#commands.executed == before, "the cycler can be disabled")
CONFIG.texture_cycle_enabled = true

-- ---------- module registry ----------
local keys = {}
for _, m in ipairs(SUITE_MODULES) do keys[m.key] = true end
for _, k in ipairs({ "status", "axis", "log", "emerg", "axmon", "texture",
                     "wheel", "avitab", "cabin", "qrh", "landperf", "efb", "realism" }) do
    check(keys[k] == true, "module '" .. k .. "' is registered")
end
for _, k in ipairs({ "input", "learn", "stick", "look" }) do
    check(keys[k] == nil, "input-layer module '" .. k .. "' is gone")
end
check(logged("input layer = thumbwheel"), "the status report names the wheel input")

-- ---------- panel ----------
drawn = {}
draw_cb()
local text = table.concat(drawn, "\n")
check(text:find("CITATION X", 1, true) ~= nil, "the panel draws its title")
check(text:find("MASTER SUITE", 1, true) ~= nil, "the panel shows its version")
check(text:find("NO KEYBINDS", 1, true) ~= nil, "the panel says it owns no keybinds")
check(text:find("AIRCRAFT TEXTURE", 1, true) ~= nil, "the texture row is on the panel")

local h = citationx_panel_height()
local top = SUITE_STYLE.top
check(top - h >= 0, "the panel fits on the screen", top - h)

-- click the second row (axis optimizer) and check it toggles
local function row_y(i)
    local body_top = top - SUITE_STYLE.header_h
    local first_y = body_top - SUITE_STYLE.sub_h - 15
    local row_top = first_y + SUITE_STYLE.row_h - (i - 1) * SUITE_STYLE.row_h
    return row_top - 11
end
local function click(x, y)
    MOUSE_X, MOUSE_Y, MOUSE_STATUS = x, y, "down"
    RESUME_MOUSE_CLICK = false
    click_cb()
    MOUSE_STATUS = "up"
end

local axis_was = CONFIG.axis_optimizer_enabled
click(SUITE_STYLE.x + 40, row_y(2))
check(CONFIG.axis_optimizer_enabled == not axis_was, "clicking the axis row toggles it")
check(RESUME_MOUSE_CLICK == true, "the click is consumed")
click(SUITE_STYLE.x + 40, row_y(2))
check(CONFIG.axis_optimizer_enabled == axis_was, "clicking it again restores it")

-- the texture row is an action, not a switch
local n = #commands.executed
click(SUITE_STYLE.x + 40, row_y(6))
check(#commands.executed == n + 1, "clicking the texture row cycles the livery")

-- AviTab row: with the plugin absent it must toast, never fire a command
local avitab_row = nil
for i, m in ipairs(SUITE_MODULES) do if m.key == "avitab" then avitab_row = i end end
check(avitab_row ~= nil, "the AviTab row is on the panel")
check(avitab_state() == "ABSENT", "AviTab reports ABSENT while the plugin is missing")
if avitab_row then
  local before_av = #commands.executed
  click(SUITE_STYLE.x + 40, row_y(avitab_row))
  check(#commands.executed == before_av, "no AviTab command is fired when it is absent")
  citationx_avitab_charts()
  check(#commands.executed == before_av, "citationx_avitab_charts() is a no-op when absent")
  citationx_avitab_report()
  check(logged("AviTab is not installed"), "the report says AviTab is not installed")
end

-- header drag moves the panel
MOUSE_X, MOUSE_Y = SUITE_STYLE.x + 80, top - 10
MOUSE_STATUS = "down"
click_cb()
MOUSE_X, MOUSE_Y, MOUSE_STATUS = SUITE_STYLE.x + 80 - 120, top - 10 - 40, "drag"
click_cb()
check(SUITE_STYLE.x < 470, "the panel follows a header drag", SUITE_STYLE.x)
MOUSE_STATUS = "up"
MOUSE_X, MOUSE_Y = -1, -1
click_cb()

-- footer hides the panel (redraw first: the click rects are rebuilt each draw)
top = SUITE_STYLE.top
h = citationx_panel_height()
drawn = {}
draw_cb()
local footer_y = (top - h) + 7 + 11
click(SUITE_STYLE.x + SUITE_STYLE.width / 2, footer_y)
check(CONFIG.status_enabled == false, "the hide button closes the panel")
frame(200.0)   -- let the 2 s toast expire
drawn = {}
draw_cb()
check(#drawn == 0, "a hidden panel draws nothing", #drawn)
citationx_set_status(true)

-- ---------- shutdown ----------
exit_cb()
check(ovr_joystick_pitch == 0 and ovr_joystick_roll == 0,
    "shutdown releases both overrides")

print("")
if fails == 0 then
    print("ALL MASTER SUITE TESTS PASSED")
    os.exit(0)
else
    print(fails .. " MASTER SUITE TEST(S) FAILED")
    os.exit(1)
end
