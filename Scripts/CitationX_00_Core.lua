-- ============================================================================
--  CESSNA CITATION X SUITE — SHARED CORE
--  X-Plane 12  |  FlyWithLua NG+ (2.8+)
-- ----------------------------------------------------------------------------
--  Loads first. FlyWithLua loads Scripts/*.lua in alphabetical order and
--  "CitationX_00_Core.lua" sorts before every panel, so this file owns the
--  suite's single copy of the palette and the drawing primitives. Panels keep
--  their own geometry, content and state; they only stop duplicating colours
--  and text/rect plumbing.
--
--  Palette: the Modern Amusement dark field from
--  MA_WEBSITE/src/styles/globals.scss (`[data-theme='dark']`):
--    #0a0a0a body · #141414 card · #171717 header · #ffffff ink
--    #a3a3a3 muted · #ff6600 accent · #2ecc71 ok · #e67e22 warn
--    #e74c3c bad · rgba(255,255,255,.35) hairline rules
--  The one deliberate deviation is the bottom bar: `footer_bg` is brand green
--  with near-black `footer_fg`, per the 2026-11-12 request.
--
--  Prefix: CX / cx_*. This file declares no datarefs, commands or callbacks,
--  so it cannot quarantine a panel and never writes to the sim.
-- ============================================================================

CX = {
    -- Surfaces -------------------------------------------------------------
    bg        = {0.04, 0.04, 0.04, 0.95},   -- #0a0a0a
    bg_alt    = {0.08, 0.08, 0.08, 0.92},   -- #141414
    header_bg = {0.09, 0.09, 0.09, 0.97},   -- #171717
    btn       = {0.09, 0.09, 0.09, 1.00},   -- key / button surface
    border    = {1.00, 1.00, 1.00, 0.55},
    hairline  = {1.00, 1.00, 1.00, 0.22},   -- --field-line
    track     = {0.12, 0.12, 0.12, 1.00},   -- gauge trough

    -- Ink ------------------------------------------------------------------
    title     = {1.00, 1.00, 1.00, 1.00},
    value     = {1.00, 1.00, 1.00, 1.00},
    label     = {0.90, 0.90, 0.90, 1.00},
    sub       = {0.64, 0.64, 0.64, 1.00},   -- #a3a3a3
    dim       = {0.52, 0.52, 0.52, 1.00},

    -- Status ---------------------------------------------------------------
    ok        = {0.18, 0.80, 0.44, 1.00},   -- #2ecc71
    warn      = {0.90, 0.49, 0.13, 1.00},   -- #e67e22
    bad       = {0.91, 0.30, 0.24, 1.00},   -- #e74c3c
    accent    = {1.00, 0.40, 0.00, 1.00},   -- #ff6600

    -- Bottom bar -----------------------------------------------------------
    footer_bg = {0.18, 0.80, 0.44, 0.96},   -- green strip
    footer_fg = {0.04, 0.04, 0.04, 1.00},   -- near-black label on green

    -- Diagnostics ----------------------------------------------------------
    mon_bg    = {0.02, 0.05, 0.03, 0.92},
    mon       = {0.18, 0.80, 0.44, 1.00},
}
CX.alert      = CX.bad                      -- panels that call it "alert"
CX.header_act = {0.16, 0.05, 0.04, 0.96}    -- QRH active-procedure header

-- --------------------------------------------------------------- DRAWING ----
-- FlyWithLua's y grows upward: y0 is the bottom edge, y1 the top edge.

function cx_color(col, alpha)
    glColor4f(col[1], col[2], col[3], alpha or col[4] or 1.0)
end

-- Two-corner rectangle.
function cx_bar(x0, y0, x1, y1, col, alpha)
    cx_color(col, alpha)
    glRectf(x0, y0, x1, y1)
end

-- Left edge + bottom/top + width, the order the panel shells already use.
function cx_bar_w(x, y0, y1, w, col, alpha)
    cx_bar(x, y0, x + w, y1, col, alpha)
end

-- Helvetica faces: 18 titles, 12 rows, 10 captions.
function cx_font(size)
    if size == 18 then return draw_string_Helvetica_18 or draw_string end
    if size == 10 then return draw_string_Helvetica_10 or draw_string end
    return draw_string_Helvetica_12 or draw_string
end

function cx_measure(text, size)
    local s = tostring(text or "")
    if size then
        return measure_string(s, "Helvetica_" .. tostring(size)) or measure_string(s)
    end
    return measure_string(s)
end

function cx_text(x, y, text, size, col)
    cx_color(col)
    cx_font(size or 12)(x, y, tostring(text or ""))
end

function cx_text_right(right_x, y, text, size, col)
    local sz = size or 12
    cx_text(right_x - cx_measure(text, sz), y, text, sz, col)
end

-- Truncate to max_px with an ellipsis. `size` selects the Helvetica face.
function cx_fit(text, max_px, size)
    local s = tostring(text or "")
    if cx_measure(s, size) <= max_px then return s end
    while #s > 1 and cx_measure(s .. "...", size) > max_px do
        s = s:sub(1, -2)
    end
    return s .. "..."
end

-- ------------------------------------------------------------ BOTTOM BAR ----
-- The suite's one green strip. Returns its click rect so each panel can wire
-- the same hit test it used before.
function cx_footer_band(bottom, footer_h)
    local y0 = bottom + 8
    return y0, y0 + (footer_h or 34) - 12
end

function cx_footer_button(x, bottom, w, label, footer_h, pad)
    local p = pad or 14
    local y0, y1 = cx_footer_band(bottom, footer_h)
    cx_bar(x + p, y0, x + w - p, y1, CX.footer_bg)
    cx_bar(x + p, y1 - 1, x + w - p, y1, CX.ok, 1.0)
    local tw = cx_measure(label, 10)
    cx_text(x + (w - tw) / 2, y0 + 6, label, 10, CX.footer_fg)
    return { x0 = x + p, x1 = x + w - p, y0 = y0, y1 = y1 }
end
