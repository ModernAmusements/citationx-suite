-- Mock-FlyWithLua smoke test for CitationX_MissionGenerator.lua
-- Exercises generation, takeoff, fix, landing, scoring, rules, abort and the
-- emergency injection/clear path without X-Plane.

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

-- 1. generate on the ground -------------------------------------------------
check("datarefs registered", #registered_datarefs >= 13, #registered_datarefs)
mg_onground, mg_gs = 1, 0
check("generate on ground", mg_generate() == true)
check("state is ARMED", mg_state == 1, mg_state)
local m = mg_mission
check("mission has fix + budget", m and m.fix_lat and m.budget_s > 0)
check("title built", m.title:find(" - ") ~= nil, m.title)
mg_draw()   -- ARMED panel must render
check("armed panel has a button", #mg_buttons == 1, #mg_buttons)
print("      mission: " .. m.title .. "  [difficulty " .. m.difficulty .. "]")
print("      fix brg " .. m.brg_deg .. " / " .. m.leg_nm .. " NM, budget " .. m.budget_s .. " s")

-- 2. takeoff starts the clock ----------------------------------------------
mg_onground, mg_gs = 0, 90
frame(1)
check("state is ACTIVE after wheels up", mg_state == 2, mg_state)

-- 3. fly to the fix ---------------------------------------------------------
mg_lat, mg_lon = m.fix_lat, m.fix_lon
mg_elev, mg_agl = 3048.0, 3048.0
mg_mach, mg_ias, mg_bank, mg_gload = 0.80, 240, 5, 1.0
frame(2)
check("fix reached", m.reached_fix == true)
check("clock running", mg_clock > 0.9, mg_clock)
mg_draw()   -- ACTIVE panel must render
check("active panel has a button", #mg_buttons == 1, #mg_buttons)

-- 4. rule engine: edge-triggered violations --------------------------------
m.constraints = { "ias250" }
m.cstate = { ias250 = { viol = 0, was_bad = false, done = false } }
mg_ias, mg_agl = 300, 1000.0   -- 300 KT below 10k = violation
frame(3)
frame(4)
check("rule counts one episode", m.cstate.ias250.viol == 1, m.cstate.ias250.viol)
mg_ias = 200
frame(5)
mg_ias = 300
frame(6)
check("rule counts second episode", m.cstate.ias250.viol == 2, m.cstate.ias250.viol)

-- 5. return home and stop ---------------------------------------------------
mg_lat, mg_lon = m.home_lat, m.home_lon
mg_onground, mg_gs, mg_vs = 1, 1.0, -120
frame(7)
check("mission completed", mg_state == 3, mg_state)
check("result is pass", mg_result and mg_result.ok == true)
check("score positive", mg_result.score > 0, mg_result.score)
print("      score: " .. mg_result.score)
for _, ln in ipairs(mg_result.lines) do print("      | " .. ln) end
check("streak incremented", mg_streak == 1, mg_streak)
check("best updated", mg_best == mg_result.score, mg_best)
check("flown counter", mg_completed == 1, mg_completed)

-- 6. draw works in every state ---------------------------------------------
mg_draw()
check("done panel has a button", #mg_buttons == 1, #mg_buttons)

-- 7. abort path -------------------------------------------------------------
mg_onground, mg_gs = 1, 0
mg_generate()
check("second mission armed", mg_state == 1)
mg_abort()
check("abort -> done", mg_state == 3)
check("abort result", mg_result and mg_result.ok == false)

-- 8. emergency injected through the QRH trainer ----------------------------
mg_generate()
m = mg_mission
m.emergency = true
mg_onground, mg_gs, mg_elev = 0, 90, 3048.0
mg_simtime = 20
mg_frame()   -- ARMED -> ACTIVE
mg_simtime = 21
mg_frame()   -- now the emergency logic runs
check("QRH emergency injected", qrh_inject_calls == 1, qrh_inject_calls)
check("mission marked injected", m.injected == true and m.qrh_injected == true)
mg_abort()
check("QRH cleared on abort", qrh_clear_calls == 1, qrh_clear_calls)

-- 9. emergency direct-failure fallback -------------------------------------
local saved_qrh = qrh_inject_by_key
qrh_inject_by_key = nil
mg_onground, mg_gs = 1, 0
mg_generate()
m = mg_mission
m.emergency = true
mg_onground, mg_gs, mg_elev = 0, 90, 3048.0
mg_simtime = 40
mg_frame()   -- ARMED -> ACTIVE
mg_simtime = 41
mg_frame()   -- now the emergency logic runs
check("direct failure fallback set", mg_engfla0 == 6, mg_engfla0)
check("raw failure flagged", m.raw_failure == true)
mg_abort()
check("direct failure cleared", mg_engfla0 == 0, mg_engfla0)
qrh_inject_by_key = saved_qrh

-- 10. persistence -----------------------------------------------------------
local fd = io.open(SCRIPT_DIRECTORY .. "CitationX_MissionProgress.txt", "r")
check("progress file written", fd ~= nil)
if fd then
    local body = fd:read("a")
    fd:close()
    print("      progress file:\n" .. body)
    check("progress has best", body:find("best=%d+") ~= nil)
end

print("\nALL SMOKE TESTS PASSED")
