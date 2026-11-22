-- ============================================================================
--  CESSNA CITATION X FAILURE TRAINER + QRH CHECKLIST
--  X-Plane 12  |  FlyWithLua NG+ 2.8+ (ImGui floating window)
-- ----------------------------------------------------------------------------
--  Injects realistic failure scenarios into the C750 and shows the matching
--  QRH-style checklist on screen, like the real airplane:
--
--    * click a scenario on the panel (or bind its command) to inject it
--    * the checklist appears with numbered steps
--    * each step auto-checks itself [X] the moment the switch is in the
--      correct position - verified against the aircraft's own laminar/CitX
--      datarefs, so you really have to fly the procedure in the cockpit
--    * clicking a step's check box also fires its command (a "do it" shortcut)
--    * advisory rows (monitors) never block completion
--    * when every mandatory step is done, click CLEAR FAILURE to restore
--
--  Converted 2026-11-22 to a native-decoration ImGui window: Neo Grotesque
--  REGULAR only, square corners, no orange. Green = checked/ON, blue = active
--  scenario, grey = pending/inactive. ImGui owns dragging and clicking; the
--  failure, checklist and command logic below is unchanged.
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
local qrh_wnd      = nil   -- ImGui floating window, created at load
local toast_text   = nil
local toast_until  = 0
local is_c750      = (PLANE_ICAO == "C750")   -- refreshed every frame

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

-- Read-only view for CitationX_FlightInstructor.lua: the instructor grades a
-- lesson's "QRH complete" item against the real checklist state, so the two
-- panels share one source of truth instead of duplicating switch logic.
function qrh_is_complete()
    return active ~= nil and proc_done == true
end

function qrh_active_key()
    return active and active.key or nil
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
    cxui_show(qrh_wnd, TRAINER_CONFIG.panel_enabled)
    qrh_toast("QRH PANEL: " .. (TRAINER_CONFIG.panel_enabled and "ON" or "OFF"))
end

-- ----------------------------------------------------------- FRAME LOOP ----
function qrh_frame()
    is_c750 = (PLANE_ICAO == "C750")
    -- A scenario is a C750 failure; clear it and stop polling when another
    -- aircraft is selected, so nothing stays injected behind the scenes.
    if TRAINER_CONFIG.require_c750 and not is_c750 then
        if active then qrh_clear() end
        return
    end

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

-- ------------------------------------------------------------- ImGui PANEL --
-- Converted 2026-11-22: the panel is a native-decoration ImGui floating window
-- in regular Neo Grotesque. ImGui owns clicking and dragging, so the old GL
-- hit-test, header drag and mouse handler are gone; the scenario and checklist
-- logic above is untouched. qrh_draw stays as a no-op for existing callers.
function qrh_draw() end

function qrh_on_build(wnd, x, y)
    local _ = wnd
    local _x = x
    local _y = y
    if PLANE_ICAO ~= "C750" then return end
    if TRAINER_CONFIG.panel_enabled == false then return end
    if type(imgui) ~= "table" then return end

    local style = cxui_begin_style()
    local w = 380

    cxui_text("CITATION X")
    cxui_muted("QRH TRAINER", "small")
    cxui_spacing()
    if type(imgui.Separator) == "function" then imgui.Separator() end
    cxui_spacing()

    -- One button per scenario; the active one is BLUE, never orange/red.
    -- Clicking is the old "select / inject" action (qrh_inject clears first).
    cxui_section("SCENARIOS")
    for _, sc in ipairs(SCENARIOS) do
        local is_active = (active == sc)
        if cxui_button(sc.title .. "###qrh_scenario_" .. sc.key, w, CXUI.row_h,
                       is_active and CXUI.color.active or nil) then
            qrh_inject(sc)
        end
    end
    if cxui_button("RANDOM FAILURE (surprise me)###qrh_random", w, CXUI.row_h) then
        qrh_inject_random()
    end

    if active then
        if type(imgui.Separator) == "function" then imgui.Separator() end
        cxui_spacing()
        cxui_text(active.title, "small", CXUI.color.active)
        cxui_muted(active.condition, "small")
        cxui_spacing()
        cxui_section("CHECKLIST")
        for i, step in ipairs(active.steps) do
            local done = step_done[i] == true
            local col = step.advisory and CXUI.color.dim
                or (done and CXUI.color.on or CXUI.color.muted)
            local mark = step.advisory and "~" or (done and "X" or " ")
            if step.cmd then
                -- Same click-through as the old GL row: fire the switch command.
                if cxui_button(mark .. "###qrh_step_" .. i, 26, 22) then
                    command_once(step.cmd)
                end
            else
                cxui_text(mark, "small", col)
            end
            if type(imgui.SameLine) == "function" then imgui.SameLine() end
            cxui_text(string.format("%d. %s", i, step.label), "small", col)
        end

        cxui_spacing()
        if proc_done then
            cxui_text("PROCEDURE COMPLETE", "small", CXUI.color.on)
        else
            cxui_muted("Fly the switches - steps self-check.", "small")
        end

        cxui_spacing()
        cxui_section("ACTIONS")
        if cxui_button("SET FAILURE###qrh_set", 176, CXUI.row_h) then
            qrh_inject(active)
        end
        if type(imgui.SameLine) == "function" then imgui.SameLine() end
        if cxui_button("CLEAR FAILURE###qrh_clear", 176, CXUI.row_h) then
            qrh_clear()
        end
    end

    if toast_text and (ft_sim_time or 0) < toast_until then
        cxui_spacing()
        cxui_muted(toast_text, "small")
    end

    cxui_spacing()
    if cxui_button("HIDE PANEL###qrh_hide", w, CXUI.row_h) then
        qrh_toggle_panel(false)
    end
    cxui_end_style(style)
end

-- ImGui handles every click and all dragging; kept for existing callers.
function qrh_mouse_click()
    return
end

function qrh_aircraft_guard()
    cxui_show(qrh_wnd, PLANE_ICAO == "C750" and TRAINER_CONFIG.panel_enabled)
end

function qrh_on_close(wnd)
    local _ = wnd
    qrh_wnd = nil
    TRAINER_CONFIG.panel_enabled = false
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

-- Create the ImGui window once. It starts hidden; the Control Center / hub
-- toggle opens it, and the aircraft guard hides it off the C750.
qrh_wnd = cxui_create_window(430, 620, "Citation X QRH Trainer",
    "qrh_on_build", "qrh_on_close", 470, 24)
cxui_show(qrh_wnd, false)
do_often("qrh_aircraft_guard()")
