--[[
  smoke_efb.lua — mock-FlyWithLua smoke test for Scripts/CitationX_EFB.lua

  Covers: panel registration, the three pages, tab clicking, checklist state,
  fuel-planner clamps, runway-condition cycling and the advisory computations
  that feed the PERF page.

  Usage:
    HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_efb.lua Scripts/CitationX_EFB.lua
--]]

local script = arg[1] or "Scripts/CitationX_EFB.lua"
local fails = 0
local function check(ok, label, detail)
  if ok then
    print("PASS  " .. label)
  else
    print("FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    fails = fails + 1
  end
end

-- ---------- mock FlyWithLua ----------
SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
MOUSE_X, MOUSE_Y, MOUSE_STATUS = -1, -1, "up"
RESUME_MOUSE_CLICK = false
VKEY, CKEY = 0, ""

local draw_cb, click_cb
local drawn = {}

function dataref(name, path, mode, index)
  _G[name] = 0
  return 0
end
function dataref_table() return {} end
function draw_string(x, y, text, r, g, b) drawn[#drawn + 1] = tostring(text) end
function measure_string(t) return #tostring(t) * 7 end
function glColor4f() end
function glRectf() end
function XPLMSetGraphicsState() end
function create_command() end
function add_macro() end
function do_every_draw(f) draw_cb = f end
function do_on_mouse_click(f) click_cb = f end
function command_once() end
function logMsg() end
function toast() end
function XPLMFindDataRef() return nil end
function XPLMGetDataf() return 0 end

-- ---------- load ----------
local chunk = assert(loadfile(script))
chunk()

check(type(EFB_CONFIG) == "table", "EFB_CONFIG exists")
check(EFB_CONFIG.panel_enabled == true, "panel enabled by default")
check(type(efb_draw) == "function", "efb_draw registered")
check(type(efb_mouse_click) == "function", "efb_mouse_click registered")
check(draw_cb ~= nil, "draw callback registered")
check(click_cb ~= nil, "mouse callback registered")

-- ---------- known aircraft state ----------
efb_weight_kg = 15000
efb_fuel_kg   = 3000
efb_oat_c     = 20
efb_qnh_inhg  = 29.92
efb_wind_kt   = 20
efb_wind_dir  = 90
efb_hdg_mag   = 0
efb_elev_m    = 100
efb_gs_ms     = 0
efb_sim_time  = 0

-- ---------- page 1: performance ----------
drawn = {}
local ok, err = pcall(efb_draw)
check(ok, "PERF page draws", err)
local text = table.concat(drawn, "\n")
check(text:find("GROSS WEIGHT", 1, true) ~= nil, "PERF shows gross weight")
check(text:find("DENSITY ALT", 1, true) ~= nil, "PERF shows density altitude")
check(text:find("V1 / VR / V2", 1, true) ~= nil, "PERF shows V-speeds")
check(text:find("TAKEOFF DIST", 1, true) ~= nil, "PERF shows takeoff distance")
check(text:find("LANDING DIST", 1, true) ~= nil, "PERF shows landing distance")
check(text:find("ADVISORY ONLY", 1, true) ~= nil, "PERF carries the advisory note")

-- 15000 kg is 6% above MLW -> V1 should be between the bookends 104..120
local v1_line
for _, s in ipairs(drawn) do
  if s:match("^%d+ / %d+ / %d+ KT$") then v1_line = s end
end
check(v1_line ~= nil, "V-speed line is numeric", v1_line)
if v1_line then
  local v1 = tonumber(v1_line:match("^(%d+)"))
  check(v1 >= 104 and v1 <= 120, "V1 inside the model envelope", v1)
end

-- ---------- page 2: checklists ----------
efb_set_page(2)
drawn = {}
ok, err = pcall(efb_draw)
check(ok, "CHECK page draws", err)
text = table.concat(drawn, "\n")
check(text:find("BEFORE START", 1, true) ~= nil, "CHECK starts on BEFORE START")
check(text:find("PROGRESS", 1, true) ~= nil, "CHECK shows progress")

efb_reset_checklist()
efb_toggle_check_item(1)
efb_toggle_check_item(3)
drawn = {}
efb_draw()
text = table.concat(drawn, "\n")
check(text:find("2 / 8", 1, true) ~= nil, "CHECK counts two checked items", text)

efb_check_next()
drawn = {}
efb_draw()
text = table.concat(drawn, "\n")
check(text:find("START", 1, true) ~= nil, "CHECK advances to START")

-- ---------- page 3: fuel ----------
efb_set_page(3)
drawn = {}
ok, err = pcall(efb_draw)
check(ok, "FUEL page draws", err)
text = table.concat(drawn, "\n")
check(text:find("DISTANCE", 1, true) ~= nil, "FUEL shows distance")
check(text:find("BLOCK FUEL", 1, true) ~= nil, "FUEL shows block fuel")
check(text:find("ENDURANCE", 1, true) ~= nil, "FUEL shows endurance")

-- clamps
efb_dist(-100000)
check(EFB_CONFIG.dist_nm == 10, "distance clamps at 10 NM", EFB_CONFIG.dist_nm)
efb_dist(100000)
check(EFB_CONFIG.dist_nm == 4000, "distance clamps at 4000 NM", EFB_CONFIG.dist_nm)
efb_alt(100000)
check(EFB_CONFIG.cruise_alt_ft == 45000, "cruise level clamps at FL450", EFB_CONFIG.cruise_alt_ft)
efb_alt(-100000)
check(EFB_CONFIG.cruise_alt_ft == 5000, "cruise level clamps at 5000 ft", EFB_CONFIG.cruise_alt_ft)
efb_wind(-100000)
check(EFB_CONFIG.wind_kt == -150, "wind clamps at -150 kt", EFB_CONFIG.wind_kt)
efb_taxi(-100000)
check(EFB_CONFIG.taxi_kg == 0, "taxi fuel clamps at 0", EFB_CONFIG.taxi_kg)

-- ---------- runway condition cycling ----------
efb_set_page(1)
EFB_CONFIG.rwy_condition = 1
efb_cycle_condition()
check(EFB_CONFIG.rwy_condition == 2, "condition cycles to WET", EFB_CONFIG.rwy_condition)
efb_cycle_condition()
check(EFB_CONFIG.rwy_condition == 3, "condition cycles to CONTAM", EFB_CONFIG.rwy_condition)
efb_cycle_condition()
check(EFB_CONFIG.rwy_condition == 1, "condition wraps to DRY", EFB_CONFIG.rwy_condition)

-- ---------- tab clicks ----------
drawn = {}
efb_draw()
local rows = efb_clickable_rows()
check(#rows >= 3, "tabs registered as clickable rows", #rows)

local function click_center(r)
  MOUSE_X = (r.x1 + r.x2) / 2
  MOUSE_Y = (r.y1 + r.y2) / 2
  MOUSE_STATUS = "down"
  RESUME_MOUSE_CLICK = false
  efb_mouse_click()
end

local tab3 = rows[3]
click_center(tab3)
check(RESUME_MOUSE_CLICK == true, "tab click is consumed")
drawn = {}
efb_draw()
text = table.concat(drawn, "\n")
check(text:find("FUEL PLANNING", 1, true) ~= nil, "third tab opens FUEL")

local tab2 = rows[2]
click_center(tab2)
drawn = {}
efb_draw()
text = table.concat(drawn, "\n")
check(text:find("CHECKLISTS", 1, true) ~= nil, "second tab opens CHECK", text)

-- click outside the panel does nothing
MOUSE_X, MOUSE_Y = 5, 5
RESUME_MOUSE_CLICK = false
efb_mouse_click()
check(RESUME_MOUSE_CLICK == false, "click outside the panel is ignored")

-- ---------- panel toggle ----------
efb_toggle_panel(false)
drawn = {}
efb_draw()
check(#drawn == 0, "hidden panel draws nothing")
efb_toggle_panel(true)

print("")
if fails == 0 then
  print("ALL EFB TESTS PASSED")
  os.exit(0)
else
  print(fails .. " EFB TEST(S) FAILED")
  os.exit(1)
end
