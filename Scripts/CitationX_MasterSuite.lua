-- ============================================================================
--  CESSNA CITATION X MASTER PERFORMANCE & TELEMETRY SUITE
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
--  Version 2.0
-- ----------------------------------------------------------------------------
--  Systems:
--    1. Telemetry HUD + structural G / Mach monitor (glass-panel styling)
--    2. Axis optimizer (deadzone, curve, smoothing) via joystick overrides
--    3. 1 Hz telemetry flight data recorder -> CSV
--    4. Trigger-based bleed-air / pressurization emergency generator
--    5. Input mapper: Logitech MX keys / mouse events / joystick buttons
--    6. Suite status panel: live ON/OFF indicator for every system above
--    7. C750 systems readback panel: live AP / electrical / fuel / ice / APU
--
--  Everything below is toggleable at runtime from the FlyWithLua macro menu,
--  from X-Plane's joystick/key assignment UI (CitationXSuite/* commands), or by
--  clicking a row on the on-screen status panel. The status panel always shows
--  which subsystem is currently active, so you are never guessing.
--
--  Verified against: DataRefs.txt, Commands.txt, the aircraft's own xLua
--  scripts (plugins/xlua/scripts/*.lua) and FlyWithLua_Manual_en.pdf.
-- ============================================================================

-- ------------------------------------------------------------------ CONFIG --
CONFIG = {
    hud_enabled            = true,
    log_enabled            = true,
    log_to_desktop         = true,

    -- Suite status panel: the live "which script is active" readout.
    status_enabled         = true,
    status_clickable       = true,   -- click a status row to toggle that system
    systems_panel_enabled  = true,   -- right-hand C750 systems readback panel
    show_when_hud_off      = true,   -- keep the status panel up if the HUD is hidden

    -- Takes over pitch/roll input via the per-axis joystick overrides.
    -- Off by default: enable only if you want the custom stick response.
    axis_optimizer_enabled = false,
    deadzone               = 0.03,
    curve_exponent         = 1.6,
    smoothing_factor       = 0.35,

    mach_warn              = 0.91,
    g_warn_high            = 2.8,
    g_warn_low             = -0.5,

    emergency_enabled      = true,
    emergency_chance_1hz   = 1 / 900,
    emergency_duration_sec = 20,
    emergency_alt_ft       = 15000,
    emergency_mach         = 0.85,

    input_map_enabled      = true,
    input_learn_mode       = false,
    input_probe_to_desktop = true,

    thumbwheel_heading      = true,
    heading_step_deg        = 1,
    heading_key_step_deg    = 5,
    heading_wheel_invert    = false,

    -- Spring-loaded heading-bug knob driven by the DS4 right stick.
    -- stick_hdg_axis = -1 auto-detects the raw axis: only spring-centered,
    -- still-unassigned axes are eligible (their learned rest must sit within
    -- stick_hdg_center_tol of stick_hdg_center). Analog triggers such as
    -- L2/R2 rest at an extreme, so squeezing them can never grab or move the
    -- heading bug - it stays on the right stick whether the pad enumerates
    -- over USB or Bluetooth. Once a stick axis is found it stays locked
    -- (stick_hdg_sticky) until the module is toggled or the scripts reload.
    -- Set stick_hdg_axis to a fixed RAW index (see the AXIS MONITOR panel) to
    -- pin it manually. Raw sim/joystick/joystick_axis_values is 0..1.
    stick_hdg_enabled       = true,
    stick_hdg_axis          = -1,
    stick_hdg_sticky        = true,
    stick_hdg_exclude_axes  = { },   -- extra RAW indices to veto, e.g. { 4, 5 }
    stick_hdg_center_tol    = 0.25,  -- eligible only if the rest is near center
    stick_hdg_stale_hold_s  = 6.0,   -- veto a slot stuck at an extreme this long
    stick_hdg_invert        = false,
    stick_hdg_center        = 0.5,
    stick_hdg_rate_dps      = 30,
    stick_hdg_deadzone      = 0.12,
    -- Per-frame convergence rate of the learned rest value toward an idle
    -- axis' current position (0..1). Slow enough that a deliberate push
    -- outpaces it; fast enough to track drift.
    stick_hdg_base_track    = 0.001,

    axis_monitor            = false,

    altitude_step_ft        = 100,
    altitude_coarse_step_ft = 1000,
    altitude_wheel_invert   = false,
    thumbwheel_altitude     = false,
}

-- ------------------------------------------------------------- HUD STYLE ----
-- Glass-panel palette, {r, g, b} in 0..1. Background entries carry alpha.
HUD_STYLE = {
    x            = 28,
    width        = 396,
    row_h        = 22,
    status_row_h = 20,
    pad          = 12,
    bg           = {0.02, 0.05, 0.08, 0.62},
    header_bg    = {0.03, 0.15, 0.21, 0.90},
    accent       = {0.22, 0.85, 1.00},
    subhdr       = {0.36, 0.68, 0.78},
    label        = {0.42, 0.62, 0.70},
    value        = {0.93, 0.97, 1.00},
    ok           = {0.32, 0.95, 0.55},
    warn         = {1.00, 0.66, 0.12},
    alert        = {1.00, 0.30, 0.28},
    dim          = {0.30, 0.37, 0.42},
    learn_bg     = {0.10, 0.07, 0.02, 0.85},
    learn        = {1.00, 0.75, 0.20},
    -- right-hand C750 systems panel
    sys_w        = 336,
    sys_pad      = 12,
    sys_row_h    = 19,
    sys_cols     = 3,
}

-- ----------------------------------------------------------- INPUT MAP ------
-- vkey is the XPLM virtual key code (XPLMDefs.h). ctrl / opt / shift are the
-- modifiers seen by FlyWithLua. Remap MX buttons in Logi Options+ to these
-- keystrokes, or use learn mode to discover what each control really sends.
INPUT_BINDINGS = {
    { vkey = 0x31, ctrl = true, shift = true, label = "NAV lights",       command = "sim/lights/nav_lights_toggle" },
    { vkey = 0x32, ctrl = true, shift = true, label = "Beacon lights",    command = "sim/lights/beacon_lights_toggle" },
    { vkey = 0x33, ctrl = true, shift = true, label = "Strobe lights",    command = "sim/lights/strobe_lights_toggle" },
    { vkey = 0x34, ctrl = true, shift = true, label = "Taxi lights",      command = "sim/lights/taxi_lights_toggle" },
    { vkey = 0x35, ctrl = true, shift = true, label = "Landing lights",   command = "sim/lights/landing_lights_toggle" },
    { vkey = 0x36, ctrl = true, shift = true, label = "AP master",        command = "sim/autopilot/servos_toggle" },
    { vkey = 0x37, ctrl = true, shift = true, label = "AP heading hold",  command = "sim/autopilot/heading_hold" },
    { vkey = 0x38, ctrl = true, shift = true, label = "Thrust reversers", command = "sim/engines/thrust_reverse_toggle" },
    { vkey = 0x39, ctrl = true, shift = true, label = "ALT SEL down",     action = function() citationx_altitude(-CONFIG.altitude_coarse_step_ft) end },
    { vkey = 0x30, ctrl = true, shift = true, label = "ALT SEL up",       action = function() citationx_altitude( CONFIG.altitude_coarse_step_ft) end },
    { vkey = 0x25, ctrl = true, shift = true, label = "HDG SEL left",     action = function() citationx_heading(-CONFIG.heading_key_step_deg) end },
    { vkey = 0x27, ctrl = true, shift = true, label = "HDG SEL right",    action = function() citationx_heading( CONFIG.heading_key_step_deg) end },
}

-- JOY_BINDINGS maps controller button indices (discovered in learn mode) to
-- the same { label, command/action } shape as INPUT_BINDINGS.
JOY_BINDINGS = {
}

-- ------------------------------------------------- C750 SYSTEMS COMMANDS -----
-- The Citation X registers ~220 custom xLua commands at
-- plugins/xlua/scripts/*.lua (create_command("laminar/CitX/...")). They are
-- not in Commands.txt and X-Plane's joystick UI makes them hard to find, so
-- the suite maps the high-value ones to three keyboard layers:
--   Ctrl+Shift + letter  flight ops / engines / fuel
--   Ctrl+Opt   + digit   electrical / APU
--   Ctrl+Opt   + letter  ice / pressurization / hydraulics / lights / O2
-- command_once() resolves runtime-registered commands by name, so these fire
-- exactly like clicking the 3D switch. Extend freely: copy an entry, change
-- vkey (XPLMDefs.h) and command (see the xLua scripts for the full list).
CITX_BINDINGS = {
    -- flight ops, engines, fuel: Ctrl+Shift + letter
    { vkey = 0x41, ctrl = true, shift = true, label = "AP toggle",        command = "laminar/CitX/autopilot/cmd_ap_toggle" },
    { vkey = 0x42, ctrl = true, shift = true, label = "AP half bank",     command = "laminar/CitX/autopilot/cmd_bank_mode" },
    { vkey = 0x43, ctrl = true, shift = true, label = "AP CWS",           command = "laminar/CitX/autopilot/cmd_cngovr_mode" },
    { vkey = 0x44, ctrl = true, shift = true, label = "AP ALT",           command = "laminar/CitX/autopilot/cmd_alt_mode" },
    { vkey = 0x47, ctrl = true, shift = true, label = "Gear toggle",      command = "sim/flight_controls/landing_gear_toggle" },
    { vkey = 0x48, ctrl = true, shift = true, label = "Heading sync",     command = "sim/autopilot/heading_sync" },
    { vkey = 0x49, ctrl = true, shift = true, label = "Fuel transfer L",  command = "laminar/CitX/fuel/cmd_transfer_left_up" },
    { vkey = 0x4A, ctrl = true, shift = true, label = "Fuel transfer R",  command = "laminar/CitX/fuel/cmd_transfer_right_up" },
    { vkey = 0x4B, ctrl = true, shift = true, label = "Start engine L",   command = "laminar/CitX/engine/cmd_starter_left" },
    { vkey = 0x4C, ctrl = true, shift = true, label = "Start engine R",   command = "laminar/CitX/engine/cmd_starter_right" },
    { vkey = 0x4D, ctrl = true, shift = true, label = "AP APP",           command = "laminar/CitX/autopilot/cmd_app_mode" },
    { vkey = 0x4E, ctrl = true, shift = true, label = "AP NAV",           command = "laminar/CitX/autopilot/cmd_nav_mode" },
    { vkey = 0x4F, ctrl = true, shift = true, label = "Ignition L",       command = "laminar/CitX/engine/cmd_ignition_switch_left_up" },
    { vkey = 0x50, ctrl = true, shift = true, label = "Ignition R",       command = "laminar/CitX/engine/cmd_ignition_switch_right_up" },
    { vkey = 0x51, ctrl = true, shift = true, label = "Boost pump L",     command = "laminar/CitX/fuel/cmd_boost_left_up" },
    { vkey = 0x52, ctrl = true, shift = true, label = "Boost pump R",     command = "laminar/CitX/fuel/cmd_boost_right_up" },
    { vkey = 0x53, ctrl = true, shift = true, label = "AP VS",            command = "laminar/CitX/autopilot/cmd_vs_mode" },
    { vkey = 0x54, ctrl = true, shift = true, label = "Starter stop",     command = "laminar/CitX/engine/cmd_starter_stop" },
    { vkey = 0x55, ctrl = true, shift = true, label = "Engine sync",      command = "laminar/CitX/engine/cmd_eng_sync_up" },
    { vkey = 0x56, ctrl = true, shift = true, label = "AP VNAV",          command = "laminar/CitX/autopilot/cmd_vnav_mode" },
    { vkey = 0x57, ctrl = true, shift = true, label = "Windshield air",   command = "laminar/CitX/ice/cmd_windshield_air_toggle" },
    { vkey = 0x58, ctrl = true, shift = true, label = "Crossfeed L",      command = "laminar/CitX/fuel/cmd_crossfeed_left" },
    { vkey = 0x59, ctrl = true, shift = true, label = "Yaw damper",       command = "laminar/CitX/autopilot/cmd_yd_toggle" },
    { vkey = 0x5A, ctrl = true, shift = true, label = "Crossfeed R",      command = "laminar/CitX/fuel/cmd_crossfeed_right" },

    -- electrical, APU: Ctrl+Opt + digit
    { vkey = 0x31, ctrl = true, opt = true, label = "Battery L",          command = "laminar/CitX/electrical/cmd_battery_left_toggle" },
    { vkey = 0x32, ctrl = true, opt = true, label = "Battery R",          command = "laminar/CitX/electrical/cmd_battery_right_toggle" },
    { vkey = 0x33, ctrl = true, opt = true, label = "Generator L",        command = "laminar/CitX/electrical/cmd_generator_left_up" },
    { vkey = 0x34, ctrl = true, opt = true, label = "Generator R",        command = "laminar/CitX/electrical/cmd_generator_right_up" },
    { vkey = 0x35, ctrl = true, opt = true, label = "External power",     command = "laminar/CitX/electrical/cmd_ext_pwr_toggle" },
    { vkey = 0x36, ctrl = true, opt = true, label = "Avionics",           command = "laminar/CitX/electrical/cmd_avionics_toggle" },
    { vkey = 0x37, ctrl = true, opt = true, label = "Avionics EICAS",     command = "laminar/CitX/electrical/cmd_avionics_eicas_toggle" },
    { vkey = 0x38, ctrl = true, opt = true, label = "APU master",         command = "laminar/CitX/APU/master_switch_toggle" },
    { vkey = 0x39, ctrl = true, opt = true, label = "APU start",          command = "laminar/CitX/APU/starter_switch_up" },
    { vkey = 0x30, ctrl = true, opt = true, label = "APU generator",      command = "laminar/CitX/APU/gen_switch_up" },

    -- ice, pressurization, hydraulics, extra lights, oxygen: Ctrl+Opt + letter
    { vkey = 0x41, ctrl = true, opt = true, label = "Ice engine L",       command = "laminar/CitX/ice/cmd_engine_left_toggle" },
    { vkey = 0x42, ctrl = true, opt = true, label = "Ice engine R",       command = "laminar/CitX/ice/cmd_engine_right_toggle" },
    { vkey = 0x43, ctrl = true, opt = true, label = "Wing ice light",     command = "laminar/CitX/ice/cmd_wing_light_toggle" },
    { vkey = 0x44, ctrl = true, opt = true, label = "Slat heat",          command = "laminar/CitX/ice/cmd_slat_toggle" },
    { vkey = 0x47, ctrl = true, opt = true, label = "Stab heat L",        command = "laminar/CitX/ice/cmd_stabilizer_left_toggle" },
    { vkey = 0x48, ctrl = true, opt = true, label = "Stab heat R",        command = "laminar/CitX/ice/cmd_stabilizer_right_toggle" },
    { vkey = 0x49, ctrl = true, opt = true, label = "Pitot heat L",       command = "laminar/CitX/ice/cmd_pitot_static_left_toggle" },
    { vkey = 0x4A, ctrl = true, opt = true, label = "Pitot heat R",       command = "laminar/CitX/ice/cmd_pitot_static_right_toggle" },
    { vkey = 0x4B, ctrl = true, opt = true, label = "Cabin dump",         command = "laminar/CitX/pressurization/cmd_cabin_dump_toggle" },
    { vkey = 0x4C, ctrl = true, opt = true, label = "Iso valve",          command = "laminar/CitX/pressurization/cmd_iso_vlv_toggle" },
    { vkey = 0x4D, ctrl = true, opt = true, label = "Master caution",     command = "sim/annunciator/clear_master_caution" },
    { vkey = 0x4E, ctrl = true, opt = true, label = "Aux hyd pump",       command = "laminar/CitX/hydraulics/cmd_aux_pump_toggle" },
    { vkey = 0x4F, ctrl = true, opt = true, label = "Unload pump A",      command = "laminar/CitX/hydraulics/cmd_unload_pump_A_toggle" },
    { vkey = 0x50, ctrl = true, opt = true, label = "Unload pump B",      command = "laminar/CitX/hydraulics/cmd_unload_pump_B_toggle" },
    { vkey = 0x51, ctrl = true, opt = true, label = "Antiskid",           command = "laminar/CitX/hydraulics/cmd_antiskid_toggle" },
    { vkey = 0x52, ctrl = true, opt = true, label = "Gravity flow",       command = "laminar/CitX/fuel/cmd_gravity_flow_toggle" },
    { vkey = 0x53, ctrl = true, opt = true, label = "AP FLC",             command = "laminar/CitX/autopilot/cmd_flc_mode" },
    { vkey = 0x54, ctrl = true, opt = true, label = "Ground idle",        command = "laminar/CitX/engine/cmd_gnd_idle_toggle" },
    { vkey = 0x55, ctrl = true, opt = true, label = "Tail flood light",   command = "laminar/CitX/lights/cmd_tail_flood_toggle" },
    { vkey = 0x56, ctrl = true, opt = true, label = "Recognition lights", command = "laminar/CitX/lights/cmd_recognition_toggle" },
    { vkey = 0x57, ctrl = true, opt = true, label = "Cabin master light", command = "laminar/CitX/lights/cmd_cabin_master_toggle" },
    { vkey = 0x58, ctrl = true, opt = true, label = "Landing light L",    command = "laminar/CitX/lights/cmd_landing_left_toggle" },
    { vkey = 0x59, ctrl = true, opt = true, label = "Landing light R",    command = "laminar/CitX/lights/cmd_landing_right_toggle" },
    { vkey = 0x5A, ctrl = true, opt = true, label = "Passenger O2",       command = "laminar/CitX/oxygen/cmd_pass_oxy_up" },
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("mach_no",     "sim/flightmodel/misc/machno", "readonly")
dataref("g_nrml",      "sim/flightmodel/forces/g_nrml", "readonly")
dataref("elevation_m", "sim/flightmodel/position/elevation", "readonly")
dataref("ias_kts",     "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("pitch_deg",   "sim/flightmodel/position/theta", "readonly")
dataref("roll_deg",    "sim/flightmodel/position/phi", "readonly")
dataref("sim_time",    "sim/time/total_running_time_sec", "readonly")

dataref("joy_pitch",       "sim/joystick/joy_mapped_axis_value", "readonly", 1)
dataref("joy_roll",        "sim/joystick/joy_mapped_axis_value", "readonly", 2)
dataref("joy_avail_pitch", "sim/joystick/joy_mapped_axis_avail", "readonly", 1)
dataref("joy_avail_roll",  "sim/joystick/joy_mapped_axis_avail", "readonly", 2)

dataref("yoke_pitch_ratio",   "sim/joystick/yoke_pitch_ratio", "writable")
dataref("yoke_roll_ratio",    "sim/joystick/yoke_roll_ratio", "writable")
dataref("ovr_joystick_pitch", "sim/operation/override/override_joystick_pitch", "writable")
dataref("ovr_joystick_roll",  "sim/operation/override/override_joystick_roll", "writable")

dataref("alt_sel_ft",    "sim/cockpit2/autopilot/altitude_dial_ft", "writable")
dataref("alt_legacy_ft", "sim/cockpit/autopilot/altitude", "writable")
dataref("hdg_sel_deg",   "sim/cockpit2/autopilot/heading_dial_deg_mag_pilot", "writable")

local fuel_flow_kg_sec = dataref_table("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")

local joy_buttons      = dataref_table("sim/joystick/joystick_button_values")
local joy_raw_axes     = dataref_table("sim/joystick/joystick_axis_values")
local joy_raw_assign   = dataref_table("sim/joystick/joystick_axis_assignments")

-- sim/joystick/joystick_axis_assignments enum (X-Plane developer docs / the
-- stock "get_axis_assignments.lua" helper). Index 1 = Pitch, 2 = Roll, 3 = Yaw.
local AXIS_FUNCS = {
    "none", "pitch", "roll", "yaw", "throttle", "collective", "l toe brake",
    "r toe brake", "prop", "mixture", "carb heat", "flaps", "thrust vec",
    "wing sweep", "speedbrakes", "displacement", "reverse", "elev trim",
    "ail trim", "rud trim", "throttle 1", "throttle 2", "throttle 3",
    "throttle 4", "prop 1", "prop 2", "prop 3", "prop 4", "mixture 1",
    "mixture 2", "mixture 3", "mixture 4", "reverse 1", "reverse 2",
    "reverse 3", "reverse 4", "gear", "tiller", "bak throttle", "cowl flaps",
}
local function axis_assign_name(v) return AXIS_FUNCS[(v or 0) + 1] or "?" end

-- Last raw axis the auto-detecting heading knob latched onto (for the monitor).
local stick_hdg_live_axis = -1
-- Learned rest (idle) raw value per axis; nil until the axis is first seen.
local stick_base_raw = {}
-- Slots that look disconnected: pinned at a hard extreme for a long time.
-- They are skipped by detection until their value comes back to center.
local stick_dead_axis  = {}
local stick_hdg_hold_s = 0.0

-- Center a raw 0..1 axis value to -1..1 around CONFIG.stick_hdg_center
-- (used by the AXIS MONITOR display only).
local function stick_center_value(raw)
    local c = (raw - CONFIG.stick_hdg_center) * 2.0
    if CONFIG.stick_hdg_invert then c = -c end
    return c
end

-- Return the raw 0..1 axis value re-centered to -1..1 around CONFIG.stick_hdg_center.
local function stick_axis_centered(idx)
    return stick_center_value(joy_raw_axes[idx] or CONFIG.stick_hdg_center)
end

-- Deflection of an axis away from its learned rest, -1..1. An axis parked
-- anywhere (a trigger at raw 0, a pad slot reading 0, a slightly drifted
-- stick) reads ~0 once its rest is learned, so only a genuine push shows up.
local function stick_axis_deflection(idx)
    local raw  = joy_raw_axes[idx]
    local base = stick_base_raw[idx]
    if raw == nil or base == nil then return 0.0 end
    local d = (raw - base) * 2.0
    if CONFIG.stick_hdg_invert then d = -d end
    return d
end

-- Adopt the first value seen for each axis as its rest, then creep the rest
-- toward the idle position. A deflected (driving) axis is frozen so the rest
-- cannot crawl toward a held stick. This makes a parked axis - idle trigger
-- at raw 0, slot of a disconnected pad, drifting pot - read as "at rest", so
-- it can never free-run the heading knob.
local function stick_baseline_update()
    for i = 0, 63 do
        local raw = joy_raw_axes[i]
        if raw then
            local base = stick_base_raw[i]
            if base == nil then
                stick_base_raw[i] = raw
            elseif math.abs(stick_axis_deflection(i)) <= CONFIG.stick_hdg_deadzone then
                stick_base_raw[i] = base + (raw - base) * CONFIG.stick_hdg_base_track
            end
        end
    end
end

-- An axis is only eligible while it is spring-centered: its learned rest must
-- sit near CONFIG.stick_hdg_center. Sticks rest at center; analog triggers
-- (L2/R2) and pedals rest at an extreme, so they can never be picked and the
-- heading bug stays on the right stick no matter what else is squeezed.
-- Boolean predicate, deliberately NOT named stick_axis_centered(): that name
-- already belongs to the numeric re-centering helper used by AXIS MONITOR.
-- Shadowing it made that panel call math.abs() on this boolean and killed the
-- whole draw callback every frame.
local function stick_axis_is_centered(idx)
    local base = stick_base_raw[idx]
    if base == nil then return false end
    return math.abs(base - CONFIG.stick_hdg_center) <= CONFIG.stick_hdg_center_tol
end

local function stick_axis_excluded(idx)
    local list = CONFIG.stick_hdg_exclude_axes
    for k = 1, #list do
        if list[k] == idx then return true end
    end
    return false
end

-- Most-deflected eligible RAW axis (relative to its learned rest): not bound
-- to a primary flight control (pitch/roll/yaw/throttle), spring-centered and
-- not vetoed. The DS4 right stick wins; L2/R2 (rest at an extreme) never do.
-- Returns nil when every candidate is at rest.
local function detect_stick_hdg_axis()
    local best_idx, best_mag = nil, CONFIG.stick_hdg_deadzone
    for i = 0, 63 do
        local a = joy_raw_assign[i] or 0
        if a ~= 1 and a ~= 2 and a ~= 3 and a ~= 4
            and not stick_dead_axis[i]
            and not stick_axis_excluded(i)
            and stick_axis_is_centered(i) then
            local mag = math.abs(stick_axis_deflection(i))
            if mag > best_mag then best_idx, best_mag = i, mag end
        end
    end
    return best_idx
end

-- ------------------------------------------------------------ STATE (early) --
-- Declared before SUITE_MODULES so its closures capture these locals (in Lua a
-- local is only visible to code textually after its declaration).
local log_fd           = nil
local optimizer_active = false
local emergency_left   = 0.0
local emergency_armed  = true
local is_c750          = true

-- ------------------------------------------------- SUITE MODULE REGISTRY ----
-- One entry per subsystem the suite owns. `state()` returns a short status
-- word plus an RGB triple used by the on-screen status panel. `set()` is the
-- single point of control for commands, macros and click-to-toggle.
SUITE_MODULES = {
    {
        key = "hud", label = "HUD DISPLAY", macro = "HUD display",
        get = function() return CONFIG.hud_enabled end,
        set = function(on) citationx_set_hud(on) end,
        state = function()
            if CONFIG.hud_enabled then return "ON",  HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "status", label = "STATUS PANEL", macro = "status panel",
        get = function() return CONFIG.status_enabled end,
        set = function(on) citationx_set_status(on) end,
        state = function()
            if CONFIG.status_enabled then return "ON",  HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "systems", label = "C750 PANEL", macro = "C750 systems panel",
        get = function() return CONFIG.systems_panel_enabled end,
        set = function(on) citationx_set_systems(on) end,
        state = function()
            if not CONFIG.systems_panel_enabled then return "OFF", HUD_STYLE.dim end
            if is_c750 then return "LIVE", HUD_STYLE.ok end
            return "NO DATA", HUD_STYLE.warn
        end,
    },
    {
        key = "axis", label = "AXIS OPTIMIZER", macro = "axis optimizer",
        get = function() return CONFIG.axis_optimizer_enabled end,
        set = function(on) citationx_set_axis(on) end,
        state = function()
            if not CONFIG.axis_optimizer_enabled then return "OFF", HUD_STYLE.dim end
            if optimizer_active then return "ACTIVE", HUD_STYLE.ok end
            return "ARMED", HUD_STYLE.warn
        end,
    },
    {
        key = "log", label = "FLIGHT RECORDER", macro = "flight recorder",
        get = function() return CONFIG.log_enabled end,
        set = function(on) citationx_set_logging(on) end,
        state = function()
            if not CONFIG.log_enabled then return "OFF", HUD_STYLE.dim end
            if log_fd then return "REC", HUD_STYLE.alert end
            return "NO FILE", HUD_STYLE.warn
        end,
    },
    {
        key = "emerg", label = "EMERGENCY GEN", macro = "emergency generator",
        get = function() return CONFIG.emergency_enabled end,
        set = function(on) citationx_set_emergency(on) end,
        state = function()
            if not CONFIG.emergency_enabled then return "OFF", HUD_STYLE.dim end
            if emergency_left > 0.0 then return "TRIGGERED", HUD_STYLE.alert end
            return "ARMED", HUD_STYLE.ok
        end,
    },
    {
        key = "input", label = "INPUT MAPPER", macro = "input mapper",
        get = function() return CONFIG.input_map_enabled end,
        set = function(on) citationx_set_input_map(on) end,
        state = function()
            if CONFIG.input_map_enabled then return "ON",  HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "learn", label = "LEARN MODE", macro = "input learn mode",
        get = function() return CONFIG.input_learn_mode end,
        set = function(on) citationx_set_input_learn(on) end,
        state = function()
            if CONFIG.input_learn_mode then return "ON",  HUD_STYLE.learn end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "stick", label = "STICK HDG KNOB", macro = "stick heading knob",
        get = function() return CONFIG.stick_hdg_enabled end,
        set = function(on) citationx_set_stick_hdg(on) end,
        state = function()
            if CONFIG.stick_hdg_enabled then return "ON",  HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "axmon", label = "AXIS MONITOR", macro = "axis monitor",
        get = function() return CONFIG.axis_monitor end,
        set = function(on) citationx_set_axis_monitor(on) end,
        state = function()
            if CONFIG.axis_monitor then return "ON",  HUD_STYLE.learn end
            return "OFF", HUD_STYLE.dim
        end,
    },
    -- --- sibling panels from the other suite scripts -------------------------
    -- These scripts share one Lua state, so their globals are reachable here.
    -- Every accessor is nil-guarded so the HUD keeps working if a script is
    -- missing, disabled or simply loaded in a different order.
    {
        key = "cabin", label = "CABIN OPS", macro = "cabin ops panel",
        get = function()
            return (type(CAB_CONFIG) == "table") and CAB_CONFIG.panel_enabled or false
        end,
        set = function(on)
            if type(cab_toggle_panel) == "function" then cab_toggle_panel(on) end
        end,
        state = function()
            if type(CAB_CONFIG) ~= "table" then return "ABSENT", HUD_STYLE.dim end
            if CAB_CONFIG.panel_enabled then return "ON", HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "qrh", label = "QRH TRAINER", macro = "QRH panel",
        get = function()
            return (type(TRAINER_CONFIG) == "table") and TRAINER_CONFIG.panel_enabled or false
        end,
        set = function(on)
            if type(qrh_toggle_panel) == "function" then qrh_toggle_panel(on) end
        end,
        state = function()
            if type(TRAINER_CONFIG) ~= "table" then return "ABSENT", HUD_STYLE.dim end
            if TRAINER_CONFIG.panel_enabled then return "ON", HUD_STYLE.ok end
            return "OFF", HUD_STYLE.dim
        end,
    },
    {
        key = "landperf", label = "LANDING PERF", macro = "landing report",
        get = function() return la_displayOn == true end,
        set = function(on)
            if type(la_toggle_last_result) ~= "function" then return end
            -- la_toggle_last_result flips; only call it when the state differs.
            if (la_displayOn == true) ~= (on == true) then la_toggle_last_result() end
        end,
        state = function()
            if la_show_last_result == nil then return "ABSENT", HUD_STYLE.dim end
            if la_displayOn == true then return "SHOWN", HUD_STYLE.ok end
            return "HIDDEN", HUD_STYLE.dim
        end,
    },
}

-- ------------------------------------------------ C750 SYSTEMS READBACK ----
-- These are the aircraft's own runtime datarefs (registered by its xLua
-- scripts via create_dataref). They do not exist until the Citation X loads,
-- so they are resolved lazily with XPLMFindDataRef() and read with
-- XPLMGetDataf() in the frame loop (reading in a draw callback is not allowed).
SYSTEMS_PANEL = {
    { title = "AUTOPILOT", items = {
        {"L AP",   "laminar/CitX/autopilot/left_ap"},
        {"R AP",   "laminar/CitX/autopilot/right_ap"},
        {"Y/D",    "laminar/CitX/autopilot/left_yd"},
        {"HDG",    "laminar/CitX/autopilot/hdg_mode_on"},
        {"NAV",    "laminar/CitX/autopilot/nav_mode_on"},
        {"ALT",    "laminar/CitX/autopilot/alt_mode_on"},
        {"VS",     "laminar/CitX/autopilot/vs_mode_on"},
        {"FLC",    "laminar/CitX/autopilot/flc_mode_on"},
        {"APPR",   "laminar/CitX/autopilot/app_mode_on"},
        {"VNAV",   "laminar/CitX/autopilot/vnav_mode_on"},
        {"BANK",   "laminar/CitX/autopilot/bank_mode_on"},
        {"CWS",    "laminar/CitX/autopilot/cngovr_mode_on"},
    }},
    { title = "ELECTRICAL", items = {
        {"BAT L",  "laminar/CitX/electrical/battery_left"},
        {"BAT R",  "laminar/CitX/electrical/battery_right"},
        {"GEN L",  "laminar/CitX/electrical/generator_left"},
        {"GEN R",  "laminar/CitX/electrical/generator_right"},
        {"EXT PWR","laminar/CitX/electrical/ext_pwr"},
        {"AVION",  "laminar/CitX/electrical/avionics"},
        {"EICAS",  "laminar/CitX/electrical/avionics_eicas"},
        {"STBY",   "laminar/CitX/electrical/battery_stby_pwr"},
    }},
    { title = "FUEL", items = {
        {"BST L",  "laminar/CitX/fuel/boost_left"},
        {"BST R",  "laminar/CitX/fuel/boost_right"},
        {"XFEED",  "laminar/CitX/fuel/crossfeed"},
        {"XFER L", "laminar/CitX/fuel/transfer_left"},
        {"XFER R", "laminar/CitX/fuel/transfer_right"},
        {"GRAV",   "laminar/CitX/fuel/gravity_flow"},
    }},
    { title = "ICE / ANTI-ICE", items = {
        {"ENG L",  "laminar/CitX/ice/engine_left"},
        {"ENG R",  "laminar/CitX/ice/engine_right"},
        {"PITOT L","laminar/CitX/ice/pitot_static_left"},
        {"PITOT R","laminar/CitX/ice/pitot_static_right"},
        {"SLAT",   "laminar/CitX/ice/slat"},
        {"STAB L", "laminar/CitX/ice/stabilizer_left"},
        {"STAB R", "laminar/CitX/ice/stabilizer_right"},
        {"W/S AIR","laminar/CitX/ice/windshield_air"},
    }},
    { title = "APU", items = {
        {"MASTER", "laminar/CitX/APU/master_switch"},
        {"STARTER","laminar/CitX/APU/starter_switch"},
        {"GEN",    "laminar/CitX/APU/gen_switch"},
        {"READY",  "laminar/CitX/APU/annunc_ready_load"},
    }},
}

SYSTEMS_ITEMS  = {}
SYSTEMS_GROUPS = {}
local function build_systems_index()
    for _, group in ipairs(SYSTEMS_PANEL) do
        local first = #SYSTEMS_ITEMS + 1
        for _, item in ipairs(group.items) do
            SYSTEMS_ITEMS[#SYSTEMS_ITEMS + 1] = { label = item[1], dr = item[2] }
        end
        SYSTEMS_GROUPS[#SYSTEMS_GROUPS + 1] = { title = group.title, first = first, last = #SYSTEMS_ITEMS }
    end
end
build_systems_index()

local SYS_REF = {}
local SYS_VAL = {}
local sys_retry_at = 0

-- ------------------------------------------------------------------ STATE ---
local recorder_path    = "(none)"
local last_tick_time   = 0
local last_frame_time  = 0
local smooth_pitch     = 0.0
local smooth_roll      = 0.0

local toast_text       = nil
local toast_until      = 0.0
local learn_last_event = "(waiting for input)"
local learn_events     = 0
local prev_joy_buttons = {}
local prev_raw_axes    = {}
local status_rects     = {}

-- ---------------------------------------------------------------- HELPERS ---
local LOG_HEADER = "Time_Sec,Altitude_FT,Mach,IAS_KTS,Pitch_Deg,Roll_Deg,G_Load,FuelFlow_KgH\n"

local function open_flight_log()
    local candidates = {}
    if CONFIG.log_to_desktop then
        local home = os.getenv("HOME")
        if home and home ~= "" then
            candidates[#candidates + 1] = home .. "/Desktop/XPlane_CitationX_FlightLog.csv"
        end
    end
    if SCRIPT_DIRECTORY and SCRIPT_DIRECTORY ~= "" then
        candidates[#candidates + 1] = SCRIPT_DIRECTORY .. "XPlane_CitationX_FlightLog.csv"
    end
    candidates[#candidates + 1] = "XPlane_CitationX_FlightLog.csv"

    for _, path in ipairs(candidates) do
        local fd = io.open(path, "w")
        if fd then return fd, path end
    end
    return nil, nil
end

local function arm_recorder()
    if log_fd then return true end
    local path
    log_fd, path = open_flight_log()
    if log_fd then
        log_fd:write(LOG_HEADER)
        log_fd:flush()
        recorder_path = tostring(path)
        logMsg("Citation X Suite: flight recorder armed -> " .. recorder_path)
        return true
    end
    recorder_path = "(unavailable)"
    logMsg("Citation X Suite: WARNING - could not open flight log file")
    return false
end

local function disarm_recorder()
    if log_fd then
        log_fd:close()
        log_fd = nil
        logMsg("Citation X Suite: flight recorder file closed")
    end
end

local function total_fuel_flow_kg_h()
    return ((fuel_flow_kg_sec[0] or 0.0) + (fuel_flow_kg_sec[1] or 0.0)) * 3600.0
end

local function shaped_axis(value)
    local magnitude = math.abs(value or 0.0)
    if magnitude <= CONFIG.deadzone then return 0.0 end
    local span = 1.0 - CONFIG.deadzone
    if span <= 0.0 then return value end
    local scaled = (magnitude - CONFIG.deadzone) / span
    scaled = scaled ^ CONFIG.curve_exponent
    if value < 0.0 then scaled = -scaled end
    return scaled
end

local function write_log_line(now)
    if not (CONFIG.log_enabled and log_fd) then return end
    log_fd:write(string.format("%.1f,%.0f,%.3f,%.1f,%.2f,%.2f,%.2f,%.0f\n",
        now,
        (elevation_m or 0.0) * 3.28084,
        mach_no or 0.0,
        ias_kts or 0.0,
        pitch_deg or 0.0,
        roll_deg or 0.0,
        g_nrml or 1.0,
        total_fuel_flow_kg_h()))
    log_fd:flush()
end

local function maybe_start_emergency()
    if not CONFIG.emergency_enabled then return end
    if not emergency_armed or emergency_left > 0.0 then return end
    if (elevation_m or 0.0) * 3.28084 > CONFIG.emergency_alt_ft
        and (mach_no or 0.0) > CONFIG.emergency_mach
        and math.random() < CONFIG.emergency_chance_1hz then
        emergency_left  = CONFIG.emergency_duration_sec
        emergency_armed = false
        print("Citation X Suite: simulated bleed air and pressurization warning")
    end
end

local function toast(text)
    toast_text  = text
    toast_until = (sim_time or 0.0) + 2.0
end

local function toast_state(name, on)
    toast(name .. (on and ": ON" or ": OFF"))
end

-- -------------------------------------------------------- SUITE CONTROL -----
function citationx_set_hud(on)
    CONFIG.hud_enabled = (on == true)
    toast_state("HUD", CONFIG.hud_enabled)
end

function citationx_set_status(on)
    CONFIG.status_enabled = (on == true)
    toast_state("STATUS PANEL", CONFIG.status_enabled)
end

function citationx_set_systems(on)
    CONFIG.systems_panel_enabled = (on == true)
    toast_state("C750 SYSTEMS", CONFIG.systems_panel_enabled)
end

function citationx_set_axis(on)
    CONFIG.axis_optimizer_enabled = (on == true)
    toast_state("AXIS OPTIMIZER", CONFIG.axis_optimizer_enabled)
end

function citationx_set_logging(on)
    on = (on == true)
    CONFIG.log_enabled = on
    if on then
        if arm_recorder() then
            toast("FLIGHT RECORDER: REC")
        else
            toast("FLIGHT RECORDER: NO FILE")
        end
    else
        disarm_recorder()
        toast("FLIGHT RECORDER: OFF")
    end
end

function citationx_set_emergency(on)
    CONFIG.emergency_enabled = (on == true)
    if not CONFIG.emergency_enabled then
        emergency_left  = 0.0
        emergency_armed = true
    end
    toast_state("EMERGENCY GEN", CONFIG.emergency_enabled)
end

function citationx_set_input_map(on)
    CONFIG.input_map_enabled = (on == true)
    toast_state("INPUT MAPPER", CONFIG.input_map_enabled)
end

function citationx_set_stick_hdg(on)
    CONFIG.stick_hdg_enabled = (on == true)
    if not CONFIG.stick_hdg_enabled then
        stick_hdg_live_axis = -1
        stick_base_raw      = {}
        stick_dead_axis     = {}
        stick_hdg_hold_s    = 0.0
    end
    toast_state("STICK HDG KNOB", CONFIG.stick_hdg_enabled)
end

function citationx_set_axis_monitor(on)
    CONFIG.axis_monitor = (on == true)
    toast_state("AXIS MONITOR", CONFIG.axis_monitor)
end

function citationx_test_emergency()
    emergency_left  = CONFIG.emergency_duration_sec
    emergency_armed = false
    logMsg("Citation X Suite: TEST bleed air / pressurization warning")
    print("Citation X Suite: test bleed air and pressurization warning")
end

function citationx_set_module(key, on)
    for i = 1, #SUITE_MODULES do
        if SUITE_MODULES[i].key == key then
            SUITE_MODULES[i].set(on == true)
            return
        end
    end
end

function citationx_toggle_module(key)
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        if m.key == key then
            m.set(not m.get())
            return
        end
    end
end

function citationx_status_report()
    logMsg("Citation X Suite: status report ----------------------------------")
    logMsg(string.format("  aircraft = %s (C750=%s)", tostring(PLANE_ICAO), tostring(is_c750)))
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        local text = m.state()
        logMsg(string.format("  %-16s : %s", m.label, text))
    end
end

-- ------------------------------------------------------------ INPUT MAPPER --
local function probe_path()
    local home = os.getenv("HOME")
    if CONFIG.input_probe_to_desktop and home and home ~= "" then
        return home .. "/Desktop/CitationX_InputProbe.txt"
    end
    if SCRIPT_DIRECTORY and SCRIPT_DIRECTORY ~= "" then
        return SCRIPT_DIRECTORY .. "CitationX_InputProbe.txt"
    end
    return "CitationX_InputProbe.txt"
end

local function probe_log(line)
    learn_last_event = line
    learn_events     = learn_events + 1
    local fd = io.open(probe_path(), "a")
    if fd then
        fd:write(os.date("%Y-%m-%d %H:%M:%S") .. "  " .. line .. "\n")
        fd:close()
    end
end

local function fire_binding(binding)
    if binding.action then binding.action() end
    if binding.command then command_once(binding.command) end
    toast(binding.label)
    logMsg("Citation X Suite: input -> " .. binding.label)
end

local function binding_matches(b, vkey, ctrl, opt, shift)
    return b.vkey == vkey
        and (b.ctrl == true) == ctrl
        and (b.opt == true) == opt
        and (b.shift == true) == shift
end

local function find_binding(vkey)
    local ctrl  = (CONTROL_KEY == true)
    local opt   = (OPTION_KEY == true)
    local shift = (SHIFT_KEY == true)
    for i = 1, #INPUT_BINDINGS do
        local b = INPUT_BINDINGS[i]
        if binding_matches(b, vkey, ctrl, opt, shift) then return b end
    end
    for i = 1, #CITX_BINDINGS do
        local b = CITX_BINDINGS[i]
        if binding_matches(b, vkey, ctrl, opt, shift) then return b end
    end
    return nil
end

local function yn(value)
    if value == true then return "1" end
    return "0"
end

function citationx_keystroke()
    local vkey = (VKEY or 0) % 256
    if CONFIG.input_learn_mode then
        probe_log(string.format("KEY vkey=%d (0x%02X) ctrl=%s opt=%s shift=%s action=%s char=%q",
            vkey, vkey, yn(CONTROL_KEY), yn(OPTION_KEY), yn(SHIFT_KEY),
            tostring(KEY_ACTION), CKEY or ""))
    end
    if KEY_ACTION ~= "pressed" or not CONFIG.input_map_enabled then return end
    local binding = find_binding(vkey)
    if binding then
        RESUME_KEY = true
        fire_binding(binding)
    end
end

function citationx_mouse_click()
    if CONFIG.input_learn_mode then
        probe_log("CLICK status=" .. tostring(MOUSE_STATUS))
    end

    -- Click the on-screen status panel to toggle a subsystem.
    if CONFIG.status_clickable and CONFIG.status_enabled and MOUSE_STATUS == "down" then
        local mx = MOUSE_X or -1.0
        local my = MOUSE_Y or -1.0
        for i = 1, #status_rects do
            local r = status_rects[i]
            if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
                citationx_toggle_module(r.key)
                RESUME_MOUSE_CLICK = true
                return
            end
        end
    end
end

function citationx_altitude(delta_ft)
    local target = (alt_sel_ft or 0.0) + delta_ft
    if target < 0.0 then target = 0.0 end
    if target > 60000.0 then target = 60000.0 end
    alt_sel_ft    = target
    alt_legacy_ft = target
    toast(string.format("ALT SEL  %.0f ft", target))
end

function citationx_heading(delta_deg)
    local target = ((hdg_sel_deg or 0.0) + delta_deg) % 360.0
    hdg_sel_deg = target
    toast(string.format("HDG SEL  %03.0f", target))
end

function citationx_mouse_wheel()
    if CONFIG.input_learn_mode then
        probe_log(string.format("WHEEL wheel=%s clicks=%s",
            tostring(MOUSE_WHEEL_NUMBER), tostring(MOUSE_WHEEL_CLICKS)))
    end
    if MOUSE_WHEEL_NUMBER ~= 1 then return end
    local clicks = MOUSE_WHEEL_CLICKS or 0
    if clicks == 0 then return end
    if CONFIG.thumbwheel_heading then
        RESUME_MOUSE_WHEEL = true
        local direction = CONFIG.heading_wheel_invert and -1 or 1
        citationx_heading(clicks * CONFIG.heading_step_deg * direction)
    elseif CONFIG.thumbwheel_altitude then
        RESUME_MOUSE_WHEEL = true
        local direction = CONFIG.altitude_wheel_invert and -1 or 1
        citationx_altitude(clicks * CONFIG.altitude_step_deg * direction)
    end
end

function citationx_set_input_learn(on)
    local was_on = (CONFIG.input_learn_mode == true)
    CONFIG.input_learn_mode = (on == true)
    learn_last_event = "(waiting for input)"
    learn_events     = 0
    if CONFIG.input_learn_mode then
        probe_log("=== LEARN MODE START ===")
        logMsg("Citation X Suite: input learn mode ON -> " .. probe_path())
        toast("LEARN MODE: ON")
    elseif was_on then
        -- Only close a session that was really open. FlyWithLua runs the
        -- macro's deactivate chunk on every script load, which used to append
        -- a STOP line each reload and made the probe look like it had run.
        probe_log("=== LEARN MODE STOP ===")
        logMsg("Citation X Suite: input learn mode OFF")
        toast("LEARN MODE: OFF")
    end
end

-- ------------------------------------------------- C750 SYSTEMS POLLING ----
local function poll_systems(now)
    local retry = (now >= sys_retry_at)
    if retry then sys_retry_at = now + 5.0 end
    for i = 1, #SYSTEMS_ITEMS do
        if not SYS_REF[i] and retry then
            SYS_REF[i] = XPLMFindDataRef(SYSTEMS_ITEMS[i].dr)
        end
        if SYS_REF[i] then
            SYS_VAL[i] = XPLMGetDataf(SYS_REF[i])
        else
            SYS_VAL[i] = nil
        end
    end
end

-- ------------------------------------------------------------- FRAME LOOP ---
function citationx_frame()
    local now = sim_time or 0.0
    local dt  = now - last_frame_time
    if dt < 0.0 then dt = 0.0 end
    last_frame_time = now

    is_c750 = (PLANE_ICAO == "C750")

    -- 2. axis optimizer
    if CONFIG.axis_optimizer_enabled and joy_avail_pitch == 1 and joy_avail_roll == 1 then
        if not optimizer_active then
            ovr_joystick_pitch = 1
            ovr_joystick_roll  = 1
            optimizer_active   = true
            logMsg("Citation X Suite: axis optimizer engaged")
        end
        local k = CONFIG.smoothing_factor
        local target_pitch = shaped_axis(joy_pitch)
        local target_roll  = shaped_axis(joy_roll)
        smooth_pitch = smooth_pitch + k * (target_pitch - smooth_pitch)
        smooth_roll  = smooth_roll  + k * (target_roll  - smooth_roll)
        yoke_pitch_ratio = smooth_pitch
        yoke_roll_ratio  = smooth_roll
    elseif optimizer_active then
        ovr_joystick_pitch = 0
        ovr_joystick_roll  = 0
        optimizer_active   = false
        logMsg("Citation X Suite: axis optimizer released")
    end

    -- Spring-centered stick axis -> rate-based heading bug. Deflection is
    -- measured against each axis' learned rest value, so a parked axis (idle
    -- trigger at raw 0, stale pad slot, drift) never drives the bug.
    if CONFIG.stick_hdg_enabled and dt > 0.0 then
        -- Revive a vetoed slot once it reports a sane centered value again.
        for idx in pairs(stick_dead_axis) do
            local raw = joy_raw_axes[idx]
            if raw and math.abs(raw - CONFIG.stick_hdg_center) < 0.10 then
                stick_dead_axis[idx] = nil
            end
        end

        local axis = CONFIG.stick_hdg_axis
        if axis < 0 then
            -- Drop a pinned axis whose slot went silent (the pad switched from
            -- USB to Bluetooth, was unplugged) so detection can start over.
            if stick_hdg_live_axis >= 0
                and joy_raw_axes[stick_hdg_live_axis] == nil then
                stick_hdg_live_axis = -1
            end
            if stick_hdg_live_axis >= 0 then
                axis = stick_hdg_live_axis
            else
                axis = detect_stick_hdg_axis()
                if axis then
                    stick_hdg_live_axis = axis
                    if CONFIG.stick_hdg_sticky then
                        logMsg("Citation X Suite: heading knob locked to raw axis "
                            .. axis .. " (right stick)")
                    end
                end
            end
        end

        if axis and axis >= 0 then
            stick_hdg_live_axis = axis
            local d   = stick_axis_deflection(axis)
            local mag = math.abs(d)
            local raw = joy_raw_axes[axis] or CONFIG.stick_hdg_center

            -- A slot pinned at a hard extreme for a long time is usually the
            -- pad's *other* interface (USB vs Bluetooth) going silent, not a
            -- held stick. Veto it so the bug cannot free-run; detection then
            -- picks up the interface that is actually alive.
            if mag >= 0.9 and (raw <= 0.02 or raw >= 0.98) then
                stick_hdg_hold_s = stick_hdg_hold_s + dt
                if CONFIG.stick_hdg_axis < 0
                    and stick_hdg_hold_s >= CONFIG.stick_hdg_stale_hold_s then
                    stick_dead_axis[axis] = true
                    stick_hdg_live_axis   = -1
                    stick_hdg_hold_s      = 0.0
                    axis                  = -1
                end
            else
                stick_hdg_hold_s = 0.0
            end

            if axis and axis >= 0 then
                if mag > CONFIG.stick_hdg_deadzone then
                    local sign = (d > 0.0) and 1 or -1
                    local scaled = (mag - CONFIG.stick_hdg_deadzone)
                                 / (1.0 - CONFIG.stick_hdg_deadzone)
                    citationx_heading(sign * scaled
                        * CONFIG.stick_hdg_rate_dps * dt)
                elseif CONFIG.stick_hdg_axis < 0
                    and not CONFIG.stick_hdg_sticky then
                    -- Non-sticky auto mode: forget the axis when it is back at
                    -- rest so the next push re-detects. In sticky (default)
                    -- mode the right stick stays locked for the whole session.
                    stick_hdg_live_axis = -1
                end
            end
        end
        stick_baseline_update()
    end

    -- 3. + 4. once-per-second tasks
    if now - last_tick_time >= 1.0 then
        last_tick_time = now
        write_log_line(now)
        maybe_start_emergency()
    end

    if emergency_left > 0.0 then
        emergency_left = emergency_left - dt
        if emergency_left <= 0.0 then
            emergency_left  = 0.0
            emergency_armed = true
            logMsg("Citation X Suite: emergency condition cleared")
        end
    end

    -- 5. joystick buttons: learn logging + mapped actions
    for i = 0, 63 do
        local value = joy_buttons[i] or 0
        if value ~= (prev_joy_buttons[i] or 0) then
            prev_joy_buttons[i] = value
            if CONFIG.input_learn_mode then
                probe_log(string.format("JOY btn=%d %s", i, (value == 1) and "down" or "up"))
            end
            if value == 1 and CONFIG.input_map_enabled and JOY_BINDINGS[i] then
                fire_binding(JOY_BINDINGS[i])
            end
        end
    end

    -- 6. raw axes: learn logging (find the physical index for a stick)
    if CONFIG.input_learn_mode then
        for i = 0, 15 do
            local v = joy_raw_axes[i] or 0.0
            if math.abs(v - (prev_raw_axes[i] or 0.0)) > 0.05 then
                prev_raw_axes[i] = v
                probe_log(string.format("AXIS idx=%d value=%.3f assign=%s",
                    i, v, tostring(joy_raw_assign[i] or 0)))
            end
        end
    end

    -- 7. aircraft systems readback (only meaningful on the Citation X)
    if CONFIG.systems_panel_enabled and is_c750 then
        poll_systems(now)
    end
end

-- ------------------------------------------------------------------- HUD ----
local function draw_text_right(right_x, y, text, r, g, b)
    draw_string(right_x - measure_string(text), y, text, r, g, b)
end

local function draw_bar(x, y_bottom, y_top, w, color, alpha)
    glColor4f(color[1], color[2], color[3], alpha or 1.0)
    glRectf(x, y_bottom, x + w, y_top)
end

local function fit_text(text, max_px)
    if measure_string(text) <= max_px then return text end
    local trimmed = text
    while #trimmed > 1 and measure_string(trimmed .. "...") > max_px do
        trimmed = trimmed:sub(1, -2)
    end
    return trimmed .. "..."
end


local function systems_panel_height()
    local st = HUD_STYLE
    local h  = st.sys_pad + 26 + 20
    for _, grp in ipairs(SYSTEMS_GROUPS) do
        h = h + 20
        local n = grp.last - grp.first + 1
        h = h + math.ceil(n / st.sys_cols) * st.sys_row_h
        h = h + 12
    end
    return h + st.sys_pad
end

local function draw_systems_panel(screen_w, screen_h)
    local st = HUD_STYLE
    local w  = st.sys_w
    local x  = screen_w - w - 20
    local top = screen_h - 20
    local h  = systems_panel_height()
    local bottom = top - h

    draw_bar(x, bottom, top, w, st.bg)
    draw_bar(x, top - 24, top, w, st.header_bg, 0.90)
    draw_bar(x, top - 26, top - 24, w, st.accent)
    draw_string(x + st.sys_pad, top - 18, "C750 SYSTEMS", st.accent[1], st.accent[2], st.accent[3])
    if not is_c750 then
        draw_text_right(x + w - st.sys_pad, top - 18, "NO DATA", st.warn[1], st.warn[2], st.warn[3])
    end

    local col_w = (w - st.sys_pad * 2) / st.sys_cols
    local y = top - 24 - 20
    for _, grp in ipairs(SYSTEMS_GROUPS) do
        draw_string(x + st.sys_pad, y, grp.title, st.subhdr[1], st.subhdr[2], st.subhdr[3])
        y = y - 20
        local i = grp.first
        while i <= grp.last do
            for c = 0, st.sys_cols - 1 do
                local idx = i + c
                if idx <= grp.last then
                    local it = SYSTEMS_ITEMS[idx]
                    local v  = SYS_VAL[idx]
                    local r, g, b
                    if v == nil then
                        r, g, b = st.dim[1], st.dim[2], st.dim[3]
                    elseif v >= 0.5 then
                        r, g, b = st.ok[1], st.ok[2], st.ok[3]
                    elseif v <= -0.5 then
                        r, g, b = st.warn[1], st.warn[2], st.warn[3]
                    else
                        r, g, b = st.dim[1], st.dim[2], st.dim[3]
                    end
                    local cx = x + st.sys_pad + c * col_w
                    glColor4f(r, g, b, 1.0)
                    glRectf(cx, y - 1, cx + 4, y + 7)
                    draw_string(cx + 8, y, it.label, r, g, b)
                end
            end
            y = y - st.sys_row_h
            i = i + st.sys_cols
        end
        y = y - 12
    end
end

local function draw_status_section(x, w, pad, top_y)
    local st = HUD_STYLE
    status_rects = {}

    draw_string(x + pad, top_y, "SUITE STATUS", st.subhdr[1], st.subhdr[2], st.subhdr[3])
    local first_y = top_y - 20

    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        local y = first_y - (i - 1) * st.status_row_h
        local text, col = m.state()

        glColor4f(col[1], col[2], col[3], 1.0)
        glRectf(x + pad, y - 1, x + pad + 5, y + 8)
        draw_string(x + pad + 11, y, m.label, st.label[1], st.label[2], st.label[3])
        draw_text_right(x + w - pad, y, text, col[1], col[2], col[3])

        status_rects[#status_rects + 1] = {
            key = m.key,
            x0 = x, x1 = x + w,
            y0 = y - 3, y1 = y + st.status_row_h - 3,
        }
    end

    return first_y - (#SUITE_MODULES - 1) * st.status_row_h
end

function citationx_hud()
    local screen_w = SCREEN_WIDTH  or 1920
    local screen_h = SCREEN_HIGHT or 1080

    local st = HUD_STYLE
    local x, w, pad = st.x, st.width, st.pad

    local mach   = mach_no or 0.0
    local gload  = g_nrml or 1.0
    local alt_ft = (elevation_m or 0.0) * 3.28084

    local show_body    = CONFIG.hud_enabled
    local show_status  = CONFIG.status_enabled and (CONFIG.hud_enabled or CONFIG.show_when_hud_off)

    if show_body or show_status then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
    end

    if show_body or show_status then
        local panel_top = screen_h - 20
        local title_y   = panel_top - 20

        local entries = {}
        if show_body then
            local mach_color = (mach > CONFIG.mach_warn) and st.alert or st.value
            local g_color    = (gload > CONFIG.g_warn_high or gload < CONFIG.g_warn_low) and st.warn or st.value
            entries = {
                { string.format("MACH   LIM %.2f", CONFIG.mach_warn), string.format("%.3f", mach), mach_color },
                { "AIRSPEED", string.format("%.0f kt", ias_kts or 0.0), st.value },
                { "ALTITUDE", string.format("%.0f ft", alt_ft), st.value },
                { "ALT SEL",  string.format("%.0f ft", alt_sel_ft or 0.0), st.accent },
                { "HDG SEL",  string.format("%03.0f deg", hdg_sel_deg or 0.0), st.accent },
                { "G-LOAD",   string.format("%+.2f G", gload), g_color },
                { "FUEL FLOW", string.format("%.0f kg/h", total_fuel_flow_kg_h()), st.value },
                { "ATTITUDE", string.format("%+.1f / %+.1f deg", pitch_deg or 0.0, roll_deg or 0.0), st.value },
            }
        end

        local row1_y = title_y - 28
        local last_body_y = row1_y - (#entries == 0 and 0 or (#entries - 1) * st.row_h)
        if #entries == 0 then last_body_y = title_y - 8 end

        local status_header_y = last_body_y - 26
        local status_first_y  = status_header_y - 20
        local status_last_y   = status_first_y - (#SUITE_MODULES - 1) * st.status_row_h
        local panel_bottom    = status_last_y - 16

        draw_bar(x, panel_bottom, panel_top, w, st.bg)
        draw_bar(x, title_y - 10, panel_top, w, st.header_bg, 0.90)
        draw_bar(x, title_y - 12, title_y - 10, w, st.accent)

        draw_string(x + pad, title_y, "CITATION X   MASTER SUITE", st.accent[1], st.accent[2], st.accent[3])

        if not is_c750 then
            draw_text_right(x + w - pad, title_y, "NOT C750", st.warn[1], st.warn[2], st.warn[3])
        else
            draw_text_right(x + w - pad, title_y, "v2.0", st.label[1], st.label[2], st.label[3])
        end

        if show_body then
            for i = 1, #entries do
                local y = row1_y - (i - 1) * st.row_h
                draw_string(x + pad, y, entries[i][1], st.label[1], st.label[2], st.label[3])
                local c = entries[i][3]
                draw_text_right(x + w - pad, y, entries[i][2], c[1], c[2], c[3])
            end
        end

        if show_status then
            draw_status_section(x, w, pad, status_header_y)
        end

        -- alert pills
        local pill_y = panel_bottom - 14
        local function pill(text, color)
            local text_w = measure_string(text)
            draw_bar(x, pill_y - 18, pill_y + 6, text_w + 22, color, 0.80)
            draw_string(x + 11, pill_y - 12, text, 0.04, 0.04, 0.04)
            pill_y = pill_y - 30
        end

        if show_body then
            if mach > CONFIG.mach_warn then
                pill(string.format("MACH LIMIT EXCEEDED  %.3f", mach), st.alert)
            end
            if gload > CONFIG.g_warn_high or gload < CONFIG.g_warn_low then
                pill(string.format("STRUCTURAL G-LOAD  %+.2f G", gload), st.warn)
            end
            if emergency_left > 0.0 and math.floor((sim_time or 0.0) * 2) % 2 == 0 then
                pill("BLEED AIR / PRESSURIZATION WARNING", st.alert)
            end
        end
        if not is_c750 then
            pill("NOT CITATION X - C750 SYSTEMS UNAVAILABLE", st.warn)
        end
    end

    if CONFIG.systems_panel_enabled then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        draw_systems_panel(screen_w, screen_h)
    end

    if CONFIG.axis_monitor then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        local rows = {}
        for i = 0, 63 do
            local a = joy_raw_assign[i] or 0
            local c = stick_axis_centered(i)
            if a ~= 0 or math.abs(c) > 0.05 or i == stick_hdg_live_axis then
                rows[#rows + 1] = { idx = i, assign = a, c = c }
            end
        end
        local box_w = 300
        local box_x = 20
        local box_y = 20
        local box_h = 44 + (#rows + 2) * 18
        glColor4f(st.learn_bg[1], st.learn_bg[2], st.learn_bg[3], st.learn_bg[4])
        glRectf(box_x, box_y, box_x + box_w, box_y + box_h)
        draw_string(box_x + 10, box_y + box_h - 20, "AXIS MONITOR",
            st.learn[1], st.learn[2], st.learn[3])
        local ry = box_y + box_h - 42
        for _, a in ipairs(rows) do
            local live = (a.idx == stick_hdg_live_axis)
            local r, g, b = st.label[1], st.label[2], st.label[3]
            if live then r, g, b = st.ok[1], st.ok[2], st.ok[3] end
            draw_string(box_x + 10, ry, string.format("AX%3d", a.idx), r, g, b)
            draw_string(box_x + 48, ry, fit_text(axis_assign_name(a.assign), 90), r, g, b)
            local cx = box_x + 190
            glColor4f(st.dim[1], st.dim[2], st.dim[3], 1.0)
            glRectf(cx - 40, ry + 2, cx + 40, ry + 5)
            glColor4f(r, g, b, 1.0)
            glRectf(cx, ry + 1, cx + a.c * 40, ry + 7)
            draw_string(box_x + 238, ry, string.format("%+.2f", a.c), r, g, b)
            ry = ry - 18
        end
        draw_string(box_x + 10, ry, "Push the right stick; triggers (L2/R2) are ignored.",
            0.60, 0.80, 0.90)
        draw_string(box_x + 10, ry - 18, "Green = locked heading-knob axis.", 0.60, 0.80, 0.90)
    end

    if toast_text and (sim_time or 0.0) < toast_until then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        local text_w = measure_string(toast_text)
        local box_w  = text_w + 32
        local box_x  = (screen_w - box_w) / 2
        local box_y  = screen_h - 96
        glColor4f(0.02, 0.06, 0.09, 0.85)
        glRectf(box_x, box_y - 8, box_x + box_w, box_y + 22)
        glColor4f(HUD_STYLE.accent[1], HUD_STYLE.accent[2], HUD_STYLE.accent[3], 1.0)
        glRectf(box_x, box_y - 8, box_x + 4, box_y + 22)
        draw_string(box_x + 16, box_y + 3, toast_text,
            HUD_STYLE.value[1], HUD_STYLE.value[2], HUD_STYLE.value[3])
    end

    if CONFIG.input_learn_mode then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        local box_w = math.min(560, screen_w - 40)
        local box_x = screen_w - box_w - 20
        local box_y = screen_h - 260
        local box_h = 134
        glColor4f(st.learn_bg[1], st.learn_bg[2], st.learn_bg[3], st.learn_bg[4])
        glRectf(box_x, box_y - box_h, box_x + box_w, box_y + 10)
        draw_string(box_x + 10, box_y - 4, "INPUT LEARN MODE  ->  CitationX_InputProbe.txt",
            st.learn[1], st.learn[2], st.learn[3])
        draw_string(box_x + 10, box_y - 26, "LAST : " .. fit_text(learn_last_event, box_w - 24), 1, 1, 1)
        draw_string(box_x + 10, box_y - 44, string.format("EVENT COUNT : %d", learn_events), 0.85, 0.85, 0.85)
        draw_string(box_x + 10, box_y - 62, "Press every MX / PS4 control once, one at a time.", 0.85, 0.85, 0.85)
        draw_string(box_x + 10, box_y - 80, "Map: Ctrl+Shift 1-5 lights, 6 AP, 7 HDG, 8 REV, 9/0 ALT.", 0.60, 0.80, 0.90)
        draw_string(box_x + 10, box_y - 98, "C750 systems: Ctrl+Shift letters, Ctrl+Opt digit/letters.", 0.60, 0.80, 0.90)
    end
end

-- --------------------------------------------------------------- LIFECYCLE --
function citationx_shutdown()
    ovr_joystick_pitch = 0
    ovr_joystick_roll  = 0
    optimizer_active   = false
    disarm_recorder()
end

function citationx_init()
    math.randomseed(os.time())
    ovr_joystick_pitch = 0
    ovr_joystick_roll  = 0

    if CONFIG.log_enabled then
        arm_recorder()
    end
    if SCRIPT_DIRECTORY and SCRIPT_DIRECTORY ~= "" then
        logMsg("Citation X Suite: loaded from " .. SCRIPT_DIRECTORY)
    end
    citationx_status_report()
end

citationx_init()
do_every_frame("citationx_frame()")
do_every_draw("citationx_hud()")
do_on_exit("citationx_shutdown()")
do_on_keystroke("citationx_keystroke()")
do_on_mouse_click("citationx_mouse_click()")
do_on_mouse_wheel("citationx_mouse_wheel()")

-- ------------------------------------------------ COMMANDS + MACRO MENU -----
-- Register each subsystem toggle as a real X-Plane command (so it can be
-- bound to a key or joystick button in Settings > Joystick) and as a
-- FlyWithLua menu switch (so the menu shows an on/off checkmark).
for _, m in ipairs(SUITE_MODULES) do
    create_command("CitationXSuite/toggle_" .. m.key,
        "CitationX Suite: toggle " .. m.label,
        "citationx_toggle_module('" .. m.key .. "')", "", "")
    add_macro("CitationX Suite: " .. m.macro,
        "citationx_set_module('" .. m.key .. "', true)",
        "citationx_set_module('" .. m.key .. "', false)",
        m.get() and "activate" or "deactivate")
end

create_command("CitationXSuite/test_emergency",
    "CitationX Suite: preview the emergency warning",
    "citationx_test_emergency()", "", "")
create_command("CitationXSuite/status_report",
    "CitationX Suite: write the active-system report to Log.txt",
    "citationx_status_report()", "", "")

add_macro("CitationX Suite: preview emergency warning", "citationx_test_emergency()")
add_macro("CitationX Suite: log status report", "citationx_status_report()")
