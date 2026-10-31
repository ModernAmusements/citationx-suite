--[[
  render_panels.lua — render the suite's panels offline into a JSON dump that
  tools/render_panels.py turns into PNGs for the README.

  This is a mock-FlyWithLua renderer, not a test: it loads each panel script
  in its own Lua state (like smoke_panel_geometry.lua), calls the panel draw
  function once, and records every primitive WITH the colour the script set
  via glColor4f. FlyWithLua's y grows upward, so the SVG/MVG side flips it.

  Usage:
    luajit tools/render_panels.lua > /tmp/panels.json
    python3 tools/render_panels.py /tmp/panels.json docs/img/panels
--]]

SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"
MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = 0, 0

local cur_color = { 1, 1, 1, 1 }
local frames = {}   -- { { name=, prims= { {k,x,y,x2,y2,text,font,c={r,g,b,a}} } } }
local prims

local function new_frame(name)
  prims = {}
  frames[#frames + 1] = { name = name, prims = prims }
end

local function stamp(kind, extra)
  prims[#prims + 1] = setmetatable({
    k = kind, c = { cur_color[1], cur_color[2], cur_color[3], cur_color[4] },
  }, { __index = function() return 0 end })
  if extra then
    for k, v in pairs(extra) do prims[#prims][k] = v end
  end
end

local function mkdraw(font)
  return function(x, y, text)
    stamp("text", { x = x, y = y, text = tostring(text), font = font })
  end
end
draw_string               = mkdraw("def")
draw_string_Helvetica_10  = mkdraw("h10")
draw_string_Helvetica_12  = mkdraw("h12")
draw_string_Helvetica_18  = mkdraw("h18")

function glRectf(x0, y0, x1, y1) stamp("rect", { x = x0, y = y0, x2 = x1, y2 = y1 }) end
function glColor4f(r, g, b, a) cur_color = { r, g, b, a } end
function measure_string(t) return tostring(t):len() * 7 end
function XPLMSetGraphicsState() end

function dataref(name, path, mode, index)
  _G[name] = 0
  return 0
end
function dataref_table() return setmetatable({}, { __index = function() return 0 end }) end
function get() return 0 end
function set() end
function logMsg() end
function create_command() return {} end
function add_macro() end
function do_every_draw() end
function do_every_frame() end
function do_often() end
function do_sometimes() end
function do_every_second() end
function do_on_exit() end
function do_on_keystroke() end
function do_on_mouse_click() end
function do_on_mouse_wheel() end
function command_once() end
function toast() end
function float_wnd_create() return {} end
function float_wnd_set_title() end
function float_wnd_set_imgui_builder() end
function float_wnd_set_onclose() end
function float_wnd_set_ondraw() end
function float_wnd_set_onclick() end
function float_wnd_destroy() end
function XPLMFindDataRef(p) return { path = p } end
function XPLMGetDataf() return 0 end
function XPLMGetDatai() return 0 end
function XPLMSetDataf() end
function XPLMSetDatai() end
function XPLMGetScreenSize() return SCREEN_WIDTH, SCREEN_HIGHT end
function load_preferences() end
function save_preferences() end
function read_preferences() end
_G.imgui = setmetatable({}, { __index = function() return function() return false end end })

-- optional-module stubs, the same ones the geometry harness uses
_G.CAB_CONFIG = { panel_enabled = true, panel_w = 430, row_h = 21, pax_total = 12 }
_G.TRAINER_CONFIG = { panel_enabled = true, panel_x = 24, panel_w = 430, row_h = 21 }
_G.CABV = nil

local function load_script(path)
  local chunk = assert(loadfile(path))
  chunk()
end

-- Load everything first, in FlyWithLua's alphabetical order, one shared state.
load_script("Scripts/CitationX_CabinOps.lua")
load_script("Scripts/CitationX_EFB.lua")
load_script("Scripts/CitationX_FailureTrainer.lua")
load_script("Scripts/CitationX_MasterSuite.lua")
load_script("Scripts/CitationX_Realism.lua")

-- 1. the load view: hub + realism panel, exactly what the sim shows at load
new_frame("load")
citationx_overlay()
real_draw()

-- 2. hub alone
new_frame("hub")
citationx_overlay()

-- 3. realism panel alone
new_frame("realism")
real_draw()

-- 4. EFB, PERF page
new_frame("efb")
efb_toggle_panel(true)
efb_set_page(1)
efb_draw()

-- 5. cabin ops
new_frame("cabin")
cab_toggle_panel(true)
cab_draw()

-- 6. QRH trainer, idle
new_frame("qrh")
qrh_toggle_panel(true)
qrh_draw()

------------------------------------------------------------ JSON emitter -----
local function esc(s)
  s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
  return s
end

local out = { '{"screen":{"w":' .. SCREEN_WIDTH .. ',"h":' .. SCREEN_HIGHT .. '},"frames":[' }
for fi, fr in ipairs(frames) do
  out[#out + 1] = '{"name":"' .. fr.name .. '","prims":['
  for pi, p in ipairs(fr.prims) do
    local parts = { '"k":"' .. p.k .. '"' }
    parts[#parts + 1] = '"c":[' .. p.c[1] .. ',' .. p.c[2] .. ',' .. p.c[3] .. ',' .. p.c[4] .. ']'
    if p.k == "text" then
      parts[#parts + 1] = '"x":' .. p.x .. ',"y":' .. p.y
      parts[#parts + 1] = '"text":"' .. esc(p.text) .. '"'
      parts[#parts + 1] = '"font":"' .. p.font .. '"'
    else
      parts[#parts + 1] = '"x":' .. p.x .. ',"y":' .. p.y .. ',"x2":' .. p.x2 .. ',"y2":' .. p.y2
    end
    out[#out + 1] = "{" .. table.concat(parts, ",") .. "}"
    if pi < #fr.prims then out[#out + 1] = "," end
  end
  out[#out + 1] = "]}"
  if fi < #frames then out[#out + 1] = "," end
end
out[#out + 1] = "]}"
print(table.concat(out))
