#!/usr/bin/env python3
"""
joymap_gui.py -- local GUI for the X-Plane joystick profile.

Shows a DualShock 4 and a mouse, with every control coloured by whether it is
bound, and lets you re-assign a control from the full command catalog (core
sim/ commands + the 220 Citation X xlua commands). Works with X-Plane closed.

The GUI is a small web page served by Python's standard library and opened in
the default browser -- no third-party packages, no tkinter (Homebrew Python
ships without Tk).

    python3 tools/joymap_gui.py            # opens the browser
    python3 tools/joymap_gui.py --no-browser
    python3 tools/joymap_gui.py --port 8765
    python3 tools/joymap_gui.py --self-test # headless smoke test, exits
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import sys
import threading
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import joymap  # noqa: E402

SUITE_LUA = os.path.join(joymap.ROOT, "Scripts", "CitationX_MasterSuite.lua")
AXES_PER_DEVICE = 25

# slot, id, label, group
CONTROLS = [
    (0, "hat_up", "D-Pad ▲", "dpad"),
    (1, "hat_up_right", "D-Pad ↗", "dpad"),
    (2, "hat_right", "D-Pad ▶", "dpad"),
    (3, "hat_down_right", "D-Pad ↘", "dpad"),
    (4, "hat_down", "D-Pad ▼", "dpad"),
    (5, "hat_down_left", "D-Pad ↙", "dpad"),
    (6, "hat_left", "D-Pad ◀", "dpad"),
    (7, "hat_up_left", "D-Pad ↖", "dpad"),
    (8, "btn0", "L1", "shoulder"),
    (9, "btn1", "L2", "shoulder"),
    (10, "btn2", "R1", "shoulder"),
    (11, "btn3", "R2", "shoulder"),
    (12, "btn4", "□", "face"),
    (13, "btn5", "✕", "face"),
    (14, "btn6", "○", "face"),
    (15, "btn7", "△", "face"),
    (16, "btn8", "Share", "misc"),
    (17, "btn9", "Options", "misc"),
    (18, "btn10", "L3", "stick"),
    (19, "btn11", "R3", "stick"),
    (20, "btn12", "PS", "misc"),
    (21, "btn13", "Touchpad", "misc"),
]

MOUSE_ROLES = []  # superseded by mouse_state(); kept for older imports

# Logi Options+ keeps its device profiles in ~/Library/.../settings.db; the
# X-Plane profile is keyed by bundle id. Slot suffixes: c195 gesture,
# c196 mode shift, c82 thumb button, c83 back, c86 forward.
LOGI_SETTINGS = os.path.expanduser(
    "~/Library/Application Support/LogiOptionsPlus/settings.db")
LOGI_BUNDLE = "com.laminar-research.X-Plane"
LOGI_SLOTS = {
    "c195": "gesture",
    "c196": "mode",
    "c82": "thumb_btn",
    "c83": "back",
    "c86": "forward",
    "thumb_wheel_adapter": "thumbwheel",
}

BIND_RE = re.compile(
    r'\{ vkey = (0x[0-9A-Fa-f]+|\d+), ctrl = (true|false),\s*shift = (true|false),'
    r'\s*label = "([^"]+)",\s*(?:command = "([^"]+)"|action = )')
MOUSE_KEY_RE = re.compile(r'key = "([^"]+)",\s*label = "([^"]+)"')

# Colour code for the map: what a binding actually does.
CATEGORIES = {
    "view":     ("Blick",      "#4aa3ff"),
    "flight":   ("Steuerung",  "#3ddc84"),
    "engine":   ("Triebwerk",  "#ff9f1c"),
    "ap":       ("Autopilot",  "#b17bff"),
    "lights":   ("Licht",      "#ffd93d"),
    "avionics": ("Avionik",    "#2ee6d6"),
    "systems":  ("Systeme",    "#ff6ba8"),
    "other":    ("Sonstiges",  "#9aa0a6"),
    "none":     ("frei",       "#3a3a40"),
    "native":   ("nativ",      "#9aa0a6"),
    "suite":    ("Suite",      "#ff6ba8"),
    "logi":     ("Logi",       "#ffb020"),
}


def category(command):
    if not command or command == joymap.NONE:
        return "none"
    if command.startswith(("sim/view/", "sim/general/hat_switch", "sim/general/rot_")):
        return "view"
    if "/autopilot/" in command:
        return "ap"
    if command.startswith("sim/flight_controls/"):
        return "flight"
    if command.startswith("sim/engines/"):
        return "engine"
    if command.startswith("sim/autopilot/"):
        return "ap"
    if command.startswith("sim/lights/") or "/lights/" in command:
        return "lights"
    if command.startswith(("sim/instruments/", "sim/GPS/")):
        return "avionics"
    if command.startswith("laminar/CitX/"):
        low = command.lower()
        if "lights" in low:
            return "lights"
        if "primus" in low or "fmc" in low or "efis" in low:
            return "avionics"
        return "systems"
    if command.startswith("sim/"):
        return "other"
    return "other"


# ---------------------------------------------------------------- catalog ---
class Opts:
    commands = joymap.DEFAULT_COMMANDS
    aircraft = None


OPTS = Opts()
_catalog_cache = {"key": None, "core": {}, "air": {}}


def load_catalog():
    """Parse Commands.txt + the aircraft scripts, cached by file mtimes."""
    acf = joymap.find_aircraft(None)
    key = [os.path.getmtime(OPTS.commands) if os.path.exists(OPTS.commands) else 0, acf]
    if acf:
        scripts = os.path.join(acf, "plugins", "xlua", "scripts")
        for dirpath, _, files in os.walk(scripts):
            for name in files:
                if name.endswith(".lua"):
                    key.append(os.path.getmtime(os.path.join(dirpath, name)))
    if _catalog_cache["key"] != key:
        _catalog_cache["key"] = key
        _catalog_cache["core"] = joymap.core_commands(OPTS.commands)
        _catalog_cache["air"] = joymap.citix_commands(acf)
    return _catalog_cache["core"], _catalog_cache["air"]


def describe(command, core=None, air=None):
    if command in (None, "", joymap.NONE):
        return ""
    core = core if core is not None else load_catalog()[0]
    air = air if air is not None else load_catalog()[1]
    return air.get(command) or core.get(command) or ""


def short(command):
    if command in (None, "", joymap.NONE):
        return "—"
    text = command
    for prefix in ("sim/flight_controls/", "sim/general/", "sim/view/",
                   "sim/engines/", "sim/", "laminar/CitX/"):
        if text.startswith(prefix):
            text = text[len(prefix):]
            break
    return text


# ------------------------------------------------------------------ state ---
def suite_bindings():
    """The keyboard layer the suite consumes (mouse thumb buttons land here)."""
    out = []
    try:
        with open(SUITE_LUA, "r", encoding="utf-8", errors="ignore") as fd:
            text = fd.read()
    except OSError:
        return out
    for match in BIND_RE.finditer(text):
        vkey = int(match.group(1), 0)
        out.append({
            "vkey": vkey,
            "key": chr(vkey) if 32 <= vkey < 127 else "0x%02X" % vkey,
            "ctrl": match.group(2) == "true",
            "shift": match.group(3) == "true",
            "label": match.group(4),
            "command": match.group(5) or "",
        })
    return out


def logi_profile():
    """The MX mouse assignments Logi Options+ holds for X-Plane."""
    try:
        con = sqlite3.connect("file:%s?mode=ro" % LOGI_SETTINGS, uri=True)
        row = con.execute(
            "SELECT file FROM data ORDER BY _id DESC LIMIT 1").fetchone()
        con.close()
    except Exception:
        return {}
    if not row:
        return {}
    blob = row[0]
    if isinstance(blob, memoryview):
        blob = blob.tobytes()
    try:
        data = json.loads(blob.decode("utf-8", "replace"))
    except Exception:
        return {}
    app_id = None
    for app in data.get("applications", {}).get("applications", []):
        if app.get("bundleId") == LOGI_BUNDLE:
            app_id = app.get("applicationId")
            break
    if not app_id:
        return {}
    out = {}
    for a in data.get("profile-%s" % app_id, {}).get("assignments", []):
        slot_id = a.get("slotId", "")
        ident = None
        for key in sorted(LOGI_SLOTS, key=len, reverse=True):
            if slot_id.endswith(key):
                ident = LOGI_SLOTS[key]
                break
        if not ident:
            continue
        card = a.get("card", {})
        macro = card.get("macro") or {}
        combo = macro.get("actionName") if macro.get("type") == "KEYSTROKE" else None
        if not combo:                      # 2-way adapters keep them nested
            nested = card.get("nestedCards") or {}
            names = []
            for direction in ("left", "right"):
                leaf = (nested.get(direction) or {}).get("macro") or {}
                if leaf.get("type") == "KEYSTROKE" and leaf.get("actionName"):
                    names.append(leaf["actionName"])
            if names and len(set(names)) == 1:
                combo = names[0]
        if macro.get("type") == "DO_NOTHING":
            label = "Do Nothing"
        elif combo:
            label = combo
        else:
            label = card.get("name", "").replace("ASSIGNMENT_NAME_", "")
        out[ident] = {"label": label, "combo": combo}
    return out


def mouse_state():
    logi = logi_profile()
    # Keys the suite always listens for on the mouse layer (CitationX_MasterSuite:
    # MOUSE_KEY_ACTIONS). Shown as a hint while Logi still sends something else.
    targets = {"gesture": ("Ctrl+Shift+8", "Landelichter"),
               "thumbwheel": ("Ctrl+Shift+6", "Taxilicht")}

    def norm(text):
        return (text or "").replace(" ", "").lower()

    suite = {}
    always_on = set()
    for b in suite_bindings():
        parts = []
        if b["ctrl"]:
            parts.append("Ctrl")
        if b["shift"]:
            parts.append("Shift")
        parts.append(b["key"])
        suite[norm(" + ".join(parts))] = b["label"]
    try:
        with open(SUITE_LUA, "r", encoding="utf-8", errors="ignore") as fd:
            lua = fd.read()
    except OSError:
        lua = ""
    for match in MOUSE_KEY_RE.finditer(lua):
        suite.setdefault(norm(match.group(1)), match.group(2))
        always_on.add(match.group(2))

    def entry(ident, label, native=None, slot=None):
        info = logi.get(slot) if slot else None
        combo = info["combo"] if info else None
        if native:
            desc, cat = native, "native"
        elif not info:
            desc, cat = "kein Logi-Profil gefunden", "logi"
        elif combo and norm(combo) in suite:
            suite_label = suite[norm(combo)]
            live = suite_label.startswith("ALT SEL") or suite_label in always_on
            note = "" if live else "  (INPUT MAPPER nötig)"
            desc, cat = "%s  →  Suite: %s%s" % (combo, suite_label, note), "suite"
        elif combo:
            desc, cat = "%s  →  in X-Plane nicht belegt" % combo, "logi"
        elif slot == "thumbwheel":
            desc, cat = "horizontales Scrollen", "logi"
        else:
            desc, cat = info["label"] or "—", "logi"
        if slot in targets and norm(combo) != norm(targets[slot][0]):
            key, what = targets[slot]
            desc += "  ·  in Logi auf %s legen → %s" % (key, what)
        return {"id": ident, "label": label, "description": desc, "cat": cat,
                "cat_label": CATEGORIES[cat][0], "cat_color": CATEGORIES[cat][1]}

    return [
        entry("left", "Linke Taste", "X-Plane: Cockpit bedienen, Menüs"),
        entry("right", "Rechte Taste", "X-Plane: Blick / Kontextmenü"),
        entry("wheel", "Mausrad", "X-Plane: Zoom"),
        entry("wheel_click", "Rad-Klick", "X-Plane: mittlere Maustaste"),
        entry("thumbwheel", "Daumenrad", None, "thumbwheel"),
        entry("gesture", "Gesten-Taste", None, "gesture"),
        entry("thumb_btn", "Daumentaste unten", None, "thumb_btn"),
        entry("mode", "Modus-Taste", None, "mode"),
        entry("back", "Daumentaste zurück", None, "back"),
        entry("forward", "Daumentaste vor", None, "forward"),
    ]


def state(device=0):
    lines, entries = joymap.read_prf(CURRENT_PRF)
    core, air = load_catalog()
    devices = []
    for dev in joymap.device_ids(lines):
        devices.append({
            "index": dev,
            "name": joymap.scalar(lines, "_joy_location%d" % dev) or "Gerät %d" % dev,
            "id": joymap.scalar(lines, "_joy_unique_id%d" % dev),
        })
    if device not in [d["index"] for d in devices]:
        device = devices[0]["index"] if devices else 0

    controls = []
    for slot, ident, label, group in CONTROLS:
        key = device * joymap.BLOCK + slot
        command = entries[key][1] if key in entries else joymap.NONE
        cat = category(command)
        controls.append({
            "slot": slot,
            "id": ident,
            "label": label,
            "group": group,
            "command": command,
            "short": short(command),
            "description": describe(command, core, air),
            "cat": cat,
            "cat_label": CATEGORIES[cat][0],
            "cat_color": CATEGORIES[cat][1],
        })

    axes = []
    base = device * AXES_PER_DEVICE
    for i in range(AXES_PER_DEVICE):
        raw = joymap.scalar(lines, "_joy_AXIS_use%d" % (base + i)).strip()
        try:
            use = int(raw) if raw else 0
        except ValueError:
            use = 0
        if use > 0:
            axes.append({"index": base + i, "name": joymap.axis_name(use)})

    return {
        "ok": True,
        "sim_running": joymap.is_running(),
        "profile": CURRENT_PRF,
        "device": device,
        "devices": devices,
        "controls": controls,
        "axes": axes,
        "mouse": mouse_state(),
        "suite": suite_bindings(),
    }


def search(query, limit=200):
    core, air = load_catalog()
    q = (query or "").strip().lower()
    rows = []
    for name, desc in air.items():
        if not q or q in name.lower() or q in desc.lower():
            rows.append({"name": name, "description": desc, "tag": "citx"})
    for name, desc in core.items():
        if q and (q in name.lower() or q in desc.lower()):
            rows.append({"name": name, "description": desc, "tag": "core"})
    rows.sort(key=lambda r: (r["tag"] != "citx", r["name"]))
    return rows[:limit]


# ------------------------------------------------------------------- write ---
def api_set(device, slot, command):
    if joymap.is_running():
        return 409, {"error": "X-Plane läuft. Bitte die Sim schließen — sie "
                              "überschreibt das Profil beim Beenden."}
    if not command:
        return 400, {"error": "Kein Command angegeben"}
    core, air = load_catalog()
    if command != joymap.NONE and command not in core and command not in air:
        return 400, {"error": "Unbekannter Command: %s" % command}
    lines, entries = joymap.read_prf(CURRENT_PRF)
    key = device * joymap.BLOCK + slot
    if key not in entries:
        return 400, {"error": "Slot %d existiert nicht" % slot}
    index, old = entries[key]
    if old == command:
        return 200, {"ok": True, "unchanged": True, "old": old}
    lines[index] = "_joy_BUTN_use%d %s" % (key, command)
    joymap.make_backup(CURRENT_PRF)
    joymap.write_prf(CURRENT_PRF, lines)
    return 200, {"ok": True, "old": old, "new": command}


def api_undo():
    if joymap.is_running():
        return 409, {"error": "X-Plane läuft — Undo gesperrt."}
    src = joymap.newest_backup(CURRENT_PRF)
    if not src:
        return 404, {"error": "Kein Backup vorhanden"}
    shutil.copy2(src, CURRENT_PRF)
    os.rename(src, src.replace(".bak-", ".restored-"))
    return 200, {"ok": True, "restored": src}


# -------------------------------------------------------------------- html ---
HTML = r"""<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<title>Citation X — Input Map</title>
<style>
  :root {
    --bg:#0b0b0c; --panel:#141416; --line:#2a2a2e; --text:#e8e8ea; --dim:#8a8a90;
    --green:#3ddc84; --amber:#ffb020; --red:#ff5b5b;
  }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text);
         font:13px/1.35 -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif; }
  header { display:flex; align-items:baseline; gap:12px; padding:10px 16px;
           border-bottom:1px solid var(--line); }
  header h1 { font-size:14px; font-weight:600; margin:0; letter-spacing:.3px; }
  header .sub { color:var(--dim); font-size:12px; }
  .warn { color:var(--amber); font-size:12px; margin-left:auto; }
  main { display:flex; gap:14px; padding:14px 16px 24px; align-items:flex-start;
         max-width:1180px; margin:0 auto; }
  .left { display:flex; gap:14px; align-items:flex-start; flex-wrap:wrap;
          flex:1 1 auto; min-width:0; }
  .right { flex:0 0 330px; position:sticky; top:12px;
           max-height:calc(100vh - 24px); overflow:auto; }
  .card { background:var(--panel); border:1px solid var(--line); border-radius:9px;
          padding:10px; margin-bottom:12px; }
  .padcard { flex:1 1 500px; max-width:600px; }
  .mousecard { flex:0 0 200px; }
  #pad { max-width:100%; }
  #mouse { max-width:180px; margin:0 auto; }
  .card h2 { font-size:10px; letter-spacing:.14em; text-transform:uppercase;
             color:var(--dim); margin:0 0 8px; font-weight:600; }
  svg { width:100%; height:auto; display:block; user-select:none; }
  .ctl { cursor:pointer; }
  .ctl .hit { fill:transparent; }
  .ctl .body { fill:#1c1c1f; stroke:#3a3a40; stroke-width:2; }
  .ctl.bound .body { fill:#14301f; stroke:var(--green); }
  .ctl.selected .body { stroke:var(--amber); stroke-width:3; }
  .ctl:hover .body { stroke:#c9c9d1; }
  .ctl text { fill:var(--dim); font-size:11px; text-anchor:middle; pointer-events:none; }
  .ctl.bound text.lbl { fill:var(--green); }
  .ctl.selected text.lbl { fill:var(--amber); }
  .glyph { fill:#d8d8de; font-size:18px; text-anchor:middle; pointer-events:none; }
  .hull { fill:#191a1d; stroke:#34343a; stroke-width:3; }
  .stickbase { fill:#101012; stroke:#3a3a40; stroke-width:2; }
  .labels line { stroke:#2e2e33; stroke-width:1; }
  .list { max-height:240px; overflow:auto; }
  .row { display:flex; gap:7px; align-items:baseline; padding:3px 5px; border-radius:5px;
         cursor:pointer; }
  .row:hover { background:#1d1d21; }
  .row.sel { background:#221c0d; outline:1px solid var(--amber); }
  .row .name { flex:0 0 100px; color:var(--dim); font-size:11px; display:flex;
               align-items:center; gap:4px; }
  .row .cmd { flex:1 1 auto; font-family:ui-monospace, Menlo, monospace; font-size:11px;
              color:var(--text); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .row .cmd.none { color:#5a5a62; }
  .row .tag { flex:0 0 auto; font-size:10px; color:var(--dim); text-transform:uppercase; }
  input[type=search] { width:100%; background:#0f0f11; color:var(--text);
      border:1px solid var(--line); border-radius:6px; padding:6px 9px; font-size:12px; }
  input[type=search]:focus { outline:1px solid var(--amber); }
  button { background:#1f1f23; color:var(--text); border:1px solid var(--line);
           border-radius:6px; padding:5px 9px; font-size:11px; cursor:pointer; }
  button:hover { border-color:#55555e; }
  button.primary { border-color:var(--green); color:var(--green); }
  button.danger { border-color:#5a2a2a; color:var(--red); }
  button:disabled { opacity:.4; cursor:default; }
  .detail { font-size:11px; color:var(--dim); margin-top:5px; }
  .detail b { color:var(--text); font-weight:600; }
  .toast { position:fixed; left:16px; bottom:14px; background:#1b1b1f; border:1px solid var(--line);
           border-radius:7px; padding:7px 12px; font-size:11px; opacity:0; transition:.2s; }
  .toast.show { opacity:1; }
  .axes { font-size:11px; color:var(--dim); }
  .axes span { display:inline-block; margin-right:10px; font-family:ui-monospace, Menlo, monospace; }
  .legend { display:flex; gap:12px; font-size:10px; color:var(--dim); margin-top:6px; }
  .dot { display:inline-block; width:8px; height:8px; border-radius:50%; margin-right:4px; }
  @keyframes flash { 0% { filter:drop-shadow(0 0 0 rgba(61,220,132,.9)); }
                     100% { filter:drop-shadow(0 0 9px rgba(61,220,132,.9)); } }
  .ctl.flash .body { animation:flash .28s ease-in-out 3 alternate; }
  .ctl:hover .body { filter:brightness(1.3); }
</style></head>
<body>
<header>
  <h1>Citation X — Input Map</h1>
  <span class="sub" id="profile"></span>
  <span class="warn" id="warn"></span>
</header>
<main>
  <div class="left">
    <div class="card padcard">
      <h2>DualShock 4</h2>
      <svg viewBox="0 0 760 470" id="pad">
        <path class="hull" d="M150 62 H610 C668 62 706 108 706 178
          C706 244 696 316 654 344 C620 366 584 340 566 300
          C520 316 240 316 194 300 C176 340 140 366 106 344
          C64 316 54 244 54 178 C54 108 92 62 150 62 Z"/>
        <g id="top">
          <g class="ctl" data-id="btn1"><rect class="body" x="146" y="26" width="104" height="26" rx="9"/>
            <rect class="hit" x="146" y="26" width="104" height="26"/><text class="lbl" x="198" y="44">L2</text></g>
          <g class="ctl" data-id="btn0"><rect class="body" x="146" y="58" width="104" height="24" rx="9"/>
            <rect class="hit" x="146" y="58" width="104" height="24"/><text class="lbl" x="198" y="75">L1</text></g>
          <g class="ctl" data-id="btn3"><rect class="body" x="510" y="26" width="104" height="26" rx="9"/>
            <rect class="hit" x="510" y="26" width="104" height="26"/><text class="lbl" x="562" y="44">R2</text></g>
          <g class="ctl" data-id="btn2"><rect class="body" x="510" y="58" width="104" height="24" rx="9"/>
            <rect class="hit" x="510" y="58" width="104" height="24"/><text class="lbl" x="562" y="75">R1</text></g>
        </g>
        <g class="ctl" data-id="btn13"><rect class="body" x="300" y="92" width="160" height="78" rx="10"/>
          <rect class="hit" x="300" y="92" width="160" height="78"/><text class="lbl" x="380" y="136">Touchpad</text></g>
        <g class="ctl" data-id="btn8"><rect class="body" x="262" y="116" width="26" height="16" rx="5"/>
          <rect class="hit" x="258" y="110" width="34" height="28"/><text class="lbl" x="275" y="152">Share</text></g>
        <g class="ctl" data-id="btn9"><rect class="body" x="472" y="116" width="26" height="16" rx="5"/>
          <rect class="hit" x="468" y="110" width="34" height="28"/><text class="lbl" x="485" y="152">Options</text></g>
        <g id="dpad">
          <g class="ctl" data-id="hat_up_left"><rect class="body" x="140" y="176" width="34" height="34" rx="6"/>
            <rect class="hit" x="140" y="176" width="34" height="34"/><text class="lbl" x="157" y="167">↖</text></g>
          <g class="ctl" data-id="hat_up"><rect class="body" x="176" y="176" width="34" height="34" rx="6"/>
            <rect class="hit" x="176" y="176" width="34" height="34"/><text class="lbl" x="193" y="167">▲</text></g>
          <g class="ctl" data-id="hat_up_right"><rect class="body" x="212" y="176" width="34" height="34" rx="6"/>
            <rect class="hit" x="212" y="176" width="34" height="34"/><text class="lbl" x="229" y="167">↗</text></g>
          <g class="ctl" data-id="hat_left"><rect class="body" x="140" y="212" width="34" height="34" rx="6"/>
            <rect class="hit" x="140" y="212" width="34" height="34"/><text class="lbl" x="128" y="235">◀</text></g>
          <g class="ctl" data-id="hat_down"><rect class="body" x="176" y="212" width="34" height="34" rx="6"/>
            <rect class="hit" x="176" y="212" width="34" height="34"/><text class="lbl" x="193" y="262">▼</text></g>
          <g class="ctl" data-id="hat_right"><rect class="body" x="212" y="212" width="34" height="34" rx="6"/>
            <rect class="hit" x="212" y="212" width="34" height="34"/><text class="lbl" x="258" y="235">▶</text></g>
          <g class="ctl" data-id="hat_down_left"><rect class="body" x="140" y="248" width="34" height="34" rx="6"/>
            <rect class="hit" x="140" y="248" width="34" height="34"/><text class="lbl" x="157" y="297">↙</text></g>
          <g class="ctl" data-id="hat_down_right"><rect class="body" x="212" y="248" width="34" height="34" rx="6"/>
            <rect class="hit" x="212" y="248" width="34" height="34"/><text class="lbl" x="229" y="297">↘</text></g>
        </g>
        <g class="ctl" data-id="btn7"><circle class="body" cx="560" cy="196" r="19"/>
          <circle class="hit" cx="560" cy="196" r="26"/><text class="glyph" x="560" y="202">△</text>
          <text class="lbl" x="560" y="166"></text></g>
        <g class="ctl" data-id="btn6"><circle class="body" cx="596" cy="232" r="19"/>
          <circle class="hit" cx="596" cy="232" r="26"/><text class="glyph" x="596" y="238">○</text>
          <text class="lbl" x="632" y="236"></text></g>
        <g class="ctl" data-id="btn5"><circle class="body" cx="560" cy="268" r="19"/>
          <circle class="hit" cx="560" cy="268" r="26"/><text class="glyph" x="560" y="274">✕</text>
          <text class="lbl" x="560" y="302"></text></g>
        <g class="ctl" data-id="btn4"><circle class="body" cx="524" cy="232" r="19"/>
          <circle class="hit" cx="524" cy="232" r="26"/><text class="glyph" x="524" y="238">□</text>
          <text class="lbl" x="488" y="236"></text></g>
        <g class="ctl" data-id="btn10"><circle class="stickbase" cx="330" cy="336" r="44"/>
          <circle class="body" cx="330" cy="336" r="33"/>
          <circle class="hit" cx="330" cy="336" r="50"/><text class="lbl" x="330" y="400">L3</text></g>
        <g class="ctl" data-id="btn11"><circle class="stickbase" cx="440" cy="336" r="44"/>
          <circle class="body" cx="440" cy="336" r="33"/>
          <circle class="hit" cx="440" cy="336" r="50"/><text class="lbl" x="440" y="400">R3</text></g>
        <g class="ctl" data-id="btn12"><circle class="body" cx="385" cy="232" r="15"/>
          <circle class="hit" cx="385" cy="232" r="21"/><text class="lbl" x="385" y="282">PS</text></g>
        <text x="330" y="430" class="lbl" style="fill:#8a8a90" id="axleft"></text>
        <text x="440" y="430" class="lbl" style="fill:#8a8a90" id="axright"></text>
      </svg>
      <div class="legend" id="legend"></div>
    </div>

    <div class="card mousecard">
      <h2>Maus</h2>
      <svg viewBox="0 0 300 230" id="mouse">
        <path class="hull" d="M150 22 C 92 22 74 74 74 118 C 74 168 100 200 150 200
                              C 200 200 226 168 226 118 C 226 74 208 22 150 22 Z"/>
        <g class="ctl" data-id="left"><path class="body" d="M148 26 C 106 26 88 66 86 104 L 148 104 Z"/>
          <path class="hit" d="M148 26 C 106 26 88 66 86 104 L 148 104 Z"/><text class="lbl" x="112" y="86">links</text></g>
        <g class="ctl" data-id="right"><path class="body" d="M152 26 C 194 26 212 66 214 104 L 152 104 Z"/>
          <path class="hit" d="M152 26 C 194 26 212 66 214 104 L 152 104 Z"/><text class="lbl" x="188" y="86">rechts</text></g>
        <g class="ctl" data-id="wheel"><rect class="body" x="141" y="52" width="18" height="42" rx="9"/>
          <rect class="hit" x="135" y="46" width="30" height="54"/><text class="lbl" x="150" y="118">Rad</text></g>
        <g class="ctl" data-id="mode"><rect class="body" x="136" y="106" width="28" height="10" rx="5"/>
          <rect class="hit" x="130" y="100" width="40" height="22"/><text class="lbl" x="150" y="132">Modus</text></g>
        <g class="ctl" data-id="thumbwheel"><rect class="body" x="58" y="66" width="14" height="26" rx="6"/>
          <rect class="hit" x="52" y="60" width="26" height="38"/></g>
        <g class="ctl" data-id="gesture"><rect class="body" x="84" y="108" width="26" height="64" rx="12"/>
          <rect class="hit" x="78" y="102" width="38" height="76"/><text class="lbl" x="97" y="96">Geste</text></g>
        <g class="ctl" data-id="back"><rect class="body" x="58" y="100" width="14" height="24" rx="6"/>
          <rect class="hit" x="52" y="94" width="26" height="36"/><text class="lbl" x="36" y="116">zurück</text></g>
        <g class="ctl" data-id="forward"><rect class="body" x="58" y="132" width="14" height="24" rx="6"/>
          <rect class="hit" x="52" y="126" width="26" height="36"/><text class="lbl" x="36" y="148">vor</text></g>
      </svg>
    </div>
  </div>

  <div class="right">
    <div class="card">
      <h2>Gerät</h2>
      <select id="device" style="width:100%;background:#0f0f11;color:#e8e8ea;border:1px solid #2a2a2e;border-radius:7px;padding:8px"></select>
      <div class="detail" id="devinfo"></div>
    </div>

    <div class="card">
      <h2>Belegung</h2>
      <div class="list" id="rows"></div>
      <div class="detail" id="axesbox"></div>
    </div>

    <div class="card">
      <h2>Maus</h2>
      <div id="mouserows"></div>
    </div>

    <div class="card" id="assigncard">
      <h2>Auswahl</h2>
      <div id="selname" class="detail" style="margin:0 0 8px">Links einen Regler anklicken.</div>
      <input type="search" id="q" placeholder="Command suchen — z. B. lights, gear, APU" autocomplete="off">
      <div class="list" id="results" style="margin-top:8px"></div>
      <div style="display:flex;gap:8px;margin-top:10px">
        <button id="undo">Rückgängig</button>
        <button id="btnclear" class="danger" disabled>Löschen</button>
        <button id="btnreload" style="margin-left:auto">Neu laden</button>
      </div>
    </div>
  </div>
</main>
<div class="toast" id="toast"></div>

<script>
let STATE = null, SELECTED = null, SELECTED_MOUSE = null, DEVICE = 0;

function rgba(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

function toast(msg, ms=2600) {
  const t = document.getElementById('toast');
  t.textContent = msg; t.classList.add('show');
  clearTimeout(t._h); t._h = setTimeout(() => t.classList.remove('show'), ms);
}

async function load(device) {
  const r = await fetch('/api/state?device=' + (device ?? DEVICE));
  const s = await r.json();
  STATE = s; DEVICE = s.device;
  render();
}

function render() {
  document.getElementById('profile').textContent = STATE.profile.split('/').pop();
  const warn = document.getElementById('warn');
  warn.textContent = STATE.sim_running ? 'X-Plane läuft — Änderungen gesperrt' : '';
  warn.style.color = STATE.sim_running ? '#ffb020' : '';

  const sel = document.getElementById('device');
  const current = String(STATE.device);
  if (sel.dataset.filled !== STATE.devices.map(d => d.index).join(',')) {
    sel.innerHTML = STATE.devices.map(d =>
      `<option value="${d.index}">Gerät ${d.index} — ${d.name}</option>`).join('');
    sel.dataset.filled = STATE.devices.map(d => d.index).join(',');
  }
  sel.value = current;
  sel.disabled = STATE.sim_running;
  document.getElementById('devinfo').innerHTML =
    STATE.devices.map(d => `Gerät ${d.index}: ${d.name}`).join('<br>') || 'kein Gerät';

  const byId = {};
  for (const c of STATE.controls) byId[c.id] = c;
  const FIXED = ['L2','L1','R2','R1','L3','R3','Share','Options','PS','Touchpad',
                 '↖','▲','↗','◀','▼','▶','↙','↘'];
  for (const el of document.querySelectorAll('.ctl')) {
    const c = byId[el.dataset.id];
    if (!c) continue;
    const bound = c.command && c.command !== 'sim/none/none';
    el.classList.toggle('bound', !!bound);
    el.classList.toggle('selected', SELECTED === c.id);
    el.querySelectorAll('text.lbl').forEach(t => {
      if (FIXED.includes(t.textContent)) return;
      t.textContent = bound ? c.short : '';
    });
    el.querySelectorAll('.body').forEach(b => {
      b.style.stroke = SELECTED === c.id ? '#ffb020' : c.cat_color;
      b.style.strokeWidth = SELECTED === c.id ? '3' : '2';
      b.style.fill = bound ? rgba(c.cat_color, 0.22) : '#1c1c1f';
    });
    // click + hover tooltip with the full command
    let tip = null;
    for (const child of el.children) if (child.tagName === 'title') tip = child;
    if (!tip) {
      tip = document.createElementNS('http://www.w3.org/2000/svg', 'title');
      el.insertBefore(tip, el.firstChild);
    }
    tip.textContent = c.label + ' — ' + (bound ? c.command : 'frei');
    el.onclick = () => select(c.id, true);
  }
  // sticks show axis functions
  const ax = STATE.axes.map(a => a.name);
  document.getElementById('axleft').textContent = ax.slice(0, 2).join(' / ');
  document.getElementById('axright').textContent = ax.slice(2, 4).join(' / ');

  const rows = document.getElementById('rows');
  rows.innerHTML = STATE.controls.map(c => {
    const bound = c.command && c.command !== 'sim/none/none';
    return `<div class="row ${SELECTED === c.id ? 'sel' : ''}" data-id="${c.id}">
      <span class="name"><i class="dot" style="background:${c.cat_color}"></i>${c.label}</span>
      <span class="cmd ${bound ? '' : 'none'}">${bound ? c.command : 'frei'}</span>
      <span class="tag" style="color:${bound ? c.cat_color : '#5a5a62'}">${bound ? c.cat_label : ''}</span>
    </div>`;
  }).join('');
  rows.querySelectorAll('.row').forEach(r =>
    r.onclick = () => select(r.dataset.id, false));

  const counts = {};
  for (const c of STATE.controls) counts[c.cat] = (counts[c.cat] || 0) + 1;
  const legend = Object.entries(counts).filter(([k]) => k !== 'none')
    .sort((a, b) => b[1] - a[1]).map(([k, n]) => {
      const found = STATE.controls.find(x => x.cat === k);
      return `<span><i class="dot" style="background:${found.cat_color}"></i>${found.cat_label} (${n})</span>`;
    });
  if (counts.none) legend.push(`<span><i class="dot" style="background:#3a3a40"></i>frei (${counts.none})</span>`);
  document.getElementById('legend').innerHTML = legend.join('');

  document.getElementById('axesbox').innerHTML = STATE.axes.length
    ? 'Achsen: ' + STATE.axes.map(a => `<span>A${a.index} ${a.name}</span>`).join('')
    : 'Keine Achsen belegt.';

  document.getElementById('mouserows').innerHTML = STATE.mouse.map(m =>
    `<div class="row ${SELECTED_MOUSE === m.id ? 'sel' : ''}" data-mouse="${m.id}">
       <span class="name"><i class="dot" style="background:${m.cat_color}"></i>${m.label}</span>
       <span class="cmd">${m.description}</span>
       <span class="tag" style="color:${m.cat_color}">${m.cat_label}</span></div>`).join('');
  document.querySelectorAll('#mouserows .row').forEach(r =>
    r.onclick = () => selectMouse(r.dataset.mouse));

  document.getElementById('btnclear').disabled = !SELECTED || STATE.sim_running;
  paintMouse();
}

function paintMouse() {
  for (const g of document.querySelectorAll('#mouse .ctl')) {
    const m = STATE.mouse.find(x => x.id === g.dataset.id);
    g.classList.add('bound');
    g.classList.toggle('selected', SELECTED_MOUSE === g.dataset.id);
    if (!m) continue;
    g.querySelectorAll('.body').forEach(b => {
      b.style.stroke = SELECTED_MOUSE === m.id ? '#ffb020' : m.cat_color;
      b.style.strokeWidth = SELECTED_MOUSE === m.id ? '3' : '2';
      b.style.fill = rgba(m.cat_color, 0.22);
    });
  }
}

function selectMouse(id) {
  SELECTED = null;
  SELECTED_MOUSE = id;
  render();
  const m = STATE.mouse.find(x => x.id === id);
  if (!m) return;
  document.getElementById('selname').innerHTML =
    `<b>${m.label}</b> &nbsp;<span style="color:${m.cat_color}">${m.cat_label}</span><br>` +
    `${m.description}` +
    `<div style="margin-top:6px">Nativ bzw. über die Suite — liegt nicht im Joystick-Profil.</div>`;
  document.getElementById('q').value = '';
  document.getElementById('results').innerHTML =
    '<div class="detail">Maus-Eingaben werden hier nur angezeigt.</div>';
  document.getElementById('btnclear').disabled = true;
}

function flash(id) {
  const el = document.querySelector(`#pad .ctl[data-id="${id}"]`);
  if (!el) return;
  el.classList.add('flash');
  setTimeout(() => el.classList.remove('flash'), 900);
}

function select(id, scroll=true) {
  SELECTED = id;
  SELECTED_MOUSE = null;
  render();
  const c = STATE.controls.find(x => x.id === id);
  if (!c) return;
  document.getElementById('selname').innerHTML =
    `<b>${c.label}</b> &nbsp;Slot ${c.slot} &nbsp;` +
    `<span style="color:${c.cat_color}">${c.cat_label}</span><br>` +
    `<span style="font-family:ui-monospace,Menlo,monospace">${c.command}</span>` +
    (c.description ? `<br>${c.description}` : '');
  const q = document.getElementById('q');
  q.value = '';
  search('');
  if (scroll) document.getElementById('assigncard').scrollIntoView({behavior:'smooth'});
}

let searchTimer = null;
function search(q) {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(async () => {
    const r = await fetch('/api/commands?q=' + encodeURIComponent(q));
    const rows = await r.json();
    document.getElementById('results').innerHTML = rows.map(c =>
      `<div class="row" data-cmd="${c.name}">
         <span class="name">${c.tag}</span>
         <span class="cmd">${c.name}</span>
         <span class="tag">${c.description.slice(0, 42)}</span>
       </div>`).join('') || '<div class="detail">nichts gefunden</div>';
    for (const el of document.querySelectorAll('#results .row')) {
      el.onclick = () => assign(el.dataset.cmd);
    }
  }, 140);
}

async function assign(command) {
  if (!SELECTED) return toast('Erst einen Regler anklicken');
  const c = STATE.controls.find(x => x.id === SELECTED);
  const r = await fetch('/api/set', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({device: DEVICE, slot: c.slot, command})
  });
  const out = await r.json();
  if (!r.ok) return toast(out.error || 'Fehler');
  toast(`${c.label}: ${out.new ? out.new : command}`);
  await load(DEVICE);
  select(SELECTED, false);
  flash(SELECTED);
}

document.getElementById('q').oninput = e => search(e.target.value);
document.getElementById('device').onchange = e => load(parseInt(e.target.value, 10));
document.getElementById('btnclear').onclick = () => assign('sim/none/none');
document.getElementById('btnreload').onclick = () => load(DEVICE);
document.getElementById('undo').onclick = async () => {
  const r = await fetch('/api/undo', {method:'POST'});
  const out = await r.json();
  if (!r.ok) return toast(out.error || 'Fehler');
  toast('Wiederhergestellt'); await load(DEVICE);
};
for (const el of document.querySelectorAll('#mouse .ctl')) {
  el.onclick = () => selectMouse(el.dataset.id);
}
load(0);
</script>
</body></html>
"""


# ------------------------------------------------------------------ server ---
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if not length:
            return {}
        return json.loads(self.rfile.read(length).decode())

    def do_GET(self):
        path, _, query = self.path.partition("?")
        params = {}
        for part in query.split("&"):
            if "=" in part:
                k, v = part.split("=", 1)
                params[k] = urllib.parse.unquote_plus(v)
        if path in ("/", "/index.html"):
            body = HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/api/state":
            try:
                device = int(params.get("device", 0))
            except ValueError:
                device = 0
            return self._json(200, state(device))
        if path == "/api/commands":
            return self._json(200, search(params.get("q", "")))
        self._json(404, {"error": "not found"})

    def do_POST(self):
        try:
            body = self._body()
        except Exception:
            return self._json(400, {"error": "bad json"})
        if self.path == "/api/set":
            try:
                code, out = api_set(int(body.get("device", 0)),
                                    int(body.get("slot")),
                                    str(body.get("command")))
            except (TypeError, ValueError):
                code, out = 400, {"error": "device/slot fehlt"}
            return self._json(code, out)
        if self.path == "/api/undo":
            code, out = api_undo()
            return self._json(code, out)
        self._json(404, {"error": "not found"})


CURRENT_PRF = joymap.default_profile()


def serve(port, open_browser):
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = "http://127.0.0.1:%d/" % server.server_address[1]
    print("Input Map läuft: %s" % url)
    print("Profil: %s" % CURRENT_PRF)
    print("Strg+C beendet den Server.")
    if open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbeendet")
    finally:
        server.server_close()


def self_test():
    """Headless check: build state, hit the endpoints, no browser."""
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = "http://127.0.0.1:%d" % port

    with urllib.request.urlopen(base + "/") as resp:
        page = resp.read().decode()
    assert "<svg" in page and "DualShock" in page, "html missing"
    for marker in ("padcard", "mousecard", "selectMouse", "flash("):
        assert marker in page, "html missing " + marker

    with urllib.request.urlopen(base + "/api/state?device=0") as resp:
        st = json.loads(resp.read())
    assert len(st["controls"]) == 22, len(st["controls"])
    assert len(st["devices"]) >= 1, st["devices"]

    with urllib.request.urlopen(base + "/api/commands?q=lights") as resp:
        rows = json.loads(resp.read())
    assert rows and any(r["tag"] == "citx" for r in rows), rows[:2]

    bound = [c for c in st["controls"] if c["command"] != joymap.NONE]
    cats = sorted({c["cat"] for c in st["controls"]})
    assert all(c["cat_color"].startswith("#") for c in st["controls"]), "no colours"
    assert len(st["mouse"]) >= 10, "mouse inputs missing"
    assert any(m["id"] == "gesture" for m in st["mouse"]), "gesture missing"
    print("self-test: html ok, %d controls, %d bound, %d devices, %d search hits, cats %s"
          % (len(st["controls"]), len(bound), len(st["devices"]), len(rows),
             ",".join(cats)))
    server.shutdown()
    return 0


def main():
    global CURRENT_PRF
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--prf", default=joymap.default_profile())
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ns = ap.parse_args()
    CURRENT_PRF = ns.prf
    if ns.self_test:
        return self_test()
    serve(ns.port, not ns.no_browser)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
