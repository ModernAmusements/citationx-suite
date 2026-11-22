--[[
  fwl_imgui_mock.lua — shared FlyWithLua + ImGui test harness.

  Loaded with dofile() by the ImGui panel smoke tests. Sets up the globals a
  FlyWithLua script expects, records every ImGui call, and offers small helpers
  for driving a builder and asserting the Apple-style rules (square corners,
  regular fonts only, no orange, balanced stacks).

  Usage:
    local M = dofile("tests/fwl_imgui_mock.lua")
    M.setup({ aircraft = "C750" })
    M.load("Scripts/CitationX_00_Core.lua")
    M.load("Scripts/CitationX_00_ImGuiKit.lua")
    M.load("Scripts/CitationX_01_ControlCenter.lua")
    M.reset_capture()
    M.build("cc_on_build")
    M.check(M.has_button("SUITE HUB###cc_status"), "hub row is exposed")
    M.check_stacks_balanced()
--]]

local M = {}

M.windows = {}
M.buttons = {}
M.text = {}
M.vars = {}
M.colors = {}
M.fonts = {}
M.commands = {}
M.macros = {}
M.logs = {}
M.frames = {}
M.draws = {}
M.oftens = {}
M.clicks = {}
M.push_color, M.pop_color = 0, 0
M.push_var, M.pop_var = 0, 0
M.push_font, M.pop_font = 0, 0
M.font_stack = {}
M.check_target = nil
M.click_target = nil
M.fails, M.checks = 0, 0

-- ------------------------------------------------------------------ setup ----
function M.setup(opts)
  opts = opts or {}
  SCREEN_WIDTH = opts.width or 2560
  SCREEN_HIGHT = opts.height or 1440
  PLANE_ICAO = opts.aircraft or "C750"
  PLANE_TAILNUMBER = opts.tail or "N750XP"
  SUPPORTS_FLOATING_WINDOWS = true
  VKEY, CKEY = 0, ""
  MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, 0, "up"
  MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = 0, 0
  SCRIPT_DIRECTORY = "./Scripts/"
  PLUGIN_MAIN_DIRECTORY = "./"

  M.windows, M.commands, M.macros = {}, {}, {}
  M.logs, M.frames, M.draws, M.oftens, M.clicks = {}, {}, {}, {}, {}
  M.fails, M.checks = 0, 0
  M.reset_capture()

  function dataref(name)
    _G[name] = 0
    return _G[name]
  end
  function dataref_table()
    return setmetatable({}, { __index = function() return 0 end })
  end
  function get() return 0 end
  function set() end
  function logMsg(s) M.logs[#M.logs + 1] = tostring(s) end
  function create_command(name, desc, act, on, off)
    M.commands[#M.commands + 1] = { name = name, desc = desc, act = act, on = on, off = off }
    return { name = name }
  end
  function add_macro(name) M.macros[#M.macros + 1] = name end
  function do_every_frame(f) M.frames[#M.frames + 1] = f end
  function do_every_draw(f) M.draws[#M.draws + 1] = f end
  function do_often(f) M.oftens[#M.oftens + 1] = f end
  function do_on_mouse_click(f) M.clicks[#M.clicks + 1] = f end
  function do_every_second() end
  function do_on_exit() end
  function do_on_mouse_wheel() end

  function float_wnd_create(w, h, decoration, use_imgui)
    local wnd = { w = w, h = h, decoration = decoration, imgui = use_imgui, visible = nil }
    M.windows[#M.windows + 1] = wnd
    return wnd
  end
  function float_wnd_set_title(wnd, title) wnd.title = title end
  function float_wnd_set_position(wnd, x, y) wnd.x, wnd.y = x, y end
  function float_wnd_set_imgui_builder(wnd, name) wnd.builder = name end
  function float_wnd_set_onclose(wnd, name) wnd.onclose = name end
  function float_wnd_set_ondraw(wnd, name) wnd.ondraw = name end
  function float_wnd_set_visible(wnd, on) wnd.visible = on end
  function float_wnd_bring_to_front(wnd) wnd.front = true end
  function float_wnd_destroy() end
  function float_wnd_get_dimensions(wnd) return wnd.w, wnd.h end
  function float_wnd_get_geometry(wnd)
    return wnd.x or 0, wnd.y or 0, (wnd.x or 0) + (wnd.w or 0), (wnd.y or 0) - (wnd.h or 0)
  end
  function float_wnd_set_geometry(wnd, l, t, r, b) wnd.x, wnd.y = l, t end
  function float_wnd_set_resizing_limits() end

  -- Minimal XPLM stubs (some scripts bind datarefs through the raw API when
  -- another script already owns them writable).
  XPLMFindDataRef = XPLMFindDataRef or function() return nil end
  XPLMGetDataf = XPLMGetDataf or function() return 0 end
  XPLMGetDatai = XPLMGetDatai or function() return 0 end
  XPLMSetDataf = XPLMSetDataf or function() end
  XPLMSetDatai = XPLMSetDatai or function() end
  XPLMSetGraphicsState = XPLMSetGraphicsState or function() end
  XPLMDrawString = XPLMDrawString or function() end

  imgui = {
    constant = {
      Col = {
        Text = 0, TextDisabled = 1, WindowBg = 2, ChildBg = 3, PopupBg = 4,
        Border = 5, FrameBg = 7, FrameBgHovered = 8, FrameBgActive = 9,
        Button = 21, ButtonHovered = 22, ButtonActive = 23, Separator = 27,
      },
      StyleVar = {
        WindowPadding = 2, WindowRounding = 3, ChildRounding = 7,
        FramePadding = 11, FrameRounding = 12, ItemSpacing = 14,
        ScrollbarRounding = 17, GrabRounding = 18, TabRounding = 21,
      },
    },
  }
  function imgui.get_font_list() return { "CCBody", "CCSmall" } end
  function imgui.PushStyleColor(id, col)
    M.push_color = M.push_color + 1
    M.colors[id] = col
  end
  function imgui.PopStyleColor() M.pop_color = M.pop_color + 1 end
  function imgui.PushStyleVar(id, v)
    M.push_var = M.push_var + 1
    M.vars[id] = v
  end
  function imgui.PushStyleVar_2(id, a, b)
    M.push_var = M.push_var + 1
    M.vars[id] = a
  end
  function imgui.PopStyleVar() M.pop_var = M.pop_var + 1 end
  function imgui.PushFont(name)
    M.push_font = M.push_font + 1
    M.fonts[name] = true
    M.font_stack[#M.font_stack + 1] = name
  end
  function imgui.PopFont()
    M.pop_font = M.pop_font + 1
    M.font_stack[#M.font_stack] = nil
  end
  function imgui.TextUnformatted(t) M.text[#M.text + 1] = tostring(t) end
  function imgui.Text(t) M.text[#M.text + 1] = tostring(t) end
  function imgui.TextColored(_, t) M.text[#M.text + 1] = tostring(t) end
  function imgui.ProgressBar() end
  function imgui.Spacing() end
  function imgui.Separator() end
  function imgui.SameLine() end
  function imgui.Dummy() end
  function imgui.BeginChild() end
  function imgui.EndChild() end
  function imgui.NewLine() end
  function imgui.Button(label, w, h)
    M.buttons[#M.buttons + 1] = { label = tostring(label), w = w, h = h }
    local id = tostring(label):match("###(.+)")
    return id ~= nil and id == M.click_target
  end
  function imgui.InvisibleButton(label, w, h)
    M.buttons[#M.buttons + 1] = { label = tostring(label), w = w, h = h }
    local id = tostring(label):match("###(.+)")
    return id ~= nil and id == M.click_target
  end
end

-- --------------------------------------------------------------- loading ----
function M.load(path)
  local chunk = assert(loadfile(path), "cannot load " .. path)
  chunk()
end

-- --------------------------------------------------------------- capture ----
function M.reset_capture()
  M.buttons, M.text, M.vars, M.colors, M.fonts = {}, {}, {}, {}, {}
  M.push_color, M.pop_color = 0, 0
  M.push_var, M.pop_var = 0, 0
  M.push_font, M.pop_font = 0, 0
  M.font_stack = {}
  M.click_target = nil
end

function M.build(name, wnd, x, y)
  local fn = _G[name]
  if type(fn) ~= "function" then error("missing builder " .. tostring(name)) end
  fn(wnd or M.windows[1], x or 0, y or 0)
end

function M.run(name, ...)
  local f = nil
  for _, cb in ipairs(M.oftens) do
    if type(cb) == "string" and cb:find(name, 1, true) then f = cb break end
  end
  if not f then error("missing do_often callback " .. tostring(name)) end
  return assert(load(f))(...)
end

function M.click(id)
  M.click_target = id
end

function M.has_button(id)
  for _, b in ipairs(M.buttons) do
    if b.label:find("###" .. id, 1, true) then return true end
  end
  return false
end

function M.has_text(word)
  for _, t in ipairs(M.text) do
    if t:find(word, 1, true) then return true end
  end
  return false
end

function M.button_labels()
  local out = {}
  for _, b in ipairs(M.buttons) do out[#out + 1] = b.label end
  return table.concat(out, "\n")
end

function M.rgb(v)
  return v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256
end

-- ---------------------------------------------------------------- checks ----
function M.check(ok, label, detail)
  M.checks = M.checks + 1
  if ok then
    print("PASS  " .. label)
  else
    print("FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    M.fails = M.fails + 1
  end
end

function M.check_stacks_balanced()
  M.check(M.push_color == M.pop_color, "style colour stack balances",
    M.push_color .. " push / " .. M.pop_color .. " pop")
  M.check(M.push_var == M.pop_var, "style variable stack balances",
    M.push_var .. " push / " .. M.pop_var .. " pop")
  M.check(M.push_font == M.pop_font and #M.font_stack == 0, "font stack balances",
    M.push_font .. " push / " .. M.pop_font .. " pop")
end

function M.check_apple_style()
  for _, id in ipairs({ 3, 7, 12, 17, 18, 21 }) do
    M.check(M.vars[id] == 0, "square corners: style var " .. id .. " is 0",
      tostring(M.vars[id]))
  end
  for alias, _ in pairs(M.fonts) do
    M.check(alias == "CCBody" or alias == "CCSmall",
      "regular font alias only: " .. tostring(alias), tostring(alias))
  end
  for id, col in pairs(M.colors) do
    local r, g, b = M.rgb(col)
    M.check(not (r > 180 and g > 80 and g < 190 and b < 80),
      "no orange pushed on colour " .. tostring(id),
      string.format("#%02X%02X%02X", r, g, b))
  end
end

function M.report(name)
  print("")
  if M.fails == 0 then
    print(string.format("ALL %s TESTS PASSED (%d checks)", name, M.checks))
    os.exit(0)
  else
    print(string.format("%d FAILURE(S) out of %d checks", M.fails, M.checks))
    os.exit(1)
  end
end

return M
