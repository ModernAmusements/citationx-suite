--[[
  smoke_realism.lua — drive CitationX_Realism.lua through a takeoff, an
  approach, a generator loss, hot brakes, a flap overspeed and icing.

  Also asserts the whole point of the pack: it registers NO draw callback, so
  it cannot add another HUD.

  Usage:
    HOME="$TMPDIR" TMPDIR="$TMPDIR" luajit tests/smoke_realism.lua Scripts/CitationX_Realism.lua
--]]

local script = arg[1] or "Scripts/CitationX_Realism.lua"
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
SCREEN_WIDTH, SCREEN_HIGHT = 1920, 1080
SCRIPT_DIRECTORY = "/tmp/citx-test/"

local logs, played, commands = {}, {}, {}
local draw_registered = false

function dataref(name, path, mode, index)
  _G[name] = 0
  return 0
end
function dataref_table(path)
  return setmetatable({}, { __index = function() return 0 end })
end
function logMsg(s) logs[#logs + 1] = tostring(s) end
function create_command() return {} end
function add_macro() end
function do_every_frame() end
function do_every_draw() draw_registered = true end
function do_on_exit() end
function command_once(c) commands[#commands + 1] = c end
function XPLMFindDataRef() return nil end
function XPLMGetDatai() return 0 end
function load_WAV_file(path) return #played + #logs end
function play_sound(id) played[#played + 1] = id end

local function has(pattern)
  for _, line in ipairs(logs) do
    if line:find(pattern, 1, true) then return true end
  end
  return false
end

-- ---------- load ----------
local chunk = assert(loadfile(script))
chunk()

check(type(REAL_CONFIG) == "table", "REAL_CONFIG exists")
check(draw_registered == false, "realism pack registers no draw callback")
check(has("callout sounds loaded"), "callout WAVs were loaded", logs[1])

-- frame helper: advance sim time past the 0.1 s gate
local t = 0
local function frame()
  t = t + 0.2
  real_sim_time = t
  real_frame()
end

-- ---------- reset to a parked aircraft ----------
real_on_ground = 1
real_ias_kt    = 0
real_agl_m     = 0
real_vs_fpm    = 0
real_flap_rat  = 0
real_brake_fan = 0
real_gear[0]   = 1
real_gen_on[0], real_gen_on[1] = 1, 1
real_battery[0], real_battery[1] = 1, 1
real_bus_v[0]  = 28.0
real_brake_j[0] = 0
real_oat_c     = 15
real_rain      = 0
frame()

-- ---------- takeoff ----------
real_ias_kt = 130; frame()
check(not has("CALLOUT V ONE"), "no V1 callout below V1")
real_ias_kt = 136; frame()
check(has("CALLOUT V ONE"), "V1 callout at V1")
real_ias_kt = 138; frame()
local v1_count = 0
for _, l in ipairs(logs) do if l:find("CALLOUT V ONE", 1, true) then v1_count = v1_count + 1 end end
check(v1_count == 1, "V1 is called exactly once", v1_count)

real_ias_kt = 146; frame()
check(has("CALLOUT ROTATE"), "rotate callout at Vr")

-- liftoff + positive rate + gear up
real_on_ground = 0
real_agl_m     = 15        -- ~49 ft
real_vs_fpm    = 900
frame()
check(has("CALLOUT POSITIVE RATE"), "positive-rate callout after liftoff")
t = t + 2.0                -- gear-up waits two seconds after liftoff
real_gear[0] = 1           -- still down
frame()
check(has("CALLOUT GEAR UP"), "gear-up callout two seconds after liftoff")

real_agl_m = 400           -- ~1312 ft
frame()
check(has("CALLOUT ONE THOUSAND"), "one-thousand callout in the climb")

-- ---------- approach ----------
t = t + 30
real_agl_m  = 150          -- ~492 ft
real_vs_fpm = -800
real_gear[0] = 1
frame()
check(has("CALLOUT FIVE HUNDRED"), "five-hundred callout on approach")
real_agl_m = 60            -- ~197 ft
frame()
check(has("CALLOUT MINIMUMS"), "minimums callout")
real_agl_m = 25            -- ~82 ft
frame()
check(has("CALLOUT ONE HUNDRED"), "one-hundred callout")

-- ---------- brakes ----------
real_on_ground = 1
real_brake_j[0] = 6.0e6
frame()
check(real_brake_fan == 1, "brake fan switches on above 5 MJ", real_brake_fan)
check(has("CALLOUT BRAKES HOT"), "brakes-hot callout")
real_brake_j[0] = 0.5e6
frame()
check(real_brake_fan == 0, "brake fan switches off after cooling", real_brake_fan)

-- ---------- electrical load shed ----------
commands = {}
t = t + 10
real_gen_on[0], real_gen_on[1] = 1, 1
real_bus_v[0] = 28.0
frame()
real_gen_on[1] = 0          -- generator lost
real_bus_v[0] = 22.0
frame()
check(commands[1] == "laminar/CitX/electrical/cmd_load_shed_dwn",
  "load shed command fired after generator loss", commands[1])
check(has("LOAD SHED step 1"), "load shed step logged")

-- ---------- flap overspeed ----------
logs = {}
real_ias_kt   = 190
real_flap_rat = 1.0
real_gear[0]  = 0
frame()
check(has("CALLOUT FLAP OVERSPEED"), "flap overspeed callout")
frame()
local flap_hits = 0
for _, l in ipairs(logs) do if l:find("flap overspeed", 1, true) then flap_hits = flap_hits + 1 end end
check(flap_hits == 1, "flap overspeed warns once per event", flap_hits)

-- ---------- icing ----------
logs = {}
real_ias_kt   = 100
real_flap_rat = 0
real_oat_c    = 0
real_rain     = 0.5
frame()
check(has("CALLOUT ICING"), "icing callout in visible moisture below 5 C")

-- ---------- toggle ----------
real_set_enabled(false)
check(REAL_CONFIG.enabled == false, "real_set_enabled(false) disables the pack")
real_set_enabled(true)

-- ---------- report ----------
print("")
if fails == 0 then
  print("ALL REALISM TESTS PASSED")
  os.exit(0)
else
  print(fails .. " FAILURE(S)")
  os.exit(1)
end
