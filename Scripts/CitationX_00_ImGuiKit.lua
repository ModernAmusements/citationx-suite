-- ============================================================================
--  CESSNA CITATION X SUITE — SHARED ImGui KIT
--  X-Plane 12  |  FlyWithLua NG+ 2.8+ (ImGui floating windows)
-- ----------------------------------------------------------------------------
--  Loads after CitationX_00_Core.lua and before every panel. Owns the single
--  copy of the Apple-like ImGui palette and the small set of primitives the
--  Control Center and the converted panels share.
--
--  Visual rules (2026-11-22 request):
--    * Neo Grotesque REGULAR only — no bold faces, no title/heading aliases.
--    * Square corners — FrameRounding / WindowRounding / ChildRounding = 0.
--    * No orange anywhere — green means ON, blue means ACTIVE, grey means off.
--    * Colours are ImGui's 0xAABBGGRR (FlyWithLua demo: 0xFF0000FF = red).
--
--  Prefix: CXUI / cxui_*. No datarefs, commands, windows or callbacks here, so
--  this file cannot quarantine a panel. Every `imgui` call resolves at draw
--  time and is guarded, which keeps the offline harnesses working.
-- ============================================================================

CXUI = {
    color = {
        window    = 0xFF1E1C1C,  -- #1C1C1E window field
        surface   = 0xFF2E2C2C,  -- #2C2C2E grouped row / button
        surface2  = 0xFF262424,  -- #242426 alternating row
        text      = 0xFFF7F5F5,  -- #F5F5F7 primary ink
        muted     = 0xFFA6A1A1,  -- #A1A1A6 secondary ink
        dim       = 0xFF7C7C80,  -- #7C7C80 tertiary ink
        on        = 0xFF58D130,  -- #30D158 iOS green
        active    = 0xFFFF840A,  -- #0A84FF iOS blue (ACTIVE / selected)
        button    = 0xFF2E2C2C,  -- #2C2C2E
        hover     = 0xFF3C3A3A,  -- #3A3A3C
        pressed   = 0xFF4A4848,  -- #48484A
        separator = 0xFF3C3A3A,  -- #3A3A3C hairline
        track     = 0xFF3A3A3C,  -- #3A3A3C gauge trough
    },

    -- Both aliases point at the regular .ttf in Custom_Fonts. There is no bold
    -- alias by design; a larger regular face is used where a title is needed.
    font = { body = "CCBody", small = "CCSmall" },

    margin  = 16,
    row_h   = 28,
    label_w = 210,
    state_w = 92,
}

-- --------------------------------------------------------------- IMGUI ENUM --
-- The sim exposes imgui.constant; the numeric 1.92 values below are the mock
-- fallback so the harnesses can draw without the plugin.
local COLOR_FALLBACK = {
    Text = 0, TextDisabled = 1, WindowBg = 2, ChildBg = 3, PopupBg = 4,
    Border = 5, FrameBg = 7, FrameBgHovered = 8, FrameBgActive = 9,
    Button = 21, ButtonHovered = 22, ButtonActive = 23, Separator = 27,
}
local VAR_FALLBACK = {
    WindowPadding = 2, WindowRounding = 3, ChildRounding = 7,
    FramePadding = 11, FrameRounding = 12, ItemSpacing = 14,
    ScrollbarRounding = 17, GrabRounding = 18, TabRounding = 21,
}

local function cxui_enum(kind, name)
    local group = (type(imgui) == "table" and imgui.constant)
        and imgui.constant[kind] or nil
    if type(group) == "table" and group[name] ~= nil then return group[name] end
    return (kind == "Col" and COLOR_FALLBACK or VAR_FALLBACK)[name]
end

function cxui_push_color(name, col)
    local id = cxui_enum("Col", name)
    if id ~= nil and type(imgui.PushStyleColor) == "function" then
        imgui.PushStyleColor(id, col)
        return true
    end
    return false
end

function cxui_pop_color(count)
    for _ = 1, (count or 1) do
        if type(imgui.PopStyleColor) == "function" then imgui.PopStyleColor() end
    end
end

function cxui_push_var(name, a, b)
    local id = cxui_enum("StyleVar", name)
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

function cxui_pop_var(count)
    for _ = 1, (count or 1) do
        if type(imgui.PopStyleVar) == "function" then imgui.PopStyleVar() end
    end
end

-- ------------------------------------------------------------- FONT HANDLING --
local font_names = nil

local function cxui_font_list()
    if font_names ~= nil then return font_names end
    font_names = {}
    local getter = nil
    if type(imgui) == "table" then getter = imgui.get_font_list or imgui.GetFontList end
    if type(getter) == "function" then
        local ok, list = pcall(getter)
        if ok and type(list) == "table" then
            for _, n in ipairs(list) do font_names[tostring(n):lower()] = true end
        end
    end
    return font_names
end

function cxui_push_font(name)
    -- If the atlas is not queryable, trust the alias and let FlyWithLua fall
    -- back. If it is queryable, never push an alias that is not loaded.
    local names = cxui_font_list()
    if next(names) ~= nil and names[tostring(name):lower()] ~= true then
        return false
    end
    local ok = pcall(imgui.PushFont, name)
    return ok
end

function cxui_pop_font(pushed)
    if pushed and type(imgui.PopFont) == "function" then imgui.PopFont() end
end

-- ------------------------------------------------------------------- TEXT ----
-- kind: "small" (12 px) or anything else (15 px). Both are regular weight.
function cxui_text(text, kind, col)
    if type(imgui.TextUnformatted) ~= "function" then return end
    local pushed = cxui_push_color("Text", col or CXUI.color.text)
    local font = cxui_push_font(kind == "small" and CXUI.font.small or CXUI.font.body)
    imgui.TextUnformatted(tostring(text or ""))
    cxui_pop_font(font)
    cxui_pop_color(pushed and 1 or 0)
end

function cxui_muted(text, kind)
    cxui_text(text, kind, CXUI.color.muted)
end

-- Map the suite's live state strings to the neutral palette. There is no
-- amber/orange branch: absent or inactive states are simply grey.
function cxui_status_color(state)
    if state == "ON" or state == "ACTIVE" or state == "ARMED"
       or state == "REC" or state == "SHOWN" or state == "DONE" then
        return CXUI.color.on
    end
    if state == "OFF" or state == "HIDDEN" or state == "IDLE" then
        return CXUI.color.muted
    end
    return CXUI.color.dim
end

-- ---------------------------------------------------------------- BUTTONS ----
-- label must include a unique "###id" so ImGui does not merge same-named rows.
function cxui_button(label, w, h, col)
    if type(imgui.Button) ~= "function" then return false end
    local pushed = col and cxui_push_color("Button", col) or false
    local clicked = imgui.Button(label, w, h)
    cxui_pop_color(pushed and 1 or 0)
    return clicked == true
end

-- A clickable label + coloured state pill on one line (the hub's row pattern).
function cxui_row(label, state, id, w, label_w, state_w)
    local lw = label_w or CXUI.label_w
    local sw = state_w or CXUI.state_w
    local clicked = cxui_button(label .. "###" .. id, lw, CXUI.row_h)
    if type(imgui.SameLine) == "function" then imgui.SameLine() end
    local pushed = cxui_push_color("Text", cxui_status_color(state))
    if cxui_button(tostring(state) .. "###" .. id .. "_state", sw, CXUI.row_h) then
        clicked = true
    end
    cxui_pop_color(pushed and 1 or 0)
    return clicked
end

function cxui_section(label)
    cxui_muted(label, "small")
    if type(imgui.Separator) == "function" then imgui.Separator() end
    cxui_spacing()
end

function cxui_spacing()
    if type(imgui.Spacing) == "function" then imgui.Spacing() end
end

function cxui_progress(fraction, w)
    if type(imgui.ProgressBar) ~= "function" then return end
    local f = math.max(0, math.min(1, tonumber(fraction) or 0))
    imgui.ProgressBar(f, w or 240, 14, "")
end

-- ----------------------------------------------------------- WINDOW STYLE ----
-- Call at the top of a builder; pass the returned token to cxui_end_style at
-- the bottom. Every push is counted so the stack always balances.
function cxui_begin_style()
    local s = { colors = 0, vars = 0 }
    local vars = {
        { "WindowPadding", CXUI.margin, 12 },
        { "FramePadding", 12, 7 },
        { "ItemSpacing", 8, 6 },
        { "FrameRounding", 0 },
        { "WindowRounding", 0 },
        { "ChildRounding", 0 },
        { "ScrollbarRounding", 0 },
        { "GrabRounding", 0 },
        { "TabRounding", 0 },
    }
    for _, v in ipairs(vars) do
        if cxui_push_var(v[1], v[2], v[3]) then s.vars = s.vars + 1 end
    end
    local colors = {
        { "WindowBg", CXUI.color.window },
        { "Border", CXUI.color.separator },
        { "Button", CXUI.color.button },
        { "ButtonHovered", CXUI.color.hover },
        { "ButtonActive", CXUI.color.pressed },
        { "Separator", CXUI.color.separator },
        { "FrameBg", CXUI.color.surface },
        { "FrameBgHovered", CXUI.color.hover },
        { "FrameBgActive", CXUI.color.pressed },
    }
    for _, c in ipairs(colors) do
        if cxui_push_color(c[1], c[2]) then s.colors = s.colors + 1 end
    end
    return s
end

function cxui_end_style(s)
    if type(s) ~= "table" then return end
    cxui_pop_color(s.colors)
    cxui_pop_var(s.vars)
end

-- -------------------------------------------------------- WINDOW LIFECYCLE ----
-- Creates an ImGui floating window and returns it. The builder/onclose names
-- are global function names, exactly as FlyWithLua expects.
function cxui_create_window(w, h, title, builder, onclose, x, y)
    if SUPPORTS_FLOATING_WINDOWS == false then
        logMsg("Citation X Suite: this FlyWithLua has no floating windows")
        return nil
    end
    local wnd = float_wnd_create(w, h, 1, true)
    if not wnd then return nil end
    if type(float_wnd_set_title) == "function" then
        float_wnd_set_title(wnd, title)
    end
    if type(float_wnd_set_imgui_builder) == "function" then
        float_wnd_set_imgui_builder(wnd, builder)
    end
    if type(float_wnd_set_onclose) == "function" then
        float_wnd_set_onclose(wnd, onclose)
    end
    if x ~= nil and y ~= nil and type(float_wnd_set_position) == "function" then
        float_wnd_set_position(wnd, x, y)
    end
    return wnd
end

function cxui_show(wnd, on)
    if not wnd or type(float_wnd_set_visible) ~= "function" then return end
    float_wnd_set_visible(wnd, on == true and 1 or 0)
end
