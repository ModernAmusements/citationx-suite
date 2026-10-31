--[[
  smoke_checklist.lua — parse the pilot's real Xchecklist file the way the EFB
  does, and check the dataref-expression engine that ticks items.

  The EFB reads <aircraft>/clist.txt (the exact file Xchecklist loads), so this
  test pins the parser to that file when it is present and falls back to the
  bundled Xchecklist copy otherwise.

  Usage:
    TMPDIR="$(mktemp -d)/" luajit tests/smoke_checklist.lua
--]]

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

local function bytes_of(s)
  local t = {}
  for i = 1, #s do t[i - 1] = s:byte(i) end
  return t
end

local ACF = "Aircraft/Cessna Citation X_mods/Cessna_CitationX.acf"
local acf_bytes = bytes_of(ACF)

-- dataref values the "copilot" reads; nil = dataref not found
local live = {
  ["laminar/CitX/brakes/park_handle"] = 1,
  ["laminar/CitX/hydraulics/aux_pump"] = 0,
  ["laminar/CitX/lights/navigation"] = 1,
}
local handles = {}
local function handle_for(path)
  if live[path] == nil then return nil end
  handles[path] = handles[path] or { path = path }
  return handles[path]
end

function dataref(name) _G[name] = 0; return 0 end
function dataref_table(path)
  if path == "sim/aircraft/view/acf_relative_path" then return acf_bytes end
  return {}
end
function draw_string() end
function measure_string(t) return #tostring(t) * 7 end
function glColor4f() end
function glRectf() end
function XPLMSetGraphicsState() end
function create_command() end
function add_macro() end
function do_every_draw() end
function do_on_mouse_click() end
function command_once() end
function logMsg() end
function XPLMFindDataRef(path) return handle_for(path) end
function XPLMGetDataf(h) return h and live[h.path] or 0 end
function XPLMGetDatai(h) return math.floor((h and live[h.path] or 0) + 0.5) end

SCRIPT_DIRECTORY = os.getenv("PWD") .. "/"

local chunk = assert(loadfile("Scripts/CitationX_EFB.lua"))
chunk()

-- ---------- the file itself ----------
local phases = efb_checklists()
check(type(phases) == "table", "efb_checklists() returns the parsed list")
check(#phases >= 10, "the checklist has its phases", #phases)

local items, with_condition = 0, 0
local names = {}
for _, p in ipairs(phases) do
  names[p.name] = true
  items = items + #p.items
  for _, it in ipairs(p.items) do
    if it.live then with_condition = with_condition + 1 end
  end
end
check(items >= 150, "every sw_item line became an item", items)
check(with_condition >= 100, "dataref conditions were parsed", with_condition)
check(names["ENGINE START"] == true, "phase ENGINE START is present")
check(names["BEFORE TAKEOFF"] == true, "phase BEFORE TAKEOFF is present")
check(names["SHUTDOWN"] == true, "phase SHUTDOWN is present")

-- colour codes and the |value column must not leak into the caption
local dirty = 0
for _, p in ipairs(phases) do
  for _, it in ipairs(p.items) do
    if it.text:find("\\", 1, true) or it.text:find("|", 1, true) or it.text == "" then
      dirty = dirty + 1
    end
  end
end
check(dirty == 0, "captions are clean (no colour tags / value column)", dirty)

-- ---------- live expression engine ----------
local function find(pred)
  for _, p in ipairs(phases) do
    for _, it in ipairs(p.items) do
      if pred(it) then return it end
    end
  end
end

local park_on = find(function(it)
  return it.live and it.text == "Parking Brake" and it.condition:find("1", 1, true)
end)
check(park_on ~= nil, "the 'Parking Brake ON' item carries its condition")
if park_on then
  live["laminar/CitX/brakes/park_handle"] = 1
  check(efb_item_live(park_on) == true, "parking brake ON ticks itself")
  live["laminar/CitX/brakes/park_handle"] = 0
  check(efb_item_live(park_on) == false, "parking brake OFF leaves it open")
end

local nav = find(function(it)
  return it.live and it.text == "Navigation Light"
end)
check(nav ~= nil, "the navigation-light item carries its condition")
if nav then
  check(efb_item_live(nav) == true, "navigation light ON ticks itself")
end

-- && / || / parentheses / intervals
local function term(expr)
  return efb_eval_expr(expr)
end
live["a/x"] = 1
live["b/y"] = 1
live["c/z"] = 5
check(term("a/x:1 && b/y:1") == true, "&& combines two true terms")
check(term("a/x:0 && b/y:1") == false, "&& requires both terms")
check(term("a/x:0 || b/y:1") == true, "|| accepts one true term")
check(term("(a/x:0) || (b/y:1)") == true, "parentheses group || terms")
check(term("(a/x:1) && (b/y:1)") == true, "parentheses group && terms")
check(term("c/z:1|10") == true, "interval test accepts an inside value")
check(term("c/z:20|30") == false, "interval test rejects an outside value")
check(term("c/z:<10") == true, "< compares")
check(term("c/z:>=5") == true, ">= compares")
check(term("c/z:!4") == true, "! compares")
check(term("c/z:><1") == false, "history tests never auto-tick")
check(term("missing/ref:1") == false, "an unknown dataref never ticks")

-- a half-filled condition must not break the panel
live["d/w"] = 2
check(term("d/w:1 && ") == false, "trailing && is handled")

print("")
if fails == 0 then
  print("ALL CHECKLIST TESTS PASSED")
  os.exit(0)
else
  print(fails .. " CHECKLIST TEST(S) FAILED")
  os.exit(1)
end
