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

## Mouse

Two separate things:

### 1. In-sim mouse wheel (always active)

Hovering over the 3-D cockpit, the **mouse wheel** drives the heading bug by
`CONFIG.heading_step_deg` (default 1°) per click. Set `thumbwheel_altitude = true`
to make it drive ALT SEL instead (100 ft per click). This is the suite's
`do_on_mouse_wheel` handler, not a Logi assignment.

### 2. Logitech MX buttons (Logi Options+)

FlyWithLua never sees the mouse button itself — only the keystroke Logi Options+
sends. Assign each MX button to one of these combos:

| MX control (recommended) | Send this | Action |
| --- | --- | --- |
| Middle click | `Ctrl+Shift+6` | AP master |
| Thumb button back | `Ctrl+Shift+7` | AP heading hold |
| Thumb button forward | `Ctrl+Shift+8` | Thrust reversers |
| Gesture button | `Ctrl+Shift+9` | ALT SEL down (−1000 ft) |
| Gesture button + Shift | `Ctrl+Shift+0` | ALT SEL up (+1000 ft) |
| Thumb wheel left | `Ctrl+Shift+←` | HDG SEL left (5°) |
| Thumb wheel right | `Ctrl+Shift+→` | HDG SEL right (5°) |
| Mode-shift | `Ctrl+Opt+5` | External power |

These are only suggestions — every combo below is a valid target.

### Keyboard / MX layers (all live)

| Layer | Keys | Covers |
| --- | --- | --- |
| Lights | `Ctrl+Shift 1–5` | nav, beacon, strobe, taxi, landing |
| Autopilot | `Ctrl+Shift 6–8`, `9/0`, `←/→` | master, heading hold, reversers, ALT down/up, heading |
| Flight ops | `Ctrl+Shift A–Z` | AP modes, gear, ignition, starters, fuel transfer/boost/crossfeed, windshield air, yaw damper |
| Electrical / APU | `Ctrl+Opt 1–0` | batteries, generators, external power, avionics, EICAS, APU master/start/gen |
| Ice / hyd / lights / O2 | `Ctrl+Opt A–Z` | engine + surface ice, pitot/stab heat, cabin dump, iso valve, master caution, hydraulic pumps, antiskid, gravity flow, FLC, ground idle, tail/recognition/cabin lights, passenger O2 |

The full command list is `CITX_BINDINGS` in `Scripts/CitationX_MasterSuite.lua`.

## If one control is wrong

Tell me the **PS4 button name** and what it should do, e.g. “L1 should be brakes”. The
profile stores numeric indices, so the name → index translation is:

`0 Cross · 1 Triangle · 2 Circle · 3 Square · 4 L1 · 5 R1 · 6 L2 · 7 R2 ·
8 Share · 9 Options · 10 R3 · 11 L3 · 12 Touchpad · 13 PS`

Backups: `citX - Joysticks.prf.bak-2026-10-27` and `.bak2-2026-10-27`.
