-- ============================================================================
--  CESSNA CITATION X FLIGHT INSTRUCTOR — SETUP WATCHER
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  A diagnostic, not a panel and not part of the graded suite. While the flight
--  instructor panel is open it writes one tab-separated line per second to
--  Scripts/CitationX_InstructorWatch.csv:
--
--    sim time, lat, lon, elevation, radio altitude, local x/y/z, true heading,
--    IAS, ground speed, gear, flap, autopilot, NAV1, instructor state,
--    SETUP result, SET ME UP target, note
--
--  The note column marks a position jump ("JUMP 7.42nm") and instructor state
--  changes ("STATE 2>3"), so a SET ME UP press is obvious even if the aircraft
--  ends up somewhere unexpected. The target column is what the setup aimed at:
--    lat,lon,elevation_ft,true_heading
--
--  Delete this file, or set WATCH_CONFIG.enabled = false, when you are done.
--  It binds only read-only datarefs, so it cannot quarantine another script.
-- ============================================================================

WATCH_CONFIG = {
    enabled  = true,
    max_rows = 20000,   -- about 5.5 hours at 1 Hz
}

-- Only these are not already bound by CitationX_FlightInstructor.lua.
dataref("wx_lat", "sim/flightmodel/position/latitude", "readonly")
dataref("wx_lon", "sim/flightmodel/position/longitude", "readonly")
dataref("wx_lx", "sim/flightmodel/position/local_x", "readonly")
dataref("wx_ly", "sim/flightmodel/position/local_y", "readonly")
dataref("wx_lz", "sim/flightmodel/position/local_z", "readonly")
dataref("wx_nav1", "sim/cockpit2/radios/actuators/nav1_frequency_hz", "readonly")
dataref("wx_vx", "sim/flightmodel/position/local_vx", "readonly")
dataref("wx_vy", "sim/flightmodel/position/local_vy", "readonly")
dataref("wx_vz", "sim/flightmodel/position/local_vz", "readonly")

local watch = {
    rows = 0,
    last_lat = nil,
    last_lon = nil,
    last_state = nil,
    last_setup = nil,
    failed = false,
}

local function watch_path()
    return (SCRIPT_DIRECTORY or "") .. "CitationX_InstructorWatch.csv"
end

local function watch_start()
    local fh = io.open(watch_path(), "w")
    if not fh then
        watch.failed = true
        logMsg("Citation X Instructor watcher: cannot write " .. watch_path())
        return
    end
    fh:write("sim_t\tlat\tlon\telev_ft\tagl_ft\tlocal_x\tlocal_y\tlocal_z"
        .. "\tpsi\tias\tgs\tgear\tflap\tap\tnav1\tstate\tsetup\ttarget\tnote"
        .. "\tweight_lb\tpayload_lb\tfuel_lb\ttheta\tphi\tvx\tvy\tvz\tonground\n")
    fh:close()
end

function watch_log()
    if not WATCH_CONFIG.enabled or watch.failed then return end
    if watch.rows >= (WATCH_CONFIG.max_rows or 20000) then return end
    -- Only while the instructor is actually on screen, and only in the C750.
    if PLANE_ICAO ~= "C750" then return end
    if type(FI_CONFIG) ~= "table" or not FI_CONFIG.panel_enabled then return end

    local lat, lon = wx_lat or 0, wx_lon or 0
    local note = ""
    if watch.last_lat and watch.last_lon then
        local dn = (lat - watch.last_lat) * 111320.0
        local de = (lon - watch.last_lon) * 111320.0 * math.cos(math.rad(lat))
        local nm = math.sqrt(dn * dn + de * de) / 1852.0
        if nm > 0.20 then note = string.format("JUMP %.2fnm", nm) end
    end
    watch.last_lat, watch.last_lon = lat, lon

    local state = nil
    if type(fi_state) == "function" then state = fi_state() end
    if state and watch.last_state and state ~= watch.last_state then
        note = (note ~= "" and (note .. " ")) or ""
        note = note .. string.format("STATE %s>%s",
            tostring(watch.last_state), tostring(state))
    end
    watch.last_state = state

    local setup = (type(fi_setup_status) == "function")
        and tostring(fi_setup_status()) or ""
    if watch.last_setup and setup ~= watch.last_setup then
        note = (note ~= "" and (note .. " ")) or ""
        note = note .. "SETUP-CHANGED"
    end
    watch.last_setup = setup
    local target = (type(fi_setup_target) == "function")
        and tostring(fi_setup_target()) or ""

    local line = string.format("%.1f\t%.7f\t%.7f\t%.1f\t%.1f\t%.3f\t%.3f\t%.3f"
        .. "\t%.1f\t%.1f\t%.1f\t%d\t%.2f\t%d\t%d\t%s\t%s\t%s\t%s"
        .. "\t%.0f\t%.0f\t%.0f\t%.1f\t%.1f\t%.2f\t%.2f\t%.2f\t%d\n",
        fi_time or 0, lat, lon,
        (fi_elev_m or 0) * 3.28084, (fi_agl_m or 0) * 3.28084,
        wx_lx or 0, wx_ly or 0, wx_lz or 0,
        fi_psi or 0, fi_ias or 0, (fi_gs or 0) * 1.94384,
        fi_gear or 0, fi_flap_handle or 0, fi_ap_on or 0, wx_nav1 or 0,
        tostring(state or ""), setup, target, note,
        (fi_weight_kg or 0) * 2.20462, (fi_payload_kg or 0) * 2.20462,
        (fi_fuel_kg or 0) * 2.20462,
        fi_pitch or 0, fi_roll or 0, wx_vx or 0, wx_vy or 0, wx_vz or 0,
        fi_on_ground or 0)

    local fh = io.open(watch_path(), "a")
    if not fh then watch.failed = true return end
    fh:write(line)
    fh:close()
    watch.rows = watch.rows + 1
end

if WATCH_CONFIG.enabled then
    watch_start()
    do_often("watch_log()")
    logMsg("Citation X Instructor watcher: " .. watch_path())
end
