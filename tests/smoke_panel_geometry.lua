--[[
  smoke_panel_geometry.lua — verify every suite panel fits and stays in style.

  Since 2026-11-22 all panels are ImGui floating windows built with CXUI. There
  are no GL rectangles or hand-rolled hit tests left to measure, so this harness
  now checks the equivalent ImGui invariants:

    * every window fits inside the screen
    * every builder balances its style/font stacks
    * all rounding style variables are zero (square corners)
    * only the regular Neo Grotesque aliases are pushed
    * no orange is pushed anywhere
    * each panel exposes its expected controls

  Usage:
    luajit tests/smoke_panel_geometry.lua
--]]

local M = dofile("tests/fwl_imgui_mock.lua")
M.setup({ width = 2560, height = 1440, aircraft = "C750" })

local scripts = {
  "Scripts/CitationX_00_Core.lua",
  "Scripts/CitationX_00_ImGuiKit.lua",
  "Scripts/CitationX_01_ControlCenter.lua",
  "Scripts/CitationX_MasterSuite.lua",
  "Scripts/CitationX_Realism.lua",
  "Scripts/CitationX_CabinOps.lua",
  "Scripts/CitationX_FailureTrainer.lua",
  "Scripts/CitationX_FlightInstructor.lua",
  "Scripts/CitationX_InstructorWatch.lua",
}
for _, path in ipairs(scripts) do
  local ok, err = pcall(M.load, path)
  M.check(ok, "loads " .. path, err)
end

-- ---------------------------------------------------------------- windows ----
M.check(#M.windows == 6, "one ImGui window per suite panel", #M.windows)

local titles = {}
for _, wnd in ipairs(M.windows) do
  titles[#titles + 1] = wnd.title
  M.check(wnd.w > 200 and wnd.h > 200,
    "window has sane dimensions: " .. tostring(wnd.title),
    tostring(wnd.w) .. "x" .. tostring(wnd.h))
  local x, y = wnd.x or 0, wnd.y or 0
  M.check(x >= 0 and y >= 0,
    "window origin is on screen: " .. tostring(wnd.title),
    x .. "," .. y)
  M.check(x + (wnd.w or 0) <= 2560 and y + (wnd.h or 0) <= 1440,
    "window fits inside the screen: " .. tostring(wnd.title),
    (x + (wnd.w or 0)) .. "," .. (y + (wnd.h or 0)))
end

local expected_titles = {
  "Citation X Control Center", "Citation X Master Suite",
  "Citation X Realism", "Citation X Cabin Ops",
  "Citation X QRH Trainer", "Citation X Flight Instructor",
}
for _, title in ipairs(expected_titles) do
  local found = false
  for _, actual in ipairs(titles) do
    if actual == title then found = true end
  end
  M.check(found, "panel window exists: " .. title)
end

-- ---------------------------------------------------------------- builders ---
-- Open every panel (the Control Center is the only one visible at load).
if SUITE_MODULES then
  for _, m in ipairs(SUITE_MODULES) do
    if m.key == "status" then pcall(m.set, true) end
  end
end
CONFIG.axis_optimizer_enabled = true
REAL_CONFIG.enabled = true
REAL_CONFIG.hud_enabled = true
CAB_CONFIG.panel_enabled = true
TRAINER_CONFIG.panel_enabled = true
FI_CONFIG.panel_enabled = true

local panels = {
  { builder = "cc_on_build",               title = "Control Center",  ids = { "cc_status", "cc_hide" } },
  { builder = "citationx_on_build",        title = "Master Suite",    ids = { "hub_tab_control", "hub_tab_flows", "hub_hide" } },
  { builder = "real_on_build",             title = "Realism",         ids = { "real_hide" } },
  { builder = "cab_on_build",              title = "Cabin Ops",       ids = { "cab_gpu", "cab_hide" } },
  { builder = "qrh_on_build",              title = "QRH Trainer",     ids = { "qrh_random", "qrh_hide" } },
  { builder = "fi_on_build",               title = "Flight Instructor", ids = { "fi_hide" } },
}

for _, panel in ipairs(panels) do
  M.reset_capture()
  local ok, err = pcall(M.build, panel.builder)
  M.check(ok, panel.title .. " builder runs", err)

  local content = #M.text + #M.buttons
  M.check(content > 8, panel.title .. " builder draws real content", content)
  M.check_stacks_balanced()
  M.check_apple_style()

  for _, id in ipairs(panel.ids) do
    M.check(M.has_button(id), panel.title .. " has control: " .. id)
  end
end

-- The AXIS MONITOR is a dark ImGui section; it must never push a white border
-- colour or leave a GL primitive behind.
CONFIG.axis_monitor = true
M.reset_capture()
local ok_ax, err_ax = pcall(M.build, "citationx_on_build")
M.check(ok_ax, "AXIS MONITOR section builds", err_ax)
M.check(M.has_text("AXIS MONITOR"), "AXIS MONITOR section is present")
for id, col in pairs(M.colors) do
  local r, g, b = M.rgb(col)
  M.check(not (r > 220 and g > 220 and b > 220),
    "AXIS MONITOR pushes no white border: colour " .. tostring(id),
    string.format("#%02X%02X%02X", r, g, b))
end
M.check_stacks_balanced()
M.check_apple_style()

-- ---------------------------------------------------------------- report -----
M.report("PANEL GEOMETRY")
