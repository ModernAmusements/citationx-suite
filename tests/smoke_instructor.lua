--[[
  smoke_instructor.lua — drive the flight instructor end to end.

  What this pins down:
    * the syllabus is complete (unique keys, sections, briefs, criteria)
    * every criterion is safe to evaluate against a cold aeroplane
    * the lesson state machine really runs MENU -> BRIEF -> FLYING -> DEBRIEF
    * a good ILS run scores 100% and a bad one does not
    * the best score is written to CitationX_TrainingProgress.txt
    * the instructor and the QRH trainer share one failure lifecycle
    * the panel draws in all four states without error

  Usage:
    TMPDIR="$TMPDIR" luajit tests/smoke_instructor.lua Scripts/CitationX_FlightInstructor.lua
--]]

local script = arg[1] or "Scripts/CitationX_FlightInstructor.lua"
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
local tmp = os.getenv("TMPDIR") or os.getenv("TMP") or "/tmp/"
if tmp:sub(-1) ~= "/" then tmp = tmp .. "/" end
SCRIPT_DIRECTORY = tmp .. "citationx_instructor_test/"
os.execute("mkdir -p '" .. SCRIPT_DIRECTORY .. "'")
os.execute("rm -f '" .. SCRIPT_DIRECTORY .. "CitationX_TrainingProgress.txt'")

SCREEN_WIDTH, SCREEN_HIGHT = 2560, 1440
VKEY, CKEY, MOUSE_X, MOUSE_Y = 0, "", 0, 0
MOUSE_STATUS, MOUSE_WHEEL_NUMBER, MOUSE_WHEEL_CLICKS = "up", 0, 0
PLANE_ICAO = "C750"
Control = {} ; Menu = {}

local datarefs, commands, macros = {}, {}, {}
local draw_cb, frame_cb

function dataref(name, path, mode, index)
  datarefs[#datarefs + 1] = { name = name, path = path, mode = mode, index = index }
  _G[name] = 0
end
function dataref_table(path) return setmetatable({}, { __index = function() return 0 end }) end
function get() return 0 end
function set() end
function logMsg(s) if os.getenv("VERBOSE") then print("      [log] " .. tostring(s)) end end
function create_command(name) commands[#commands + 1] = name return { name = name } end
function add_macro(name) macros[#macros + 1] = name end
function do_every_draw(f) if type(f) == "string" then draw_cb = assert(load(f)) else draw_cb = f end end
function do_every_frame(f) if type(f) == "string" then frame_cb = assert(load(f)) else frame_cb = f end end
function do_often() end
function do_sometimes() end
function do_every_second() end
function do_on_exit() end
function do_on_keystroke() end
function do_on_mouse_click() end
function do_on_mouse_wheel() end
function draw_string() end
function draw_string_Helvetica_10() end
function draw_string_Helvetica_12() end
function draw_string_Helvetica_18() end
function measure_string(t) return #tostring(t) * 7 end
function command_once() end
function toast() end
function XPLMFindDataRef(p) return { path = p } end
function XPLMGetDataf() return 0 end
function XPLMGetDatai() return 0 end
function XPLMSetDataf() end
function XPLMSetDatai() end
function XPLMSetGraphicsState() end
function glColor4f() end
function glRectf() end
function load_preferences() end
function save_preferences() end
function read_preferences() end
function float_wnd_create() return {} end
function float_wnd_set_title() end
function float_wnd_set_imgui_builder() end
function float_wnd_set_onclose() end
function float_wnd_destroy() end
function XPLMGetScreenSize() return 2560, 1440 end

-- ---------- load, in FlyWithLua order ----------
assert(loadfile("Scripts/CitationX_00_Core.lua"))()
assert(loadfile("Scripts/CitationX_FailureTrainer.lua"))()
assert(loadfile(script))()

check(type(FI_CONFIG) == "table", "FI_CONFIG exists")
check(type(FI_STYLE) == "table", "FI_STYLE exists")
check(FI_CONFIG.panel_enabled == false, "instructor panel starts hidden")

-- ---------- syllabus ----------
local lessons = fi_lessons()
check(type(lessons) == "table" and #lessons == 12, "twelve graded lessons", tostring(#lessons))

local sections = {}
for _, s in ipairs(fi_section_list()) do sections[s] = true end
check(sections["DEPARTURE"] and sections["PATTERN & LANDING"]
  and sections["INSTRUMENT"] and sections["EMERGENCY"],
  "all four syllabus sections present")

local seen, total_criteria = {}, 0
for _, lesson in ipairs(lessons) do
  local tag = "lesson " .. tostring(lesson.key)
  check(type(lesson.key) == "string" and lesson.key ~= "", tag .. " has a key")
  check(not seen[lesson.key], tag .. " key is unique", lesson.key)
  seen[lesson.key] = true
  check(type(lesson.title) == "string" and #lesson.title > 4, tag .. " has a title")
  check(type(lesson.section) == "string" and lesson.section ~= "", tag .. " has a section")
  check(type(lesson.brief) == "table" and #lesson.brief >= 2, tag .. " has a brief")
  check(type(lesson.setup) == "table" and #lesson.setup >= 2, tag .. " has a setup")
  check(type(lesson.waiting) == "string", tag .. " has a waiting hint")
  check(type(lesson.arm) == "function", tag .. " has an arm condition")
  check(type(lesson.criteria) == "table" and #lesson.criteria >= 4,
    tag .. " has at least four graded items", tostring(#lesson.criteria))
  check(type(lesson.end_when) == "function", tag .. " has an end condition")

  -- a brief is only useful if it fits the panel
  for _, line in ipairs(lesson.brief) do
    check(#line <= 60, tag .. " brief line fits the panel", line)
  end
  for _, line in ipairs(lesson.setup) do
    check(#line <= 60, tag .. " setup line fits the panel", line)
  end

  for i, c in ipairs(lesson.criteria) do
    total_criteria = total_criteria + 1
    check(type(c.label) == "string" and c.label ~= "", tag .. " item " .. i .. " has a label")
    check(type(c.hint) == "string" and c.hint ~= "", tag .. " item " .. i .. " has a hint")
    check(type(c.check) == "function", tag .. " item " .. i .. " has a check")
    check(#c.label <= 34, tag .. " item " .. i .. " label fits the row", c.label)
  end
end
check(total_criteria >= 50, "syllabus has a real number of graded items",
  tostring(total_criteria))

-- ---------- commands and macros ----------
local cmd_set = {}
for _, n in ipairs(commands) do cmd_set[n] = true end
for _, n in ipairs({ "CitationXInstructor/toggle_panel", "CitationXInstructor/finish",
                     "CitationXInstructor/menu", "CitationXInstructor/start_next" }) do
  check(cmd_set[n] == true, "command registered: " .. n)
end
for _, lesson in ipairs(lessons) do
  check(cmd_set["CitationXInstructor/lesson_" .. lesson.key] == true,
    "command registered: lesson_" .. lesson.key)
end
check(#macros >= 4, "menu macros registered", tostring(#macros))

-- ---------- every check survives a cold, parked aeroplane ----------
-- All fi_* datarefs read 0 here, i.e. a cold and dark C750.
local S0 = { met = {}, hold = {}, elapsed = 0, vref = 110, vr = 116, v2 = 129 }
for _, d in ipairs(datarefs) do _G[d.name] = 0 end
local V0 = fi_snapshot()
for _, lesson in ipairs(lessons) do
  local ok_arm, err_arm = pcall(lesson.arm, V0, S0)
  check(ok_arm, "lesson " .. lesson.key .. " arm() is safe", err_arm)
  for i, c in ipairs(lesson.criteria) do
    local ok, err = pcall(c.check, V0, S0)
    check(ok, "lesson " .. lesson.key .. " item " .. i .. " check() is safe", err)
  end
end

-- ---------- the state machine ----------
fi_toggle_panel(true)
check(FI_CONFIG.panel_enabled == true, "panel opens")
local st = fi_state()
check(st == 1, "opening the panel shows the lesson list", tostring(st))

fi_brief("ils")
st = fi_state()
check(st == 2, "fi_brief() moves to the brief", tostring(st))
check(type(draw_cb) == "function", "draw callback registered")

fi_start("ils")
st = fi_state()
check(st == 3, "fi_start() moves to flying", tostring(st))

-- Fly a perfect ILS: descend through the graded windows with the needles
-- centred, then touch down. Time advances 0.25 s per frame.
local t = 100.0
local function frame(agl, ias, fpm, hdef, vdef, extra)
  t = t + 0.25
  fi_time = t
  fi_agl_m = agl / 3.28084
  fi_elev_m = 900 / 3.28084
  fi_ias = ias
  fi_gs = ias * 0.514444          -- the dataref is m/s; the script converts to kt
  fi_fpm = fpm
  fi_hdef = hdef or 0
  fi_vdef = vdef or 0
  fi_gear = 1
  fi_flap = 1.0
  fi_n1_l, fi_n1_r = 62, 62
  fi_ap_on = 0
  fi_on_ground = 0
  if extra then extra() end
  frame_cb()
end

-- Not armed yet: too high.
frame(3000, 160, -800, 0, 0, function() fi_ap_on = 1 fi_flap = 0.75 end)
st = fi_state()
check(st == 3, "still flying while waiting to arm")

-- Armed once inside 800-4500 ft AGL with the needles alive.
for agl = 2800, 1200, -100 do
  frame(agl, 145, -700, 0)   -- on glideslope, configuring
end
check(select(3, fi_state()) == 0, "nothing graded yet above 1,100 ft")

-- Gear and full flaps inside the 900-1,100 ft window, held long enough to
-- count: four frames.
for agl = 1050, 900, -50 do
  frame(agl, 135, -700, 0.1, 0.1)
end

-- Through the 420-540 ft window: five frames for the localiser, glideslope,
-- Vref and sink-rate items.
for agl = 600, 400, -25 do
  frame(agl, 118, -700, 0.2, 0.3)
end

-- Hand-flown below 175 ft with the autopilot out.
for agl = 170, 100, -20 do
  frame(agl, 116, -640, 0.05, 0.05)
end

-- Touchdown, with enough ground frames for the 0.6 s hold to mature.
frame(30, 113, -300, 0, 0, function() fi_on_ground = 1 fi_gs = 40 end)
frame(20, 112, -140, 0, 0, function() fi_on_ground = 1 fi_gs = 25 end)
frame(10, 110, -130, 0, 0, function() fi_on_ground = 1 fi_gs = 10 end)
frame(0, 100, -120, 0, 0, function() fi_on_ground = 1 fi_gs = 3 end)
frame(0, 80, 0, 0, 0, function() fi_on_ground = 1 fi_gs = 0 end)

st = fi_state()
check(st == 4, "touchdown ends the lesson in the debrief", tostring(st))
local _, key, pct = fi_state()
check(key == "ils", "debrief keeps the lesson", tostring(key))
check(pct == 100, "a clean ILS scores 100%", tostring(pct))
check(fi_best("ils") == 100, "best score recorded in memory", tostring(fi_best("ils")))

-- The progress file must be on disk and readable.
local fh = io.open(SCRIPT_DIRECTORY .. "CitationX_TrainingProgress.txt", "r")
check(fh ~= nil, "progress file written")
if fh then
  local body = fh:read("*a")
  fh:close()
  check(body:find("ils=100", 1, true) ~= nil, "progress file records ils=100", body)
end

-- ---------- a bad run does not score well ----------
fi_start("visual")
for agl = 2500, 100, -100 do
  frame(agl, 200, -1500, 0)      -- too fast, too steep
end
frame(20, 150, -900, 0, 0, function() fi_on_ground = 1 fi_gs = 40 end)
frame(0, 60, -900, 0, 0, function() fi_on_ground = 1 fi_gs = 3 end)
local _, _, bad_pct = fi_state()
check(fi_state() == 4, "the bad run also debriefs")
check(bad_pct < 50, "a bad run scores below 50%", tostring(bad_pct))

-- ---------- waiting state is honest ----------
fi_start("pattern")
fi_on_ground = 1
fi_agl_m = 0
fi_ias = 0
frame_cb()
check(select(3, fi_state()) == 0, "a parked aeroplane scores nothing")
check(type(draw_cb) == "function", "draw survives the waiting state")
local ok_draw = pcall(draw_cb)
check(ok_draw, "panel draws while waiting for the setup")

-- ---------- failure lifecycle is shared with the QRH ----------
fi_menu()
fi_start("engfail_tkof")
check(type(qrh_active_key) == "function", "QRH exposes qrh_active_key()")
check(qrh_active_key() == nil, "no failure before the lesson arms")

-- Arm during a takeoff roll, exactly as the lesson expects.
fi_on_ground, fi_agl_m, fi_ias = 1, 0, 100
fi_gs, fi_fpm = 100, 0
fi_time = t + 1
frame_cb()
check(qrh_active_key() == nil, "no failure while still on the runway")

-- Rotate and climb through 400 ft: the instructor fails the left engine.
fi_on_ground = 0
fi_agl_m = 450 / 3.28084
fi_ias, fi_gs = 150, 150
fi_time = t + 1.25
frame_cb()
check(qrh_active_key() == "flameout_l", "the lesson injects the flameout at 400 ft",
  tostring(qrh_active_key()))
check(qrh_is_complete() == false, "QRH starts incomplete")

fi_menu()
check(qrh_active_key() == nil, "leaving the lesson clears the injected failure")

-- ---------- panel interaction ----------
fi_toggle_panel(true)
fi_menu()
MOUSE_STATUS = "down"
MOUSE_X, MOUSE_Y = FI_CONFIG.panel_x + 20,
  (FI_CONFIG.panel_top or 500) - 10
RESUME_MOUSE_CLICK = false
fi_mouse_click()
check(RESUME_MOUSE_CLICK == true, "header press is consumed")
MOUSE_STATUS = "up"
fi_mouse_click()

MOUSE_STATUS = "down"
MOUSE_X, MOUSE_Y = 5, 5
RESUME_MOUSE_CLICK = false
fi_mouse_click()
check(RESUME_MOUSE_CLICK == false, "click outside the panel is not consumed")

fi_toggle_panel(false)
check(FI_CONFIG.panel_enabled == false, "panel closes")

-- ---------- report ----------
print("")
if fails == 0 then
  print("ALL FLIGHT INSTRUCTOR TESTS PASSED")
  os.exit(0)
else
  print(fails .. " FAILURE(S)")
  os.exit(1)
end
