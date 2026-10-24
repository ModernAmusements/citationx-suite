-- ============================================================================
--  CESSNA CITATION X — REALISM PACK
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
--  Version 1.0
-- ----------------------------------------------------------------------------
--  Adds the things the aircraft and X-Plane do not do on their own. It draws
--  NOTHING on screen: callouts are audio, everything else goes to Log.txt.
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
--       speedbrake, landing flaps).
--    8. Stabilised-approach gate at 1000 ft AGL, with the reason when unstable.
--    9. GEAR DOWN confirmation when the gear locks down in flight.
--   10. ANTI-ICE OFF advisory while icing conditions exist.
--   11. CABIN ALTITUDE warning above 10 000 ft cabin altitude.
--
--  Speeds (Citation X POM, Operating-Speeds page):
--    Vr 145 · Vref 132 · Vfe 180 · Vle/Vlo 210 · Vmo 270 (<8000 ft) / 350
--    Mmo 0.935 · Vso 115 · Vs1 136
--  V1 is not published in the POM table; it is a configurable advisory value.
--
--  Audio files live in Scripts/CitationX_Callouts/. If a file or the FlyWithLua
--  sound API is missing, the callout still goes to Log.txt — no error.
-- ============================================================================

REAL_CONFIG = {
    enabled            = true,

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
    flap15_vfe_kt      = 250,   -- 15 deg detent (POM publishes 180 for full)
    flap_full_ratio    = 0.60,

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
    to_flap_max_ratio  = 0.80,  -- more flap than this is a landing setting

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

real_brake_j = dataref_table("sim/flightmodel2/gear/brake_absorbed_J")
real_gear    = dataref_table("sim/flightmodel2/gear/deploy_ratio")
real_bus_v   = dataref_table("sim/cockpit2/electrical/bus_volts")
real_gen_on  = dataref_table("sim/cockpit2/electrical/generator_on")
real_battery = dataref_table("sim/cockpit2/electrical/battery_on")

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

-- Log-only + 2 s toast. The toast is borrowed from the MasterSuite; without
-- that script loaded the notice stays in Log.txt, and this file still registers
-- no draw callback of its own.
local function notify(text, toast_text)
    logMsg("Citation X Realism: " .. text)
    if not REAL_CONFIG.toasts_enabled then return end
    local fn = _G.citationx_toast
    if type(fn) == "function" then pcall(fn, toast_text or text) end
end

local function callout(key, text)
    logMsg("Citation X Realism: CALLOUT " .. text)
    local idx = callout_id[key]
    if idx then play_callout_sound(idx) end
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
}

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
    if thr < 0.2 then S.to_config_armed = true end
    if not S.to_config_armed or thr < REAL_CONFIG.to_throttle_ratio then return end
    S.to_config_armed = false

    local issues = {}
    if (real_park_brake or 0.0) > 0.1 then issues[#issues + 1] = "PARK BRAKE" end
    if (real_spoiler or 0.0) > 0.1 then issues[#issues + 1] = "SPEEDBRAKE" end
    if (real_flap_rat or 0.0) > REAL_CONFIG.to_flap_max_ratio then
        issues[#issues + 1] = "FLAPS"
    end
    if #issues == 0 then return end

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
        callout("stable", "STABLE")
        notify(string.format("stabilised at %.0f ft, %.0f kt", agl_ft, ias),
            "STABLE APPROACH")
    else
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

-- -------------------------------------------------------------- OVERSPEED ----
local function overspeed_tick(now)
    if not REAL_CONFIG.overspeed_enabled then return end
    local ias  = real_ias_kt or 0.0
    local flap = real_flap_rat or 0.0
    local gear = real_gear[0] or 0.0

    local vfe = REAL_CONFIG.vfe_kt
    if flap > 0.05 and flap <= REAL_CONFIG.flap_full_ratio then
        vfe = REAL_CONFIG.flap15_vfe_kt
    end

    if flap > 0.05 and ias > vfe + 3.0 then
        if not S.flap_warned then
            S.flap_warned = true
            callout("flap_over", "FLAP OVERSPEED")
            notify(string.format("flap overspeed %.0f kt (limit %.0f)", ias, vfe),
                string.format("FLAP OVERSPEED %.0f KT (MAX %.0f)", ias, vfe))
        end
    elseif ias < vfe - 3.0 then
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
    if not REAL_CONFIG.enabled then return end
    local now = real_sim_time or 0.0
    if now - S.last_tick < 0.1 then return end
    S.last_tick = now

    local agl_ft = (real_agl_m or 0.0) * 3.28084

    callouts_tick(now, agl_ft)
    takeoff_config_tick(now)
    vmo_tick(now)
    stable_tick(now, agl_ft)
    gear_down_tick()
    electrical_tick(now)
    brakes_tick(now)
    overspeed_tick(now)
    icing_tick(now)
    anti_ice_tick(now)
    cabin_alt_tick(now)

    S.was_ground = (real_on_ground == 1)
end

-- -------------------------------------------------------------- CONTROLS -----
function real_set_enabled(on)
    REAL_CONFIG.enabled = (on == true)
    logMsg("Citation X Realism: " .. (REAL_CONFIG.enabled and "ON" or "OFF"))
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
do_on_exit("real_shutdown()")

function real_shutdown()
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

add_macro("Citation X Realism: enable/disable", "real_set_enabled(not REAL_CONFIG.enabled)")
add_macro("Citation X Realism: test callout", "real_test_callout()")
add_macro("Citation X Realism: status report", "real_status_report()")
