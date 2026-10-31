#!/usr/bin/env python3
"""Render the JSON dump from tools/render_panels.lua into PNG panel images.

Uses ImageMagick's native MVG text format (no SVG/rsvg delegate needed):

    luajit tools/render_panels.lua > /tmp/panels.json
    python3 tools/render_panels.py /tmp/panels.json docs/img/panels
"""

import json
import math
import os
import subprocess
import sys

FONT_PX = {"def": 12, "h10": 10, "h12": 12, "h18": 18}
BACKDROP = "#141414"   # dark cockpit-ish background
MARGIN = 28


def hexcolor(r, g, b, a):
    def c(v):
        return min(255, max(0, int(round(v * 255))))
    return "#%02x%02x%02x%02x" % (c(r), c(g), c(b), c(a))


def mvg_quote(s):
    return s.replace("'", "''")


def emit(frame, screen_w, screen_h, out_path):
    prims = frame["prims"]
    if not prims:
        print("skip %s: no primitives" % frame["name"])
        return
    # bounding box in FlyWithLua coords (y up)
    xs, ys = [], []
    for p in prims:
        xs.append(p["x"])
        if p["k"] == "text":
            ys.append(p["y"])
            xs.append(p["x"] + len(p.get("text", "")) * FONT_PX.get(p.get("font", "def"), 12) * 0.58)
        else:
            xs.append(p.get("x2", p["x"]))
            ys.append(p["y"])
            ys.append(p.get("y2", p["y"]))
    x0, x1 = min(xs) - MARGIN, max(xs) + MARGIN
    y0, y1 = min(ys) - MARGIN, max(ys) + MARGIN
    w, h = math.ceil(x1 - x0), math.ceil(y1 - y0)

    lines = ["push graphic-context",
             "viewbox 0 0 %d %d" % (w, h),
             "fill '%s'" % BACKDROP,
             "rectangle 0,0 %d,%d" % (w, h)]
    def fy(y):
        return h - (y - y0)          # FlyWithLua y-up -> image y-down

    for p in prims:
        col = hexcolor(p["c"][0], p["c"][1], p["c"][2], p["c"][3])
        if p["k"] == "rect":
            lines.append("fill '%s'" % col)
            lines.append("stroke '%s'" % col)
            lines.append("stroke-width 1")
            xa, ya = p["x"] - x0, fy(p["y"])
            xb, yb = (p.get("x2", p["x"]) - x0), fy(p.get("y2", p["y"]))
            lines.append("rectangle %.1f,%.1f %.1f,%.1f" % (xa, ya, xb, yb))
        else:
            font = p.get("font", "def")
            lines.append("fill '%s'" % col)
            lines.append("font-size %d" % FONT_PX.get(font, 12))
            lines.append("text %.1f,%.1f '%s'" % (p["x"] - x0, fy(p["y"]), mvg_quote(p["text"])))

    lines.append("pop graphic-context")
    mvg = "\n".join(lines)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    cmd = ["magick", "-font", "/System/Library/Fonts/Helvetica.ttc", "mvg:-", out_path]
    r = subprocess.run(cmd, input=mvg.encode("utf-8"), capture_output=True)
    if r.returncode != 0:
        raise SystemExit("magick failed for %s:\n%s" % (out_path, r.stderr.decode("utf-8", "ignore")))
    print("rendered %-8s -> %s (%dx%d)" % (frame["name"], out_path, w, h))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    outdir = sys.argv[2]
    w, h = data["screen"]["w"], data["screen"]["h"]
    for fr in data["frames"]:
        emit(fr, w, h, os.path.join(outdir, fr["name"] + ".png"))


if __name__ == "__main__":
    main()
