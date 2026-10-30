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
    lua DEV                    print FlyWithLua set_button_assignment lines
    check                      every assigned command exists in Commands.txt
    log                        hardware X-Plane last saw (from Log.txt)
    backup                     timestamped copy of the profile
    restore                    newest backup back over the profile

INPUT names: hat_up hat_up_right hat_right hat_down_right hat_down
             hat_down_left hat_left hat_up_left, btn0..btn31, slotN.

Examples:
    python3 tools/joymap.py list
    python3 tools/joymap.py set 0 hat_up sim/general/hat_switch_up
    python3 tools/joymap.py set 0 btn0 sim/flight_controls/flaps_up
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

BUTTON_RE = re.compile(r"^_joy_BUTN_use(\d+) (\S+)$")


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
def known_commands(path):
    names = set()
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fd:
            for line in fd:
                line = line.strip()
                if line and not line.startswith("#"):
                    names.add(line.split()[0])
    except FileNotFoundError:
        pass
    return names


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
    ap.add_argument("--force", action="store_true",
                    help="write even if X-Plane is running or the command is unknown")
    ap.add_argument("command", choices=["list", "show", "set", "clear", "lua",
                                        "check", "log", "backup", "restore"])
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
        known = known_commands(ns.commands)
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
        known = known_commands(ns.commands)
        if known and value not in known and value != NONE and not ns.force:
            raise SystemExit("%s is not in %s (--force to write anyway)"
                             % (value, ns.commands))

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
