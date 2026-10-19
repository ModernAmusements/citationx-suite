-- ============================================================================
--  CESSNA CITATION X MISSION GENERATOR
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  Randomly generated story missions that turn a free flight into a scored
--  sortie. Every mission comes with a client, a payload, a reason to fly and
--  a short multi-leg flight plan. Everything is measured from the sim's own
--  datarefs, so it works anywhere in the world, from any airport and in any
--  aircraft (the Citation X simply gets the nicest numbers).
--
--    * missions start on the ground - park up, then GENERATE
--    * read the BRIEFING (client, payload, flight plan, goals, hard rules)
--      and ACCEPT - or SKIP to draw another one
--    * the clock starts the moment the wheels leave the runway
--    * fly the plan leg by leg; the last leg is always home, land to a
--      full stop within 3 NM of where you started
--    * the story picks the goals:
--        VIP CHARTER      smooth cabin, gentle touchdown, on the clock
--        AIR TAXI         hop several stops in sequence
--        MEDEVAC          life-or-death clock, door-to-pad time bonus
--        FERRY FLIGHT     reposition the jet inside a tight fuel budget
--        PHOTO SURVEY     climb to a photo level before the last leg
--        TEST FLIGHT      hold a mach number for a set time
--        RELIABILITY FLT  engine flameout in flight (uses the QRH trainer
--                         if installed, else fires the failure directly)
--        FLIGHT SCHOOL    graded lesson: steep turns, pattern work, precision
--                         approach or climb & level - with an A-F instructor
--                         grade in the debrief (MissionGen/lesson)
--    * every mission also draws 2-4 hard rules, each violation scores minus:
--        SPEED <= 250 KT below 10,000 FT        MACH <= 0.87
--        BANK <= 35 DEG                         G-LOAD -0.3 .. +2.5
--        TOUCHDOWN >= -300 FPM                  RESERVE FUEL ON LANDING
--    * four difficulties (EASY / NORMAL / HARD / BRUTAL) scale legs,
--      distance, clock and score
--    * best score, current streak and missions flown persist to disk
--
--  Commands (bindable in Settings > Keyboard / Joystick):
--    MissionGen/generate      MissionGen/accept       MissionGen/skip
--    MissionGen/abort         MissionGen/lesson       MissionGen/toggle_panel
--    MissionGen/report
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
    force_archetype    = nil,     -- set by MissionGen/lesson, cleared afterwards
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

-- Written only by the RELIABILITY objective (when the QRH trainer is absent).
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
local MG_IDLE, MG_BRIEF, MG_ARMED, MG_ACTIVE, MG_DONE = 0, 1, 2, 3, 4

local MG_DIFF_NAMES  = { "EASY", "NORMAL", "HARD", "BRUTAL" }
local MG_DIFF_BASE   = { 300, 600, 900, 1200 }
local MG_DIFF_TIME   = { 1.20, 1.05, 0.95, 0.88 }   -- clock factor
local MG_DIFF_LEG_NM = { {12, 22}, {15, 30}, {18, 38}, {22, 48} }  -- per leg
local MG_DIFF_LEGS   = { 2, 2, 3, 3 }               -- legs incl. the ride home
local MG_DIFF_RULES  = { 2, 3, 4, 4 }

local MG_CALLSIGNS = {
    "SILVER ARROW", "NIGHT HAWK", "IRON EAGLE", "BLUE STREAK",
    "GHOST RIDER", "DESERT FOX", "STORM CELL", "THUNDERBIRD",
    "ACES HIGH", "VIPER ONE", "PHOENIX", "BLACK CAT",
    "WHITE KNIGHT", "RAVEN", "COPPERHEAD", "SKYHAWK",
}

local MG_OPERATORS = {
    "NORDWIND AIR", "BLUE RIDGE CHARTER", "SILVERLINE AVIATION",
    "CROWN JET SERVICES", "POLARIS AIR", "ATLAS EXECUTIVE",
    "HARBOUR AIR LINK", "MERIDIAN FLIGHT OPS",
}

-- Syllables for generated fix names (no nav database, so waypoints are
-- synthetic - but they still deserve names).
local MG_NAME_A = {
    "VEL", "DUN", "KAR", "LON", "MIR", "TAZ", "BEL", "GAR", "NIV", "OST",
    "RUK", "SAM", "TEL", "WEX", "ZUR", "HAN", "KEB", "LOR", "MAR", "PIL",
}
local MG_NAME_B = {
    "TO", "RA", "MI", "KA", "LO", "NE", "SO", "TI", "VA", "ZE",
    "DA", "KU", "RI", "XE", "NA",
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

-- Initial great-circle bearing from (lat1, lon1) to (lat2, lon2).
local function mg_bearing(lat1, lon1, lat2, lon2)
    local p1, p2 = mg_rad(lat1), mg_rad(lat2)
    local dl = mg_rad(lon2 - lon1)
    local y = math.sin(dl) * math.cos(p2)
    local x = math.cos(p1) * math.sin(p2)
            - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (mg_atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0
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

local function mg_pick(list)
    return list[math.random(#list)]
end

-- Word-wrap `text` to lines that fit `max_px` screen pixels.
local function mg_wrap(text, max_px)
    local lines = {}
    local cur = ""
    for word in string.gmatch(text, "%S+") do
        local trial = (cur == "") and word or (cur .. " " .. word)
        if measure_string(trial) > max_px and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = trial
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

local mg_name_used = {}
local function mg_fix_name()
    for _ = 1, 50 do
        local n = mg_pick(MG_NAME_A) .. mg_pick(MG_NAME_B)
        if not mg_name_used[n] then
            mg_name_used[n] = true
            return n
        end
    end
    return mg_pick(MG_NAME_A) .. mg_pick(MG_NAME_B) .. mg_pick(MG_NAME_B)
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

-- ------------------------------------------------------------ ARCHETYPES ---
-- Every archetype writes the goals into the mission in `setup` and returns the
-- story lines for the briefing page. Goals reuse the shared mechanics (clock,
-- altitude, mach, fuel, emergency) with story-flavored numbers and labels.
local MG_ARCHETYPES = {}

MG_ARCHETYPES.charter = {
    title = "VIP CHARTER",
    legs  = function(diff) return (diff >= 3) and 3 or 2 end,
    clock = 1.00,
    setup = function(m, diff)
        m.touchdown_min = -250
        m.extra_rules = {
            comfort = { label = "CABIN G -0.1 .. +1.6", penalty = 25,
                check = function()
                    return (mg_onground or 0) == 0
                       and ((mg_gload or 1) > 1.6 or (mg_gload or 1) < -0.1)
                end },
        }
        local who = mg_pick({
            "a steel magnate and his legal team",
            "a film director scouting locations",
            "two touring musicians and their gear",
            "a racing driver and his trainer",
            "an heiress and her small, loud dog",
        })
        local why = mg_pick({
            "a board meeting", "a contract signing", "a yacht handover",
            "a fashion shoot", "a winery weekend",
        })
        return {
            string.format("%s wants %s at %s in time for %s.",
                m.operator, who, m.legs[1].name, why),
            "Fly them out and bring them home. Gentle hands: the cabin",
            "stays between -0.1 and +1.6 G and the touchdown kisses the",
            "runway at -250 fpm or better. They are paying for smooth.",
        }
    end,
}

MG_ARCHETYPES.airtaxi = {
    title = "AIR TAXI",
    legs  = function(diff) return (diff >= 3) and 4 or 3 end,
    clock = 1.05,
    setup = function(m)
        local names = {}
        for i = 1, #m.legs - 1 do names[#names + 1] = m.legs[i].name end
        return {
            string.format("%s runs the evening hopper: %s, then home.",
                m.operator, table.concat(names, ", ")),
            "A full cabin of commuters pays per leg - fly the plan in",
            "order and keep the clock. Nobody tips for circling.",
        }
    end,
}

MG_ARCHETYPES.medevac = {
    title = "MEDEVAC",
    legs  = function() return 2 end,
    clock = 0.80,
    setup = function(m)
        m.door_bonus_s = math.floor(m.budget_s * 0.80)
        local who = mg_pick({
            "a transplant team with a cooled organ box",
            "a neonatal nurse and an incubator",
            "a trauma surgeon on call",
            "a cardiac patient wired to a monitor",
        })
        return {
            string.format("%s has %s waiting at the terminal.",
                m.operator, who),
            string.format("Be over %s, turn, and be back at base before the",
                m.legs[1].name),
            string.format("ice runs out - inside %s there is a life bonus.",
                mg_fmt_time(m.door_bonus_s)),
        }
    end,
}

MG_ARCHETYPES.ferry = {
    title = "FERRY FLIGHT",
    legs  = function(diff) return (diff >= 3) and 3 or 2 end,
    clock = 1.15,
    setup = function(m, diff)
        local air_s = (m.total_nm / MG_CONFIG.cruise_tas_kt) * 3600
        m.fuel_budget_kg = math.floor(air_s * 0.65
            * ({1.05, 1.00, 0.96, 0.93})[diff] + 300)
        m.force_reserve = true
        return {
            string.format("%s needs the jet repositioned past %s and back",
                m.operator, m.legs[1].name),
            "tonight. The fuel card is yours, not theirs - burn as little",
            "as you dare and park it with the reserves untouched.",
        }
    end,
}

MG_ARCHETYPES.survey = {
    title = "PHOTO SURVEY",
    legs  = function(diff) return (diff >= 3) and 3 or 2 end,
    clock = 1.05,
    setup = function(m, diff)
        local fl_min = ({180, 220, 260, 300})[diff]
        local fl_max = ({240, 280, 320, 360})[diff]
        m.alt_target_ft = math.random(math.floor(fl_min / 10),
                                      math.floor(fl_max / 10)) * 1000
        return {
            string.format("%s contracts a photo run for %s.",
                m.operator, mg_pick({
                    "a coastal survey", "a fault-line scan",
                    "a pipeline inspection", "a storm-chase crew",
                })),
            string.format("The cameras only pay above FL%.0f - get up there",
                m.alt_target_ft / 100),
            "before the last leg home, then bring the film down gently.",
        }
    end,
}

MG_ARCHETYPES.testflight = {
    title = "TEST FLIGHT",
    legs  = function() return 2 end,
    clock = 1.00,
    setup = function(m, diff)
        m.mach_target = ({0.68, 0.72, 0.76, 0.79})[diff]
                      + math.random(0, 2) * 0.01
        m.mach_hold_s = 60 * diff + 30
        return {
            string.format("%s signed off an engine change at 02:00.",
                m.operator),
            string.format("The company inspector wants mach %.2f held for",
                m.mach_target),
            string.format("%s with a dead-stable jet, then a clean return.",
                mg_fmt_time(m.mach_hold_s)),
        }
    end,
}

MG_ARCHETYPES.reliability = {
    title = "RELIABILITY FLT",
    legs  = function() return 2 end,
    clock = 1.00,
    setup = function(m)
        m.emergency = true
        return {
            string.format("%s uploaded a FADEC update to engine 1 and the",
                m.operator),
            "chief pilot wants a reliability check. If the left engine",
            "quits somewhere along the plan - run the QRH and bring",
            "her home on one. No pressure.",
        }
    end,
}

-- Flight school: a graded lesson with an instructor in the right seat.
-- The debrief carries a letter grade derived from rule busts and missed
-- maneuvers (see mg_grade), and a clean ride pays a checkride bonus.
MG_ARCHETYPES.school = {
    title = "FLIGHT SCHOOL",
    legs  = function() return 3 end,
    clock = 1.10,
    setup = function(m, diff)
        local instructor = "Capt. " .. mg_pick({
            "Voss", "Mercer", "Halden", "Okafor", "Lindqvist", "Reyes",
        })
        local lesson = mg_pick({ "steep", "pattern", "precision", "climb" })

        if lesson == "steep" then
            m.lesson        = "steep"
            m.lesson_title  = "STEEP TURNS"
            m.steep_hold_s  = 45 + (diff - 1) * 10
            m.steep_hold_acc = 0
            m.touchdown_min = -250
            m.extra_rules = {
                bankbust = { label = "BANK <= 50 DEG", penalty = 30,
                    check = function()
                        return (mg_onground or 0) == 0
                           and math.abs(mg_bank or 0) > 50
                    end },
            }
            return {
                string.format("INSTRUCTOR: %s. LESSON: STEEP TURNS.", instructor),
                string.format("Hold 30-45 deg of bank for %s in total.",
                    mg_fmt_time(m.steep_hold_s)),
                "Roll in smoothly, hold it, roll out on a heading. Anything",
                "past 50 deg of bank busts the ride. Then fly the plan home.",
            }
        elseif lesson == "pattern" then
            m.lesson        = "pattern"
            m.lesson_title  = "PATTERN WORK"
            m.touchdown_min = -200
            return {
                string.format("INSTRUCTOR: %s. LESSON: PATTERN WORK.", instructor),
                "Three short legs, one landing - every turn flown like the",
                "examiner is watching. Set it down at -200 fpm or better",
                "and stop inside the box. Smooth is the whole lesson.",
            }
        elseif lesson == "precision" then
            m.lesson        = "precision"
            m.lesson_title  = "PRECISION APPROACH"
            m.touchdown_min = -180
            return {
                string.format("INSTRUCTOR: %s. LESSON: PRECISION APPROACH.", instructor),
                "Fly the plan, then give me the softest touchdown of your",
                "life: -180 fpm or better, on centerline, no float. The",
                "chief pilot signs off on this one, so make it count.",
            }
        else
            local fl_min = ({180, 220, 260, 300})[diff]
            local fl_max = ({240, 280, 320, 340})[diff]
            m.lesson        = "climb"
            m.lesson_title  = "CLIMB & LEVEL"
            m.alt_target_ft = math.random(math.floor(fl_min / 10),
                                          math.floor(fl_max / 10)) * 1000
            return {
                string.format("INSTRUCTOR: %s. LESSON: CLIMB & LEVEL.", instructor),
                string.format("Climb to FL%.0f before the last leg, level off",
                    m.alt_target_ft / 100),
                "cleanly and hold it. Then descend on the plan and land",
                "without chasing the power levers all the way down.",
            }
        end
    end,
}

local MG_ARCH_WEIGHTS = {
    "charter", "charter", "airtaxi", "airtaxi", "medevac",
    "ferry", "ferry", "survey", "survey", "testflight", "reliability",
    "school", "school",
}

-- ------------------------------------------------------------- GENERATE ----
local function mg_build_legs(home_lat, home_lon, n_legs, diff)
    local legs = {}
    local lat, lon = home_lat, home_lon
    local brg = math.random(0, 359)
    local total = 0.0
    for i = 1, n_legs - 1 do
        local d = math.random(MG_DIFF_LEG_NM[diff][1], MG_DIFF_LEG_NM[diff][2])
        local nlat, nlon = mg_dest(lat, lon, brg, d)
        legs[#legs + 1] = {
            name = mg_fix_name(), lat = nlat, lon = nlon,
            brg = brg, dist_nm = d,
        }
        total = total + d
        lat, lon = nlat, nlon
        brg = (brg + 180 + math.random(-70, 70)) % 360
    end
    -- final leg: back home
    local home_d = mg_dist_nm(lat, lon, home_lat, home_lon)
    legs[#legs + 1] = {
        name = "HOME", lat = home_lat, lon = home_lon,
        brg = mg_bearing(lat, lon, home_lat, home_lon),
        dist_nm = home_d, home = true,
    }
    return legs, total + home_d
end

local function mg_build_mission()
    local roll = math.random(1, 10)
    local diff = roll <= 2 and 1 or (roll <= 5 and 2 or (roll <= 8 and 3 or 4))

    local forced = MG_CONFIG.force_archetype
    local arch = (forced and MG_ARCHETYPES[forced])
        or MG_ARCHETYPES[mg_pick(MG_ARCH_WEIGHTS)]
    local n_legs = math.max(2, arch.legs(diff))

    local home_lat = mg_lat or 0.0
    local home_lon = mg_lon or 0.0
    mg_name_used = {}
    local legs, total_nm = mg_build_legs(home_lat, home_lon, n_legs, diff)

    local budget = math.floor((total_nm / MG_CONFIG.cruise_tas_kt)
        * 3600 * MG_DIFF_TIME[diff] * arch.clock + 300)

    local cids = mg_shuffle_pick(MG_CONSTRAINT_POOL, MG_DIFF_RULES[diff])
    local cstate = {}
    for _, id in ipairs(cids) do
        cstate[id] = { viol = 0, was_bad = false, done = false }
    end

    local m = {
        callsign    = mg_pick(MG_CALLSIGNS),
        operator    = mg_pick(MG_OPERATORS),
        archetype   = arch.title,
        difficulty  = diff,
        legs        = legs,
        legs_done   = 0,
        total_nm    = total_nm,
        home_lat    = home_lat,
        home_lon    = home_lon,
        budget_s    = budget,
        constraints = cids,
        cstate      = cstate,
        rule_defs   = {},
        plane       = PLANE_ICAO,
        fuel_start_kg = mg_fuel_kg or 0.0,
        landed      = false,
        wheels_up   = false,
        injected    = false,
        mach_hold_acc = 0,
        max_alt_ft  = 0,
    }
    -- story sets the goals (and may add rules) before the rule list closes
    m.story = arch.setup(m, diff) or {}

    local kind_title = arch.title
    if m.lesson_title then
        kind_title = kind_title .. " - " .. m.lesson_title
    end
    m.title = m.callsign .. " - " .. kind_title .. " " ..
        string.format("%.0f NM", total_nm)

    if m.force_reserve and not cstate.reserve then
        cids[#cids + 1] = "reserve"
        cstate.reserve = { viol = 0, was_bad = false, done = false }
    end
    -- a story that promises a touchdown limit must always enforce it
    if m.touchdown_min and not cstate.touchdown then
        cids[#cids + 1] = "touchdown"
        cstate.touchdown = { viol = 0, was_bad = false, done = false }
    end
    if m.touchdown_min then
        cstate.touchdown.label = string.format(
            "TOUCHDOWN >= %d FPM", m.touchdown_min)
    end

    -- resolved rule definitions: all shared constraints + story extras
    for id, def in pairs(MG_CONSTRAINTS) do
        m.rule_defs[id] = def
    end
    if m.extra_rules then
        for id, def in pairs(m.extra_rules) do
            m.rule_defs[id] = def
            cids[#cids + 1] = id
            cstate[id] = { viol = 0, was_bad = false, done = false }
        end
    end

    return m
end

function mg_generate()
    if (mg_onground or 0) ~= 1
        or (mg_gs or 0) > mg_kt_to_ms(MG_CONFIG.max_start_gs_kt) then
        mg_toast("LAND & SLOW DOWN FIRST - MISSIONS START ON THE GROUND")
        return false
    end
    if mg_state ~= MG_IDLE and mg_state ~= MG_DONE then
        mg_clear_emergency(mg_mission)
    end

    mg_mission = mg_build_mission()
    mg_result  = nil
    mg_clock   = 0
    mg_state   = MG_BRIEF

    local m = mg_mission
    logMsg(string.format(
        "Mission Gen: briefing '%s' [%s] %.0f NM, %d legs, budget %s",
        m.title, MG_DIFF_NAMES[m.difficulty], m.total_nm, #m.legs,
        mg_fmt_time(m.budget_s)))
    mg_toast("BRIEFING READY - " .. m.title)
    return true
end

function mg_generate_archetype(key)
    MG_CONFIG.force_archetype = key
    local ok = mg_generate()
    MG_CONFIG.force_archetype = nil
    return ok
end

function mg_accept()
    if mg_state ~= MG_BRIEF or not mg_mission then
        mg_toast("NOTHING TO ACCEPT - GENERATE FIRST")
        return false
    end
    mg_state = MG_ARMED
    mg_toast("MISSION ACCEPTED - CLOCK STARTS AT WHEELS UP")
    logMsg("Mission Gen: accepted " .. mg_mission.title)
    return true
end

function mg_skip()
    if mg_state ~= MG_BRIEF then
        mg_toast("NOTHING TO SKIP")
        return false
    end
    mg_mission = mg_build_mission()
    mg_toast("NEW BRIEFING - " .. mg_mission.title)
    return true
end

function mg_abort()
    if not mg_mission then
        mg_toast("NO ACTIVE MISSION")
        return
    end
    local m = mg_mission
    mg_clear_emergency(m)
    if mg_state == MG_BRIEF then
        mg_mission = nil
        mg_state   = MG_IDLE
        mg_toast("BRIEFING DISCARDED")
        logMsg("Mission Gen: briefing discarded " .. m.title)
        return
    end
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
-- Instructor grade for FLIGHT SCHOOL lessons: every busted rule or missed
-- maneuver costs one letter. A clean ride is an A and pays a checkride bonus.
local MG_GRADES = { "A", "B", "C", "D", "F", "F" }
local function mg_grade(m)
    local busts = 0
    for _, id in ipairs(m.constraints) do
        local st = m.cstate[id]
        if st and st.viol > 0 then busts = busts + st.viol end
    end
    local missed = 0
    if m.steep_hold_s and (m.steep_hold_acc or 0) < m.steep_hold_s then
        missed = missed + 1
    end
    if m.alt_target_ft and (m.max_alt_ft or 0) < m.alt_target_ft - 200 then
        missed = missed + 1
    end
    local idx = math.min(#MG_GRADES, busts + missed + 1)
    return MG_GRADES[idx], busts, missed
end

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
            if (m.max_alt_ft or 0) >= m.alt_target_ft - 200 then
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
        if m.door_bonus_s and mg_clock <= m.door_bonus_s then
            score = score + 200
            lines[#lines + 1] = string.format(
                "DOOR TO PAD  +200  (under %s)", mg_fmt_time(m.door_bonus_s))
        end
        if m.lesson then
            local grade = mg_grade(m)
            if grade == "A" then
                score = score + 100
                lines[#lines + 1] = "CLEAN CHECKRIDE  +100"
            end
            lines[#lines + 1] = "INSTRUCTOR GRADE  " .. grade
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
            local def = m.rule_defs[id]
            local st  = m.cstate[id]
            if st and st.viol > 0 then
                local p = st.viol * def.penalty
                penalty_total = penalty_total + p
                if id == "touchdown" and st.value then
                    lines[#lines + 1] = string.format(
                        "HARD LANDING  %.0f FPM  -%d", st.value, p)
                else
                    lines[#lines + 1] = string.format("%s x%d  -%d",
                        st.label or def.label, st.viol, p)
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

    -- distance readouts are live in both ARMED and ACTIVE
    local lat = mg_lat or m.home_lat
    local lon = mg_lon or m.home_lon
    m.dist_home = mg_dist_nm(lat, lon, m.home_lat, m.home_lon)
    local nxt = m.legs[m.legs_done + 1]
    if nxt then
        m.dist_next = mg_dist_nm(lat, lon, nxt.lat, nxt.lon)
        m.brg_next  = mg_bearing(lat, lon, nxt.lat, nxt.lon)
    end

    if mg_state == MG_ARMED then
        if (mg_onground or 0) == 0 then
            mg_state    = MG_ACTIVE
            m.wheels_up = true
            mg_clock    = 0
            mg_toast("CLOCK STARTED - FLY THE PLAN")
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
    if alt_ft > (m.max_alt_ft or 0) then m.max_alt_ft = alt_ft end

    -- leg progression
    if nxt and (m.dist_next or 99)
        <= (nxt.home and MG_CONFIG.home_radius_nm or MG_CONFIG.fix_radius_nm) then
        m.legs_done = m.legs_done + 1
        if nxt.home then
            mg_toast("HOME LEG REACHED - LAND AND FULL STOP")
        else
            mg_toast(string.format("LEG %d/%d DONE - NEXT %s  %03.0f DEG",
                m.legs_done, #m.legs, m.legs[m.legs_done + 1].name,
                m.legs[m.legs_done + 1].brg or 0))
        end
        logMsg(string.format("Mission Gen: leg %s reached at %.0f ft after %s",
            nxt.name, alt_ft, mg_fmt_time(mg_clock)))
    end

    -- special objectives
    if m.mach_target and (mg_onground or 0) == 0
        and (mg_mach or 0) >= m.mach_target then
        m.mach_hold_acc = (m.mach_hold_acc or 0) + dt
    end
    -- flight school: steep-turn time only counts inside the 30-45 deg window
    if m.steep_hold_s and (mg_onground or 0) == 0 then
        local bank = math.abs(mg_bank or 0)
        if bank >= 30 and bank <= 45 then
            m.steep_hold_acc = (m.steep_hold_acc or 0) + dt
        end
    end
    if m.emergency and not m.injected
        and (m.legs_done >= 1 or alt_ft >= 8000 or mg_clock >= 240) then
        mg_inject_emergency(m)
    end

    -- rules with a live check
    for _, id in ipairs(m.constraints) do
        local def = m.rule_defs[id]
        local st  = m.cstate[id]
        if def.check and st and not st.done then
            local bad = def.check()
            if bad and not st.was_bad then
                st.viol = st.viol + 1
                logMsg(string.format("Mission Gen: rule broken - %s",
                    st.label or def.label))
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
            local limit = m.touchdown_min or -300
            if m.touchdown_fpm < limit then
                st.viol = 1
                mg_toast(string.format("HARD LANDING  %.0f FPM",
                    m.touchdown_fpm))
            end
        end
        logMsg(string.format("Mission Gen: touchdown %.0f fpm",
            m.touchdown_fpm))
    end
    m.was_onground = ong

    -- completion: plan done, back home, on the ground, stopped
    if m.legs_done == #m.legs and m.landed
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

local function mg_draw_brief(rows, row, spacer, button, st)
    local m = mg_mission
    row(m.title, MG_DIFF_NAMES[m.difficulty], st.warn)
    spacer()
    for _, ln in ipairs(m.story) do
        row(ln, "", st.value)
    end
    spacer()
    row("FLIGHT PLAN  (fly in order, last leg home)", "", st.subhdr)
    for i, leg in ipairs(m.legs) do
        row(string.format("  %d  %-7s %03.0f DEG / %.0f NM",
                i, leg.name, leg.brg, leg.dist_nm),
            leg.home and "FULL STOP" or "", leg.home and st.gold or st.label)
    end
    spacer()
    row("OBJECTIVES", "", st.subhdr)
    row(mg_mark(false) .. string.format("FLY %d LEGS, RETURN, FULL STOP",
            #m.legs), "", st.value)
    if m.alt_target_ft then
        row(mg_mark(false) .. string.format("CLIMB FL%.0f BEFORE HOME LEG",
                m.alt_target_ft / 100), "", st.value)
    end
    if m.mach_target then
        row(mg_mark(false) .. string.format("HOLD MACH %.2f FOR %s",
                m.mach_target, mg_fmt_time(m.mach_hold_s)), "", st.value)
    end
    if m.fuel_budget_kg then
        row(mg_mark(false) .. string.format("FUEL USED <= %.0f KG",
                m.fuel_budget_kg), "", st.value)
    end
    if m.emergency then
        row(mg_mark(false) .. "SURVIVE ENGINE FAILURE + LAND", "", st.warn)
    end
    if m.steep_hold_s then
        row(mg_mark(false) .. string.format(
                "STEEP TURNS %s IN 30-45 DEG BANK",
                mg_fmt_time(m.steep_hold_s)), "", st.value)
    end
    if m.door_bonus_s then
        row(mg_mark(false) .. string.format("BONUS: HOME INSIDE %s",
                mg_fmt_time(m.door_bonus_s)), "", st.gold)
    end
    spacer()
    for _, id in ipairs(m.constraints) do
        local stt = m.cstate[id]
        local def = m.rule_defs[id]
        row("RULE  " .. (stt.label or def.label), "", st.label)
    end
    spacer()
    row(string.format("CLOCK  %s  -  STARTS AT WHEELS UP",
            mg_fmt_time(m.budget_s)), "", st.value)
    spacer()
    button("accept", "ACCEPT MISSION  (click)", st.ok)
    button("skip",   "SKIP - NEW BRIEFING  (click)", st.subhdr)
end

local function mg_draw_flight(rows, row, spacer, button, st)
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

    -- leg list
    spacer()
    row("FLIGHT PLAN", "", st.subhdr)
    for i, leg in ipairs(m.legs) do
        local done = i <= m.legs_done
        local rtext, rcol
        if done then
            rtext, rcol = "DONE", st.ok
        elseif i == m.legs_done + 1 then
            rtext = string.format("%03.0f  %4.1f NM",
                m.brg_next or leg.brg, m.dist_next or leg.dist_nm)
            rcol  = st.gold
        else
            rtext, rcol = string.format("%.0f NM", leg.dist_nm), st.dim
        end
        row(mg_mark(done) .. leg.name, rtext,
            done and st.ok or (i == m.legs_done + 1 and st.value or st.dim), rcol)
    end
    row("", string.format("HOME %4.1f NM", m.dist_home or 0.0), st.dim, st.dim)

    -- objectives
    if m.alt_target_ft then
        local done = (m.max_alt_ft or 0) >= m.alt_target_ft - 200
        row(mg_mark(done) .. string.format("CLIMB FL%.0f",
                m.alt_target_ft / 100),
            string.format("MAX %.0f FT", m.max_alt_ft or 0),
            done and st.ok or st.value)
    end
    if m.mach_target then
        local acc  = m.mach_hold_acc or 0
        local done = acc >= m.mach_hold_s
        row(mg_mark(done) .. string.format("HOLD MACH >= %.2f", m.mach_target),
            string.format("%s / %s", mg_fmt_time(acc), mg_fmt_time(m.mach_hold_s)),
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
    if m.steep_hold_s then
        local acc  = m.steep_hold_acc or 0
        local done = acc >= m.steep_hold_s
        row(mg_mark(done) .. "STEEP TURNS 30-45 DEG",
            string.format("%s / %s", mg_fmt_time(acc),
                mg_fmt_time(m.steep_hold_s)),
            done and st.ok or st.value)
    end

    -- rules
    spacer()
    for _, id in ipairs(m.constraints) do
        local def = m.rule_defs[id]
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
        row("RULE  " .. (cs.label or def.label), rtext, st.label, rcol)
    end
    spacer()
    button("abort", "ABORT MISSION", st.warn)
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
    elseif mg_state == MG_BRIEF then
        head_state, head_col = "BRIEFING", st.gold
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
        row("STORY SORTIES WITH A PLAN, A CLOCK AND HARD RULES", "", st.label)
        if mg_result then
            row(string.format("LAST: %s", mg_result.title),
                mg_result.ok and "PASS" or "FAIL",
                mg_result.ok and st.ok or st.alert)
        else
            row("PARK UP ON THE GROUND AND GENERATE A BRIEFING", "", st.label)
        end
        row(string.format("STREAK %d   BEST %d   FLOWN %d",
            mg_streak, mg_best, mg_completed), "", st.gold)
        spacer()
        button("gen", "GENERATE MISSION  (click)")

    elseif mg_state == MG_BRIEF then
        mg_draw_brief(rows, row, spacer, button, st)

    elseif mg_state == MG_ARMED or mg_state == MG_ACTIVE then
        mg_draw_flight(rows, row, spacer, button, st)

    elseif mg_state == MG_DONE and mg_result then
        local r = mg_result
        row(r.title, r.ok and "PASS" or "FAIL",
            r.ok and st.ok or st.alert)
        row(string.format("SCORE  %d", r.score), "",
            r.ok and st.gold or st.alert)
        for i = 1, math.min(#r.lines, 9) do
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
            elseif b.key == "accept" then mg_accept()
            elseif b.key == "skip" then mg_skip()
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
        for i, leg in ipairs(m.legs) do
            logMsg(string.format("  leg %d %-7s %03.0f/%4.0f NM %s",
                i, leg.name, leg.brg, leg.dist_nm,
                (i <= (m.legs_done or 0)) and "DONE" or ""))
        end
        for _, id in ipairs(m.constraints) do
            local cs = m.cstate[id]
            local def = m.rule_defs[id]
            logMsg(string.format("  rule %-28s violations=%d",
                (cs and cs.label) or (def and def.label) or id,
                cs and cs.viol or 0))
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
    "Mission Gen: generate a new mission briefing", "mg_generate()", "", "")
create_command("MissionGen/accept",
    "Mission Gen: accept the briefed mission", "mg_accept()", "", "")
create_command("MissionGen/skip",
    "Mission Gen: skip to a new briefing", "mg_skip()", "", "")
create_command("MissionGen/lesson",
    "Mission Gen: generate a flight-school lesson",
    "mg_generate_archetype('school')", "", "")
create_command("MissionGen/abort",
    "Mission Gen: abort the active mission", "mg_abort()", "", "")
create_command("MissionGen/toggle_panel",
    "Mission Gen: toggle the mission panel", "mg_toggle_panel()", "", "")
create_command("MissionGen/report",
    "Mission Gen: write a status report to Log.txt", "mg_report()", "", "")

add_macro("Mission Gen: toggle panel", "mg_toggle_panel(true)", "mg_toggle_panel(false)",
    MG_CONFIG.panel_enabled and "activate" or "deactivate")
add_macro("Mission Gen: generate", "mg_generate()")
add_macro("Mission Gen: accept", "mg_accept()")
add_macro("Mission Gen: skip briefing", "mg_skip()")
add_macro("Mission Gen: flight school lesson", "mg_generate_archetype('school')")
add_macro("Mission Gen: abort", "mg_abort()")
add_macro("Mission Gen: status report", "mg_report()")
