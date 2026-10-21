--[[
  check_datarefs.lua — static DataRef validator for FlyWithLua scripts.

  FlyWithLua quarantines a whole script when a scalar dataref() call binds a
  missing dataref or an ARRAY dataref (float[N], int[N], byte[N]). This harness
  reproduces that check offline so you know before launching X-Plane.

  Usage:
    lua tests/check_datarefs.lua <DataRefs.txt> <file.lua> [more.lua ...]

  Exit code 0 when every declaration is legal, 1 otherwise.
--]]

local datarefs_path = arg[1]
if not datarefs_path then
  io.stderr:write("usage: lua tests/check_datarefs.lua <DataRefs.txt> <file.lua> ...\n")
  os.exit(2)
end

-- ---------- load the authoritative dataref table ----------
local types = {}      -- path -> type string ("float", "float[13]", "int", ...)
local replaced = {}   -- path -> true when X-Plane marks it REPLACED

do
  local fh, err = io.open(datarefs_path, "r")
  if not fh then
    io.stderr:write("cannot open " .. datarefs_path .. ": " .. tostring(err) .. "\n")
    os.exit(2)
  end
  for line in fh:lines() do
    local name, typ, _w, _unit, desc = line:match("^(%S+)%s+(%S+)%s+([yn])%s+([^%s]+)%s+(.*)$")
    if not name then
      name, typ = line:match("^(%S+)%s+(%S+)%s+([yn])%s+$")
    end
    if name then
      types[name] = typ
      if desc and desc:find("REPLACED", 1, true) then replaced[name] = true end
    end
  end
  fh:close()
end

local function is_array(typ)
  return typ ~= nil and typ:find("%[%d+%]") ~= nil
end

-- ---------- scan a script ----------
local problems, checked, notes = 0, 0, 0

local function scan_file(file)
  local fh, err = io.open(file, "r")
  if not fh then
    io.stderr:write("cannot open " .. file .. ": " .. tostring(err) .. "\n")
    problems = problems + 1
    return
  end
  local lineno = 0
  for line in fh:lines() do
    lineno = lineno + 1
    -- scalar binding: dataref("var", "path", "mode"[, index])
    local var, path, mode, idx = line:match('dataref%s*%(%s*"([^"]*)"%s*,%s*"([^"]+)"%s*,%s*"([^"]*)"%s*,%s*(%d+)')
    if not path then
      var, path, mode = line:match('dataref%s*%(%s*"([^"]*)"%s*,%s*"([^"]+)"%s*,%s*"([^"]*)"')
    end
    if path then
      checked = checked + 1
      local has_index = idx ~= nil
      local typ = types[path]
      if not typ then
        -- runtime-registered aircraft datarefs are not in DataRefs.txt
        if not path:match("^laminar/") and not path:match("^kp/") and not path:match("^CitX") then
          print(string.format("MISSING  %s:%d  %s  (var %s)", file, lineno, path, var))
          problems = problems + 1
        end
      elseif is_array(typ) then
        if has_index then
          notes = notes + 1 -- legal: bound to element idx-1
        else
          print(string.format("ARRAY    %s:%d  %s  type %s  (var %s) -- array ref bound without an index",
            file, lineno, path, typ, var))
          problems = problems + 1
        end
      elseif replaced[path] then
        print(string.format("REPLACED %s:%d  %s  (var %s)", file, lineno, path, var))
        notes = notes + 1
      end
    end
    -- table binding: dataref_table("path") is the legal form for arrays
    local tpath = line:match('dataref_table%s*%(%s*"([^"]+)"')
    if tpath then
      checked = checked + 1
      if not types[tpath] and not tpath:match("^laminar/") and not tpath:match("^kp/") then
        print(string.format("MISSING  %s:%d  %s  (dataref_table)", file, lineno, tpath))
        problems = problems + 1
      end
    end
  end
  fh:close()
end

for i = 2, #arg do scan_file(arg[i]) end

print(string.format("checked %d declaration(s): %d problem(s), %d replaced-ref note(s)",
  checked, problems, notes))
os.exit(problems == 0 and 0 or 1)
