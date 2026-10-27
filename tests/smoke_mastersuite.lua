-- Mock-FlyWithLua smoke test for the CitationX_MasterSuite stick-heading fix.
-- Verifies: L2/R2 trigger axes can never grab the heading bug, the right-stick
-- axis locks (sticky), and a dead USB/Bluetooth slot is vetoed after 6 s so it
-- cannot free-run the bug.

local TMP = os.getenv("TMPDIR") or "/tmp/"
SCRIPT_DIRECTORY = TMP
PLANE_ICAO = "C750"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440

local defaults = {
    mach_no = 0, g_nrml = 1, elevation_m = 0, ias_kts = 0,
    pitch_deg = 0, roll_deg = 0, citationx_sim_time = 0,
    joy_pitch = 0, joy_roll = 0, joy_avail_pitch = 1, joy_avail_roll = 1,
    yoke_pitch_ratio = 0, yoke_roll_ratio = 0,
    ovr_joystick_pitch = 0, ovr_joystick_roll = 0,
    alt_sel_ft = 10000, alt_legacy_ft = 10000, hdg_sel_deg = 180,
    view_panel_type = 2,   -- 3-D cockpit lit: the look tests run there
}

function dataref(name, path, access, index)
    _G[name] = defaults[name] or 0
end

local axis_values, axis_assign, button_assign, button_values
function dataref_table(path)
    local t = setmetatable({}, { __index = function() return 0 end })
    if path == "sim/joystick/joystick_axis_values" then
        axis_values = t
    elseif path == "sim/joystick/joystick_axis_assignments" then
        axis_assign = t
    elseif path == "sim/joystick/joystick_button_assignments" then
        button_assign = t
    elseif path == "sim/joystick/joystick_button_values" then
        button_values = t
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

function create_command() end
function add_macro() end
function command_once() end
function do_every_frame() end
function do_every_draw() end
function do_on_exit() end
function do_on_keystroke() end
function do_on_mouse_click() end
function do_on_mouse_wheel() end
function XPLMFindDataRef() return nil end
function XPLMGetDataf() return 0 end

local SCRIPT = arg[1] or "CitationX_MasterSuite.lua"
dofile(SCRIPT)

-- The suite now loads with the heading knob (like every other module) off;
-- this harness is about the stick logic itself, so switch it on explicitly.
CONFIG.stick_hdg_enabled = true

local function frame(t)
    citationx_sim_time = t
    citationx_frame()
end

local function delta(after, before)
    local d = (after - before) % 360
    if d > 180 then d = d - 360 end
    return d
end

local function check(name, cond, detail)
    if cond then
        print("PASS  " .. name)
    else
        print("FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
        os.exit(1)
    end
end

-- controller layout: left stick assigned, right stick + triggers unassigned
axis_assign[0], axis_assign[1], axis_assign[2] = 2, 1, 3
axis_values[0], axis_values[1], axis_values[2], axis_values[3] = 0.5, 0.5, 0.5, 0.5
axis_values[4], axis_values[5] = 0.0, 0.0          -- L2/R2 at rest
axis_values[27], axis_values[28] = 0.5, 0.5        -- right stick (unassigned)

frame(0)   -- baseline frame (dt = 0)
frame(1)   -- learn rests

-- 1. triggers must never grab the heading bug --------------------------------
local h0 = hdg_sel_deg
axis_values[4], axis_values[5] = 1.0, 1.0          -- squeeze both triggers
frame(2)
check("L2/R2 do not move heading", hdg_sel_deg == h0, delta(hdg_sel_deg, h0))
axis_values[4], axis_values[5] = 0.0, 0.0
frame(3)

-- 2. right stick takes the knob once ... -------------------------------------
local before = hdg_sel_deg
axis_values[27] = 0.9
frame(4)
local d = delta(hdg_sel_deg, before)
check("right stick drives heading", d > 10, d)
check("lock logged", logged("locked to raw axis 27"))

-- 3. ... and stays sticky when the stick is released -------------------------
axis_values[27] = 0.5
before = hdg_sel_deg
frame(5)
check("heading steady at rest", hdg_sel_deg == before, delta(hdg_sel_deg, before))

axis_values[28] = 0.9                              -- nudge the other axis
before = hdg_sel_deg
frame(6)
check("sticky: second axis ignored", hdg_sel_deg == before,
    delta(hdg_sel_deg, before))
axis_values[28] = 0.5
frame(7)

axis_values[27] = 0.1                              -- push the locked axis again
before = hdg_sel_deg
frame(8)
d = delta(hdg_sel_deg, before)
check("locked axis re-engages", d < -10, d)

-- 4. dead slot (USB unplugged: raw reads 0) must be vetoed -------------------
axis_values[27] = 0.0                              -- slot gone silent
for t = 9, 15 do frame(t) end                      -- 7 s > 6 s threshold
local settled = hdg_sel_deg
frame(16)
frame(17)
check("dead slot stops the bug", hdg_sel_deg == settled,
    delta(hdg_sel_deg, settled))

-- 5. the slot coming back to center revives it -------------------------------
axis_values[27] = 0.5
frame(18)                                          -- dead flag clears
axis_values[27] = 0.9
before = hdg_sel_deg
frame(19)
d = delta(hdg_sel_deg, before)
check("revived slot locks again", d > 10, d)

-- 6. module toggle re-arms cleanly -------------------------------------------
citationx_set_stick_hdg(false)
citationx_set_stick_hdg(true)
axis_values[27] = 0.5
frame(20)
axis_values[27] = 0.1
before = hdg_sel_deg
frame(21)
d = delta(hdg_sel_deg, before)
check("works after toggle", d < -5, d)

-- 7. regression: X-Plane reports -0.01 before the pad enumerates --------------
-- The 2026-10-24 log showed every axis with a learned rest of -0.01, so the
-- knob never locked. Reload the script with the right stick "not live yet".
logs = {}
dofile(SCRIPT)
CONFIG.stick_hdg_enabled = true

-- the mocks hand out fresh tables on reload, so re-publish the device state
axis_assign[0], axis_assign[1], axis_assign[2] = 2, 1, 3
axis_values[0], axis_values[1], axis_values[2], axis_values[3] = 0.5, 0.5, 0.5, 0.5
axis_values[4], axis_values[5] = 0.0, 0.0
axis_values[27], axis_values[28] = -0.01, -0.01

frame(30)                                          -- must NOT latch -0.01
axis_values[27], axis_values[28] = 0.5, 0.5        -- pad enumerates, centred
frame(31)
axis_values[27] = 0.9
before = hdg_sel_deg
frame(32)
d = delta(hdg_sel_deg, before)
check("late-enumerating right stick still locks", d > 10, d)
check("late lock logged", logged("locked to raw axis 27"))

-- 8. auto-bind uses ONLY the buttons X-Plane reports as unassigned -------------
-- The feature is off by default (it hijacked spare buttons in flight), so turn
-- it on explicitly for this check.
logs = {}
CONFIG.joy_autobind_enabled = true
for b = 8, 17 do button_assign[64 + b] = 500 end   -- second slot fully mapped
citationx_autobind_joy()
check("free button 8 bound in the free slot", JOY_BINDINGS[8] ~= nil)
check("first free button gets the panel", JOY_BINDINGS[8].label == "CONTROL PANEL",
    JOY_BINDINGS[8] and JOY_BINDINGS[8].label)
check("second free button gets realism", JOY_BINDINGS[9].label == "REALISM PANEL",
    JOY_BINDINGS[9] and JOY_BINDINGS[9].label)
check("already-mapped button is never overwritten", JOY_BINDINGS[64 + 8] == nil)
local panel_before = CONFIG.status_enabled
JOY_BINDINGS[8].action()
check("bound action actually runs", CONFIG.status_enabled ~= panel_before)
CONFIG.status_enabled = panel_before

-- 9. R3 + right stick looks around the 3-D cockpit ----------------------------
-- By now the right stick is locked to axis 27 (heading knob). Holding R3 must
-- take it over: same stick pans the head, the heading bug stays put.
axis_values[27], axis_values[28] = 0.5, 0.5
frame(40)
local hdg_before_look = hdg_sel_deg
local psi0, the0 = view_head_psi, view_head_the
button_values[11] = 1
axis_values[27] = 0.9
frame(41)
check("R3 + stick yaws the 3-D cockpit view", view_head_psi ~= psi0,
    view_head_psi)
check("R3 suppresses the heading knob", hdg_sel_deg == hdg_before_look,
    delta(hdg_sel_deg, hdg_before_look))

axis_values[27] = 0.5
axis_values[28] = 0.1                              -- stick pushed up
frame(42)
check("R3 + stick up pitches the view up", view_head_the > the0, view_head_the)

axis_values[28] = 0.5
button_values[11] = 0
frame(43)
axis_values[27] = 0.9
local hdg_after_look = hdg_sel_deg
frame(44)
check("heading knob resumes after R3 is released",
    delta(hdg_sel_deg, hdg_after_look) > 10,
    delta(hdg_sel_deg, hdg_after_look))

-- centring the stick while R3 is held must not drift the view
button_values[11] = 1
axis_values[27], axis_values[28] = 0.5, 0.5
frame(45)
local psi_hold, the_hold = view_head_psi, view_head_the
frame(46)
check("R3 at stick centre holds the view",
    view_head_psi == psi_hold and view_head_the == the_hold)
button_values[11] = 0
frame(47)

-- releasing R3 while the stick is still deflected must not hand the stick back
-- to the heading bug until it re-centres
button_values[11] = 1
axis_values[27], axis_values[28] = 0.5, 0.5
frame(48)
axis_values[27] = 0.9
frame(49)
local hdg_latched = hdg_sel_deg
button_values[11] = 0
frame(50)
check("heading knob waits for the stick to centre after R3",
    hdg_sel_deg == hdg_latched, delta(hdg_sel_deg, hdg_latched))
axis_values[27] = 0.5
frame(51)
axis_values[27] = 0.9
local hdg_recentre = hdg_sel_deg
frame(52)
check("heading knob resumes after the stick re-centres",
    delta(hdg_sel_deg, hdg_recentre) > 10,
    delta(hdg_sel_deg, hdg_recentre))

-- in a 2-D view the head offsets must not be written (R3 asks X-Plane for the
-- 3-D cockpit first; the pan starts on a later frame)
view_panel_type = 0
button_values[11] = 1
axis_values[27], axis_values[28] = 0.9, 0.5
local psi_2d = view_head_psi
frame(53)
check("2-D view: no head-offset writes", view_head_psi == psi_2d, view_head_psi)
button_values[11] = 0
axis_values[27] = 0.5
view_panel_type = 2
frame(54)

print("\nALL MASTERSUITE STICK TESTS PASSED")
