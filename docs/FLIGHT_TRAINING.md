# Learning to fly the Citation X

A written syllabus to go with `Scripts/CitationX_FlightInstructor.lua` — twelve graded
lessons in the aeroplane, and the ground school you need before you fly them.

The panel grades what you actually do with the aeroplane. It does not fly for you and it
does not draw a telemetry HUD: the numbers it reads are already on the PFD, EICAS and
synoptics. The only extra text on screen is the lesson's own coach line, the readout of
the values being graded, and a two-second toast.

**Sources.** All limitations and speeds below are from the FAA Approved Flight Manual
(Section II, Limitations) and the Model 750 Operating Manual supplied with the aircraft.
Where a figure is a training simplification rather than a book number it is marked
*(training target)*. See [Reference documents](#7-reference-documents).

---

## 1. How the instructor works

Open it from the Master Suite hub (`FLIGHT INSTRUCTOR`) or with the macro
`flight instructor`. Commands you can bind:

| Command | Does |
| --- | --- |
| `CitationXInstructor/toggle_panel` | show/hide the panel |
| `CitationXInstructor/start_next` | start the next lesson |
| `CitationXInstructor/menu` | back to the lesson list (clears any injected failure) |
| `CitationXInstructor/finish` | end the current lesson and grade it |
| `CitationXInstructor/lesson_<key>` | jump straight to one lesson |

The flow is always **LESSON LIST → BRIEF → FLYING → DEBRIEF**.

* **Brief.** Read the three-line brief and the setup. The setup tells you exactly how to
  position the aeroplane with X-Plane's own Flight Configuration — the panel cannot
  teleport you, and it should not: setting the scenario up is part of the lesson.
* **Flying.** `START` arms the lesson. Most lessons wait until you are in the right place
  (rolling, established on final, above 20,000 ft) and say so: `ARMED - <what to do>`.
  Until then nothing is graded and the score stays at zero.
* **Grading.** Each item self-checks against the simulator's datarefs and must be **held
  for a moment** (0.6 s by default, 1.5–2 s for the ones that matter). A single frame of
  luck does not score. When an item is met it turns green and gets an `X`.
* **Coach.** The line above the list is the next thing to do, taken from the first
  unmet item's hint. If you are lost, read it.
* **Debrief.** The lesson ends on touchdown, on the lesson's own end condition, or when
  you press `FINISH & GRADE`. You get a percentage, a letter, and PASS/MISS per item.
  `RETRY` repeats it, `NEXT` moves on, `MENU` goes back.
* **Best score.** The best percentage per lesson is kept in
  `CitationX_TrainingProgress.txt` in the FlyWithLua `Scripts` folder, so it survives a
  reload. `RESET PROGRESS` on the menu clears it.

**Grading scale.** 100% = A, 85%+ = B+, 70%+ = B, 60%+ = C, anything else = D/F.
A lesson is "passable" at 70%, but do not move on below 85%, and do not call a lesson
learned until you can score 100% twice in a row, in different conditions.

**Failures.** Three lessons inject their own failure through the QRH trainer
(`CitationX_FailureTrainer.lua`): engine failure at 400 ft, flap actuator jam, and cabin
decompression. You work the same QRH panel a real crew would, and the lesson's
"QRH PROCEDURE COMPLETE" item reads the trainer's actual checklist state — not a
duplicate switch list. Leaving the lesson clears the failure it injected.

---

## 2. Setting up a lesson in X-Plane

1. **Aircraft.** `Cessna Citation X` (the `C750`). The instructor refuses to start in any
   other aeroplane — that is deliberate, every speed in it is a C750 number.
2. **Weight.** Flight Configuration → payload/fuel to roughly the weight the brief asks
   for (typically 24,000 lb for departure lessons, 26,000–28,000 lb for landings). The
   instructor computes Vref, VR and V2 from the **actual** total weight every time you
   start a lesson, so the targets move with you.
3. **Position.** Use Flight Configuration's runway or approach starts:
   * *runway start* for takeoff, rejected takeoff and engine-failure lessons;
   * *approach start* (3 NM or 10 NM final) for the ILS, RNAV, visual and crosswind
     lessons — the sim places you on final and tunes NAV1;
   * *air start* on downwind at 1,500 ft AGL for the pattern lesson;
   * *cruise at FL350* for the emergency descent.
4. **Weather.** Calm and CAVOK for the first attempt at anything; then add the wind,
   turbulence and visibility the lesson calls for. The crosswind lesson needs a custom
   surface wind 90° to the runway at 10 kt.
5. **Reload.** After editing any suite file: FlyWithLua → *Reload all Lua script files*.

> If you want the sim's own failure menu instead of the QRH trainer's injection, you can
> use it — but the lesson's QRH item will then never complete, because the trainer will
> not know a failure is active.

---

## 3. Ground school

### 3.1 The aeroplane in one page

The Citation X is a swept-wing, slatted, twin-turbofan business jet with a
Honeywell Primus 2000 glass cockpit, FADEC engines, three hydraulic systems (A, B and
standby), and a pressurised cabin. The wing has **slats** as well as flaps, and that is
why the flap schedule has four detents and why a flap failure is not a "no-flap"
landing — it is a **flaps 15°** landing.

What you actually manage, and what the instructor grades:

| System | What matters in flight | Where you see it |
| --- | --- | --- |
| Engines | N1 for thrust, ITT for limits, N2 for start | EICAS |
| Flaps/slats | 0 / 5° / 15° / 35°, Vfe 250 / 210 / 180 | EICAS + flap indicator |
| Gear | Vlo/Vle 210, three greens | gear indicator + CAS |
| Speedbrakes | no upper limit, **minimum Vref+15**, not below 500 ft AGL in flight | CAS / lever |
| Autopilot | min use height 1,000 ft cruise, 170 ft Cat I, 400 ft non-precision, 80 ft Cat II | FGS annunciation |
| Pressurisation | cabin altitude, emergency descent at 10,000 ft | EICAS |
| Fuel | 500 lb minimum per wing for takeoff, 400 lb max asymmetry | EICAS fuel |

### 3.2 Limitations

**Weights and altitudes**

| Limit | Value |
| --- | --- |
| Maximum takeoff weight | 36,100 lb |
| Maximum landing weight | 31,800 lb |
| Maximum zero-fuel weight | 24,400 lb |
| Maximum operating altitude | 51,000 ft |
| Maximum altitude for flap/gear extension | 18,000 ft |
| Takeoff/landing field altitude limit | 14,000 ft |
| Maximum tailwind component | 10 kt |

**Speeds**

| Limit | Value |
| --- | --- |
| Vmo below 8,000 ft | 270 KIAS |
| Vmo 8,000–30,650 ft | 350 KIAS |
| Mmo above 30,650 ft | 0.92 (0.82 with mach trim off) |
| Vfe flaps 5° | 250 KIAS |
| Vfe flaps 15° | 210 KIAS |
| Vfe flaps full (35°) | 180 KIAS |
| Vlo / Vle | 210 KIAS |
| Slat extended speed | 250 KIAS |
| Turbulent air penetration | 300 KIAS / 0.90 M |
| Minimum speedbrake extension | Vref + 15 KIAS |
| Minimum single-engine enroute climb | 190 KIAS |
| Maximum tire ground speed | 210 kt |
| Demonstrated crosswind | 21 kt (not limiting) |
| Crosswind with manual flight controls, or slat asymmetry | 10 kt |
| Crosswind, Category II | 15 kt |

**Other operational limits**

* Speedbrakes: not below **500 ft AGL** in flight.
* Fuel: **500 lb** minimum in each wing for takeoff; **400 lb** maximum asymmetry
  (800 lb emergency).
* Autopilot minimum use height: **1,000 ft** AGL cruise, **170 ft** Cat I ILS,
  **400 ft** non-precision, **80 ft** Cat II.
* Autopilot coupled ILS with flaps up is prohibited.
* Category II: flaps **full** only; max final approach speed Vref+20 at the outer marker,
  slowing to Vref by decision height.

### 3.3 Speeds

**Landing reference speeds** (flaps full, from the simplified landing criteria):

| Weight (lb) | 23,000 | 24,000 | 26,000 | 28,000 | 30,000 | 31,800 |
| --- | --- | --- | --- | --- | --- | --- |
| **Vref** | 108 | 110 | 115 | 121 | 126 | 132 |
| **Vapp** | 113 | 116 | 121 | 126 | 131 | 136 |

`Vapp` is the speed over the fence; `Vref` is the target by the threshold. The panel
computes Vref by linear interpolation between those six points, so 27,000 lb gives
118 KIAS.

**Takeoff V-speeds** (flaps 15, at or below 2,000 ft MSL and 30 °C — the AFM simplified
criteria; for anything else use the AFM Section IV charts or the FMS):

| Weight range (lb) | V1 | VR | V2 | Min runway |
| --- | --- | --- | --- | --- |
| 23,000–27,000 | 114 | 116 | 129 | 4,500 ft |
| 27,001–30,000 | 116 | 119 | 127 | 5,000 ft |
| 30,001–33,000 | 125 | 128 | 132 | 6,000 ft |
| 33,001–35,700 | 133 | 134 | 137 | 7,000 ft |

Those are the exact bands the instructor uses for `tkof_clean`, `rto` and
`engfail_tkof`. The non-monotonic V2 (129 then 127) is in the AFM table, not a typo.

**Maneuvering minimums** (the numbers that keep you out of the stall):

| Configuration | Minimum speed |
| --- | --- |
| Clean | Vref + 30 |
| Flaps 15° | Vref + 20 |
| Flaps full | Vref + 10 |
| On final, landing assured | Vref to Vref + 10 |

Add **half the gust factor above 5 kt** to Vref in gusty wind.

### 3.4 The normal profile

**Takeoff and climb**

1. Line up, set takeoff thrust, check N1 stabilised.
2. Rotate at **VR** to about 10° pitch; fly **V2** to V2+10.
3. Positive rate → **gear up**; climb at V2+10 to 3,000 ft AGL.
4. Above 3,000 ft AGL (clear of obstacles), lower the nose, accelerate, and retract
   flaps on schedule — 5° then UP — respecting Vfe 250/210.
5. Climb at **250 KIAS** below 10,000 ft, then normal climb speed / Mach.
6. Single engine: retract flaps at **V2+15 minimum**, accelerate to **VENR 190 KIAS**.

**Descent and approach**

1. Below 10,000 ft: 250 KIAS, seatbelt sign on, landing briefing done.
2. Approaching the terminal area: below 210 KIAS, **flaps 15**.
3. One dot before glideslope (ILS) or abeam the touchdown point (visual): **gear down**
   below 210 KIAS.
4. At the final descent point / final approach fix: below 180 KIAS, **full flaps**,
   set the descent rate, power to hold **Vref to Vref + 10**.
5. Stabilised by the FAF (instrument) or by the base turn (visual): on speed, on path,
   configured, checklist done. If not, go around.
6. Autopilot **off** by its minimum use height — 170 ft Cat I, 400 ft non-precision,
   80 ft Cat II. It must be off for landing.
7. Typical approach power is **60–65% N1**.

**Landing and rollout**

1. Flare; do not hold it off — the Citation X is happy to touchdown firmly.
2. Touchdown main wheels first, then **forward elevator** to lower the nose.
3. Speedbrakes out, brakes after nose-wheel contact, reversers after nose-wheel contact.
4. In a crosswind, keep aileron into the wind through the rollout.

### 3.5 Energy and the 3° path

A 3° glideslope is **5.31 ft/NM per knot of ground speed**, so the sink rate you need is:

| Ground speed | 100 | 120 | 140 | 160 | 180 |
| --- | --- | --- | --- | --- | --- |
| Sink for 3° | 531 | 637 | 743 | 850 | 956 fpm |

If you are fast, you need more sink or more drag; if you are slow, less. On an ILS the
glideslope needle is the truth — the table is for the visual and RNAV lessons, where
there is no vertical guidance.

### 3.6 Single engine and emergencies

**Engine failure after takeoff.** Hold V2, wings level (ball centred — bank into the
dead engine only after you have speed and altitude), gear up, flaps up at V2+15, climb
at VENR 190 KIAS, work the QRH. Do not turn back to the runway below 1,000 ft AGL.

**Single-engine approach and landing.** Flaps **15° maximum**, Vref(flaps 15) +10
minimum until landing is assured, then Vref(flaps 15). Gear down, speedbrakes retracted,
autopilot off. Avoid tailwind and downhill runways.

**Emergency descent (decompression).** Masks on, autopilot off, thrust idle,
speedbrakes full out, turn 15° to keep the descent path clear, descend at 4,000+ fpm,
level at 10,000 ft or the lowest safe altitude, then work the QRH. Do not exceed Vmo/Mmo
— 270 KIAS below 8,000 ft, 350 KIAS to 30,650 ft, 0.92 M above.

**Rejected takeoff.** Decide once, act once, below V1: throttles idle, maximum braking,
speedbrakes out, maintain centreline, stop. Above V1 you go flying — the aeroplane will
not stop in the remaining runway.

---

## 4. The twelve lessons

Each lesson lists what the panel actually grades. "Pass" means 70%; "signed off" means
100% twice.

### DEPARTURE

#### 1. Normal takeoff & cleanup — `tkof_clean`

**Objective.** A full-length takeoff with the right rotation, the right climb speed and
a clean, on-schedule cleanup.

**Setup.** KLAX 07L, day, no wind, about 24,000 lb. Press START, then release the brakes.

**Graded.** Rotate at VR (pitch > 4.5°, at or above VR−8); positive rate and gear up;
climb at V2+5 to V2+40 between 300 and 1,600 ft AGL; flaps up by 2,500 ft AGL below
250 KIAS; 240–262 KIAS by 3,500 ft AGL.

**Common errors.** Rotating before VR (the jet will fly, but you will be slow and
dragging); leaving the gear down while accelerating; retracting flaps before 3,000 ft;
chasing 250 KIAS while still climbing at V2.

#### 2. Rejected takeoff — `rto`

**Objective.** Recognise, decide and stop — once.

**Setup.** KLAX 25R, clear weather. Press START before starting the roll. V1 is
114–133 KIAS depending on weight; reject at 100 KIAS.

**Graded.** Power to idle at or below 130 KIAS; speed decreasing by 10 kt after the
abort; speedbrakes out; stopped (ground speed < 2) within 40 s of the abort.

**Common errors.** Deciding late; forgetting the boards (they are most of your stopping
force at this weight); letting the nose wander while standing on the brakes; stopping
with the runway behind you because you waited.

#### 3. Engine failure at 400 ft — `engfail_tkof`

**Objective.** Fly the aeroplane first, then run the checklist.

**Setup.** KLAX 07L, 24,000 lb, no wind. Press START, take off normally. The instructor
fails the left engine at 400 ft AGL and opens the QRH flameout checklist.

**Graded.** Hold V2 (not below V2−5) for 2 s; wings level ±5° for 2 s; gear up; flaps up
above 1,000 ft; 180–205 KIAS (VENR 190); QRH procedure complete.

**Common errors.** Relaxing back pressure and letting the speed decay; banking into the
dead engine; retracting flaps too early; flying the aeroplane into the ground while
heads-down in the QRH. Fly, then checklist.

### PATTERN & LANDING

#### 4. Visual pattern & landing — `pattern`

**Objective.** One closed circuit flown to the book.

**Setup.** KLAX 07L, or KSNA 20R for a short one. Start airborne on the downwind at
1,500 ft AGL. Press START on the downwind leg.

**Graded.** Downwind 155–205 KIAS at 1,150–1,850 ft AGL; abeam, flaps ≥15° and gear down;
base at 145–175 KIAS with more than 8° of bank; final below 700 ft AGL with full flaps
and at or below Vref+15; stable at 300 ft (250–340 ft AGL, 480–900 fpm down, wings
within 8°); touchdown under 600 fpm.

**Common errors.** Too fast downwind; gear late; overshooting the base-to-final turn;
arriving at 300 ft still configuring. The stable-at-300 item is the one that matters —
if it is red, go around.

#### 5. Visual approach & landing — `visual`

**Objective.** A straight-in visual from 5 NM with no guidance, flown on speed and path.

**Setup.** KLAX 10 NM final (or join downwind and call a 5 NM final), day, no wind.
Press START.

**Graded.** Configured by 1,000 ft (900–1,100 ft AGL, flaps ≥15°, gear down); full flaps
by 500 ft; Vref to Vref+12 at 500 ft; 500–950 fpm down; wings level within 5° below
220 ft; touchdown under 600 fpm.

**Common errors.** Leaving configuration to 600 ft; arriving fast and high; a path
steeper than 900 fpm; floating in ground effect because the power was left on.

#### 6. Crosswind landing — `crosswind`

**Objective.** The technique this wing actually wants: crab, wings level, rudder to
align.

**Setup.** Custom weather: surface wind 90° to the runway at 10 kt (e.g. 360/10 for 27).
Fly a normal approach, then press START.

**Graded.** Crabbed on final (3° or more between heading and track, 200–900 ft AGL);
wings level (≤5°) in the flare between 5 and 60 ft; aligned within 8° at touchdown;
touchdown under 600 fpm. The panel adds 5 kt to Vref for this lesson, so the target is
already wind-adjusted.

**Why not wing-low.** The Operating Manual is explicit: because of the long span and
swept wing, the aeroplane **should not be flown in a wing-down sideslip**. Crab with
wings level, use rudder in the flare to align, and accept touching down in a slight
crab. Keep aileron into the wind during rollout.

**Common errors.** Kicking off the crab too early and drifting downwind; stalling the
into-wind wing by adding bank; touching down fast because you were afraid of the
crosswind; forgetting the aileron after touchdown.

#### 7. Flaps 15 landing (flap jam) — `noflap`

**Objective.** Land after a flap actuator failure, at the configuration the QRH
prescribes.

**Setup.** 10 NM final at KLAX 25R (long runway). Press START — the flap actuator fails
and the QRH opens together. Set flaps 15 per the checklist.

**Graded.** Flaps 15 maximum; gear down by 1,000 ft; Vref+8 to Vref+27 at 500 ft
(the flaps-15 Vref is roughly full-flap Vref+15 — the AFM flaps-15 table is the
authority); 450–950 fpm down; touchdown under 600 fpm.

**Common errors.** Selecting full flaps against the jam; approaching too fast and
floating; landing on a short runway. This is a long-runway landing — treat it that way.

### INSTRUMENT

#### 8. ILS precision approach — `ils`

**Objective.** A stabilised Cat I ILS to a landing, autopilot off by 170 ft.

**Setup.** KLAX 25L (or 07L) approach start, 10 NM final; the start tunes NAV1. Arm APPR,
then press START.

**Graded.** Localiser within 1 dot and glideslope within 1 dot at 500 ft; gear and full
flaps by 1,000 ft; Vref−3 to Vref+12 at 500 ft; 500–950 fpm at 500 ft; autopilot off
between 60 and 175 ft; touchdown under 600 fpm.

**Common errors.** Chasing the needles with big corrections; configuration late; leaving
the autopilot engaged below 170 ft (a real limitation, not a style choice); arriving
high and diving.

#### 9. RNAV / non-precision approach — `rnav`

**Objective.** Fly a 3° path with no glideslope — the sink rate is your vertical
guidance.

**Setup.** KSAN RNAV 27 (or any LNAV approach) from 10 NM final. Press START once
established inbound.

**Graded.** Lateral within 0.5 dot for 3 s; 3° path within 200 fpm between 300 and
2,500 ft AGL; gear and full flaps by 1,000 ft; Vref to Vref+10 at 500 ft; touchdown
under 600 fpm.

**Common errors.** Chasing the altimeter instead of holding a sink rate; a path that is
too shallow (low and fast); forgetting the step-downs; late configuration.

#### 10. Single-engine ILS — `se_ils`

**Objective.** Fly an ILS with one engine out, at the correct (flaps 15) configuration.

**Setup.** KLAX 25L from 10 NM final. Press START — the left engine fails once you are
inside 3,000 ft AGL.

**Graded.** Localiser and glideslope within 1 dot at 500 ft; at least Vref+10 (flaps-15
Vref +10 is the book figure; the panel grades the floor); gear down and flaps 15° (not
full) by 1,000 ft; wings level ±5° at 300 ft; touchdown under 600 fpm.

**Common errors.** Selecting full flaps — the QRH says flaps 15° maximum; letting the
speed decay below Vref+10; banking into the dead engine; forgetting that the missed
approach is still available and cheaper than an unstable landing.

#### 11. Go-around / missed approach — `goaround`

**Objective.** Break off at 300 ft and fly a clean missed approach.

**Setup.** Any ILS or visual, 3 NM final, configured. Press START at about 500 ft and
keep coming; go around at 300 ft — do not land.

**Graded.** Power to TO/MCT (N1 ≥ 80); rotate to +7.5° (pitch ≥ 6.5°); positive rate
(> 300 fpm); gear up; flaps 15° or less; level at 2,700–3,400 ft.

**Common errors.** Hesitating (the aeroplane is already descending — act now); not
pitching enough; leaving the gear down; climbing at Vref instead of Vapp; forgetting
flaps 15 before accelerating.

### EMERGENCY

#### 12. Emergency descent — `decompression`

**Objective.** Get the cabin to 10,000 ft before the passengers run out of oxygen.

**Setup.** Start in cruise at FL350 (or climb there), then press START. The QRH cabin
decompression checklist opens once you are above 20,000 ft.

**Graded.** Autopilot off; thrust idle; speedbrakes out; 4,000+ fpm down for 1.5 s;
level at 9,500–10,500 ft; QRH procedure complete.

**Common errors.** Leaving the autopilot on; adding power instead of reducing it;
forgetting the boards; levelling at the first convenient altitude instead of 10,000 ft;
not turning 15° to clear the descent path (brief item, not graded — do it anyway).

---

## 5. Where to practise in SoCal

| Airport | Runway | Why | Watch out for |
| --- | --- | --- | --- |
| KLAX | 07L/25R (12,923 ft) | long runway, ILS 25L/07L, ILS 25R | Class B; the north complex is busy |
| KSAN | 27 (9,401 ft) | single runway, offset ILS, terrain | short-ish, displaced threshold, hill west of 27 |
| KSNA | 20R (5,700 ft) | short-field training, tight pattern | noise-sensitive, Class C |
| KVNY | 16R (8,001 ft) | cheap pattern work, VOR/RNAV | under LAX Class B shelf |
| KBUR | 15 (5,801 ft) | short-field, terrain, visual circling | high terrain both sides |
| KSMO | 21 (4,973 ft) | shortest local runway, good go-around practice | short, noise-sensitive |

For the first attempt at any lesson use KLAX or KSAN: long runways, ILS everywhere, and
no terrain to hit while you are heads-down. Move to KSNA/KBUR/KSMO once you are scoring
85%+ — they punish unstable approaches.

---

## 6. A ten-flight study plan

| Flight | Lessons | Focus | Target |
| --- | --- | --- | --- |
| 1 | 1, 2 | rotation, cleanup, reject decision | 70% on both |
| 2 | 1, 3 | engine failure on departure | 85% on 1, 70% on 3 |
| 3 | 4, 5 | pattern, stable approach, touchdown | 85% on both |
| 4 | 6, 7 | crosswind and flap failure | 70% on both |
| 5 | 8 | ILS to a landing, autopilot off | 85% |
| 6 | 9, 10 | RNAV path and single-engine ILS | 70% on both |
| 7 | 11, 12 | go-around, emergency descent | 85% on both |
| 8 | weakest three | repeat at higher wind/turbulence | 85%+ |
| 9 | all twelve | one pass, no retries | 85% average |
| 10 | all twelve | different weights and airports | 100% twice on each |

Rules of thumb:

* One lesson per approach. Do not chain them in a single flight until flight 9.
* Debrief before you retry. Read the MISS lines; they are the lesson.
* Change one variable at a time: wind, weight, airport — never all three at once.
* If you score 0% because the lesson never armed, you were in the wrong place; read the
  `ARMED - ...` line.

---

## 7. Reference documents

All in the aircraft folder (`Aircraft/Cessna Citation X_mods/`):

| Document | Use |
| --- | --- |
| `X-Plane_Citation_X_Pilot_Operating_Manual.pdf` | the sim's POM: systems, panel layouts, procedures |
| `Citation_X_Pilot_Operating_Manual.pdf` | the full Model 750 Operating Manual: normal/abnormal/emergency procedures and the performance section |
| `Citation_X_FMS_Manual.pdf` | FMS, V-speeds, flight plan entry |
| `clist.txt` / `Citation_X_clist.txt` | the community checklist (flows) |

The AFM Section II limitations are reproduced in the Operating Manual. The community
checklist in the aircraft folder has a couple of transcription errors in the Vfe table
(it lists 251/185 KIAS); use the AFM numbers in §3.2.

**Sim versus reality.** This is a training aid for a desktop simulator. It teaches the
numbers and the sequence, but it cannot teach feel, and the X-Plane flight model is not
a Level D simulator. Nothing here is a substitute for an approved type course or for the
aircraft's AFM.
