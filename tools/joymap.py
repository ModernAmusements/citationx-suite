#!/usr/bin/env python3
"""
joymap.py -- minimal, offline mapper for X-Plane joystick profiles.

The suite's in-sim LEARN MODE can only record while X-Plane is open. This tool
works on the saved profile instead, so a controller can be inspected and
re-mapped with the sim closed.

Profile layout (Output/preferences/X-Plane Joystick Settings.prf):

    device block base = device * 160
    base +  0 ..   7  = hat switch, 8 positions, clockwise from up
    base +  8 ..  39  = physical buttons 0..31
    base + 40 .. 159  = unused

The hat is a HID hat, not eight buttons: X-Plane stores it in the same
_joy_BUTN_use range, which is why a hat press never shows up as a joystick
button in a plugin.

Commands:
    list                       devices and their full mapping
    show DEV [INPUT]           one device (optionally one input)
    set DEV INPUT COMMAND      write one binding
    clear DEV INPUT            unassign one input
    axes                       axis assignments from the profile
    commands [PATTERN]         every control: core sim/ commands + Citation X
                               xlua commands, marked when already bound
                               (--citx / --core filter, --bound / --unbound)
    lua DEV                    print FlyWithLua set_button_assignment lines
    check                      every bound command exists in the catalog
    log                        hardware X-Plane last saw (from Log.txt)
    backup                     timestamped copy of the profile
    restore                    newest backup back over the profile

INPUT names: hat_up hat_up_right hat_right hat_down_right hat_down
             hat_down_left hat_left hat_up_left, btn0..btn31, slotN.

Examples:
    python3 tools/joymap.py list
    python3 tools/joymap.py set 0 hat_up sim/general/hat_switch_up
    python3 tools/joymap.py commands --unbound
    python3 tools/joymap.py set 0 btn0 laminar/CitX/lights/cmd_taxi_toggle
"""

import argparse
import datetime
import glob
import os
import re
import shutil
import subprocess
import sys

BLOCK = 160
HAT = ["up", "up_right", "right", "down_right",
       "down", "down_left", "left", "up_left"]
HAT_NAMES = ["hat_" + n for n in HAT]
NONE = "sim/none/none"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PRF = os.path.expanduser(
    "~/X-Plane 12/Output/preferences/X-Plane Joystick Settings.prf")
DEFAULT_LOG = os.path.expanduser("~/X-Plane 12/Log.txt")
DEFAULT_COMMANDS = os.path.join(ROOT, "..", "Commands.txt")
DEFAULT_DATAREFS = os.path.join(ROOT, "..", "DataRefs.txt")
DEFAULT_AIRCRAFT_GLOB = os.path.expanduser(
    "~/X-Plane 12/Aircraft/*/Cessna_CitationX.acf")

BUTTON_RE = re.compile(r"^_joy_BUTN_use(\d+) (\S+)$")
CREATE_RE = re.compile(r'create_command\(\s*"([^"]+)"\s*(?:,\s*"([^"]*)")?')

# sim/joystick/joystick_axis_assignments enum, copied from the suite
# (CitationX_MasterSuite.lua: AXIS_FUNCS).
AXIS_FUNCS = [
    "none", "pitch", "roll", "yaw", "throttle", "collective", "l toe brake",
    "r toe brake", "prop", "mixture", "carb heat", "flaps", "thrust vec",
    "wing sweep", "speedbrakes", "displacement", "reverse", "elev trim",
    "ail trim", "rud trim", "throttle 1", "throttle 2", "throttle 3",
    "throttle 4", "prop 1", "prop 2", "prop 3", "prop 4", "mixture 1",
    "mixture 2", "mixture 3", "mixture 4", "reverse 1", "reverse 2",
    "reverse 3", "reverse 4", "gear", "tiller", "bak throttle", "cowl flaps",
]


# --------------------------------------------------------------- profile ---
def read_prf(path):
    """Return (lines, {global_index: value}) keeping the file byte-order."""
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as fd:
        lines = fd.read().splitlines()
    entries = {}
    for i, line in enumerate(lines):
        m = BUTTON_RE.match(line)
        if m:
            entries[int(m.group(1))] = (i, m.group(2))
    return lines, entries


def write_prf(path, lines):
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as fd:
        fd.write("\n".join(lines) + "\n")


def scalar(lines, key):
    for line in lines:
        if line.startswith(key + " "):
            return line[len(key) + 1:]
    return ""


def device_ids(lines):
    ids = []
    for line in lines:
        m = re.match(r"^_joy_unique_id(\d+) ", line)
        if m:
            ids.append(int(m.group(1)))
    return sorted(ids)


def input_name(slot):
    if slot < len(HAT):
        return HAT_NAMES[slot]
    if slot < 40:
        return "btn%d" % (slot - 8)
    return "slot%d" % slot


def input_slot(text):
    t = text.strip().lower()
    if t.startswith("hat_"):
        name = t[4:]
        if name in HAT:
            return HAT.index(name)
        raise SystemExit("unknown hat direction %r (use: %s)"
                         % (name, " ".join(HAT)))
    for prefix, base in (("btn", 8), ("button", 8)):
        if t.startswith(prefix) and t[len(prefix):].isdigit():
            n = int(t[len(prefix):])
            if 0 <= n < 32:
                return base + n
            raise SystemExit("button index out of range: %d" % n)
    if t.startswith("slot") and t[4:].isdigit():
        return int(t[4:])
    if t.isdigit():
        return int(t)
    raise SystemExit("unknown input %r" % text)


def is_running():
    try:
        out = subprocess.run(["pgrep", "-f", "X-Plane.app/Contents/MacOS/X-Plane"],
                             capture_output=True, text=True, timeout=5)
        return out.returncode == 0 and out.stdout.strip() != ""
    except Exception:
        return False


def newest_backup(prf):
    found = sorted(glob.glob(prf + ".bak-*"))
    return found[-1] if found else None


def make_backup(prf):
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S-%f")[:-3]
    dst = "%s.bak-%s" % (prf, stamp)
    shutil.copy2(prf, dst)
    return dst


# --------------------------------------------------------------- commands ---
def core_commands(path):
    """Every core command X-Plane ships, with its one-line description."""
    out = {}
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fd:
            for line in fd:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(None, 1)
                out[parts[0]] = parts[1].strip() if len(parts) > 1 else ""
    except FileNotFoundError:
        pass
    return out


def find_aircraft(path=None):
    if path:
        return os.path.abspath(os.path.expanduser(path))
    hits = sorted(glob.glob(DEFAULT_AIRCRAFT_GLOB))
    return os.path.dirname(hits[0]) if hits else None


def citix_commands(acf):
    """The commands the Citation X xlua plugin registers at runtime."""
    out = {}
    if not acf:
        return out
    root = os.path.join(acf, "plugins", "xlua", "scripts")
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as fd:
                    text = fd.read()
            except OSError:
                continue
            for match in CREATE_RE.finditer(text):
                out[match.group(1)] = match.group(2) or ""
    return out


def catalog(ns):
    """(core, aircraft, aircraft_path) -- the full set of bindable commands."""
    acf = find_aircraft(ns.aircraft)
    return core_commands(ns.commands), citix_commands(acf), acf


def known_names(ns):
    core, air, _ = catalog(ns)
    return set(core) | set(air)


def axis_name(value):
    if 0 <= value < len(AXIS_FUNCS):
        return AXIS_FUNCS[value]
    return "?"


# --------------------------------------------------------------- hardware ---
def hardware(log_path):
    """What X-Plane last enumerated, grouped per HID handle."""
    if not os.path.exists(log_path):
        return []
    boxes = []
    with open(log_path, "r", encoding="utf-8", errors="ignore") as fd:
        for line in fd:
            line = line.rstrip("\n")
            if "Hardware ADDED" in line:
                m = re.search(r"Hardware ADDED\(\w+, \w+\) - (.+?) at path (\S+)", line)
                if m:
                    boxes.append({"name": m.group(1), "path": m.group(2),
                                  "axes": [], "buttons": 0, "hats": []})
            elif boxes:
                m = re.search(r"AXIS Added Index: (\d+)", line)
                if m:
                    boxes[-1]["axes"].append(int(m.group(1)))
                m = re.search(r"BUTTON Added Index: (\d+)", line)
                if m:
                    boxes[-1]["buttons"] = max(boxes[-1]["buttons"], int(m.group(1)) + 1)
                m = re.search(r"HATSWITCH Added Index: (\d+).*It has (\d+) positions", line)
                if m:
                    boxes[-1]["hats"].append((int(m.group(1)), int(m.group(2))))
    return boxes


# --------------------------------------------------------------- printing ---
def print_device(lines, entries, dev, only_slot=None):
    loc = scalar(lines, "_joy_location%d" % dev) or "(no location)"
    uid = scalar(lines, "_joy_unique_id%d" % dev) or "(no id)"
    print("device %d  %s  [%s]" % (dev, loc, uid))
    base = dev * BLOCK
    rows = 0
    for slot in range(BLOCK):
        key = base + slot
        if key not in entries:
            continue
        if only_slot is not None and slot != only_slot:
            continue
        value = entries[key][1]
        if value == NONE and only_slot is None:
            continue
        print("  %-14s slot %-3d  %s" % (input_name(slot), slot, value))
        rows += 1
    if rows == 0:
        print("  (nothing assigned)")
    print()


# ------------------------------------------------------------------ main ---
def main():
    ap = argparse.ArgumentParser(
        description="Offline mapper for X-Plane joystick profiles.")
    ap.add_argument("--prf", default=DEFAULT_PRF, help="joystick profile")
    ap.add_argument("--log", default=DEFAULT_LOG, help="X-Plane Log.txt")
    ap.add_argument("--commands", default=DEFAULT_COMMANDS, help="Commands.txt")
    ap.add_argument("--aircraft", default=None,
                    help="Citation X folder (default: auto-detect the .acf)")
    ap.add_argument("--force", action="store_true",
                    help="write even if X-Plane is running or the command is unknown")
    ap.add_argument("--citx", action="store_true", help="commands: only Citation X")
    ap.add_argument("--core", action="store_true", help="commands: only core sim/")
    ap.add_argument("--bound", action="store_true", help="commands: only bound ones")
    ap.add_argument("--unbound", action="store_true", help="commands: only unbound ones")
    ap.add_argument("command", nargs="?", default="list",
                    choices=["list", "show", "set", "clear", "axes",
                                        "commands", "lua", "check", "log",
                                        "backup", "restore"])
    ap.add_argument("args", nargs="*")
    ns = ap.parse_args()

    if not os.path.exists(ns.prf):
        raise SystemExit("profile not found: %s" % ns.prf)
    lines, entries = read_prf(ns.prf)
    devs = device_ids(lines)

    if ns.command == "list":
        for dev in devs:
            print_device(lines, entries, dev)
        return 0

    if ns.command == "show":
        if not ns.args:
            raise SystemExit("usage: show DEV [INPUT]")
        dev = int(ns.args[0])
        slot = input_slot(ns.args[1]) if len(ns.args) > 1 else None
        print_device(lines, entries, dev, slot)
        return 0

    if ns.command == "axes":
        shown = 0
        for i in range(500):
            raw = scalar(lines, "_joy_AXIS_use%d" % i).strip()
            if not raw:
                continue
            try:
                use = int(raw)
            except ValueError:
                continue
            if use <= 0:
                continue
            center = scalar(lines, "_joy_center%d" % i).strip() or "-"
            null = scalar(lines, "_joy_null%d" % i).strip() or "-"
            print("axis %-3d %-14s center %-10s null %s"
                  % (i, axis_name(use), center, null))
            shown += 1
        if not shown:
            print("no axes assigned")
        return 0

    if ns.command == "commands":
        core, air, acf = catalog(ns)
        if not air:
            print("warning: no Citation X commands found (%s)"
                  % (acf or "aircraft not found -- use --aircraft"), file=sys.stderr)
        bound = {value for (_, value) in entries.values()}
        pattern = ns.args[0].lower() if ns.args else ""
        only_core = ns.core and not ns.citx
        rows = []
        if not only_core:
            rows += [(n, d, "citx", n in bound) for n, d in air.items()]
        if ns.core:
            rows += [(n, d, "core", n in bound) for n, d in core.items()]
        shown = 0
        for name, desc, tag, is_bound in sorted(rows):
            if pattern and pattern not in name.lower() and pattern not in desc.lower():
                continue
            if ns.bound and not is_bound:
                continue
            if ns.unbound and is_bound:
                continue
            print("%s %-5s %-54s %s" % ("*" if is_bound else " ", tag, name, desc))
            shown += 1
        print("%d shown | %d Citation X command(s), %d core command(s)"
              % (shown, len(air), len(core)))
        if not ns.core and air:
            print("tip: --core lists the sim/ commands, '*' marks a bound command")
        return 0

    if ns.command == "log":
        boxes = hardware(ns.log)
        if not boxes:
            print("no HID hardware found in %s" % ns.log)
            return 0
        for box in boxes:
            print("%s" % box["name"])
            print("  path    %s" % box["path"])
            print("  axes    %s" % (", ".join(map(str, box["axes"])) or "-"))
            print("  buttons %d" % box["buttons"])
            hats = ", ".join("index %d (%d positions)" % h for h in box["hats"])
            print("  hats    %s" % (hats or "-"))
            print()
        return 0

    if ns.command == "check":
        known = known_names(ns)
        bad = 0
        assigned = 0
        for key in sorted(entries):
            value = entries[key][1]
            if value == NONE:
                continue
            assigned += 1
            if value in known:
                continue
            dev, slot = divmod(key, BLOCK)
            print("MISSING  device %d  %-14s  %s" % (dev, input_name(slot), value))
            bad += 1
        print("%d assigned binding(s), %d unknown command(s)" % (assigned, bad))
        return 1 if bad else 0

    if ns.command == "lua":
        if not ns.args:
            raise SystemExit("usage: lua DEV")
        dev = int(ns.args[0])
        for slot in range(BLOCK):
            key = dev * BLOCK + slot
            if key in entries and entries[key][1] != NONE:
                print('set_button_assignment( (%d*160) + %d, "%s" )'
                      % (dev, slot, entries[key][1]))
        return 0

    if ns.command == "backup":
        print(make_backup(ns.prf))
        return 0

    if ns.command == "restore":
        src = newest_backup(ns.prf)
        if not src:
            raise SystemExit("no backup next to %s" % ns.prf)
        if is_running() and not ns.force:
            raise SystemExit("X-Plane is running -- close it first (or --force)")
        shutil.copy2(src, ns.prf)
        # Consume the snapshot so a second restore steps further back.
        os.rename(src, src.replace(".bak-", ".restored-"))
        print("restored %s" % src)
        nxt = newest_backup(ns.prf)
        print("next undo: %s" % (nxt or "(none left)"))
        return 0

    if ns.command not in ("set", "clear"):
        raise SystemExit("unhandled command")

    if len(ns.args) < 2:
        raise SystemExit("usage: %s DEV INPUT [COMMAND]" % ns.command)
    dev = int(ns.args[0])
    slot = input_slot(ns.args[1])
    if dev not in devs:
        raise SystemExit("device %d not in profile (have: %s)"
                         % (dev, ", ".join(map(str, devs))))
    if slot >= BLOCK:
        raise SystemExit("slot %d outside the device block" % slot)

    value = NONE
    if ns.command == "set":
        if len(ns.args) < 3:
            raise SystemExit("usage: set DEV INPUT COMMAND")
        value = ns.args[2]
        known = known_names(ns)
        if known and value not in known and value != NONE and not ns.force:
            raise SystemExit("%s is neither a core command nor a Citation X command"
                             " (--force to write anyway)" % value)

    if is_running() and not ns.force:
        raise SystemExit("X-Plane is running -- it rewrites this file on exit.\n"
                         "Close the sim first (or --force if you know better).")

    key = dev * BLOCK + slot
    if key not in entries:
        raise SystemExit("slot %d is not stored in the profile" % slot)
    index, old = entries[key]
    if old == value:
        print("unchanged: %s <= %s" % (input_name(slot), value))
        return 0
    lines[index] = "_joy_BUTN_use%d %s" % (key, value)
    backup = make_backup(ns.prf)
    write_prf(ns.prf, lines)
    print("device %d  %s  %s -> %s" % (dev, input_name(slot), old, value))
    print("backup   %s" % backup)
    return 0


if __name__ == "__main__":
    sys.exit(main())
