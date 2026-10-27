# PS4 controller mapping — Citation X (`citX` profile)

X-Plane profile: `Output/preferences/control profiles/citX - Joysticks.prf`
Device: DUALSHOCK 4 Wireless Controller (VID 054c, PID 09cc) — the same map is written
into **both** device slots, so it behaves identically over USB and Bluetooth.

Axes: left stick = pitch/roll, right stick X = yaw, right stick Y = view left/right.

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

## Suite additions (not part of the X-Plane profile)

- Right stick (spring-centred, unassigned axis) drives the heading bug — L2/R2 never do.
- D-pad and face buttons are never touched by the suite; X-Plane owns them.
- Keyboard layer: `Ctrl+Shift` / `Ctrl+Opt` combinations (see `README.md`).

## If one control is wrong

Tell me the **PS4 button name** and what it should do, e.g. “L1 should be brakes”. The
profile stores numeric indices, so the name → index translation is:

`0 Cross · 1 Triangle · 2 Circle · 3 Square · 4 L1 · 5 R1 · 6 L2 · 7 R2 ·
8 Share · 9 Options · 10 R3 · 11 L3 · 12 Touchpad · 13 PS`

Backups: `citX - Joysticks.prf.bak-2026-10-27` and `.bak2-2026-10-27`.
