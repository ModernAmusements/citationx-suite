-- ============================================================================
--  CESSNA CITATION X CONTROL CENTER
--  X-Plane 12  |  FlyWithLua NG+ 2.8+ (ImGui floating window)
-- ----------------------------------------------------------------------------
--  One Apple-like window replaces the old "open five panels at startup" layout.
--  It is the only suite surface shown at load and it owns the on/off state of
--  every other panel. The legacy Helvetica panels stay exactly as they are;
--  this window simply calls their existing toggle functions, so nothing here
--  reads a dataref, writes the sim or duplicates a panel's state machine.
--
--  Type: Neo Grotesque, loaded from FlyWithLua's Custom_Fonts folder through
--  `fwl_prefs.ini` aliases (CCTitle / CCHeading / CCBody / CCSmall). FlyWithLua
--  can only use custom TTF faces inside ImGui floating windows, which is why
--  this one surface uses `imgui` while the other panels keep `draw_string`.
--
--  Prefix: CC / cc_*. No datarefs are bound here, so this script cannot
--  quarantine a panel on a bad X-Plane data path.
-- ============================================================================

CC = {
    window_w = 360,
    window_h = 456,
    margin   = 18,
    row_h    = 30,
    label_w  = 204,
    state_w  = 104,

    font_title    = "CCTitle",
    font_heading  = "CCHeading",
    font_body     = "CCBody",
    font_small    = "CCSmall",

    -- 0xAABBGGRR, ImGui's packed colour format (FlyWithLua demo:
    -- 0xFF0000FF = red, 0xFFFF0000 = blue). Each value below is an Apple
    -- system colour written as 0xFFBBGGRR.
    color = {
        window    = 0xFF1E1C1C,  -- #1C1C1E, translucency comes from the window
        border    = 0xFF3C3A3A,  -- #3A3A3C
        text      = 0xFFF7F5F5,  -- #F5F5F7
        muted     = 0xFFA6A1A1,  -- #A1A1A6
        on        = 0xFF58D130,  -- iOS green #30D158
        wait      = 0xFF0A9FFF,  -- amber #FF9F0A: ABSENT / NO FILE / MENU
        button    = 0xFF2E2C2C,  -- #2C2C2E
        hover     = 0xFF3C3A3A,  -- #3A3A3C
        active    = 0xFF4A4848,  -- #48484A
        separator = 0xFF4A4848,  -- #48484A
    },

    -- Every drawable suite panel, in the order a pilot would work through
    -- them. `landperf` reports SHOWN/HIDDEN rather than ON/OFF; both are
    -- handled by the shared SUITE_MODULES mapping in CitationX_MasterSuite.
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
local cc_font_names = nil

-- --------------------------------------------------------------- IMGUI HELP --
-- ImGui enum tables are present in the sim. The numeric fallbacks are the
-- 1.92 values and keep the harnesses (which have no enum tables) working.
local COLOR_FALLBACK = {
    Text = 0, WindowBg = 2, Border = 5, FrameBg = 7,
    Button = 21, ButtonHovered = 22, ButtonActive = 23, Separator = 27,
}
local VAR_FALLBACK = {
    WindowPadding = 2, WindowRounding = 3, ChildRounding = 7,
    FramePadding = 11, FrameRounding = 12, ItemSpacing = 14,
}

local function cc_enum(kind, name)
    local group = (type(imgui) == "table" and imgui.constant)
        and imgui.constant[kind] or nil
    if type(group) == "table" and group[name] ~= nil then return group[name] end
    return (kind == "Col" and COLOR_FALLBACK or VAR_FALLBACK)[name]
end

local function cc_push_color(name, rgba)
    local id = cc_enum("Col", name)
    if id ~= nil and type(imgui.PushStyleColor) == "function" then
        imgui.PushStyleColor(id, rgba)
        return true
    end
    return false
end

local function cc_pop_color(count)
    for _ = 1, (count or 1) do
        if type(imgui.PopStyleColor) == "function" then imgui.PopStyleColor() end
    end
end

local function cc_push_var(name, a, b)
    local id = cc_enum("StyleVar", name)
    if id == nil then return false end
    if b ~= nil then
        if type(imgui.PushStyleVar_2) == "function" then
            imgui.PushStyleVar_2(id, a, b)
            return true
        end
    elseif type(imgui.PushStyleVar) == "function" then
        imgui.PushStyleVar(id, a)
        return true
    end
    return false
end

local function cc_pop_var(count)
    for _ = 1, (count or 1) do
        if type(imgui.PopStyleVar) == "function" then imgui.PopStyleVar() end
    end
end

-- The named font registry is optional: if the font list is not exposed, assume
-- the aliases exist (the documented default) and let FlyWithLua's own fallback
-- handle a missing face. Never push a font without popping it again.
local function cc_font_available(name)
    if cc_font_names == nil then
        cc_font_names = {}
        local getter = nil
        if type(imgui) == "table" then
            getter = imgui.get_font_list or imgui.GetFontList
        end
        if type(getter) == "function" then
            local ok, list = pcall(getter)
            if ok and type(list) == "table" then
                for _, n in ipairs(list) do cc_font_names[tostring(n):lower()] = true end
            end
        end
    end
    if next(cc_font_names) == nil then return true end
    return cc_font_names[tostring(name):lower()] == true
end

local function cc_push_font(name)
    if not cc_font_available(name) then return false end
    local ok = pcall(imgui.PushFont, name)
    return ok
end

local function cc_pop_font(pushed)
    if pushed and type(imgui.PopFont) == "function" then imgui.PopFont() end
end

local function cc_text(text, rgba)
    if type(imgui.TextUnformatted) ~= "function" then return end
    local pushed = cc_push_color("Text", rgba or CC.color.text)
    imgui.TextUnformatted(tostring(text))
    cc_pop_color(pushed and 1 or 0)
end

local function cc_section(label)
    local pushed = cc_push_font(CC.font_small)
    cc_text(label, CC.color.muted)
    cc_pop_font(pushed)
    if type(imgui.Separator) == "function" then imgui.Separator() end
    if type(imgui.Spacing) == "function" then imgui.Spacing() end
end

-- ------------------------------------------------------------ MODULE ACCESS --
-- SUITE_MODULES is created by CitationX_MasterSuite.lua, which loads after
-- this file. Everything here resolves it at draw time, never at load time.
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

local function cc_state_color(text)
    if text == "ON" or text == "ACTIVE" or text == "ARMED"
       or text == "REC" or text == "SHOWN" then
        return CC.color.on
    end
    if text == "OFF" or text == "HIDDEN" then return CC.color.text end
    return CC.color.wait
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
    if type(imgui.Button) ~= "function" then return end
    local state = cc_state(item.key)
    local clicked = false

    if imgui.Button(item.label .. "###cc_" .. item.key, CC.label_w, CC.row_h) then
        clicked = true
    end
    if type(imgui.SameLine) == "function" then imgui.SameLine() end

    local text_pushed = cc_push_color("Text", cc_state_color(state))
    if imgui.Button(state .. "###cc_" .. item.key .. "_state", CC.state_w, CC.row_h) then
        clicked = true
    end
    cc_pop_color(text_pushed and 1 or 0)

    if clicked then cc_toggle_module(item.key) end
end

local function cc_action_button(item, half_w)
    if type(imgui.Button) ~= "function" then return end
    if imgui.Button(item.label .. "###cc_action_" .. item.key, half_w, CC.row_h) then
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

    local vars = 0
    if cc_push_var("WindowPadding", CC.margin, 14) then vars = vars + 1 end
    if cc_push_var("FramePadding", 12, 7) then vars = vars + 1 end
    if cc_push_var("ItemSpacing", 8, 6) then vars = vars + 1 end
    if cc_push_var("FrameRounding", 10) then vars = vars + 1 end
    if cc_push_var("WindowRounding", 14) then vars = vars + 1 end
    local colors = 0
    if cc_push_color("WindowBg", CC.color.window) then colors = colors + 1 end
    if cc_push_color("Border", CC.color.border) then colors = colors + 1 end
    if cc_push_color("Button", CC.color.button) then colors = colors + 1 end
    if cc_push_color("ButtonHovered", CC.color.hover) then colors = colors + 1 end
    if cc_push_color("ButtonActive", CC.color.active) then colors = colors + 1 end
    if cc_push_color("Separator", CC.color.separator) then colors = colors + 1 end

    local title = cc_push_font(CC.font_title)
    cc_text("CITATION X", CC.color.text)
    cc_pop_font(title)

    local heading = cc_push_font(CC.font_heading)
    cc_text("CONTROL CENTER", CC.color.muted)
    cc_pop_font(heading)
    if type(imgui.Spacing) == "function" then imgui.Spacing() end
    if type(imgui.Separator) == "function" then imgui.Separator() end
    if type(imgui.Spacing) == "function" then imgui.Spacing() end

    local body = cc_push_font(CC.font_body)

    cc_section("PANELS")
    for _, item in ipairs(CC.panels) do
        cc_row(item)
    end

    if type(imgui.Spacing) == "function" then imgui.Spacing() end
    cc_section("DIAGNOSTICS")
    for _, item in ipairs(CC.diagnostics) do
        cc_row(item)
    end

    if type(imgui.Spacing) == "function" then imgui.Spacing() end
    cc_section("SHORTCUTS")
    cc_action_button({ key = "flows", label = "OPEN FLOWS" }, 150)
    if type(imgui.SameLine) == "function" then imgui.SameLine() end
    cc_action_button({ key = "livery", label = "NEXT TEXTURE" }, 150)

    if type(imgui.Spacing) == "function" then imgui.Spacing() end
    if type(imgui.Button) == "function" then
        if imgui.Button("SHOW ALL###cc_show_all", 150, CC.row_h) then
            for _, item in ipairs(CC.panels) do cc_set_module(item.key, true) end
        end
        if type(imgui.SameLine) == "function" then imgui.SameLine() end
        if imgui.Button("HIDE ALL###cc_hide_all", 150, CC.row_h) then
            for _, item in ipairs(CC.panels) do cc_set_module(item.key, false) end
        end
    end
    cc_pop_font(body)

    if type(imgui.Spacing) == "function" then imgui.Spacing() end
    local small = cc_push_font(CC.font_small)
    cc_text("C750 ONLY - NO KEYBINDS", CC.color.muted)
    cc_pop_font(small)

    cc_pop_color(colors)
    cc_pop_var(vars)
end

-- ------------------------------------------------------------ WINDOW LIFE ----
local function cc_position_window()
    if type(float_wnd_set_position) ~= "function" then return end
    local sh = tonumber(SCREEN_HIGHT) or 1440
    local y = sh - CC.window_h - 72
    if y < 24 then y = 24 end
    float_wnd_set_position(cc_wnd, 24, y)
end

function cc_set_visible(on)
    if not cc_wnd then return end
    if type(float_wnd_set_visible) == "function" then
        float_wnd_set_visible(cc_wnd, on == true)
    end
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

local function cc_create_window()
    if SUPPORTS_FLOATING_WINDOWS == false then
        logMsg("Citation X Control Center: this FlyWithLua has no floating windows")
        return
    end
    if cc_wnd then return end

    cc_wnd = float_wnd_create(CC.window_w, CC.window_h, 1, true)
    if not cc_wnd then return end

    if type(float_wnd_set_title) == "function" then
        float_wnd_set_title(cc_wnd, "Citation X Control Center")
    end
    if type(float_wnd_set_imgui_builder) == "function" then
        float_wnd_set_imgui_builder(cc_wnd, "cc_on_build")
    end
    if type(float_wnd_set_onclose) == "function" then
        float_wnd_set_onclose(cc_wnd, "cc_on_close")
    end
    cc_position_window()
    cc_aircraft_guard()
end

function cc_open()
    cc_closed = false
    if cc_wnd then
        cc_set_visible(true)
        if type(float_wnd_bring_to_front) == "function" then
            float_wnd_bring_to_front(cc_wnd)
        end
        return
    end
    cc_create_window()
    if cc_wnd and type(float_wnd_bring_to_front) == "function" then
        float_wnd_bring_to_front(cc_wnd)
    end
end

cc_create_window()
do_often("cc_aircraft_guard()")

create_command("CitationXSuite/control_center",
    "Citation X Suite: show the Control Center", "cc_open()", "", "")
add_macro("Citation X Control Center: show", "cc_open()")
