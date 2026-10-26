-- ============================================================================
--  CESSNA CITATION X — REALISM PACK
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
--  Version 1.1
-- ----------------------------------------------------------------------------
--  Adds the things the aircraft and X-Plane do not do on their own. Everything
--  is audio or Log.txt, plus ONE black, sans-serif panel (item 14) listing the
--  pack's controls and live state.
--
--    1. Takeoff/approach callouts (V1, rotate, positive rate, gear up,
--       1000/500/100, minimums) from the POM's operating speeds.
--    2. Electrical load manager: when a generator is lost and the bus volts
--       collapse, it drives the aircraft's own LOAD SHED switch down, one step
--       at a time. It never restores automatically — that is the pilot's job.
--    3. Brake energy monitor: switches the brake fan on when the discs absorb
--       too much energy and off again once they have cooled.
--    4. Flap and gear overspeed advisories against Vfe / Vle.
--    5. Icing advisory from OAT + visible moisture.
--    6. Vmo / Mmo overspeed warning (270 kt below 8000 ft, 350 above, M 0.935).
--    7. Takeoff configuration warning at thrust application (park brake,
--       speedbrake, flaps).
--    8. Stabilised-approach gate at 1000 ft AGL, with the reason when unstable.
--    9. GEAR DOWN confirmation when the gear locks down in flight.
--   10. ANTI-ICE OFF advisory while icing conditions exist.
--   11. CABIN ALTITUDE warning above 10 000 ft cabin altitude.
--   12. Handling curve: deadzone, expo and smoothing on the pitch/roll axes,
--       so a short-throw stick has jet-like precision near neutral. It does
--       not touch the flight model, only the pilot input.
--   13. Flight-controls check before takeoff: pitch, roll and rudder must each
--       reach 60 % of travel while on the ground, or the takeoff-config
--       warning says CONTROL CHECK.
--   14. One black, sans-serif panel (Helvetica) with every control and its live
--       state; click a row to toggle it. CitationXRealism/hud hides it.
--   15. Takeoff trim gate: elevator trim must sit in the aircraft checklist's
--       green band for the selected flap detent, aileron/rudder trim neutral.
--   16. Fuel-balance monitor: left/right wing tank difference above 200 lb.
--   17. Weight limits: MTOW 36 100 lb at takeoff, MLW 31 800 lb at touchdown.
--   18. Crosswind advisory: component above the 10 kt demonstrated limit
--       during the takeoff roll or on short final.
--
--  Speeds (Citation X POM, Operating-Speeds page / aircraft checklist):
--    Vr 145 · Vref 132 · Vfe 5° 250, 15° 210, full 180 · Vle/Vlo 210
--    Vmo 270 (<8000 ft) / 350 · Mmo 0.935 · Vso 115 · Vs1 136
--  V1 is not published in the POM table; it is a configurable advisory value.
--
--  Audio files live in Scripts/CitationX_Callouts/. If a file or the FlyWithLua
--  sound API is missing, the callout still goes to Log.txt — no error.
-- ============================================================================

REAL_CONFIG = {
    enabled            = true,
    hud_enabled        = true,   -- the one black, sans-serif realism panel

    -- Callouts ---------------------------------------------------------------
    callouts_enabled   = true,
    audio_enabled      = true,
    -- "auto" prefers FlyWithLua NG+'s FMOD buses (the X-Plane 12 path) and
    -- falls back to the legacy OpenAL load_WAV_file/play_sound pair.
    audio_backend      = "auto",   -- "auto" | "fmod" | "wav"
    callout_dir        = "CitationX_Callouts/",
    toasts_enabled     = true,     -- 2 s notice in the MasterSuite toast slot
    v1_kt              = 135,   -- advisory; POM does not publish V1
    vr_kt              = 145,
    vref_kt            = 132,
    vfe_kt             = 180,
    vle_kt             = 210,
    minima_ft          = 200,   -- decision height for the MINIMUMS call
    pos_rate_vs_fpm    = 200,
    pos_rate_agl_ft    = 35,

    -- Electrical load manager ------------------------------------------------
    elec_enabled       = true,
    elec_min_bus_v     = 24.0,
    elec_shed_interval = 2.5,   -- seconds between LOAD SHED steps
    elec_max_sheds     = 4,

    -- Brake energy -----------------------------------------------------------
    brake_enabled      = true,
    brake_hot_j        = 5.0e6, -- per brake, joules
    brake_cool_j       = 1.0e6,

    -- Overspeed advisories ---------------------------------------------------
    overspeed_enabled  = true,
    -- Citation X checklist: Vfe 250 kt at flaps 5, 210 kt at flaps 15,
    -- 180 kt at full flaps. The detents are 0.50 / 0.75 / 1.00 of travel.
    flap5_vfe_kt       = 250,
    flap15_vfe_kt      = 210,
    flap5_ratio_max    = 0.60,
    flap15_ratio_max   = 0.85,

    -- Icing ------------------------------------------------------------------
    ice_enabled        = true,
    ice_oat_max_c      = 5.0,
    ice_oat_min_c      = -20.0,
    ice_repeat_s       = 120.0,

    -- Vmo / Mmo overspeed ----------------------------------------------------
    vmo_enabled        = true,
    vmo_low_kt         = 270,   -- below vmo_low_alt_ft
    vmo_high_kt        = 350,   -- at or above vmo_low_alt_ft
    vmo_low_alt_ft     = 8000,
    mmo                = 0.935,

    -- Takeoff configuration --------------------------------------------------
    to_config_enabled  = true,
    to_throttle_ratio  = 0.70,  -- thrust lever position that arms the check
    to_flap_min_ratio  = 0.45,  -- takeoff flaps 5 (0.50) or 15 (0.75)
    to_flap_max_ratio  = 0.80,
    to_trim_tolerance  = 0.02,  -- checklist green band, plus rig tolerance

    -- Weight limits (aircraft checklist: MTOW 36 100 lb, MLW 31 800 lb) -----
    weight_enabled     = true,
    mtow_lb            = 36100,
    mlw_lb             = 31800,

    -- Fuel balance (Before Taxi checklist: imbalance < 200 lb) --------------
    fuel_balance_enabled = true,
    fuel_imbalance_lb    = 200,
    fuel_rearm_lb        = 150,
    fuel_imbalance_delay_s = 5.0,   -- ignore transient transfer/refuel slosh

    -- Crosswind (POM: maximum demonstrated crosswind 10 kt) -----------------
    crosswind_enabled  = true,
    crosswind_limit_kt = 10,

    -- Stabilised approach ----------------------------------------------------
    stable_enabled     = true,
    stable_agl_ft      = 1000,
    stable_vref_minus  = 5,     -- kt below Vref still acceptable
    stable_vref_plus   = 25,    -- kt above Vref still acceptable
    stable_max_vs_fpm  = -1200,
    stable_max_bank_deg = 30,
    stable_min_flap_ratio = 0.30,

    -- Gear-down confirmation ------------------------------------------------
    gear_down_enabled  = true,

    -- Anti-ice and pressurisation -------------------------------------------
    anti_ice_enabled   = true,
    anti_ice_repeat_s  = 60.0,
    cabin_alt_enabled  = true,
    cabin_alt_limit_ft = 10000.0,
    cabin_alt_repeat_s = 60.0,

    -- Handling: pilot-input shaping ------------------------------------------
    -- Does NOT touch the flight model. It reshapes the pitch/roll axes that go
    -- into X-Plane (deadzone, expo, smoothing), which is what makes a short-
    -- throw gamepad flyable with a jet's precision. Turn off for raw axes.
    handling_enabled    = true,
    handling_deadzone   = 0.02,
    handling_exponent   = 1.35,
    handling_smoothing  = 0.55,

    -- Flight-controls check before takeoff (pitch, roll and rudder must each
    -- reach control_check_travel of their range while on the ground).
    control_check_enabled = true,
    control_check_travel  = 0.60,
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("real_ias_kt",     "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("real_agl_m",      "sim/flightmodel/position/y_agl", "readonly")
dataref("real_vs_fpm",     "sim/flightmodel/position/vh_ind_fpm", "readonly")
dataref("real_on_ground",  "sim/flightmodel/failures/onground_any", "readonly")
dataref("real_weight_kg",  "sim/flightmodel/weight/m_total", "readonly")
dataref("real_oat_c",      "sim/cockpit2/temperature/outside_air_temp_deg", "readonly")
dataref("real_flap_rat",   "sim/flightmodel/controls/flaprat", "readonly")
dataref("real_mach",       "sim/flightmodel/misc/machno", "readonly")
dataref("real_brake_fan",  "sim/cockpit2/controls/brake_fan_on", "writable")
dataref("real_rain",       "sim/weather/region/rain_percent", "readonly")
dataref("real_sim_time",   "sim/time/total_running_time_sec", "readonly")
dataref("real_elev_m",     "sim/flightmodel/position/elevation", "readonly")
dataref("real_phi_deg",    "sim/flightmodel/position/phi", "readonly")
dataref("real_park_brake", "sim/flightmodel/controls/parkbrake", "readonly")
dataref("real_spoiler",    "sim/cockpit2/controls/speedbrake_ratio", "readonly")
dataref("real_throttle",   "sim/cockpit2/engine/actuators/throttle_ratio_all", "readonly")
dataref("real_anti_ice",   "sim/cockpit2/ice/ice_surface_hot_bleed_air_on", "readonly")
dataref("real_cabin_alt_ft",
    "sim/cockpit2/pressurization/indicators/cabin_altitude_ft", "readonly")

-- Takeoff trim, weight and crosswind monitors.
dataref("real_elev_trim", "sim/cockpit2/controls/elevator_trim", "readonly")
dataref("real_ail_trim",  "sim/cockpit2/controls/aileron_trim", "readonly")
dataref("real_rud_trim",  "sim/cockpit2/controls/rudder_trim", "readonly")
dataref("real_wind_dir_deg",
    "sim/cockpit2/gauges/indicators/wind_heading_deg_mag", "readonly")
dataref("real_wind_speed_kt",
    "sim/cockpit2/gauges/indicators/wind_speed_kts", "readonly")
dataref("real_heading_deg",
    "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", "readonly")

-- Pilot input, for the handling curve.
dataref("real_joy_pitch", "sim/joystick/joy_mapped_axis_value", "readonly", 1)
dataref("real_joy_roll",  "sim/joystick/joy_mapped_axis_value", "readonly", 2)
dataref("real_joy_pitch_avail", "sim/joystick/joy_mapped_axis_avail", "readonly", 1)
dataref("real_joy_roll_avail",  "sim/joystick/joy_mapped_axis_avail", "readonly", 2)
-- The four joystick-write DataRefs are already bound writable by the
-- MasterSuite's axis optimizer, and FlyWithLua quarantines a second writable
-- binding. Resolve them lazily through XPLM and write only while the handling
-- curve actually owns the override.

-- Resulting control positions, for the pre-takeoff control check.
dataref("real_ctrl_pitch", "sim/cockpit2/controls/yoke_pitch_ratio", "readonly")
dataref("real_ctrl_roll",  "sim/cockpit2/controls/yoke_roll_ratio", "readonly")
dataref("real_ctrl_yaw",   "sim/cockpit2/controls/yoke_heading_ratio", "readonly")
real_engine_rpm = dataref_table("sim/cockpit2/engine/indicators/engine_speed_rpm")

real_brake_j = dataref_table("sim/flightmodel2/gear/brake_absorbed_J")
real_gear    = dataref_table("sim/flightmodel2/gear/deploy_ratio")
real_bus_v   = dataref_table("sim/cockpit2/electrical/bus_volts")
real_gen_on  = dataref_table("sim/cockpit2/electrical/generator_on")
real_battery = dataref_table("sim/cockpit2/electrical/battery_on")
-- C750 tank order is 0 center, 1 left, 2 right (acf _tank_name), so the
-- checklist's "Fuel Balance <200 lbs" compares [1] against [2]. Units are kg.
real_fuel    = dataref_table("sim/cockpit2/fuel/fuel_quantity")

-- ---------------------------------------------------------------- CALLOUTS ---
local CALLOUT_FILES = {
    v1        = "v1.wav",
    rotate    = "rotate.wav",
    pos_rate  = "positive_rate.wav",
    gear_up   = "gear_up.wav",
    thousand  = "one_thousand.wav",
    five_hund = "five_hundred.wav",
    one_hund  = "one_hundred.wav",
    minimums  = "minimums.wav",
    brakes    = "brakes_hot.wav",
    flap_over = "flap_overspeed.wav",
    gear_over = "gear_speed.wav",
    icing     = "icing.wav",
    overspeed = "overspeed.wav",
    to_config = "to_config.wav",
    stable    = "stable.wav",
    unstable  = "unstable.wav",
    gear_down = "gear_down.wav",
    anti_ice  = "anti_ice.wav",
    cabin_alt = "cabin_alt.wav",
    fuel_imb  = "fuel_imbalance.wav",
    crosswind = "crosswind.wav",
    overweight = "overweight.wav",
}
local callout_id  = {}
local sound_bus   = "none"   -- "fmod" | "wav" | "none"

-- FlyWithLua NG+ 2.8 exposes two sound paths. The legacy one
-- (load_WAV_file + play_sound) goes through OpenAL; on X-Plane 12, where the
-- sim owns the audio device through FMOD, it loads fine (12/12) and plays
-- nothing. The FMOD bus path is the one the sim actually mixes.
local function fmod_sound_ok()
    return type(load_fmod_sound) == "function"
        and type(play_sound_on_master_bus) == "function"
end

local function wav_sound_ok()
    return type(load_WAV_file) == "function" and type(play_sound) == "function"
end

local function pick_backend()
    local want = tostring(REAL_CONFIG.audio_backend or "auto")
    if want == "fmod" then return fmod_sound_ok() and "fmod" or "none" end
    if want == "wav"  then return wav_sound_ok()  and "wav"  or "none" end
    if fmod_sound_ok() then return "fmod" end
    if wav_sound_ok()  then return "wav"  end
    return "none"
end

-- Current level of the bus the callouts ride on, for the Log.txt diagnosis.
-- If the FlyWithLua master group is muted or at zero the callouts would be
-- silent even though they "play", so lift it back to unity once at load.
local function log_bus_state()
    if sound_bus ~= "fmod" then return end
    local vol  = XPLMFindDataRef("FlyWithLua_MasterChannelGroup/Volume")
    local mute = XPLMFindDataRef("FlyWithLua_MasterChannelGroup/Mute")
    local v = vol  and XPLMGetDataf(vol)  or nil
    local m = mute and XPLMGetDatai(mute) or nil
    if vol and v and v < 0.05 then
        XPLMSetDataf(vol, 1.0)
        logMsg(string.format(
            "Citation X Realism: master bus was at %.2f, set to 1.00", v))
        v = 1.0
    end
    logMsg(string.format(
        "Citation X Realism: master bus volume=%s mute=%s",
        v and string.format("%.2f", v) or "?", m and tostring(m) or "?"))
end

local function load_callouts()
    if not REAL_CONFIG.audio_enabled then return end
    sound_bus = pick_backend()
    if sound_bus == "none" then
        logMsg("Citation X Realism: sound API unavailable, callouts go to Log.txt only")
        return
    end

    local total = 0
    for _ in pairs(CALLOUT_FILES) do total = total + 1 end

    local loaded = 0
    for key, file in pairs(CALLOUT_FILES) do
        local path = SCRIPT_DIRECTORY .. REAL_CONFIG.callout_dir .. file
        local ok, idx = pcall(
            sound_bus == "fmod" and load_fmod_sound or load_WAV_file, path)
        if ok and type(idx) == "number" and idx >= 0 then
            callout_id[key] = idx
            loaded = loaded + 1
        else
            logMsg(string.format("Citation X Realism: could not load %s (%s)",
                file, tostring(idx)))
        end
    end
    logMsg(string.format("Citation X Realism: %d/%d callout sounds loaded (%s bus)",
        loaded, total, sound_bus))
    log_bus_state()
end

local function play_callout_sound(idx)
    local ok, err
    if sound_bus == "fmod" then
        ok, err = pcall(play_sound_on_master_bus, idx)
    else
        ok, err = pcall(play_sound, idx)
    end
    if not ok then
        logMsg("Citation X Realism: sound " .. tostring(idx) .. " failed: " .. tostring(err))
    end
    return ok
end

-- Log-only + 2 s toast. The toast is borrowed from the MasterSuite when it is
-- loaded; the realism HUD is this script's only on-screen surface.
local HUD_INFO = { last_event = "" }

local function notify(text, toast_text)
    logMsg("Citation X Realism: " .. text)
    HUD_INFO.last_event = toast_text or text
    if not REAL_CONFIG.toasts_enabled then return end
    local fn = _G.citationx_toast
    if type(fn) == "function" then pcall(fn, toast_text or text) end
end

local function callout(key, text)
    logMsg("Citation X Realism: CALLOUT " .. text)
    HUD_INFO.last_event = text
    local idx = callout_id[key]
    if idx and REAL_CONFIG.audio_enabled then play_callout_sound(idx) end
end

-- ------------------------------------------------------------------ STATE ---
local S = {
    was_ground      = true,
    airborne        = false,
    v1_done         = false,
    vr_done         = false,
    pos_done        = false,
    gear_done       = false,
    thousand_done   = false,
    five_done       = false,
    one_done        = false,
    minima_done     = false,
    last_call       = 0.0,
    lift_off_time   = 0.0,
    prev_gen_count  = 2,
    shed_steps      = 0,
    next_shed       = 0.0,
    brake_hot       = false,
    flap_over_at    = 0.0,
    flap_warned     = false,
    gear_over_at    = 0.0,
    gear_warned     = false,
    ice_next        = 0.0,
    last_tick       = -1.0,
    prev_gear       = 1.0,
    overspeed_warned = false,
    to_config_armed  = true,
    stable_checked   = false,
    gear_prev        = 1.0,
    gear_down_called = false,
    anti_ice_next    = 0.0,
    cabin_next       = 0.0,
    cc_pitch         = false,
    cc_roll          = false,
    cc_yaw           = false,
    cc_done          = false,
    cc_engine_running = false,
    to_issue         = "",
    approach_note    = "-",
    fuel_over_since  = nil,
    fuel_warned      = false,
    xwind_warned     = false,
    weight_airborne  = false,
    overweight_called = false,
}

-- --------------------------------------------------------------- HELPERS -----
-- Citation X checklist units: fuel is loaded in lb, X-Plane stores kg.
local LB_PER_KG = 2.2046226218
local function kg_to_lb(kg) return (kg or 0.0) * LB_PER_KG end

-- C750 tanks: 1 left wing, 2 right wing. The Before Taxi check requires the
-- difference below 200 lb; X-Plane reports each tank in kg.
local function fuel_imbalance_lb()
    local left  = real_fuel[1] or 0.0
    local right = real_fuel[2] or 0.0
    return math.abs(left - right) * LB_PER_KG
end

-- The checklist's green band: flaps 5 -> -0.43..0, flaps 15 -> -0.21..0.42.
-- Anything outside the two takeoff detents has no published takeoff band.
local function takeoff_trim_band(flap)
    if flap >= 0.45 and flap <= 0.60 then return -0.43, 0.00 end
    if flap > 0.60 and flap <= 0.85 then return -0.21, 0.42 end
    return nil
end

-- Crosswind component relative to the nose. During the takeoff roll and on
-- short final the nose is aligned with the runway, so this is the component
-- the POM's 10 kt demonstrated limit refers to.
local function crosswind_kt()
    local delta = math.rad((real_wind_dir_deg or 0.0) - (real_heading_deg or 0.0))
    return math.abs((real_wind_speed_kt or 0.0) * math.sin(delta))
end

-- ---------------------------------------------------------------- HANDLING ---
-- Two writers may never own the same joystick override: if the MasterSuite's
-- axis optimizer is on, this section stays out of the way.
local handling_active = false
local smooth_pitch    = 0.0
local smooth_roll     = 0.0

local handling_refs = nil
local function handling_datarefs()
    if not handling_refs then
        handling_refs = {
            yoke_pitch = XPLMFindDataRef("sim/joystick/yoke_pitch_ratio"),
            yoke_roll  = XPLMFindDataRef("sim/joystick/yoke_roll_ratio"),
            ovr_pitch  = XPLMFindDataRef("sim/operation/override/override_joystick_pitch"),
            ovr_roll   = XPLMFindDataRef("sim/operation/override/override_joystick_roll"),
        }
    end
    return handling_refs
end

local function release_handling()
    if not handling_active then return end
    -- Hand the overrides back only if nobody else has taken them: the
    -- MasterSuite axis optimizer writes the same two datarefs, and stomping
    -- them to 0 would leave it driving an override it no longer owns.
    if not (type(CONFIG) == "table" and CONFIG.axis_optimizer_enabled) then
        local refs = handling_datarefs()
        if refs.ovr_pitch then XPLMSetDatai(refs.ovr_pitch, 0) end
        if refs.ovr_roll  then XPLMSetDatai(refs.ovr_roll,  0) end
    end
    handling_active = false
    logMsg("Citation X Realism: handling curve released")
end

local function shaped_axis(v)
    local dz = REAL_CONFIG.handling_deadzone
    local a  = math.abs(v or 0.0)
    if a <= dz then return 0.0 end
    a = (a - dz) / (1.0 - dz)
    local out = a ^ REAL_CONFIG.handling_exponent
    return (v < 0.0) and -out or out
end

local function handling_tick()
    if not REAL_CONFIG.handling_enabled then
        release_handling()
        return
    end
    if type(CONFIG) == "table" and CONFIG.axis_optimizer_enabled then
        release_handling()
        return
    end
    if real_joy_pitch_avail ~= 1 or real_joy_roll_avail ~= 1 then
        release_handling()
        return
    end

    local refs = handling_datarefs()
    if not (refs.yoke_pitch and refs.yoke_roll and refs.ovr_pitch and refs.ovr_roll) then
        release_handling()
        return
    end

    local target_pitch = shaped_axis(real_joy_pitch)
    local target_roll  = shaped_axis(real_joy_roll)

    if not handling_active then
        XPLMSetDatai(refs.ovr_pitch, 1)
        XPLMSetDatai(refs.ovr_roll,  1)
        handling_active = true
        smooth_pitch    = target_pitch
        smooth_roll     = target_roll
        logMsg("Citation X Realism: handling curve engaged")
    end

    local k = REAL_CONFIG.handling_smoothing
    smooth_pitch = smooth_pitch + k * (target_pitch - smooth_pitch)
    smooth_roll  = smooth_roll  + k * (target_roll  - smooth_roll)
    XPLMSetDataf(refs.yoke_pitch, smooth_pitch)
    XPLMSetDataf(refs.yoke_roll,  smooth_roll)
end

-- ---------------------------------------------------------- CONTROL CHECK ----
local function control_check_tick()
    if not REAL_CONFIG.control_check_enabled then
        S.cc_done = true
        return
    end

    local rpm1 = real_engine_rpm[0] or 0.0
    local rpm2 = real_engine_rpm[1] or 0.0
    local running = (rpm1 > 50.0) or (rpm2 > 50.0)
    if S.cc_engine_running and not running and real_on_ground == 1 then
        S.cc_pitch, S.cc_roll, S.cc_yaw = false, false, false
        S.cc_done = false
        logMsg("Citation X Realism: control check reset (engines shut down)")
    end
    S.cc_engine_running = running

    if S.cc_done or real_on_ground ~= 1 then return end

    local travel = REAL_CONFIG.control_check_travel
    if math.abs(real_ctrl_pitch or 0.0) >= travel then S.cc_pitch = true end
    if math.abs(real_ctrl_roll or 0.0)  >= travel then S.cc_roll  = true end
    if math.abs(real_ctrl_yaw or 0.0)   >= travel then S.cc_yaw   = true end

    if S.cc_pitch and S.cc_roll and S.cc_yaw then
        S.cc_done = true
        notify("flight controls checked (pitch, roll, yaw)", "CONTROLS CHECKED")
    end
end

-- Last runtime dataref the C750 registers (read lazily: it does not exist
-- until the aircraft loads, so a dataref() binding here would quarantine us).
local load_shed_ref = nil
local load_shed_retry = 0.0

local function load_shed_position(now)
    if not load_shed_ref and now >= load_shed_retry then
        load_shed_retry = now + 5.0
        load_shed_ref = XPLMFindDataRef("laminar/CitX/electrical/load_shed")
    end
    if load_shed_ref then return XPLMGetDatai(load_shed_ref) end
    return nil
end

-- ------------------------------------------------------------ CALL OUT LOGIC -
local function reset_takeoff_state()
    S.v1_done       = false
    S.vr_done       = false
    S.pos_done      = false
    S.gear_done     = false
    S.thousand_done = false
    S.five_done     = false
    S.one_done      = false
    S.minima_done   = false
end

local function callouts_tick(now, agl_ft)
    if not REAL_CONFIG.callouts_enabled then return end
    local ias  = real_ias_kt or 0.0
    local vs   = real_vs_fpm or 0.0
    local gear = real_gear[0] or 0.0

    -- Takeoff roll: only while still on the ground and accelerating through
    -- the speed. One call each per takeoff.
    if S.was_ground == true and real_on_ground == 1 then
        if not S.v1_done and ias >= REAL_CONFIG.v1_kt then
            S.v1_done = true
            callout("v1", "V ONE")
        end
        if not S.vr_done and ias >= REAL_CONFIG.vr_kt then
            S.vr_done = true
            callout("rotate", "ROTATE")
        end
    end

    -- Liftoff
    if S.was_ground == true and real_on_ground == 0 then
        S.airborne     = true
        S.lift_off_time = now
        reset_takeoff_state()
        S.v1_done  = true   -- already rolling; do not repeat on a bounce
        S.vr_done  = true
    end

    if S.airborne and not S.pos_done
        and agl_ft >= REAL_CONFIG.pos_rate_agl_ft
        and vs >= REAL_CONFIG.pos_rate_vs_fpm then
        S.pos_done = true
        callout("pos_rate", "POSITIVE RATE")
    end

    if S.airborne and S.pos_done and not S.gear_done
        and now - S.lift_off_time >= 2.0
        and S.prev_gear >= 0.95 and gear < 0.95 then
        -- Only when the gear is actually coming up: the old test fired as soon
        -- as two seconds had passed, even with the gear still down.
        S.gear_done = true
        callout("gear_up", "GEAR UP")
    end

    if S.airborne and not S.thousand_done and agl_ft >= 1000.0 and vs > 0 then
        S.thousand_done = true
        callout("thousand", "ONE THOUSAND")
    end

    -- Approach: descending, gear down, radio-altimeter style calls.
    local approach = (not S.was_ground) and vs < -300.0 and gear > 0.9
    if approach then
        if not S.five_done and agl_ft <= 500.0 then
            S.five_done = true
            callout("five_hund", "FIVE HUNDRED")
        end
        if not S.one_done and agl_ft <= 100.0 then
            S.one_done = true
            callout("one_hund", "ONE HUNDRED")
        end
        if not S.minima_done and agl_ft <= REAL_CONFIG.minima_ft then
            S.minima_done = true
            callout("minimums", "MINIMUMS")
        end
    end

    -- Touchdown
    if S.was_ground == false and real_on_ground == 1 then
        S.airborne = false
        reset_takeoff_state()
    end

    S.prev_gear = gear
end

-- ------------------------------------------------------ TAKEOFF CONFIG ------
-- Fires once when the thrust levers go forward with something set for landing
-- or parking. It does not touch the aircraft: it only says what is wrong.
local function takeoff_config_tick(now)
    if not REAL_CONFIG.to_config_enabled then return end
    if real_on_ground ~= 1 then
        S.to_config_armed = true
        return
    end
    local thr = real_throttle or 0.0
    if thr < 0.2 then
        S.to_config_armed = true
        S.to_issue = ""
    end
    if not S.to_config_armed or thr < REAL_CONFIG.to_throttle_ratio then return end
    S.to_config_armed = false

    local issues = {}
    local flap = real_flap_rat or 0.0
    if (real_park_brake or 0.0) > 0.1 then issues[#issues + 1] = "PARK BRAKE" end
    if (real_spoiler or 0.0) > 0.1 then issues[#issues + 1] = "SPEEDBRAKE" end
    if flap < REAL_CONFIG.to_flap_min_ratio
        or flap > REAL_CONFIG.to_flap_max_ratio then
        issues[#issues + 1] = "FLAPS"
    end

    -- Stabilizer trim green band + lateral trim neutral, from the aircraft's
    -- BEFORE TAXI checklist. Only meaningful when the flaps are at a takeoff
    -- detent; a flap issue above already covers every other setting.
    local tol = REAL_CONFIG.to_trim_tolerance
    local tmin, tmax = takeoff_trim_band(flap)
    if tmin and ((real_elev_trim or 0.0) < tmin - tol
        or (real_elev_trim or 0.0) > tmax + tol) then
        issues[#issues + 1] = "STAB TRIM"
    end
    if math.abs(real_ail_trim or 0.0) > tol
        or math.abs(real_rud_trim or 0.0) > tol then
        issues[#issues + 1] = "LATERAL TRIM"
    end
    if kg_to_lb(real_weight_kg) > REAL_CONFIG.mtow_lb then
        issues[#issues + 1] = "WEIGHT"
    end

    if REAL_CONFIG.control_check_enabled and not S.cc_done then
        issues[#issues + 1] = "CONTROL CHECK"
    end
    if #issues == 0 then return end

    S.to_issue = table.concat(issues, ", ")
    callout("to_config", "TAKEOFF CONFIG")
    notify("takeoff config: " .. table.concat(issues, ", "),
        "TAKEOFF CONFIG: " .. table.concat(issues, " / "))
end

-- -------------------------------------------------------- VMO / MMO ---------
local function vmo_tick(now)
    if not REAL_CONFIG.vmo_enabled then return end
    local ias    = real_ias_kt or 0.0
    local mach   = real_mach or 0.0
    local alt_ft = (real_elev_m or 0.0) * 3.28084
    local vmo    = (alt_ft < REAL_CONFIG.vmo_low_alt_ft)
        and REAL_CONFIG.vmo_low_kt or REAL_CONFIG.vmo_high_kt
    local over = (ias > vmo + 3.0) or (mach > REAL_CONFIG.mmo + 0.01)
    if over and not S.overspeed_warned then
        S.overspeed_warned = true
        callout("overspeed", "OVERSPEED")
        notify(string.format("overspeed %.0f kt / M%.3f (Vmo %.0f, Mmo %.3f)",
            ias, mach, vmo, REAL_CONFIG.mmo), "OVERSPEED")
    elseif not over
        and ias < vmo - 5.0
        and mach < REAL_CONFIG.mmo - 0.01 then
        S.overspeed_warned = false
    end
end

-- ---------------------------------------------------- STABILISED APPROACH ---
local function stable_tick(now, agl_ft)
    if not REAL_CONFIG.stable_enabled then return end
    if real_on_ground == 1 then
        S.stable_checked = false
        S.approach_note  = "-"
        return
    end
    if agl_ft > REAL_CONFIG.stable_agl_ft + 500.0 then
        S.stable_checked = false   -- re-arm after a go-around
        return
    end
    if S.stable_checked or agl_ft > REAL_CONFIG.stable_agl_ft then return end

    local gear = real_gear[0] or 0.0
    local flap = real_flap_rat or 0.0
    local vs   = real_vs_fpm or 0.0
    if vs > -200.0 or (gear < 0.5 and flap < 0.05) then return end
    S.stable_checked = true

    local ias    = real_ias_kt or 0.0
    local issues = {}
    if gear < 0.95 then issues[#issues + 1] = "GEAR" end
    if flap < REAL_CONFIG.stable_min_flap_ratio then issues[#issues + 1] = "FLAPS" end
    if (real_spoiler or 0.0) > 0.1 then issues[#issues + 1] = "SPEEDBRAKE" end
    if math.abs(real_phi_deg or 0.0) > REAL_CONFIG.stable_max_bank_deg then
        issues[#issues + 1] = "BANK"
    end
    if vs < REAL_CONFIG.stable_max_vs_fpm then issues[#issues + 1] = "SINK RATE" end
    if ias < REAL_CONFIG.vref_kt - REAL_CONFIG.stable_vref_minus
        or ias > REAL_CONFIG.vref_kt + REAL_CONFIG.stable_vref_plus then
        issues[#issues + 1] = string.format("SPEED %.0f", ias)
    end

    if #issues == 0 then
        S.approach_note = "STABLE"
        callout("stable", "STABLE")
        notify(string.format("stabilised at %.0f ft, %.0f kt", agl_ft, ias),
            "STABLE APPROACH")
    else
        S.approach_note = "UNSTABLE: " .. table.concat(issues, ", ")
        callout("unstable", "UNSTABLE")
        notify("not stabilised: " .. table.concat(issues, ", "),
            "UNSTABLE: " .. table.concat(issues, " / "))
    end
end

-- --------------------------------------------------------- GEAR CONFIRM -----
local function gear_down_tick()
    if not REAL_CONFIG.gear_down_enabled then return end
    local gear = real_gear[0] or 0.0
    if S.airborne and not S.gear_down_called
        and S.gear_prev < 0.95 and gear >= 0.99 then
        S.gear_down_called = true
        callout("gear_down", "GEAR DOWN")
    end
    if gear < 0.05 then S.gear_down_called = false end
    S.gear_prev = gear
end

-- ------------------------------------------------------------- ANTI-ICE -----
local function anti_ice_tick(now)
    if not REAL_CONFIG.anti_ice_enabled then return end
    if real_on_ground == 1 or (real_anti_ice or 0) ~= 0 then return end
    local oat  = real_oat_c or 15.0
    local rain = real_rain or 0.0
    if oat > REAL_CONFIG.ice_oat_max_c or oat < REAL_CONFIG.ice_oat_min_c then return end
    if rain <= 0.01 then return end
    if now < S.anti_ice_next then return end
    S.anti_ice_next = now + REAL_CONFIG.anti_ice_repeat_s
    callout("anti_ice", "ANTI ICE")
    notify(string.format(
        "icing conditions with wing anti-ice OFF (OAT %.0f C, rain %.0f%%)",
        oat, rain * 100), "ICING - ANTI-ICE OFF")
end

-- ------------------------------------------------------ CABIN ALTITUDE ------
local function cabin_alt_tick(now)
    if not REAL_CONFIG.cabin_alt_enabled then return end
    if real_on_ground == 1 then return end
    local cab = real_cabin_alt_ft or 0.0
    if cab < REAL_CONFIG.cabin_alt_limit_ft then return end
    if now < S.cabin_next then return end
    S.cabin_next = now + REAL_CONFIG.cabin_alt_repeat_s
    callout("cabin_alt", "CABIN ALTITUDE")
    notify(string.format("cabin altitude %.0f ft", cab),
        string.format("CABIN ALTITUDE %.0f FT", cab))
end

-- --------------------------------------------------------------- ELECTRICAL --
local function electrical_tick(now)
    if not REAL_CONFIG.elec_enabled then return end
    local gen_count = (real_gen_on[0] or 0) + (real_gen_on[1] or 0)
    local bus_v     = real_bus_v[0] or 0.0
    local battery   = (real_battery[0] or 0) + (real_battery[1] or 0)

    -- Nothing powered: forget the history.
    if gen_count == 0 and battery == 0 then
        S.prev_gen_count = 0
        return
    end

    local lost_generator = (S.prev_gen_count >= 2 and gen_count < S.prev_gen_count)
    S.prev_gen_count = gen_count

    if lost_generator then
        notify(string.format("generator lost (%d online), bus %.1f V",
            gen_count, bus_v), "GENERATOR LOST")
    end

    if gen_count == 2 and bus_v >= REAL_CONFIG.elec_min_bus_v then
        S.shed_steps = 0
        return
    end

    if gen_count >= 1
        and bus_v < REAL_CONFIG.elec_min_bus_v
        and S.shed_steps < REAL_CONFIG.elec_max_sheds
        and now >= S.next_shed then
        S.next_shed = now + REAL_CONFIG.elec_shed_interval
        command_once("laminar/CitX/electrical/cmd_load_shed_dwn")
        S.shed_steps = S.shed_steps + 1
        local pos = load_shed_position(now)
        notify(string.format("LOAD SHED step %d (bus %.1f V, switch=%s)",
            S.shed_steps, bus_v, tostring(pos)),
            string.format("LOAD SHED %d/4", S.shed_steps))
    end
end

-- ------------------------------------------------------------------ BRAKES ---
local function brakes_tick(now)
    if not REAL_CONFIG.brake_enabled then return end
    local hottest = 0.0
    for i = 0, 9 do
        local j = real_brake_j[i] or 0.0
        if j > hottest then hottest = j end
    end

    if not S.brake_hot and hottest >= REAL_CONFIG.brake_hot_j and real_brake_fan == 0 then
        S.brake_hot = true
        real_brake_fan = 1
        callout("brakes", "BRAKES HOT")
        notify(string.format("brake fan ON (%.1f MJ)", hottest / 1e6),
            string.format("BRAKES HOT %.1f MJ", hottest / 1e6))
    elseif S.brake_hot and hottest <= REAL_CONFIG.brake_cool_j and real_brake_fan == 1 then
        S.brake_hot = false
        real_brake_fan = 0
        notify(string.format("brake fan OFF (%.1f MJ)", hottest / 1e6), "BRAKE FAN OFF")
    end
end

-- ------------------------------------------------------------- FUEL BALANCE --
local function fuel_tick(now)
    if not REAL_CONFIG.fuel_balance_enabled then return end
    local lb = fuel_imbalance_lb()

    -- Ignore the ground/refuel case until an engine is running: the Before
    -- Taxi checklist item only matters once the aircraft is about to move.
    local powered = (real_engine_rpm[0] or 0.0) > 50.0
        or (real_engine_rpm[1] or 0.0) > 50.0
    if real_on_ground == 1 and not powered then
        S.fuel_over_since = nil
        return
    end

    if lb > REAL_CONFIG.fuel_imbalance_lb then
        if not S.fuel_over_since then S.fuel_over_since = now end
        if not S.fuel_warned
            and now - S.fuel_over_since >= REAL_CONFIG.fuel_imbalance_delay_s then
            S.fuel_warned = true
            callout("fuel_imb", "FUEL IMBALANCE")
            notify(string.format("fuel imbalance %.0f lb (limit %.0f)",
                lb, REAL_CONFIG.fuel_imbalance_lb),
                string.format("FUEL IMBALANCE %.0f LB", lb))
        end
    else
        S.fuel_over_since = nil
        if S.fuel_warned and lb < REAL_CONFIG.fuel_rearm_lb then
            S.fuel_warned = false
        end
    end
end

-- ----------------------------------------------------------------- WEIGHT ----
local function weight_tick()
    if not REAL_CONFIG.weight_enabled then return end
    local on_ground = (real_on_ground == 1)
    local lb = kg_to_lb(real_weight_kg)

    if on_ground and S.weight_airborne and not S.overweight_called then
        S.overweight_called = true
        if lb > REAL_CONFIG.mlw_lb then
            callout("overweight", "OVERWEIGHT")
            notify(string.format("landed at %.0f lb, MLW %.0f lb", lb, REAL_CONFIG.mlw_lb),
                string.format("OVERWEIGHT LANDING %.0f LB", lb))
        end
    end
    if not on_ground then S.overweight_called = false end
    S.weight_airborne = not on_ground
end

-- --------------------------------------------------------------- CROSSWIND ---
local function crosswind_tick(agl_ft)
    if not REAL_CONFIG.crosswind_enabled then return end
    local ias = real_ias_kt or 0.0
    local takeoff_roll = (real_on_ground == 1) and ias > 40.0
    local short_final  = (real_on_ground == 0)
        and agl_ft < 1200.0 and (real_vs_fpm or 0.0) < -100.0

    if not (takeoff_roll or short_final) then
        S.xwind_warned = false
        return
    end

    local xw = crosswind_kt()
    if xw > REAL_CONFIG.crosswind_limit_kt and not S.xwind_warned then
        S.xwind_warned = true
        callout("crosswind", "CROSSWIND")
        notify(string.format("crosswind %.0f kt (demonstrated limit %.0f)",
            xw, REAL_CONFIG.crosswind_limit_kt),
            string.format("CROSSWIND %.0f KT (MAX DEMO %.0f)",
                xw, REAL_CONFIG.crosswind_limit_kt))
    end
end

-- -------------------------------------------------------------- OVERSPEED ----
local function overspeed_tick(now)
    if not REAL_CONFIG.overspeed_enabled then return end
    local ias  = real_ias_kt or 0.0
    local flap = real_flap_rat or 0.0
    local gear = real_gear[0] or 0.0

    local vfe = nil
    if flap > 0.05 then
        if flap <= REAL_CONFIG.flap5_ratio_max then
            vfe = REAL_CONFIG.flap5_vfe_kt
        elseif flap <= REAL_CONFIG.flap15_ratio_max then
            vfe = REAL_CONFIG.flap15_vfe_kt
        else
            vfe = REAL_CONFIG.vfe_kt
        end
    end

    if vfe and ias > vfe + 3.0 then
        if not S.flap_warned then
            S.flap_warned = true
            callout("flap_over", "FLAP OVERSPEED")
            notify(string.format("flap overspeed %.0f kt (limit %.0f)", ias, vfe),
                string.format("FLAP OVERSPEED %.0f KT (MAX %.0f)", ias, vfe))
        end
    elseif vfe and ias < vfe - 3.0 then
        S.flap_warned = false
    elseif not vfe then
        S.flap_warned = false
    end

    -- Gear in transit or extended above Vle.
    if gear > 0.05 and ias > REAL_CONFIG.vle_kt + 3.0 then
        if not S.gear_warned then
            S.gear_warned = true
            callout("gear_over", "GEAR SPEED")
            notify(string.format("gear overspeed %.0f kt (limit %.0f)",
                ias, REAL_CONFIG.vle_kt),
                string.format("GEAR OVERSPEED %.0f KT (MAX %.0f)",
                    ias, REAL_CONFIG.vle_kt))
        end
    elseif ias < REAL_CONFIG.vle_kt - 3.0 then
        S.gear_warned = false
    end
end

-- -------------------------------------------------------------------- ICING --
local function icing_tick(now)
    if not REAL_CONFIG.ice_enabled then return end
    if real_on_ground == 1 then return end   -- airframe icing needs flight
    local oat  = real_oat_c or 15.0
    local rain = real_rain or 0.0
    -- With the wing anti-ice off, anti_ice_tick() owns the message instead.
    if REAL_CONFIG.anti_ice_enabled and (real_anti_ice or 0) == 0 then return end
    if oat <= REAL_CONFIG.ice_oat_max_c
        and oat >= REAL_CONFIG.ice_oat_min_c
        and rain > 0.01
        and now >= S.ice_next then
        S.ice_next = now + REAL_CONFIG.ice_repeat_s
        callout("icing", "ICING CONDITIONS")
        notify(string.format("icing conditions (OAT %.0f C, rain %.0f%%)",
            oat, rain * 100), "ICING CONDITIONS")
    end
end

-- ---------------------------------------------------------------- FRAME ------
function real_frame()
    if not REAL_CONFIG.enabled then
        release_handling()
        return
    end
    handling_tick()

    local now = real_sim_time or 0.0
    if now - S.last_tick < 0.1 then return end
    S.last_tick = now

    local agl_ft = (real_agl_m or 0.0) * 3.28084

    control_check_tick()
    callouts_tick(now, agl_ft)
    takeoff_config_tick(now)
    vmo_tick(now)
    stable_tick(now, agl_ft)
    gear_down_tick()
    electrical_tick(now)
    brakes_tick(now)
    overspeed_tick(now)
    fuel_tick(now)
    weight_tick()
    crosswind_tick(agl_ft)
    icing_tick(now)
    anti_ice_tick(now)
    cabin_alt_tick(now)

    S.was_ground = (real_on_ground == 1)
end

-- -------------------------------------------------------------- CONTROLS -----
function real_set_enabled(on)
    REAL_CONFIG.enabled = (on == true)
    if not REAL_CONFIG.enabled then release_handling() end
    logMsg("Citation X Realism: " .. (REAL_CONFIG.enabled and "ON" or "OFF"))
end

function real_set_handling(on)
    REAL_CONFIG.handling_enabled = (on == true)
    if not REAL_CONFIG.handling_enabled then release_handling() end
    logMsg("Citation X Realism: handling curve "
        .. (REAL_CONFIG.handling_enabled and "ON" or "OFF"))
end

function real_status_report()
    logMsg("Citation X Realism: status -------------------------------------")
    logMsg(string.format("  enabled=%s callouts=%s audio=%s elec=%s brakes=%s",
        tostring(REAL_CONFIG.enabled), tostring(REAL_CONFIG.callouts_enabled),
        tostring(REAL_CONFIG.audio_enabled), tostring(REAL_CONFIG.elec_enabled),
        tostring(REAL_CONFIG.brake_enabled)))
    logMsg(string.format("  vmo=%s to_config=%s stable=%s anti_ice=%s cabin_alt=%s",
        tostring(REAL_CONFIG.vmo_enabled), tostring(REAL_CONFIG.to_config_enabled),
        tostring(REAL_CONFIG.stable_enabled), tostring(REAL_CONFIG.anti_ice_enabled),
        tostring(REAL_CONFIG.cabin_alt_enabled)))
    logMsg(string.format("  weight=%s fuel_bal=%s crosswind=%s",
        tostring(REAL_CONFIG.weight_enabled),
        tostring(REAL_CONFIG.fuel_balance_enabled),
        tostring(REAL_CONFIG.crosswind_enabled)))
    logMsg(string.format("  weight=%.0f lb (MTOW %.0f, MLW %.0f), fuel imbalance=%.0f lb",
        kg_to_lb(real_weight_kg), REAL_CONFIG.mtow_lb, REAL_CONFIG.mlw_lb,
        fuel_imbalance_lb()))
    logMsg(string.format("  stab trim=%.2f, crosswind=%.0f kt",
        real_elev_trim or 0.0, crosswind_kt()))
    logMsg(string.format("  handling=%s (dz %.2f exp %.2f), control check=%s (%s)",
        tostring(REAL_CONFIG.handling_enabled), REAL_CONFIG.handling_deadzone,
        REAL_CONFIG.handling_exponent, tostring(REAL_CONFIG.control_check_enabled),
        tostring(S.cc_done)))
    logMsg(string.format("  sound bus=%s, %d sound(s) loaded",
        sound_bus, (function() local n = 0 for _ in pairs(callout_id) do n = n + 1 end return n end)()))
    logMsg(string.format("  speeds V1=%d Vr=%d Vref=%d Vfe=%d Vle=%d",
        REAL_CONFIG.v1_kt, REAL_CONFIG.vr_kt, REAL_CONFIG.vref_kt,
        REAL_CONFIG.vfe_kt, REAL_CONFIG.vle_kt))
    logMsg(string.format("  load shed steps=%d, brake hot=%s",
        S.shed_steps, tostring(S.brake_hot)))
end

function real_test_callout()
    local idx = callout_id.rotate
    logMsg(string.format("Citation X Realism: TEST callout via %s (index %s)",
        sound_bus, tostring(idx)))
    if idx then play_callout_sound(idx) end
end

-- ------------------------------------------------------------------- HUD -----
-- The pack's one on-screen surface: a black, sans-serif panel listing every
-- realism control and its live state. Everything else stays audio/Log.txt.
REAL_STYLE = {
    x = 24, top = 24, width = 430, pad = 14,
    header_h = 34, row_h = 21, footer_h = 34,
    bg        = {0.00, 0.00, 0.00, 0.90},
    header_bg = {0.04, 0.04, 0.04, 0.96},
    border    = {0.32, 0.32, 0.32, 1.00},
    title     = {1.00, 1.00, 1.00, 1.00},
    sub       = {0.55, 0.55, 0.55, 1.00},
    label     = {0.80, 0.80, 0.80, 1.00},
    value     = {1.00, 1.00, 1.00, 1.00},
    dim       = {0.45, 0.45, 0.45, 1.00},
    ok        = {0.45, 0.85, 0.50, 1.00},
    warn      = {0.95, 0.72, 0.25, 1.00},
    bad       = {0.95, 0.36, 0.32, 1.00},
    btn       = {0.10, 0.10, 0.10, 1.00},
}

local hud_hits = {}

local function hud_bar(x0, y0, x1, y1, col, alpha)
    glColor4f(col[1], col[2], col[3], alpha or col[4] or 1.0)
    glRectf(x0, y0, x1, y1)
end

local function hud_font(size)
    if size == 18 then return draw_string_Helvetica_18 end
    if size == 10 then return draw_string_Helvetica_10 end
    return draw_string_Helvetica_12
end

local function hud_text(x, y, text, size, col)
    glColor4f(col[1], col[2], col[3], 1.0)
    hud_font(size)(x, y, tostring(text or ""))
end

local function hud_text_right(x_right, y, text, size, col)
    local w = measure_string(tostring(text or ""), "Helvetica_" .. tostring(size)) or 0
    hud_text(x_right - w, y, text, size, col)
end

local function hud_fit(text, max_chars)
    text = tostring(text or "")
    if #text <= max_chars then return text end
    return text:sub(1, max_chars - 2) .. ".."
end

local function hud_audio()
    if not REAL_CONFIG.audio_enabled then return "OFF", REAL_STYLE.dim end
    if sound_bus == "none" then return "NO API", REAL_STYLE.bad end
    local n = 0
    for _ in pairs(callout_id) do n = n + 1 end
    return string.format("%s  %d", sound_bus == "fmod" and "FMOD" or "WAV", n),
        REAL_STYLE.value
end

local function hud_brakes()
    local hottest = 0.0
    for i = 0, 9 do
        local j = real_brake_j[i] or 0.0
        if j > hottest then hottest = j end
    end
    local text = string.format("FAN %s  %.1f MJ",
        S.brake_hot and "ON" or "OFF", hottest / 1e6)
    return text, S.brake_hot and REAL_STYLE.warn or REAL_STYLE.value
end

local function hud_icing()
    local oat  = real_oat_c or 15.0
    local rain = real_rain or 0.0
    if oat <= REAL_CONFIG.ice_oat_max_c and oat >= REAL_CONFIG.ice_oat_min_c
        and rain > 0.01 and real_on_ground ~= 1 then
        if (real_anti_ice or 0) == 0 then
            return "ICE - PROT OFF", REAL_STYLE.bad
        end
        return "ICE - PROT ON", REAL_STYLE.warn
    end
    return "CLEAR", REAL_STYLE.value
end

local function hud_trim()
    local flap = real_flap_rat or 0.0
    local trim = real_elev_trim or 0.0
    local tol  = REAL_CONFIG.to_trim_tolerance
    local tmin, tmax = takeoff_trim_band(flap)
    if not tmin then
        return string.format("%.2f  --", trim), REAL_STYLE.dim
    end
    local ok = trim >= tmin - tol and trim <= tmax + tol
        and math.abs(real_ail_trim or 0.0) <= tol
        and math.abs(real_rud_trim or 0.0) <= tol
    return string.format("%.2f  %s", trim, ok and "GREEN" or "OUT"),
        ok and REAL_STYLE.ok or REAL_STYLE.warn
end

local function hud_fuel()
    local lb = fuel_imbalance_lb()
    return string.format("%.0f LB", lb),
        (lb > REAL_CONFIG.fuel_imbalance_lb) and REAL_STYLE.warn or REAL_STYLE.value
end

local function hud_weight()
    local lb = kg_to_lb(real_weight_kg)
    local airborne = (real_on_ground == 0)
    local limit = airborne and REAL_CONFIG.mlw_lb or REAL_CONFIG.mtow_lb
    local tag = airborne and "LDG" or "TO"
    return string.format("%.1fK  %s", lb / 1000.0, tag),
        (lb > limit) and REAL_STYLE.warn or REAL_STYLE.value
end

local function hud_xwind()
    local xw = crosswind_kt()
    return string.format("%.0f KT", xw),
        (xw > REAL_CONFIG.crosswind_limit_kt) and REAL_STYLE.warn or REAL_STYLE.value
end

REAL_HUD_ROWS = {
    {
        label = "REALISM PACK",
        act = function() real_set_enabled(not REAL_CONFIG.enabled) end,
        value = function()
            if REAL_CONFIG.enabled then return "ON", REAL_STYLE.ok end
            return "OFF", REAL_STYLE.dim
        end,
    },
    {
        label = "CALLOUTS",
        act = function()
            REAL_CONFIG.callouts_enabled = not REAL_CONFIG.callouts_enabled
        end,
        value = function()
            if REAL_CONFIG.callouts_enabled then return "ON", REAL_STYLE.ok end
            return "OFF", REAL_STYLE.dim
        end,
    },
    { label = "AUDIO", value = hud_audio },
    {
        label = "HANDLING CURVE",
        act = function() real_set_handling(not REAL_CONFIG.handling_enabled) end,
        value = function()
            if REAL_CONFIG.handling_enabled then return "ON", REAL_STYLE.ok end
            return "OFF", REAL_STYLE.dim
        end,
    },
    {
        label = "CTRL CHECK",
        act = function()
            S.cc_pitch, S.cc_roll, S.cc_yaw = false, false, false
            S.cc_done = false
            logMsg("Citation X Realism: control check reset from the HUD")
        end,
        value = function()
            if not REAL_CONFIG.control_check_enabled then return "OFF", REAL_STYLE.dim end
            if S.cc_done then return "DONE", REAL_STYLE.ok end
            return "PENDING", REAL_STYLE.warn
        end,
    },
    {
        label = "LOAD SHED",
        value = function()
            local text = string.format("%d/%d  %.1f V",
                S.shed_steps, REAL_CONFIG.elec_max_sheds, real_bus_v[0] or 0.0)
            return text, S.shed_steps > 0 and REAL_STYLE.warn or REAL_STYLE.value
        end,
    },
    { label = "BRAKES", value = hud_brakes },
    { label = "ICING", value = hud_icing },
    {
        label = "OVERSPEED",
        value = function()
            if S.overspeed_warned then return "OVER", REAL_STYLE.bad end
            return "OK", REAL_STYLE.ok
        end,
    },
    {
        label = "TAKEOFF CFG",
        value = function()
            if S.to_issue ~= "" then return hud_fit(S.to_issue, 26), REAL_STYLE.warn end
            return "OK", REAL_STYLE.ok
        end,
    },
    { label = "TAKEOFF TRIM", value = hud_trim },
    { label = "FUEL BAL", value = hud_fuel },
    { label = "WEIGHT", value = hud_weight },
    { label = "CROSSWIND", value = hud_xwind },
    {
        label = "APPROACH",
        value = function()
            if S.approach_note == "-" then return "-", REAL_STYLE.dim end
            if S.approach_note == "STABLE" then return "STABLE", REAL_STYLE.ok end
            return hud_fit(S.approach_note, 26), REAL_STYLE.warn
        end,
    },
    {
        label = "LAST",
        value = function()
            return hud_fit(HUD_INFO.last_event, 26), REAL_STYLE.dim
        end,
    },
}

local function hud_height()
    local st = REAL_STYLE
    return st.header_h + 10 + #REAL_HUD_ROWS * st.row_h + st.footer_h + 8
end

function real_set_hud(on)
    REAL_CONFIG.hud_enabled = (on == true)
    logMsg("Citation X Realism: HUD " .. (REAL_CONFIG.hud_enabled and "ON" or "OFF"))
end

function real_draw()
    if not REAL_CONFIG.hud_enabled then return end
    local sw = SCREEN_WIDTH  or 1920
    local sh = SCREEN_HIGHT or 1080
    local st = REAL_STYLE
    local x, w, pad = st.x, st.width, st.pad
    local top = sh - st.top
    local box_h = hud_height()
    local bottom = top - box_h
    if bottom < 8 then bottom = 8 end

    XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
    hud_hits = {}

    hud_bar(x, bottom, x + w, top, st.bg)
    hud_bar(x, top - 1, x + w, top, st.border)
    hud_bar(x, bottom, x + 1, top, st.border)
    hud_bar(x + w - 1, bottom, x + w, top, st.border)
    hud_bar(x, bottom, x + w, bottom + 1, st.border)
    hud_bar(x, top - st.header_h, x + w, top, st.header_bg)
    hud_bar(x, top - st.header_h, x + w, top - st.header_h + 2, st.border)

    hud_text(x + pad, top - 25, "REALISM", 18, st.title)
    hud_text_right(x + w - pad, top - 22, "CITATION X", 10, st.sub)

    local y = top - st.header_h - 20
    for i = 1, #REAL_HUD_ROWS do
        local row = REAL_HUD_ROWS[i]
        local text, col = row.value()
        col = col or st.value
        hud_text(x + pad, y, row.label, 12, st.label)
        hud_text_right(x + w - pad, y, text, 12, col)
        if row.act then
            hud_bar(x + 4, y + 5, x + 6, y + 8, st.border)
            hud_hits[#hud_hits + 1] = {
                x0 = x, x1 = x + w,
                y0 = y - 4, y1 = y + 17,
                act = row.act,
            }
        end
        y = y - st.row_h
    end

    local by0 = bottom + 8
    local by1 = by0 + st.footer_h - 12
    local mid = x + w / 2
    hud_bar(x + pad, by0, mid - 4, by1, st.btn)
    hud_bar(mid + 4, by0, x + w - pad, by1, st.btn)
    hud_text(x + pad + 9, by0 + 6, "TEST CALLOUT", 10, st.value)
    local hide_w = measure_string("HIDE HUD", "Helvetica_10") or 44
    hud_text(x + w - pad - 9 - hide_w, by0 + 6, "HIDE HUD", 10, st.value)

    hud_hits[#hud_hits + 1] = {
        x0 = x + pad, x1 = mid - 4, y0 = by0, y1 = by1,
        act = function() real_test_callout() end,
    }
    hud_hits[#hud_hits + 1] = {
        x0 = mid + 4, x1 = x + w - pad, y0 = by0, y1 = by1,
        act = function() real_set_hud(false) end,
    }
end

function real_mouse_click()
    if not REAL_CONFIG.hud_enabled then return end
    if MOUSE_STATUS ~= "down" then return end
    for i = 1, #hud_hits do
        local h = hud_hits[i]
        if MOUSE_X >= h.x0 and MOUSE_X <= h.x1
            and MOUSE_Y >= h.y0 and MOUSE_Y <= h.y1 then
            h.act()
            RESUME_MOUSE_CLICK = true
            return
        end
    end
end

-- ------------------------------------------------------------- LIFECYCLE -----
function real_init()
    load_callouts()
    logMsg("Citation X Realism: loaded (" .. tostring(SCRIPT_DIRECTORY) .. ")")
    real_status_report()
    if sound_bus ~= "none" then
        notify(string.format("loaded, %d callouts on %s bus",
            (function() local n = 0 for _ in pairs(callout_id) do n = n + 1 end return n end)(),
            sound_bus), "REALISM PACK READY")
    end
end

real_init()
do_every_frame("real_frame()")
do_every_draw("real_draw()")
do_on_mouse_click("real_mouse_click()")
do_on_exit("real_shutdown()")

function real_shutdown()
    release_handling()
    if real_brake_fan == 1 then real_brake_fan = 0 end
end

create_command("CitationXRealism/toggle",
    "Citation X Realism: enable or disable the realism pack",
    "real_set_enabled(not REAL_CONFIG.enabled)", "", "")
create_command("CitationXRealism/test_callout",
    "Citation X Realism: play a test callout",
    "real_test_callout()", "", "")
create_command("CitationXRealism/status",
    "Citation X Realism: write the status to Log.txt",
    "real_status_report()", "", "")
create_command("CitationXRealism/handling",
    "Citation X Realism: toggle the pilot-input handling curve",
    "real_set_handling(not REAL_CONFIG.handling_enabled)", "", "")
create_command("CitationXRealism/hud",
    "Citation X Realism: show or hide the realism panel",
    "real_set_hud(not REAL_CONFIG.hud_enabled)", "", "")

add_macro("Citation X Realism: enable/disable", "real_set_enabled(not REAL_CONFIG.enabled)")
add_macro("Citation X Realism: test callout", "real_test_callout()")
add_macro("Citation X Realism: status report", "real_status_report()")
add_macro("Citation X Realism: handling curve", "real_set_handling(not REAL_CONFIG.handling_enabled)")
add_macro("Citation X Realism: realism panel", "real_set_hud(not REAL_CONFIG.hud_enabled)")
