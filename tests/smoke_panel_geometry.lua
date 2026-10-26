--[[
  smoke_panel_geometry.lua — render the suite panels into a recording canvas and
  assert the layout is actually sane.

  This replaces "somebody should look at it on screen" with measurable checks:
    * every panel fits inside the screen
    * no text overlaps the row above/below it
    * no text overflows the panel's own width
    * rows sit in the right vertical order (FlyWithLua's y grows upward)
    * every clickable row's hit rectangle is non-degenerate

  Usage:
    luajit tests/smoke_panel_geometry.lua
--]]

local screen_w, screen_h = 2560, 1440
local fails, checks = 0, 0

local function check(ok, label, detail)
  checks = checks + 1
  if not ok then
    fails = fails + 1
    print("FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
  end
end

------------------------------------------------------------ mock FlyWithLua --
-- Recording canvas: every primitive lands in `drawn`.
SCREEN_WIDTH, SCREEN_HIGHT = screen_w, screen_h
PLANE_ICAO, PLANE_TAILNUMBER = "C750", "N750XP"
VKEY, CKEY, MOUSE_X, MOUSE_Y, MOUSE_STATUS = 0, "", 0, 0, "up"
MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = 0, 0

local drawn = {}          -- { kind=, x=, y=, x2=, y2=, text=, w= }
local function reset() drawn = {} end

-- Approximate FlyWithLua's default draw_string font.
local CHAR_W = 7
function measure_string(t) return #tostring(t) * CHAR_W end

function draw_string(x, y, text) drawn[#drawn + 1] = { kind = "text", x = x, y = y, text = tostring(text) } end
function draw_string_Helvetica_10(x, y, text) drawn[#drawn + 1] = { kind = "text", x = x, y = y, text = tostring(text) } end
function draw_string_Helvetica_12(x, y, text) drawn[#drawn + 1] = { kind = "text", x = x, y = y, text = tostring(text) } end
function draw_string_Helvetica_18(x, y, text) drawn[#drawn + 1] = { kind = "text", x = x, y = y, text = tostring(text) } end
function glRectf(x0, y0, x1, y1) drawn[#drawn + 1] = { kind = "rect", x = x0, y = y0, x2 = x1, y2 = y1 } end
function glColor4f() end
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
function XPLMGetScreenSize() return screen_w, screen_h end
function load_preferences() end
function save_preferences() end
function read_preferences() end
_G.imgui = setmetatable({}, { __index = function() return function() return false end end })

-- optional modules
_G.CAB_CONFIG = { panel_enabled = true, panel_w = 430, row_h = 21, pax_total = 12 }
_G.TRAINER_CONFIG = { panel_enabled = true, panel_x = 24, panel_w = 430, row_h = 21 }
_G.CABV = nil

--------------------------------------------------------------- assertions ----
local function text_boxes()
  local boxes = {}
  for _, d in ipairs(drawn) do
    if d.kind == "text" then
      boxes[#boxes + 1] = { x0 = d.x, x1 = d.x + measure_string(d.text), y = d.y, text = d.text }
    end
  end
  return boxes
end

local function rect_boxes()
  local out = {}
  for _, d in ipairs(drawn) do
    if d.kind == "rect" then out[#out + 1] = d end
  end
  return out
end

-- Every primitive is inside the screen and inside the panel that owns it.
local function assert_on_screen(tag, bounds)
  local worst_x, worst_y = 0, 0
  for _, d in ipairs(drawn) do
    if d.kind == "text" then
      local x2 = d.x + measure_string(d.text)
      if x2 > screen_w then worst_x = math.max(worst_x, x2) end
      if d.x < 0 then worst_x = math.max(worst_x, -d.x) end
      if d.y < 0 then worst_y = math.max(worst_y, -d.y) end
      if d.y > screen_h then worst_y = math.max(worst_y, d.y - screen_h) end
    else
      if d.x2 > screen_w then worst_x = math.max(worst_x, d.x2) end
      if d.x < 0 then worst_x = math.max(worst_x, -d.x) end
      if d.y < 0 then worst_y = math.max(worst_y, -d.y) end
      if d.y2 > screen_h then worst_y = math.max(worst_y, d.y2 - screen_h) end
    end
  end
  check(worst_x == 0, tag .. ": nothing exceeds screen width", "+" .. worst_x .. " px")
  check(worst_y == 0, tag .. ": nothing exceeds screen height", "+" .. worst_y .. " px")
end

-- Rows must not collide: for each panel, group text by x-origin, then confirm
-- successive baselines are at least 14 px apart (a 12 px font needs that).
local function assert_row_spacing(tag)
  local boxes = text_boxes()
  local by_x = {}
  for _, b in ipairs(boxes) do
    local k = math.floor(b.x0 + 0.5)
    by_x[k] = by_x[k] or {}
    by_x[k][#by_x[k] + 1] = b
  end
  local collisions = 0
  for _, col in pairs(by_x) do
    table.sort(col, function(a, b) return a.y > b.y end)
    for i = 2, #col do
      local gap = col[i - 1].y - col[i].y
      if gap > 0 and gap < 14 then
        collisions = collisions + 1
        if collisions <= 3 then
          print(string.format("      tight: %.1f px between %q and %q",
            gap, col[i - 1].text:sub(1, 18), col[i].text:sub(1, 18)))
        end
      end
    end
  end
  check(collisions == 0, tag .. ": no vertical text collisions", collisions .. " pair(s)")
end

-- Text must stay inside the panel background it belongs to.
local function assert_text_inside_panel(tag)
  local rects = rect_boxes()
  if #rects == 0 then return end
  -- widest, tallest rect is the panel body
  local panel = rects[1]
  for _, r in ipairs(rects) do
    if (r.x2 - r.x) * (r.y2 - r.y) > (panel.x2 - panel.x) * (panel.y2 - panel.y) then panel = r end
  end
  local overflow = 0
  for _, b in ipairs(text_boxes()) do
    -- only text belonging to this panel (starts inside its x range)
    if b.x0 >= panel.x - 1 and b.x0 <= panel.x2
       and b.y >= panel.y - 2 and b.y <= panel.y2 + 16 then
      if b.x1 > panel.x2 + 1 then
        overflow = overflow + 1
        if overflow <= 3 then
          print(string.format("      overflows by %.0f px: %q", b.x1 - panel.x2, b.text:sub(1, 28)))
        end
      end
    end
  end
  check(overflow == 0, tag .. ": text stays inside its panel", overflow .. " overflow(s)")
end

------------------------------------------------------------------ MasterSuite
print("== CitationX_MasterSuite.lua ==")
do
  local chunk = assert(loadfile("Scripts/CitationX_MasterSuite.lua"))
  chunk()
  -- The hub is visible at load, next to the realism panel.
  check(CONFIG.status_enabled == true, "control panel is visible at load")

  reset()
  citationx_overlay()
  local n = #drawn
  check(n > 20, "control panel draws a meaningful number of primitives", n)
  assert_on_screen("control panel", nil)
  assert_row_spacing("control panel")
  assert_text_inside_panel("control panel")

  -- Drag the header and confirm the panel follows the mouse.
  local st = SUITE_STYLE
  local x0, top0 = st.x, st.top
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = x0 + 20, top0 - 10
  RESUME_MOUSE_CLICK = false
  citationx_mouse_click()
  check(RESUME_MOUSE_CLICK == true, "header press starts a drag")
  MOUSE_STATUS = "drag"
  MOUSE_X, MOUSE_Y = x0 + 20 - 120, top0 - 10 - 70
  citationx_mouse_click()
  check(math.abs(st.x - (x0 - 120)) < 1 and math.abs(st.top - (top0 - 70)) < 1,
    "panel follows the mouse while dragging",
    string.format("%.0f/%.0f vs %.0f/%.0f", st.x, st.top, x0 - 120, top0 - 70))
  MOUSE_STATUS = "up"
  citationx_mouse_click()
  check(st.x == x0 - 120, "drag position is kept after release")
  st.x, st.top = x0, top0

  -- The control panel is the suite's only surface. With it switched off the
  -- overlay must draw nothing at all (no telemetry HUD, no systems readback).
  CONFIG.status_enabled = false
  reset()
  citationx_overlay()
  check(#drawn == 0, "nothing is drawn when the control panel is off", #drawn .. " primitive(s)")
  CONFIG.status_enabled = true

  -- Behaviour-level click test: sweep the panel vertically and confirm each
  -- click hits at most one row and actually toggles something. The HIDE footer
  -- is excluded here; it is checked separately.
  local hit_count = 0
  local errors = 0
  for y = 40, screen_h - 40, 4 do
    MOUSE_STATUS = "down"
    MOUSE_X = st.x + st.width / 2
    MOUSE_Y = y
    RESUME_MOUSE_CLICK = false
    local ok = pcall(citationx_mouse_click)
    if not ok then errors = errors + 1 end
    if RESUME_MOUSE_CLICK then
      hit_count = hit_count + 1
    end
    -- a row hit may toggle the panel itself off; keep sweeping
    CONFIG.status_enabled = true
    MOUSE_STATUS = "up"
  end
  check(errors == 0, "click sweep over the control panel never errors", errors .. " error(s)")
  check(hit_count >= #SUITE_MODULES, "click sweep hits at least one row per module",
    hit_count .. " hits for " .. #SUITE_MODULES .. " modules")

  -- clicking far outside the panel must not be consumed
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = 5, 5
  RESUME_MOUSE_CLICK = false
  pcall(citationx_mouse_click)
  check(RESUME_MOUSE_CLICK == false, "click outside the panel is not consumed")
  MOUSE_STATUS = "up"

  -- HIDE button closes the hub
  reset()
  citationx_overlay()
  CONFIG.status_enabled = true
  reset()
  citationx_overlay()
  MOUSE_X = st.x + st.width / 2
  MOUSE_Y = st.top - (34 + 20 + 16 + #SUITE_MODULES * st.row_h + 34 + 8) + 20
  MOUSE_STATUS = "down"
  RESUME_MOUSE_CLICK = false
  citationx_mouse_click()
  check(CONFIG.status_enabled == false, "HIDE PANEL footer button closes the hub")
  CONFIG.status_enabled = true
end

--------------------------------------------------------------- CabinOps ----
print("== CitationX_CabinOps.lua ==")
do
  CAB_CONFIG = nil
  local chunk = assert(loadfile("Scripts/CitationX_CabinOps.lua"))
  chunk()
  cab_toggle_panel(true)       -- hidden at load; the hub opens it

  reset()
  cab_draw()
  check(#drawn > 10, "cabin panel draws content", #drawn)
  assert_on_screen("cabin", nil)
  assert_row_spacing("cabin")
  assert_text_inside_panel("cabin")

  -- header drag
  local cx0, ctop0 = CAB_CONFIG.panel_x, CAB_CONFIG.panel_top
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = cx0 + 20, ctop0 - 10
  RESUME_MOUSE_CLICK = false
  cab_mouse_click()
  check(RESUME_MOUSE_CLICK == true, "cabin header press starts a drag")
  MOUSE_STATUS = "drag"
  MOUSE_X, MOUSE_Y = cx0 + 20 - 80, ctop0 - 10 - 60
  cab_mouse_click()
  check(math.abs(CAB_CONFIG.panel_x - (cx0 - 80)) < 1
    and math.abs(CAB_CONFIG.panel_top - (ctop0 - 60)) < 1,
    "cabin panel follows the mouse while dragging")
  MOUSE_STATUS = "up"
  cab_mouse_click()
  CAB_CONFIG.panel_x, CAB_CONFIG.panel_top = cx0, ctop0

  -- behaviour-level: clicking inside the panel is consumed, outside is not
  local hit = 0
  for y = ctop0 - 260, ctop0, 6 do
    MOUSE_STATUS = "down"; MOUSE_X = cx0 + 60; MOUSE_Y = y
    RESUME_MOUSE_CLICK = false
    pcall(cab_mouse_click)
    if RESUME_MOUSE_CLICK then hit = hit + 1 end
    CAB_CONFIG.panel_enabled = true
    MOUSE_STATUS = "up"
  end
  check(hit > 0, "cabin panel consumes clicks on its rows", hit .. " hit(s)")
end

------------------------------------------------------------ FailureTrainer --
print("== CitationX_FailureTrainer.lua ==")
do
  TRAINER_CONFIG = nil
  local chunk = assert(loadfile("Scripts/CitationX_FailureTrainer.lua"))
  chunk()
  qrh_toggle_panel(true)       -- hidden at load; the hub opens it

  reset()
  qrh_draw()
  check(#drawn > 10, "QRH panel draws content", #drawn)
  assert_on_screen("qrh", nil)
  assert_row_spacing("qrh")
  assert_text_inside_panel("qrh")

  local qx0, qtop0 = TRAINER_CONFIG.panel_x, TRAINER_CONFIG.panel_top
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = qx0 + 20, qtop0 - 10
  RESUME_MOUSE_CLICK = false
  qrh_mouse_click()
  check(RESUME_MOUSE_CLICK == true, "QRH header press starts a drag")
  MOUSE_STATUS = "drag"
  MOUSE_X, MOUSE_Y = qx0 + 20 + 120, qtop0 - 10 - 60
  qrh_mouse_click()
  check(math.abs(TRAINER_CONFIG.panel_x - (qx0 + 120)) < 1
    and math.abs(TRAINER_CONFIG.panel_top - (qtop0 - 60)) < 1,
    "QRH panel follows the mouse while dragging")
  MOUSE_STATUS = "up"
  qrh_mouse_click()
  TRAINER_CONFIG.panel_x, TRAINER_CONFIG.panel_top = qx0, qtop0

  local hit = 0
  for y = qtop0 - 300, qtop0, 6 do
    MOUSE_STATUS = "down"; MOUSE_X = qx0 + 40; MOUSE_Y = y
    RESUME_MOUSE_CLICK = false
    pcall(qrh_mouse_click)
    if RESUME_MOUSE_CLICK then hit = hit + 1 end
    TRAINER_CONFIG.panel_enabled = true
    MOUSE_STATUS = "up"
  end
  check(hit > 0, "QRH panel consumes clicks on its rows", hit .. " hit(s)")

  -- active procedure: long step labels must still fit the narrower panel
  TRAINER_CONFIG.require_c750 = false
  qrh_inject_by_key("engine_fire_l")
  reset()
  qrh_draw()
  check(#drawn > 10, "active QRH procedure draws content", #drawn)
  assert_on_screen("qrh-active", nil)
  assert_row_spacing("qrh-active")
  assert_text_inside_panel("qrh-active")
  qrh_clear()
  TRAINER_CONFIG.require_c750 = true
end

--------------------------------------------------------------------- EFB ----
print("== CitationX_EFB.lua ==")
do
  EFB_CONFIG = nil
  local chunk = assert(loadfile("Scripts/CitationX_EFB.lua"))
  chunk()

  reset()
  efb_toggle_panel(true)   -- the script loads with the panel hidden
  efb_draw()
  check(#drawn > 20, "EFB panel draws content", #drawn)
  assert_on_screen("efb", nil)
  assert_row_spacing("efb")
  assert_text_inside_panel("efb")

  local ex0, etop0 = EFB_CONFIG.panel_x, EFB_CONFIG.panel_top
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = ex0 + 20, etop0 - 10
  RESUME_MOUSE_CLICK = false
  efb_mouse_click()
  check(RESUME_MOUSE_CLICK == true, "EFB header press starts a drag")
  MOUSE_STATUS = "drag"
  MOUSE_X, MOUSE_Y = ex0 + 20 - 100, etop0 - 10 - 50
  efb_mouse_click()
  check(math.abs(EFB_CONFIG.panel_x - (ex0 - 100)) < 1
    and math.abs(EFB_CONFIG.panel_top - (etop0 - 50)) < 1,
    "EFB panel follows the mouse while dragging")
  MOUSE_STATUS = "up"
  efb_mouse_click()
  EFB_CONFIG.panel_x, EFB_CONFIG.panel_top = ex0, etop0
  reset()
  efb_draw()

  -- every page must render without leaving the screen
  for _, page in ipairs({ 2, 3, 1 }) do
    efb_set_page(page)
    reset()
    efb_draw()
    check(#drawn > 10, "EFB page " .. page .. " draws content", #drawn)
    assert_on_screen("efb-page-" .. page, nil)
    assert_text_inside_panel("efb-page-" .. page)
  end

  -- default positions must not collide: hub + realism top-left, QRH left,
  -- EFB centre, cabin right
  local x1 = EFB_CONFIG.panel_x
  local x2 = x1 + EFB_CONFIG.panel_w
  local qrh_right = TRAINER_CONFIG.panel_x + TRAINER_CONFIG.panel_w
  local cab_left = CAB_CONFIG.panel_x
  check(x1 > qrh_right, "EFB clears the QRH panel", string.format("%.0f > %d", x1, qrh_right))
  check(x2 < cab_left, "EFB clears the cabin panel", string.format("%.0f < %d", x2, cab_left))
end

------------------------------------------------------------------- Realism ---
print("== CitationX_Realism.lua ==")
do
  local chunk = assert(loadfile("Scripts/CitationX_Realism.lua"))
  chunk()
  reset()
  real_draw()
  check(#drawn > 40, "realism panel draws content", #drawn)
  assert_on_screen("realism", nil)
  assert_row_spacing("realism")
  assert_text_inside_panel("realism")

  local rx0, rtop0 = REAL_STYLE.x, REAL_STYLE.y
  MOUSE_STATUS = "down"
  MOUSE_X, MOUSE_Y = rx0 + 20, rtop0 - 10
  RESUME_MOUSE_CLICK = false
  real_mouse_click()
  check(RESUME_MOUSE_CLICK == true, "realism header press starts a drag")
  MOUSE_STATUS = "drag"
  MOUSE_X, MOUSE_Y = rx0 + 20 + 80, rtop0 - 10 - 50
  real_mouse_click()
  check(math.abs(REAL_STYLE.x - (rx0 + 80)) < 1
    and math.abs(REAL_STYLE.y - (rtop0 - 50)) < 1,
    "realism panel follows the mouse while dragging")
  MOUSE_STATUS = "up"
  real_mouse_click()
  REAL_STYLE.x, REAL_STYLE.y = rx0, rtop0

  -- the panel must survive a small screen too
  SCREEN_WIDTH, SCREEN_HIGHT = 1280, 720
  reset()
  real_draw()
  assert_on_screen("realism-720p", nil)
  SCREEN_WIDTH, SCREEN_HIGHT = screen_w, screen_h
end

------------------------------------------------------------------- result ----
print("")
if fails == 0 then
  print(string.format("ALL PANEL GEOMETRY TESTS PASSED (%d checks)", checks))
  os.exit(0)
else
  print(string.format("%d FAILURE(S) out of %d checks", fails, checks))
  os.exit(1)
end
