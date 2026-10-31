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
--    2. Mouse wheel      - forward/backward moves ALT SEL (the only input the
--                          suite reads itself; no key is ever captured)
--    3. Mouse actions    - taxi light, both landing lights, heading bug and
--                          ALT SEL are published as real X-Plane commands, so
--                          a middle click / gesture / thumbwheel can be pointed
--                          at them from X-Plane or the mouse driver
--    4. Flight recorder  - 1 Hz CSV of altitude, Mach, IAS, attitude, G, fuel
--    5. Emergency gen    - rare bleed-air / pressurisation warning at altitude
--    6. Axis monitor     - opt-in diagnostic readout of the live raw axes
--    7. Texture cycler   - steps through the installed liveries from the panel
--    8. Panel hub        - opens the sibling panels (EFB, QRH, cabin, realism)
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
    status_enabled         = true,    -- the hub is the one panel shown at load
    status_clickable       = true,    -- click a row to toggle / cycle it

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
    -- The only pilot input the suite reads itself. Wheel forward/backward
    -- moves ALT SEL; nothing is bound to a key and no button is remapped.
    -- Middle click / gestures belong to the mouse driver or X-Plane's own
    -- joystick screen - the suite only publishes commands for them.
    mouse_wheel_altitude   = true,
    -- X-Plane reports which wheel moved: the main wheel and the thumbwheel
    -- are different numbers. 1 = main wheel -> ALT SEL, 2 = thumbwheel ->
    -- heading bug. Swap them with CitationXSuite/wheel_map_swap if your mouse
    -- enumerates them the other way round.
    wheel_altitude_number  = 1,
    wheel_heading_number   = 2,
    wheel_heading_enabled  = true,
    alt_step_ft            = 100,
    hdg_step_deg           = 1,
    alt_min_ft             = 0,
    alt_max_ft             = 50000,
}

-- ----------------------------------------------------------- PANEL STYLE ----
-- Shared black/Helvetica language. 38 px header, 22 px rows, hairline
-- separators and a two-tone body so a 1600-wide screen still reads cleanly.
SUITE_STYLE = {
    x            = 470,
    top          = nil,          -- nil = top-right on first draw
    width        = 446,
    pad          = 16,
    header_h     = 38,
    sub_h        = 22,
    row_h        = 22,
    footer_h     = 34,
    bg           = {0.00, 0.00, 0.00, 0.92},
    bg_alt       = {0.06, 0.06, 0.06, 0.92},
    header_bg    = {0.05, 0.05, 0.05, 0.97},
    border       = {0.36, 0.36, 0.36, 1.00},
    hairline     = {0.22, 0.22, 0.22, 1.00},
    title        = {1.00, 1.00, 1.00, 1.00},
    sub          = {0.58, 0.58, 0.58, 1.00},
    label        = {0.86, 0.86, 0.86, 1.00},
    value        = {1.00, 1.00, 1.00, 1.00},
    dim          = {0.46, 0.46, 0.46, 1.00},
    ok           = {0.45, 0.88, 0.52, 1.00},
    warn         = {0.96, 0.74, 0.26, 1.00},
    alert        = {0.96, 0.36, 0.32, 1.00},
    btn          = {0.11, 0.11, 0.11, 1.00},
    accent       = {1.00, 1.00, 1.00, 1.00},
    subhdr       = {0.58, 0.58, 0.58, 1.00},
    mon_bg       = {0.03, 0.05, 0.03, 0.90},
    mon          = {0.62, 0.95, 0.66, 1.00},
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
local is_c750          = true

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
        key = "efb", label = "EFB", macro = "EFB panel",
        get = function()
            return (type(EFB_CONFIG) == "table") and EFB_CONFIG.panel_enabled or false
        end,
        set = function(on)
            if type(efb_toggle_panel) == "function" then efb_toggle_panel(on) end
        end,
        state = function()
            if type(EFB_CONFIG) ~= "table" then return "ABSENT" end
            return EFB_CONFIG.panel_enabled and "ON" or "OFF"
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
            return REAL_CONFIG.enabled and "ON" or "OFF"
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
local last_tick_time   = 0
local last_frame_time  = 0
local smooth_pitch     = 0.0
local smooth_roll      = 0.0

local toast_text       = nil
local toast_until      = 0.0
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
    log_fd:flush()
end

local function toast(text)
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
-- The wheel is the one pilot input the suite touches, and it only moves the
-- two autopilot selectors. Every action is also a real X-Plane command, so a
-- middle click, a gesture or a thumbwheel can be pointed at it from X-Plane's
-- joystick screen (or the mouse driver) without the suite grabbing anything.
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

function citationx_hdg_up()
    local deg = ((citationx_hdg_sel_deg or 0) + CONFIG.hdg_step_deg) % 360
    citationx_hdg_sel_deg = deg
    toast(string.format("HDG %03.0f", deg))
end

function citationx_hdg_down()
    local deg = ((citationx_hdg_sel_deg or 0) - CONFIG.hdg_step_deg) % 360
    if deg < 0 then deg = deg + 360 end
    citationx_hdg_sel_deg = deg
    toast(string.format("HDG %03.0f", deg))
end

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

-- Two wheels, two selectors:
--   main wheel forward/back  -> ALT SEL up/down
--   thumbwheel forward/back  -> heading bug right/left
-- X-Plane tells us which wheel moved in MOUSE_WHEEL_NUMBER. RESUME_MOUSE_WHEEL
-- keeps the notch from also zooming the view. No key is ever read.
local wheel_last_number, wheel_last_clicks = nil, 0

function citationx_mouse_wheel()
    local clicks = MOUSE_WHEEL_CLICKS or 0
    local wheel  = MOUSE_WHEEL_NUMBER or 1
    wheel_last_number, wheel_last_clicks = wheel, clicks
    if clicks == 0 then return end

    if wheel == CONFIG.wheel_heading_number then
        if not CONFIG.wheel_heading_enabled then return end
        local n = math.min(math.abs(clicks), 10)
        for _ = 1, n do
            if clicks > 0 then citationx_hdg_up() else citationx_hdg_down() end
        end
    else
        if not CONFIG.mouse_wheel_altitude then return end
        local n = math.min(math.abs(clicks), 10)
        for _ = 1, n do
            if clicks > 0 then citationx_alt_up() else citationx_alt_down() end
        end
    end
    RESUME_MOUSE_WHEEL = true
end

-- Which physical wheel is which? Turn one notch and run the report.
function citationx_wheel_report()
    logMsg(string.format(
        "Citation X Suite: last wheel event = number %s, %d click(s); ALT SEL wheel %d, heading wheel %d",
        tostring(wheel_last_number), wheel_last_clicks or 0,
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
    logMsg("  input layer = mouse wheel -> ALT SEL (no keystrokes, no buttons)")
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        logMsg(string.format("  %-18s : %s", m.label, m.state()))
    end
end

-- ------------------------------------------------------------- FRAME LOOP ---
function citationx_frame()
    local now = citationx_sim_time or 0.0
    local dt  = now - last_frame_time
    if dt < 0.0 then dt = 0.0 end
    last_frame_time = now

    is_c750 = (PLANE_ICAO == "C750")

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

-- Helvetica faces; 18 for titles, 12 for rows, 10 for captions.
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

-- Black shell: body, 1 px border, 2 px header rule, title and right caption.
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
    local by0 = bottom + 7
    local by1 = by0 + st.footer_h - 12
    draw_bar(x + st.pad, by0, by1, w - 2 * st.pad, st.btn)
    draw_bar(x + st.pad, by1 - 1, by1, w - 2 * st.pad, st.border)
    local tw = measure_string(label, "Helvetica_10") or measure_string(label)
    suite_text(x + (w - tw) / 2, by0 + 7, label, 10, st.value)
    return { x0 = x + st.pad, x1 = x + w - st.pad, y0 = by0, y1 = by1 }
end

-- header (38) + sub-header (22) + rows + footer + padding
function control_panel_height()
    local st = SUITE_STYLE
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

    status_rects = {}

    draw_shell(x, top, w, h, "CITATION X", "MASTER SUITE 3.0")

    -- sub-header: what the hub is, so the intent is visible in the cockpit
    suite_text(x + pad, body_top - 15, "SUITE CONTROL", 10, st.sub)
    local note = "MOUSE ONLY - NO KEYBINDS"
    local nw = measure_string(note, "Helvetica_10") or measure_string(note)
    suite_text(x + w - pad - nw, body_top - 15, note, 10, st.dim)
    draw_bar(x, body_top - st.sub_h, body_top, w, st.hairline, 0.45)

    local first_y = body_top - st.sub_h - 15
    for i = 1, #SUITE_MODULES do
        local m = SUITE_MODULES[i]
        local row_top = first_y + st.row_h - (i - 1) * st.row_h
        local y = row_top - 15
        local text = m.state()
        local col  = m.cycle and st.value or state_color(text)

        -- alternating body tone keeps 11 rows readable at a glance
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
        draw_bar(box_x, box_y - 8, box_y + 22, box_w, {0.00, 0.00, 0.00}, 0.92)
        draw_bar(box_x, box_y - 8, box_x + 3, box_y + 22, SUITE_STYLE.accent, 1.0)
        suite_text(box_x + 16, box_y + 3, toast_text, 12, SUITE_STYLE.value)
    end
end

-- ------------------------------------------------------------- MOUSE (UI) ---
-- Panel dragging and clickable rows only. No keystroke and no wheel handler is
-- registered at all, so every key and scroll belongs to X-Plane.
function citationx_mouse_click()
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

    local f = panel_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        citationx_set_status(false)
        RESUME_MOUSE_CLICK = true
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

-- Mouse actions as real commands: point a middle click, a gesture or the
-- thumbwheel at these from X-Plane's joystick screen (or the mouse driver).
create_command("CitationXSuite/alt_sel_up",
    "CitationX Suite: altitude selector up", "citationx_alt_up()", "", "")
create_command("CitationXSuite/alt_sel_down",
    "CitationX Suite: altitude selector down", "citationx_alt_down()", "", "")
create_command("CitationXSuite/hdg_bug_up",
    "CitationX Suite: heading bug right", "citationx_hdg_up()", "", "")
create_command("CitationXSuite/hdg_bug_down",
    "CitationX Suite: heading bug left", "citationx_hdg_down()", "", "")
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
    "CitationX Suite: log which mouse wheel moved last",
    "citationx_wheel_report()", "", "")
create_command("CitationXSuite/wheel_map_swap",
    "CitationX Suite: swap the ALT SEL and heading wheels",
    "citationx_wheel_map_swap()", "", "")
add_macro("CitationX Suite: mouse wheel report", "citationx_wheel_report()")
