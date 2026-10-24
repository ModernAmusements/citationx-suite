-- ============================================================================
--  CESSNA CITATION X EFB  (ELECTRONIC FLIGHT BAG)
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  The Zibo-style tablet pages the Citation X was missing, in one clickable
--  panel. Three pages:
--
--    PERF   gross weight, field/pressure/density altitude, wind components,
--           V1/VR/V2, Vref, takeoff and landing distance for the current
--           runway condition.
--    CHECK  interactive checklists (before start -> shutdown) with progress
--           and a per-phase reset.
--    FUEL   route distance, cruise level, wind and taxi fuel in; trip,
--           contingency, alternate, final reserve, total and endurance out.
--
--  All numbers are ADVISORY estimates for simulation use. They are NOT AFM
--  data and must never be used for a real flight.
--
--  Commands (bindable in Settings > Joystick):
--    CitationXSuite/efb_toggle        CitationXSuite/efb_page_perf
--    CitationXSuite/efb_page_check    CitationXSuite/efb_page_fuel
--    CitationXSuite/efb_condition     CitationXSuite/efb_reset_checklist
--    CitationXSuite/efb_check_next    CitationXSuite/efb_dist_up
--    CitationXSuite/efb_dist_down     CitationXSuite/efb_alt_up
--    CitationXSuite/efb_alt_down      CitationXSuite/efb_wind_up
--    CitationXSuite/efb_wind_down     CitationXSuite/efb_taxi_up
--    CitationXSuite/efb_taxi_down
--
--  Every binding is verified against Resources/plugins/DataRefs.txt.
-- ============================================================================

-- ------------------------------------------------------------------ CONFIG --
EFB_CONFIG = {
    panel_enabled   = false,   -- hidden at load; macro "CitationX Suite: EFB panel" shows it
    panel_w         = 470,
    panel_bottom    = 60,      -- bottom-centre panel
    row_h           = 22,

    -- Performance reference data (C750, advisory only)
    mtow_kg         = 16374,
    mlw_kg          = 14424,
    rwy_condition   = 1,       -- 1 DRY, 2 WET, 3 CONTAMINATED
    condition_names = { "DRY", "WET", "CONTAM" },
    condition_to    = { 1.00, 1.25, 1.55 },
    condition_ldg   = { 1.00, 1.35, 1.70 },

    -- Fuel planner defaults
    dist_nm         = 250,
    dist_step_nm    = 10,
    cruise_alt_ft   = 35000,
    alt_step_ft     = 2000,
    wind_kt         = 0,       -- + headwind, - tailwind
    wind_step_kt    = 10,
    taxi_kg         = 150,
    taxi_step_kg    = 50,
    reserve_min     = 45,
    alternate_min   = 10,
    contingency_pct = 0.05,
}

EFB_STYLE = {
    bg        = {0.02, 0.05, 0.08, 0.62},
    header_bg = {0.03, 0.15, 0.21, 0.90},
    accent    = {0.22, 0.85, 1.00},
    label     = {0.42, 0.62, 0.70},
    value     = {0.93, 0.97, 1.00},
    ok        = {0.32, 0.95, 0.55},
    warn      = {1.00, 0.66, 0.12},
    alert     = {1.00, 0.35, 0.30},
    dim       = {0.30, 0.37, 0.42},
    tab_on    = {0.10, 0.42, 0.55, 0.95},
    tab_off   = {0.05, 0.12, 0.17, 0.85},
}

-- --------------------------------------------------------------- DATAREFS ---
dataref("efb_weight_kg",  "sim/flightmodel/weight/m_total", "readonly")
dataref("efb_fuel_kg",    "sim/flightmodel/weight/m_fuel_total", "readonly")
dataref("efb_oat_c",      "sim/cockpit2/temperature/outside_air_temp_degc", "readonly")
dataref("efb_qnh_inhg",   "sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot", "readonly")
dataref("efb_wind_kt",    "sim/cockpit2/gauges/indicators/wind_speed_kts", "readonly")
dataref("efb_wind_dir",   "sim/cockpit2/gauges/indicators/wind_heading_deg_mag", "readonly")
dataref("efb_hdg_mag",    "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", "readonly")
dataref("efb_elev_m",     "sim/flightmodel/position/elevation", "readonly")
dataref("efb_gs_ms",      "sim/flightmodel/position/groundspeed", "readonly")
dataref("efb_sim_time",   "sim/time/total_running_time_sec", "readonly")

-- ------------------------------------------------------------------ STATE ---
local EFB_PAGE_PERF  = 1
local EFB_PAGE_CHECK = 2
local EFB_PAGE_FUEL  = 3

local efb_page        = EFB_PAGE_PERF
local efb_rows        = {}
local efb_toast_text  = nil
local efb_toast_until = 0
local efb_chk_phase   = 1

local efb_chk_state = {}

local EFB_CHECKS = {
    { name = "BEFORE START", items = {
        "Battery switch ON",
        "Avionics master OFF",
        "Fuel quantity checked",
        "Parking brake SET",
        "Seats / belts / doors",
        "GPU or APU available",
        "Altimeters set",
        "Flight plan loaded",
    }},
    { name = "START", items = {
        "Beacon ON",
        "Throttles IDLE",
        "Start LEFT engine",
        "Oil pressure rising",
        "Start RIGHT engine",
        "N1 / N2 stable",
        "Generators ON",
        "Anti-ice as required",
    }},
    { name = "TAXI", items = {
        "Flight controls free",
        "Brakes checked",
        "Flight instruments alive",
        "APU OFF",
        "Taxi clearance",
        "Transponder ALT",
        "Landing lights ON",
        "Takeoff briefing done",
    }},
    { name = "TAKEOFF", items = {
        "Flaps SET",
        "Pitch trim SET",
        "V-speeds set",
        "Baro set / cross-checked",
        "Runway verified",
        "Strobes ON",
        "TOGA armed",
        "Brakes released",
    }},
    { name = "CLIMB", items = {
        "Gear UP",
        "Flaps UP",
        "Climb power SET",
        "Autopilot ON",
        "Pressurisation checked",
        "Anti-ice as required",
        "Seatbelt sign ON",
        "Altimeters cross-checked",
    }},
    { name = "APPROACH", items = {
        "ATIS / altimeter set",
        "Approach briefed",
        "Minimums SET",
        "Vref SET",
        "Speedbrakes armed",
        "Gear DOWN",
        "Flaps APPROACH",
        "Landing lights ON",
    }},
    { name = "LANDING", items = {
        "Flaps LAND",
        "Vref bugged",
        "Autopilot OFF",
        "Crosswind corrected",
        "Touchdown zone",
        "Thrust reversers",
        "Brakes as required",
        "Speedbrakes out",
    }},
    { name = "SHUTDOWN", items = {
        "Parking brake SET",
        "Avionics OFF",
        "Generators OFF",
        "Engines OFF",
        "Beacon OFF",
        "Landing lights OFF",
        "Fuel pumps OFF",
        "GPU / APU OFF",
    }},
}

-- --------------------------------------------------------------- HELPERS ----
local function efb_clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function efb_rad(deg)
    return (deg or 0) * math.pi / 180
end

local function efb_toast(text)
    efb_toast_text  = text
    efb_toast_until = (efb_sim_time or 0) + 2.5
end

local function efb_bar(x, y0, y1, w, color, alpha)
    glColor4f(color[1], color[2], color[3], alpha or 1.0)
    glRectf(x, y0, x + w, y1)
end

local function efb_txt(x, y, text, color)
    draw_string(x, y, text, color[1], color[2], color[3])
end

local function efb_txt_right(right_x, y, text, color)
    draw_string(right_x - measure_string(text), y, text, color[1], color[2], color[3])
end

local function efb_register_row(x1, y1, x2, y2, fn)
    efb_rows[#efb_rows + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, fn = fn }
end

-- ------------------------------------------------------------- COMPUTATION --
local function efb_field_alt_ft()
    return (efb_elev_m or 0) * 3.28084
end

local function efb_pressure_alt_ft()
    local qnh = efb_qnh_inhg or 29.92
    return efb_field_alt_ft() + (29.92 - qnh) * 1000.0
end

local function efb_isa_temp_c()
    return 15.0 - 1.98 * (efb_pressure_alt_ft() / 1000.0)
end

local function efb_density_alt_ft()
    local delta = (efb_oat_c or 15.0) - efb_isa_temp_c()
    return efb_pressure_alt_ft() + 118.8 * delta
end

local function efb_weight_frac()
    local w = efb_weight_kg or EFB_CONFIG.mtow_kg
    local span = EFB_CONFIG.mtow_kg - EFB_CONFIG.mlw_kg
    if span <= 0 then return 0 end
    return efb_clamp((w - EFB_CONFIG.mlw_kg) / span, 0.0, 1.0)
end

local function efb_vspeeds()
    local f = efb_weight_frac()
    local v1 = 104 + 16 * f
    return v1, v1 + 5, v1 + 14, 112 + 10 * f
end

local function efb_wind_components()
    local wind_kt  = efb_wind_kt or 0
    local wind_dir = efb_wind_dir or 0
    local rwy      = efb_hdg_mag or 0
    local delta    = efb_rad(wind_dir - rwy)
    return wind_kt * math.cos(delta), wind_kt * math.sin(delta)
end

local function efb_wind_factor(headwind)
    return efb_clamp(1.0 - 0.015 * (headwind or 0), 0.70, 1.30)
end

local function efb_takeoff_distance_m()
    local w    = efb_weight_kg or EFB_CONFIG.mtow_kg
    local frac = efb_clamp(w / EFB_CONFIG.mtow_kg, 0.5, 1.0)
    local head = efb_wind_components()
    local cond = EFB_CONFIG.condition_to[EFB_CONFIG.rwy_condition] or 1.0
    local da   = efb_density_alt_ft()
    return 1600 * frac * frac
               * (1.0 + 0.10 * (da / 1000.0))
               * efb_wind_factor(head)
               * cond
end

local function efb_landing_distance_m()
    local w    = efb_weight_kg or EFB_CONFIG.mlw_kg
    local frac = efb_clamp(w / EFB_CONFIG.mlw_kg, 0.5, 1.2)
    local head = efb_wind_components()
    local cond = EFB_CONFIG.condition_ldg[EFB_CONFIG.rwy_condition] or 1.0
    local da   = efb_density_alt_ft()
    return 1050 * frac * frac
               * (1.0 + 0.07 * (da / 1000.0))
               * efb_wind_factor(head)
               * cond
end

local function efb_fuel_plan()
    local cfg  = EFB_CONFIG
    local dist = math.max(cfg.dist_nm, 1)
    local alt  = efb_clamp(cfg.cruise_alt_ft, 5000, 45000)

    -- True airspeed and cruise fuel flow vs. level (advisory C750 model)
    local tas  = efb_clamp(420 + (alt - 35000) / 8000 * 40, 360, 470)
    local burn = efb_clamp(1150 - (alt - 35000) / 8000 * 200, 820, 1320)
    local gs   = math.max(tas - (cfg.wind_kt or 0), 120)

    local trip_h = dist / gs
    local trip   = burn * trip_h
    local cont   = trip * cfg.contingency_pct
    local altn   = burn * (cfg.alternate_min / 60)
    local resv   = burn * (cfg.reserve_min / 60)
    local total  = trip + cont + altn + resv + cfg.taxi_kg
    return {
        tas = tas, gs = gs, burn = burn, trip_h = trip_h,
        trip = trip, cont = cont, altn = altn, resv = resv,
        total = total,
    }
end

-- ------------------------------------------------------------------ ACTIONS --
function efb_toggle_panel(on)
    if on == nil then on = not EFB_CONFIG.panel_enabled end
    EFB_CONFIG.panel_enabled = (on == true)
    efb_toast("EFB: " .. (EFB_CONFIG.panel_enabled and "ON" or "OFF"))
end

function efb_set_page(page)
    efb_page = efb_clamp(page, EFB_PAGE_PERF, EFB_PAGE_FUEL)
end

function efb_cycle_condition()
    EFB_CONFIG.rwy_condition = EFB_CONFIG.rwy_condition % 3 + 1
    efb_toast("EFB RWY: " .. EFB_CONFIG.condition_names[EFB_CONFIG.rwy_condition])
end

function efb_check_next()
    efb_chk_phase = efb_chk_phase % #EFB_CHECKS + 1
    efb_toast("EFB CHECK: " .. EFB_CHECKS[efb_chk_phase].name)
end

function efb_check_prev()
    efb_chk_phase = efb_chk_phase - 1
    if efb_chk_phase < 1 then efb_chk_phase = #EFB_CHECKS end
    efb_toast("EFB CHECK: " .. EFB_CHECKS[efb_chk_phase].name)
end

function efb_reset_checklist()
    local phase = EFB_CHECKS[efb_chk_phase]
    efb_chk_state[efb_chk_phase] = {}
    for i = 1, #phase.items do efb_chk_state[efb_chk_phase][i] = false end
    efb_toast("EFB CHECK: " .. phase.name .. " RESET")
end

function efb_toggle_check_item(index)
    local phase = EFB_CHECKS[efb_chk_phase]
    if not phase or not phase.items[index] then return end
    efb_chk_state[efb_chk_phase] = efb_chk_state[efb_chk_phase] or {}
    efb_chk_state[efb_chk_phase][index] = not efb_chk_state[efb_chk_phase][index]
end

function efb_dist(delta)
    EFB_CONFIG.dist_nm = efb_clamp(EFB_CONFIG.dist_nm + delta, 10, 4000)
    efb_toast(string.format("EFB DIST: %d NM", EFB_CONFIG.dist_nm))
end

function efb_alt(delta)
    EFB_CONFIG.cruise_alt_ft = efb_clamp(EFB_CONFIG.cruise_alt_ft + delta, 5000, 45000)
    efb_toast(string.format("EFB ALT: FL%03d", math.floor(EFB_CONFIG.cruise_alt_ft / 100)))
end

function efb_wind(delta)
    EFB_CONFIG.wind_kt = efb_clamp(EFB_CONFIG.wind_kt + delta, -150, 150)
    efb_toast(string.format("EFB WIND: %+d KT", EFB_CONFIG.wind_kt))
end

function efb_taxi(delta)
    EFB_CONFIG.taxi_kg = efb_clamp(EFB_CONFIG.taxi_kg + delta, 0, 1500)
    efb_toast(string.format("EFB TAXI: %d KG", EFB_CONFIG.taxi_kg))
end

-- --------------------------------------------------------------- DRAWING ----
local function efb_draw_tabs(x, y, w)
    local labels = { "PERF", "CHECK", "FUEL" }
    local tab_w  = (w - 16) / 3
    for i = 1, 3 do
        local tx = x + 8 + (i - 1) * tab_w
        local on = (efb_page == i)
        efb_bar(tx, y - 20, y, tab_w - 4, on and EFB_STYLE.tab_on or EFB_STYLE.tab_off, 0.95)
        local tw = measure_string(labels[i])
        efb_txt(tx + (tab_w - 4 - tw) / 2, y - 15, labels[i],
            on and EFB_STYLE.accent or EFB_STYLE.label)
        efb_register_row(tx, y - 20, tx + tab_w - 4, y, function() efb_set_page(i) end)
    end
end

local function efb_row_label(x, y, w, label, value, value_color, fn)
    if fn then
        efb_bar(x + 6, y - 19, y + 1, w - 12, EFB_STYLE.tab_off, 0.55)
        efb_register_row(x + 6, y - 19, x + w - 6, y + 1, fn)
    end
    efb_txt(x + 12, y - 14, label, EFB_STYLE.label)
    efb_txt_right(x + w - 12, y - 14, value, value_color or EFB_STYLE.value)
end

local function efb_draw_perf(x, y, w)
    local head, cross = efb_wind_components()
    local v1, vr, v2, vref = efb_vspeeds()
    local to_m  = efb_takeoff_distance_m()
    local ldg_m = efb_landing_distance_m()
    local da    = efb_density_alt_ft()

    efb_row_label(x, y, w, "GROSS WEIGHT",
        string.format("%.0f KG  (%.0f LB)", efb_weight_kg or 0, (efb_weight_kg or 0) * 2.20462))
    y = y - 22
    efb_row_label(x, y, w, "FUEL ON BOARD",
        string.format("%.0f KG", efb_fuel_kg or 0))
    y = y - 22
    efb_row_label(x, y, w, "FIELD / QNH",
        string.format("%.0f FT / %.2f IN", efb_field_alt_ft(), efb_qnh_inhg or 29.92))
    y = y - 22
    efb_row_label(x, y, w, "OAT / ISA",
        string.format("%+.0f C / %+.0f C", efb_oat_c or 0, efb_isa_temp_c()))
    y = y - 22
    efb_row_label(x, y, w, "PRESSURE ALT",
        string.format("%.0f FT", efb_pressure_alt_ft()))
    y = y - 22
    local da_col = (da > 8000) and EFB_STYLE.warn or EFB_STYLE.value
    efb_row_label(x, y, w, "DENSITY ALT", string.format("%.0f FT", da), da_col)
    y = y - 22
    efb_row_label(x, y, w, "WIND  HDG / KT",
        string.format("%03.0f / %.0f   HD %+.0f  XW %+.0f",
            efb_wind_dir or 0, efb_wind_kt or 0, head, cross))
    y = y - 22
    efb_row_label(x, y, w, "V1 / VR / V2",
        string.format("%.0f / %.0f / %.0f KT", v1, vr, v2), EFB_STYLE.accent)
    y = y - 22
    efb_row_label(x, y, w, "VREF", string.format("%.0f KT", vref), EFB_STYLE.accent)
    y = y - 22
    efb_row_label(x, y, w, "TAKEOFF DIST",
        string.format("%.0f M  (%.0f FT)", to_m, to_m * 3.28084), EFB_STYLE.value)
    y = y - 22
    efb_row_label(x, y, w, "LANDING DIST",
        string.format("%.0f M  (%.0f FT)", ldg_m, ldg_m * 3.28084), EFB_STYLE.value)
    y = y - 22
    efb_row_label(x, y, w, "RUNWAY CONDITION",
        EFB_CONFIG.condition_names[EFB_CONFIG.rwy_condition], EFB_STYLE.warn,
        function() efb_cycle_condition() end)
    y = y - 22
    efb_txt(x + 12, y - 14, "ADVISORY ONLY - NOT AFM DATA", EFB_STYLE.dim)
    return y
end

local function efb_draw_check(x, y, w)
    local phase = EFB_CHECKS[efb_chk_phase]
    local state = efb_chk_state[efb_chk_phase] or {}
    local done  = 0
    for i = 1, #phase.items do if state[i] then done = done + 1 end end

    efb_row_label(x, y, w, "PHASE " .. efb_chk_phase .. " / " .. #EFB_CHECKS,
        phase.name, EFB_STYLE.accent,
        function() efb_check_next() end)
    y = y - 22
    efb_row_label(x, y, w, "PROGRESS",
        string.format("%d / %d", done, #phase.items),
        (done == #phase.items) and EFB_STYLE.ok or EFB_STYLE.value)
    y = y - 22

    for i = 1, #phase.items do
        local on  = state[i] == true
        local box_x = x + 12
        glColor4f(on and EFB_STYLE.ok[1] or EFB_STYLE.dim[1],
                  on and EFB_STYLE.ok[2] or EFB_STYLE.dim[2],
                  on and EFB_STYLE.ok[3] or EFB_STYLE.dim[3], 1.0)
        glRectf(box_x, y - 14, box_x + 8, y - 6)
        efb_txt(box_x + 14, y - 14, phase.items[i],
            on and EFB_STYLE.ok or EFB_STYLE.value)
        local item = i
        efb_register_row(x + 6, y - 19, x + w - 6, y + 1,
            function() efb_toggle_check_item(item) end)
        y = y - 22
    end

    efb_row_label(x, y, w, "NEXT PHASE", "CLICK / CMD", EFB_STYLE.label,
        function() efb_check_next() end)
    y = y - 22
    efb_row_label(x, y, w, "RESET THIS PHASE", "CLICK", EFB_STYLE.warn,
        function() efb_reset_checklist() end)
    return y - 22
end

local function efb_draw_fuel(x, y, w)
    local cfg = EFB_CONFIG
    local p   = efb_fuel_plan()

    efb_row_label(x, y, w, "DISTANCE",
        string.format("%d NM", cfg.dist_nm), EFB_STYLE.value,
        function() efb_dist(cfg.dist_step_nm) end)
    y = y - 22
    efb_row_label(x, y, w, "CRUISE LEVEL",
        string.format("FL%03d", math.floor(cfg.cruise_alt_ft / 100)), EFB_STYLE.value,
        function() efb_alt(cfg.alt_step_ft) end)
    y = y - 22
    efb_row_label(x, y, w, "WIND (+HEAD / -TAIL)",
        string.format("%+d KT", cfg.wind_kt), EFB_STYLE.value,
        function() efb_wind(cfg.wind_step_kt) end)
    y = y - 22
    efb_row_label(x, y, w, "TAXI FUEL",
        string.format("%d KG", cfg.taxi_kg), EFB_STYLE.value,
        function() efb_taxi(cfg.taxi_step_kg) end)
    y = y - 22
    efb_row_label(x, y, w, "TAS / GS",
        string.format("%.0f / %.0f KT", p.tas, p.gs))
    y = y - 22
    efb_row_label(x, y, w, "TRIP TIME / FUEL",
        string.format("%.1f H / %.0f KG", p.trip_h, p.trip))
    y = y - 22
    efb_row_label(x, y, w, "CONTINGENCY 5%", string.format("%.0f KG", p.cont))
    y = y - 22
    efb_row_label(x, y, w, "ALTERNATE 10 MIN", string.format("%.0f KG", p.altn))
    y = y - 22
    efb_row_label(x, y, w, "FINAL RESERVE 45 MIN", string.format("%.0f KG", p.resv))
    y = y - 22
    efb_row_label(x, y, w, "BLOCK FUEL", string.format("%.0f KG", p.total), EFB_STYLE.ok)
    y = y - 22

    local burn = p.burn
    local usable = math.max((efb_fuel_kg or 0) - cfg.taxi_kg - p.resv, 0)
    local endurance_min = (burn > 0) and (usable / burn * 60) or 0
    efb_row_label(x, y, w, "ENDURANCE (CURRENT FUEL)",
        string.format("%.0f MIN", endurance_min),
        (endurance_min < p.trip_h * 60 + cfg.alternate_min) and EFB_STYLE.warn or EFB_STYLE.ok)
    y = y - 22
    efb_txt(x + 12, y - 14, "CLICK A ROW TO INCREASE  -  SHIFT-CLICK DECREASES", EFB_STYLE.dim)
    return y
end

function efb_draw()
    if not EFB_CONFIG.panel_enabled then return end
    efb_rows = {}

    local cfg = EFB_CONFIG
    local w   = cfg.panel_w
    local rh  = cfg.row_h
    local sw  = SCREEN_WIDTH or 1920
    local x   = (sw - w) / 2
    local bottom = cfg.panel_bottom
    local top    = bottom + 24 + 30 + 12 * rh + 18

    XPLMSetGraphicsState(0, 0, 0, 1, 1, 0, 0)

    efb_bar(x, bottom, top, w, EFB_STYLE.bg, 0.78)
    efb_bar(x, top - 24, top, w, EFB_STYLE.header_bg, 0.92)
    efb_bar(x, top - 2, top, w, EFB_STYLE.accent)

    local page_name = ({ "PERFORMANCE", "CHECKLISTS", "FUEL PLANNING" })[efb_page]
    efb_txt(x + 10, top - 17, "CITATION X EFB", EFB_STYLE.accent)
    efb_txt_right(x + w - 10, top - 17, page_name, EFB_STYLE.label)

    local y = top - 24
    efb_draw_tabs(x, y, w)
    y = y - 30

    if efb_page == EFB_PAGE_PERF then
        efb_draw_perf(x, y, w)
    elseif efb_page == EFB_PAGE_CHECK then
        efb_draw_check(x, y, w)
    else
        efb_draw_fuel(x, y, w)
    end

    -- toast
    if efb_toast_text and (efb_sim_time or 0) < efb_toast_until then
        local tw = measure_string(efb_toast_text) + 24
        efb_bar(x + (w - tw) / 2, bottom - 24, bottom - 4, tw, EFB_STYLE.header_bg, 0.95)
        efb_txt(x + (w - tw) / 2 + 12, bottom - 18, efb_toast_text, EFB_STYLE.accent)
    end
end

-- ------------------------------------------------------------------ INPUT ---
-- Exposed for the offline harness (and harmless at runtime): the clickable
-- rectangles registered by the last draw pass.
function efb_clickable_rows()
    return efb_rows
end

function efb_mouse_click()
    if not EFB_CONFIG.panel_enabled then return end
    if MOUSE_STATUS ~= "down" then return end

    local mx = MOUSE_X or -1
    local my = MOUSE_Y or -1

    for i = 1, #efb_rows do
        local r = efb_rows[i]
        if mx >= r.x1 and mx <= r.x2 and my >= r.y1 and my <= r.y2 then
            RESUME_MOUSE_CLICK = true
            if r.fn then r.fn() end
            return
        end
    end
end

-- --------------------------------------------------- COMMANDS AND MACROS ----
create_command("CitationXSuite/efb_toggle",
    "CitationX Suite: toggle the EFB panel",
    "efb_toggle_panel()", "", "")
create_command("CitationXSuite/efb_page_perf",
    "CitationX Suite: EFB performance page",
    "efb_set_page(1)", "", "")
create_command("CitationXSuite/efb_page_check",
    "CitationX Suite: EFB checklist page",
    "efb_set_page(2)", "", "")
create_command("CitationXSuite/efb_page_fuel",
    "CitationX Suite: EFB fuel page",
    "efb_set_page(3)", "", "")
create_command("CitationXSuite/efb_condition",
    "CitationX Suite: EFB cycle runway condition",
    "efb_cycle_condition()", "", "")
create_command("CitationXSuite/efb_reset_checklist",
    "CitationX Suite: EFB reset current checklist",
    "efb_reset_checklist()", "", "")
create_command("CitationXSuite/efb_check_next",
    "CitationX Suite: EFB next checklist phase",
    "efb_check_next()", "", "")
create_command("CitationXSuite/efb_dist_up",
    "CitationX Suite: EFB distance +10 NM",
    "efb_dist(EFB_CONFIG.dist_step_nm)", "", "")
create_command("CitationXSuite/efb_dist_down",
    "CitationX Suite: EFB distance -10 NM",
    "efb_dist(-EFB_CONFIG.dist_step_nm)", "", "")
create_command("CitationXSuite/efb_alt_up",
    "CitationX Suite: EFB cruise level +2000 ft",
    "efb_alt(EFB_CONFIG.alt_step_ft)", "", "")
create_command("CitationXSuite/efb_alt_down",
    "CitationX Suite: EFB cruise level -2000 ft",
    "efb_alt(-EFB_CONFIG.alt_step_ft)", "", "")
create_command("CitationXSuite/efb_wind_up",
    "CitationX Suite: EFB headwind +10 kt",
    "efb_wind(EFB_CONFIG.wind_step_kt)", "", "")
create_command("CitationXSuite/efb_wind_down",
    "CitationX Suite: EFB headwind -10 kt",
    "efb_wind(-EFB_CONFIG.wind_step_kt)", "", "")
create_command("CitationXSuite/efb_taxi_up",
    "CitationX Suite: EFB taxi fuel +50 kg",
    "efb_taxi(EFB_CONFIG.taxi_step_kg)", "", "")
create_command("CitationXSuite/efb_taxi_down",
    "CitationX Suite: EFB taxi fuel -50 kg",
    "efb_taxi(-EFB_CONFIG.taxi_step_kg)", "", "")

add_macro("CitationX Suite: EFB panel", "efb_toggle_panel()")
add_macro("CitationX Suite: EFB performance page", "efb_set_page(1)")
add_macro("CitationX Suite: EFB checklist page", "efb_set_page(2)")
add_macro("CitationX Suite: EFB fuel page", "efb_set_page(3)")
add_macro("CitationX Suite: EFB runway condition", "efb_cycle_condition()")
add_macro("CitationX Suite: EFB reset checklist", "efb_reset_checklist()")

do_every_draw("efb_draw()")
do_on_mouse_click("efb_mouse_click()")

logMsg("Citation X EFB loaded (PERF / CHECK / FUEL)")
