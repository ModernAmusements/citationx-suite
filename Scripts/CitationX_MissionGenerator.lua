-- ============================================================================
--  CESSNA CITATION X MISSION GENERATOR
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  Randomly generated challenge sorties that turn a free flight into a scored
--  mission. Everything is measured from the sim's own datarefs, so it works
--  anywhere in the world, from any airport and in any aircraft (the Citation
--  X simply gets the nicest numbers).
--
--    * missions start on the ground - park up, then GENERATE
--    * the clock starts the moment the wheels leave the runway:
--        1. fly out to a randomly placed fix point (bearing + distance)
--        2. come back and land to a full stop within 3 NM of home
--    * every mission adds one special objective:
--        ALTITUDE RUN    climb to a random flight level before the fix
--        FAST LANE       hold a mach number for a set time
--        FUEL DISCIPLINE finish inside a tight fuel budget
--        EMERGENCY       engine flameout in flight (uses the QRH trainer if
--                        it is installed, otherwise fires the failure
--                        directly) - survive and land
--    * every mission also draws 2-4 hard rules, each violation scores minus:
--        SPEED <= 250 KT below 10,000 FT        MACH <= 0.87
--        BANK <= 35 DEG                         G-LOAD -0.3 .. +2.5
--        TOUCHDOWN >= -300 FPM                  RESERVE FUEL ON LANDING
--    * four difficulties (EASY / NORMAL / HARD / BRUTAL) scale distance,
--      clock and score
--    * best score, current streak and missions flown persist to disk
--
--  Commands (bindable in Settings > Keyboard / Joystick):
--    MissionGen/generate      MissionGen/abort
--    MissionGen/toggle_panel  MissionGen/report
-- ============================================================================

MG_CONFIG = {
    panel_enabled      = true,
    panel_w            = 560,
    panel_bottom       = 60,      -- panel sits bottom-center
    row_h              = 16,

    cruise_tas_kt      = 300,     -- used for the clock budget math
    max_start_gs_kt    = 25,      -- generate only when this slow on the ground
    fix_radius_nm      = 2.0,     -- this close counts as "fix reached"
    home_radius_nm     = 3.0,     -- land this close to home to complete
    ground_quiet_kt    = 6,       -- "full stop" threshold
    reserve_kg         = 350,     -- reserve fuel the RESERVE rule checks

    qrh_bridge         = true,    -- use the QRH Failure Trainer when present
    persist            = true,    -- save best / streak / count to disk
}

MG_STYLE = {
    bg        = {0.02, 0.05, 0.08, 0.62},
    header_bg = {0.03, 0.15, 0.21, 0.90},
    accent    = {0.22, 0.85, 1.00},
    subhdr    = {0.36, 0.68, 0.78},
    label     = {0.42, 0.62, 0.70},
    value     = {0.93, 0.97, 1.00},
    ok        = {0.32, 0.95, 0.55},
    warn      = {1.00, 0.66, 0.12},
    alert     = {1.00, 0.30, 0.28},
    dim       = {0.30, 0.37, 0.42},
    gold      = {1.00, 0.80, 0.25},
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("mg_lat",      "sim/flightmodel/position/latitude", "readonly")
dataref("mg_lon",      "sim/flightmodel/position/longitude", "readonly")
dataref("mg_elev",     "sim/flightmodel/position/elevation", "readonly")
dataref("mg_agl",      "sim/flightmodel/position/y_agl", "readonly")
dataref("mg_vs",       "sim/flightmodel/position/vh_ind_fpm", "readonly")
dataref("mg_gs",       "sim/flightmodel/position/groundspeed", "readonly")
dataref("mg_ias",      "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("mg_bank",     "sim/flightmodel/position/phi", "readonly")
dataref("mg_mach",     "sim/flightmodel/misc/machno", "readonly")
dataref("mg_gload",    "sim/flightmodel2/misc/gforce_normal", "readonly")
dataref("mg_onground", "sim/flightmodel/failures/onground_any", "readonly")
dataref("mg_fuel_kg",  "sim/flightmodel/weight/m_fuel_total", "readonly")
dataref("mg_simtime",  "sim/time/total_running_time_sec", "readonly")
dataref("mg_paused",   "sim/time/paused", "readonly")

-- Written only by the EMERGENCY objective (when the QRH trainer is absent).
-- The Failure Trainer already owns this DataRef whenever it is loaded, and
-- FlyWithLua quarantines a script that opens a second *writable* handle to the
-- same ref. Reuse the trainer's variable in that case; only bind our own when
-- the trainer is not installed.
local mg_engfla_own = false
if type(ft_fail_engfla0) ~= "number" then
    dataref("mg_engfla0", "sim/operation/failures/rel_engfla0", "writable")
    mg_engfla_own = true
end

local function mg_set_engfla(value)
    if mg_engfla_own then
        mg_engfla0 = value
    else
        ft_fail_engfla0 = value
    end
end

-- ---------------------------------------------------------------- CONSTS ----
local MG_IDLE, MG_ARMED, MG_ACTIVE, MG_DONE = 0, 1, 2, 3

local MG_DIFF_NAMES  = { "EASY", "NORMAL", "HARD", "BRUTAL" }
local MG_DIFF_BASE   = { 300, 600, 900, 1200 }
local MG_DIFF_TIME   = { 1.20, 1.05, 0.95, 0.88 }   -- clock factor
local MG_DIFF_DIST   = { {25, 45}, {35, 70}, {50, 95}, {65, 120} }
local MG_DIFF_RULES  = { 2, 3, 4, 4 }

local MG_KIND_TITLE = {
    turnaround = "TURNAROUND",
    profile    = "ALTITUDE RUN",
    speed      = "FAST LANE",
    fuel       = "FUEL DISCIPLINE",
    emergency  = "EMERGENCY SORTIE",
}
local MG_KIND_POOL = {
    "turnaround", "turnaround", "turnaround", "profile", "profile",
    "speed", "speed", "fuel", "fuel", "emergency",
}

local MG_CALLSIGNS = {
    "SILVER ARROW", "NIGHT HAWK", "IRON EAGLE", "BLUE STREAK",
    "GHOST RIDER", "DESERT FOX", "STORM CELL", "THUNDERBIRD",
    "ACES HIGH", "VIPER ONE", "PHOENIX", "BLACK CAT",
    "WHITE KNIGHT", "RAVEN", "COPPERHEAD", "SKYHAWK",
}

-- Rules a mission can draw. `check` runs every frame (live "violating"
-- state); rising edges are counted as violations. touchdown / reserve are
-- event-driven and evaluated by the landing / finish logic instead.
local MG_CONSTRAINTS = {
    ias250   = { label = "SPEED <= 250 KT BELOW 10K",  penalty = 40,
        check = function()
            return (mg_onground or 0) == 0
               and (mg_agl or 0) * 3.28084 < 10000
               and (mg_ias or 0) > 250
        end },
    bank     = { label = "BANK LIMIT 35 DEG",          penalty = 25,
        check = function()
            return (mg_onground or 0) == 0 and math.abs(mg_bank or 0) > 35
        end },
    gload    = { label = "G-LOAD -0.3 .. +2.5",        penalty = 25,
        check = function()
            return (mg_onground or 0) == 0
               and ((mg_gload or 1) > 2.5 or (mg_gload or 1) < -0.3)
        end },
    machlim  = { label = "MACH <= 0.87",               penalty = 40,
        check = function()
            return (mg_onground or 0) == 0 and (mg_mach or 0) > 0.87
        end },
    touchdown = { label = "TOUCHDOWN >= -300 FPM",     penalty = 150 },
    reserve   = { label = "LAND WITH RESERVE FUEL",    penalty = 250 },
}
local MG_CONSTRAINT_POOL = {
    "ias250", "bank", "gload", "machlim", "touchdown", "reserve",
}

-- ----------------------------------------------------------------- STATE ----
mg_state      = MG_IDLE
mg_mission    = nil
mg_result     = nil
mg_clock      = 0
mg_last_t     = 0
mg_streak     = 0
mg_best       = 0
mg_completed  = 0
mg_buttons    = {}
mg_toast_text = nil
mg_toast_until = 0

-- --------------------------------------------------------------- HELPERS ---
local function mg_rad(d) return d * math.pi / 180.0 end

local function mg_atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    return math.atan(y, x)
end

-- Great-circle distance in nautical miles.
local function mg_dist_nm(lat1, lon1, lat2, lon2)
    if not lat1 or not lon1 or not lat2 or not lon2 then return 0.0 end
    local R = 3440.065
    local dlat = mg_rad(lat2 - lat1)
    local dlon = mg_rad(lon2 - lon1)
    local a = math.sin(dlat / 2) ^ 2
            + math.cos(mg_rad(lat1)) * math.cos(mg_rad(lat2))
            * math.sin(dlon / 2) ^ 2
    return 2.0 * R * math.asin(math.min(1.0, math.sqrt(a)))
end

-- Point at `dist_nm` from (lat, lon) along the true bearing `brg`.
local function mg_dest(lat, lon, brg, dist_nm)
    local R  = 3440.065
    local dr = dist_nm / R
    local b  = mg_rad(brg)
    local p1 = mg_rad(lat)
    local l1 = mg_rad(lon)
    local p2 = math.asin(math.sin(p1) * math.cos(dr)
             + math.cos(p1) * math.sin(dr) * math.cos(b))
    local l2 = l1 + mg_atan2(math.sin(b) * math.sin(dr) * math.cos(p1),
                             math.cos(dr) - math.sin(p1) * math.sin(p2))
    return p2 * 180.0 / math.pi, l2 * 180.0 / math.pi
end

local function mg_fmt_time(sec)
    sec = math.max(0, math.floor(sec or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function mg_kt_to_ms(kt) return kt * 0.514444 end

local function mg_mark(done)
    if done then return "[X] " end
    return "[ ] "
end

local function mg_toast(text)
    mg_toast_text  = text
    mg_toast_until = (mg_simtime or 0) + 3.0
end

local function mg_shuffle_pick(list, n)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    for i = #copy, 2, -1 do
        local j = math.random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    local out = {}
    for i = 1, math.min(n, #copy) do out[i] = copy[i] end
    return out
end

-- ------------------------------------------------------------ PROGRESS -----
local function mg_progress_path()
    if SCRIPT_DIRECTORY and SCRIPT_DIRECTORY ~= "" then
        return SCRIPT_DIRECTORY .. "CitationX_MissionProgress.txt"
    end
    return "CitationX_MissionProgress.txt"
end

local function mg_load_progress()
    mg_streak, mg_best, mg_completed = 0, 0, 0
    local fd = io.open(mg_progress_path(), "r")
    if not fd then return end
    for line in fd:lines() do
        local k, v = line:match("^(%w+)=(%d+)$")
        if k == "best" then mg_best = tonumber(v) or 0
        elseif k == "streak" then mg_streak = tonumber(v) or 0
        elseif k == "completed" then mg_completed = tonumber(v) or 0
        end
    end
    fd:close()
end

local function mg_save_progress()
    if not MG_CONFIG.persist then return end
    local fd = io.open(mg_progress_path(), "w")
    if not fd then return end
    fd:write(string.format("best=%d\nstreak=%d\ncompleted=%d\n",
        mg_best, mg_streak, mg_completed))
    fd:close()
end

-- ------------------------------------------------------------ EMERGENCY ----
local function mg_inject_emergency(m)
    m.injected = true
    local via_qrh = false
    if MG_CONFIG.qrh_bridge and PLANE_ICAO == "C750"
        and type(qrh_inject_by_key) == "function" then
        via_qrh = pcall(qrh_inject_by_key, "flameout_l")
    end
    if not via_qrh then
        mg_set_engfla(6)
        m.raw_failure = true
    end
    m.qrh_injected = via_qrh
    mg_toast("L ENGINE FLAMEOUT - QRH!")
    logMsg("Mission Gen: emergency injected (QRH trainer: "
        .. tostring(via_qrh) .. ")")
end

local function mg_clear_emergency(m)
    if not m or not m.injected then return end
    if m.raw_failure then mg_set_engfla(0) end
    if m.qrh_injected and type(qrh_clear) == "function" then
        pcall(qrh_clear)
    end
    m.injected = false
    logMsg("Mission Gen: emergency cleared")
end

-- ------------------------------------------------------------- GENERATE ----
local function mg_build_mission()
    local roll = math.random(1, 10)
    local diff = roll <= 2 and 1 or (roll <= 5 and 2 or (roll <= 8 and 3 or 4))

    local dist_min = MG_DIFF_DIST[diff][1]
    local dist_max = MG_DIFF_DIST[diff][2]
    local leg_nm   = math.random(dist_min, dist_max)
    local brg      = math.random(0, 359)

    local kind = MG_KIND_POOL[math.random(#MG_KIND_POOL)]

    local budget = math.floor((leg_nm * 2 / MG_CONFIG.cruise_tas_kt)
        * 3600 * MG_DIFF_TIME[diff]) + 360

    local cids   = mg_shuffle_pick(MG_CONSTRAINT_POOL, MG_DIFF_RULES[diff])
    local cstate = {}
    for _, id in ipairs(cids) do
        cstate[id] = { viol = 0, was_bad = false, done = false }
    end

    local home_lat = mg_lat or 0.0
    local home_lon = mg_lon or 0.0
    local fix_lat, fix_lon = mg_dest(home_lat, home_lon, brg, leg_nm)

    local m = {
        callsign    = MG_CALLSIGNS[math.random(#MG_CALLSIGNS)],
        kind        = kind,
        difficulty  = diff,
        leg_nm      = leg_nm,
        brg_deg     = brg,
        home_lat    = home_lat,
        home_lon    = home_lon,
        fix_lat     = fix_lat,
        fix_lon     = fix_lon,
        budget_s    = budget,
        constraints = cids,
        cstate      = cstate,
        plane       = PLANE_ICAO,
        fuel_start_kg = mg_fuel_kg or 0.0,
        reached_fix = false,
        landed      = false,
        wheels_up   = false,
        injected    = false,
        mach_hold_acc = 0,
    }
    m.title = m.callsign .. " - " .. MG_KIND_TITLE[kind] .. " " .. leg_nm .. " NM"

    if kind == "profile" then
        local fl_min = ({180, 220, 260, 300})[diff]
        local fl_max = ({240, 280, 320, 360})[diff]
        m.alt_target_ft = math.random(math.floor(fl_min / 10),
                                      math.floor(fl_max / 10)) * 1000
    elseif kind == "speed" then
        m.mach_target = ({0.68, 0.72, 0.76, 0.79})[diff]
                      + math.random(0, 2) * 0.01
        m.mach_hold_s = 60 * diff + 30
    elseif kind == "fuel" then
        local air_s = (leg_nm * 2 / MG_CONFIG.cruise_tas_kt) * 3600
        m.fuel_budget_kg = math.floor(air_s * 0.65
            * ({1.05, 1.00, 0.96, 0.93})[diff] + 300)
    elseif kind == "emergency" then
        m.emergency = true
    end

    return m
end

function mg_generate()
    if (mg_onground or 0) ~= 1
        or (mg_gs or 0) > mg_kt_to_ms(MG_CONFIG.max_start_gs_kt) then
        mg_toast("LAND & SLOW DOWN FIRST - MISSIONS START ON THE GROUND")
        return false
    end
    if mg_state == MG_ARMED or mg_state == MG_ACTIVE then
        mg_abort()
    end

    mg_mission = mg_build_mission()
    mg_result  = nil
    mg_clock   = 0
    mg_state   = MG_ARMED

    local m = mg_mission
    logMsg(string.format(
        "Mission Gen: generated '%s' [%s] %.0f NM, brg %03.0f, budget %s",
        m.title, MG_DIFF_NAMES[m.difficulty], m.leg_nm, m.brg_deg,
        mg_fmt_time(m.budget_s)))
    mg_toast("MISSION: " .. m.title)
    return true
end

function mg_abort()
    if not mg_mission then
        mg_toast("NO ACTIVE MISSION")
        return
    end
    local m = mg_mission
    mg_clear_emergency(m)
    mg_result = {
        ok    = false,
        score = 0,
        title = m.title,
        lines = { "ABORTED BY PILOT - NO SCORE" },
    }
    logMsg("Mission Gen: aborted " .. m.title)
    mg_mission = nil
    mg_state   = MG_DONE
    mg_toast("MISSION ABORTED")
end

-- --------------------------------------------------------------- FINISH ----
local function mg_finish(success, reason)
    local m = mg_mission
    if not m then return end

    local lines = {}
    local score = 0

    if success then
        score = MG_DIFF_BASE[m.difficulty]
        lines[#lines + 1] = string.format("BASE SCORE  +%d", score)

        local left = math.max(0, m.budget_s - mg_clock)
        local time_bonus = math.floor(left / 60) * 10
        score = score + time_bonus
        lines[#lines + 1] = string.format("TIME BONUS  +%d  (%s left)",
            time_bonus, mg_fmt_time(left))

        if m.alt_target_ft then
            if (m.alt_at_fix or 0) >= m.alt_target_ft - 200 then
                score = score + 150
                lines[#lines + 1] = "PROFILE FLOWN  +150"
            else
                lines[#lines + 1] = "PROFILE MISSED  (no bonus)"
            end
        end
        if m.mach_target and (m.mach_hold_acc or 0) >= m.mach_hold_s then
            score = score + 150
            lines[#lines + 1] = "MACH HOLD COMPLETE  +150"
        end
        if m.fuel_budget_kg then
            local used = (m.fuel_start_kg or 0) - (mg_fuel_kg or 0)
            m.fuel_used_kg = used
            if used <= m.fuel_budget_kg then
                score = score + 150
                lines[#lines + 1] = string.format(
                    "FUEL BUDGET KEPT  +150  (%.0f KG)", used)
            else
                lines[#lines + 1] = string.format(
                    "OVER FUEL BUDGET  %.0f / %.0f KG", used, m.fuel_budget_kg)
            end
        end
        if m.emergency and m.injected then
            score = score + 250
            lines[#lines + 1] = "EMERGENCY HANDLED  +250"
        end

        -- reserve rule is evaluated at the moment of completion
        local rst = m.cstate.reserve
        if rst and not rst.done then
            rst.done  = true
            rst.value = mg_fuel_kg or 0
            if rst.value < MG_CONFIG.reserve_kg then
                rst.viol = 1
                lines[#lines + 1] = string.format(
                    "RESERVE BUSTED  (%.0f KG LEFT)", rst.value)
            end
        end

        local penalty_total = 0
        for _, id in ipairs(m.constraints) do
            local def = MG_CONSTRAINTS[id]
            local st  = m.cstate[id]
            if st and st.viol > 0 then
                local p = st.viol * def.penalty
                penalty_total = penalty_total + p
                if id == "touchdown" and st.value then
                    lines[#lines + 1] = string.format(
                        "HARD LANDING  %.0f FPM  -%d", st.value, p)
                else
                    lines[#lines + 1] = string.format("%s x%d  -%d",
                        def.label, st.viol, p)
                end
            end
        end
        score = math.max(0, score - penalty_total)

        mg_streak    = mg_streak + 1
        mg_completed = mg_completed + 1
        if score > mg_best then
            mg_best = score
            lines[#lines + 1] = "NEW BEST SCORE!"
        end
    else
        mg_streak = 0
        lines[#lines + 1] = reason or "MISSION FAILED"
    end

    mg_save_progress()
    mg_clear_emergency(m)

    mg_result = {
        ok    = success,
        score = score,
        title = m.title,
        lines = lines,
    }
    logMsg(string.format("Mission Gen: %s '%s' score %d (streak %d, best %d)",
        success and "completed" or "failed", m.title, score,
        mg_streak, mg_best))

    mg_mission = nil
    mg_state   = MG_DONE
    mg_toast(success
        and string.format("MISSION COMPLETE  %d PTS", score)
        or  "MISSION FAILED")
end

-- ------------------------------------------------------------ FRAME LOOP ----
function mg_frame()
    local now = mg_simtime or 0
    local dt  = now - mg_last_t
    mg_last_t = now
    if dt < 0 or dt > 2 then dt = 0 end
    if (mg_paused or 0) == 1 then dt = 0 end

    local m = mg_mission
    if not m then return end

    -- distance readout is live in both ARMED and ACTIVE
    local lat = mg_lat or m.home_lat
    local lon = mg_lon or m.home_lon
    m.dist_fix  = mg_dist_nm(lat, lon, m.fix_lat, m.fix_lon)
    m.dist_home = mg_dist_nm(lat, lon, m.home_lat, m.home_lon)

    if mg_state == MG_ARMED then
        if (mg_onground or 0) == 0 then
            mg_state    = MG_ACTIVE
            m.wheels_up = true
            mg_clock    = 0
            mg_toast("CLOCK STARTED - GO GET THE FIX")
            logMsg("Mission Gen: wheels up, mission clock started")
        end
        return
    end

    if mg_state ~= MG_ACTIVE then return end

    if PLANE_ICAO ~= m.plane then
        mg_finish(false, "AIRCRAFT CHANGED - MISSION SCRAPPED")
        return
    end

    mg_clock = mg_clock + dt
    local alt_ft = (mg_elev or 0) * 3.28084

    -- fix point
    if not m.reached_fix and (m.dist_fix or 99) <= MG_CONFIG.fix_radius_nm then
        m.reached_fix = true
        m.alt_at_fix  = alt_ft
        mg_toast("FIX POINT REACHED - TURN HOME")
        logMsg(string.format(
            "Mission Gen: fix reached at %.0f ft after %s",
            alt_ft, mg_fmt_time(mg_clock)))
    end

    -- special objectives
    if m.mach_target and (mg_mach or 0) >= m.mach_target then
        m.mach_hold_acc = (m.mach_hold_acc or 0) + dt
    end
    if m.emergency and not m.injected
        and (alt_ft >= 8000 or mg_clock >= 240) then
        mg_inject_emergency(m)
    end

    -- rules with a live check
    for _, id in ipairs(m.constraints) do
        local def = MG_CONSTRAINTS[id]
        local st  = m.cstate[id]
        if def.check and st and not st.done then
            local bad = def.check()
            if bad and not st.was_bad then
                st.viol = st.viol + 1
                logMsg(string.format("Mission Gen: rule broken - %s", def.label))
            end
            st.was_bad = bad
        end
    end

    -- landing event (first touchdown is what counts)
    local ong = (mg_onground or 0) == 1
    if ong and not m.was_onground and m.wheels_up then
        m.landed = true
        m.touchdown_fpm = mg_vs or 0
        local st = m.cstate.touchdown
        if st and not st.done then
            st.done  = true
            st.value = m.touchdown_fpm
            if m.touchdown_fpm < -300 then
                st.viol = 1
                mg_toast(string.format("HARD LANDING  %.0f FPM",
                    m.touchdown_fpm))
            end
        end
        logMsg(string.format("Mission Gen: touchdown %.0f fpm",
            m.touchdown_fpm))
    end
    m.was_onground = ong

    -- completion: back home, on the ground, stopped
    if m.landed
        and (m.dist_home or 99) <= MG_CONFIG.home_radius_nm
        and (mg_gs or 99) <= mg_kt_to_ms(MG_CONFIG.ground_quiet_kt) then
        mg_finish(true)
        return
    end

    -- clock
    if mg_clock > m.budget_s then
        mg_finish(false, "MISSION CLOCK EXPIRED")
        return
    end
end

-- ------------------------------------------------------------- DRAWING -----
local function mg_bar(x, y0, y1, w, color, alpha)
    glColor4f(color[1], color[2], color[3], alpha or 1.0)
    glRectf(x, y0, x + w, y1)
end

local function mg_txt(x, y, text, color)
    draw_string(x, y, text, color[1], color[2], color[3])
end

local function mg_txt_right(right_x, y, text, color)
    draw_string(right_x - measure_string(text), y, text, color[1], color[2], color[3])
end

function mg_draw()
    if not MG_CONFIG.panel_enabled then return end
    mg_buttons = {}

    local st = MG_STYLE
    local w  = MG_CONFIG.panel_w
    local sw = SCREEN_WIDTH or 1920
    local x  = math.floor((sw - w) / 2)
    local rh = MG_CONFIG.row_h
    local bottom_anchor = MG_CONFIG.panel_bottom

    local rows = {}
    local function row(l, r, col, rcol)
        rows[#rows + 1] = { l = l, r = r, col = col or st.value,
                            rcol = rcol or col or st.value }
    end
    local function spacer()
        rows[#rows + 1] = { blank = true }
    end
    local function button(key, label, color)
        rows[#rows + 1] = { btn = label, key = key, col = color or st.ok }
    end

    local head_state, head_col
    if mg_state == MG_ACTIVE then
        head_state, head_col = "FLYING", st.ok
    elseif mg_state == MG_ARMED then
        head_state, head_col = "ARMED", st.warn
    elseif mg_state == MG_DONE then
        if mg_result and mg_result.ok then
            head_state, head_col = "PASSED", st.ok
        else
            head_state, head_col = "FAILED", st.alert
        end
    else
        head_state, head_col = "READY", st.subhdr
    end

    if mg_state == MG_IDLE then
        row("NO ACTIVE MISSION", "", st.value)
        row("MISSIONS START ON THE GROUND - PARK UP AND GENERATE", "", st.label)
        if mg_result then
            row(string.format("LAST: %s", mg_result.title),
                mg_result.ok and "PASS" or "FAIL",
                mg_result.ok and st.ok or st.alert)
        else
            row("OUT-AND-BACK SORTIES WITH A CLOCK AND HARD RULES", "", st.label)
        end
        row(string.format("STREAK %d   BEST %d   FLOWN %d",
            mg_streak, mg_best, mg_completed), "", st.gold)
        spacer()
        button("gen", "GENERATE MISSION  (click)")

    elseif mg_state == MG_ARMED or mg_state == MG_ACTIVE then
        local m = mg_mission
        row(m.title, MG_DIFF_NAMES[m.difficulty], st.warn)

        if mg_state == MG_ARMED then
            row("ON THE GROUND - CLOCK STARTS AT WHEELS UP", "", st.label)
        else
            local left = m.budget_s - mg_clock
            row(string.format("CLOCK %s    LEFT %s",
                    mg_fmt_time(mg_clock), mg_fmt_time(math.max(0, left))),
                "", left < 120 and st.alert or st.value)
        end

        row(string.format("FIX %03.0f DEG / %.0f NM    OUT %5.1f    HOME %5.1f",
                m.brg_deg, m.leg_nm, m.dist_fix or 0.0, m.dist_home or 0.0),
            "", st.subhdr)

        -- objectives
        local reached = m.reached_fix
        row(mg_mark(reached) .. "REACH FIX POINT",
            reached and "DONE" or "PENDING", reached and st.ok or st.value)
        local homed = m.landed
            and (m.dist_home or 99) <= MG_CONFIG.home_radius_nm
        row(mg_mark(homed) .. "RETURN HOME + FULL STOP",
            homed and "DONE" or string.format("%.1f NM", m.dist_home or 0.0),
            homed and st.ok or st.value)

        if m.alt_target_ft then
            local done = m.alt_at_fix and m.alt_at_fix >= m.alt_target_ft - 200
            row(mg_mark(done) .. string.format("CLIMB FL%.0f BEFORE FIX",
                    m.alt_target_ft / 100),
                string.format("%.0f FT", (mg_elev or 0) * 3.28084),
                (done or m.reached_fix) and (done and st.ok or st.alert) or st.value)
        end
        if m.mach_target then
            local acc  = m.mach_hold_acc or 0
            local done = acc >= m.mach_hold_s
            row(mg_mark(done) .. string.format("HOLD MACH >= %.2f", m.mach_target),
                string.format("%s / %s", mg_fmt_time(acc),
                    mg_fmt_time(m.mach_hold_s)),
                done and st.ok or st.value)
        end
        if m.fuel_budget_kg then
            local used = (m.fuel_start_kg or 0) - (mg_fuel_kg or 0)
            row(string.format("[ ] FUEL USED <= %.0f KG", m.fuel_budget_kg),
                string.format("%.0f KG", used),
                used <= m.fuel_budget_kg and st.value or st.alert)
        end
        if m.emergency then
            local state_word, state_col
            if not m.injected then state_word, state_col = "ARMED", st.dim
            elseif m.landed then state_word, state_col = "LANDED", st.ok
            else state_word, state_col = "IN FLIGHT", st.alert end
            row(mg_mark(m.landed) .. "SURVIVE ENGINE FAILURE + LAND",
                state_word, m.landed and st.ok or st.warn)
        end

        -- rules
        spacer()
        for _, id in ipairs(m.constraints) do
            local def = MG_CONSTRAINTS[id]
            local cs  = m.cstate[id]
            local live_bad = def.check and def.check() or false
            local rtext, rcol
            if cs.viol > 0 then
                rtext = string.format("x%d", cs.viol)
                rcol  = st.alert
            elseif live_bad then
                rtext = "VIOLATING"
                rcol  = st.alert
            else
                rtext = "OK"
                rcol  = st.dim
            end
            if id == "touchdown" and cs.done then
                rtext = string.format("%.0f FPM", cs.value or 0)
                rcol  = (cs.viol > 0) and st.alert or st.ok
            end
            if id == "reserve" and not cs.done then
                rtext = string.format("%.0f KG", mg_fuel_kg or 0)
                rcol  = st.dim
            end
            row("RULE  " .. def.label, rtext, st.label, rcol)
        end
        spacer()
        button("abort", "ABORT MISSION", st.warn)

    elseif mg_state == MG_DONE and mg_result then
        local r = mg_result
        row(r.title, r.ok and "PASS" or "FAIL",
            r.ok and st.ok or st.alert)
        row(string.format("SCORE  %d", r.score), "",
            r.ok and st.gold or st.alert)
        for i = 1, math.min(#r.lines, 7) do
            row(r.lines[i], "", st.label)
        end
        row(string.format("STREAK %d   BEST %d   FLOWN %d",
            mg_streak, mg_best, mg_completed), "", st.subhdr)
        spacer()
        button("gen", "NEW MISSION  (click)")
    end

    local h = 20 + 8 + #rows * rh + 10
    local bottom = bottom_anchor
    local top = bottom + h

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    mg_bar(x, bottom, top, w, st.bg, 0.75)
    mg_bar(x, top - 20, top, w, st.header_bg, 0.92)
    mg_bar(x, top - 2, top, w, st.accent)
    mg_txt(x + 10, top - 15, "MISSION GENERATOR", st.accent)
    mg_txt_right(x + w - 10, top - 15, head_state, head_col)

    local y = top - 20 - rh + 2
    for _, rw in ipairs(rows) do
        if rw.blank then
            -- spacer line
        elseif rw.btn then
            mg_bar(x + 8, y - rh + 6, y + 2, w - 16, rw.col, 0.75)
            mg_txt(x + 16, y - 11, rw.btn, {0.05, 0.05, 0.05})
            mg_buttons[#mg_buttons + 1] = {
                key = rw.key,
                x0 = x + 8, x1 = x + w - 8,
                y0 = y - rh + 6, y1 = y + 2,
            }
        else
            mg_txt(x + 12, y - 11, rw.l, rw.col)
            if rw.r and rw.r ~= "" then
                mg_txt_right(x + w - 12, y - 11, rw.r, rw.rcol)
            end
        end
        y = y - rh
    end

    -- toast above the panel
    if mg_toast_text and (mg_simtime or 0) < mg_toast_until then
        local tw = measure_string(mg_toast_text) + 32
        local bx = x + math.floor((w - tw) / 2)
        local by = top + 12
        mg_bar(bx, by, by + 24, tw, {0.02, 0.06, 0.09}, 0.85)
        mg_bar(bx, by, by + 24, 4, st.accent)
        mg_txt(bx + 16, by + 7, mg_toast_text, st.value)
    end
end

-- --------------------------------------------------------------- MOUSE -----
function mg_mouse_click()
    if MOUSE_STATUS ~= "down" then return end
    local mx, my = MOUSE_X or -1, MOUSE_Y or -1
    for _, b in ipairs(mg_buttons) do
        if mx >= b.x0 and mx <= b.x1 and my >= b.y0 and my <= b.y1 then
            RESUME_MOUSE_CLICK = true
            if b.key == "gen" then mg_generate()
            elseif b.key == "abort" then mg_abort()
            end
            return
        end
    end
end

-- ------------------------------------------------------- PANEL + REPORT ----
function mg_toggle_panel(on)
    if on == nil then
        MG_CONFIG.panel_enabled = not MG_CONFIG.panel_enabled
    else
        MG_CONFIG.panel_enabled = (on == true)
    end
    mg_toast("MISSION PANEL: " .. (MG_CONFIG.panel_enabled and "ON" or "OFF"))
end

function mg_report()
    logMsg("Mission Gen: report ----------------------------------")
    logMsg(string.format("  state=%s streak=%d best=%d flown=%d",
        tostring(mg_state), mg_streak, mg_best, mg_completed))
    logMsg("  progress file: " .. mg_progress_path())
    local m = mg_mission
    if m then
        logMsg(string.format("  mission=%s [%s] budget=%s clock=%s",
            m.title, MG_DIFF_NAMES[m.difficulty],
            mg_fmt_time(m.budget_s), mg_fmt_time(mg_clock)))
        logMsg(string.format("  fix brg %03.0f / %.0f NM  out %.1f NM  home %.1f NM",
            m.brg_deg, m.leg_nm, m.dist_fix or -1, m.dist_home or -1))
        for _, id in ipairs(m.constraints) do
            local cs = m.cstate[id]
            logMsg(string.format("  rule %-28s violations=%d",
                MG_CONSTRAINTS[id].label, cs and cs.viol or 0))
        end
    end
end

-- --------------------------------------------------------- LIFECYCLE -------
math.randomseed(os.time())
mg_load_progress()
logMsg("Mission Gen: loaded - progress file " .. mg_progress_path())
logMsg(string.format("Mission Gen: streak %d, best %d, flown %d",
    mg_streak, mg_best, mg_completed))

do_every_frame("mg_frame()")
do_every_draw("mg_draw()")
do_on_mouse_click("mg_mouse_click()")

-- ---------------------------------------------------- COMMANDS + MACROS ----
create_command("MissionGen/generate",
    "Mission Gen: generate a new mission", "mg_generate()", "", "")
create_command("MissionGen/abort",
    "Mission Gen: abort the active mission", "mg_abort()", "", "")
create_command("MissionGen/toggle_panel",
    "Mission Gen: toggle the mission panel", "mg_toggle_panel()", "", "")
create_command("MissionGen/report",
    "Mission Gen: write a status report to Log.txt", "mg_report()", "", "")

add_macro("Mission Gen: toggle panel", "mg_toggle_panel(true)", "mg_toggle_panel(false)",
    MG_CONFIG.panel_enabled and "activate" or "deactivate")
add_macro("Mission Gen: generate", "mg_generate()")
add_macro("Mission Gen: abort", "mg_abort()")
add_macro("Mission Gen: status report", "mg_report()")
