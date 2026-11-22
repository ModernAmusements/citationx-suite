--[[
  smoke_control_center.lua — verify the ImGui Control Center.

  The Control Center is the only suite surface visible at load. It must expose
  every other panel, drive them through SUITE_MODULES (never through its own
  state), use the Neo Grotesque aliases, and balance every style/font push.

  Usage:
    luajit tests/smoke_control_center.lua Scripts/CitationX_01_ControlCenter.lua
--]]

local script = arg[1] or "Scripts/CitationX_01_ControlCenter.lua"
local fails, checks = 0, 0

local function check(ok, label, detail)
  checks = checks + 1
  if ok then
    print("PASS  " .. label)
  else
    print("FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    fails = fails + 1
  end
end

-- ------------------------------------------------------------ mock FlyWithLua --
SCRIPT_DIRECTORY = "./Scripts/"
PLUGIN_MAIN_DIRECTORY = "./"
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
SUPPORTS_FLOATING_WINDOWS = true
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"

local dataref_calls = 0
local commands, macros = {}, {}
local often_cb

function dataref()
  dataref_calls = dataref_calls + 1
end
function dataref_table() return setmetatable({}, { __index = function() return 0 end }) end
function logMsg() end
function create_command(name) commands[#commands + 1] = name return { name = name } end
function add_macro(name) macros[#macros + 1] = name end
function do_often(cb) often_cb = cb end
function do_every_frame() end
function do_every_draw() end
function do_on_exit() end
function do_on_mouse_click() end

local windows = {}
function float_wnd_create(w, h, decoration, use_imgui)
  local wnd = { w = w, h = h, decoration = decoration, imgui = use_imgui, visible = nil }
  windows[#windows + 1] = wnd
  return wnd
end
function float_wnd_set_title(wnd, title) wnd.title = title end
function float_wnd_set_position(wnd, x, y) wnd.x, wnd.y = x, y end
function float_wnd_set_imgui_builder(wnd, name) wnd.builder = name end
function float_wnd_set_onclose(wnd, name) wnd.onclose = name end
function float_wnd_set_visible(wnd, on) wnd.visible = on end
function float_wnd_bring_to_front(wnd) wnd.front = true end
function float_wnd_destroy() end

-- ------------------------------------------------------------- mock ImGui ----
local captured = {
  buttons = {}, text = {}, fonts = {}, vars = {},
  push_color = 0, pop_color = 0,
  push_var = 0, pop_var = 0,
  push_font = 0, pop_font = 0,
  font_stack = {},
}
local click_target = nil

local function reset_capture()
  captured.buttons = {}
  captured.text = {}
  captured.fonts = {}
  captured.vars = {}
  captured.push_color, captured.pop_color = 0, 0
  captured.push_var, captured.pop_var = 0, 0
  captured.push_font, captured.pop_font = 0, 0
  captured.font_stack = {}
  click_target = nil
end

imgui = {
  constant = {
    Col = {
      Text = 0, WindowBg = 2, Border = 5, FrameBg = 7,
      Button = 21, ButtonHovered = 22, ButtonActive = 23, Separator = 27,
    },
    StyleVar = {
      WindowPadding = 2, WindowRounding = 3, ChildRounding = 7,
      FramePadding = 11, FrameRounding = 12, ItemSpacing = 14,
      ScrollbarRounding = 17, GrabRounding = 18, TabRounding = 21,
    },
  },
}
function imgui.get_font_list()
  return { "CCBody", "CCSmall" }
end
function imgui.PushStyleColor() captured.push_color = captured.push_color + 1 end
function imgui.PopStyleColor() captured.pop_color = captured.pop_color + 1 end
function imgui.PushStyleVar(id, v) captured.push_var = captured.push_var + 1 captured.vars[id] = v end
function imgui.PushStyleVar_2(id, a, b) captured.push_var = captured.push_var + 1 captured.vars[id] = a end
function imgui.PopStyleVar() captured.pop_var = captured.pop_var + 1 end
function imgui.PushFont(name)
  captured.push_font = captured.push_font + 1
  captured.fonts[name] = true
  captured.font_stack[#captured.font_stack + 1] = name
end
function imgui.PopFont()
  captured.pop_font = captured.pop_font + 1
  captured.font_stack[#captured.font_stack] = nil
end
function imgui.TextUnformatted(text) captured.text[#captured.text + 1] = tostring(text) end
function imgui.ProgressBar() end
function imgui.Spacing() end
function imgui.Separator() end
function imgui.SameLine() end
function imgui.Button(label, w, h)
  captured.buttons[#captured.buttons + 1] = { label = label, w = w, h = h }
  local id = label:match("###(.+)")
  return id ~= nil and id == click_target
end

-- ------------------------------------------------------------------- load ----
-- The shared kit loads first in the real FlyWithLua alphabetical order.
assert(loadfile("Scripts/CitationX_00_Core.lua"))()
assert(loadfile("Scripts/CitationX_00_ImGuiKit.lua"))()
local chunk = assert(loadfile(script))
chunk()

check(dataref_calls == 0, "the Control Center binds no datarefs", dataref_calls)
check(#windows == 1, "one floating window is created at load", #windows)
local wnd = windows[1]
check(wnd.imgui == true and wnd.decoration == 1, "window uses native decoration and ImGui")
check(wnd.title == "Citation X Control Center", "window has an Apple-style title", wnd.title)
check(wnd.builder == "cc_on_build", "ImGui builder is registered", wnd.builder)
check(wnd.onclose == "cc_on_close", "close callback is registered", wnd.onclose)
check(type(wnd.x) == "number" and wnd.y > 24, "window is placed on screen", tostring(wnd.y))
check(wnd.visible == 1 or wnd.visible == true, "window is visible on the C750",
  tostring(wnd.visible))
check(type(often_cb) == "string" and often_cb:find("cc_aircraft_guard", 1, true) ~= nil,
  "aircraft guard runs often", tostring(often_cb))
check(#commands == 1 and commands[1] == "CitationXSuite/control_center",
  "show command is registered", table.concat(commands, ","))
check(#macros == 1 and macros[1] == "Citation X Control Center: show",
  "show macro is registered", table.concat(macros, ","))

-- ImGui packs colours as 0xAABBGGRR. The shared palette must be green/blue/
-- grey only — no orange accent anywhere, and all rounding values must be 0.
local function cc_rgb(v)
  return v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256
end
local r, g, b = cc_rgb(CXUI.color.on)
check(g > r and g > b, "ON state pill is green after ABGR packing",
  string.format("#%02X%02X%02X", r, g, b))
r, g, b = cc_rgb(CXUI.color.active)
check(b > r and b > g, "ACTIVE state pill is blue, not orange",
  string.format("#%02X%02X%02X", r, g, b))
for _, key in ipairs({ "window", "surface", "text", "muted", "dim",
                       "button", "hover", "pressed", "separator", "track" }) do
  local rr, gg, bb = cc_rgb(CXUI.color[key])
  check(math.max(rr, gg, bb) - math.min(rr, gg, bb) <= 8,
    "palette entry is neutral grey: " .. key,
    string.format("#%02X%02X%02X", rr, gg, bb))
end

-- --------------------------------------------------- module registry stub ----
local panel_state = {
  status = false, realism = false, cabin = false, qrh = false,
  instructor = false, landperf = false, axmon = false,
}
SUITE_MODULES = {}
for _, key in ipairs({ "status", "realism", "cabin", "qrh", "instructor",
                       "landperf", "axmon" }) do
  SUITE_MODULES[#SUITE_MODULES + 1] = {
    key = key,
    get = function() return panel_state[key] end,
    set = function(on) panel_state[key] = (on == true) end,
    state = function()
      if key == "landperf" then
        return panel_state[key] and "SHOWN" or "HIDDEN"
      end
      return panel_state[key] and "ON" or "OFF"
    end,
  }
end

local flows_opened, textures_cycled = 0, 0
function citationx_set_status(on) panel_state.status = (on == true) end
function citationx_set_flow_tab(tab) if tab == "flows" then flows_opened = flows_opened + 1 end end
function citationx_texture_next() textures_cycled = textures_cycled + 1 end

-- -------------------------------------------------------------- draw pass ----
reset_capture()
cc_on_build(wnd, 0, 0)

local text_blob = table.concat(captured.text, "\n")
for _, word in ipairs({ "CITATION X", "CONTROL CENTER", "PANELS", "DIAGNOSTICS" }) do
  check(text_blob:find(word, 1, true) ~= nil, "header draws " .. word)
end

local button_labels = {}
for _, b in ipairs(captured.buttons) do
  button_labels[#button_labels + 1] = b.label
end
local blob = table.concat(button_labels, "\n")
for _, item in ipairs({
  { key = "status", label = "SUITE HUB" },
  { key = "realism", label = "REALISM PANEL" },
  { key = "cabin", label = "CABIN OPS" },
  { key = "qrh", label = "QRH TRAINER" },
  { key = "instructor", label = "FLIGHT INSTRUCTOR" },
  { key = "landperf", label = "LANDING REPORT" },
  { key = "axmon", label = "AXIS MONITOR" },
}) do
  check(blob:find(item.label .. "###cc_" .. item.key, 1, true) ~= nil,
    "Control Center exposes " .. item.label)
end
check(blob:find("OFF###cc_status_state", 1, true) ~= nil, "states are rendered in the row")
check(blob:find("HIDDEN###cc_landperf_state", 1, true) ~= nil,
  "landing report uses its SHOWN/HIDDEN state")

for _, alias in ipairs({ "CCBody", "CCSmall" }) do
  check(captured.fonts[alias] == true, "Neo Grotesque REGULAR alias is used: " .. alias)
end
check(captured.fonts.CCTitle == nil and captured.fonts.CCHeading == nil,
  "no bold font alias is pushed")
for _, id in ipairs({ 3, 7, 12, 17, 18, 21 }) do
  check(captured.vars[id] == 0, "square corners: style var " .. id .. " is 0",
    tostring(captured.vars[id]))
end
check(captured.push_font == captured.pop_font and #captured.font_stack == 0,
  "font stack balances", captured.push_font .. " push / " .. captured.pop_font .. " pop")
check(captured.push_color == captured.pop_color, "style colour stack balances",
  captured.push_color .. " push / " .. captured.pop_color .. " pop")
check(captured.push_var == captured.pop_var, "style variable stack balances",
  captured.push_var .. " push / " .. captured.pop_var .. " pop")

-- ------------------------------------------------------------ click drives --
reset_capture()
click_target = "cc_realism"
cc_on_build(wnd, 0, 0)
check(panel_state.realism == true, "clicking the realism row opens the realism panel")
check(panel_state.status == false, "clicking one row does not open the others")

reset_capture()
click_target = "cc_show_all"
cc_on_build(wnd, 0, 0)
local all_on = true
for _, key in ipairs({ "status", "realism", "cabin", "qrh", "instructor", "landperf" }) do
  all_on = all_on and panel_state[key]
end
check(all_on, "SHOW ALL opens every panel")

reset_capture()
click_target = "cc_hide_all"
cc_on_build(wnd, 0, 0)
local all_off = true
for _, key in ipairs({ "status", "realism", "cabin", "qrh", "instructor", "landperf" }) do
  all_off = all_off and not panel_state[key]
end
check(all_off, "HIDE ALL closes every panel")
check(panel_state.axmon == false, "HIDE ALL leaves the diagnostic switch alone")

reset_capture()
click_target = "cc_action_flows"
cc_on_build(wnd, 0, 0)
check(flows_opened == 1 and panel_state.status == true,
  "FLOWS shortcut opens the legacy hub on its FLOWS page",
  tostring(flows_opened) .. "/" .. tostring(panel_state.status))

reset_capture()
click_target = "cc_action_livery"
cc_on_build(wnd, 0, 0)
check(textures_cycled == 1, "TEXTURE shortcut cycles the livery")

-- ------------------------------------------------------------ C750 guard ----
PLANE_ICAO = "MD80"
cc_aircraft_guard()
check(wnd.visible == 0 or wnd.visible == false, "window hides on another aircraft",
  tostring(wnd.visible))
reset_capture()
cc_on_build(wnd, 0, 0)
check(#captured.buttons == 0, "no suite controls are drawn on another aircraft")
PLANE_ICAO = "C750"
cc_aircraft_guard()
check(wnd.visible == 1 or wnd.visible == true, "window returns with the Citation X",
  tostring(wnd.visible))

-- ------------------------------------------------------------- close/reopen --
cc_on_close(wnd)
check(wnd ~= nil, "close callback does not destroy the window twice")
cc_open()
check(#windows == 2 and windows[2] ~= wnd, "cc_open recreates a closed window")
check(windows[2].builder == "cc_on_build", "reopened window gets the same builder")
check(windows[2].front == true, "reopened window is brought to the front")

print("")
if fails == 0 then
  print(string.format("ALL CONTROL CENTER TESTS PASSED (%d checks)", checks))
  os.exit(0)
else
  print(string.format("%d FAILURE(S) out of %d checks", fails, checks))
  os.exit(1)
end
