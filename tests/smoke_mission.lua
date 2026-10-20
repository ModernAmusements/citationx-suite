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
    ["sim/time/sim_speed"]                           = 1,
    ["sim/flightmodel/position/magnetic_variation"]  = 0.0,
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

-- XPLMNavigation mocks: every query returns a unique airport 0.005 deg away,
-- so the generator sees real ICAO-style targets instead of synthetic fixes.
xplm_Nav_Airport = 1
local nav_refs, nav_next = {}, 0
function XPLMFindNavAid(name, id, lat, lon, freq, atype)
    assert(atype == xplm_Nav_Airport, "unexpected nav aid type")
    nav_next = nav_next + 1
    nav_refs[nav_next] = {
        lat = (lat or 0.0) + 0.005,
        lon = (lon or 0.0) + 0.005,
        icao = string.format("T%03d", nav_next),
    }
    return nav_next
end
function XPLMGetNavAidInfo(ref)
    local a = nav_refs[ref]
    if not a then return -1 end
    return xplm_Nav_Airport, a.lat, a.lon, 300.0, 0, 0, a.icao,
        "TEST AIRPORT " .. a.icao
end

-- FMS mocks for the optional MissionGen/load_fms path.
local fms_entries = {}
function XPLMClearFMSEntry(i) fms_entries[i] = nil end
function XPLMSetFMSEntryLatLon(i, lat, lon, alt)
    fms_entries[i] = { lat = lat, lon = lon, alt = alt }
end

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
check("datarefs registered", #registered_datarefs >= 15, #registered_datarefs)
mg_onground, mg_gs = 1, 0
check("generate on ground", mg_generate() == true)
check("state is BRIEF", mg_state == MG_BRIEF, mg_state)
local m = mg_mission
check("mission has story", m and type(m.story) == "table" and #m.story > 0)
check("mission has legs", type(m.legs) == "table" and #m.legs >= 2, m.legs and #m.legs)
check("last leg is home", m.legs[#m.legs].home == true, m.legs[#m.legs].name)
check("departure airport identified",
    type(m.home_icao) == "string" and #m.home_icao > 0, m.home_icao)
check("legs snapped to real airports", (function()
    for i = 1, #m.legs - 1 do
        if not m.legs[i].apt or not m.legs[i].name:match("^T") then
            return false
        end
    end
    return true
end)())
check("magnetic bearings computed", (function()
    for _, leg in ipairs(m.legs) do
        if type(leg.brg_mag) ~= "number" then return false end
    end
    return true
end)())
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
check("briefing has accept + FMS + skip", #mg_buttons == 3, #mg_buttons)
check("FMS plan loads", mg_load_fms() == true)
local fms_n = 0
for i = 0, 20 do if fms_entries[i] then fms_n = fms_n + 1 end end
check("FMS has every leg", fms_n == #m.legs, fms_n)
print("      mission: " .. m.title .. "  [difficulty " .. m.difficulty .. "]")
print("      departure: " .. tostring(m.home_icao) .. " " .. tostring(m.home_name))
for _, ln in ipairs(m.story) do print("      | " .. ln) end
print("      plan:")
for i, leg in ipairs(m.legs) do
    print(string.format("        %d  %-5s %03.0f mag / %.0f NM  %s",
        i, leg.name, leg.brg_mag or leg.brg, leg.dist_nm, leg.place or ""))
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
check("armed panel has warp + abort", #mg_buttons == 2, #mg_buttons)

-- 4. takeoff starts the clock -------------------------------------------------
mg_onground, mg_gs = 0, 90
frame(1)
check("state is ACTIVE after wheels up", mg_state == MG_ACTIVE, mg_state)

-- 4b. cruise time warp ---------------------------------------------------------
mg_elev, mg_agl, mg_bank = 3048.0, 3048.0, 0.0
frame(2)
check("auto warp engages in cruise", mg_sim_speed == MG_CONFIG.warp_cruise,
    mg_sim_speed)
mg_warp_cycle()
check("manual warp cycles to 8x", mg_sim_speed == 8 and mg_warp_manual,
    mg_sim_speed)
mg_warp_cycle()
check("manual warp cycles back to 1x", mg_sim_speed == 1, mg_sim_speed)
mg_warp_cycle()
check("manual warp cycles to 2x", mg_sim_speed == 2 and mg_warp_manual,
    mg_sim_speed)
mg_warp_auto()
check("auto mode re-enabled", mg_warp_manual == false)
frame(3)
check("auto warp re-engages", mg_sim_speed == MG_CONFIG.warp_cruise,
    mg_sim_speed)
mg_lat, mg_lon = m.legs[1].lat + 0.08, m.legs[1].lon
frame(4)
check("auto warp drops near the fix", mg_sim_speed == 1, mg_sim_speed)
mg_lat, mg_lon = m.home_lat, m.home_lon

-- 5. fly the plan, leg by leg -------------------------------------------------
mg_elev, mg_agl = 3048.0, 3048.0
mg_mach, mg_ias, mg_bank, mg_gload = 0.80, 240, 5, 1.0
local t = 5
for i, leg in ipairs(m.legs) do
    mg_lat, mg_lon = leg.lat, leg.lon
    frame(t)
    t = t + 1
    check("leg " .. i .. " done (" .. leg.name .. ")",
        m.legs_done == i, m.legs_done)
end
check("clock running", mg_clock > 0.9, mg_clock)
mg_draw()   -- ACTIVE panel must render
check("active panel has warp + abort", #mg_buttons == 2, #mg_buttons)

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
check("warp reset after mission", mg_sim_speed == 1, mg_sim_speed)

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

-- 14. graceful fallback without XPLMNavigation --------------------------------
local saved_find, saved_info = XPLMFindNavAid, XPLMGetNavAidInfo
XPLMFindNavAid, XPLMGetNavAidInfo = nil, nil
mg_onground, mg_gs = 1, 0
check("generate without navdata", mg_generate() == true)
m = mg_mission
check("fallback has no airport id", m.home_icao == nil, m.home_icao)
check("fallback ends at HOME", m.legs[#m.legs].name == "HOME",
    m.legs[#m.legs].name)
check("fallback legs are synthetic", (function()
    for i = 1, #m.legs - 1 do
        if m.legs[i].apt then return false end
    end
    return true
end)())
mg_abort()
XPLMFindNavAid, XPLMGetNavAidInfo = saved_find, saved_info

-- 15. persistence -------------------------------------------------------------
local fd = io.open(SCRIPT_DIRECTORY .. "CitationX_MissionProgress.txt", "r")
check("progress file written", fd ~= nil)
if fd then
    local body = fd:read("a")
    fd:close()
    print("      progress file:\n" .. body)
    check("progress has best", body:find("best=%d+") ~= nil)
end

print("\nALL SMOKE TESTS PASSED")
