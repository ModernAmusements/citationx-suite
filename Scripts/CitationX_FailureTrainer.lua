-- ============================================================================
--  CESSNA CITATION X FAILURE TRAINER + QRH CHECKLIST
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  Injects realistic failure scenarios into the C750 and shows the matching
--  QRH-style checklist on screen, like the real airplane:
--
--    * click a scenario on the panel (or bind its command) to inject it
--    * the checklist appears with numbered steps
--    * each step auto-checks itself [X] the moment the switch is in the
--      correct position - verified against the aircraft's own laminar/CitX
--      datarefs, so you really have to fly the procedure in the cockpit
--    * clicking a step row also fires its command (a "do it" shortcut)
--    * advisory rows (monitors) never block completion
--    * when every mandatory step is done, click CLEAR FAILURE to restore
--
--  Scenarios:
--    ENGINE FIRE L   GENERATOR L TRIP   BLEED AIR L FAILURE
--    BOOST PUMP L    FLAMEOUT L (restart)   APU FIRE   HYD PUMP A
--    FLAP ACTUATOR   GEAR INDICATION   HYD PUMP B   APU FAIL TO START
--    PITOT / STATIC  ELEVATOR TRIM RUNAWAY   CABIN DECOMPRESSION
--    + RANDOM (bind it to a joystick button for surprise failures)
--
--  Commands (bindable in Settings > Keyboard/Joystick):
--    CitationXQRH/toggle_panel        CitationXQRH/random
--    CitationXQRH/clear               CitationXQRH/inject_<scenario key>
--
--  Failure injection uses X-Plane's own failure system (rel_engfir0, ...) and
--  the CitX switch commands, so the aircraft responds exactly as it should.
-- ============================================================================

TRAINER_CONFIG = {
    panel_enabled    = false,   -- hidden at load; the Master Suite hub opens it
    panel_x          = 24,     -- panel anchor; drag writes panel_top
    panel_top        = nil,    -- nil = bottom-left (60 px) on first draw
    panel_w          = 430,
    require_c750     = true,   -- only inject failures when flying the C750
    row_h            = 21,
}

-- Geometry only; colours come from the shared MA dark field (CX).
ST = {
    bg         = CX.bg,
    header_bg  = CX.header_bg,
    header_act = CX.header_act,
    border     = CX.border,
    hairline   = CX.hairline,
    title      = CX.title,
    sub        = CX.sub,
    label      = CX.label,
    value      = CX.value,
    dim        = CX.dim,
    ok         = CX.ok,
    warn       = CX.warn,
    alert      = CX.alert,
    btn        = CX.btn,
    -- legacy aliases used by the existing drawing code
    accent     = CX.accent,
    subhdr     = CX.sub,
    footer_bg  = CX.footer_bg,
    footer_fg  = CX.footer_fg,
    header_h   = 34,
    footer_h   = 34,
    pad        = 14,
}

-- --------------------------------------------------------------- DATAREFS ---
-- X-Plane failure system (writable: this is how scenarios are injected).
dataref("ft_fail_engfir0", "sim/operation/failures/rel_engfir0", "writable")
dataref("ft_fail_genera0", "sim/operation/failures/rel_genera0", "writable")
dataref("ft_fail_engfla0", "sim/operation/failures/rel_engfla0", "writable")
dataref("ft_fail_bleed_l", "sim/operation/failures/rel_bleed_air_lft", "writable")
dataref("ft_fail_apu",     "sim/operation/failures/rel_apu_fire", "writable")
dataref("ft_fail_apu_start", "sim/operation/failures/rel_apu", "writable")
dataref("ft_fail_gear_ind",  "sim/operation/failures/rel_gear_ind", "writable")
dataref("ft_fail_pitot",     "sim/operation/failures/rel_pitot", "writable")
dataref("ft_fail_trim_run",  "sim/operation/failures/rel_elv_trim_run", "writable")
dataref("ft_fail_depres",    "sim/operation/failures/rel_depres_slow", "writable")

-- Standard state used by the checklist verifiers (1-based array slots).
dataref("ft_throttle_l",   "sim/cockpit2/engine/actuators/throttle_ratio", "readonly", 1)
dataref("ft_ext_bottle_l", "sim/cockpit2/engine/actuators/fire_extinguisher_on", "readonly", 1)
dataref("ft_master_caution", "sim/cockpit2/annunciators/master_caution", "readonly")
dataref("ft_eng_fire_l",     "sim/cockpit2/annunciators/engine_fires", "readonly", 1)
dataref("ft_on_ground",      "sim/flightmodel/failures/onground_any", "readonly")
dataref("ft_sim_time",       "sim/time/total_running_time_sec", "readonly")
dataref("ft_ias_kts",        "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("ft_elev_m",         "sim/flightmodel/position/elevation", "readonly")
dataref("ft_ap_on",          "sim/cockpit2/autopilot/autopilot_on", "readonly")
dataref("ft_cabin_alt_ft",   "sim/cockpit2/pressurization/indicators/cabin_altitude_ft", "readonly")
dataref("ft_gear_handle",    "sim/cockpit2/controls/gear_handle_down", "readonly")

-- CitX runtime datarefs: they only exist once the C750 is loaded, so they are
-- resolved lazily with XPLMFindDataRef and polled in the frame loop (reading
-- in a draw callback is not allowed).
CITX_TR = {
    guard_l    = "laminar/CitX/engine_fire/LH_eng_fire_guard",
    button_l   = "laminar/CitX/engine_fire/LH_eng_fire_button",
    bat_l      = "laminar/CitX/electrical/battery_left",
    bat_r      = "laminar/CitX/electrical/battery_right",
    gen_l      = "laminar/CitX/electrical/generator_left",
    ext_pwr    = "laminar/CitX/electrical/ext_pwr",
    boost_l    = "laminar/CitX/fuel/boost_left",
    crossfeed  = "laminar/CitX/fuel/crossfeed",
    transfer_l = "laminar/CitX/fuel/transfer_left",
    cabin_dump = "laminar/CitX/pressurization/cabin_dump",
    pac_bleed  = "laminar/CitX/pressurization/pac_bleed",
    iso_valve  = "laminar/CitX/bleedair/iso_valve",
    ign_l      = "laminar/CitX/engine/ignition_switch_left",
    fadec_l    = "laminar/CitX/engine/fadec_switch_left",
    apu_master = "laminar/CitX/APU/master_switch",
    apu_gen    = "laminar/CitX/APU/gen_switch",
    aux_pump   = "laminar/CitX/hydraulics/aux_pump",
    unload_a   = "laminar/CitX/hydraulics/unload_pump_A",
    unload_b   = "laminar/CitX/hydraulics/unload_pump_B",
    antiskid   = "laminar/CitX/hydraulics/antiskid",
    flap_handle = "laminar/CitX/flaps_slats/handle_ratio",
    pitot_l    = "laminar/CitX/ice/pitot_static_left",
    pitot_r    = "laminar/CitX/ice/pitot_static_right",
    apu_starter = "laminar/CitX/APU/starter_switch",
    pass_oxy   = "laminar/CitX/oxygen/pass_oxy",
    press_manual = "laminar/CitX/pressurization/manual",
}

-- Failure enums already bound writable by another suite script must be written
-- through XPLM: a second writable dataref() for the same ref quarantines this
-- script. CitationX_Realism.lua owns rel_flap_act (overspeed damage).
local ft_lazy_refs = {}

local function ft_fail_lazy(ref, value)
    local h = ft_lazy_refs[ref]
    if not h then
        h = XPLMFindDataRef(ref)
        ft_lazy_refs[ref] = h
    end
    if h and XPLMSetDatai then XPLMSetDatai(h, value) end
end

local tr_ref  = {}   -- lazily resolved XPLM ref handles
local TRV     = {}   -- polled values (frame loop snapshot)
local tr_retry_at = 0

-- ------------------------------------------------------------ SCENARIOS ----
-- Each step: { label, cmd (optional, fired on row click), advisory (optional),
--              check(v) -> true when the step is correctly executed }.
-- v is the polled value table TRV / frame-loop globals.
local SCENARIOS = {
    {
        key = "engine_fire_l",
        title = "ENGINE FIRE - L ENGINE",
        condition = "L ENGINE FIRE WARNING - INFLT / GND",
        inject = function() ft_fail_engfir0 = 6 end,
        clear  = function() ft_fail_engfir0 = 0 end,
        steps = {
            { label = "THROTTLE L ....................... CUT",
              check = function() return (ft_throttle_l or 1.0) < 0.05 end },
            { label = "MASTER CAUTION ................... CLEAR",
              cmd = "sim/annunciator/clear_master_caution",
              check = function() return (ft_master_caution or 0) < 0.5 end },
            { label = "FIRE GUARD L ..................... OPEN",
              cmd = "laminar/CitX/engine_fire/cmd_LH_eng_fire_guard",
              check = function() return (TRV.guard_l or 0) > 0.9 end },
            { label = "FIRE BUTTON L .................... PUSH",
              cmd = "laminar/CitX/engine_fire/cmd_LH_eng_fire_push",
              check = function() return (TRV.button_l or 0) > 0.9 end },
            { label = "EXTINGUISHER L ................... DISCHARGE",
              cmd = "laminar/CitX/engine_fire/cmd_LH_fire_ext_push",
              check = function() return (ft_ext_bottle_l or 0) > 0.5 end },
        },
    },
    {
        key = "gen_trip_l",
        title = "GENERATOR L - TRIP / FAILURE",
        condition = "L GENERATOR OFF - BUS TRANSFER",
        inject = function() ft_fail_genera0 = 6 end,
        clear  = function() ft_fail_genera0 = 0 end,
        steps = {
            { label = "BATTERY L ....................... ON",
              cmd = "laminar/CitX/electrical/cmd_battery_left_toggle",
              check = function() return (TRV.bat_l or 0) > 0.5 end },
            { label = "BATTERY R ....................... ON",
              cmd = "laminar/CitX/electrical/cmd_battery_right_toggle",
              check = function() return (TRV.bat_r or 0) > 0.5 end },
            { label = "GENERATOR L ..................... OFF",
              cmd = "laminar/CitX/electrical/cmd_generator_left_dwn",
              check = function() return (TRV.gen_l or 1) <= 0 end },
            { label = "GENERATOR L ..................... ON (RESET)",
              cmd = "laminar/CitX/electrical/cmd_generator_left_up",
              check = function() return (TRV.gen_l or 0) >= 1 end },
            { label = "LOAD SHED / EICAS ............... MONITOR",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "bleed_air_l",
        title = "BLEED AIR L - FAILURE",
        condition = "L ENGINE BLEED AIR PRESSURE LOW",
        inject = function() ft_fail_bleed_l = 6 end,
        clear  = function() ft_fail_bleed_l = 0 end,
        steps = {
            { label = "PAC BLEED ....................... NORM",
              cmd = "laminar/CitX/pressurization/cmd_pac_bleed_dwn",
              check = function() return math.abs((TRV.pac_bleed or 0)) < 0.25 end },
            { label = "ISO VALVE ....................... OPEN",
              cmd = "laminar/CitX/pressurization/cmd_iso_vlv_toggle",
              check = function() return (TRV.iso_valve or 0) > 0.5 end },
            { label = "CABIN DUMP ...................... CLOSED",
              cmd = "laminar/CitX/pressurization/cmd_cabin_dump_toggle",
              check = function() return (TRV.cabin_dump or 0) < 0.5 end },
            { label = "CABIN ALT / RATE ............... MONITOR",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "boost_pump_l",
        title = "FUEL BOOST PUMP L - FAILURE",
        condition = "L BOOST PUMP LOW PRESSURE",
        inject = function() command_once("laminar/CitX/fuel/cmd_boost_left_dwn") end,
        clear  = function() command_once("laminar/CitX/fuel/cmd_boost_left_up") end,
        steps = {
            { label = "BOOST L ........................ OFF",
              cmd = "laminar/CitX/fuel/cmd_boost_left_dwn",
              check = function() return (TRV.boost_l or 1) <= 0 end },
            { label = "CROSSFEED ....................... OPEN",
              cmd = "laminar/CitX/fuel/cmd_crossfeed_left",
              check = function() return math.abs(TRV.crossfeed or 0) > 0.5 end },
            { label = "FUEL TRANSFER L ................. NORM",
              advisory = true,
              check = function() return true end },
            { label = "FUEL QTY L ...................... MONITOR",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "flameout_l",
        title = "L ENGINE FLAMEOUT - RESTART",
        condition = "L ENGINE FLAMEOUT - RESTART PER QRH",
        inject = function() ft_fail_engfla0 = 6 end,
        clear  = function() ft_fail_engfla0 = 0 end,
        steps = {
            { label = "FADEC L .......................... ON",
              cmd = "laminar/CitX/engine/cmd_fadec_switch_left_up",
              check = function() return (TRV.fadec_l or 0) > 0.5 end },
            { label = "IGNITION L ...................... ON",
              cmd = "laminar/CitX/engine/cmd_ignition_switch_left_up",
              check = function() return (TRV.ign_l or 0) > 0.5 end },
            { label = "APU MASTER ...................... ON",
              cmd = "laminar/CitX/APU/master_switch_toggle",
              check = function() return (TRV.apu_master or 0) > 0.5 end },
            { label = "APU GENERATOR ................... ON",
              cmd = "laminar/CitX/APU/gen_switch_up",
              check = function() return (TRV.apu_gen or 0) > 0.5 end },
            { label = "RELIGHT - CLEAR FAILURE FIRST .. NOTE",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "apu_fire",
        title = "APU FIRE",
        condition = "APU FIRE WARNING",
        inject = function() ft_fail_apu = 6 end,
        clear  = function() ft_fail_apu = 0 end,
        steps = {
            { label = "APU MASTER ...................... OFF",
              cmd = "laminar/CitX/APU/master_switch_toggle",
              check = function() return (TRV.apu_master or 1) < 0.5 end },
            { label = "APU GENERATOR ................... OFF",
              cmd = "laminar/CitX/APU/gen_switch_up",
              check = function() return (TRV.apu_gen or 1) < 0.5 end },
            { label = "EXTERNAL POWER ................. ON",
              cmd = "laminar/CitX/electrical/cmd_ext_pwr_toggle",
              check = function() return (TRV.ext_pwr or 0) > 0.5 end },
            { label = "BATTERY L ....................... ON",
              cmd = "laminar/CitX/electrical/cmd_battery_left_toggle",
              check = function() return (TRV.bat_l or 0) > 0.5 end },
        },
    },
    {
        key = "hyd_pump_a",
        title = "HYDRAULIC SYSTEM A - PUMP FAILURE",
        condition = "HYD A PUMP - LOW PRESSURE",
        inject = function() command_once("laminar/CitX/hydraulics/cmd_unload_pump_A_toggle") end,
        clear  = function() command_once("laminar/CitX/hydraulics/cmd_unload_pump_A_toggle") end,
        steps = {
            { label = "AUXILIARY PUMP ................. ON",
              cmd = "laminar/CitX/hydraulics/cmd_aux_pump_toggle",
              check = function() return (TRV.aux_pump or 0) > 0.5 end },
            { label = "PUMP A UNLOAD .................. CHECK",
              check = function() return (TRV.unload_a or 0) > 0.5 end },
            { label = "ANTISKID ....................... NORM",
              cmd = "laminar/CitX/hydraulics/cmd_antiskid_toggle",
              check = function() return (TRV.antiskid or 0) < 0.5 end },
        },
    },
    {
        key = "hyd_pump_b",
        title = "HYDRAULIC SYSTEM B - PUMP FAILURE",
        condition = "HYD B PUMP - LOW PRESSURE",
        inject = function() command_once("laminar/CitX/hydraulics/cmd_unload_pump_B_toggle") end,
        clear  = function() command_once("laminar/CitX/hydraulics/cmd_unload_pump_B_toggle") end,
        steps = {
            { label = "AUXILIARY PUMP ................. ON",
              cmd = "laminar/CitX/hydraulics/cmd_aux_pump_toggle",
              check = function() return (TRV.aux_pump or 0) > 0.5 end },
            { label = "PUMP B UNLOAD .................. CHECK",
              check = function() return (TRV.unload_b or 0) > 0.5 end },
            { label = "ANTISKID ....................... NORM",
              cmd = "laminar/CitX/hydraulics/cmd_antiskid_toggle",
              check = function() return (TRV.antiskid or 0) < 0.5 end },
        },
    },
    {
        key = "flap_actuator",
        title = "FLAP ACTUATOR - FAILURE",
        condition = "FLAP DISAGREE - ASYMMETRIC / JAMMED",
        -- Realism binds rel_flap_act writable for overspeed damage, so this
        -- script writes the same enum through XPLM instead of binding it.
        inject = function() ft_fail_lazy("sim/operation/failures/rel_flap_act", 6) end,
        clear  = function() ft_fail_lazy("sim/operation/failures/rel_flap_act", 0) end,
        steps = {
            { label = "FLAP LEVER ...................... 15",
              check = function() return math.abs((TRV.flap_handle or 0) - 0.75) < 0.13 end },
            { label = "AIRSPEED ....................... 200 KIAS MAX",
              check = function() return (ft_ias_kts or 0) < 200 end },
            { label = "FLAP RESET ANNUNCIATOR ......... CHECK",
              advisory = true,
              check = function() return true end },
            { label = "LANDING DISTANCE ............... INCREASE",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "gear_indication",
        title = "LANDING GEAR - INDICATION FAILURE",
        condition = "GEAR INDICATION DISAGREES WITH HANDLE",
        inject = function() ft_fail_gear_ind = 6 end,
        clear  = function() ft_fail_gear_ind = 0 end,
        steps = {
            { label = "GEAR LEVER ....................... DOWN",
              check = function() return (ft_gear_handle or 0) > 0.5 end },
            { label = "GEAR DOWN .................... VISUAL / TOWER",
              advisory = true,
              check = function() return true end },
            { label = "AIRSPEED ......................... 210 KIAS MAX",
              check = function() return (ft_ias_kts or 0) < 210 end },
            { label = "LAND ............................ NORMAL",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "apu_fail_start",
        title = "APU - FAILURE TO START",
        condition = "APU FAULT - NO START / NO BLEED",
        inject = function() ft_fail_apu_start = 6 end,
        clear  = function() ft_fail_apu_start = 0 end,
        steps = {
            { label = "APU MASTER ...................... OFF",
              cmd = "laminar/CitX/APU/master_switch_toggle",
              check = function() return (TRV.apu_master or 1) < 0.5 end },
            { label = "APU STARTER ..................... OFF",
              cmd = "laminar/CitX/APU/starter_switch_dwn",
              check = function() return (TRV.apu_starter or 1) < 0.5 end },
            { label = "APU GENERATOR ................... OFF",
              cmd = "laminar/CitX/APU/gen_switch_dwn",
              check = function() return (TRV.apu_gen or 1) < 0.5 end },
            { label = "EXTERNAL POWER ................. ON",
              cmd = "laminar/CitX/electrical/cmd_ext_pwr_toggle",
              check = function() return (TRV.ext_pwr or 0) > 0.5 end },
        },
    },
    {
        key = "pitot_static",
        title = "PITOT / STATIC - BLOCKAGE",
        condition = "AIR DATA DISAGREES - PITOT HEAT OFF",
        inject = function() ft_fail_pitot = 6 end,
        clear  = function() ft_fail_pitot = 0 end,
        steps = {
            { label = "PITOT HEAT L ................... ON",
              cmd = "laminar/CitX/ice/cmd_pitot_static_left_toggle",
              check = function() return (TRV.pitot_l or 0) > 0.5 end },
            { label = "PITOT HEAT R ................... ON",
              cmd = "laminar/CitX/ice/cmd_pitot_static_right_toggle",
              check = function() return (TRV.pitot_r or 0) > 0.5 end },
            { label = "STANDBY INSTRUMENTS ............ CROSS-CHECK",
              advisory = true,
              check = function() return true end },
            { label = "AIRSPEED / ALTITUDE ............ STANDBY",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "trim_runaway",
        title = "ELEVATOR TRIM - RUNAWAY",
        condition = "UNCOMMANDED PITCH TRIM - AP OFF",
        inject = function() ft_fail_trim_run = 6 end,
        clear  = function() ft_fail_trim_run = 0 end,
        steps = {
            { label = "AUTOPILOT ...................... DISCONNECT",
              cmd = "sim/autopilot/servos_fdir_off",
              check = function() return (ft_ap_on or 0) < 0.5 end },
            { label = "CONTROL WHEEL .................. HOLD",
              advisory = true,
              check = function() return true end },
            { label = "TRIM ........................... OPPOSE",
              advisory = true,
              check = function() return true end },
            { label = "AIRSPEED ....................... REDUCE",
              advisory = true,
              check = function() return true end },
        },
    },
    {
        key = "cabin_decompression",
        title = "CABIN - SLOW DECOMPRESSION",
        condition = "CABIN ALTITUDE RISING - O2 REQUIRED",
        inject = function() ft_fail_depres = 6 end,
        clear  = function() ft_fail_depres = 0 end,
        steps = {
            { label = "PASSENGER OXYGEN ............... ON",
              cmd = "laminar/CitX/oxygen/cmd_pass_oxy_up",
              check = function() return (TRV.pass_oxy or 0) > 0.5 end },
            { label = "PRESSURIZATION ................. MANUAL",
              cmd = "laminar/CitX/pressurization/cmd_manual_toggle",
              check = function() return (TRV.press_manual or 0) > 0.5 end },
            { label = "CABIN ALTITUDE ........... BELOW 10 000 FT",
              check = function() return (ft_cabin_alt_ft or 0) < 10000 end },
            { label = "DESCENT .................. BELOW 10 000 FT",
              check = function() return (ft_elev_m or 0) * 3.28084 < 10000 end },
        },
    },
}

-- ---------------------------------------------------------------- STATE ----
local active       = nil   -- scenario table when one is active
local step_done    = {}    -- [i] = true/false per step of the active scenario
local proc_done    = false
local qrh_rows     = {}    -- clickable rects, rebuilt each draw
local toast_text   = nil
local toast_until  = 0
local is_c750      = false

-- --------------------------------------------------------------- HELPERS ---
local function qrh_toast(text)
    toast_text  = text
    toast_until = (ft_sim_time or 0) + 2.5
end

local function scenario_done(sc)
    for i, step in ipairs(sc.steps) do
        if not step.advisory and not step_done[i] then return false end
    end
    return true
end

local function resolve_citx_refs()
    for name, path in pairs(CITX_TR) do
        if not tr_ref[name] then
            tr_ref[name] = XPLMFindDataRef(path)
        end
    end
end

local function poll_citx_refs()
    for name, _ in pairs(CITX_TR) do
        local h = tr_ref[name]
        if h then TRV[name] = XPLMGetDataf(h) end
    end
end

function qrh_inject(sc)
    if TRAINER_CONFIG.require_c750 and not is_c750 then
        qrh_toast("FAILURE TRAINER: C750 ONLY")
        return
    end
    if active then
        active.clear()
    end
    active = sc
    step_done = {}
    proc_done = false
    sc.inject()
    qrh_toast("FAILURE INJECTED: " .. sc.title)
    logMsg("Citation X QRH: injected " .. sc.key)
end

function qrh_inject_by_key(key)
    for _, sc in ipairs(SCENARIOS) do
        if sc.key == key then qrh_inject(sc) return end
    end
end

function qrh_inject_random()
    qrh_inject(SCENARIOS[math.random(#SCENARIOS)])
end

-- Read-only view for the offline harnesses (panel geometry, smoke tests).
function qrh_scenarios()
    return SCENARIOS
end

function qrh_clear()
    if active then
        active.clear()
        logMsg("Citation X QRH: cleared " .. active.key)
        active = nil
        step_done = {}
        proc_done = false
        qrh_toast("FAILURE CLEARED")
    end
end

function qrh_toggle_panel(on)
    if on == nil then
        TRAINER_CONFIG.panel_enabled = not TRAINER_CONFIG.panel_enabled
    else
        TRAINER_CONFIG.panel_enabled = (on == true)
    end
    qrh_toast("QRH PANEL: " .. (TRAINER_CONFIG.panel_enabled and "ON" or "OFF"))
end

-- ----------------------------------------------------------- FRAME LOOP ----
function qrh_frame()
    is_c750 = (PLANE_ICAO == "C750")

    local now = ft_sim_time or 0
    if now >= tr_retry_at then
        tr_retry_at = now + 5.0
        resolve_citx_refs()
    end
    poll_citx_refs()

    if active then
        for i, step in ipairs(active.steps) do
            local ok, res = pcall(step.check)
            step_done[i] = ok and res or false
        end
        proc_done = scenario_done(active)
    end
end

-- ------------------------------------------------------------- DRAWING -----
local function bar(x, y0, y1, w, color, alpha)
    cx_bar_w(x, y0, y1, w, color, alpha)
end

local function txt(x, y, text, color, size)
    cx_text(x, y, text, size or 12, color)
end

local function txt_right(right_x, y, text, color, size)
    cx_text_right(right_x, y, text, size or 12, color)
end

-- Keep long QRH step labels inside the panel (the 460 px original had room;
-- the 430 px shell needs a guard for the dotted-line steps).
local function qrh_fit(text, max_px, size)
    local s = tostring(text or "")
    if cx_measure(s, size or 12) <= max_px then return s end
    while #s > 1 and cx_measure(s .. "..", size or 12) > max_px do s = s:sub(1, -2) end
    return s .. ".."
end

local qrh_header_rect = nil
local qrh_footer_rect = nil
local qrh_drag = { active = false, dx = 0, dy = 0 }

function qrh_draw()
    if not TRAINER_CONFIG.panel_enabled then
        qrh_drag.active = false
        return
    end
    qrh_rows = {}

    local cfg = TRAINER_CONFIG
    local st  = ST
    local w   = cfg.panel_w
    local rh  = cfg.row_h
    local sw  = SCREEN_WIDTH or 1920
    local sh  = SCREEN_HIGHT or 1080

    -- measure panel height from content
    local h
    if active then
        h = st.header_h + 30 + (#active.steps) * rh + 20 + st.footer_h + 8
        if proc_done then h = h + rh + 8 end
    else
        h = st.header_h + 20 + (#SCENARIOS + 1) * rh + st.footer_h + 8
    end

    local x = math.max(0, math.min(cfg.panel_x, sw - w))
    local top = cfg.panel_top or (60 + h)
    top = math.max(h + 8, math.min(top, sh - 4))
    cfg.panel_x, cfg.panel_top = x, top
    local bottom = top - h

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    -- black shell: body, 1 px border, 34 px header
    bar(x, bottom, top, w, st.bg)
    bar(x, top - 1, top, w, st.border)
    bar(x, bottom, top, 1, st.border)
    bar(x + w - 1, bottom, top, 1, st.border)
    bar(x, bottom, bottom + 1, w, st.border)
    bar(x, top - st.header_h, top, w, active and st.header_act or st.header_bg)
    bar(x, top - st.header_h, top - st.header_h + 2, w,
        active and st.alert or st.border)
    if active then
        txt(x + st.pad, top - 25,
            qrh_fit("QRH  " .. active.title, w - 2 * st.pad, 18), st.alert, 18)
    else
        txt(x + st.pad, top - 25, "FAILURE TRAINER", st.title, 18)
        txt_right(x + w - st.pad, top - 22, "SELECT SCENARIO", st.sub, 10)
    end
    qrh_header_rect = { x0 = x, x1 = x + w, y0 = top - st.header_h, y1 = top }

    local y = top - st.header_h

    if active then
        -- condition line
        txt(x + st.pad, y - 16,
            qrh_fit(active.condition, w - 2 * st.pad, 12), st.warn)
        y = y - 30

        for i, step in ipairs(active.steps) do
            local done = step_done[i]
            local col
            if step.advisory then
                col = st.dim
            elseif done then
                col = st.ok
            else
                col = st.value
            end

            -- check box
            if step.advisory then
                txt(x + st.pad - 2, y - 14, "~", st.dim)
            elseif done then
                txt(x + st.pad - 2, y - 14, "X", st.ok)
            else
                glColor4f(st.dim[1], st.dim[2], st.dim[3], 1.0)
                glRectf(x + st.pad - 3, y - 14, x + st.pad + 6, y - 5)
            end

            txt(x + st.pad + 16, y - 14, string.format("%d.", i), st.label)
            txt(x + st.pad + 36, y - 14,
                qrh_fit(step.label, w - 2 * st.pad - 36, 12), col)

            qrh_rows[#qrh_rows + 1] = {
                kind = "step", step = step,
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
            y = y - rh
        end

        if proc_done then
            y = y - 8
            txt(x + st.pad, y - 14, "PROCEDURE COMPLETE", st.ok)
            y = y - rh
            bar(x + st.pad, y - rh + 8, y + 5, w - 2 * st.pad, st.alert, 0.85)
            txt(x + st.pad + 8, y - 14, "CLEAR FAILURE  (click)", CX.footer_fg)
            qrh_rows[#qrh_rows + 1] = {
                kind = "clear",
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
        else
            y = y - 6
            txt(x + st.pad, y - 14, "Fly the switches - steps self-check.", st.dim)
        end
    else
        y = y - 16
        for _, sc in ipairs(SCENARIOS) do
            local col = (ft_on_ground or 0) == 1 and st.value or st.warn
            glColor4f(st.accent[1], st.accent[2], st.accent[3], 0.8)
            glRectf(x + st.pad - 4, y - 12, x + st.pad + 2, y - 6)
            txt(x + st.pad + 12, y - 14,
                qrh_fit(sc.title, w - 2 * st.pad - 72, 12), col)
            txt_right(x + w - st.pad, y - 14, "INJECT", st.dim)

            qrh_rows[#qrh_rows + 1] = {
                kind = "scenario", sc = sc,
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
            y = y - rh
        end
        -- random row
        bar(x + st.pad, y - rh + 8, y + 5, w - 2 * st.pad, st.warn, 0.85)
        txt(x + st.pad + 8, y - 14, "RANDOM FAILURE (surprise me)", CX.footer_fg)
        qrh_rows[#qrh_rows + 1] = {
            kind = "random",
            x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
        }
    end

    -- footer: drag-safe hide button (shared green bottom bar)
    qrh_footer_rect = cx_footer_button(x, bottom, w, "HIDE PANEL", st.footer_h, st.pad)

    -- toast
    if toast_text and (ft_sim_time or 0) < toast_until then
        local tw2 = (measure_string(toast_text, "Helvetica_12")
            or measure_string(toast_text)) + 32
        local bx = x
        local by = bottom - 30
        bar(bx, by, by + 24, tw2, CX.bg)
        bar(bx, by, by + 24, 4, st.accent)
        txt(bx + 16, by + 7, toast_text, st.value)
    end
end

-- --------------------------------------------------------------- MOUSE -----
function qrh_mouse_click()
    if not TRAINER_CONFIG.panel_enabled then
        qrh_drag.active = false
        return
    end

    local mx, my = MOUSE_X or -1, MOUSE_Y or -1
    local cfg = TRAINER_CONFIG

    if MOUSE_STATUS == "down" then
        local hr = qrh_header_rect
        if hr and mx >= hr.x0 and mx <= hr.x1 and my >= hr.y0 and my <= hr.y1 then
            qrh_drag.active = true
            qrh_drag.dx = mx - cfg.panel_x
            qrh_drag.dy = my - (cfg.panel_top or my)
            RESUME_MOUSE_CLICK = true
            return
        end
    elseif MOUSE_STATUS == "drag" then
        if qrh_drag.active then
            local sw = SCREEN_WIDTH or 1920
            local sh = SCREEN_HIGHT or 1080
            cfg.panel_x = math.max(0, math.min(mx - qrh_drag.dx, sw - cfg.panel_w))
            cfg.panel_top = math.max(120, math.min(my - qrh_drag.dy, sh - 4))
            RESUME_MOUSE_CLICK = true
        end
        return
    elseif MOUSE_STATUS == "up" then
        if qrh_drag.active then
            qrh_drag.active = false
            RESUME_MOUSE_CLICK = true
            return
        end
    end

    if MOUSE_STATUS ~= "down" then return end

    local f = qrh_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        qrh_toggle_panel(false)
        RESUME_MOUSE_CLICK = true
        return
    end

    for _, r in ipairs(qrh_rows) do
        if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            RESUME_MOUSE_CLICK = true
            if r.kind == "scenario" then
                qrh_inject(r.sc)
            elseif r.kind == "random" then
                qrh_inject_random()
            elseif r.kind == "clear" then
                qrh_clear()
            elseif r.kind == "step" and r.step.cmd then
                command_once(r.step.cmd)
            end
            return
        end
    end
end

-- ------------------------------------------------------- COMMANDS + MENU ---
create_command("CitationXQRH/toggle_panel", "QRH: toggle the failure trainer panel",
    "qrh_toggle_panel()", "", "")
create_command("CitationXQRH/random", "QRH: inject a random failure scenario",
    "qrh_inject_random()", "", "")
create_command("CitationXQRH/clear", "QRH: clear the active failure",
    "qrh_clear()", "", "")
for _, sc in ipairs(SCENARIOS) do
    create_command("CitationXQRH/inject_" .. sc.key,
        "QRH: inject - " .. sc.title, "qrh_inject_by_key('" .. sc.key .. "')", "", "")
end

add_macro("Citation X QRH: toggle panel", "qrh_toggle_panel(true)", "qrh_toggle_panel(false)",
    TRAINER_CONFIG.panel_enabled and "activate" or "deactivate")
add_macro("Citation X QRH: random failure", "qrh_inject_random()")
add_macro("Citation X QRH: clear failure", "qrh_clear()")

math.randomseed(os.time())
logMsg("Citation X Failure Trainer + QRH loaded")
do_every_frame("qrh_frame()")
do_every_draw("qrh_draw()")
do_on_mouse_click("qrh_mouse_click()")
