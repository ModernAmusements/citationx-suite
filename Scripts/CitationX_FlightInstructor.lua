-- ============================================================================
--  CESSNA CITATION X FLIGHT INSTRUCTOR
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  A graded lesson panel, not a telemetry mirror. Pick a lesson, read the
--  brief, fly the aeroplane exactly as the AFM asks, and the instructor scores
--  the items that matter - then shows you what you missed.
--
--  Lesson flow:  LESSON LIST -> BRIEF -> FLYING -> DEBRIEF -> (retry / next)
--
--    * every lesson has a written brief and a sim setup line; SET ME UP places
--      and configures the aeroplane for you (runway threshold, final, downwind
--      or cruise) within 40 NM of the field, or you can do it by hand in
--      X-Plane's Flight Configuration
--    * each graded item self-checks against the sim's own datarefs, and is
--      only awarded once it has been held for a moment - same idea as the QRH
--      trainer's switch checks, applied to flying
--    * three lessons inject their own failure through CitationX_QRH (engine
--      fire/flameout, flap jam, decompression), so the QRH checklist and this
--      panel work on the same aeroplane
--    * the live line only shows the numbers being graded (radio altitude,
--      airspeed against Vref, localiser/glideslope dots, sink rate). It exists
--      only while a lesson is running and only for that lesson's targets.
--    * best score per lesson is kept in CitationX_TrainingProgress.txt
--
--  Speeds come from the 750 AFM/POM (see docs/FLIGHT_TRAINING.md):
--    takeoff V1/VR/V2 by weight band, flaps 15
--    landing VREF 108 KIAS at 23,000 lb to 132 KIAS at 31,800 lb
--    Vfe 250/210/180, Vle 210, Vmo 270 below 8,000 ft, Vmo 350 above
--
--  Commands (bindable in Settings > Keyboard/Joystick):
--    CitationXInstructor/toggle_panel     CitationXInstructor/finish
--    CitationXInstructor/start_next       CitationXInstructor/menu
--    CitationXInstructor/lesson_<key>
-- ============================================================================

FI_CONFIG = {
    -- Visible at load so the lesson list is one glance away; the hub row and
    -- the macro still toggle it, and hiding it abandons the run.
    panel_enabled = true,
    panel_x       = nil,     -- nil = bottom-right on first draw (the QRH keeps
                             -- the bottom-left, so a failure lesson shows both)
    panel_top     = nil,     -- nil = bottom-left (60 px) on first draw
    panel_w       = 430,
    row_h         = 20,
    header_h      = 34,
    footer_h      = 34,
    pad           = 14,
    require_c750  = true,
    setup_max_nm  = 40,     -- SET ME UP refuses a cross-country jump
}

-- Geometry only; colours come from the shared MA dark field (CX).
FI_STYLE = {
    bg        = CX.bg,
    header_bg = CX.header_bg,
    header_act = CX.header_act,
    border    = CX.border,
    hairline  = CX.hairline,
    title     = CX.title,
    label     = CX.label,
    sub       = CX.sub,
    dim       = CX.dim,
    value     = CX.value,
    ok        = CX.ok,
    warn      = CX.warn,
    bad       = CX.bad,
    accent    = CX.accent,
    btn       = CX.btn,
    footer_bg = CX.footer_bg,
    footer_fg = CX.footer_fg,
    footer_h  = 34,
}

-- --------------------------------------------------------------- DATAREFS ---
-- Air data and geometry.
dataref("fi_ias",        "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("fi_gs",         "sim/flightmodel/position/groundspeed",        "readonly")
dataref("fi_fpm",        "sim/flightmodel/position/vh_ind_fpm",         "readonly")
dataref("fi_agl_m",      "sim/flightmodel/position/y_agl",              "readonly")
dataref("fi_elev_m",     "sim/flightmodel/position/elevation",          "readonly")
dataref("fi_mag_psi",    "sim/flightmodel/position/mag_psi",            "readonly")
dataref("fi_psi",        "sim/flightmodel/position/psi",                "readonly")
dataref("fi_hpath",      "sim/flightmodel/position/hpath",              "readonly")
dataref("fi_pitch",      "sim/flightmodel/position/true_theta",         "readonly")
dataref("fi_roll",       "sim/flightmodel/position/true_phi",           "readonly")
dataref("fi_g",          "sim/flightmodel/forces/g_nrml",               "readonly")
dataref("fi_on_ground",  "sim/flightmodel/failures/onground_any",       "readonly")
dataref("fi_ra",         "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", "readonly")
dataref("fi_time",       "sim/time/total_running_time_sec",             "readonly")
dataref("fi_weight_kg",  "sim/flightmodel/weight/m_total",              "readonly")
dataref("fi_payload_kg", "sim/flightmodel/weight/m_fixed",              "writable")
dataref("fi_fuel_kg",    "sim/flightmodel/weight/m_fuel_total",         "readonly")
-- The C750's tank ratio is 0.461 / 0.270 / 0.270 (left, right, centre).
dataref("fi_fuel_t0",    "sim/flightmodel/weight/m_fuel1",              "writable")
dataref("fi_fuel_t1",    "sim/flightmodel/weight/m_fuel2",              "writable")
dataref("fi_fuel_t2",    "sim/flightmodel/weight/m_fuel3",              "writable")

-- Configuration.
dataref("fi_gear",       "sim/cockpit2/controls/gear_handle_down",      "readonly")
dataref("fi_flap",       "sim/cockpit2/controls/flap_system_deploy_ratio", "readonly")
dataref("fi_flap_handle","sim/cockpit2/controls/flap_handle_deploy_ratio", "readonly")
dataref("fi_brake",      "sim/cockpit2/controls/speedbrake_ratio",      "readonly")
dataref("fi_n1_l",       "sim/cockpit2/engine/indicators/N1_percent",   "readonly", 1)
dataref("fi_n1_r",       "sim/cockpit2/engine/indicators/N1_percent",   "readonly", 2)

-- Autopilot and annunciators.
dataref("fi_ap_on",      "sim/cockpit2/autopilot/autopilot_on",         "readonly")
dataref("fi_ap_appr",    "sim/cockpit2/autopilot/approach_status",      "readonly")
dataref("fi_stall",      "sim/cockpit2/annunciators/stall_warning",     "readonly")
dataref("fi_gear_unsafe","sim/cockpit2/annunciators/gear_unsafe",       "readonly")
dataref("fi_reverser",   "sim/cockpit2/annunciators/reverser_deployed", "readonly")

-- Navigation deviation (the HSI is what the PFD is showing).
dataref("fi_hdef",       "sim/cockpit2/radios/indicators/hsi_hdef_dots_pilot", "readonly")
dataref("fi_vdef",       "sim/cockpit2/radios/indicators/hsi_vdef_dots_pilot", "readonly")
dataref("fi_dme",        "sim/cockpit2/radios/indicators/nav1_dme_distance_nm", "readonly")
dataref("fi_gps_xtk",    "sim/cockpit2/radios/indicators/gps_xtk",      "readonly")
dataref("fi_nav1_h",     "sim/cockpit2/radios/indicators/nav1_display_horizontal", "readonly")
dataref("fi_nav1_v",     "sim/cockpit2/radios/indicators/nav1_display_vertical",   "readonly")

-- Wind (for the crosswind lesson readout).
dataref("fi_wind_kts",   "sim/cockpit2/gauges/indicators/wind_speed_kts", "readonly")
dataref("fi_wind_dir",   "sim/cockpit2/gauges/indicators/wind_heading_deg_mag", "readonly")

-- --------------------------------------------------------------- HELPERS ----
local FI_STATE = { MENU = 1, BRIEF = 2, FLYING = 3, DEBRIEF = 4 }

local function fi_clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local function fi_between(x, lo, hi)
    return x ~= nil and x >= lo and x <= hi
end

-- Piecewise-linear VREF from the AFM simplified flap-full landing table
-- (23,000 lb -> 108 KIAS ... 31,800 lb -> 132 KIAS).
local FI_VREF_TABLE = {
    { 23000, 108 }, { 24000, 110 }, { 26000, 115 },
    { 28000, 121 }, { 30000, 126 }, { 31800, 132 },
}

local function fi_vref_lb(wt_lb)
    local t = FI_VREF_TABLE
    if wt_lb == nil or wt_lb <= t[1][1] then return t[1][2] end
    if wt_lb >= t[#t][1] then return t[#t][2] end
    for i = 2, #t do
        if wt_lb <= t[i][1] then
            local w0, v0 = t[i - 1][1], t[i - 1][2]
            local w1, v1 = t[i][1], t[i][2]
            return v0 + (v1 - v0) * (wt_lb - w0) / (w1 - w0)
        end
    end
    return t[#t][2]
end

-- Takeoff V-speeds, flaps 15, at or below 2,000 ft MSL / 30 C (AFM table).
local FI_TKO_TABLE = {
    { 27000, 114, 116, 129 },
    { 30000, 116, 119, 127 },
    { 33000, 125, 128, 132 },
    { 35700, 133, 134, 137 },
}

local function fi_tko_speeds(wt_lb)
    for _, row in ipairs(FI_TKO_TABLE) do
        if wt_lb <= row[1] then return row[2], row[3], row[4] end
    end
    local last = FI_TKO_TABLE[#FI_TKO_TABLE]
    return last[2], last[3], last[4]
end

-- Flap detent from the deployed ratio: 0 / 5 / 15 / 35 degrees.
local function fi_flap_name(ratio)
    if ratio == nil then return "?" end
    if ratio < 0.20 then return "UP" end
    if ratio < 0.62 then return "5" end
    if ratio < 0.88 then return "15" end
    return "35"
end

-- 3-degree path sink rate for a ground speed in knots (tan 3 deg = 0.0524).
local function fi_path_fpm(gs_kts)
    return (gs_kts or 0) * 5.3109
end

local function fi_abs(x)
    return x and math.abs(x) or 999
end

local inst_setup_target = ""   -- last computed target, for the watcher
local inst_setup_weight_lb = nil -- weight the last setup imposed, for the speeds
local inst_ground_settle = 0      -- frames until a runway placement snaps to the surface

-- ------------------------------------------------------------- AUTO SETUP ----
-- "SET ME UP" places the aeroplane where the lesson begins instead of asking
-- the pilot to do it in Flight Configuration. Thresholds and true headings are
-- taken from X-Plane's own apt.dat (Global Airports), so the final is on the
-- real centreline; nothing here is invented.
--
-- Only the current position is moved (local_x/z/y deltas), so this works
-- without touching the read-only lat/lon datarefs. Refused beyond 40 NM from
-- the field: a long jump would tear the scenery.
local FI_RUNWAYS = {
    KLAX_25L = { lat = 33.9373695, lon = -118.3827247, hdg = 262.97,
                 elev_ft = 125, nav = 10990, icao = "KLAX" },  -- ILS ILAX 109.90
    KLAX_07L = { lat = 33.9355612, lon = -118.4220740, hdg =  82.97,
                 elev_ft = 125, nav = 11110, icao = "KLAX" },  -- ILS IIAS 111.10
    KSAN_27  = { lat = 32.7299936, lon = -117.1749683, hdg = 286.08,
                 elev_ft =  17, nav = nil,   icao = "KSAN" },  -- RNAV, no ILS
    KSNA_20R = { lat = 33.6816573, lon = -117.8650825, hdg = 207.80,
                 elev_ft =  56, nav = 11175, icao = "KSNA" },  -- ILS ISNA 111.75
}

-- Move a lat/lon by a distance (metres) along a true heading.
local function fi_move_latlon(lat, lon, hdg_deg, dist_m)
    local r  = math.rad(hdg_deg)
    local dn = dist_m * math.cos(r)
    local de = dist_m * math.sin(r)
    local dlat = dn / 111320.0
    local dlon = de / (111320.0 * math.cos(math.rad(lat)))
    return lat + dlat, lon + dlon
end

local function fi_dist_nm(lat1, lon1, lat2, lon2)
    local dn = (lat2 - lat1) * 111320.0
    local de = (lon2 - lon1) * 111320.0 * math.cos(math.rad((lat1 + lat2) / 2))
    return math.sqrt(dn * dn + de * de) / 1852.0
end

-- Put the aeroplane at a target position/attitude/speed. Everything is a delta
-- on the OpenGL local frame (+X east, +Y up, +Z south), which is writable.
local function fi_place_at(lat, lon, elev_ft, hdg, pitch, ias, fpm)
    local lat0  = get("sim/flightmodel/position/latitude")
    local lon0  = get("sim/flightmodel/position/longitude")
    local elev0 = get("sim/flightmodel/position/elevation")
    if not lat0 or not lon0 or not elev0 then return false end

    local dn = (lat - lat0) * 111320.0
    local de = (lon - lon0) * 111320.0 * math.cos(math.rad((lat + lat0) / 2))
    set("sim/flightmodel/position/local_x",
        get("sim/flightmodel/position/local_x") + de)
    set("sim/flightmodel/position/local_z",
        get("sim/flightmodel/position/local_z") - dn)
    set("sim/flightmodel/position/local_y",
        get("sim/flightmodel/position/local_y") + (elev_ft * 0.3048 - elev0))

    -- Level the aeroplane and kill any residual rotation before the physics
    -- sees the new position: a leftover spin after a teleport flips the model.
    set("sim/flightmodel/position/psi",   hdg)
    set("sim/flightmodel/position/theta", pitch or 0)
    set("sim/flightmodel/position/phi",   0)
    set("sim/flightmodel/position/P", 0)
    set("sim/flightmodel/position/Q", 0)
    set("sim/flightmodel/position/R", 0)

    local gs = (ias or 0) * 0.514444
    set("sim/flightmodel/position/local_vx",  gs * math.sin(math.rad(hdg)))
    set("sim/flightmodel/position/local_vz", -gs * math.cos(math.rad(hdg)))
    set("sim/flightmodel/position/local_vy",  (fpm or 0) * 0.00508)
    return true
end

local function fi_set_weight(target_lb)
    local target_kg = (target_lb or 0) * 0.45359237
    local total   = fi_weight_kg or 0
    local fuel    = fi_fuel_kg or 0
    local payload = fi_payload_kg or 0
    if total <= 1 or target_kg <= 1 then return false end
    local empty = total - fuel - payload
    if empty <= 1 or empty >= target_kg then return false end

    local fuel_kg = math.min(fuel, target_kg - empty)
    local payload_kg = math.max(0, target_kg - empty - fuel_kg)

    fi_fuel_t0 = fuel_kg * 0.461
    fi_fuel_t1 = fuel_kg * 0.270
    fi_fuel_t2 = fuel_kg * 0.270
    fi_payload_kg = payload_kg
    return true
end

local function fi_apply_place(place)
    local rw = FI_RUNWAYS[place.runway]
    if not rw then return false, "no runway data" end

    local lat0 = get("sim/flightmodel/position/latitude")
    local lon0 = get("sim/flightmodel/position/longitude")
    if not lat0 or not lon0 then return false, "no position" end
    if fi_dist_nm(lat0, lon0, rw.lat, rw.lon) > (FI_CONFIG.setup_max_nm or 40) then
        return false, "load " .. tostring(rw.icao) .. " first"
    end

    local hdg     = rw.hdg
    local lat, lon = rw.lat, rw.lon
    local elev_ft = rw.elev_ft
    local pitch, fpm, ias = 0, 0, 0

    if place.kind == "final" then
        lat, lon = fi_move_latlon(rw.lat, rw.lon, (hdg + 180) % 360,
                                  (place.dist_nm or 10) * 1852)
        elev_ft = rw.elev_ft + (place.dist_nm or 10) * 318.0 + 50
        pitch, fpm, ias = 2.0, -700, place.ias or 140
    elseif place.kind == "runway" then
        lat, lon = fi_move_latlon(rw.lat, rw.lon, hdg, 60)
        -- Park it well above the surface for one frame, then snap it to the
        -- real terrain height (y_agl) on the next frame. Hard-coding the
        -- threshold elevation put the aeroplane 10 ft up at KLAX and it fell
        -- onto the gear.
        elev_ft  = rw.elev_ft + 100
        ias      = 0
        inst_ground_settle = 2
    elseif place.kind == "downwind" then
        -- Start before the threshold in the landing direction, offset left.
        lat, lon = fi_move_latlon(rw.lat, rw.lon, hdg, 1.5 * 1852)
        lat, lon = fi_move_latlon(lat, lon, (hdg - 90) % 360, 1.5 * 1852)
        elev_ft  = rw.elev_ft + (place.alt_ft or 1500)
        hdg      = (hdg + 180) % 360
        ias      = place.ias or 180
    elseif place.kind == "cruise" then
        elev_ft  = place.alt_ft or 35000
        ias      = place.ias or 250
    else
        return false, "unknown setup"
    end

    if place.kind == "cruise" then
        -- Set a ground speed that gives roughly the requested IAS at altitude.
        ias = ias * 1.7
    end

    inst_setup_target = string.format("%.6f,%.6f,%.0f,%.1f", lat, lon, elev_ft, hdg)

    -- Do the move with the sim frozen so one frame cannot integrate the old
    -- attitude/velocity into the new position and tumble the model.
    local was_paused = get("sim/time/paused")
    set("sim/time/paused", 1)

    if not fi_place_at(lat, lon, elev_ft, hdg, pitch, ias, fpm) then
        set("sim/time/paused", was_paused or 0)
        return false, "no position"
    end

    set("sim/cockpit2/controls/gear_handle_down", place.gear or 0)
    -- Force the legs down in the same frame: a runway placement one foot above
    -- the surface with the handle down but the gear still retracting is a
    -- belly landing (and reads as "the plane broke").
    if (place.gear or 0) == 1 then
        for i = 0, 9 do set_array("sim/aircraft/parts/acf_gear_deploy", i, 1) end
    end
    set("sim/cockpit2/controls/flap_handle_request_ratio", place.flap or 0)
    set("sim/cockpit2/controls/speedbrake_ratio", 0)
    set("sim/flightmodel/controls/parkbrake", 0)
    set("sim/cockpit2/engine/actuators/throttle_ratio_all",
        place.throttle or (place.kind == "runway" and 0.0 or 0.60))

    if place.ap then
        command_once("sim/autopilot/servos_on")
    else
        command_once("sim/autopilot/servos_fdir_off")
    end

    if place.nav and rw.nav then
        set("sim/cockpit2/radios/actuators/nav1_frequency_hz", rw.nav)
        command_once("sim/autopilot/hsi_select_nav_1")
    end

    local target_lb = place.weight_lb
        or ((place.kind == "runway") and 24000)
        or ((place.kind == "cruise") and 28000)
        or 26000
    local okw, setw = pcall(fi_set_weight, target_lb)
    inst_setup_weight_lb = (okw and setw) and target_lb or nil

    set("sim/time/paused", was_paused or 0)
    return true
end

-- ---------------------------------------------------------------- LESSONS ---
-- Criteria are checked every frame; they are awarded once held for `hold`
-- seconds (default 0.6). `hint` is the instruction the coach shows next.
-- `arm` decides when grading starts (SET ME UP places the aeroplane, but the
-- pilot may also set the scenario up by hand with Flight Configuration).
local FI_LESSONS = {
    -- ------------------------------------------------------- DEPARTURE ------
    {
        key     = "tkof_clean",
        title   = "NORMAL TAKEOFF & CLEANUP",
        section = "DEPARTURE",
        brief = {
            "Fly a full-length takeoff, rotate at VR,",
            "climb at V2 and clean up on schedule.",
            "Targets come from your actual weight.",
        },
        setup = {
            "Flight Configuration > KLAX > runway 07L.",
            "Day, no wind, weight about 24,000 lb.",
            "Press START, then release the brakes.",
        },
        waiting = "release the brakes and roll",
        detail = {
            "Rotate smoothly at VR - do not yank it off.",
            "V2+10 to 3,000 ft, then clean up and accelerate.",
        },
        place = { runway = "KLAX_07L", kind = "runway", gear = 1, flap = 0.75 },
        arm = function(v, s) return v.on_ground == 1 and v.ias > 20 end,
        criteria = {
            { label = "ROTATE AT VR", hint = "ROTATE AT VR - 10 DEGREES",
              check = function(v, s)
                  return v.agl > 3 and v.pitch > 4.5 and v.ias >= s.vr - 8
              end },
            { label = "POSITIVE RATE - GEAR UP", hint = "GEAR UP",
              check = function(v, s)
                  return v.agl > 150 and v.gear_handle == 0
              end },
            { label = "CLIMB AT V2 + 10", hint = "SET CLIMB ATTITUDE - V2 + 10",
              check = function(v, s)
                  return fi_between(v.agl, 300, 1600)
                     and fi_between(v.ias, s.v2 + 5, s.v2 + 40)
              end },
            { label = "FLAPS UP BY 3,000 FT", hint = "CLEAN UP - FLAPS 5 THEN UP",
              check = function(v, s)
                  return fi_between(v.agl, 2850, 3200)
                     and v.flap < 0.2 and v.ias < 250
              end },
            { label = "250 KIAS CLIMB OUT", hint = "ACCELERATE TO 250 KIAS",
              check = function(v, s)
                  return v.agl > 3500 and fi_between(v.ias, 240, 262)
              end },
        },
        end_when = function(v, s) return v.agl > 6000 or s.elapsed > 180 end,
        readout = function(v, s)
            return string.format("VR %d  V2 %d  |  RA %d  IAS %d",
                s.vr, s.v2, v.agl, v.ias)
        end,
    },
    {
        key     = "rto",
        title   = "REJECTED TAKEOFF",
        section = "DEPARTURE",
        brief = {
            "Roll to 100 KIAS, then reject: throttles idle,",
            "maximum braking, boards out. Stop straight.",
            "Decide once, act once - below V1.",
        },
        setup = {
            "KLAX 25R (long runway), clear weather.",
            "Press START before starting the roll.",
            "V1 is 114-133 KIAS depending on weight.",
        },
        waiting = "start the takeoff roll",
        detail = {
            "Below V1 a stop is cheaper than a fly; above it, fly.",
            "Both feet on the rudder, boards out, do not release.",
        },
        place = { runway = "KLAX_07L", kind = "runway", gear = 1, flap = 0.75 },
        arm = function(v, s) return v.on_ground == 1 and v.ias > 25 end,
        update = function(v, s, dt)
            -- The abort is "seen" the first time power comes off at speed.
            if not s.abort_ias and v.on_ground == 1 and v.ias > 60
               and math.max(v.n1_l or 0, v.n1_r or 0) < 45 then
                s.abort_ias = v.ias
            end
        end,
        criteria = {
            { label = "POWER TO IDLE BY 130", hint = "THROTTLES TO IDLE",
              check = function(v, s)
                  return v.on_ground == 1 and v.ias <= 130
                     and math.max(v.n1_l or 0, v.n1_r or 0) < 45
              end },
            { label = "SPEED DECREASING", hint = "MAX BRAKING - HOLD CENTRELINE",
              check = function(v, s)
                  return s.abort_ias ~= nil and v.ias < s.abort_ias - 10
              end },
            { label = "SPEEDBRAKES OUT", hint = "SPEEDBRAKES FULL OUT",
              check = function(v, s) return v.speedbrake > 0.25 end },
            { label = "STOPPED UNDER 40 S", hint = "STOP THE AEROPLANE",
              check = function(v, s)
                  return v.gs < 2 and s.abort_ias ~= nil and s.elapsed < 40
              end },
        },
        end_when = function(v, s)
            return (s.abort_ias ~= nil and v.gs < 1 and s.elapsed > 3)
                or s.elapsed > 60
        end,
        readout = function(v, s)
            return string.format("IAS %d  GS %d  N1 %.0f  BRKS %.2f",
                v.ias, v.gs, math.max(v.n1_l or 0, v.n1_r or 0), v.speedbrake)
        end,
    },
    {
        key     = "engfail_tkof",
        title   = "ENGINE FAILURE AT 400 FT",
        section = "DEPARTURE",
        brief = {
            "The instructor fails the left engine at 400 ft.",
            "Hold V2, keep the ball centred, gear up, then",
            "flaps up at V2+15, VENR 190, and work the QRH.",
        },
        setup = {
            "KLAX 07L, 24,000 lb, no wind.",
            "Press START, take off normally.",
            "The QRH flameout checklist opens itself.",
        },
        waiting = "start the takeoff roll",
        detail = {
            "Fly the aeroplane first: hold V2, ball centred.",
            "Then gear, flaps at V2+15, VENR 190, and the QRH.",
        },
        place = { runway = "KLAX_07L", kind = "runway", gear = 1, flap = 0.75 },
        arm = function(v, s) return v.on_ground == 1 and v.ias > 20 end,
        update = function(v, s, dt)
            if not s.injected and v.on_ground == 0 and v.agl > 400 then
                s.injected = true
                if type(qrh_inject_by_key) == "function" then
                    qrh_inject_by_key("flameout_l")
                    if type(qrh_toggle_panel) == "function" then qrh_toggle_panel(true) end
                end
                if type(citationx_toast) == "function" then
                    citationx_toast("INSTRUCTOR: L ENGINE FAILED")
                end
            end
        end,
        criteria = {
            { label = "HOLD V2 (NOT BELOW V2 - 5)", hint = "PITCH DOWN - HOLD V2",
              check = function(v, s)
                  return s.injected and v.ias >= s.v2 - 5
              end, hold = 2.0 },
            { label = "WINGS LEVEL +/- 5", hint = "BALL CENTRED - WINGS LEVEL",
              check = function(v, s)
                  return s.injected and fi_abs(v.roll) <= 5
              end, hold = 2.0 },
            { label = "GEAR UP", hint = "GEAR UP",
              check = function(v, s)
                  return s.injected and v.gear_handle == 0
              end },
            { label = "FLAPS UP ABOVE 1,000 FT", hint = "CLEAN UP WHEN ABOVE 1,000 FT",
              check = function(v, s)
                  return s.injected and v.agl > 1000 and v.flap < 0.2
              end },
            { label = "CLIMB AT 190 KIAS (VENR)", hint = "SET 190 KIAS - VENR",
              check = function(v, s)
                  return s.injected and fi_between(v.ias, 180, 205)
              end },
            { label = "QRH PROCEDURE COMPLETE", hint = "WORK THE QRH PANEL",
              check = function(v, s)
                  return type(qrh_is_complete) == "function" and qrh_is_complete()
              end, hold = 0.2 },
        },
        end_when = function(v, s)
            return s.elapsed > 300 or (v.on_ground == 1 and v.gs < 5 and s.elapsed > 30)
        end,
        readout = function(v, s)
            return string.format("VENR 190  |  RA %d  IAS %d  BANK %.0f",
                v.agl, v.ias, v.roll)
        end,
    },

    -- ------------------------------------------------- PATTERN & LANDING ----
    {
        key     = "pattern",
        title   = "VISUAL PATTERN & LANDING",
        section = "PATTERN & LANDING",
        brief = {
            "One closed circuit at 1,500 ft AGL.",
            "Abeam: flaps 15 and gear. Base 160,",
            "final Vref + 5, full flaps, land in the zone.",
        },
        setup = {
            "KLAX 07L, or KSNA 20R if you want a short one.",
            "Start airborne on the downwind at 1,500 ft AGL.",
            "Press START on the downwind leg.",
        },
        waiting = "get airborne on the downwind",
        detail = {
            "Abeam: flaps 15 and gear; base 160; final Vref+5.",
            "If you are not stable at 300 ft, go around.",
        },
        place = { runway = "KLAX_07L", kind = "downwind", alt_ft = 1500, ias = 180,
                  gear = 0, flap = 0 },
        arm = function(v, s)
            return v.on_ground == 0 and v.agl > 500 and v.ias < 250
        end,
        criteria = {
            { label = "DOWNWIND 160-200 KIAS", hint = "DOWNWIND - SLOW TO 180",
              check = function(v, s)
                  return fi_between(v.agl, 1150, 1850) and fi_between(v.ias, 155, 205)
              end },
            { label = "ABEAM: FLAPS 15 + GEAR", hint = "ABEAM - FLAPS 15, GEAR DOWN",
              check = function(v, s)
                  return fi_between(v.agl, 1200, 1800)
                     and v.flap >= 0.65 and v.gear_handle == 1
              end },
            { label = "BASE 145-175 KIAS", hint = "BASE - 160 KIAS",
              check = function(v, s)
                  return fi_abs(v.roll) > 8 and fi_between(v.ias, 145, 175)
              end },
            { label = "FINAL: FULL FLAPS, VREF + 5", hint = "FINAL - FLAPS 35, VREF + 5",
              check = function(v, s)
                  return v.agl < 700 and v.flap > 0.9
                     and fi_between(v.ias, s.vref - 5, s.vref + 15)
              end },
            { label = "STABLE AT 300 FT", hint = "STABLE - SINK 600-800 FPM",
              check = function(v, s)
                  return fi_between(v.agl, 250, 340)
                     and fi_between(v.fpm, -900, -480)
                     and fi_abs(v.roll) <= 8
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 600
        end,
        readout = function(v, s)
            return string.format("VREF %d  |  RA %d  IAS %d  FPM %d  FLAP %s",
                s.vref, v.agl, v.ias, v.fpm, fi_flap_name(v.flap))
        end,
    },
    {
        key     = "visual",
        title   = "VISUAL APPROACH & LANDING",
        section = "PATTERN & LANDING",
        brief = {
            "A straight-in visual from 5 NM, no guidance.",
            "Flaps 15 and gear by 1,000 ft AGL, full",
            "flaps and Vref by 500 ft, land in the zone.",
        },
        setup = {
            "Flight Configuration > KLAX > 10 NM final,",
            "or join downwind and call a 5 NM final.",
            "Day, no wind, then press START.",
        },
        waiting = "roll out on final",
        detail = {
            "No guidance: put the runway on the aim point.",
            "Configured by 1,000 ft, Vref by 500, wings level.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 5, ias = 170,
                  gear = 0, flap = 0.5 },
        arm = function(v, s)
            return v.on_ground == 0 and v.agl > 400 and v.agl < 6000 and v.ias < 250
        end,
        criteria = {
            { label = "CONFIGURED BY 1,000 FT", hint = "FLAPS 15, GEAR DOWN BY 1,000 FT",
              check = function(v, s)
                  return fi_between(v.agl, 900, 1100)
                     and v.flap >= 0.65 and v.gear_handle == 1
              end },
            { label = "FULL FLAPS BY 500 FT", hint = "FULL FLAPS, VREF BY 500 FT",
              check = function(v, s)
                  return fi_between(v.agl, 400, 560) and v.flap > 0.9
              end },
            { label = "VREF + 5 AT 500 FT", hint = "SPEED VREF + 5",
              check = function(v, s)
                  return fi_between(v.agl, 400, 560)
                     and fi_between(v.ias, s.vref, s.vref + 12)
              end },
            { label = "PATH 600-900 FPM", hint = "HOLD A 3 DEGREE PATH",
              check = function(v, s)
                  return fi_between(v.agl, 400, 560)
                     and fi_between(v.fpm, -950, -500)
              end },
            { label = "WINGS LEVEL AT 200 FT", hint = "WINGS LEVEL",
              check = function(v, s)
                  return v.on_ground == 0 and fi_between(v.agl, 140, 220)
                     and fi_abs(v.roll) <= 5
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 480
        end,
        readout = function(v, s)
            return string.format("VREF %d  |  RA %d  IAS %d  FPM %d",
                s.vref, v.agl, v.ias, v.fpm)
        end,
    },
    {
        key     = "crosswind",
        title   = "CROSSWIND LANDING",
        section = "PATTERN & LANDING",
        brief = {
            "Set a 10 kt crosswind (21 is demonstrated).",
            "Crab on final with wings level, then rudder",
            "to align; land in a slight crab, no wing-low.",
        },
        setup = {
            "Weather > custom: surface wind 90 deg to",
            "the runway at 10 kt (e.g. 360/10 for 27).",
            "Fly a normal approach, then press START.",
        },
        waiting = "roll out on final",
        detail = {
            "Crab with wings level; rudder in the flare to align.",
            "Do not use a wing-down sideslip in this wing.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 5, ias = 145,
                  gear = 1, flap = 0.75 },
        arm = function(v, s)
            return v.on_ground == 0 and v.agl > 200 and v.agl < 3000 and v.ias < 220
        end,
        criteria = {
            { label = "CRABBED ON FINAL", hint = "CRAB INTO WIND - TRACK THE CENTRELINE",
              check = function(v, s)
                  local crab = math.abs((v.hpath or 0) - (v.psi or 0))
                  return fi_between(v.agl, 200, 900) and crab >= 3 and crab <= 30
              end },
            { label = "WINGS LEVEL IN THE FLARE", hint = "WINGS LEVEL - RUDDER TO ALIGN",
              check = function(v, s)
                  return v.on_ground == 0 and fi_between(v.agl, 5, 60)
                     and fi_abs(v.roll) <= 5
              end },
            { label = "ALIGNED AT TOUCHDOWN", hint = "STRAIGHTEN BEFORE TOUCHDOWN",
              check = function(v, s)
                  return v.on_ground == 1
                     and math.abs((v.hpath or 0) - (v.psi or 0)) <= 8
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE - DON'T DROP IT IN",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 420
        end,
        readout = function(v, s)
            return string.format("WIND %03.0f/%02.0f  |  RA %d  CRAB %.0f",
                v.wind_dir, v.wind_kts, v.agl,
                math.abs((v.hpath or 0) - (v.psi or 0)))
        end,
    },
    {
        key     = "noflap",
        title   = "FLAPS 15 LANDING (JAM)",
        section = "PATTERN & LANDING",
        brief = {
            "The flap actuator fails: select flaps 15.",
            "Approach at Vref + 15, gear down early,",
            "land long and let it roll.",
        },
        setup = {
            "Set up a 10 NM final at KLAX 25R (long).",
            "Press START - the jam and QRH open together.",
            "Vref + 15 is the target over the fence.",
        },
        waiting = "roll out on final",
        detail = {
            "Flaps 15 per the QRH, not full. Long runway only.",
            "Expect a faster, flatter approach and a long float.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 10, ias = 175,
                  gear = 0, flap = 0.75 },
        arm = function(v, s)
            return v.on_ground == 0 and v.agl > 300 and v.agl < 6000 and v.ias < 240
        end,
        on_start = function(s)
            s.injected = true
            if type(qrh_inject_by_key) == "function" then
                qrh_inject_by_key("flap_actuator")
                if type(qrh_toggle_panel) == "function" then qrh_toggle_panel(true) end
            end
        end,
        criteria = {
            { label = "FLAPS 15 MAXIMUM", hint = "DO NOT EXCEED FLAPS 15",
              check = function(v, s) return v.flap <= 0.8 end },
            { label = "GEAR DOWN BY 1,000 FT", hint = "GEAR DOWN EARLY",
              check = function(v, s)
                  return fi_between(v.agl, 900, 1100) and v.gear_handle == 1
              end },
            { label = "VREF + 10 TO +25 AT 500", hint = "SPEED VREF + 15 - FLAPS 15",
              check = function(v, s)
                  return fi_between(v.agl, 400, 560)
                     and fi_between(v.ias, s.vref + 8, s.vref + 27)
              end },
            { label = "PATH 500-900 FPM", hint = "HOLD THE PATH - LESS FLAP, MORE POWER",
              check = function(v, s)
                  return fi_between(v.agl, 400, 560)
                     and fi_between(v.fpm, -950, -450)
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 480
        end,
        readout = function(v, s)
            return string.format("VREF15 ~%d  |  RA %d  IAS %d  FLAP %s",
                s.vref + 15, v.agl, v.ias, fi_flap_name(v.flap))
        end,
    },

    -- -------------------------------------------------- INSTRUMENT ----------
    {
        key     = "ils",
        title   = "ILS PRECISION APPROACH",
        section = "INSTRUMENT",
        brief = {
            "ILS to KLAX 25L (or 07L) from 10 NM.",
            "Flaps 15 and gear by glidepath capture,",
            "full flaps and Vref by 500 ft, out by 170 ft.",
        },
        setup = {
            "Flight Configuration > KLAX > Approach >",
            "ILS 25L > 10 NM final. The start tunes NAV1.",
            "Arm APPR, then press START.",
        },
        waiting = "capture the localiser",
        detail = {
            "Gear and flaps 15 by capture; full flaps by 500 ft.",
            "Autopilot off by 170 ft - it must be off for landing.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 10, ias = 145,
                  gear = 1, flap = 0.75, nav = true },
        arm = function(v, s)
            return v.on_ground == 0 and fi_between(v.agl, 800, 4500) and v.ias < 260
        end,
        criteria = {
            { label = "LOCALISER +/- 1 DOT AT 500", hint = "TRACK THE LOCALISER",
              check = function(v, s)
                  return v.nav1_h == 1
                     and fi_between(v.agl, 420, 540) and fi_abs(v.hdef) <= 1.0
              end },
            { label = "GLIDESLOPE +/- 1 DOT AT 500", hint = "TRACK THE GLIDESLOPE",
              check = function(v, s)
                  return v.nav1_v == 1
                     and fi_between(v.agl, 420, 540) and fi_abs(v.vdef) <= 1.0
              end },
            { label = "GEAR + FULL FLAPS BY 1,000", hint = "GEAR DOWN, FULL FLAPS",
              check = function(v, s)
                  return fi_between(v.agl, 900, 1100)
                     and v.gear_handle == 1 and v.flap > 0.9
              end },
            { label = "VREF TO VREF + 10 AT 500", hint = "SET VREF - SPEED IS LIFE",
              check = function(v, s)
                  return fi_between(v.agl, 420, 540)
                     and fi_between(v.ias, s.vref - 3, s.vref + 12)
              end },
            { label = "SINK 600-900 FPM AT 500", hint = "HOLD THE GLIDESLOPE",
              check = function(v, s)
                  return fi_between(v.agl, 420, 540)
                     and fi_between(v.fpm, -950, -500)
              end },
            { label = "AUTOPILOT OFF BELOW 170", hint = "DISCONNECT BY 170 FT",
              check = function(v, s)
                  return v.agl < 175 and v.agl > 60 and (v.ap_on or 0) == 0
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 480
        end,
        readout = function(v, s)
            return string.format("VREF %d  |  LOC %+.1f  GS %+.1f  RA %d  IAS %d",
                s.vref, v.hdef or 0, v.vdef or 0, v.agl, v.ias)
        end,
    },
    {
        key     = "rnav",
        title   = "RNAV / NON-PRECISION APPROACH",
        section = "INSTRUMENT",
        brief = {
            "RNAV (RNP) 27 into KSAN, or any LNAV approach.",
            "No glideslope to save you: fly the 3 degree",
            "path with the sink rate, respect the steps.",
        },
        setup = {
            "Flight Configuration > KSAN > Approach >",
            "RNAV 27 > 10 NM final, or any LNAV approach.",
            "Press START once established inbound.",
        },
        waiting = "establish inbound on the final approach course",
        detail = {
            "No glideslope: 318 ft per NM is your vertical path.",
            "Match sink to ground speed, not to the altimeter.",
        },
        place = { runway = "KSAN_27", kind = "final", dist_nm = 10, ias = 145,
                  gear = 1, flap = 0.75 },
        arm = function(v, s)
            return v.on_ground == 0 and fi_between(v.agl, 500, 6000) and v.ias < 260
        end,
        criteria = {
            { label = "LATERAL +/- 0.5 DOT", hint = "TRACK THE COURSE - HALF DOT",
              check = function(v, s) return fi_abs(v.hdef) <= 0.5 end, hold = 3.0 },
            { label = "3 DEG PATH +/- 200 FPM", hint = "MATCH SINK TO GROUND SPEED",
              check = function(v, s)
                  return fi_between(v.agl, 300, 2500)
                     and math.abs((v.fpm or 0) + fi_path_fpm(v.gs)) <= 200
              end, hold = 1.5 },
            { label = "GEAR + FULL FLAPS BY 1,000", hint = "CONFIGURE EARLY",
              check = function(v, s)
                  return fi_between(v.agl, 900, 1100)
                     and v.gear_handle == 1 and v.flap > 0.9
              end },
            { label = "VREF TO VREF + 10 AT 500", hint = "SET VREF BY 500 FT",
              check = function(v, s)
                  return fi_between(v.agl, 420, 560)
                     and fi_between(v.ias, s.vref - 3, s.vref + 12)
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 480
        end,
        readout = function(v, s)
            return string.format("VREF %d  |  DEV %+.1f  RA %d  IAS %d",
                s.vref, v.hdef or 0, v.agl, v.ias)
        end,
    },
    {
        key     = "se_ils",
        title   = "SINGLE-ENGINE ILS",
        section = "INSTRUMENT",
        brief = {
            "One engine fails at 3,000 ft on the approach.",
            "Fly it flaps 15 at Vref(15) + 10, trim out,",
            "hold the ball, no go-around unless it drifts.",
        },
        setup = {
            "Start on the ILS at 10 NM (KLAX 25L).",
            "Press START - the left engine fails once",
            "you are inside 3,000 ft AGL.",
        },
        waiting = "capture the localiser",
        detail = {
            "Flaps 15, Vref(15)+10 minimum, trim it out.",
            "Wings level; the missed approach is always available.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 10, ias = 155,
                  gear = 1, flap = 0.75, nav = true },
        arm = function(v, s)
            return v.on_ground == 0 and fi_between(v.agl, 800, 4500) and v.ias < 260
        end,
        update = function(v, s, dt)
            if not s.injected and v.agl < 3000 then
                s.injected = true
                if type(qrh_inject_by_key) == "function" then
                    qrh_inject_by_key("flameout_l")
                    if type(qrh_toggle_panel) == "function" then qrh_toggle_panel(true) end
                end
                if type(citationx_toast) == "function" then
                    citationx_toast("INSTRUCTOR: L ENGINE FAILED")
                end
            end
        end,
        criteria = {
            { label = "LOCALISER +/- 1 DOT AT 500", hint = "TRACK THE LOCALISER",
              check = function(v, s)
                  return v.nav1_h == 1
                     and fi_between(v.agl, 420, 540) and fi_abs(v.hdef) <= 1.0
              end },
            { label = "GLIDESLOPE +/- 1 DOT AT 500", hint = "TRACK THE GLIDESLOPE",
              check = function(v, s)
                  return v.nav1_v == 1
                     and fi_between(v.agl, 420, 540) and fi_abs(v.vdef) <= 1.0
              end },
            { label = "VREF(15) + 10 MIN AT 500", hint = "SPEED VREF(15) + 10 - ONE ENGINE",
              check = function(v, s)
                  return fi_between(v.agl, 420, 540)
                     and fi_between(v.ias, s.vref + 10, s.vref + 45)
              end },
            { label = "GEAR + FLAPS 15 BY 1,000", hint = "FLAPS 15 MAX - GEAR DOWN",
              check = function(v, s)
                  return fi_between(v.agl, 900, 1100)
                     and v.gear_handle == 1 and fi_between(v.flap, 0.6, 0.85)
              end },
            { label = "WINGS LEVEL +/- 5 AT 300", hint = "TRIM IT OUT - WINGS LEVEL",
              check = function(v, s)
                  return fi_between(v.agl, 250, 340) and fi_abs(v.roll) <= 5
              end },
            { label = "TOUCHDOWN UNDER 600 FPM", hint = "FLARE AND HOLD IT OFF",
              check = function(v, s) return v.td_fpm ~= nil and v.td_fpm > -600 end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (v.td_fpm ~= nil and v.gs < 45) or s.elapsed > 480
        end,
        readout = function(v, s)
            return string.format("MIN %d  IAS %d  RA %d  |  LOC %+.1f  GS %+.1f",
                s.vref + 10, v.ias, v.agl, v.hdef or 0, v.vdef or 0)
        end,
    },
    {
        key     = "goaround",
        title   = "GO-AROUND / MISSED APPROACH",
        section = "INSTRUMENT",
        brief = {
            "Fly the approach to 300 ft, then break it off.",
            "TO/GA, rotate to +7.5, positive rate, gear up,",
            "flaps 15, climb to 3,000 ft and level.",
        },
        setup = {
            "Any ILS or visual, 3 NM final, configured.",
            "Press START at about 500 ft and keep coming.",
            "Go around at 300 ft - do not land.",
        },
        waiting = "descend through 500 ft, configured",
        detail = {
            "TO/GA, rotate to +7.5, positive rate, gear up.",
            "Flaps 15, climb at Vapp, level at 3,000 ft.",
        },
        place = { runway = "KLAX_25L", kind = "final", dist_nm = 3, ias = 130,
                  gear = 1, flap = 1.0, nav = true },
        arm = function(v, s)
            return v.on_ground == 0 and fi_between(v.agl, 30, 500)
                and v.flap > 0.85 and v.gear_handle == 1
        end,
        criteria = {
            { label = "POWER TO TO/MCT", hint = "TO/GA - POWER UP",
              check = function(v, s)
                  return math.max(v.n1_l or 0, v.n1_r or 0) >= 80
              end },
            { label = "ROTATE TO +7.5 DEGREES", hint = "ROTATE TO +7.5 DEGREES",
              check = function(v, s) return v.pitch >= 6.5 end },
            { label = "POSITIVE RATE", hint = "CHECK POSITIVE RATE",
              check = function(v, s) return v.fpm > 300 end },
            { label = "GEAR UP", hint = "GEAR UP",
              check = function(v, s) return v.gear_handle == 0 end },
            { label = "FLAPS 15 OR LESS", hint = "FLAPS 15",
              check = function(v, s) return v.flap <= 0.8 end },
            { label = "LEVEL AT 3,000 FT", hint = "LEVEL OFF AT 3,000 FT",
              check = function(v, s)
                  return fi_between(v.agl, 2700, 3400) and math.abs(v.fpm) < 450
              end },
        },
        end_when = function(v, s)
            return (fi_between(v.agl, 2700, 3400) and math.abs(v.fpm) < 450
                    and s.met[6])
                or s.elapsed > 300
        end,
        readout = function(v, s)
            return string.format("RA %d  IAS %d  PITCH %.0f  FPM %d",
                v.agl, v.ias, v.pitch, v.fpm)
        end,
    },

    -- --------------------------------------------------- EMERGENCY ----------
    {
        key     = "decompression",
        title   = "EMERGENCY DESCENT",
        section = "EMERGENCY",
        brief = {
            "Cabin altitude is climbing at FL350.",
            "Masks on, AP off, idle, boards out,",
            "15 deg bank, 4,000+ fpm, level at 10,000.",
        },
        setup = {
            "Start in cruise at FL350 (or climb there),",
            "then press START - the QRH decompression",
            "checklist opens once above 20,000 ft.",
        },
        waiting = "get airborne above 20,000 ft",
        detail = {
            "Masks, AP off, idle, boards out, 15 deg bank.",
            "4,000 fpm to 10,000 ft, then work the QRH.",
        },
        place = { runway = "KLAX_25L", kind = "cruise", alt_ft = 35000, ias = 250,
                  gear = 0, flap = 0, ap = true },
        arm = function(v, s)
            return v.on_ground == 0 and v.elev_ft > 20000
        end,
        update = function(v, s, dt)
            if not s.injected then
                s.injected = true
                if type(qrh_inject_by_key) == "function" then
                    qrh_inject_by_key("cabin_decompression")
                    if type(qrh_toggle_panel) == "function" then qrh_toggle_panel(true) end
                end
            end
        end,
        criteria = {
            { label = "AUTOPILOT OFF", hint = "DISCONNECT THE AUTOPILOT",
              check = function(v, s) return (v.ap_on or 0) == 0 end, hold = 0.5 },
            { label = "THRUST IDLE", hint = "THROTTLES TO IDLE",
              check = function(v, s)
                  return math.max(v.n1_l or 0, v.n1_r or 0) < 45
              end },
            { label = "SPEEDBRAKES OUT", hint = "SPEEDBRAKES FULL OUT",
              check = function(v, s) return v.speedbrake > 0.4 end },
            { label = "DESCENT 4,000+ FPM", hint = "DESCEND - 4,000 FPM OR MORE",
              check = function(v, s) return v.fpm < -4000 end, hold = 1.5 },
            { label = "LEVEL AT 10,000 FT", hint = "LEVEL AT 10,000 FT",
              check = function(v, s)
                  return fi_between(v.elev_ft, 9500, 10500)
                     and math.abs(v.fpm) < 500
              end },
            { label = "QRH PROCEDURE COMPLETE", hint = "WORK THE QRH PANEL",
              check = function(v, s)
                  return type(qrh_is_complete) == "function" and qrh_is_complete()
              end, hold = 0.2 },
        },
        end_when = function(v, s)
            return (s.met[5] and s.met[6]) or s.elapsed > 600
        end,
        readout = function(v, s)
            return string.format("ALT %d  FPM %d  IAS %d",
                v.elev_ft, v.fpm, v.ias)
        end,
    },
}

-- ---------------------------------------------------------------- STATE -----
local inst_state     = FI_STATE.MENU
local inst_lesson    = nil       -- lesson table being briefed/flown
local inst_rows      = {}        -- clickable rects, rebuilt each draw
local inst_header_rect = nil
local inst_footer_rect = nil
local inst_drag      = { active = false, dx = 0, dy = 0 }
local inst_toast_text = nil
local inst_toast_until = 0
local inst_is_c750   = (PLANE_ICAO == "C750")   -- refreshed every frame
local inst_scroll    = 0         -- menu scroll offset (whole rows)
local inst_setup_msg = "NOT RUN" -- last SET ME UP result, shown in the brief

-- Per-lesson run state.
local S = {}

local function fi_reset_run(lesson, weight_lb)
    S = {
        armed    = false,
        t0       = 0,
        elapsed  = 0,
        met      = {},
        hold     = {},
        td_fpm   = nil,
        td_ias   = nil,
        injected = false,
        abort_ias = nil,
        was_ground = false,
    }
    local wt = weight_lb or ((fi_weight_kg or 0) * 2.20462)
    if wt < 15000 then wt = 24000 end   -- cold-and-dark default before load
    S.weight_lb = wt
    S.vref = math.floor(fi_vref_lb(wt) + 0.5)
    local v1, vr, v2 = fi_tko_speeds(wt)
    S.v1, S.vr, S.v2 = v1, vr, v2
    if lesson and lesson.key == "crosswind" then S.vref = S.vref + 5 end
end

local function fi_now()
    return fi_time or 0
end

local function fi_toast(text)
    inst_toast_text  = text
    inst_toast_until = fi_now() + 2.5
end

-- -------------------------------------------------------------- PROGRESS ----
local inst_progress = {}   -- key -> best percent (0..100)

local function fi_progress_path()
    if SCRIPT_DIRECTORY and SCRIPT_DIRECTORY ~= "" then
        return SCRIPT_DIRECTORY .. "CitationX_TrainingProgress.txt"
    end
    return "CitationX_TrainingProgress.txt"
end

local function fi_load_progress()
    local fh = io.open(fi_progress_path(), "r")
    if not fh then return end
    for line in fh:lines() do
        local k, v = line:match("^([%w_]+)=(%d+)")
        if k and v then inst_progress[k] = tonumber(v) end
    end
    fh:close()
end

function fi_save_progress()
    local fh = io.open(fi_progress_path(), "w")
    if not fh then return end
    for _, lesson in ipairs(FI_LESSONS) do
        local best = inst_progress[lesson.key]
        if best then fh:write(lesson.key .. "=" .. tostring(best) .. "\n") end
    end
    fh:close()
end

-- ------------------------------------------------------------ LIFECYCLE -----
local function fi_total_criteria(lesson)
    return #lesson.criteria
end

local function fi_score_percent()
    if not inst_lesson then return 0 end
    local n, got = 0, 0
    for i = 1, #inst_lesson.criteria do
        local c = inst_lesson.criteria[i]
        if not c.optional then
            n = n + 1
            if S.met[i] then got = got + 1 end
        end
    end
    if n == 0 then return 0 end
    return math.floor(got * 100 / n + 0.5)
end

local function fi_grade_letter(pct)
    if pct >= 100 then return "A" end
    if pct >= 85 then return "B+" end
    if pct >= 70 then return "B" end
    if pct >= 60 then return "C" end
    if pct > 0 then return "D" end
    return "F"
end

local function fi_lesson_by_key(key)
    for _, lesson in ipairs(FI_LESSONS) do
        if lesson.key == key then return lesson end
    end
end

local function fi_clear_own_failure()
    if S.injected and type(qrh_clear) == "function" then qrh_clear() end
    S.injected = false
end

function fi_start(key, weight_lb)
    local lesson = fi_lesson_by_key(key)
    if not lesson then return end
    if FI_CONFIG.require_c750 and not inst_is_c750 then
        fi_toast("FLIGHT INSTRUCTOR: C750 ONLY")
        return
    end
    fi_clear_own_failure()
    inst_lesson = lesson
    fi_reset_run(lesson, weight_lb)
    inst_state = FI_STATE.FLYING
    if lesson.on_start then pcall(lesson.on_start, S) end
    fi_toast("LESSON START: " .. lesson.title)
    logMsg("Citation X Instructor: started " .. lesson.key)
end

-- Place and configure the aeroplane, then start the lesson. Refuses when the
-- lesson has no preset or when the aircraft is not near the field.
function fi_setup(key)
    local lesson = fi_lesson_by_key(key) or inst_lesson
    if not lesson or not lesson.place then
        fi_toast("NO AUTO SETUP FOR THIS LESSON")
        return false
    end
    if FI_CONFIG.require_c750 and not inst_is_c750 then
        fi_toast("FLIGHT INSTRUCTOR: C750 ONLY")
        return false
    end
    local ran, placed, why = pcall(fi_apply_place, lesson.place)
    if not ran then
        inst_setup_msg = "FAILED - internal error"
        fi_toast("SETUP: INTERNAL ERROR")
        return false
    end
    if not placed then
        inst_setup_msg = "FAILED - " .. tostring(why)
        fi_toast("SETUP: " .. tostring(why))
        return false
    end
    fi_start(lesson.key, inst_setup_weight_lb)
    inst_setup_msg = "PLACED - " .. tostring(lesson.place.runway)
    fi_toast("SETUP: " .. lesson.title)
    return true
end

function fi_brief(key)
    local lesson = fi_lesson_by_key(key)
    if not lesson then return end
    inst_lesson = lesson
    fi_reset_run(lesson)
    inst_state = FI_STATE.BRIEF
    inst_setup_msg = "NOT RUN"
    inst_setup_target = ""
    inst_setup_weight_lb = nil
end

function fi_finish(quiet)
    if inst_state ~= FI_STATE.FLYING or not inst_lesson then return end
    inst_state = FI_STATE.DEBRIEF
    local pct = fi_score_percent()
    local best = inst_progress[inst_lesson.key] or 0
    if pct > best then
        inst_progress[inst_lesson.key] = pct
        fi_save_progress()
    end
    if not quiet then
        logMsg(string.format("Citation X Instructor: %s scored %d%% (%s)",
            inst_lesson.key, pct, fi_grade_letter(pct)))
    end
end

function fi_retry()
    if not inst_lesson then return end
    local key = inst_lesson.key
    fi_clear_own_failure()
    fi_start(key)
end

function fi_next()
    if not inst_lesson then return end
    local idx = 1
    for i, lesson in ipairs(FI_LESSONS) do
        if lesson.key == inst_lesson.key then idx = i break end
    end
    local next_lesson = FI_LESSONS[idx + 1]
    if next_lesson then
        fi_start(next_lesson.key)
    else
        fi_toast("THAT WAS THE LAST LESSON")
    end
end

function fi_menu()
    fi_clear_own_failure()
    inst_state = FI_STATE.MENU
    inst_lesson = nil
    fi_reset_run(nil)
end

function fi_toggle_panel(on)
    if on == nil then
        FI_CONFIG.panel_enabled = not FI_CONFIG.panel_enabled
    else
        FI_CONFIG.panel_enabled = (on == true)
    end
    if not FI_CONFIG.panel_enabled then
        inst_drag.active = false
        -- Hiding the panel abandons the run: the frame loop must not keep
        -- grading (or keep a lesson's failure injected) behind a hidden panel.
        if inst_state == FI_STATE.FLYING or inst_state == FI_STATE.BRIEF then
            fi_menu()
        end
    else
        -- Opening the panel always shows the lesson list.
        inst_state = FI_STATE.MENU
    end
    fi_toast("FLIGHT INSTRUCTOR: " .. (FI_CONFIG.panel_enabled and "ON" or "OFF"))
end

function fi_reset_progress()
    inst_progress = {}
    fi_save_progress()
    fi_toast("TRAINING PROGRESS CLEARED")
end

-- Read-only views for the offline harnesses.
function fi_lessons()
    return FI_LESSONS
end

function fi_section_list()
    local out, seen = {}, {}
    for _, lesson in ipairs(FI_LESSONS) do
        if not seen[lesson.section] then
            seen[lesson.section] = true
            out[#out + 1] = lesson.section
        end
    end
    return out
end

function fi_state()
    return inst_state, inst_lesson and inst_lesson.key or nil, fi_score_percent()
end

-- Read-only views for the watcher: what SET ME UP reported and where it aimed.
function fi_setup_status()
    return inst_setup_msg
end

function fi_setup_target()
    return inst_setup_target
end

function fi_run_weight()
    return S.weight_lb
end

function fi_run_met()
    local out = {}
    for i = 1, #inst_lesson.criteria do out[i] = S.met[i] and true or false end
    return out
end

function fi_best(key)
    return inst_progress[key] or 0
end

-- ------------------------------------------------------------- FRAME LOOP ---
-- Read-only view of the aeroplane, keyed the way the criteria expect. Exposed
-- so the offline harness can grade a cold airframe without a frame loop.
function fi_snapshot()
    local v = {
        ias        = fi_ias or 0,
        -- sim/flightmodel/position/groundspeed is metres per second; every
        -- criterion and readout above is in knots.
        gs         = (fi_gs or 0) * 1.94384,
        fpm        = fi_fpm or 0,
        agl        = (fi_agl_m or 0) * 3.28084,
        elev_ft    = (fi_elev_m or 0) * 3.28084,
        hdg        = fi_mag_psi or 0,
        psi        = fi_psi or 0,
        hpath      = fi_hpath or 0,
        pitch      = fi_pitch or 0,
        roll       = fi_roll or 0,
        g          = fi_g or 1,
        on_ground  = fi_on_ground or 0,
        ra         = fi_ra or 0,
        gear_handle = fi_gear or 0,
        flap       = fi_flap or 0,
        flap_handle = fi_flap_handle or 0,
        speedbrake = fi_brake or 0,
        n1_l       = fi_n1_l or 0,
        n1_r       = fi_n1_r or 0,
        ap_on      = fi_ap_on or 0,
        ap_appr    = fi_ap_appr or 0,
        stall      = fi_stall or 0,
        gear_unsafe = fi_gear_unsafe or 0,
        reverser   = fi_reverser or 0,
        hdef       = fi_hdef or 0,
        vdef       = fi_vdef or 0,
        dme        = fi_dme or 0,
        xtk        = fi_gps_xtk or 0,
        nav1_h     = fi_nav1_h or 0,
        nav1_v     = fi_nav1_v or 0,
        wind_kts   = fi_wind_kts or 0,
        wind_dir   = fi_wind_dir or 0,
        td_fpm     = S.td_fpm,
    }
    if v.agl < 0 then v.agl = 0 end
    return v
end

function fi_frame()
    inst_is_c750 = (PLANE_ICAO == "C750")
    local now = fi_now()
    local dt  = now - (S.last_time or now)
    if dt < 0 or dt > 1.0 then dt = 0 end
    S.last_time = now

    if inst_state ~= FI_STATE.FLYING or not inst_lesson then return end

    local V = fi_snapshot()

    -- Runway placements: one frame after the move, snap the aeroplane down by
    -- its actual height above the terrain, so it starts on the wheels instead
    -- of falling the last few feet and breaking.
    if inst_ground_settle > 0 then
        inst_ground_settle = inst_ground_settle - 1
        if inst_ground_settle == 0 and (V.agl or 0) > 0.2 then
            set("sim/flightmodel/position/local_y",
                get("sim/flightmodel/position/local_y") - V.agl * 0.3048)
            set("sim/flightmodel/position/local_vx", 0)
            set("sim/flightmodel/position/local_vy", 0)
            set("sim/flightmodel/position/local_vz", 0)
        end
    end

    -- Track the touchdown so every landing lesson can grade the same way.
    if V.on_ground == 1 and not S.was_ground and S.armed then
        S.td_fpm = V.fpm
        S.td_ias = V.ias
    end
    S.was_ground = (V.on_ground == 1)

    if not S.armed then
        local ok, armed = pcall(inst_lesson.arm or function() return true end, V, S)
        if ok and armed then
            S.armed = true
            S.t0 = now
        end
    end

    if S.armed then
        S.elapsed = now - S.t0
        if inst_lesson.update then pcall(inst_lesson.update, V, S, dt) end

        for i, c in ipairs(inst_lesson.criteria) do
            if not S.met[i] then
                local ok, res = pcall(c.check, V, S)
                if ok and res then
                    S.hold[i] = (S.hold[i] or 0) + dt
                    if S.hold[i] >= (c.hold or 0.6) then S.met[i] = true end
                else
                    S.hold[i] = 0
                end
            end
        end

        local done = false
        if inst_lesson.end_when then
            local ok, res = pcall(inst_lesson.end_when, V, S)
            done = ok and res or false
        end
        if done then fi_finish() end
    end
end

-- -------------------------------------------------------------- DRAWING -----
local function bar(x, y0, y1, w, col, alpha)
    cx_bar_w(x, y0, y1, w, col, alpha)
end

local function txt(x, y, text, size, col)
    cx_text(x, y, text, size or 12, col)
end

local function txt_right(right_x, y, text, size, col)
    cx_text_right(right_x, y, text, size or 12, col)
end

-- Panel height for the current screen, so the shell never clips.
local function fi_menu_rows()
    local rows = {}
    for _, section in ipairs(fi_section_list()) do
        rows[#rows + 1] = { kind = "section", label = section }
        for _, lesson in ipairs(FI_LESSONS) do
            if lesson.section == section then
                rows[#rows + 1] = { kind = "lesson", lesson = lesson }
            end
        end
    end
    rows[#rows + 1] = { kind = "reset", label = "RESET PROGRESS" }
    return rows
end

-- Height of the panel in its current state; also used by the geometry harness.
function fi_panel_height()
    local cfg = FI_CONFIG
    if inst_state == FI_STATE.MENU then
        return cfg.header_h + 14 + 18 + #fi_menu_rows() * cfg.row_h + 14
             + cfg.footer_h + 8
    elseif inst_state == FI_STATE.BRIEF then
        local lesson = inst_lesson
        if not lesson then return 200 end
        return cfg.header_h + 18
             + #lesson.brief * 15 + 8
             + 14
             + 15 + #lesson.setup * 15 + 10
             + 15 + #lesson.criteria * 15 + 10
             + 16 + #(lesson.detail or {}) * 14 + 10
             + 14
             + 26 + 10 + cfg.footer_h + 8
    elseif inst_state == FI_STATE.FLYING then
        local lesson = inst_lesson
        if not lesson then return 200 end
        return cfg.header_h + 22 + 18 + 16 + 8
             + #lesson.criteria * cfg.row_h + 10
             + 26 + 10 + cfg.footer_h + 8
    else
        local lesson = inst_lesson
        if not lesson then return 200 end
        return cfg.header_h + 40 + 16 + 18
             + #lesson.criteria * 18 + 12
             + 26 + 10 + cfg.footer_h + 8
    end
end

local function fi_button(x, y, w, label, col, fg)
    bar(x, y - 22, y, w, col)
    local tw = cx_measure(label, 12)
    txt(math.floor(x + (w - tw) / 2 + 0.5), y - 16, label, 12, fg or CX.footer_fg)
    return { x0 = x, x1 = x + w, y0 = y - 22, y1 = y }
end

local function fi_draw_menu(cfg, st, x, top, w)
    local rows = fi_menu_rows()
    local y = top - cfg.header_h - 14

    local sum, flown = 0, 0
    for _, lesson in ipairs(FI_LESSONS) do
        local b = inst_progress[lesson.key]
        if b then sum = sum + b flown = flown + 1 end
    end
    local avg = flown > 0 and math.floor(sum / flown + 0.5) or 0
    txt(x + cfg.pad, y - 13, string.format(
        "AVERAGE %d%%   %d OF %d FLOWN", avg, flown, #FI_LESSONS), 10, st.sub)
    bar(x + cfg.pad, y - 17, y - 16, w - 2 * cfg.pad, st.hairline, 0.5)
    y = y - 18

    for _, row in ipairs(rows) do
        if row.kind == "section" then
            txt(x + cfg.pad, y - 13, row.label, 10, st.sub)
            bar(x + cfg.pad, y - 17, y - 16, w - 2 * cfg.pad, st.hairline, 0.5)
        elseif row.kind == "lesson" then
            local best = inst_progress[row.lesson.key]
            txt(x + cfg.pad, y - 14,
                cx_fit(row.lesson.title, w - 2 * cfg.pad - 54, 12), 12, st.value)
            if best then
                txt_right(x + w - cfg.pad, y - 14,
                    string.format("%d%%", best), 12, best >= 70 and st.ok or st.warn)
            else
                txt_right(x + w - cfg.pad, y - 14, "NEW", 10, st.dim)
            end
            inst_rows[#inst_rows + 1] = {
                kind = "lesson", key = row.lesson.key,
                x0 = x, x1 = x + w, y0 = y - 18, y1 = y + 2,
            }
        else
            txt(x + cfg.pad, y - 14, row.label, 12, st.bad)
            inst_rows[#inst_rows + 1] = {
                kind = "reset", x0 = x, x1 = x + w, y0 = y - 18, y1 = y + 2,
            }
        end
        y = y - cfg.row_h
    end
end

local function fi_draw_brief(cfg, st, x, top, w, lesson)
    local y = top - cfg.header_h - 16

    for _, line in ipairs(lesson.brief) do
        txt(x + cfg.pad, y, cx_fit(line, w - 2 * cfg.pad, 12), 12, st.value)
        y = y - 15
    end
    y = y - 8

    -- What the aeroplane actually weighs and the speeds that follow from it.
    txt(x + cfg.pad, y, cx_fit(string.format(
        "GW %d LB   VREF %d   VR %d   V2 %d",
        math.floor((S.weight_lb or 0) + 0.5),
        math.floor((S.vref or 0) + 0.5),
        math.floor((S.vr or 0) + 0.5),
        math.floor((S.v2 or 0) + 0.5)), w - 2 * cfg.pad, 10), 10, st.sub)
    y = y - 14

    txt(x + cfg.pad, y, "SETUP", 10, st.sub)
    y = y - 15
    for _, line in ipairs(lesson.setup) do
        txt(x + cfg.pad, y, cx_fit(line, w - 2 * cfg.pad, 12), 12, st.label)
        y = y - 15
    end
    y = y - 8

    txt(x + cfg.pad, y, "GRADED ITEMS", 10, st.sub)
    y = y - 15
    for i, c in ipairs(lesson.criteria) do
        txt(x + cfg.pad, y, string.format("%d.", i), 12, st.dim)
        txt(x + cfg.pad + 16, y, cx_fit(c.label, w - 2 * cfg.pad - 16, 12), 12, st.value)
        y = y - 15
    end
    y = y - 8

    txt(x + cfg.pad, y, "TECHNIQUE", 10, st.sub)
    y = y - 15
    for _, line in ipairs(lesson.detail or {}) do
        txt(x + cfg.pad, y, cx_fit(line, w - 2 * cfg.pad, 12), 12, st.dim)
        y = y - 14
    end
    y = y - 8

    local setup_col = st.warn
    if inst_setup_msg:find("^PLACED") then setup_col = st.ok end
    if inst_setup_msg:find("^FAILED") then setup_col = st.bad end
    txt(x + cfg.pad, y, cx_fit("SETUP: " .. inst_setup_msg,
        w - 2 * cfg.pad, 10), 10, setup_col)
    y = y - 10

    local bw = (w - 2 * cfg.pad - 20) / 3
    inst_rows[#inst_rows + 1] = { kind = "setup",
        rect = fi_button(x + cfg.pad, y, bw, "SET ME UP", st.ok) }
    inst_rows[#inst_rows + 1] = { kind = "start",
        rect = fi_button(x + cfg.pad + bw + 10, y, bw, "START", st.btn, st.value) }
    inst_rows[#inst_rows + 1] = { kind = "back",
        rect = fi_button(x + cfg.pad + 2 * bw + 20, y, bw, "BACK", st.btn, st.value) }
end

local function fi_coach_text(lesson)
    local unmet = {}
    for i, c in ipairs(lesson.criteria) do
        if not S.met[i] then unmet[#unmet + 1] = c end
    end
    if #unmet == 0 then return "ALL ITEMS MET - FINISH TO GRADE", CX.ok end
    return "NEXT: " .. unmet[1].hint, CX.warn
end

local function fi_draw_flying(cfg, st, x, top, w, lesson)
    local y = top - cfg.header_h - 16
    local V = fi_snapshot()

    if not S.armed then
        txt(x + cfg.pad, y, "ARMED - " .. (lesson.waiting or "fly the setup"),
            12, st.warn)
        y = y - 22
    else
        local text, col = fi_coach_text(lesson)
        txt(x + cfg.pad, y, cx_fit(text, w - 2 * cfg.pad, 12), 12, col)
        y = y - 18
        local readout = lesson.readout and lesson.readout(V, S) or ""
        txt(x + cfg.pad, y, cx_fit(readout, w - 2 * cfg.pad, 10), 10, st.sub)
        y = y - 16
    end

    local met = 0
    for i = 1, #lesson.criteria do if S.met[i] then met = met + 1 end end
    txt(x + cfg.pad, y, cx_fit(string.format(
        "GW %d  GEAR %s  FLAP %s  AP %s  NAV %s  |  %d/%d",
        math.floor((S.weight_lb or 0) + 0.5),
        (V.gear_handle == 1) and "DN" or "UP",
        fi_flap_name(V.flap),
        (V.ap_on == 1) and "ON" or "OFF",
        (V.nav1_h == 1) and "SIG" or "---",
        met, #lesson.criteria), w - 2 * cfg.pad, 10), 10, st.dim)
    y = y - 16

    for i, c in ipairs(lesson.criteria) do
        local done = S.met[i]
        txt(x + cfg.pad - 2, y, done and "X" or "-", 12, done and st.ok or st.dim)
        txt(x + cfg.pad + 14, y,
            cx_fit(c.label, w - 2 * cfg.pad - 14, 12), 12,
            done and st.ok or st.label)
        y = y - cfg.row_h
    end

    y = y - 10
    local bw = (w - 2 * cfg.pad - 10) / 2
    inst_rows[#inst_rows + 1] = { kind = "finish",
        rect = fi_button(x + cfg.pad, y, bw, "FINISH & GRADE", st.warn) }
    inst_rows[#inst_rows + 1] = { kind = "abort",
        rect = fi_button(x + cfg.pad + bw + 10, y, bw, "ABORT", st.btn, st.value) }
end

local function fi_draw_debrief(cfg, st, x, top, w, lesson)
    local pct = fi_score_percent()
    local letter = fi_grade_letter(pct)
    local y = top - cfg.header_h - 30

    txt(x + cfg.pad, y, "GRADE", 10, st.sub)
    txt_right(x + w - cfg.pad, y, string.format("%d%%", pct), 10, st.sub)
    y = y - 24
    local col = pct >= 70 and st.ok or (pct >= 50 and st.warn or st.bad)
    txt(x + cfg.pad, y, letter, 18, col)
    local got, total = 0, 0
    for i = 1, #lesson.criteria do
        total = total + 1
        if S.met[i] then got = got + 1 end
    end
    txt(x + cfg.pad + 34, y, string.format("%d OF %d ITEMS", got, total), 12, st.dim)
    y = y - 18
    local best = inst_progress[lesson.key] or 0
    txt(x + cfg.pad, y, string.format("BEST %d%%%s", best,
        (pct >= best) and "  NEW BEST" or ""), 10, st.dim)
    y = y - 18

    for i, c in ipairs(lesson.criteria) do
        local done = S.met[i]
        txt(x + cfg.pad, y, done and "PASS" or "MISS", 10, done and st.ok or st.bad)
        txt(x + cfg.pad + 40, y,
            cx_fit(c.label, w - 2 * cfg.pad - 40, 12), 12,
            done and st.label or st.dim)
        y = y - 18
    end

    y = y - 14
    local bw = (w - 2 * cfg.pad - 10) / 2
    inst_rows[#inst_rows + 1] = { kind = "retry",
        rect = fi_button(x + cfg.pad, y, bw, "RETRY", st.ok) }
    inst_rows[#inst_rows + 1] = { kind = "next",
        rect = fi_button(x + cfg.pad + bw + 10, y, bw, "NEXT LESSON", st.btn, st.value) }
end

function fi_draw()
    if not FI_CONFIG.panel_enabled then
        inst_drag.active = false
        return
    end
    inst_rows = {}

    local cfg = FI_CONFIG
    local st  = FI_STYLE
    local w   = cfg.panel_w
    local sw  = SCREEN_WIDTH or 1920
    local sh  = SCREEN_HIGHT or 1080

    local h = fi_panel_height()
    local x = cfg.panel_x or (sw - w - 24)
    x = math.max(0, math.min(x, sw - w))
    local top = cfg.panel_top or (60 + h)
    top = math.max(h + 8, math.min(top, sh - 4))
    cfg.panel_x, cfg.panel_top = x, top
    local bottom = top - h

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    bar(x, bottom, top, w, st.bg)
    bar(x, top - 1, top, w, st.border)
    bar(x, bottom, top, 1, st.border)
    bar(x + w - 1, bottom, top, 1, st.border)
    bar(x, bottom, bottom + 1, w, st.border)
    bar(x, top - cfg.header_h, top, w,
        inst_state == FI_STATE.FLYING and st.header_act or st.header_bg)
    bar(x, top - cfg.header_h, top - cfg.header_h + 2, w,
        inst_state == FI_STATE.FLYING and st.accent or st.border)

    txt(x + cfg.pad, top - 25,
        cx_fit(inst_lesson and inst_lesson.title or "FLIGHT INSTRUCTOR",
            w - 2 * cfg.pad - 70, 18), 18, st.title)
    local caption = "12 GRADED LESSONS"
    if inst_state == FI_STATE.FLYING then
        caption = inst_setup_msg:find("^PLACED") and "SETUP OK" or "LESSON"
    elseif inst_state == FI_STATE.DEBRIEF then caption = "DEBRIEF"
    elseif inst_state == FI_STATE.BRIEF then caption = "BRIEF" end
    txt_right(x + w - cfg.pad, top - 22, caption, 10, st.sub)

    inst_header_rect = { x0 = x, x1 = x + w, y0 = top - cfg.header_h, y1 = top }

    if inst_state == FI_STATE.MENU then
        fi_draw_menu(cfg, st, x, top, w)
    elseif inst_state == FI_STATE.BRIEF and inst_lesson then
        fi_draw_brief(cfg, st, x, top, w, inst_lesson)
    elseif inst_state == FI_STATE.FLYING and inst_lesson then
        fi_draw_flying(cfg, st, x, top, w, inst_lesson)
    elseif inst_state == FI_STATE.DEBRIEF and inst_lesson then
        fi_draw_debrief(cfg, st, x, top, w, inst_lesson)
    end

    inst_footer_rect = cx_footer_button(x, bottom, w, "HIDE PANEL", cfg.footer_h, cfg.pad)

    if inst_toast_text and fi_now() < inst_toast_until then
        local tw2 = (measure_string(inst_toast_text, "Helvetica_12")
            or measure_string(inst_toast_text)) + 32
        local by = bottom - 30
        bar(x, by, by + 24, tw2, CX.bg)
        bar(x, by, by + 24, 4, st.accent)
        txt(x + 16, by + 7, inst_toast_text, 12, st.value)
    end
end

-- ----------------------------------------------------------------- MOUSE ----
function fi_mouse_click()
    if not FI_CONFIG.panel_enabled then
        inst_drag.active = false
        return
    end

    local mx, my = MOUSE_X or -1, MOUSE_Y or -1
    local cfg = FI_CONFIG

    if MOUSE_STATUS == "down" then
        local hr = inst_header_rect
        if hr and mx >= hr.x0 and mx <= hr.x1 and my >= hr.y0 and my <= hr.y1 then
            inst_drag.active = true
            inst_drag.dx = mx - cfg.panel_x
            inst_drag.dy = my - (cfg.panel_top or my)
            RESUME_MOUSE_CLICK = true
            return
        end
    elseif MOUSE_STATUS == "drag" then
        if inst_drag.active then
            local sw = SCREEN_WIDTH or 1920
            local sh = SCREEN_HIGHT or 1080
            cfg.panel_x = math.max(0, math.min(mx - inst_drag.dx, sw - cfg.panel_w))
            cfg.panel_top = math.max(120, math.min(my - inst_drag.dy, sh - 4))
            RESUME_MOUSE_CLICK = true
        end
        return
    elseif MOUSE_STATUS == "up" then
        if inst_drag.active then
            inst_drag.active = false
            RESUME_MOUSE_CLICK = true
            return
        end
    end

    if MOUSE_STATUS ~= "down" then return end

    local f = inst_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        fi_toggle_panel(false)
        RESUME_MOUSE_CLICK = true
        return
    end

    for _, r in ipairs(inst_rows) do
        local rect = r.rect or r
        if mx >= rect.x0 and mx <= rect.x1 and my >= rect.y0 and my <= rect.y1 then
            RESUME_MOUSE_CLICK = true
            if r.kind == "lesson" then
                fi_brief(r.key)
            elseif r.kind == "reset" then
                fi_reset_progress()
            elseif r.kind == "setup" then
                if inst_lesson then fi_setup(inst_lesson.key) end
            elseif r.kind == "start" then
                fi_start(inst_lesson.key)
            elseif r.kind == "back" then
                fi_menu()
            elseif r.kind == "finish" then
                fi_finish()
            elseif r.kind == "abort" then
                fi_menu()
            elseif r.kind == "retry" then
                fi_retry()
            elseif r.kind == "next" then
                fi_next()
            end
            return
        end
    end
end

-- ------------------------------------------------------- COMMANDS + MENU ---
create_command("CitationXInstructor/toggle_panel",
    "Instructor: toggle the flight instructor panel", "fi_toggle_panel()", "", "")
create_command("CitationXInstructor/finish",
    "Instructor: finish the lesson and grade it", "fi_finish()", "", "")
create_command("CitationXInstructor/menu",
    "Instructor: back to the lesson list", "fi_menu()", "", "")
create_command("CitationXInstructor/start_next",
    "Instructor: start the next lesson", "fi_next()", "", "")
for _, lesson in ipairs(FI_LESSONS) do
    create_command("CitationXInstructor/lesson_" .. lesson.key,
        "Instructor: start " .. lesson.title,
        "fi_start('" .. lesson.key .. "')", "", "")
end

add_macro("Citation X Instructor: toggle panel",
    "fi_toggle_panel(true)", "fi_toggle_panel(false)",
    FI_CONFIG.panel_enabled and "activate" or "deactivate")
add_macro("Citation X Instructor: finish and grade", "fi_finish()")
add_macro("Citation X Instructor: next lesson", "fi_next()")
add_macro("Citation X Instructor: lesson list", "fi_menu()")

fi_load_progress()
fi_reset_run(nil)
logMsg("Citation X Flight Instructor loaded ("
    .. tostring(#FI_LESSONS) .. " graded lessons)")
do_every_frame("fi_frame()")
do_every_draw("fi_draw()")
do_on_mouse_click("fi_mouse_click()")
do_on_exit("fi_save_progress()")
