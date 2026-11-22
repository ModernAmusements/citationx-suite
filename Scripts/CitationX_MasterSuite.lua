-- ============================================================================
--  CESSNA CITATION X MASTER SUITE
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
--  Version 3.0
-- ----------------------------------------------------------------------------
--  This is the suite hub and nothing else. It deliberately contains NO
--  keyboard layer: no do_on_keystroke, no controller-button map and no
--  axis-to-heading-bug knob. X-Plane's own keyboard / joystick profile is the
--  single source of truth for every pilot input.
--
--  What it still does, all of it "realism / quality of life":
--    1. Axis optimizer   - deadzone, expo and smoothing on the pitch/roll axes
--                          (the physical stick response, not a key mapping)
--    2. Mouse wheel      - the main scroll wheel stays with X-Plane (view
--                          zoom); the thumbwheel moves the heading bug in
--                          10 deg steps and an optional third wheel moves
--                          ALT SEL. No key is ever captured
--    3. Mouse actions    - taxi light, both landing lights, heading bug and
--                          ALT SEL are published as real X-Plane commands, so
--                          a middle click / gesture / thumbwheel can be pointed
--                          at them from X-Plane or the mouse driver
--    4. Flight recorder  - 1 Hz CSV of altitude, Mach, IAS, attitude, G, fuel
--    5. Emergency gen    - rare bleed-air / pressurisation warning at altitude
--    6. Axis monitor     - opt-in diagnostic readout of the live raw axes
--    7. Texture cycler   - steps through the installed liveries from the panel
--    8. Panel hub        - opens the sibling panels (QRH, cabin, realism)
--    9. FLOWS page       - guided, self-checking normal procedures in the hub
--   10. Debrief CSV      - one end-of-flight summary row on engine shutdown
--
--  There is deliberately NO telemetry overlay and NO C750 systems readback:
--  the aircraft's own PFD, EICAS and synoptics already show airspeed, altitude,
--  heading, Mach, G, fuel flow, electrics, fuel and anti-ice. The only surfaces
--  drawn here are the control panel, the opt-in AXIS MONITOR and a 2 s toast.
--
--  Verified against DataRefs.txt, Commands.txt and the aircraft's own xLua
--  scripts (plugins/xlua/scripts/*.lua).
-- ============================================================================

-- ------------------------------------------------------------------ CONFIG --
CONFIG = {
    -- Flight recorder -------------------------------------------------------
    log_enabled            = false,
    log_to_desktop         = true,

    -- Control panel ---------------------------------------------------------
    -- The ImGui Control Center is the only surface shown at load. The legacy
    -- hub stays available for FLOWS and the full module list, but starts hidden.
    status_enabled         = false,
    status_clickable       = true,    -- click a row to toggle / cycle it
    flow_tab               = "control", -- "control" = module rows, "flows" = procedures

    -- End-of-flight debrief --------------------------------------------------
    -- Written once when both fuel flows stay at zero after a qualifying flight.
    -- A test harness may override debrief_path with a scratch file.
    debrief_enabled        = true,
    debrief_path           = nil,

    -- Axis optimizer --------------------------------------------------------
    -- Reshapes the pitch/roll axes on their way into X-Plane: deadzone, expo
    -- and smoothing. It never maps a key or a button, and it can be switched
    -- off from the panel row (the raw axes come straight back).
    axis_optimizer_enabled = true,
    deadzone               = 0.02,
    curve_exponent         = 1.40,
    smoothing_factor       = 0.50,

    -- Emergency generator ---------------------------------------------------
    emergency_enabled      = false,
    emergency_chance_1hz   = 1 / 900,
    emergency_duration_sec = 20,
    emergency_alt_ft       = 15000,
    emergency_mach         = 0.85,

    -- Opt-in diagnostics ----------------------------------------------------
    axis_monitor           = false,

    -- Textures --------------------------------------------------------------
    -- The cycler drives X-Plane's own next_livery / prev_livery commands, so
    -- the sim reloads the aircraft art exactly as it does from the menu.
    texture_cycle_enabled  = true,

    -- Mouse wheel -----------------------------------------------------------
    -- The main scroll wheel is left alone so X-Plane keeps its view zoom.
    -- X-Plane numbers wheels from 0: 0 = main wheel, 1 = thumbwheel, and so
    -- on. The thumbwheel moves the heading bug in 10 deg steps; an optional
    -- third wheel moves ALT SEL. Run CitationXSuite/wheel_report to see which
    -- number your mouse sends, and CitationXSuite/wheel_map_swap to exchange
    -- the two mappings.
    mouse_wheel_altitude   = true,
    wheel_altitude_number  = 2,
    wheel_heading_number   = 1,
    wheel_heading_enabled  = true,
    wheel_heading_fast     = true,
    alt_step_ft            = 100,
    hdg_step_deg           = 1,
    hdg_fast_step_deg      = 10,
    alt_min_ft             = 0,
    alt_max_ft             = 50000,
}

-- ----------------------------------------------------------- PANEL STYLE ----
-- Geometry only; every colour is the shared MA dark field in
-- CitationX_00_Core.lua (CX). 38 px header, 22 px rows, hairline separators,
-- green bottom bar.
SUITE_STYLE = {
    x            = 470,
    top          = nil,          -- nil = top-right on first draw
    width        = 446,
    pad          = 16,
    header_h     = 38,
    sub_h        = 22,
    row_h        = 22,
    footer_h     = 34,
    bg           = CX.bg,
    bg_alt       = CX.bg_alt,
    header_bg    = CX.header_bg,
    border       = CX.border,
    hairline     = CX.hairline,
    title        = CX.title,
    sub          = CX.sub,
    label        = CX.label,
    value        = CX.value,
    dim          = CX.dim,
    ok           = CX.ok,
    warn         = CX.warn,
    alert        = CX.alert,
    btn          = CX.btn,
    accent       = CX.accent,
    subhdr       = CX.sub,
    footer_bg    = CX.footer_bg,
    footer_fg    = CX.footer_fg,
    mon_bg       = CX.mon_bg,
    mon          = CX.mon,
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("mach_no",     "sim/flightmodel/misc/machno", "readonly")
dataref("g_nrml",      "sim/flightmodel/forces/g_nrml", "readonly")
dataref("elevation_m", "sim/flightmodel/position/elevation", "readonly")
dataref("ias_kts",     "sim/flightmodel/position/indicated_airspeed", "readonly")
dataref("pitch_deg",   "sim/flightmodel/position/theta", "readonly")
dataref("roll_deg",    "sim/flightmodel/position/phi", "readonly")
dataref("citationx_sim_time", "sim/time/total_running_time_sec", "readonly")

-- Mapped (post-assignment) pitch/roll, which is what the pilot's stick
-- actually commands; the optimizer re-shapes exactly these two values.
dataref("joy_pitch",       "sim/joystick/joy_mapped_axis_value", "readonly", 1)
dataref("joy_roll",        "sim/joystick/joy_mapped_axis_value", "readonly", 2)
dataref("joy_avail_pitch", "sim/joystick/joy_mapped_axis_avail", "readonly", 1)
dataref("joy_avail_roll",  "sim/joystick/joy_mapped_axis_avail", "readonly", 2)

dataref("yoke_pitch_ratio",   "sim/joystick/yoke_pitch_ratio", "writable")
dataref("yoke_roll_ratio",    "sim/joystick/yoke_roll_ratio", "writable")
dataref("ovr_joystick_pitch", "sim/operation/override/override_joystick_pitch", "writable")
dataref("ovr_joystick_roll",  "sim/operation/override/override_joystick_roll", "writable")

-- Autopilot selectors driven from the mouse wheel. These are the *stock*
-- selectors the Citation X Primus autopilot reads, so the numbers appear on
-- the aircraft's own displays.
dataref("citationx_hdg_sel_deg", "sim/cockpit2/autopilot/heading_dial_deg_mag_pilot", "writable")
dataref("citationx_alt_sel_ft",  "sim/cockpit2/autopilot/altitude_dial_ft", "writable")
dataref("citationx_alt_legacy_ft", "sim/cockpit/autopilot/altitude", "writable")

-- Texture / livery readout. Both are read-only; the switches themselves are
-- X-Plane's own sim/operation/next_livery / prev_livery commands.
dataref("citationx_livery_index", "sim/aircraft/view/acf_livery_index", "readonly")
-- sim/aircraft/view/acf_livery_path is a byte[512] dataref; binding it as a
-- dataref_table makes FlyWithLua fail in CopyDataRefsToLua() and quarantine
-- the script. The panel label therefore comes from the livery index only.
local livery_path = nil

local fuel_flow_kg_sec = dataref_table("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")
local joy_raw_axes     = dataref_table("sim/joystick/joystick_axis_values")
local joy_raw_assign   = dataref_table("sim/joystick/joystick_axis_assignments")

-- sim/joystick/joystick_axis_assignments enum, for the axis monitor only.
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

-- ------------------------------------------------------------ STATE (early) --
-- Declared before SUITE_MODULES so its closures capture these locals.
local log_fd           = nil
local optimizer_active = false
local emergency_left   = 0.0
local emergency_armed  = true
local is_c750          = (PLANE_ICAO == "C750")

-- --------------------------------------------------- TEXTURE (LIVERY) NAME --
-- acf_livery_path is a *slow* dataref (it builds a string), and the panel asks
-- for the label on every draw, so the resolved name is cached and refreshed at
-- 1 Hz instead of 60 times a second.
local livery_label_cache = nil
local livery_label_stamp = -1.0

local function livery_name()
    -- acf_livery_path cannot be read as a table (see above), so there is no
    -- string to parse here; livery_label_now() falls back to the index.
    return nil
end

local function livery_label_now()
    local name = livery_name()
    if name then return name:upper() end
    local idx = citationx_livery_index or 0
    if idx and idx >= 0 then return "LIVERY " .. tostring(idx + 1) end
    return "DEFAULT"
end

local function livery_label(force)
    local now = citationx_sim_time or 0.0
    if force or livery_label_cache == nil or now - livery_label_stamp >= 1.0 then
        livery_label_cache = livery_label_now()
        livery_label_stamp = now
    end
    return livery_label_cache
end

-- --------------------------------------------------------------- AVITAB ----
-- AviTab (Resources/plugins/AviTab) publishes its own datarefs and commands;
-- the suite only forwards to them, so the panel is honest about whether the
-- plugin is even installed.
local avitab_panel_ref = nil
local function avitab_present()
    if avitab_panel_ref == nil then
        avitab_panel_ref = XPLMFindDataRef("avitab/panel_enabled") or false
    end
    return avitab_panel_ref ~= false
end

function avitab_state()
    if not avitab_present() then return "ABSENT" end
    local menu = XPLMFindDataRef("avitab/is_in_menu")
    if menu and XPLMGetDatai(menu) == 1 then return "MENU" end
    return "OPEN"
end

-- ------------------------------------------------- SUITE MODULE REGISTRY ----
-- One entry per subsystem the suite owns. `state()` is the short status word,
-- `set()` the single control point for commands, macros and panel clicks.
-- `cycle = true` means the row is an action (click / macro = next texture).
SUITE_MODULES = {
    {
        key = "status", label = "CONTROL PANEL", macro = "control panel",
        get = function() return CONFIG.status_enabled end,
        set = function(on) citationx_set_status(on) end,
        state = function() return CONFIG.status_enabled and "ON" or "OFF" end,
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
        key = "axmon", label = "AXIS MONITOR", macro = "axis monitor",
        get = function() return CONFIG.axis_monitor end,
        set = function(on) citationx_set_axis_monitor(on) end,
        state = function() return CONFIG.axis_monitor and "ON" or "OFF" end,
    },
    {
        key = "texture", label = "AIRCRAFT TEXTURE", macro = "next aircraft texture",
        cycle = true,
        get = function() return false end,
        set = function(on)
            if on == true then citationx_texture_next() end
        end,
        state = function() return livery_label() end,
    },
    {
        key = "wheel", label = "WHEEL = ALT SEL", macro = "mouse wheel altitude",
        get = function() return CONFIG.mouse_wheel_altitude end,
        set = function(on) citationx_set_wheel_altitude(on) end,
        state = function() return CONFIG.mouse_wheel_altitude and "ON" or "OFF" end,
    },
    {
        key = "avitab", label = "AVITAB CHARTS", macro = "AviTab charts",
        cycle = true,
        get = function() return false end,
        set = function(on)
            if on == true then citationx_avitab_charts() end
        end,
        state = function() return avitab_state() end,
    },
    -- --- sibling panels from the other suite scripts ------------------------
    -- They share one Lua state; every accessor is nil-guarded so the hub keeps
    -- working when a script is missing, disabled or loaded in another order.
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
            return CAB_CONFIG.panel_enabled and "ON" or "OFF"
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
            return TRAINER_CONFIG.panel_enabled and "ON" or "OFF"
        end,
    },
    {
        key = "instructor", label = "FLIGHT INSTRUCTOR", macro = "flight instructor",
        get = function()
            return (type(FI_CONFIG) == "table") and FI_CONFIG.panel_enabled or false
        end,
        set = function(on)
            if type(fi_toggle_panel) == "function" then fi_toggle_panel(on) end
        end,
        state = function()
            if type(FI_CONFIG) ~= "table" then return "ABSENT" end
            return FI_CONFIG.panel_enabled and "ON" or "OFF"
        end,
    },
    {
        key = "landperf", label = "LANDING PERF", macro = "landing report",
        get = function() return la_displayOn == true end,
        set = function(on)
            if type(la_toggle_last_result) ~= "function" then return end
            if (la_displayOn == true) ~= (on == true) then la_toggle_last_result() end
        end,
        state = function()
            if la_show_last_result == nil then return "ABSENT" end
            return la_displayOn == true and "SHOWN" or "HIDDEN"
        end,
    },
    {
        -- The Control Center needs the panel switch, not the background pack
        -- (which stays armed so the callouts and advisories keep working).
        key = "realism", label = "REALISM PANEL", macro = "realism panel",
        get = function()
            return (type(REAL_CONFIG) == "table") and REAL_CONFIG.hud_enabled or false
        end,
        set = function(on)
            if type(real_set_hud) == "function" then real_set_hud(on) end
        end,
        state = function()
            if type(REAL_CONFIG) ~= "table" then return "ABSENT" end
            return REAL_CONFIG.hud_enabled and "ON" or "OFF"
        end,
    },
}

local function state_color(text)
    local st = SUITE_STYLE
    if text == "ON" or text == "LIVE" or text == "REC"
        or text == "ACTIVE" or text == "ARMED" or text == "SHOWN" then
        return st.ok
    end
    if text == "TRIGGERED" then return st.alert end
    if text == "OFF" or text == "HIDDEN" then return st.dim end
    return st.warn   -- ABSENT / NO FILE / anything unexpected
end

-- ------------------------------------------------------------------ STATE ---
local recorder_path    = "(none)"
local recorder_samples = 0
local last_tick_time   = 0
local last_frame_time  = 0
local smooth_pitch     = 0.0
local smooth_roll      = 0.0

-- FLOWS page: one independent step cursor and one done flag per step.
local flow_state = {
    active = nil,        -- key of the flow currently shown
    step   = {},         -- key -> current step index (1-based)
    done   = {},         -- key -> { [step_index] = true }
}

-- Debrief accumulator. Only datarefs already bound above are sampled; the
-- landing score is borrowed read-only from LandingPerformance's shared globals.
local debrief = {
    phase          = "idle",     -- idle -> running -> cooldown -> idle
    start_time     = 0.0,
    end_time       = 0.0,
    low_flow_time  = 0.0,
    max_alt_ft     = 0.0,
    max_ias_kts    = 0.0,
    max_mach       = 0.0,
    max_g          = 0.0,
    max_bank_deg   = 0.0,
    max_pitch_deg  = 0.0,
    fuel_kg        = 0.0,
    score          = nil,
    rating         = "",
    landing_rate   = nil,
    last_row       = nil,
    last_path      = "(none)",
    written        = false,
}

local toast            -- forward declaration: FLOWS controls call it above
local toast_text       = nil
local toast_until      = 0.0
local status_rects     = {}
local panel_tab_rects  = {}
local flow_rects       = {}
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
        recorder_samples = 0
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

-- ------------------------------------------------------------------ FLOWS ---
-- Guided normal procedures. Each step is a short procedural prompt; `check`
-- is either nil (visual only) or a predicate over datarefs this file already
-- binds. No new DataRef or aircraft command is introduced here.
CONFIG.flows = {
    {
        key = "cold_dark", label = "COLD & DARK",
        steps = {
            { text = "Walk around; confirm doors, gear and control locks.", check = nil },
            { text = "Establish electrical power and verify EICAS is alive.", check = nil },
            { text = "Set parking brake; confirm flaps and trim as required.", check = nil },
            { text = "Review ATIS, route, FMS and clearance.", check = nil },
            { text = "Call for push/start when the engines may be started.",
              check = function() return total_fuel_flow_kg_h() < 100.0 end,
              check_label = "FUEL FLOW < 100 KG/H (ENGINES OFF)" },
        },
    },
    {
        key = "before_start", label = "BEFORE START",
        steps = {
            { text = "Doors closed; external power connected or APU available.", check = nil },
            { text = "Set PFD/ND sources, radios and autopilot modes.", check = nil },
            { text = "Set heading bug to the departure runway.",
              check = function() return citationx_hdg_sel_deg ~= nil end,
              check_label = "HEADING BUG SET" },
            { text = "Set ALT SEL to the cleared altitude.",
              check = function() return (citationx_alt_sel_ft or 0) > 0 end,
              check_label = "ALT SEL ABOVE ZERO" },
            { text = "Start engines; verify fuel flow on both EICAS engines.",
              check = function() return total_fuel_flow_kg_h() > 200.0 end,
              check_label = "FUEL FLOW > 200 KG/H" },
        },
    },
    {
        key = "taxi", label = "TAXI",
        steps = {
            { text = "Obtain taxi clearance; taxi light ON.", check = nil },
            { text = "Release parking brake and taxi clear of the ramp.",
              check = function() return (ias_kts or 0) >= 1.0 end,
              check_label = "IAS >= 1 KT" },
            { text = "Hold short; set parking brake.",
              check = function() return (ias_kts or 0) < 5.0 end,
              check_label = "IAS < 5 KT" },
            { text = "Review takeoff data and complete the departure brief.", check = nil },
        },
    },
    {
        key = "before_takeoff", label = "BEFORE TAKEOFF",
        steps = {
            { text = "Landing lights ON, taxi light OFF; transponder ALT.", check = nil },
            { text = "Flight controls free; flaps and pitch trim set.", check = nil },
            { text = "Confirm heading bug matches the takeoff runway.",
              check = function() return citationx_hdg_sel_deg ~= nil end,
              check_label = "HEADING BUG SET" },
            { text = "Confirm ALT SEL matches the cleared altitude.",
              check = function() return (citationx_alt_sel_ft or 0) > 0 end,
              check_label = "ALT SEL ABOVE ZERO" },
            { text = "Hold on the brakes; verify airspeed is alive before takeoff.",
              check = function() return (ias_kts or 0) < 60.0 end,
              check_label = "IAS < 60 KT" },
        },
    },
    {
        key = "after_landing", label = "AFTER LANDING",
        steps = {
            { text = "Clear the runway; taxi light ON.", check = nil },
            { text = "Landing lights OFF; speedbrakes and flaps stowed.", check = nil },
            { text = "Verify speed is below the taxi limit.",
              check = function() return (ias_kts or 0) < 40.0 end,
              check_label = "IAS < 40 KT" },
            { text = "Complete the after-landing checklist and call for parking.", check = nil },
        },
    },
    {
        key = "shutdown", label = "SHUTDOWN",
        steps = {
            { text = "Park the aircraft; set the parking brake.",
              check = function() return (ias_kts or 0) < 1.0 end,
              check_label = "IAS < 1 KT" },
            { text = "Throttles cutoff; verify both fuel flows at zero.",
              check = function() return total_fuel_flow_kg_h() < 100.0 end,
              check_label = "FUEL FLOW < 100 KG/H" },
            { text = "Lights, packs and bleeds OFF; doors as required.", check = nil },
            { text = "Debrief CSV is written automatically at shutdown.", check = nil },
        },
    },
}

local function flow_by_key(key)
    for i = 1, #CONFIG.flows do
        if CONFIG.flows[i].key == key then return CONFIG.flows[i] end
    end
    return nil
end

local function flow_current_key()
    return flow_state.active or CONFIG.flows[1].key
end

local function flow_step_index(key)
    local n = #(flow_by_key(key).steps)
    local i = flow_state.step[key] or 1
    if i < 1 then i = 1 end
    if i > n then i = n end
    return i
end

local function flow_step_done(key, i)
    local marks = flow_state.done[key]
    return marks ~= nil and marks[i] == true
end

local function flow_all_done(key)
    local flow = flow_by_key(key)
    if not flow then return false end
    for i = 1, #flow.steps do
        if not flow_step_done(key, i) then return false end
    end
    return true
end

local function flow_step_check(key, i)
    local flow = flow_by_key(key)
    if not flow then return false end
    local step = flow.steps[i]
    return step ~= nil and step.check ~= nil and step.check() == true
end

-- Tick the visible step's self-check. Clicking NEXT still advances a step whose
-- predicate is false: the pilot stays in control of the flow.
function citationx_flow_poll()
    if CONFIG.flow_tab ~= "flows" then return end
    local key = flow_current_key()
    local i = flow_step_index(key)
    if flow_step_check(key, i) then
        flow_state.done[key] = flow_state.done[key] or {}
        flow_state.done[key][i] = true
    end
end

function citationx_flows() return CONFIG.flows end

function citationx_flow_state()
    local out = { tab = CONFIG.flow_tab, active = flow_current_key(), step = {}, done = {} }
    for _, flow in ipairs(CONFIG.flows) do
        out.step[flow.key] = flow_step_index(flow.key)
        out.done[flow.key] = {}
        for i = 1, #flow.steps do
            out.done[flow.key][i] = flow_step_done(flow.key, i)
        end
    end
    return out
end

function citationx_set_flow_tab(tab)
    if tab ~= "flows" then tab = "control" end
    CONFIG.flow_tab = tab
    if tab == "flows" then
        if not flow_by_key(flow_state.active) then
            flow_state.active = CONFIG.flows[1].key
        end
        citationx_flow_poll()
    end
end

function citationx_flows_toggle()
    citationx_set_flow_tab(CONFIG.flow_tab == "flows" and "control" or "flows")
    if not CONFIG.status_enabled then citationx_set_status(true) end
    toast("FLOWS: " .. string.upper(CONFIG.flow_tab))
end

function citationx_flow_select(key)
    if not flow_by_key(key) then return end
    flow_state.active = key
    CONFIG.flow_tab = "flows"
    citationx_flow_poll()
    toast(flow_by_key(key).label)
end

function citationx_flow_next()
    local key = flow_current_key()
    local flow = flow_by_key(key)
    local i = flow_step_index(key)
    flow_state.done[key] = flow_state.done[key] or {}
    flow_state.done[key][i] = true
    if i < #flow.steps then
        flow_state.step[key] = i + 1
    else
        -- Revisiting a finished flow starts a fresh pass.
        flow_state.step[key] = 1
        flow_state.done[key] = {}
    end
    citationx_flow_poll()
end

function citationx_flow_back()
    local key = flow_current_key()
    local i = flow_step_index(key)
    if i > 1 then flow_state.step[key] = i - 1 end
    citationx_flow_poll()
end

function citationx_flow_reset()
    local key = flow_current_key()
    flow_state.step[key] = 1
    flow_state.done[key] = {}
    toast("FLOW RESET")
end

function citationx_flow_report()
    logMsg("Citation X Suite: FLOWS report ------------------------------------")
    logMsg("  page = " .. CONFIG.flow_tab)
    for _, flow in ipairs(CONFIG.flows) do
        local done_count = 0
        for i = 1, #flow.steps do
            if flow_step_done(flow.key, i) then done_count = done_count + 1 end
        end
        logMsg(string.format("  %-16s : %d/%d, cursor %d",
            flow.label, done_count, #flow.steps, flow_step_index(flow.key)))
    end
end

-- Deadzone -> expo -> sign, so both axes share one response curve.
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
    recorder_samples = recorder_samples + 1
    log_fd:flush()
end

function toast(text)
    toast_text  = text
    toast_until = (citationx_sim_time or 0.0) + 2.0
end

-- Sibling scripts (the realism pack) borrow the 2 s toast. Nil-guarded there,
-- so the suite still works when this file is absent.
function citationx_toast(text)
    toast(text)
end

local function toast_state(name, on)
    toast(name .. (on and ": ON" or ": OFF"))
end

-- ------------------------------------------------------------- DEBRIEF CSV ---
-- One row per flight, appended when both engines stay at zero fuel flow for a
-- few seconds. Only existing bindings are sampled. LandingPerformance's score
-- is borrowed read-only; this file never writes to that script's globals.
local DEBRIEF_HEADER = "Timestamp,Start_Sec,End_Sec,Duration_Sec,Max_Alt_FT,"
    .. "Max_IAS_KTS,Max_Mach,Max_G,Max_Bank_Deg,Max_Pitch_Deg,Fuel_Burned_Kg,"
    .. "Recorder_Samples,Recorder_File,Landing_Score,Landing_Rating,Landing_Rate_FPM\n"
local DEBRIEF_START_FLOW_KG_S = 0.05
local DEBRIEF_OFF_FLOW_KG_S   = 0.01
local DEBRIEF_OFF_HOLD_SEC    = 3.0
local DEBRIEF_MIN_IAS_KTS     = 60.0
local DEBRIEF_MIN_MACH        = 0.08

local function debrief_path_candidates()
    if CONFIG.debrief_path and CONFIG.debrief_path ~= "" then
        return { CONFIG.debrief_path }
    end
    local dir = SCRIPT_DIRECTORY or ""
    if dir ~= "" and dir:sub(-1) ~= "/" then dir = dir .. "/" end
    -- Scripts/ -> FlyWithLua/ -> plugins/ -> Resources/ -> X-Plane 12/
    local out = {}
    if dir ~= "" then out[1] = dir .. "../../../../Output/CitationX_Debrief.csv" end
    out[#out + 1] = "Output/CitationX_Debrief.csv"
    if dir ~= "" then out[#out + 1] = dir .. "CitationX_Debrief.csv" end
    return out
end

function citationx_debrief_path()
    return debrief_path_candidates()[1] or "(none)"
end

local function csv_cell(value)
    local s = tostring(value or "")
    if s:find('[",\r\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
    return s
end

local function debrief_number(value, fmt)
    if type(value) ~= "number" then return "" end
    return string.format(fmt, value)
end

local function debrief_reset(now)
    debrief.phase         = "running"
    debrief.start_time    = now
    debrief.end_time      = now
    debrief.low_flow_time = 0.0
    debrief.max_alt_ft    = 0.0
    debrief.max_ias_kts   = 0.0
    debrief.max_mach      = 0.0
    debrief.max_g         = 0.0
    debrief.max_bank_deg  = 0.0
    debrief.max_pitch_deg = 0.0
    debrief.fuel_kg       = 0.0
    debrief.score         = nil
    debrief.rating        = ""
    debrief.landing_rate  = nil
end

local function debrief_borrow_landing_score()
    if debrief.score ~= nil then return end
    if type(la_score) ~= "number" then return end
    debrief.score = la_score
    if type(la_rating) == "string" then debrief.rating = la_rating end
    if type(la_landingRate) == "number" then debrief.landing_rate = la_landingRate end
end

local function debrief_finalize(now)
    debrief.end_time      = now
    debrief.phase         = "cooldown"
    debrief.low_flow_time = 0.0
    debrief.written       = false

    local qualified = debrief.max_ias_kts >= DEBRIEF_MIN_IAS_KTS
        or debrief.max_mach >= DEBRIEF_MIN_MACH
    if not qualified then
        logMsg("Citation X Suite: debrief skipped - no qualifying flight segment")
        toast("DEBRIEF: NO FLIGHT")
        return
    end

    local row = table.concat({
        os.date("%Y-%m-%d %H:%M:%S"),
        debrief_number(debrief.start_time, "%.1f"),
        debrief_number(debrief.end_time, "%.1f"),
        debrief_number(debrief.end_time - debrief.start_time, "%.1f"),
        debrief_number(debrief.max_alt_ft, "%.0f"),
        debrief_number(debrief.max_ias_kts, "%.1f"),
        debrief_number(debrief.max_mach, "%.3f"),
        debrief_number(debrief.max_g, "%.2f"),
        debrief_number(debrief.max_bank_deg, "%.1f"),
        debrief_number(debrief.max_pitch_deg, "%.1f"),
        debrief_number(debrief.fuel_kg, "%.1f"),
        tostring(recorder_samples),
        csv_cell(recorder_path),
        debrief_number(debrief.score, "%.0f"),
        csv_cell(debrief.rating),
        debrief_number(debrief.landing_rate, "%.0f"),
    }, ",")

    for _, path in ipairs(debrief_path_candidates()) do
        local probe = io.open(path, "r")
        local empty = true
        if probe then
            local first = probe:read(1)
            if first then empty = false end
            probe:close()
        end
        local fd = io.open(path, "a")
        if fd then
            if empty then fd:write(DEBRIEF_HEADER) end
            fd:write(row .. "\n")
            fd:flush()
            fd:close()
            debrief.last_path = path
            debrief.last_row  = row
            debrief.written   = true
            logMsg("Citation X Suite: debrief written -> " .. path)
            toast("DEBRIEF SAVED")
            return
        end
    end
    logMsg("Citation X Suite: WARNING - could not write the debrief CSV")
    toast("DEBRIEF: NO FILE")
end

function citationx_debrief_poll(now, dt)
    if not CONFIG.debrief_enabled then return end
    if dt < 0.0 then dt = 0.0 end
    -- Cap the fuel integral on a time jump, but keep the shutdown hold honest
    -- at low frame rates (a 1 Hz test sim still sees a real 3 s).
    local hold_dt = math.min(dt, 1.0)
    local fuel_dt = math.min(dt, 0.5)

    local left  = fuel_flow_kg_sec[0] or 0.0
    local right = fuel_flow_kg_sec[1] or 0.0
    local both_on  = left >= DEBRIEF_START_FLOW_KG_S and right >= DEBRIEF_START_FLOW_KG_S
    local both_off = left <= DEBRIEF_OFF_FLOW_KG_S and right <= DEBRIEF_OFF_FLOW_KG_S

    if debrief.phase == "idle" or debrief.phase == "cooldown" then
        if both_on then debrief_reset(now) end
        return
    end
    if debrief.phase ~= "running" then return end

    debrief.fuel_kg = debrief.fuel_kg + (left + right) * fuel_dt
    local alt_ft = (elevation_m or 0.0) * 3.28084
    if alt_ft > debrief.max_alt_ft then debrief.max_alt_ft = alt_ft end
    if (ias_kts or 0.0) > debrief.max_ias_kts then debrief.max_ias_kts = ias_kts end
    if (mach_no or 0.0) > debrief.max_mach then debrief.max_mach = mach_no end
    if (g_nrml or 0.0) > debrief.max_g then debrief.max_g = g_nrml end
    if math.abs(roll_deg or 0.0) > debrief.max_bank_deg then
        debrief.max_bank_deg = math.abs(roll_deg)
    end
    if math.abs(pitch_deg or 0.0) > debrief.max_pitch_deg then
        debrief.max_pitch_deg = math.abs(pitch_deg)
    end
    debrief_borrow_landing_score()

    if both_off then
        debrief.low_flow_time = debrief.low_flow_time + hold_dt
    else
        debrief.low_flow_time = 0.0
    end
    if debrief.low_flow_time >= DEBRIEF_OFF_HOLD_SEC then debrief_finalize(now) end
end

function citationx_debrief_state()
    return {
        enabled   = CONFIG.debrief_enabled,
        phase     = debrief.phase,
        start     = debrief.start_time,
        end_time  = debrief.end_time,
        max_ias   = debrief.max_ias_kts,
        max_mach  = debrief.max_mach,
        score     = debrief.score,
        rating    = debrief.rating,
        written   = debrief.written,
        path      = debrief.last_path,
        row       = debrief.last_row,
    }
end

function citationx_debrief_write()
    if debrief.phase ~= "running" then
        logMsg("Citation X Suite: no active flight to debrief")
        toast("DEBRIEF: NO FLIGHT")
        return false
    end
    debrief_finalize(citationx_sim_time or 0.0)
    return debrief.written
end

function citationx_debrief_toggle(on)
    CONFIG.debrief_enabled = (on == true)
    toast_state("DEBRIEF CSV", CONFIG.debrief_enabled)
end

function citationx_debrief_report()
    logMsg("Citation X Suite: debrief report -----------------------------------")
    logMsg(string.format("  enabled = %s, phase = %s", tostring(CONFIG.debrief_enabled), debrief.phase))
    logMsg("  file = " .. citationx_debrief_path())
    logMsg(string.format("  max IAS %.1f kt, max Mach %.3f, fuel %.1f kg, score %s",
        debrief.max_ias_kts, debrief.max_mach, debrief.fuel_kg,
        tostring(debrief.score or "n/a")))
    if debrief.last_row then logMsg("  last row = " .. debrief.last_row) end
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

function citationx_set_axis_monitor(on)
    CONFIG.axis_monitor = (on == true)
    toast_state("AXIS MONITOR", CONFIG.axis_monitor)
end

-- Textures ---------------------------------------------------------------
-- You asked for a toggle between the installed textures; X-Plane already
-- knows how to load a livery, so the suite just steps its list.
function citationx_texture_next()
    if not CONFIG.texture_cycle_enabled then return end
    command_once("sim/operation/next_livery")
    livery_label_stamp = -1.0
    toast("TEXTURE: " .. livery_label(true))
end

function citationx_texture_prev()
    if not CONFIG.texture_cycle_enabled then return end
    command_once("sim/operation/prev_livery")
    livery_label_stamp = -1.0
    toast("TEXTURE: " .. livery_label(true))
end

function citationx_texture_report()
    logMsg("Citation X Suite: texture = " .. livery_label(true))
end

-- ------------------------------------------------------------- AVITAB OPS ---
-- Every AviTab command the suite forwards. AviTab is a separate plugin; if it
-- is not installed these are silent no-ops plus a toast, never an error.
local function avitab_command(cmd, label)
    if not avitab_present() then
        toast("AVITAB NOT INSTALLED")
        return
    end
    command_once(cmd)
    if label then toast(label) end
end

function citationx_avitab_charts()  avitab_command("AviTab/app_charts",  "AVITAB: CHARTS") end
function citationx_avitab_maps()    avitab_command("AviTab/app_maps",    "AVITAB: MAPS") end
function citationx_avitab_routes()  avitab_command("AviTab/app_routes",  "AVITAB: ROUTES") end
function citationx_avitab_airports() avitab_command("AviTab/app_airports", "AVITAB: AIRPORTS") end
function citationx_avitab_home()    avitab_command("AviTab/Home",        "AVITAB: HOME") end
function citationx_avitab_recentre() avitab_command("AviTab/recentre",   "AVITAB: RECENTRE") end
function citationx_avitab_zoom_in()  avitab_command("AviTab/zoom_in",    nil) end
function citationx_avitab_zoom_out() avitab_command("AviTab/zoom_out",   nil) end
function citationx_avitab_toggle()  avitab_command("AviTab/toggle_tablet", "AVITAB") end

-- Text report (Log.txt) of what AviTab is showing, for the status command.
function citationx_avitab_report()
    if not avitab_present() then
        logMsg("Citation X Suite: AviTab is not installed")
        return
    end
    local function getf(name)
        local r = XPLMFindDataRef(name)
        return r and XPLMGetDataf(r) or 0
    end
    logMsg(string.format(
        "Citation X Suite: AviTab %s, map %.4f/%.4f zoom %.2f, brightness %.2f",
        avitab_state(), getf("avitab/map/latitude"), getf("avitab/map/longitude"),
        getf("avitab/map/zoom"), getf("avitab/brightness")))
end

-- ------------------------------------------------------ MOUSE SELECTORS ----
-- The suite reads one wheel only: the thumbwheel by default. The main scroll
-- wheel is never consumed, so X-Plane's view zoom keeps working. Every action
-- is also a real X-Plane command, so another button can be pointed at it from
-- X-Plane's joystick screen (or the mouse driver).
function citationx_set_wheel_altitude(on)
    CONFIG.mouse_wheel_altitude = (on == true)
    toast_state("WHEEL = ALT SEL", CONFIG.mouse_wheel_altitude)
end

local function alt_sel_write(feet)
    feet = math.floor(feet / 100 + 0.5) * 100
    if feet < CONFIG.alt_min_ft then feet = CONFIG.alt_min_ft end
    if feet > CONFIG.alt_max_ft then feet = CONFIG.alt_max_ft end
    citationx_alt_sel_ft    = feet
    citationx_alt_legacy_ft = feet
    return feet
end

function citationx_alt_up()
    local feet = alt_sel_write((citationx_alt_sel_ft or 0) + CONFIG.alt_step_ft)
    toast(string.format("ALT SEL %d FT", feet))
end

function citationx_alt_down()
    local feet = alt_sel_write((citationx_alt_sel_ft or 0) - CONFIG.alt_step_ft)
    toast(string.format("ALT SEL %d FT", feet))
end

local function hdg_step(delta)
    local deg = ((citationx_hdg_sel_deg or 0) + delta) % 360
    if deg < 0 then deg = deg + 360 end
    citationx_hdg_sel_deg = deg
    toast(string.format("HDG %03.0f", deg))
end

function citationx_hdg_up() hdg_step(CONFIG.hdg_step_deg) end
function citationx_hdg_down() hdg_step(-CONFIG.hdg_step_deg) end

-- Big-step commands for a key or mouse button: 10 degrees per press instead
-- of the fine 1-degree step.
function citationx_hdg_fast_up() hdg_step(CONFIG.hdg_fast_step_deg) end
function citationx_hdg_fast_down() hdg_step(-CONFIG.hdg_fast_step_deg) end

-- Taxi light and both landing lights: X-Plane's own switches, so the cockpit
-- annunciation follows automatically.
function citationx_taxi_light()
    command_once("sim/lights/taxi_lights_toggle")
    toast("TAXI LIGHT")
end

function citationx_landing_lights()
    command_once("sim/lights/landing_lights_toggle")
    toast("LANDING LIGHTS")
end

-- Wheels are numbered from 0 by X-Plane:
--   0 (main scroll)  -> left to X-Plane, so the view zooms as usual
--   1 (thumbwheel)   -> heading bug, 10 deg per notch by default
--   2 (third wheel)  -> ALT SEL up/down
-- RESUME_MOUSE_WHEEL is set only when the suite actually uses the notch, so
-- the main wheel is never swallowed. No key is ever read.
local wheel_last_number, wheel_last_clicks = nil, 0

function citationx_mouse_wheel()
    local clicks = MOUSE_WHEEL_CLICKS or 0
    local wheel  = MOUSE_WHEEL_NUMBER or 0
    wheel_last_number, wheel_last_clicks = wheel, clicks
    RESUME_MOUSE_WHEEL = false
    if not is_c750 then return end
    if clicks == 0 then return end

    if wheel == CONFIG.wheel_altitude_number then
        if not CONFIG.mouse_wheel_altitude then return end
        local n = math.min(math.abs(clicks), 10)
        for _ = 1, n do
            if clicks > 0 then citationx_alt_up() else citationx_alt_down() end
        end
        RESUME_MOUSE_WHEEL = true
        return
    end

    if wheel == CONFIG.wheel_heading_number then
        if not CONFIG.wheel_heading_enabled then return end
        local step = CONFIG.wheel_heading_fast and CONFIG.hdg_fast_step_deg
            or CONFIG.hdg_step_deg
        local n = math.min(math.abs(clicks), 10)
        for _ = 1, n do
            if clicks > 0 then hdg_step(step) else hdg_step(-step) end
        end
        RESUME_MOUSE_WHEEL = true
    end
    -- any other wheel (the main scroll wheel by default) falls through:
    -- RESUME stays false, so X-Plane receives it and zooms.
end

-- Which physical wheel is which? Turn one notch and run the report; the toast
-- and the log both show the number, so the mapping can be set without guessing.
function citationx_wheel_report()
    local last = tostring(wheel_last_number)
    local clicks = wheel_last_clicks or 0
    logMsg(string.format(
        "Citation X Suite: last wheel event = number %s, %d click(s); ALT SEL wheel %d, heading wheel %d",
        last, clicks, CONFIG.wheel_altitude_number, CONFIG.wheel_heading_number))
    toast(string.format("WHEEL %s (%d) - ALT %d HDG %d", last, clicks,
        CONFIG.wheel_altitude_number, CONFIG.wheel_heading_number))
end

function citationx_wheel_map_swap()
    local a, h = CONFIG.wheel_altitude_number, CONFIG.wheel_heading_number
    CONFIG.wheel_altitude_number, CONFIG.wheel_heading_number = h, a
    logMsg(string.format("Citation X Suite: ALT SEL wheel = %d, heading wheel = %d",
        CONFIG.wheel_altitude_number, CONFIG.wheel_heading_number))
    toast("WHEEL MAP SWAPPED")
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
            if m.cycle then
                m.set(true)
            else
                m.set(not m.get())
            end
            return
        end
    end
end

-- One-click "the whole suite, back on" / "off again". The control panel row is
-- excluded so enabling everything does not paint the panel on top of the rest.
function citationx_set_all(on)
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        if m.key ~= "status" and not m.cycle then m.set(on == true) end
    end
end

function citationx_status_report()
    logMsg("Citation X Suite: status report ----------------------------------")
    logMsg(string.format("  aircraft = %s (C750=%s)", tostring(PLANE_ICAO), tostring(is_c750)))
    logMsg("  input layer = thumbwheel -> heading; main wheel stays X-Plane zoom")
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        logMsg(string.format("  %-18s : %s", m.label, m.state()))
    end
    logMsg(string.format("  flows page     : %s, active %s",
        CONFIG.flow_tab, flow_current_key()))
    logMsg(string.format("  debrief        : %s, %s",
        CONFIG.debrief_enabled and "ON" or "OFF", citationx_debrief_path()))
end

-- ------------------------------------------------------------- FRAME LOOP ---
function citationx_frame()
    local now = citationx_sim_time or 0.0
    local dt  = now - last_frame_time
    if dt < 0.0 then dt = 0.0 end
    last_frame_time = now

    is_c750 = (PLANE_ICAO == "C750")

    -- The suite belongs to the C750. When another aircraft is loaded, stop all
    -- aircraft-specific work and hand the joystick overrides back; the panels
    -- are hidden by the same flag further down.
    if not is_c750 then
        if optimizer_active then
            ovr_joystick_pitch = 0
            ovr_joystick_roll  = 0
            optimizer_active   = false
            logMsg("Citation X Suite: axis optimizer released (not a C750)")
        end
        return
    end

    -- Guided flows and the end-of-flight debrief both read only bindings that
    -- were already declared above; neither draws an aircraft readback.
    citationx_flow_poll()
    citationx_debrief_poll(now, dt)

    -- 1. Axis optimizer. Only pitch/roll: yaw, brakes, throttle and every
    --    button stay exactly as X-Plane has them.
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

    -- 2. Once-per-second tasks.
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
end

-- --------------------------------------------------------- ON-SCREEN PANEL ----
-- The only thing the suite draws is the control panel (plus the opt-in axis
-- monitor and a 2 s toast). No telemetry, no systems mirror.
local function draw_bar(x, y_bottom, y_top, w, color, alpha)
    cx_bar_w(x, y_bottom, y_top, w, color, alpha)
end

local function fit_text(text, max_px)
    return cx_fit(text, max_px)
end

local function suite_text(x, y, text, size, color)
    cx_text(x, y, text, size, color)
end

local function suite_text_right(right_x, y, text, size, color)
    cx_text_right(right_x, y, text, size, color)
end

-- Shell: body, 1 px border, 2 px header rule, title and right caption.
local function draw_shell(x, top, w, h, title, sub)
    local st = SUITE_STYLE
    local bottom = top - h
    draw_bar(x, bottom, top, w, st.bg)
    draw_bar(x, top - 1, top, w, st.border)
    draw_bar(x, bottom, top, 1, st.border)
    draw_bar(x + w - 1, bottom, top, 1, st.border)
    draw_bar(x, bottom, bottom + 1, w, st.border)
    draw_bar(x, top - st.header_h, top, w, st.header_bg)
    -- inner hairline under the header: reads crisper than a thick border
    draw_bar(x, top - st.header_h, top - st.header_h + 1, w, st.border)
    draw_bar(x, top - st.header_h - 1, top - st.header_h, w, st.hairline)
    suite_text(x + st.pad, top - 27, title, 18, st.title)
    if sub and sub ~= "" then
        suite_text_right(x + w - st.pad, top - 24, sub, 10, st.sub)
    end
end

local function draw_footer_button(x, bottom, w, label)
    local st = SUITE_STYLE
    return cx_footer_button(x, bottom, w, label, st.footer_h, st.pad)
end

-- Flow page geometry. `top` is the panel's top edge (FlyWithLua y grows up).
-- The same layout drives drawing and hit testing, so a clicked row is always
-- the row the pilot sees.
local function flow_layout(st, top)
    local first_y = top - st.header_h - st.sub_h - 15
    local rows = {}
    for i = 1, #CONFIG.flows do
        rows[i] = first_y + st.row_h - (i - 1) * st.row_h   -- row top edge
    end
    local last_bottom = rows[#rows] - st.row_h
    local prompt_y = last_bottom - 16
    local check_y  = prompt_y - 18
    local nav_top  = check_y - 16
    local nav_bottom = nav_top - (st.row_h - 8)
    local footer_top = nav_bottom - 14
    return {
        first_y = first_y, rows = rows,
        prompt_y = prompt_y, check_y = check_y,
        nav_top = nav_top, nav_bottom = nav_bottom,
        footer_top = footer_top,
        bottom = footer_top - st.footer_h - 8,
    }
end

-- Control page: header + sub-header + rows + footer + padding.
-- Flows page: the shared layout above decides the bottom edge.
function control_panel_height()
    local st = SUITE_STYLE
    if CONFIG.flow_tab == "flows" then
        return -flow_layout(st, 0).bottom
    end
    return st.header_h + st.sub_h + 14
        + #SUITE_MODULES * st.row_h + st.footer_h + 8
end

-- Public mirror of the panel height (the local forward declaration above
-- shadows the function inside this file; other suite scripts and the tests
-- ask through this name).
function citationx_panel_height()
    return control_panel_height()
end

local function draw_control_panel(screen_h)
    local st = SUITE_STYLE
    local w, pad = st.width, st.pad
    local x = st.x

    if st.top == nil then st.top = screen_h - 24 end
    x = math.max(8, math.min(x, (SCREEN_WIDTH or 1920) - w - 8))
    st.x = x
    local h = control_panel_height()
    local top = math.max(h + 8, math.min(st.top, screen_h - 8))
    st.top = top
    local bottom = top - h
    local body_top = top - st.header_h

    status_rects, panel_tab_rects, flow_rects = {}, {}, {}

    draw_shell(x, top, w, h, "CITATION X", "MASTER SUITE 3.0")

    -- Sub-header: the two hub pages. CONTROL keeps the original module rows;
    -- FLOWS shows the guided normal procedures. Neither page owns a keybind.
    local sub_y = body_top - 15
    suite_text(x + pad, sub_y, "HUB", 10, st.dim)
    local tab_x = x + pad + cx_measure("HUB", 10) + 12
    local function add_tab(label, key)
        local tw = cx_measure(label, 10)
        local active = (CONFIG.flow_tab == key)
        suite_text(tab_x, sub_y, label, 10, active and st.accent or st.sub)
        if active then
            draw_bar(tab_x, body_top - st.sub_h + 2, tab_x + tw,
                body_top - st.sub_h + 3, st.accent, 1.0)
        end
        panel_tab_rects[#panel_tab_rects + 1] = {
            key = key, x0 = tab_x - 4, x1 = tab_x + tw + 4,
            y0 = body_top - st.sub_h, y1 = body_top,
        }
        tab_x = tab_x + tw + 18
    end
    add_tab("CONTROL", "control")
    add_tab("FLOWS", "flows")

    local note = "MOUSE ONLY - NO KEYBINDS"
    local nw = measure_string(note, "Helvetica_10") or measure_string(note)
    suite_text(x + w - pad - nw, sub_y, note, 10, st.dim)
    draw_bar(x, body_top - st.sub_h, body_top, w, st.hairline, 0.45)

    if CONFIG.flow_tab == "flows" then
        -- Flow index rows ---------------------------------------------------
        local L = flow_layout(st, top)
        local flow = flow_by_key(flow_current_key())
        for i = 1, #CONFIG.flows do
            local f = CONFIG.flows[i]
            local row_top = L.rows[i]
            local y = row_top - 15
            local active = (f.key == flow.key)
            local done_all = flow_all_done(f.key)
            local col = active and st.accent or (done_all and st.ok or st.label)
            if active or i % 2 == 0 then
                draw_bar(x + 1, row_top - st.row_h, row_top, w - 2,
                    st.bg_alt, active and 0.85 or 0.55)
            end
            glColor4f(col[1], col[2], col[3], 1.0)
            glRectf(x + pad, y - 1, x + pad + 5, y + 8)
            suite_text(x + pad + 12, y,
                fit_text(string.format("%d. %s", i, f.label), w * 0.52), 12, col)
            local marks = 0
            for s = 1, #f.steps do
                if flow_step_done(f.key, s) then marks = marks + 1 end
            end
            suite_text_right(x + w - pad, y,
                done_all and "DONE" or string.format("%d/%d", marks, #f.steps),
                12, done_all and st.ok or st.dim)
            flow_rects[#flow_rects + 1] = {
                key = f.key, x0 = x, x1 = x + w,
                y0 = row_top - st.row_h, y1 = row_top,
            }
        end

        -- Current step and its optional self-check --------------------------
        local idx = flow_step_index(flow.key)
        local step = flow.steps[idx]
        suite_text(x + pad + 16, L.prompt_y,
            fit_text(string.format("STEP %d/%d  %s", idx, #flow.steps, step.text),
                w - pad * 2 - 32), 12, st.label)
        local check_ok = flow_step_check(flow.key, idx)
        local check_line
        if step.check then
            check_line = (check_ok and "[X] " or "[ ] ") .. step.check_label
        else
            check_line = "[ ] VISUAL CHECK - VERIFY ON COCKPIT DISPLAYS"
        end
        local check_col = step.check and (check_ok and st.ok or st.sub) or st.dim
        suite_text(x + pad + 16, L.check_y,
            fit_text(check_line, w - pad * 2 - 32), 10, check_col)

        -- Navigation buttons -----------------------------------------------
        local labels = { "BACK", "NEXT", "RESET" }
        local gap, btn_w = 8, (w - pad * 2 - 16) / 3
        for i, label in ipairs(labels) do
            local bx = x + pad + (i - 1) * (btn_w + gap)
            draw_bar(bx, L.nav_bottom, L.nav_top, btn_w, st.btn)
            draw_bar(bx, L.nav_top - 1, L.nav_top, btn_w, st.hairline, 0.6)
            local bcol = label == "NEXT" and st.accent or st.label
            suite_text(bx + (btn_w - cx_measure(label, 10)) / 2,
                L.nav_bottom + 6, label, 10, bcol)
            flow_rects[#flow_rects + 1] = {
                key = string.lower(label), x0 = bx, x1 = bx + btn_w,
                y0 = L.nav_bottom, y1 = L.nav_top,
            }
        end
    else
        local first_y = body_top - st.sub_h - 15
        for i = 1, #SUITE_MODULES do
            local m = SUITE_MODULES[i]
            local row_top = first_y + st.row_h - (i - 1) * st.row_h
            local y = row_top - 15
            local text = m.state()
            local col  = m.cycle and st.value or state_color(text)

            -- alternating body tone keeps the rows readable at a glance
            if i % 2 == 0 then
                draw_bar(x + 1, row_top - st.row_h, row_top, w - 2, st.bg_alt, 0.55)
            end

            -- status dot (a 5x5 square reads sharper than a circle at this size)
            glColor4f(col[1], col[2], col[3], 1.0)
            glRectf(x + pad, y - 1, x + pad + 5, y + 8)

            suite_text(x + pad + 12, y, m.label, 12, st.label)
            local value_max = w - pad * 2 - 12 - measure_string(m.label) - 16
            local shown = fit_text(tostring(text), math.max(60, value_max))
            suite_text_right(x + w - pad, y, shown, 12, col)

            status_rects[#status_rects + 1] = {
                key = m.key,
                x0 = x, x1 = x + w,
                y0 = row_top - st.row_h, y1 = row_top,
            }
        end
    end

    panel_header_rect = { x0 = x, x1 = x + w, y0 = top - st.header_h, y1 = top }
    panel_footer_rect = draw_footer_button(x, bottom, w, "HIDE PANEL")
end

local function draw_axis_monitor()
    local st = SUITE_STYLE
    local rows = {}
    for i = 0, 63 do
        local a = joy_raw_assign[i] or 0
        local v = joy_raw_axes[i]
        if v ~= nil and (a ~= 0 or math.abs((v or 0.5) - 0.5) > 0.05) then
            rows[#rows + 1] = { idx = i, assign = a, raw = v }
        end
    end

    local box_w = 336
    local box_x = 20
    local box_y = 20
    local box_h = 48 + (#rows + 1) * 18
    draw_bar(box_x, box_y, box_y + box_h, box_w, st.mon_bg)
    draw_bar(box_x, box_y + box_h - 1, box_y + box_h, box_w, st.border)
    draw_bar(box_x, box_y, box_x + 1, box_h, st.border)
    draw_bar(box_x + box_w - 1, box_y, box_x + box_w, box_h, st.border)
    draw_bar(box_x, box_y, box_x + box_w, box_y + 1, st.border)
    suite_text(box_x + 12, box_y + box_h - 22, "AXIS MONITOR", 10, st.mon)
    suite_text(box_x + 12, box_y + box_h - 38, "RAW  FUNCTION                 VALUE",
        10, st.sub)

    local ry = box_y + box_h - 58
    for _, a in ipairs(rows) do
        suite_text(box_x + 12, ry, string.format("%3d", a.idx), 12, st.label)
        suite_text(box_x + 56, ry, fit_text(axis_assign_name(a.assign), 120),
            12, st.label)
        local cx = box_x + 196
        draw_bar(cx - 40, ry + 3, ry + 6, 80, st.dim, 1.0)
        glColor4f(st.mon[1], st.mon[2], st.mon[3], 1.0)
        glRectf(cx - 40, ry + 2, cx - 40 + (a.raw or 0.0) * 80, ry + 7)
        suite_text(box_x + 244, ry, string.format("%.2f", a.raw or 0.0), 12, st.mon)
        ry = ry - 18
    end
end

function citationx_overlay()
    if not is_c750 then return end
    local screen_w = SCREEN_WIDTH  or 1920
    local screen_h = SCREEN_HIGHT or 1080

    if CONFIG.status_enabled then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        draw_control_panel(screen_h)
    end

    if CONFIG.axis_monitor then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        draw_axis_monitor()
    end

    if toast_text and (citationx_sim_time or 0.0) < toast_until then
        XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        local text_w = measure_string(toast_text)
        local box_w  = text_w + 34
        local box_x  = (screen_w - box_w) / 2
        local box_y  = screen_h - 96
        draw_bar(box_x, box_y - 8, box_y + 22, box_w, CX.bg)
        draw_bar(box_x, box_y - 8, box_y + 22, 3, SUITE_STYLE.accent, 1.0)
        suite_text(box_x + 16, box_y + 3, toast_text, 12, SUITE_STYLE.value)
    end
end

-- ------------------------------------------------------------- MOUSE (UI) ---
-- Panel dragging and clickable rows only. No keystroke handler and no button
-- remap; the wheel is handled separately, and only wheels 1 and 2 are consumed.
function citationx_mouse_click()
    if not is_c750 then
        panel_drag.active = false
        return
    end
    if not CONFIG.status_enabled then
        panel_drag.active = false
        return
    end

    local mx = MOUSE_X or -1.0
    local my = MOUSE_Y or -1.0
    local st = SUITE_STYLE

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

    -- Hub tabs are part of the same draggable panel.
    for i = 1, #panel_tab_rects do
        local r = panel_tab_rects[i]
        if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            citationx_set_flow_tab(r.key)
            RESUME_MOUSE_CLICK = true
            return
        end
    end

    local f = panel_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        citationx_set_status(false)
        RESUME_MOUSE_CLICK = true
        return
    end

    if CONFIG.flow_tab == "flows" then
        for i = 1, #flow_rects do
            local r = flow_rects[i]
            if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
                if r.key == "back" then citationx_flow_back()
                elseif r.key == "next" then citationx_flow_next()
                elseif r.key == "reset" then citationx_flow_reset()
                else citationx_flow_select(r.key) end
                RESUME_MOUSE_CLICK = true
                return
            end
        end
        return
    end

    for i = 1, #status_rects do
        local r = status_rects[i]
        if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            citationx_toggle_module(r.key)
            RESUME_MOUSE_CLICK = true
            return
        end
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
do_on_mouse_click("citationx_mouse_click()")
do_on_mouse_wheel("citationx_mouse_wheel()")

-- ------------------------------------------------ COMMANDS + MACRO MENU -----
-- Each subsystem is a real X-Plane command (bind it yourself if you ever want
-- to) and a FlyWithLua menu switch. Nothing here is pre-bound.
for _, m in ipairs(SUITE_MODULES) do
    create_command("CitationXSuite/toggle_" .. m.key,
        "CitationX Suite: " .. (m.cycle and "next " or "toggle ") .. m.label,
        "citationx_toggle_module('" .. m.key .. "')", "", "")
    if m.cycle then
        add_macro("CitationX Suite: " .. m.macro, "citationx_set_module('" .. m.key .. "', true)")
    else
        add_macro("CitationX Suite: " .. m.macro,
            "citationx_set_module('" .. m.key .. "', true)",
            "citationx_set_module('" .. m.key .. "', false)",
            m.get() and "activate" or "deactivate")
    end
end

create_command("CitationXSuite/texture_next",
    "CitationX Suite: next aircraft texture",
    "citationx_texture_next()", "", "")
create_command("CitationXSuite/texture_prev",
    "CitationX Suite: previous aircraft texture",
    "citationx_texture_prev()", "", "")
create_command("CitationXSuite/test_emergency",
    "CitationX Suite: preview the emergency warning",
    "citationx_test_emergency()", "", "")
create_command("CitationXSuite/status_report",
    "CitationX Suite: write the active-system report to Log.txt",
    "citationx_status_report()", "", "")

-- FLOWS page: every control is a real command and a macro. Nothing is bound to
-- a key or a controller button by the suite itself.
create_command("CitationXSuite/flows_toggle",
    "CitationX Suite: show or hide the FLOWS page in the hub",
    "citationx_flows_toggle()", "", "")
for _, flow in ipairs(CONFIG.flows) do
    create_command("CitationXSuite/flows_select_" .. flow.key,
        "CitationX Suite: show the " .. flow.label .. " flow",
        "citationx_flow_select('" .. flow.key .. "')", "", "")
    add_macro("CitationX Suite: flow " .. flow.label,
        "citationx_flow_select('" .. flow.key .. "')")
end
create_command("CitationXSuite/flows_next",
    "CitationX Suite: complete the current flow step and advance",
    "citationx_flow_next()", "", "")
create_command("CitationXSuite/flows_back",
    "CitationX Suite: return to the previous flow step",
    "citationx_flow_back()", "", "")
create_command("CitationXSuite/flows_reset",
    "CitationX Suite: reset the current flow",
    "citationx_flow_reset()", "", "")
create_command("CitationXSuite/flows_report",
    "CitationX Suite: write the FLOWS progress report to Log.txt",
    "citationx_flow_report()", "", "")

-- Debrief CSV: normally automatic at engine shutdown, with manual controls for
-- checking the path and forcing a row while a flight is still running.
create_command("CitationXSuite/debrief_toggle",
    "CitationX Suite: enable or disable the end-of-flight debrief CSV",
    "citationx_debrief_toggle(false)", "citationx_debrief_toggle(true)",
    CONFIG.debrief_enabled and "activate" or "deactivate")
create_command("CitationXSuite/debrief_write",
    "CitationX Suite: write the current flight's debrief row now",
    "citationx_debrief_write()", "", "")
create_command("CitationXSuite/debrief_report",
    "CitationX Suite: write the debrief report to Log.txt",
    "citationx_debrief_report()", "", "")
add_macro("CitationX Suite: FLOWS page", "citationx_flows_toggle()")
add_macro("CitationX Suite: next flow step", "citationx_flow_next()")
add_macro("CitationX Suite: previous flow step", "citationx_flow_back()")
add_macro("CitationX Suite: reset flow", "citationx_flow_reset()")
add_macro("CitationX Suite: log FLOWS report", "citationx_flow_report()")
add_macro("CitationX Suite: end-of-flight debrief", "citationx_debrief_toggle(true)",
    "citationx_debrief_toggle(false)",
    CONFIG.debrief_enabled and "activate" or "deactivate")
add_macro("CitationX Suite: write debrief now", "citationx_debrief_write()")
add_macro("CitationX Suite: log debrief report", "citationx_debrief_report()")

-- Mouse actions as real commands: point another mouse button, a gesture or a
-- second wheel at these from X-Plane's joystick screen (or the mouse driver).
create_command("CitationXSuite/alt_sel_up",
    "CitationX Suite: altitude selector up", "citationx_alt_up()", "", "")
create_command("CitationXSuite/alt_sel_down",
    "CitationX Suite: altitude selector down", "citationx_alt_down()", "", "")
create_command("CitationXSuite/hdg_bug_up",
    "CitationX Suite: heading bug right", "citationx_hdg_up()", "", "")
create_command("CitationXSuite/hdg_bug_down",
    "CitationX Suite: heading bug left", "citationx_hdg_down()", "", "")
create_command("CitationXSuite/hdg_fast_up",
    "CitationX Suite: heading bug +10 deg", "citationx_hdg_fast_up()", "", "")
create_command("CitationXSuite/hdg_fast_down",
    "CitationX Suite: heading bug -10 deg", "citationx_hdg_fast_down()", "", "")
create_command("CitationXSuite/taxi_light_toggle",
    "CitationX Suite: taxi light toggle", "citationx_taxi_light()", "", "")
create_command("CitationXSuite/landing_lights_toggle",
    "CitationX Suite: both landing lights toggle", "citationx_landing_lights()", "", "")

add_macro("CitationX Suite: previous aircraft texture", "citationx_texture_prev()")
add_macro("CitationX Suite: preview emergency warning", "citationx_test_emergency()")
add_macro("CitationX Suite: log status report", "citationx_status_report()")
add_macro("CitationX Suite: altitude selector up", "citationx_alt_up()")
add_macro("CitationX Suite: altitude selector down", "citationx_alt_down()")
add_macro("CitationX Suite: heading bug right", "citationx_hdg_up()")
add_macro("CitationX Suite: heading bug left", "citationx_hdg_down()")
add_macro("CitationX Suite: heading bug +10", "citationx_hdg_fast_up()")
add_macro("CitationX Suite: heading bug -10", "citationx_hdg_fast_down()")
add_macro("CitationX Suite: taxi light toggle", "citationx_taxi_light()")
add_macro("CitationX Suite: both landing lights", "citationx_landing_lights()")
-- AviTab is a separate plugin; these commands only forward to its own API.
create_command("CitationXSuite/avitab_charts",
    "CitationX Suite: AviTab charts app", "citationx_avitab_charts()", "", "")
create_command("CitationXSuite/avitab_maps",
    "CitationX Suite: AviTab map app", "citationx_avitab_maps()", "", "")
create_command("CitationXSuite/avitab_routes",
    "CitationX Suite: AviTab route app", "citationx_avitab_routes()", "", "")
create_command("CitationXSuite/avitab_airports",
    "CitationX Suite: AviTab airport app", "citationx_avitab_airports()", "", "")
create_command("CitationXSuite/avitab_toggle",
    "CitationX Suite: show/hide the AviTab tablet", "citationx_avitab_toggle()", "", "")
create_command("CitationXSuite/avitab_recentre",
    "CitationX Suite: recentre the AviTab map", "citationx_avitab_recentre()", "", "")
create_command("CitationXSuite/avitab_zoom_in",
    "CitationX Suite: zoom the AviTab map in", "citationx_avitab_zoom_in()", "", "")
create_command("CitationXSuite/avitab_zoom_out",
    "CitationX Suite: zoom the AviTab map out", "citationx_avitab_zoom_out()", "", "")
add_macro("CitationX Suite: AviTab map", "citationx_avitab_maps()")
add_macro("CitationX Suite: AviTab routes", "citationx_avitab_routes()")
add_macro("CitationX Suite: AviTab report", "citationx_avitab_report()")
create_command("CitationXSuite/wheel_report",
    "CitationX Suite: show which mouse wheel moved last",
    "citationx_wheel_report()", "", "")
create_command("CitationXSuite/wheel_map_swap",
    "CitationX Suite: swap the ALT SEL and heading wheels",
    "citationx_wheel_map_swap()", "", "")
add_macro("CitationX Suite: mouse wheel report", "citationx_wheel_report()")
