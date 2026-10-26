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

-- Same black / Helvetica language as the realism panel.
ST = {
    bg         = {0.00, 0.00, 0.00, 0.90},
    header_bg  = {0.04, 0.04, 0.04, 0.96},
    header_act = {0.16, 0.05, 0.05, 0.96},
    border     = {0.32, 0.32, 0.32, 1.00},
    title      = {1.00, 1.00, 1.00, 1.00},
    sub        = {0.55, 0.55, 0.55, 1.00},
    label      = {0.80, 0.80, 0.80, 1.00},
    value      = {1.00, 1.00, 1.00, 1.00},
    dim        = {0.45, 0.45, 0.45, 1.00},
    ok         = {0.45, 0.85, 0.50, 1.00},
    warn       = {0.95, 0.72, 0.25, 1.00},
    alert      = {0.95, 0.36, 0.32, 1.00},
    btn        = {0.10, 0.10, 0.10, 1.00},
    -- legacy aliases used by the existing drawing code
    accent     = {1.00, 1.00, 1.00, 1.00},
    subhdr     = {0.55, 0.55, 0.55, 1.00},
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

-- Standard state used by the checklist verifiers (1-based array slots).
dataref("ft_throttle_l",   "sim/cockpit2/engine/actuators/throttle_ratio", "readonly", 1)
dataref("ft_ext_bottle_l", "sim/cockpit2/engine/actuators/fire_extinguisher_on", "readonly", 1)
dataref("ft_master_caution", "sim/cockpit2/annunciators/master_caution", "readonly")
dataref("ft_eng_fire_l",     "sim/cockpit2/annunciators/engine_fires", "readonly", 1)
dataref("ft_on_ground",      "sim/flightmodel/failures/onground_any", "readonly")
dataref("ft_sim_time",       "sim/time/total_running_time_sec", "readonly")

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
    antiskid   = "laminar/CitX/hydraulics/antiskid",
}

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
    glColor4f(color[1], color[2], color[3], alpha or color[4] or 1.0)
    glRectf(x, y0, x + w, y1)
end

local function qrh_font(size)
    if size == 18 then return draw_string_Helvetica_18 or draw_string end
    if size == 10 then return draw_string_Helvetica_10 or draw_string end
    return draw_string_Helvetica_12 or draw_string
end

local function txt(x, y, text, color, size)
    glColor4f(color[1], color[2], color[3], color[4] or 1.0)
    qrh_font(size or 12)(x, y, tostring(text or ""))
end

local function txt_right(right_x, y, text, color, size)
    local s = tostring(text or "")
    local sz = size or 12
    local tw = measure_string(s, "Helvetica_" .. tostring(sz)) or measure_string(s)
    txt(right_x - tw, y, s, color, sz)
end

-- Keep long QRH step labels inside the panel (the 460 px original had room;
-- the 430 px shell needs a guard for the dotted-line steps).
local function qrh_fit(text, max_px, size)
    local s = tostring(text or "")
    local font = "Helvetica_" .. tostring(size or 12)
    local function m(t) return measure_string(t, font) or measure_string(t) end
    if m(s) <= max_px then return s end
    while #s > 1 and m(s .. "..") > max_px do s = s:sub(1, -2) end
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
            txt(x + st.pad + 8, y - 14, "CLEAR FAILURE  (click)", {0.05, 0.05, 0.05})
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
        txt(x + st.pad + 8, y - 14, "RANDOM FAILURE (surprise me)", {0.05, 0.05, 0.05})
        qrh_rows[#qrh_rows + 1] = {
            kind = "random",
            x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
        }
    end

    -- footer: drag-safe hide button
    local by0 = bottom + 8
    local by1 = by0 + st.footer_h - 12
    bar(x + st.pad, by0, by1, w - 2 * st.pad, st.btn)
    local label = "HIDE PANEL"
    local tw = measure_string(label, "Helvetica_10") or measure_string(label)
    txt(x + (w - tw) / 2, by0 + 6, label, st.value, 10)
    qrh_footer_rect = { x0 = x + st.pad, x1 = x + w - st.pad, y0 = by0, y1 = by1 }

    -- toast
    if toast_text and (ft_sim_time or 0) < toast_until then
        local tw2 = (measure_string(toast_text, "Helvetica_12")
            or measure_string(toast_text)) + 32
        local bx = x
        local by = bottom - 30
        bar(bx, by, by + 24, tw2, {0.00, 0.00, 0.00}, 0.92)
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
