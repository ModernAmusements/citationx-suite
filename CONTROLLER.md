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

> **L2 / R2 are analog on the DS4.** The suite reads the trigger axes directly
> (USB axes 4/5, Bluetooth 29/30) and steps the throttle while a trigger is
> held, through `sim/engines/throttle_down` / `throttle_up`. The profile's
> button 6/7 entries only cover the digital end-stop.

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

### Ctrl+Shift + digit / arrow

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+1` | NAV lights |
| `Ctrl+Shift+2` | Beacon lights |
| `Ctrl+Shift+3` | Strobe lights |
| `Ctrl+Shift+4` | Taxi lights |
| `Ctrl+Shift+5` | Landing lights |
| `Ctrl+Shift+6` | AP master |
| `Ctrl+Shift+7` | AP heading hold |
| `Ctrl+Shift+8` | Thrust reversers |
| `Ctrl+Shift+9` | ALT SEL down |
| `Ctrl+Shift+0` | ALT SEL up |
| `Ctrl+Shift+←` | HDG SEL left |
| `Ctrl+Shift+→` | HDG SEL right |

### Ctrl+Shift + letter

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+A` | AP toggle |
| `Ctrl+Shift+B` | AP half bank |
| `Ctrl+Shift+C` | AP CWS |
| `Ctrl+Shift+D` | AP ALT |
| `Ctrl+Shift+G` | Gear toggle |
| `Ctrl+Shift+H` | Heading sync |
| `Ctrl+Shift+I` | Fuel transfer L |
| `Ctrl+Shift+J` | Fuel transfer R |
| `Ctrl+Shift+K` | Start engine L |
| `Ctrl+Shift+L` | Start engine R |
| `Ctrl+Shift+M` | AP APP |
| `Ctrl+Shift+N` | AP NAV |
| `Ctrl+Shift+O` | Ignition L |
| `Ctrl+Shift+P` | Ignition R |
| `Ctrl+Shift+Q` | Boost pump L |
| `Ctrl+Shift+R` | Boost pump R |
| `Ctrl+Shift+S` | AP VS |
| `Ctrl+Shift+T` | Starter stop |
| `Ctrl+Shift+U` | Engine sync |
| `Ctrl+Shift+V` | AP VNAV |
| `Ctrl+Shift+W` | Windshield air |
| `Ctrl+Shift+X` | Crossfeed L |
| `Ctrl+Shift+Y` | Yaw damper |
| `Ctrl+Shift+Z` | Crossfeed R |

### Ctrl+Opt + digit

| Keys | Action |
| --- | --- |
| `Ctrl+Opt+1` | Battery L |
| `Ctrl+Opt+2` | Battery R |
| `Ctrl+Opt+3` | Generator L |
| `Ctrl+Opt+4` | Generator R |
| `Ctrl+Opt+5` | External power |
| `Ctrl+Opt+6` | Avionics |
| `Ctrl+Opt+7` | Avionics EICAS |
| `Ctrl+Opt+8` | APU master |
| `Ctrl+Opt+9` | APU start |
| `Ctrl+Opt+0` | APU generator |

### Ctrl+Opt + letter

| Keys | Action |
| --- | --- |
| `Ctrl+Opt+A` | Ice engine L |
| `Ctrl+Opt+B` | Ice engine R |
| `Ctrl+Opt+C` | Wing ice light |
| `Ctrl+Opt+D` | Slat heat |
| `Ctrl+Opt+G` | Stab heat L |
| `Ctrl+Opt+H` | Stab heat R |
| `Ctrl+Opt+I` | Pitot heat L |
| `Ctrl+Opt+J` | Pitot heat R |
| `Ctrl+Opt+K` | Cabin dump |
| `Ctrl+Opt+L` | Iso valve |
| `Ctrl+Opt+M` | Master caution |
| `Ctrl+Opt+N` | Aux hyd pump |
| `Ctrl+Opt+O` | Unload pump A |
| `Ctrl+Opt+P` | Unload pump B |
| `Ctrl+Opt+Q` | Antiskid |
| `Ctrl+Opt+R` | Gravity flow |
| `Ctrl+Opt+S` | AP FLC |
| `Ctrl+Opt+T` | Ground idle |
| `Ctrl+Opt+U` | Tail flood light |
| `Ctrl+Opt+V` | Recognition lights |
| `Ctrl+Opt+W` | Cabin master light |
| `Ctrl+Opt+X` | Landing light L |
| `Ctrl+Opt+Y` | Landing light R |
| `Ctrl+Opt+Z` | Passenger O2 |

### Free inputs

- **PS4 buttons:** every physical control is assigned — Cross/Triangle/Circle/Square, L1/R1, L2/R2, Share, Options, L3/R3, Touchpad, PS and all eight D-pad directions. Nothing is free.
- **PS4 axes:** left stick (roll/pitch), right stick X (yaw), L2/R2 (throttle, read by the suite). The right stick Y (USB axis 3 / Bluetooth 28) is unassigned and free if you want a view axis there.
- **Mouse wheel:** used for the heading bug. ALT SEL is free if you set `thumbwheel_altitude = true` (and turn `thumbwheel_heading` off).
- **MX buttons:** FlyWithLua only receives keystrokes, so any MX button not mapped in Logi Options+ is free. Free keystroke slots: `Ctrl+Shift+E`, `Ctrl+Shift+F`, `Ctrl+Shift+↑/↓`, `Ctrl+Opt+E`, `Ctrl+Opt+F` and all `Ctrl+Opt` arrows. Plain keys belong to X-Plane.

The full command list is `CITX_BINDINGS` in `Scripts/CitationX_MasterSuite.lua`.

## If one control is wrong

Tell me the **PS4 button name** and what it should do, e.g. “L1 should be brakes”. The
profile stores numeric indices, so the name → index translation is:

`0 Cross · 1 Triangle · 2 Circle · 3 Square · 4 L1 · 5 R1 · 6 L2 · 7 R2 ·
8 Share · 9 Options · 10 R3 · 11 L3 · 12 Touchpad · 13 PS`

Backups: `citX - Joysticks.prf.bak-2026-10-27` and `.bak2-2026-10-27`.
