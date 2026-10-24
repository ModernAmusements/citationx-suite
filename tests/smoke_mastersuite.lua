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
}

function dataref(name, path, access, index)
    _G[name] = defaults[name] or 0
end

local axis_values, axis_assign
function dataref_table(path)
    local t = setmetatable({}, { __index = function() return 0 end })
    if path == "sim/joystick/joystick_axis_values" then
        axis_values = t
    elseif path == "sim/joystick/joystick_axis_assignments" then
        axis_assign = t
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

print("\nALL MASTERSUITE STICK TESTS PASSED")
