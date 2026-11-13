# PS4 controller mapping — Citation X

Active aircraft profile: `Output/preferences/control profiles/PS4-CitationX - Joysticks.prf`.
X-Plane maps it to the modded aircraft in `Miscellaneous.prf`
(`P acf_profile Cessna___Citation___X_mods PS4-CitationX`); the stock
`Laminar Research/Cessna Citation X` still uses `citX - Joysticks.prf`.

Device: DUALSHOCK 4 Wireless Controller (VID 054c, PID 09cc) — the same map is written
into **both** device slots, so it behaves identically over USB and Bluetooth.

Axes: left stick = pitch/roll, right stick X = yaw, right stick Y = **free**. The suite
registers no keystroke handler, no button map and no axis handler, so every input below is
X-Plane's own profile; the suite reads only the **mouse wheel** (section below).

## Buttons (PS4 notation)

| Control | Action |
| --- | --- |
| **Cross** | Flaps down |
| **Triangle** | Flaps up |
| **Circle** | Brakes |
| **Square** | Landing gear toggle |
| **L1** | Pitch trim down |
| **R1** | Pitch trim up |
| **L2** | Throttle down |
| **R2** | Throttle up |
| **Share** | Autopilot servos toggle |
| **Options** | Level change (FLC) |
| **R3** (right stick click) | Thrust reversers |
| **L3** (left stick click) | Speed brakes |
| **Touchpad** | Landing lights |
| **PS** | Quick look 0 |

> **L2 / R2 are buttons in this profile**, not axes: X-Plane steps the throttles with
> `sim/engines/throttle_down` / `throttle_up`. The suite does not touch them.

## D-pad (8-way hat)

| Direction | Action |
| --- | --- |
| Up | Altitude up |
| Down | Altitude down |
| Left | Heading down |
| Right | Heading up |
| Up-right | Vertical speed up |
| Up-left | Vertical speed down |
| Down-right | Approach |
| Down-left | NAV |

## Suite input (v3.0)

The suite consumes exactly one pilot input, and only when the selected wheel is one it owns:

| Mouse | Action |
| --- | --- |
| main wheel (wheel 0) | X-Plane view zoom — the suite leaves it alone |
| thumbwheel (wheel 1) | heading bug, 10° per notch |
| wheel 2 | ALT SEL, 100 ft per notch |

`CitationXSuite/wheel_report` logs which wheel number the mouse sends;
`CitationXSuite/wheel_map_swap` exchanges 1 and 2. The **WHEEL = ALT SEL** row on the
Master Suite hub disables the wheel layer entirely and returns both wheels to X-Plane.

There is **no** Lua keyboard layer, no thumb-button ALT SEL, no stick-to-heading knob and no
right-stick cockpit look in v3.0. `Ctrl+Shift+9` / `Ctrl+Shift+0` (the MX thumb buttons) pass
straight through to X-Plane like any other keystroke. Bind them in X-Plane's own keyboard
settings if you want them to do something.

`tools/joymap.py` / `tools/joymap_gui.py` read and edit the active profile with the sim closed.

## View

| Input | Action |
| --- | --- |
| **↑ / ↓ arrow keys** | Tilt the view up / down (X-Plane's own keys) |
| **Right-click + drag** | Free look, X-Plane native |
| **Mouse wheel** | View zoom in/out |
| **Right stick ←/→** | Yaw |
| **Right stick ↑/↓** | Free — the suite does not read it |

## If one control is wrong

Tell me the **PS4 button name** and what it should do, e.g. “L1 should be brakes”. The
profile stores numeric indices, so the name → index translation is:

`0 Cross · 1 Triangle · 2 Circle · 3 Square · 4 L1 · 5 R1 · 6 L2 · 7 R2 ·
8 Share · 9 Options · 10 R3 · 11 L3 · 12 Touchpad · 13 PS`

Backups: `PS4-CitationX - Joysticks.prf.bak-2026-10-30-233044` and
`citX - Joysticks.prf.bak-2026-10-27`.
