-- Mock-FlyWithLua smoke test for CitationX_MissionGenerator.lua
-- Exercises briefing/accept/skip, leg-by-leg progression, landing, scoring,
-- rules, abort, the emergency injection/clear path and the flight-school
-- lesson grading without X-Plane.

local TMP = os.getenv("TMPDIR") or "/tmp/"
SCRIPT_DIRECTORY = TMP
PLANE_ICAO = "C750"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
MOUSE_STATUS, MOUSE_X, MOUSE_Y = "up", 0, 0

local defaults = {
    ["sim/flightmodel/position/latitude"]            = 52.0,
    ["sim/flightmodel/position/longitude"]           = 13.0,
    ["sim/flightmodel/position/elevation"]           = 0.0,
    ["sim/flightmodel/position/y_agl"]               = 0.0,
    ["sim/flightmodel/position/vh_ind_fpm"]          = 0.0,
    ["sim/flightmodel/position/groundspeed"]         = 0.0,
    ["sim/flightmodel/position/indicated_airspeed"]  = 0.0,
    ["sim/flightmodel/position/phi"]                 = 0.0,
    ["sim/flightmodel/misc/machno"]                  = 0.0,
    ["sim/flightmodel2/misc/gforce_normal"]          = 1.0,
    ["sim/flightmodel/failures/onground_any"]        = 1,
    ["sim/flightmodel/weight/m_fuel_total"]          = 4000.0,
    ["sim/time/total_running_time_sec"]              = 0.0,
    ["sim/time/paused"]                              = 0,
}
local registered_datarefs = {}
function dataref(name, path, access, index)
    assert(type(name) == "string" and type(path) == "string", "bad dataref call")
    _G[name] = defaults[path]
    registered_datarefs[#registered_datarefs + 1] = { name = name, path = path }
end
function logMsg() end
function create_command() end
function add_macro() end
function do_every_frame() end
function do_every_draw() end
function do_on_mouse_click() end
function draw_string() end
function measure_string(s) return #tostring(s) * 8 end
function glColor4f() end
function glRectf() end
function XPLMSetGraphicsState() end

local qrh_inject_calls, qrh_clear_calls = 0, 0
function qrh_inject_by_key(key)
    qrh_inject_calls = qrh_inject_calls + 1
    assert(key == "flameout_l", "unexpected QRH key " .. tostring(key))
end
function qrh_clear() qrh_clear_calls = qrh_clear_calls + 1 end

local SCRIPT = arg[1] or "CitationX_MissionGenerator.lua"
os.remove(SCRIPT_DIRECTORY .. "CitationX_MissionProgress.txt")
dofile(SCRIPT)

local MG_IDLE, MG_BRIEF, MG_ARMED, MG_ACTIVE, MG_DONE = 0, 1, 2, 3, 4

local function frame(t)
    mg_simtime = t
    mg_frame()
end

local function check(name, cond, detail)
    if cond then
        print("PASS  " .. name)
    else
        print("FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
        os.exit(1)
    end
end

-- 1. briefing page ------------------------------------------------------------
check("datarefs registered", #registered_datarefs >= 13, #registered_datarefs)
mg_onground, mg_gs = 1, 0
check("generate on ground", mg_generate() == true)
check("state is BRIEF", mg_state == MG_BRIEF, mg_state)
local m = mg_mission
check("mission has story", m and type(m.story) == "table" and #m.story > 0)
check("mission has legs", type(m.legs) == "table" and #m.legs >= 2, m.legs and #m.legs)
check("last leg is home", m.legs[#m.legs].home == true, m.legs[#m.legs].name)
check("fix names unique", (function()
    local seen = {}
    for _, leg in ipairs(m.legs) do
        if seen[leg.name] then return false end
        seen[leg.name] = true
    end
    return true
end)())
check("budget set", m.budget_s > 0, m.budget_s)
check("title built", m.title:find(" - ") ~= nil, m.title)
mg_draw()   -- briefing page must render
check("briefing has accept + skip", #mg_buttons == 2, #mg_buttons)
print("      mission: " .. m.title .. "  [difficulty " .. m.difficulty .. "]")
for _, ln in ipairs(m.story) do print("      | " .. ln) end
print("      plan:")
for i, leg in ipairs(m.legs) do
    print(string.format("        %d  %-7s %03.0f deg / %.0f NM", i, leg.name, leg.brg, leg.dist_nm))
end

-- 2. skip draws a fresh briefing ---------------------------------------------
check("skip draws new briefing", mg_skip() == true)
check("still briefing", mg_state == MG_BRIEF, mg_state)
check("new mission object", mg_mission ~= m)
m = mg_mission

-- 3. accept arms the mission --------------------------------------------------
check("accept arms", mg_accept() == true)
check("state is ARMED", mg_state == MG_ARMED, mg_state)
mg_draw()
check("armed panel has abort button", #mg_buttons == 1, #mg_buttons)

-- 4. takeoff starts the clock -------------------------------------------------
mg_onground, mg_gs = 0, 90
frame(1)
check("state is ACTIVE after wheels up", mg_state == MG_ACTIVE, mg_state)

-- 5. fly the plan, leg by leg -------------------------------------------------
mg_elev, mg_agl = 3048.0, 3048.0
mg_mach, mg_ias, mg_bank, mg_gload = 0.80, 240, 5, 1.0
local t = 2
for i, leg in ipairs(m.legs) do
    mg_lat, mg_lon = leg.lat, leg.lon
    frame(t)
    t = t + 1
    check("leg " .. i .. " done (" .. leg.name .. ")",
        m.legs_done == i, m.legs_done)
end
check("clock running", mg_clock > 0.9, mg_clock)
mg_draw()   -- ACTIVE panel must render
check("active panel has a button", #mg_buttons == 1, #mg_buttons)

-- 6. rule engine: edge-triggered violations ----------------------------------
m.constraints = { "ias250" }
m.cstate = { ias250 = { viol = 0, was_bad = false, done = false } }
mg_ias, mg_agl = 300, 1000.0   -- 300 KT below 10k = violation
frame(t); t = t + 1
frame(t); t = t + 1
check("rule counts one episode", m.cstate.ias250.viol == 1, m.cstate.ias250.viol)
mg_ias = 200
frame(t); t = t + 1
mg_ias = 300
frame(t); t = t + 1
check("rule counts second episode", m.cstate.ias250.viol == 2, m.cstate.ias250.viol)

-- 7. land at home and stop ----------------------------------------------------
mg_lat, mg_lon = m.home_lat, m.home_lon
mg_onground, mg_gs, mg_vs = 1, 1.0, -120
frame(t); t = t + 1
check("mission completed", mg_state == MG_DONE, mg_state)
check("result is pass", mg_result and mg_result.ok == true)
check("score positive", mg_result.score > 0, mg_result.score)
print("      score: " .. mg_result.score)
for _, ln in ipairs(mg_result.lines) do print("      | " .. ln) end
check("streak incremented", mg_streak == 1, mg_streak)
check("best updated", mg_best == mg_result.score, mg_best)
check("flown counter", mg_completed == 1, mg_completed)

-- 8. draw works in every state ------------------------------------------------
mg_draw()
check("done panel has a button", #mg_buttons == 1, #mg_buttons)

-- 9. abort from briefing is silent, abort in flight fails --------------------
mg_onground, mg_gs = 1, 0
mg_generate()
check("brief again", mg_state == MG_BRIEF)
mg_abort()
check("brief abort -> idle, mission cleared", mg_state == MG_IDLE and mg_mission == nil)
mg_generate()
mg_accept()
check("second mission armed", mg_state == MG_ARMED)
mg_abort()
check("flight abort -> done", mg_state == MG_DONE)
check("abort result", mg_result and mg_result.ok == false)

-- 10. emergency injected through the QRH trainer -----------------------------
mg_generate()
mg_accept()
m = mg_mission
m.emergency = true
mg_onground, mg_gs, mg_elev = 0, 90, 3048.0
frame(20)
frame(21)
check("QRH emergency injected", qrh_inject_calls == 1, qrh_inject_calls)
check("mission marked injected", m.injected == true and m.qrh_injected == true)
mg_abort()
check("QRH cleared on abort", qrh_clear_calls == 1, qrh_clear_calls)

-- 11. emergency direct-failure fallback --------------------------------------
local saved_qrh = qrh_inject_by_key
qrh_inject_by_key = nil
mg_onground, mg_gs = 1, 0
mg_generate()
mg_accept()
m = mg_mission
m.emergency = true
mg_onground, mg_gs, mg_elev = 0, 90, 3048.0
frame(40)
frame(41)
check("direct failure fallback set", mg_engfla0 == 6, mg_engfla0)
check("raw failure flagged", m.raw_failure == true)
mg_abort()
check("direct failure cleared", mg_engfla0 == 0, mg_engfla0)
qrh_inject_by_key = saved_qrh

-- 12. story promises become real rules ---------------------------------------
mg_onground, mg_gs = 1, 0
mg_generate_archetype("charter")
local has_td = false
for _, id in ipairs(mg_mission.constraints) do
    if id == "touchdown" then has_td = true end
end
check("charter forces its touchdown rule",
    has_td and mg_mission.touchdown_min == -250, mg_mission.touchdown_min)
mg_abort()

-- 13. flight school lesson ----------------------------------------------------
mg_onground, mg_gs = 1, 0
check("lesson generates a school briefing", mg_generate_archetype("school") == true)
m = mg_mission
check("school briefing has a lesson", m.lesson ~= nil, m.lesson)
check("title names the lesson", m.title:find("FLIGHT SCHOOL") ~= nil, m.title)
print("      lesson: " .. m.title)
mg_accept()
-- force the steep-turn tracker on regardless of the drawn lesson
m.steep_hold_s   = 10
m.steep_hold_acc = 0
m.constraints    = {}
m.cstate         = {}
mg_onground, mg_gs, mg_elev = 0, 90, 3048.0
mg_bank = 40
frame(50)   -- ARMED -> ACTIVE
frame(51)   -- inside 30-45: +1 s
frame(52)   -- inside 30-45: +1 s
mg_bank = 50
frame(53)   -- outside the window: must not count
check("steep turns accumulate inside 30-45",
    math.abs((m.steep_hold_acc or 0) - 2.0) < 0.01, m.steep_hold_acc)
mg_bank = 0
m.steep_hold_s   = 1     -- target met for the grade
m.alt_target_ft  = nil   -- ignore any climb lesson goal
t = 54
for i, leg in ipairs(m.legs) do
    mg_lat, mg_lon = leg.lat, leg.lon
    frame(t); t = t + 1
end
mg_lat, mg_lon = m.home_lat, m.home_lon
mg_onground, mg_gs, mg_vs = 1, 1.0, -100
frame(t)
check("lesson completed", mg_state == MG_DONE, mg_state)
local has_grade, has_clean = false, false
for _, ln in ipairs(mg_result.lines) do
    if ln:find("INSTRUCTOR GRADE  A", 1, true) then has_grade = true end
    if ln:find("CLEAN CHECKRIDE", 1, true) then has_clean = true end
end
check("instructor grade A", has_grade)
check("checkride bonus paid", has_clean)

-- 14. persistence -------------------------------------------------------------
local fd = io.open(SCRIPT_DIRECTORY .. "CitationX_MissionProgress.txt", "r")
check("progress file written", fd ~= nil)
if fd then
    local body = fd:read("a")
    fd:close()
    print("      progress file:\n" .. body)
    check("progress has best", body:find("best=%d+") ~= nil)
end

print("\nALL SMOKE TESTS PASSED")
