--[[
  fwl_imgui_capture.lua — compact ImGui recorder for the legacy smoke tests.

  dofile() this AFTER a harness has installed its FlyWithLua mocks but BEFORE it
  loads the converted panels. It installs a recording `imgui` table and a global
  `ImgCap` with the captured calls, so an old GL-drawing assertion can be
  replaced with a builder-content assertion without rewriting the whole harness.

  The shared, fuller harness is tests/fwl_imgui_mock.lua; this file is only for
  the existing behaviour harnesses that already own their own dataref mocks.
--]]

ImgCap = {
  text = {}, buttons = {}, vars = {}, colors = {}, fonts = {},
  push_color = 0, pop_color = 0, push_var = 0, pop_var = 0,
  push_font = 0, pop_font = 0, click_id = nil,
}

function ImgCap.reset()
  ImgCap.text, ImgCap.buttons = {}, {}
  ImgCap.vars, ImgCap.colors, ImgCap.fonts = {}, {}, {}
  ImgCap.push_color, ImgCap.pop_color = 0, 0
  ImgCap.push_var, ImgCap.pop_var = 0, 0
  ImgCap.push_font, ImgCap.pop_font = 0, 0
  ImgCap.click_id = nil
end

-- Set a button id that the next builder call should report as clicked.
function ImgCap.click(id)
  ImgCap.click_id = id
end

function ImgCap.joined()
  return table.concat(ImgCap.text, "\n") .. "\n" .. table.concat(ImgCap.buttons, "\n")
end

function ImgCap.has(word)
  return ImgCap.joined():find(word, 1, true) ~= nil
end

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
  ImgCap.push_color = ImgCap.push_color + 1
  ImgCap.colors[id] = col
end
function imgui.PopStyleColor() ImgCap.pop_color = ImgCap.pop_color + 1 end
function imgui.PushStyleVar(id, a, b)
  ImgCap.push_var = ImgCap.push_var + 1
  ImgCap.vars[id] = a
end
function imgui.PushStyleVar_2(id, a, b)
  ImgCap.push_var = ImgCap.push_var + 1
  ImgCap.vars[id] = a
end
function imgui.PopStyleVar() ImgCap.pop_var = ImgCap.pop_var + 1 end
function imgui.PushFont(name)
  ImgCap.push_font = ImgCap.push_font + 1
  ImgCap.fonts[name] = true
end
function imgui.PopFont() ImgCap.pop_font = ImgCap.pop_font + 1 end
function imgui.TextUnformatted(t) ImgCap.text[#ImgCap.text + 1] = tostring(t) end
function imgui.Text(t) ImgCap.text[#ImgCap.text + 1] = tostring(t) end
function imgui.TextColored(_, t) ImgCap.text[#ImgCap.text + 1] = tostring(t) end
function imgui.ProgressBar() end
function imgui.Spacing() end
function imgui.Separator() end
function imgui.SameLine() end
function imgui.Dummy() end
function imgui.NewLine() end
function imgui.BeginChild() end
function imgui.EndChild() end
local function im_button(label)
  label = tostring(label)
  ImgCap.buttons[#ImgCap.buttons + 1] = label
  local id = label:match("###(.+)")
  return id ~= nil and id == ImgCap.click_id
end
function imgui.Button(label) return im_button(label) end
function imgui.InvisibleButton(label) return im_button(label) end

-- Floating-window stubs. The converted panels create their ImGui window at
-- load; harnesses that did not mock these need no-ops here. Existing harness
-- stubs are preserved.
float_wnd_create = float_wnd_create or function() return {} end
float_wnd_set_title = float_wnd_set_title or function() end
float_wnd_set_position = float_wnd_set_position or function() end
float_wnd_set_imgui_builder = float_wnd_set_imgui_builder or function() end
float_wnd_set_onclose = float_wnd_set_onclose or function() end
float_wnd_set_ondraw = float_wnd_set_ondraw or function() end
float_wnd_set_onclick = float_wnd_set_onclick or function() end
float_wnd_set_visible = float_wnd_set_visible or function() end
float_wnd_bring_to_front = float_wnd_bring_to_front or function() end
float_wnd_destroy = float_wnd_destroy or function() end

ImgCap.reset()
