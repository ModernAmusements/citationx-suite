# PS4 controller mapping — Citation X (`citX` profile)

X-Plane profile: `Output/preferences/control profiles/citX - Joysticks.prf`
Device: DUALSHOCK 4 Wireless Controller (VID 054c, PID 09cc) — the same map is written
into **both** device slots, so it behaves identically over USB and Bluetooth.

Axes: left stick = pitch/roll, right stick X = yaw, right stick Y = heading bug.
X-Plane lists the right stick Y as **Axis 3** and leaves it unassigned; the suite reads it
(the only input it reads).

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

- **One input only:** right stick Y (**Axis 3**, spring-centred and unassigned in the profile)
  turns the heading bug. Push up/down to change HDG SEL; it is rate-based, 30°/s at full
  deflection. Raw axis 3 or 28 depending on which device slot X-Plane gives the pad, so both
  are pinned.
- **Everything else is OFF at load**, so this profile is the only input map: keyboard layers,
  L2/R2 analog throttle, stick ALT SEL, arrow-key view tilt, R3 cockpit look, axis optimizer
  and the realism handling curve. Switch a layer on from the MasterSuite `CONTROL PANEL` row
  (or the macro menu) if you want it back — it will compete with the profile again.
- D-pad and face buttons are never touched by the suite; X-Plane owns them.

## Mouse

Two separate things:

### 1. In-sim mouse wheel

| Control | Action |
| --- | --- |
| Wheel | View zoom in/out (X-Plane native; the suite does not consume it) |

### 2. Logitech MX buttons (Logi Options+)

FlyWithLua never sees the mouse button itself — only the keystroke Logi Options+
sends. Assign each MX button to one of these combos:

| MX control (recommended) | Send this | Action |
| --- | --- | --- |
| Wheel click | `Ctrl+Shift+5` | Both landing lights |
| Gesture button | `Ctrl+Shift+5` | Both landing lights |
| Thumb button back | `Ctrl+Shift+9` | ALT SEL down (100 ft) |
| Thumb button forward | `Ctrl+Shift+0` | ALT SEL up (100 ft) |
| `Ctrl+Shift+,` | Pitch trim down (keyboard knob) |
| `Ctrl+Shift+.` | Pitch trim up (keyboard knob) |
| Thumb wheel left | `Ctrl+Shift+1` | NAV lights |
| Thumb wheel right | `Ctrl+Shift+2` | Beacon lights |
| Mode-shift | `Ctrl+Opt+M` | Master caution |
| Keyboard rotary knob ← / → | `Ctrl+Shift+,` / `Ctrl+Shift+.` | Pitch trim down / up |

These are only suggestions — every combo below is a valid target.

### Keyboard / MX layers (available, OFF at load)

These layers belong to the suite, not to X-Plane. They are **off at load** (the `INPUT MAPPER`
row switches them on); while they are off, the keys pass straight to X-Plane. Each layer owns
what the pad cannot reach — no command is duplicated between the PS4 profile and the keyboard.

### Ctrl+Shift + digit / arrow

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+1` | NAV lights |
| `Ctrl+Shift+2` | Beacon lights |
| `Ctrl+Shift+3` | Strobe lights |
| `Ctrl+Shift+4` | Taxi lights |
| `Ctrl+Shift+5` | Both landing lights |
| `Ctrl+Shift+9` | ALT SEL down (100 ft) |
| `Ctrl+Shift+0` | ALT SEL up (100 ft) |
| `Ctrl+Shift+,` | Pitch trim down (keyboard knob) |
| `Ctrl+Shift+.` | Pitch trim up (keyboard knob) |
| `Ctrl+Shift+7` | AP heading hold |

### Ctrl+Shift + letter

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+A` | AP toggle |
| `Ctrl+Shift+B` | AP half bank |
| `Ctrl+Shift+C` | AP CWS |
| `Ctrl+Shift+D` | AP ALT |
| `Ctrl+Shift+H` | Heading sync |
| `Ctrl+Shift+I` | Fuel transfer L |
| `Ctrl+Shift+J` | Fuel transfer R |
| `Ctrl+Shift+K` | Start engine L |
| `Ctrl+Shift+L` | Start engine R |
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

- **PS4 buttons:** every physical control is assigned.
- **PS4 axes:** right stick Y drives the heading bug (the only input the suite reads); every
  other axis belongs to the profile.
- **Mouse wheel:** X-Plane view zoom — deliberately not used by the suite.
- **Free keystrokes** (no duplicate of the pad): `Ctrl+Shift+6`, `Ctrl+Shift+8`, `Ctrl+Shift+↑/↓/←/→`, `Ctrl+Shift+E/F`, `Ctrl+Opt+E/F`, all `Ctrl+Opt` arrows, and any MX button not mapped in Logi Options+.

## View

| Input | Action |
| --- | --- |
| **↑ / ↓ arrow keys** | Tilt the view up / down (`sim/general/hat_switch_up/down` in `X-Plane Keys.prf`) |
| **Right-click + drag** | Free look, X-Plane native — the only smooth mouse-look; FlyWithLua gets clicks/wheel only, not motion |
| **Mouse wheel** | View zoom in/out |
| **Wheel click** | Both landing lights |
| **Gesture button** | Both landing lights |
| **Thumb back / forward** | ALT SEL down / up (100 ft) |
| **Right stick ←/→** | Yaw |
| **Right stick ↑/↓** | Heading bug (suite, Axis 3) |

If you want a mouse button to tilt, map it in Logi Options+ to send **↑** or **↓** —
those keys now drive the view.

## If one control is wrong

Tell me the **PS4 button name** and what it should do, e.g. “L1 should be brakes”. The
profile stores numeric indices, so the name → index translation is:

`0 Cross · 1 Triangle · 2 Circle · 3 Square · 4 L1 · 5 R1 · 6 L2 · 7 R2 ·
8 Share · 9 Options · 10 R3 · 11 L3 · 12 Touchpad · 13 PS`

Backups: `citX - Joysticks.prf.bak-2026-10-27` and `.bak2-2026-10-27`.
