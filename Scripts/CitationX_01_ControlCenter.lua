-- ============================================================================
--  CESSNA CITATION X CONTROL CENTER
--  X-Plane 12  |  FlyWithLua NG+ 2.8+ (ImGui floating window)
-- ----------------------------------------------------------------------------
--  One Apple-like window is the only suite surface shown at load. Its rows
--  open or close every other panel through the existing SUITE_MODULES mapping,
--  so nothing here duplicates a panel's state machine or binds a dataref.
--
--  Style: Neo Grotesque REGULAR (fwl_prefs.ini aliases CCBody / CCSmall),
--  square corners, and a neutral palette — no bold faces and no orange.
--  Shared primitives live in CitationX_00_ImGuiKit.lua (CXUI / cxui_*).
--
--  Prefix: CC / cc_*. No datarefs are bound here, so this script cannot
--  quarantine a panel on a bad X-Plane data path.
-- ============================================================================

CC = {
    window_w = 360,
    window_h = 440,

    panels = {
        { key = "status",     label = "SUITE HUB" },
        { key = "realism",    label = "REALISM PANEL" },
        { key = "cabin",      label = "CABIN OPS" },
        { key = "qrh",        label = "QRH TRAINER" },
        { key = "instructor", label = "FLIGHT INSTRUCTOR" },
        { key = "landperf",   label = "LANDING REPORT" },
    },
    diagnostics = {
        { key = "axmon", label = "AXIS MONITOR" },
    },
}

local cc_wnd = nil
local cc_closed = false

-- ------------------------------------------------------------ MODULE ACCESS --
-- SUITE_MODULES is created by CitationX_MasterSuite.lua, which loads after
-- this file. Resolve it at draw time, never at load time.
local function cc_find_module(key)
    if type(SUITE_MODULES) ~= "table" then return nil end
    for _, m in ipairs(SUITE_MODULES) do
        if m.key == key then return m end
    end
    return nil
end

local function cc_state(key)
    local m = cc_find_module(key)
    if not m then return "ABSENT" end
    local ok, text = pcall(m.state)
    if not ok or type(text) ~= "string" then return "ABSENT" end
    return text
end

local function cc_set_module(key, on)
    local m = cc_find_module(key)
    if m and type(m.set) == "function" then m.set(on == true) end
end

local function cc_toggle_module(key)
    local m = cc_find_module(key)
    if not m or type(m.set) ~= "function" then return end
    if m.cycle then
        m.set(true)
    else
        local on = false
        if type(m.get) == "function" then on = (m.get() == true) end
        m.set(not on)
    end
end

local function cc_run_action(key)
    if key == "flows" then
        if type(citationx_set_status) == "function" then citationx_set_status(true) end
        if type(citationx_set_flow_tab) == "function" then
            citationx_set_flow_tab("flows")
        end
    elseif key == "livery" and type(citationx_texture_next) == "function" then
        citationx_texture_next()
    end
end

-- ---------------------------------------------------------------- ROW PAINT --
local function cc_row(item)
    if cxui_row(item.label, cc_state(item.key), "cc_" .. item.key,
                nil, CXUI.label_w, CXUI.state_w) then
        cc_toggle_module(item.key)
    end
end

local function cc_action_button(item, w)
    if cxui_button(item.label .. "###cc_action_" .. item.key, w, CXUI.row_h) then
        cc_run_action(item.key)
    end
end

-- ------------------------------------------------------------------ BUILDER --
-- Called by FlyWithLua every frame while the floating window is visible.
function cc_on_build(wnd, x, y)
    local _ = wnd
    local _x = x
    local _y = y
    if PLANE_ICAO ~= "C750" then return end
    if type(imgui) ~= "table" then return end

    local style = cxui_begin_style()

    cxui_text("CITATION X")
    cxui_muted("CONTROL CENTER", "small")
    cxui_spacing()
    if type(imgui.Separator) == "function" then imgui.Separator() end
    cxui_spacing()

    cxui_section("PANELS")
    for _, item in ipairs(CC.panels) do cc_row(item) end

    cxui_spacing()
    cxui_section("DIAGNOSTICS")
    for _, item in ipairs(CC.diagnostics) do cc_row(item) end

    cxui_spacing()
    cxui_section("SHORTCUTS")
    cc_action_button({ key = "flows", label = "OPEN FLOWS" }, 150)
    if type(imgui.SameLine) == "function" then imgui.SameLine() end
    cc_action_button({ key = "livery", label = "NEXT TEXTURE" }, 150)

    cxui_spacing()
    if cxui_button("SHOW ALL###cc_show_all", 150, CXUI.row_h) then
        for _, item in ipairs(CC.panels) do cc_set_module(item.key, true) end
    end
    if type(imgui.SameLine) == "function" then imgui.SameLine() end
    if cxui_button("HIDE ALL###cc_hide_all", 150, CXUI.row_h) then
        for _, item in ipairs(CC.panels) do cc_set_module(item.key, false) end
    end

    cxui_spacing()
    cxui_muted("C750 ONLY - NO KEYBINDS", "small")

    cxui_end_style(style)
end

-- ------------------------------------------------------------ WINDOW LIFE ----
function cc_set_visible(on)
    cxui_show(cc_wnd, on)
end

function cc_aircraft_guard()
    if cc_closed then return end
    cc_set_visible(PLANE_ICAO == "C750")
end

function cc_on_close(wnd)
    local _ = wnd
    cc_wnd = nil
    cc_closed = true
end

function cc_open()
    cc_closed = false
    if cc_wnd then
        cxui_show(cc_wnd, true)
        if type(float_wnd_bring_to_front) == "function" then
            float_wnd_bring_to_front(cc_wnd)
        end
        return
    end
    local sh = tonumber(SCREEN_HIGHT) or 1440
    local y = sh - CC.window_h - 72
    if y < 24 then y = 24 end
    cc_wnd = cxui_create_window(CC.window_w, CC.window_h,
        "Citation X Control Center", "cc_on_build", "cc_on_close", 24, y)
    if cc_wnd then
        cxui_show(cc_wnd, true)
        if type(float_wnd_bring_to_front) == "function" then
            float_wnd_bring_to_front(cc_wnd)
        end
    end
end

cc_open()
do_often("cc_aircraft_guard()")

create_command("CitationXSuite/control_center",
    "Citation X Suite: show the Control Center", "cc_open()", "", "")
add_macro("Citation X Control Center: show", "cc_open()")
