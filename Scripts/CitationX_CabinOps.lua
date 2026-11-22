-- ============================================================================
--  CESSNA CITATION X CABIN & GROUND OPS
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  A small cabin-crew / ground-handling simulation for the C750:
--
--    BOARDING   click START BOARDING - requests the GPU, connects external
--               power, switches the cabin lights and nav lights on, releases
--               the seatbelt sign and boards your passengers over the
--               configured time (pax counter + progress bar)
--    PREP       when boarding completes the seatbelt sign comes on by itself
--    DEPARTED   once the engines are running the GPU is disconnected and the
--               beacon comes on automatically - you are cleared to taxi
--    STANDBY    resets automatically when you are back on the ground with
--               engines idle, ready for the next leg
--
--  Everything is also clickable on the panel and bindable:
--    CabinOps/toggle_panel      CabinOps/start_boarding   CabinOps/reset
--    CabinOps/skip_boarding     CabinOps/toggle_gpu       CabinOps/toggle_seatbelt
--    CabinOps/toggle_cabin_lights  CabinOps/toggle_beacon CabinOps/request_trucks
-- ============================================================================

CAB_CONFIG = {
    panel_enabled    = false,   -- hidden at load; the Master Suite hub opens it
    panel_w          = 430,
    panel_x          = nil,    -- nil = top-right on first draw; drag writes here
    panel_top        = nil,    -- absolute top edge (bottom-left origin)
    row_h            = 21,
    pax_total        = 8,      -- passengers (C750 cabin is 8-12 typical)
    boarding_seconds = 150,    -- real seconds from START to boarding complete
    require_c750     = true,   -- only run the flow when flying the C750
    engine_run_n1    = 20,     -- % N1 considered "engines running"
    ground_reset_s   = 20,     -- engines idle on ground this long -> STANDBY
}

-- Geometry only; colours come from the shared MA dark field (CX).
CS = {
    bg        = CX.bg,
    header_bg = CX.header_bg,
    border    = CX.border,
    hairline  = CX.hairline,
    title     = CX.title,
    sub       = CX.sub,
    label     = CX.label,
    value     = CX.value,
    dim       = CX.dim,
    ok        = CX.ok,
    warn      = CX.warn,
    bad       = CX.bad,
    btn       = CX.btn,
    -- legacy aliases used by the existing drawing code
    footer_bg = CX.footer_bg,
    footer_fg = CX.footer_fg,
    header_h  = 34,
    footer_h  = 34,
    pad       = 14,
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("cab_n1_l",      "sim/cockpit2/engine/indicators/N1_percent", "readonly", 1)
dataref("cab_n1_r",      "sim/cockpit2/engine/indicators/N1_percent", "readonly", 2)
dataref("cab_on_ground", "sim/flightmodel/failures/onground_any", "readonly")
dataref("cab_sim_time",  "sim/time/total_running_time_sec", "readonly")
dataref("cab_paused",    "sim/time/paused", "readonly")

-- CitX runtime datarefs (resolved lazily; only exist once the C750 is loaded).
CITX_CB = {
    ext_pwr   = "laminar/CitX/electrical/ext_pwr",
    seatbelt  = "laminar/CitX/lights/seat_belt_pass_safety",
    cabin_master = "laminar/CitX/lights/cabin_master",
    cabin_lights = "laminar/CitX/lights/cabin_lights_on",
    beacon    = "laminar/CitX/lights/gnd_rec_anti_coll",
    nav       = "laminar/CitX/lights/navigation",
}

local cb_ref   = {}
local CBV      = {}
local cb_retry_at = 0

-- ---------------------------------------------------------------- STATE ----
local PHASE_STANDBY  = 0
local PHASE_BOARDING = 1
local PHASE_PREP     = 2
local PHASE_DEPARTED = 3
local phase          = PHASE_STANDBY
local pax_boarded    = 0
local phase_time     = 0
local ground_idle_t  = 0
local was_airborne   = false
local gpu_requested  = false
local cb_frame_last  = nil
local cb_rows        = {}
local cb_toast_text  = nil
local cb_toast_until = 0
local is_c750        = (PLANE_ICAO == "C750")   -- refreshed every frame

local PHASE_NAME = { "STANDBY", "BOARDING", "PREP / PUSH", "DEPARTED" }

-- --------------------------------------------------------------- HELPERS ---
local function cb_toast(text)
    cb_toast_text  = text
    cb_toast_until = (cab_sim_time or 0) + 2.5
end

local function resolve_cb_refs()
    for name, path in pairs(CITX_CB) do
        if not cb_ref[name] then cb_ref[name] = XPLMFindDataRef(path) end
    end
end

local function poll_cb_refs()
    for name, _ in pairs(CITX_CB) do
        local h = cb_ref[name]
        if h then CBV[name] = XPLMGetDataf(h) end
    end
end

local function guarded(action, on)
    if CAB_CONFIG.require_c750 and not is_c750 then
        cb_toast("CABIN OPS: C750 ONLY")
        return
    end
    action()
    if on then cb_toast(on) end
end

-- ------------------------------------------------------------ GROUND SVC ---
local function gpu_set(on)
    if on and not gpu_requested then
        command_once("sim/ground_ops/toggle_gpu_request")
        gpu_requested = true
    elseif not on and gpu_requested then
        command_once("sim/ground_ops/toggle_gpu_request")
        gpu_requested = false
    end
    -- connect / disconnect the airplane-side switch
    if on and (CBV.ext_pwr or 0) < 0.5 then
        command_once("laminar/CitX/electrical/cmd_ext_pwr_toggle")
    elseif not on and (CBV.ext_pwr or 0) > 0.5 then
        command_once("laminar/CitX/electrical/cmd_ext_pwr_toggle")
    end
end

local function seatbelt_set(on)
    if on and (CBV.seatbelt or 0) < 0.5 then
        command_once("laminar/CitX/lights/cmd_seat_belt_pass_safety_up")
    elseif not on and (CBV.seatbelt or 0) > 0.5 then
        command_once("laminar/CitX/lights/cmd_seat_belt_pass_safety_dwn")
    end
end

local function beacon_set(on)
    if on and (CBV.beacon or 0) < 0.5 then
        command_once("laminar/CitX/lights/cmd_gnd_rec_anti_coll_up")
    elseif not on and (CBV.beacon or 0) > 0.5 then
        command_once("laminar/CitX/lights/cmd_gnd_rec_anti_coll_dwn")
    end
end

local function cabin_lights_set(on)
    if on and (CBV.cabin_master or 0) < 0.5 then
        command_once("laminar/CitX/lights/cmd_cabin_master_toggle")
    elseif not on and (CBV.cabin_master or 0) > 0.5 then
        command_once("laminar/CitX/lights/cmd_cabin_master_toggle")
    end
end

-- ----------------------------------------------------------------- FLOW ----
function cab_start_boarding()
    guarded(function()
        if phase ~= PHASE_STANDBY then return end
        phase       = PHASE_BOARDING
        phase_time  = 0
        pax_boarded = 0
        gpu_set(true)
        cabin_lights_set(true)
        if (CBV.nav or 0) < 0.5 then
            command_once("laminar/CitX/lights/cmd_navigation_toggle")
        end
        seatbelt_set(false)
        cb_toast("BOARDING - " .. CAB_CONFIG.pax_total .. " PAX")
        logMsg("Cabin Ops: boarding started")
    end)
end

function cab_skip_boarding()
    if phase == PHASE_BOARDING then
        pax_boarded = CAB_CONFIG.pax_total
        cb_toast("BOARDING SKIPPED")
    end
end

function cab_toggle_gpu()
    guarded(function() gpu_set(not gpu_requested) end,
        "GPU: " .. (gpu_requested and "ON" or "OFF"))
end

function cab_toggle_seatbelt()
    guarded(function() seatbelt_set((CBV.seatbelt or 0) < 0.5) end, "SEATBELT SIGN")
end

function cab_toggle_cabin_lights()
    guarded(function() cabin_lights_set((CBV.cabin_master or 0) < 0.5) end, "CABIN LIGHTS")
end

function cab_toggle_nav()
    guarded(function() command_once("laminar/CitX/lights/cmd_navigation_toggle") end, "NAV LIGHTS")
end

function cab_toggle_beacon()
    guarded(function() beacon_set((CBV.beacon or 0) < 0.5) end, "BEACON")
end

function cab_request_trucks()
    guarded(function() command_once("sim/ground_ops/service_plane") end, "GROUND TRUCKS")
end

function cab_reset()
    phase          = PHASE_STANDBY
    pax_boarded    = 0
    phase_time     = 0
    ground_idle_t  = 0
    was_airborne   = false
    cb_toast("CABIN OPS: RESET")
end

-- ----------------------------------------------------------- FRAME LOOP ----
function cab_frame()
    is_c750 = (PLANE_ICAO == "C750")
    if CAB_CONFIG.require_c750 and not is_c750 then
        if phase ~= PHASE_STANDBY then cab_reset() end
        return
    end

    local now = cab_sim_time or 0
    if now >= cb_retry_at then
        cb_retry_at = now + 5.0
        resolve_cb_refs()
    end
    poll_cb_refs()

    local dt = cb_frame_last and (now - cb_frame_last) or 0
    cb_frame_last = now
    if dt < 0 or dt > 2 or (cab_paused or 0) == 1 then dt = 0 end

    local running = ((cab_n1_l or 0) > CAB_CONFIG.engine_run_n1)
                or ((cab_n1_r or 0) > CAB_CONFIG.engine_run_n1)

    if phase == PHASE_BOARDING then
        phase_time = phase_time + dt
        pax_boarded = math.min(CAB_CONFIG.pax_total,
            CAB_CONFIG.pax_total * phase_time / CAB_CONFIG.boarding_seconds)
        if pax_boarded >= CAB_CONFIG.pax_total then
            phase      = PHASE_PREP
            phase_time = 0
            seatbelt_set(true)
            cb_toast("BOARDING COMPLETE - SEATBELT SIGN ON")
            logMsg("Cabin Ops: boarding complete, prep phase")
        end
    elseif phase == PHASE_PREP then
        phase_time = phase_time + dt
        if running and phase_time > 3 then
            gpu_set(false)
            beacon_set(true)
            phase = PHASE_DEPARTED
            cb_toast("ENGINES RUNNING - GPU DISCONNECTED, BEACON ON")
            logMsg("Cabin Ops: departed phase")
        end
    elseif phase == PHASE_DEPARTED then
        if (cab_on_ground or 0) == 1 then
            if running then
                was_airborne = true
                ground_idle_t = 0
            elseif was_airborne then
                ground_idle_t = ground_idle_t + dt
                if ground_idle_t >= CAB_CONFIG.ground_reset_s then
                    phase          = PHASE_STANDBY
                    pax_boarded    = 0
                    was_airborne   = false
                    ground_idle_t  = 0
                    cb_toast("ENGINES IDLE - CABIN OPS RESET")
                    logMsg("Cabin Ops: auto reset after arrival")
                end
            end
        else
            was_airborne  = true
            ground_idle_t = 0
        end
    end
end

-- ------------------------------------------------------------ ImGui PANEL ----
-- Converted 2026-11-22: the panel is a native ImGui floating window in regular
-- Neo Grotesque. ImGui owns clicking and dragging, so the old GL hit-test and
-- mouse handler are gone; the state machine above is untouched.
CAB_ACTIONS = {
    start   = cab_start_boarding,
    skip    = cab_skip_boarding,
    gpu     = cab_toggle_gpu,
    cabin   = cab_toggle_cabin_lights,
    seatbelt= cab_toggle_seatbelt,
    beacon  = cab_toggle_beacon,
    nav     = cab_toggle_nav,
    trucks  = cab_request_trucks,
    reset   = cab_reset,
}

local cab_wnd = nil
local cab_closed = false

function cab_toggle_panel(on)
    if on == nil then
        CAB_CONFIG.panel_enabled = not CAB_CONFIG.panel_enabled
    else
        CAB_CONFIG.panel_enabled = (on == true)
    end
    cxui_show(cab_wnd, CAB_CONFIG.panel_enabled)
    cb_toast("CABIN OPS PANEL: " .. (CAB_CONFIG.panel_enabled and "ON" or "OFF"))
end

function cab_aircraft_guard()
    if cab_closed then return end
    cxui_show(cab_wnd, is_c750 and CAB_CONFIG.panel_enabled)
end

function cab_on_close(wnd)
    local _ = wnd
    cab_wnd = nil
    cab_closed = true
    CAB_CONFIG.panel_enabled = false
end

local function cab_panel_rows()
    local rows = {}
    if phase == PHASE_STANDBY then
        rows[#rows + 1] = { "START BOARDING", "start", true, true }
    elseif phase == PHASE_BOARDING then
        rows[#rows + 1] = { "SKIP BOARDING", "skip", true, true }
    end
    rows[#rows + 1] = { "GROUND POWER (GPU)", "gpu", gpu_requested }
    rows[#rows + 1] = { "CABIN LIGHTS", "cabin", (CBV.cabin_master or 0) > 0.5 }
    rows[#rows + 1] = { "SEATBELT SIGN", "seatbelt", (CBV.seatbelt or 0) > 0.5 }
    rows[#rows + 1] = { "BEACON", "beacon", (CBV.beacon or 0) > 0.5 }
    rows[#rows + 1] = { "NAV LIGHTS", "nav", (CBV.nav or 0) > 0.5 }
    rows[#rows + 1] = { "GROUND TRUCKS / FUEL", "trucks", false }
    if phase ~= PHASE_STANDBY then
        rows[#rows + 1] = { "RESET", "reset", false }
    end
    return rows
end

function cab_on_build(wnd, x, y)
    local _ = wnd
    local _x = x
    local _y = y
    if PLANE_ICAO ~= "C750" then return end
    local style = cxui_begin_style()

    cxui_text("CABIN / GROUND")
    cxui_muted(PHASE_NAME[phase + 1], "small")
    cxui_spacing()

    -- passenger progress, now an ImGui ProgressBar
    cxui_text(string.format("PAX  %d / %d",
        math.floor(pax_boarded + 0.5), CAB_CONFIG.pax_total))
    if phase == PHASE_DEPARTED then
        cxui_text("ALL ABOARD", "small", CXUI.color.on)
    elseif phase == PHASE_PREP then
        cxui_text("PREFLIGHT", "small", CXUI.color.active)
    else
        cxui_text(string.format("%d%%",
            math.floor(100 * pax_boarded / CAB_CONFIG.pax_total + 0.5)),
            "small", CXUI.color.muted)
    end
    cxui_progress(pax_boarded / CAB_CONFIG.pax_total, 300)
    cxui_spacing()

    cxui_section("ACTIONS")
    for _, r in ipairs(cab_panel_rows()) do
        local name, key, on, full = r[1], r[2], r[3], r[4]
        local clicked
        if full then
            clicked = cxui_button(name .. "###cab_" .. key, 300, CXUI.row_h)
        elseif key == "trucks" then
            clicked = cxui_button(name .. "###cab_" .. key, 300, CXUI.row_h)
        else
            clicked = cxui_row(name, on and "ON" or "OFF", "cab_" .. key,
                300, CXUI.label_w, CXUI.state_w)
        end
        if clicked then
            local fn = CAB_ACTIONS[key]
            if fn then fn() end
        end
    end

    cxui_spacing()
    if cxui_button("HIDE PANEL###cab_hide", 300, CXUI.row_h) then
        cab_toggle_panel(false)
    end
    cxui_end_style(style)
end

-- ------------------------------------------------------- COMMANDS + MENU ---
create_command("CabinOps/toggle_panel",       "Cabin Ops: toggle the panel",            "cab_toggle_panel()", "", "")
create_command("CabinOps/start_boarding",     "Cabin Ops: start boarding (GPU, lights)", "cab_start_boarding()", "", "")
create_command("CabinOps/skip_boarding",      "Cabin Ops: skip boarding",               "cab_skip_boarding()", "", "")
create_command("CabinOps/toggle_gpu",         "Cabin Ops: toggle ground power",         "cab_toggle_gpu()", "", "")
create_command("CabinOps/toggle_seatbelt",    "Cabin Ops: toggle seatbelt sign",        "cab_toggle_seatbelt()", "", "")
create_command("CabinOps/toggle_cabin_lights","Cabin Ops: toggle cabin lights",         "cab_toggle_cabin_lights()", "", "")
create_command("CabinOps/toggle_nav",         "Cabin Ops: toggle nav lights",           "cab_toggle_nav()", "", "")
create_command("CabinOps/toggle_beacon",      "Cabin Ops: toggle beacon",               "cab_toggle_beacon()", "", "")
create_command("CabinOps/request_trucks",     "Cabin Ops: call ground trucks / fuel",   "cab_request_trucks()", "", "")
create_command("CabinOps/reset",              "Cabin Ops: reset the flow",              "cab_reset()", "", "")

add_macro("Cabin Ops: toggle panel", "cab_toggle_panel(true)", "cab_toggle_panel(false)",
    CAB_CONFIG.panel_enabled and "activate" or "deactivate")
add_macro("Cabin Ops: start boarding", "cab_start_boarding()")
add_macro("Cabin Ops: skip boarding", "cab_skip_boarding()")
add_macro("Cabin Ops: call ground trucks", "cab_request_trucks()")
add_macro("Cabin Ops: reset flow", "cab_reset()")

logMsg("Cabin & Ground Ops loaded")
do_every_frame("cab_frame()")

-- Create the ImGui window once. It starts hidden; the hub / Control Center
-- toggle opens it, and the aircraft guard hides it off the C750.
local cab_sw = tonumber(SCREEN_WIDTH) or 1920
local cab_sh = tonumber(SCREEN_HIGHT) or 1080
cab_wnd = cxui_create_window(430, 470, "Citation X Cabin Ops",
    "cab_on_build", "cab_on_close",
    math.max(8, cab_sw - 438), math.max(8, cab_sh - 494))
cxui_show(cab_wnd, false)
do_often("cab_aircraft_guard()")
