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

-- Same black / Helvetica language as the realism panel.
CS = {
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
    -- legacy aliases used by the existing drawing code
    accent    = {1.00, 1.00, 1.00, 1.00},
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
local is_c750        = false

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

function cab_toggle_panel(on)
    if on == nil then
        CAB_CONFIG.panel_enabled = not CAB_CONFIG.panel_enabled
    else
        CAB_CONFIG.panel_enabled = (on == true)
    end
    cb_toast("CABIN OPS PANEL: " .. (CAB_CONFIG.panel_enabled and "ON" or "OFF"))
end

-- ----------------------------------------------------------- FRAME LOOP ----
function cab_frame()
    is_c750 = (PLANE_ICAO == "C750")

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

-- ------------------------------------------------------------- DRAWING -----
local function bar(x, y0, y1, w, color, alpha)
    glColor4f(color[1], color[2], color[3], alpha or color[4] or 1.0)
    glRectf(x, y0, x + w, y1)
end

local function cab_font(size)
    if size == 18 then return draw_string_Helvetica_18 or draw_string end
    if size == 10 then return draw_string_Helvetica_10 or draw_string end
    return draw_string_Helvetica_12 or draw_string
end

local function txt(x, y, text, color, size)
    glColor4f(color[1], color[2], color[3], color[4] or 1.0)
    cab_font(size or 12)(x, y, tostring(text or ""))
end

local function txt_right(right_x, y, text, color, size)
    local s = tostring(text or "")
    local sz = size or 12
    local tw = measure_string(s, "Helvetica_" .. tostring(sz)) or measure_string(s)
    txt(right_x - tw, y, s, color, sz)
end

local function state_word(v)
    if (v or 0) > 0.5 then return "ON", CS.ok end
    return "OFF", CS.dim
end

local cab_header_rect = nil
local cab_footer_rect = nil
local cab_drag = { active = false, dx = 0, dy = 0 }

function cab_draw()
    if not CAB_CONFIG.panel_enabled then
        cab_drag.active = false
        return
    end
    cb_rows = {}

    local cfg = CAB_CONFIG
    local st  = CS
    local w   = cfg.panel_w
    local rh  = cfg.row_h
    local sw  = SCREEN_WIDTH or 1920
    local sh  = SCREEN_HIGHT or 1080

    -- status / action rows (built first: the panel height follows the content)
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

    local h = st.header_h + 44 + #rows * rh + st.footer_h + 8

    local x = cfg.panel_x or (sw - w - 24)
    x = math.max(0, math.min(x, sw - w))
    local top = cfg.panel_top or (sh - 24)
    top = math.max(h, math.min(top, sh - 4))
    cfg.panel_x, cfg.panel_top = x, top
    local bottom = top - h

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    -- black shell: body, 1 px border, 34 px header
    bar(x, bottom, top, w, st.bg)
    bar(x, top - 1, top, w, st.border)
    bar(x, bottom, top, 1, st.border)
    bar(x + w - 1, bottom, top, 1, st.border)
    bar(x, bottom, bottom + 1, w, st.border)
    bar(x, top - st.header_h, top, w, st.header_bg)
    bar(x, top - st.header_h, top - st.header_h + 2, w, st.border)
    txt(x + st.pad, top - 25, "CABIN / GROUND", st.title, 18)
    txt_right(x + w - st.pad, top - 22, PHASE_NAME[phase + 1],
        phase == PHASE_STANDBY and st.dim or st.ok, 10)
    cab_header_rect = { x0 = x, x1 = x + w, y0 = top - st.header_h, y1 = top }

    local y = top - st.header_h

    -- pax progress
    txt(x + st.pad, y - 15, string.format("PAX  %d / %d",
        math.floor(pax_boarded + 0.5), cfg.pax_total), st.value)
    if phase == PHASE_DEPARTED then
        txt_right(x + w - st.pad, y - 15, "ALL ABOARD", st.ok)
    elseif phase == PHASE_PREP then
        txt_right(x + w - st.pad, y - 15, "PREFLIGHT", st.warn)
    else
        txt_right(x + w - st.pad, y - 15,
            string.format("%d%%", math.floor(100 * pax_boarded / cfg.pax_total + 0.5)),
            st.accent)
    end
    local pbx, pby, pbw = x + st.pad, y - 32, w - 2 * st.pad
    bar(pbx, pby, pby + 8, pbw, {0.05, 0.05, 0.05}, 0.9)
    local frac = pax_boarded / cfg.pax_total
    if frac > 0 then bar(pbx, pby, pby + 8, pbw * frac, st.ok, 0.95) end
    y = y - 44

    for _, r in ipairs(rows) do
        local name, key, on = r[1], r[2], r[3]
        local full = r[4]

        if full then
            bar(x + st.pad, y - rh + 6, y + 4, w - 2 * st.pad,
                key == "start" and st.ok or st.warn, 0.85)
            txt(x + st.pad + 8, y - 13, name, {0.05, 0.05, 0.05})
        else
            glColor4f((on == true) and st.ok[1] or st.dim[1],
                      (on == true) and st.ok[2] or st.dim[2],
                      (on == true) and st.ok[3] or st.dim[3], 1.0)
            glRectf(x + st.pad, y - 12, x + st.pad + 6, y - 6)
            txt(x + st.pad + 16, y - 12, name, st.label)
            if key ~= "trucks" then
                txt_right(x + w - st.pad, y - 12, on == true and "ON" or "OFF",
                    on == true and st.ok or st.dim)
            end
        end

        cb_rows[#cb_rows + 1] = {
            key = key, x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
        }
        y = y - rh
    end

    -- footer: drag-safe hide button
    local by0 = bottom + 8
    local by1 = by0 + st.footer_h - 12
    bar(x + st.pad, by0, by1, w - 2 * st.pad, st.btn)
    local label = "HIDE PANEL"
    local tw = measure_string(label, "Helvetica_10") or measure_string(label)
    txt(x + (w - tw) / 2, by0 + 6, label, st.value, 10)
    cab_footer_rect = { x0 = x + st.pad, x1 = x + w - st.pad, y0 = by0, y1 = by1 }

    -- toast
    if cb_toast_text and (cab_sim_time or 0) < cb_toast_until then
        local tw2 = (measure_string(cb_toast_text, "Helvetica_12")
            or measure_string(cb_toast_text)) + 32
        local by = bottom - 30
        bar(x + w - tw2, by, by + 24, tw2, {0.00, 0.00, 0.00}, 0.92)
        bar(x + w - tw2, by, by + 24, 4, st.ok)
        txt(x + w - tw2 + 16, by + 7, cb_toast_text, st.value)
    end
end

-- --------------------------------------------------------------- MOUSE -----
local CAB_ACTIONS = {
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

function cab_mouse_click()
    if not CAB_CONFIG.panel_enabled then
        cab_drag.active = false
        return
    end

    local mx, my = MOUSE_X or -1, MOUSE_Y or -1
    local cfg = CAB_CONFIG
    local st  = CS

    if MOUSE_STATUS == "down" then
        local hr = cab_header_rect
        if hr and mx >= hr.x0 and mx <= hr.x1 and my >= hr.y0 and my <= hr.y1 then
            cab_drag.active = true
            cab_drag.dx = mx - (cfg.panel_x or mx)
            cab_drag.dy = my - (cfg.panel_top or my)
            RESUME_MOUSE_CLICK = true
            return
        end
    elseif MOUSE_STATUS == "drag" then
        if cab_drag.active then
            local sw = SCREEN_WIDTH or 1920
            local sh = SCREEN_HIGHT or 1080
            cfg.panel_x = math.max(0, math.min(mx - cab_drag.dx, sw - cfg.panel_w))
            cfg.panel_top = math.max(120, math.min(my - cab_drag.dy, sh - 4))
            RESUME_MOUSE_CLICK = true
        end
        return
    elseif MOUSE_STATUS == "up" then
        if cab_drag.active then
            cab_drag.active = false
            RESUME_MOUSE_CLICK = true
            return
        end
    end

    if MOUSE_STATUS ~= "down" then return end

    local f = cab_footer_rect
    if f and mx >= f.x0 and mx <= f.x1 and my >= f.y0 and my <= f.y1 then
        cab_toggle_panel(false)
        RESUME_MOUSE_CLICK = true
        return
    end

    for _, r in ipairs(cb_rows) do
        if mx >= r.x0 and mx <= r.x1 and my >= r.y0 and my <= r.y1 then
            RESUME_MOUSE_CLICK = true
            local fn = CAB_ACTIONS[r.key]
            if fn then fn() end
            return
        end
    end
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
do_every_draw("cab_draw()")
do_on_mouse_click("cab_mouse_click()")
