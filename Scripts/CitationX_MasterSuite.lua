-- ============================================================================
--  CESSNA CITATION X MASTER SUITE
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
--  Version 2.1
-- ----------------------------------------------------------------------------
--  Systems:
--    1. Axis optimizer (deadzone, curve, smoothing) via joystick overrides
--    2. 1 Hz telemetry flight data recorder -> CSV
--    3. Trigger-based bleed-air / pressurization emergency generator
--    4. Input mapper: Logitech MX keys / mouse events / joystick buttons
--    5. Control panel: live ON/OFF state of every subsystem; click a row to
--       toggle it
--
--  There is deliberately NO telemetry overlay and NO C750 systems readback:
--  the aircraft's own PFD, EICAS and synoptics already show airspeed, altitude,
--  heading, Mach, G, fuel flow, electrics, fuel and anti-ice. The only thing
--  drawn on screen is the control panel (plus the axis monitor / learn-mode
--  diagnostics while they are switched on).
--
--  Everything below is toggleable at runtime from the FlyWithLua macro menu,
--  from X-Plane's joystick/key assignment UI (CitationXSuite/* commands), or by
--  clicking a row on the control panel. The panel always shows which subsystem
--  is currently active, so you are never guessing.
--
--  Verified against: DataRefs.txt, Commands.txt, the aircraft's own xLua
--  scripts (plugins/xlua/scripts/*.lua) and FlyWithLua_Manual_en.pdf.
-- ============================================================================

-- ------------------------------------------------------------------ CONFIG --
CONFIG = {
    -- Everything starts disabled except the DS4 right-stick heading knob and
    -- the keyboard input layer (the one thing the user flies with). Every
    -- module here can be switched on from the control panel (once shown) or
    -- the FlyWithLua macro menu / CitationXSuite/toggle_<key> commands.
    log_enabled            = false,
    log_to_desktop         = true,

    -- Control panel: the live "which subsystem is active" readout and the
    -- suite's panel hub. Visible at load, next to the realism panel; every
    -- other panel starts hidden and is opened from here.
    status_enabled         = true,
    status_clickable       = true,   -- click a row to toggle that system

    -- Takes over pitch/roll input via the per-axis joystick overrides.
    -- Off by default: enable only if you want the custom stick response.
    axis_optimizer_enabled = false,
    deadzone               = 0.03,
    curve_exponent         = 1.6,
    smoothing_factor       = 0.35,

    emergency_enabled      = false,
    emergency_chance_1hz   = 1 / 900,
    emergency_duration_sec = 20,
    emergency_alt_ft       = 15000,
    emergency_mach         = 0.85,

    -- Keyboard layers for the C750 systems. This is a control surface, not a
    -- panel: it must stay on at init even though every drawing module starts
    -- off, otherwise Ctrl+Shift/Alt shortcuts silently stop working.
    input_map_enabled      = true,
    joy_map_enabled        = true,   -- fires JOY_BINDINGS when it is not empty
    -- OFF: the suite must never claim controller buttons. X-Plane's own
    -- joystick mapping is the single source of truth, otherwise pressing a
    -- spare button toggles panels/recorder instead of flying the aircraft.
    joy_autobind_enabled   = false,
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
    stick_hdg_enabled       = true,   -- the one MasterSuite module on at init
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

    -- Right-stick click (DS4 R3) + right-stick movement = look around the 3-D
    -- cockpit. The button suppresses the heading knob while it is held, so the
    -- same stick does not move the bug at the same time. view_pan_axis_* = -1
    -- auto-detects the right stick as the first *moved* spring-centred axis
    -- pair (DS4: raw 2/3). Pin them to fixed RAW indices to override.
    view_pan_enabled        = true,
    view_pan_button         = 11,    -- 0-based physical button in a 64-button device slot (R3)
    view_pan_axis_x         = -1,
    view_pan_axis_y         = -1,
    view_pan_deadzone       = 0.12,
    view_pan_rate_dps       = 80,    -- look speed at full stick deflection
    view_pan_invert_x       = false,
    view_pan_invert_y       = false,
    view_pan_force_3d       = true,  -- R3 switches to the 3-D cockpit if in 2-D
    view_pan_pitch_limit    = 80,    -- degrees, keeps the head inside the cockpit

    axis_monitor            = false,

    altitude_step_ft        = 100,
    altitude_coarse_step_ft = 1000,
    altitude_wheel_invert   = false,
    thumbwheel_altitude     = false,
}

-- ----------------------------------------------------------- PANEL STYLE ----
-- Matches the realism panel: black body, grey border, white Helvetica title,
-- 12 px rows and a 10 px sub-header. {r, g, b} in 0..1; background entries
-- carry alpha. `top` is the absolute top edge in FlyWithLua screen pixels
-- (origin bottom-left) and is updated when the panel is dragged.
SUITE_STYLE = {
    x            = 470,
    top          = nil,          -- nil = top-right of the realism panel on first draw
    width        = 430,
    pad          = 14,
    header_h     = 34,
    sub_h        = 20,
    row_h        = 21,
    footer_h     = 34,
    bg           = {0.00, 0.00, 0.00, 0.90},
    header_bg    = {0.04, 0.04, 0.04, 0.96},
    border       = {0.32, 0.32, 0.32, 1.00},
    title        = {1.00, 1.00, 1.00, 1.00},
    sub          = {0.55, 0.55, 0.55, 1.00},
    label        = {0.80, 0.80, 0.80, 1.00},
    value        = {1.00, 1.00, 1.00, 1.00},
    dim          = {0.45, 0.45, 0.45, 1.00},
    ok           = {0.45, 0.85, 0.50, 1.00},
    warn         = {0.95, 0.72, 0.25, 1.00},
    alert        = {0.95, 0.36, 0.32, 1.00},
    btn          = {0.10, 0.10, 0.10, 1.00},
    -- legacy names kept so the older rows/toast code keeps working
    accent       = {1.00, 1.00, 1.00, 1.00},
    subhdr       = {0.55, 0.55, 0.55, 1.00},
    learn_bg     = {0.10, 0.07, 0.02, 0.85},
    learn        = {1.00, 0.75, 0.20, 1.00},
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
-- the same { label, command/action } shape as INPUT_BINDINGS. It is filled at
-- runtime by citationx_autobind_joy(): only buttons that X-Plane reports as
-- UNASSIGNED are used, so nothing the pilot already mapped is overwritten.
JOY_BINDINGS = {}

-- What the suite puts on the free controller buttons, in order. The first free
-- physical button gets the panel, the next the realism panel, and so on.
JOY_AUTOBIND_ACTIONS = {
    { label = "CONTROL PANEL",  action = function() citationx_toggle_module("status") end },
    { label = "REALISM PANEL",  action = function() command_once("CitationXRealism/hud") end },
    { label = "TEST CALLOUT",   action = function() command_once("CitationXRealism/test_callout") end },
    { label = "FLIGHT RECORDER", action = function() citationx_set_logging(not CONFIG.log_enabled) end },
    { label = "EMERGENCY GEN",  action = function() citationx_set_emergency(not CONFIG.emergency_enabled) end },
    { label = "AXIS MONITOR",   action = function() citationx_set_axis_monitor(not CONFIG.axis_monitor) end },
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
dataref("citationx_sim_time",    "sim/time/total_running_time_sec", "readonly")

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

-- 3-D cockpit look (R3 + right stick). These are the head-tracking offsets the
-- sim itself uses, so writing them pans the view without touching the camera.
dataref("view_head_psi",   "sim/graphics/view/pilots_head_psi", "writable")
dataref("view_head_the",   "sim/graphics/view/pilots_head_the", "writable")
dataref("view_panel_type", "sim/graphics/view/panel_render_type", "readonly")

local fuel_flow_kg_sec = dataref_table("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")

local joy_buttons      = dataref_table("sim/joystick/joystick_button_values")
local joy_btn_assign   = dataref_table("sim/joystick/joystick_button_assignments")
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
local stick_hdg_diag_at = 0.0
local joy_autobind_done = false

-- 3-D cockpit look state (R3 + right stick).
local view_pan_axis_x   = -1
local view_pan_axis_y   = -1
local view_pan_was_held = false
local view_pan_logged   = false
local view_pan_wait_center = false

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
                -- X-Plane publishes -0.01 (or 0) for axes whose device has not
                -- enumerated yet. Latching that as the rest makes the axis look
                -- permanently deflected, freezes the learned centre and the
                -- knob never detects it (the 2026-10-24 "right stick dead"
                -- symptom: base -0.01, deflection 1.02 at rest). Only adopt a
                -- plausible centred first value; triggers rest at 0/1 and are
                -- excluded by stick_axis_is_centered() anyway.
                if math.abs(raw - CONFIG.stick_hdg_center) <= 0.35 then
                    stick_base_raw[i] = raw
                end
            elseif (base < 0.05 or base > 0.95)
                and math.abs(raw - base) > 0.35
                and math.abs(raw - CONFIG.stick_hdg_center) <= 0.15 then
                -- Repair a rest latched before the device went live.
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

-- ---------------------------------------------------------- COCKPIT LOOK ----
-- The DS4 right stick is a pair of adjacent spring-centred axes. Detection
-- runs only while R3 is held and the stick is actually pushed, so the left
-- stick (assigned to pitch/roll) and the triggers (rest at an extreme) can
-- never be picked. Pinned CONFIG.view_pan_axis_x/y values win.
local function view_pan_axis_eligible(j)
    if j < 0 or j > 63 then return false end
    local a = joy_raw_assign[j] or 0
    return a ~= 1 and a ~= 2 and a ~= 3 and a ~= 4
        and not stick_dead_axis[j]
        and not stick_axis_excluded(j)
        and stick_base_raw[j] ~= nil
end

local function view_pan_pair()
    if CONFIG.view_pan_axis_x >= 0 and CONFIG.view_pan_axis_y >= 0 then
        return CONFIG.view_pan_axis_x, CONFIG.view_pan_axis_y
    end
    if view_pan_axis_x >= 0 and view_pan_axis_y >= 0 then
        return view_pan_axis_x, view_pan_axis_y
    end

    -- Most-deflected eligible axis = the stick the pilot just pushed.
    local best, best_mag = nil, CONFIG.view_pan_deadzone
    for i = 0, 31 do
        if view_pan_axis_eligible(i) and stick_axis_is_centered(i) then
            local mag = math.abs(stick_axis_deflection(i))
            if mag > best_mag then best, best_mag = i, mag end
        end
    end
    if not best then return -1, -1 end

    -- Its hardware partner: the adjacent index (DS4 Z/Rz = 2/3, Rx/Ry = 4/5).
    -- Check both neighbours; a pad slot can start on either parity.
    local partner = nil
    local first  = (best % 2 == 0) and (best + 1) or (best - 1)
    local second = (best % 2 == 0) and (best - 1) or (best + 1)
    if view_pan_axis_eligible(first) then
        partner = first
    elseif view_pan_axis_eligible(second) then
        partner = second
    end
    if not partner then return -1, -1 end

    local ax, ay = best, partner
    if ax > ay then ax, ay = ay, ax end
    view_pan_axis_x, view_pan_axis_y = ax, ay
    if not view_pan_logged then
        view_pan_logged = true
        logMsg(string.format(
            "Citation X Suite: cockpit look axes %d/%d on button %d",
            ax, ay, CONFIG.view_pan_button))
    end
    return ax, ay
end

local function view_pan_button_held()
    local b = CONFIG.view_pan_button
    for slot = 0, 1 do
        if (joy_buttons[slot * 64 + b] or 0) == 1 then return true end
    end
    return false
end

-- Returns true while R3 is held, so the heading knob stands down for that frame.
local function citationx_view_pan(dt)
    if not CONFIG.view_pan_enabled then return false end
    if not view_pan_button_held() then
        if view_pan_was_held then
            view_pan_was_held = false
            -- Do not hand the same stick back to the heading knob while it is
            -- still deflected; wait until it re-centres.
            view_pan_wait_center = true
        end
        if view_pan_wait_center then
            local ax, ay = view_pan_axis_x, view_pan_axis_y
            if ax >= 0 and ay >= 0 then
                local dz = CONFIG.view_pan_deadzone
                if math.abs(stick_axis_deflection(ax)) > dz
                    or math.abs(stick_axis_deflection(ay)) > dz then
                    return true
                end
            end
            view_pan_wait_center = false
        end
        return false
    end
    view_pan_wait_center = false

    if not view_pan_was_held then
        view_pan_was_held = true
        if CONFIG.view_pan_force_3d and (view_panel_type or 2) == 0 then
            command_once("sim/view/3d_cockpit_cmnd_look")
        end
        if type(citationx_toast) == "function" then citationx_toast("COCKPIT LOOK") end
    end

    if dt > 0.0 and (view_panel_type or 2) ~= 0 then
        local ax, ay = view_pan_pair()
        if ax >= 0 and ay >= 0 then
            local function shape(v)
                local m = math.abs(v)
                if m <= CONFIG.view_pan_deadzone then return 0.0 end
                local s = (m - CONFIG.view_pan_deadzone)
                        / (1.0 - CONFIG.view_pan_deadzone)
                if v < 0.0 then s = -s end
                return s
            end
            local yaw   = shape(stick_axis_deflection(ax))
            local pitch = -shape(stick_axis_deflection(ay))  -- stick up looks up
            if CONFIG.view_pan_invert_x then yaw   = -yaw end
            if CONFIG.view_pan_invert_y then pitch = -pitch end

            if yaw ~= 0.0 then
                local psi = (view_head_psi or 0.0)
                    + yaw * CONFIG.view_pan_rate_dps * dt
                if psi > 180 then psi = psi - 360 end
                if psi < -180 then psi = psi + 360 end
                view_head_psi = psi
            end
            if pitch ~= 0.0 then
                local lim = CONFIG.view_pan_pitch_limit
                local the = (view_head_the or 0.0)
                    + pitch * CONFIG.view_pan_rate_dps * dt
                if the >  lim then the =  lim end
                if the < -lim then the = -lim end
                view_head_the = the
            end
        end
    end
    return true
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
-- One entry per subsystem the suite owns. `state()` returns the short status
-- word shown on the control panel. `set()` is the single point of control for
-- commands, macros and click-to-toggle.
SUITE_MODULES = {
    {
        key = "status", label = "CONTROL PANEL", macro = "control panel",
        get = function() return CONFIG.status_enabled end,
        set = function(on) citationx_set_status(on) end,
        state = function()
            if CONFIG.status_enabled then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "axis", label = "AXIS OPTIMIZER", macro = "axis optimizer",
        get = function() return CONFIG.axis_optimizer_enabled end,
        set = function(on) citationx_set_axis(on) end,
        state = function()
            if not CONFIG.axis_optimizer_enabled then return "OFF" end
            if optimizer_active then return "ACTIVE" end
            return "ARMED"
        end,
    },
    {
        key = "log", label = "FLIGHT RECORDER", macro = "flight recorder",
        get = function() return CONFIG.log_enabled end,
        set = function(on) citationx_set_logging(on) end,
        state = function()
            if not CONFIG.log_enabled then return "OFF" end
            if log_fd then return "REC" end
            return "NO FILE"
        end,
    },
    {
        key = "emerg", label = "EMERGENCY GEN", macro = "emergency generator",
        get = function() return CONFIG.emergency_enabled end,
        set = function(on) citationx_set_emergency(on) end,
        state = function()
            if not CONFIG.emergency_enabled then return "OFF" end
            if emergency_left > 0.0 then return "TRIGGERED" end
            return "ARMED"
        end,
    },
    {
        key = "input", label = "INPUT MAPPER", macro = "input mapper",
        get = function() return CONFIG.input_map_enabled end,
        set = function(on) citationx_set_input_map(on) end,
        state = function()
            if CONFIG.input_map_enabled then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "learn", label = "LEARN MODE", macro = "input learn mode",
        get = function() return CONFIG.input_learn_mode end,
        set = function(on) citationx_set_input_learn(on) end,
        state = function()
            if CONFIG.input_learn_mode then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "stick", label = "STICK HDG KNOB", macro = "stick heading knob",
        get = function() return CONFIG.stick_hdg_enabled end,
        set = function(on) citationx_set_stick_hdg(on) end,
        state = function()
            if CONFIG.stick_hdg_enabled then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "axmon", label = "AXIS MONITOR", macro = "axis monitor",
        get = function() return CONFIG.axis_monitor end,
        set = function(on) citationx_set_axis_monitor(on) end,
        state = function()
            if CONFIG.axis_monitor then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "look", label = "COCKPIT LOOK", macro = "cockpit look (R3 + stick)",
        get = function() return CONFIG.view_pan_enabled end,
        set = function(on) citationx_set_view_pan(on) end,
        state = function()
            if not CONFIG.view_pan_enabled then return "OFF" end
            if view_pan_was_held then return "PAN" end
            return "ON"
        end,
    },
    -- --- sibling panels from the other suite scripts -------------------------
    -- These scripts share one Lua state, so their globals are reachable here.
    -- Every accessor is nil-guarded so the panel keeps working if a script is
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
            if type(CAB_CONFIG) ~= "table" then return "ABSENT" end
            if CAB_CONFIG.panel_enabled then return "ON" end
            return "OFF"
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
            if type(TRAINER_CONFIG) ~= "table" then return "ABSENT" end
            if TRAINER_CONFIG.panel_enabled then return "ON" end
            return "OFF"
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
            if la_show_last_result == nil then return "ABSENT" end
            if la_displayOn == true then return "SHOWN" end
            return "HIDDEN"
        end,
    },
    {
        key = "efb", label = "EFB", macro = "EFB panel",
        get = function()
            return (type(EFB_CONFIG) == "table") and EFB_CONFIG.panel_enabled or false
        end,
        set = function(on)
            if type(efb_toggle_panel) == "function" then efb_toggle_panel(on) end
        end,
        state = function()
            if type(EFB_CONFIG) ~= "table" then return "ABSENT" end
            if EFB_CONFIG.panel_enabled then return "ON" end
            return "OFF"
        end,
    },
    {
        key = "realism", label = "REALISM PACK", macro = "realism pack",
        get = function()
            return (type(REAL_CONFIG) == "table") and REAL_CONFIG.enabled or false
        end,
        set = function(on)
            if type(real_set_enabled) == "function" then real_set_enabled(on) end
        end,
        state = function()
            if type(REAL_CONFIG) ~= "table" then return "ABSENT" end
            if REAL_CONFIG.enabled then return "ON" end
            return "OFF"
        end,
    },
}

-- Status word -> colour on the control panel.
local function state_color(text)
    local st = SUITE_STYLE
    if text == "ON" or text == "LIVE" or text == "REC"
        or text == "ACTIVE" or text == "ARMED" or text == "SHOWN"
        or text == "PAN" then
        return st.ok
    end
    if text == "TRIGGERED" then return st.alert end
    if text == "OFF" or text == "HIDDEN" then return st.dim end
    return st.warn   -- ABSENT / NO FILE / anything unexpected
end

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
local panel_footer_rect = nil
local panel_header_rect = nil
local panel_drag = { active = false, dx = 0, dy = 0 }
local control_panel_height   -- forward declaration (used by the mouse handler)

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

local function toast(text)
    toast_text  = text
    toast_until = (citationx_sim_time or 0.0) + 2.0
end

-- Sibling scripts (the realism pack) borrow the 2 s toast. Nil-guarded on their
-- side, so the suite still works when this file is absent.
function citationx_toast(text)
    toast(text)
end

local function toast_state(name, on)
    toast(name .. (on and ": ON" or ": OFF"))
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
        toast("BLEED AIR / PRESSURIZATION WARNING")
    end
end

-- -------------------------------------------------------- SUITE CONTROL -----
function citationx_set_status(on)
    CONFIG.status_enabled = (on == true)
    toast_state("CONTROL PANEL", CONFIG.status_enabled)
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

function citationx_set_view_pan(on)
    CONFIG.view_pan_enabled = (on == true)
    if not CONFIG.view_pan_enabled then
        view_pan_was_held = false
        view_pan_wait_center = false
        view_pan_axis_x, view_pan_axis_y = -1, -1
    end
    toast_state("COCKPIT LOOK", CONFIG.view_pan_enabled)
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

-- One-click "the whole suite, back on" / "off again". The control panel row is
-- excluded so enabling everything does not paint the panel on top of the rest.
function citationx_set_all(on)
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        if m.key ~= "status" then m.set(on == true) end
    end
end

-- Fill JOY_BINDINGS from the buttons X-Plane reports as UNASSIGNED. Face and
-- shoulder buttons only (8..17 per device): 0..7 are the D-pad hat on the DS4
-- and 18+ are not physical. Both device slots are scanned because the pad
-- enumerates twice (USB + Bluetooth), so the same action lands on both and
-- survives a reconnect. Nothing already mapped by the pilot is overwritten.
function citationx_autobind_joy()
    if not CONFIG.joy_autobind_enabled then return end
    JOY_BINDINGS = {}

    local free = {}
    for slot = 0, 1 do
        for b = 8, 17 do
            local idx = slot * 64 + b
            if b ~= CONFIG.view_pan_button and (joy_btn_assign[idx] or 0) == 0 then
                free[b] = free[b] or {}
                free[b][#free[b] + 1] = idx
            end
        end
    end

    local bound = 0
    for b = 8, 17 do
        local slots = free[b]
        if slots and bound < #JOY_AUTOBIND_ACTIONS then
            bound = bound + 1
            local a = JOY_AUTOBIND_ACTIONS[bound]
            for i = 1, #slots do
                JOY_BINDINGS[slots[i]] = { label = a.label, action = a.action }
                logMsg(string.format(
                    "Citation X Suite: free joy button %d -> %s",
                    slots[i], a.label))
            end
        end
    end
    if bound == 0 then
        logMsg("Citation X Suite: no free controller buttons to bind")
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
    local n = 0
    for _ in pairs(JOY_BINDINGS) do n = n + 1 end
    logMsg(string.format("  joystick autobind: %d free button(s)", n))
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
    if not CONFIG.status_enabled then
        panel_drag.active = false
        return
    end

    local mx = MOUSE_X or -1.0
    local my = MOUSE_Y or -1.0
    local st = SUITE_STYLE

    -- Drag by the header: down starts, drag moves, up ends.
    if MOUSE_STATUS == "down" then
        local r = panel_header_rect
        if r and mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            panel_drag.active = true
            panel_drag.dx = mx - st.x
            panel_drag.dy = my - (st.top or my)
            RESUME_MOUSE_CLICK = true
            return
        end
    elseif MOUSE_STATUS == "drag" then
        if panel_drag.active then
            local sw = SCREEN_WIDTH or 1920
            local sh = SCREEN_HIGHT or 1080
            local h  = control_panel_height()
            st.x = math.max(0, math.min(mx - panel_drag.dx, sw - st.width))
            st.top = math.max(h, math.min(my - panel_drag.dy, sh))
            RESUME_MOUSE_CLICK = true
        end
        return
    elseif MOUSE_STATUS == "up" then
        if panel_drag.active then
            panel_drag.active = false
            RESUME_MOUSE_CLICK = true
            return
        end
    end

    if not CONFIG.status_clickable or MOUSE_STATUS ~= "down" then return end

    local f = panel_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        citationx_set_status(false)
        RESUME_MOUSE_CLICK = true
        return
    end

    -- Click a row to toggle that subsystem.
    for i = 1, #status_rects do
        local r = status_rects[i]
        if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            citationx_toggle_module(r.key)
            RESUME_MOUSE_CLICK = true
            return
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

-- ------------------------------------------------------------- FRAME LOOP ---
function citationx_frame()
    local now = citationx_sim_time or 0.0
    local dt  = now - last_frame_time
    if dt < 0.0 then dt = 0.0 end
    last_frame_time = now

    is_c750 = (PLANE_ICAO == "C750")

    -- Fill the free-button map once X-Plane has published assignments (or
    -- after 5 s on a virgin config where none exist yet).
    if not joy_autobind_done then
        local ready = (now >= 5.0)
        if not ready then
            for i = 0, 127 do
                if (joy_btn_assign[i] or 0) ~= 0 then
                    ready = true
                    break
                end
            end
        end
        if ready then
            joy_autobind_done = true
            citationx_autobind_joy()
        end
    end

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

    -- R3 + right stick pans the 3-D cockpit. While it is held the same stick
    -- must not also drive the heading bug, so the knob block is skipped.
    local look_held = citationx_view_pan(dt)

    -- Spring-centered stick axis -> rate-based heading bug. Deflection is
    -- measured against each axis' learned rest value, so a parked axis (idle
    -- trigger at raw 0, stale pad slot, drift) never drives the bug.
    if CONFIG.stick_hdg_enabled and dt > 0.0 and not look_held then
        -- Revive a vetoed slot once it reports a sane centered value again.
        for idx in pairs(stick_dead_axis) do
            local raw = joy_raw_axes[idx]
            if raw and math.abs(raw - CONFIG.stick_hdg_center) < 0.10 then
                stick_dead_axis[idx] = nil
            end
        end

        -- A locked axis that turns out to be a flight control must be dropped.
        -- At aircraft load X-Plane can still report an empty assignment table,
        -- which made detection latch onto the roll axis before it was filled;
        -- the sticky lock then kept the heading bug on the left stick.
        if stick_hdg_live_axis >= 0 then
            local a = joy_raw_assign[stick_hdg_live_axis] or 0
            if a == 1 or a == 2 or a == 3 or a == 4 then
                stick_hdg_live_axis = -1
                stick_hdg_hold_s    = 0.0
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
                -- Never autodetect before X-Plane has published the axis
                -- assignments: an empty table makes every axis look free.
                local assignments_ready = false
                for i = 0, 63 do
                    local a = joy_raw_assign[i] or 0
                    if a == 1 or a == 2 or a == 3 or a == 4 then
                        assignments_ready = true
                        break
                    end
                end
                axis = assignments_ready and detect_stick_hdg_axis() or nil
                if axis then
                    stick_hdg_live_axis = axis
                    if CONFIG.stick_hdg_sticky then
                        logMsg("Citation X Suite: heading knob locked to raw axis "
                            .. axis .. " (right stick)")
                    end
                elseif now >= stick_hdg_diag_at then
                    -- Nothing eligible yet. Log every live axis (raw index,
                    -- deflection, assignment enum, learned rest) once every
                    -- 10 s so a bad pick can be pinned without guessing.
                    stick_hdg_diag_at = now + 10.0
                    local parts = {}
                    for i = 0, 31 do
                        local raw = joy_raw_axes[i]
                        if raw ~= nil then
                            parts[#parts + 1] = string.format("%d:d%.2f/a%d/b%.2f",
                                i, math.abs(stick_axis_deflection(i)),
                                joy_raw_assign[i] or 0, stick_base_raw[i] or -1)
                        end
                    end
                    logMsg("Citation X Suite: HDG scan " .. table.concat(parts, " "))
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
    end
    if (CONFIG.stick_hdg_enabled or CONFIG.view_pan_enabled) and dt > 0.0 then
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
            toast("BLEED AIR WARNING CLEARED")
        end
    end

    -- 5. joystick buttons: learn logging + mapped actions.
    -- Buttons are 64 per device (sim/joystick/joystick_button_values is
    -- int[3200] = 50 devices x 64). The DS4 enumerates twice, USB and
    -- Bluetooth, so scan both slots or the pad goes dead when it reconnects
    -- on the other interface.
    for i = 0, 127 do
        local value = joy_buttons[i] or 0
        if value ~= (prev_joy_buttons[i] or 0) then
            prev_joy_buttons[i] = value
            if CONFIG.input_learn_mode then
                probe_log(string.format("JOY btn=%d %s", i, (value == 1) and "down" or "up"))
            end
            if value == 1 and (CONFIG.input_map_enabled or CONFIG.joy_map_enabled)
                and JOY_BINDINGS[i] then
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
end

-- --------------------------------------------------------- ON-SCREEN PANEL ----
-- The only thing the suite draws is the control panel (plus the axis monitor,
-- the learn-mode box and a 2 s toast while those are switched on). There is no
-- telemetry readout and no aircraft-systems mirror: the cockpit already has
-- airspeed, altitude, heading, Mach, G, fuel flow, electrics, fuel and ice.
local function draw_text_right(right_x, y, text, r, g, b)
    draw_string(right_x - measure_string(text), y, text, r, g, b)
end

local function draw_bar(x, y_bottom, y_top, w, color, alpha)
    glColor4f(color[1], color[2], color[3], alpha or color[4] or 1.0)
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

-- Helvetica faces and the realism panel's text metrics.
local function suite_font(size)
    if size == 18 then return draw_string_Helvetica_18 or draw_string end
    if size == 10 then return draw_string_Helvetica_10 or draw_string end
    return draw_string_Helvetica_12 or draw_string
end

local function suite_text(x, y, text, size, color)
    glColor4f(color[1], color[2], color[3], color[4] or 1.0)
    suite_font(size)(x, y, tostring(text or ""))
end

local function suite_text_right(right_x, y, text, size, color)
    local s = tostring(text or "")
    local w = measure_string(s, "Helvetica_" .. tostring(size)) or measure_string(s)
    suite_text(right_x - w, y, s, size, color)
end

-- Shared black-shell drawing: body, 1 px border, 34 px header, divider.
local function draw_shell(x, top, w, h, title, sub)
    local st = SUITE_STYLE
    local bottom = top - h
    draw_bar(x, bottom, top, w, st.bg)
    draw_bar(x, top - 1, top, w, st.border)
    draw_bar(x, bottom, top, 1, st.border)
    draw_bar(x + w - 1, bottom, top, 1, st.border)
    draw_bar(x, bottom, bottom + 1, w, st.border)
    draw_bar(x, top - st.header_h, top, w, st.header_bg)
    draw_bar(x, top - st.header_h, top - st.header_h + 2, w, st.border)
    suite_text(x + st.pad, top - 25, title, 18, st.title)
    if sub and sub ~= "" then
        suite_text_right(x + w - st.pad, top - 22, sub, 10, st.sub)
    end
end

-- Footer button, returns its clickable rectangle.
local function draw_footer_button(x, bottom, w, label)
    local st = SUITE_STYLE
    local by0 = bottom + 8
    local by1 = by0 + st.footer_h - 12
    draw_bar(x + st.pad, by0, by1, w - 2 * st.pad, st.btn)
    local tw = measure_string(label, "Helvetica_10") or measure_string(label)
    suite_text(x + (w - tw) / 2, by0 + 6, label, 10, st.value)
    return { x0 = x + st.pad, x1 = x + w - st.pad, y0 = by0, y1 = by1 }
end

-- header (34) + sub-header (20) + rows + footer + padding
function control_panel_height()
    local st = SUITE_STYLE
    return st.header_h + st.sub_h + 16
        + #SUITE_MODULES * st.row_h + st.footer_h + 8
end

local function draw_control_panel(screen_h)
    local st = SUITE_STYLE
    local w, pad = st.width, st.pad
    local x = st.x

    -- first draw: park the hub to the right of the realism panel
    if st.top == nil then st.top = screen_h - 24 end
    x = math.max(8, math.min(x, (SCREEN_WIDTH or 1920) - w - 8))
    st.x = x
    local top = math.max(control_panel_height() + 8,
        math.min(st.top, screen_h - 8))
    st.top = top
    local bottom = top - control_panel_height()

    status_rects = {}

    draw_shell(x, top, w, control_panel_height(), "CITATION X", "MASTER SUITE")
    suite_text(x + pad, top - st.header_h - 14, "CONTROL PANEL", 10, st.sub)

    local first_y = top - st.header_h - st.sub_h - 14
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        local y = first_y - (i - 1) * st.row_h
        local text = m.state()
        local col  = state_color(text)

        glColor4f(col[1], col[2], col[3], 1.0)
        glRectf(x + pad, y - 1, x + pad + 5, y + 8)
        suite_text(x + pad + 11, y, m.label, 12, st.label)
        suite_text_right(x + w - pad, y, text, 12, col)

        status_rects[#status_rects + 1] = {
            key = m.key,
            x0 = x, x1 = x + w,
            y0 = y - 4, y1 = y + st.row_h - 4,
        }
    end

    panel_header_rect = { x0 = x, x1 = x + w, y0 = top - st.header_h, y1 = top }
    panel_footer_rect = draw_footer_button(x, bottom, w, "HIDE PANEL")
end

function citationx_overlay()
    local screen_w = SCREEN_WIDTH  or 1920
    local screen_h = SCREEN_HIGHT or 1080

    local st = SUITE_STYLE

    if CONFIG.status_enabled then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        draw_control_panel(screen_h)
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
        suite_text(box_x + 10, box_y + box_h - 20, "AXIS MONITOR", 10, st.learn)
        local ry = box_y + box_h - 42
        for _, a in ipairs(rows) do
            local live = (a.idx == stick_hdg_live_axis)
            local r, g, b = st.label[1], st.label[2], st.label[3]
            if live then r, g, b = st.ok[1], st.ok[2], st.ok[3] end
            suite_text(box_x + 10, ry, string.format("AX%3d", a.idx), 12, { r, g, b })
            suite_text(box_x + 48, ry, fit_text(axis_assign_name(a.assign), 90), 12, { r, g, b })
            local cx = box_x + 190
            glColor4f(st.dim[1], st.dim[2], st.dim[3], 1.0)
            glRectf(cx - 40, ry + 2, cx + 40, ry + 5)
            glColor4f(r, g, b, 1.0)
            glRectf(cx, ry + 1, cx + a.c * 40, ry + 7)
            suite_text(box_x + 238, ry, string.format("%+.2f", a.c), 12, { r, g, b })
            ry = ry - 18
        end
        suite_text(box_x + 10, ry, "Push the right stick; triggers (L2/R2) are ignored.", 10, st.sub)
        suite_text(box_x + 10, ry - 18, "Green = locked heading-knob axis.", 10, st.sub)
    end

    if toast_text and (citationx_sim_time or 0.0) < toast_until then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        local text_w = measure_string(toast_text)
        local box_w  = text_w + 32
        local box_x  = (screen_w - box_w) / 2
        local box_y  = screen_h - 96
        glColor4f(0.00, 0.00, 0.00, 0.92)
        glRectf(box_x, box_y - 8, box_x + box_w, box_y + 22)
        glColor4f(SUITE_STYLE.accent[1], SUITE_STYLE.accent[2], SUITE_STYLE.accent[3], 1.0)
        glRectf(box_x, box_y - 8, box_x + 4, box_y + 22)
        suite_text(box_x + 16, box_y + 3, toast_text, 12, SUITE_STYLE.value)
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
do_every_draw("citationx_overlay()")
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
add_macro("CitationX Suite: enable all modules", "citationx_set_all(true)")
add_macro("CitationX Suite: disable all modules", "citationx_set_all(false)")
