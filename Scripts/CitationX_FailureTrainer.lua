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
    panel_enabled    = false,   -- hidden at load; macro "Citation X QRH: toggle panel" shows it
    panel_x          = 28,     -- panel anchor, bottom-left corner
    panel_y          = 60,
    panel_w          = 460,
    require_c750     = true,   -- only inject failures when flying the C750
    row_h            = 22,
}

-- Glass-panel palette, matching the Citation X Master Suite style.
ST = {
    bg         = {0.02, 0.05, 0.08, 0.62},
    header_bg  = {0.03, 0.15, 0.21, 0.90},
    header_act = {0.35, 0.05, 0.05, 0.92},
    accent     = {0.22, 0.85, 1.00},
    subhdr     = {0.36, 0.68, 0.78},
    label      = {0.42, 0.62, 0.70},
    value      = {0.93, 0.97, 1.00},
    ok         = {0.32, 0.95, 0.55},
    warn       = {1.00, 0.66, 0.12},
    alert      = {1.00, 0.30, 0.28},
    dim        = {0.30, 0.37, 0.42},
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
    glColor4f(color[1], color[2], color[3], alpha or 1.0)
    glRectf(x, y0, x + w, y1)
end

local function txt(x, y, text, color)
    draw_string(x, y, text, color[1], color[2], color[3])
end

local function txt_right(right_x, y, text, color)
    draw_string(right_x - measure_string(text), y, text, color[1], color[2], color[3])
end

function qrh_draw()
    if not TRAINER_CONFIG.panel_enabled then return end
    qrh_rows = {}

    local cfg = TRAINER_CONFIG
    local w   = cfg.panel_w
    local rh  = cfg.row_h
    local x   = cfg.panel_x
    local bottom = cfg.panel_y

    -- measure panel height from content
    local h
    if active then
        h = 24 + 30 + (#active.steps) * rh + 20 + 12
            + (proc_done and (rh + 20) or 0)
    else
        h = 24 + 16 + (#SCENARIOS + 1) * rh + 12
    end
    local top = bottom + h

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    -- body background, then header strip on top
    bar(x, bottom, top, w, ST.bg, 0.75)
    bar(x, top - 24, top, w, active and ST.header_act or ST.header_bg, 0.92)
    bar(x, top - 2, top, w, active and ST.alert or ST.accent)
    if active then
        txt(x + 10, top - 17, "QRH  " .. active.title, ST.alert)
    else
        txt(x + 10, top - 17, "FAILURE TRAINER - SELECT SCENARIO", ST.accent)
    end

    local y = top - 24

    if active then
        -- condition line
        txt(x + 10, y - 13, active.condition, ST.warn)
        y = y - 30

        for i, step in ipairs(active.steps) do
            local done = step_done[i]
            local col
            if step.advisory then
                col = ST.dim
            elseif done then
                col = ST.ok
            else
                col = ST.value
            end

            -- check box
            if step.advisory then
                txt(x + 12, y - 14, "~", ST.dim)
            elseif done then
                txt(x + 12, y - 14, "X", ST.ok)
            else
                glColor4f(ST.dim[1], ST.dim[2], ST.dim[3], 1.0)
                glRectf(x + 11, y - 14, x + 20, y - 5)
            end

            txt(x + 30, y - 14, string.format("%d.", i), ST.label)
            txt(x + 50, y - 14, step.label, col)

            qrh_rows[#qrh_rows + 1] = {
                kind = "step", step = step,
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
            y = y - rh
        end

        if proc_done then
            y = y - 8
            txt(x + 12, y - 14, "PROCEDURE COMPLETE", ST.ok)
            y = y - rh
            bar(x + 8, y - rh + 8, y + 5, w - 16, ST.alert, 0.80)
            txt(x + 16, y - 14, "CLEAR FAILURE  (click)", {0.05, 0.05, 0.05})
            qrh_rows[#qrh_rows + 1] = {
                kind = "clear",
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
        else
            y = y - 6
            txt(x + 12, y - 14, "Fly the switches - steps self-check.", ST.dim)
        end
    else
        y = y - 16
        for _, sc in ipairs(SCENARIOS) do
            local col = (ft_on_ground or 0) == 1 and ST.value or ST.warn
            glColor4f(ST.accent[1], ST.accent[2], ST.accent[3], 0.8)
            glRectf(x + 10, y - 13, x + 16, y - 6)
            txt(x + 26, y - 16, sc.title, col)
            txt_right(x + w - 10, y - 16, "INJECT", ST.dim)

            qrh_rows[#qrh_rows + 1] = {
                kind = "scenario", sc = sc,
                x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
            }
            y = y - rh
        end
        -- random row
        bar(x + 8, y - rh + 8, y + 5, w - 16, ST.warn, 0.75)
        txt(x + 16, y - 16, "RANDOM FAILURE (surprise me)", {0.05, 0.05, 0.05})
        qrh_rows[#qrh_rows + 1] = {
            kind = "random",
            x0 = x, x1 = x + w, y0 = y - rh + 4, y1 = y + 4,
        }
    end

    -- toast
    if toast_text and (ft_sim_time or 0) < toast_until then
        local tw = measure_string(toast_text) + 32
        local bx = x
        local by = bottom - 34
        bar(bx, by, by + 24, tw, {0.02, 0.06, 0.09}, 0.85)
        bar(bx, by, by + 24, 4, ST.accent)
        txt(bx + 16, by + 7, toast_text, ST.value)
    end
end

-- --------------------------------------------------------------- MOUSE -----
function qrh_mouse_click()
    if MOUSE_STATUS ~= "down" then return end
    local mx, my = MOUSE_X or -1, MOUSE_Y or -1
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
