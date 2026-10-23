# S2.6UI — John fidelity design integration

Research SimLab visual pass. Sporting semantics, Match Core, and persistence are unchanged. This is not a native watch implementation.

## Design source

Founder folder: https://drive.google.com/drive/folders/1JPbpu38yDpX77m8uvugaMc8VARIRSh7I

Originals are stored unmodified at `research/hf_prototype/assets/john_design/source/`.

| File | Pixels | Role |
| --- | --- | --- |
| `bc28380e-4b88-4839-b472-3cf5c76a84b4.png` | 1672×941 | Master desktop composition, hierarchy, color, panels |
| `babf46ad-e67a-4b50-b735-5fbfb39b2d15.png` | 1254×1254 | SimLab application icon only |
| `ee2ec25a-0ada-4fb0-8fd4-6a8c4ad0b756.png` | 1024×1536 | Rectangular frame A (taller case, crown on the right) |
| `53c9c4d8-23fe-4321-9239-c7441b29ca55.png` | 1024×1536 | Rectangular frame B (squarer case) |
| `c89addd2-9479-444c-837c-dabc2deeb9ea.png` | 1024×1536 | Round metal case |

Sampled from the master, not from the brief’s approximate hex: navy `#0B2743`, cyan `#26C0CA`, canvas `#F3F7FA`, line `#D1DBE2`. Tokens live on `LabColors` in `research/hf_prototype/lib/src/lab_theme.dart`.

## Derived watch shells

`research/hf_prototype/assets/john_design/derived/` holds the same three watch files as RGBA overlays.

Process, applied once to copies of the sources:

1. Flood light background from the corners where the channel max is above 205. Those pixels become alpha 0.
2. Punch the glass aperture to alpha 0 so reflections do not cover the live UI. The punch is an inset of the glass, not a repaint.
3. Bezel, crown, buttons, and strap stay in the source pixels.

Normalized apertures used by `PhotographicWatchFrame` (`john_frames.dart`), as fractions of the 1024×1536 image:

| Frame | Left | Top | Width | Height | Clip |
| --- | --- | --- | --- | --- | --- |
| A `ee2ec25a` | 161/1024 | 341/1536 | (855−161)/1024 | (1122−341)/1536 | rounded rect, radius factor 0.12 |
| B `53c9c4d8` | 153/1024 | 330/1536 | (863−153)/1024 | (1105−330)/1536 | rounded rect, radius factor 0.16 |
| Round `c89addd2` | 138/1024 | 355/1536 | (872−138)/1024 | (1072−355)/1536 | circle |

The overlay is `IgnorePointer`. Taps hit the live child. The frame is scaled so the case fills the card width and the aperture stays large. Strap pixels may clip. The shell is not a measured safe area.

## Profile mapping

`johnFrameForProfile` reads display shape, then case shape. It does not read file names.

| Shape fact | Frame |
| --- | --- |
| `round` (Huawei Watch GT 4 46 mm) | Round source |
| `roundedRectangle` and case height > width × 1.05 (Apple Watch Series 9 45 mm, 38×45 mm) | Frame A |
| Other `roundedRectangle` (Amazfit GTS 4) | Frame B |
| Unknown shape (Garmin Approach S60) | Schematic shell only. No supplied frame is claimed |

`Show device frame` toggles the photographic shell. Off shows the existing schematic viewport.

At 1672×941 the Huawei GT 4 round aperture fits `WatchReferenceApp`. The capture does not show `LAYOUT NOT FIT FOR THIS PROFILE`. The 120×180 fail-closed check is unchanged.

## Desktop system

Wide and desktop widths (≥1100) use one row:

Scenario controls · Mobile session · simulated pair · Watch session · Device & view controls

Below that: the research outcome line, then Command Lab chips and the Event Journal. Compact and narrow widths stack those regions and scroll.

Navigation:

| Previous | John label |
| --- | --- |
| Focus | Simulation |
| Inspector | Inspection |
| Command Lab | Command Lab |
| Compare | Device Compare |

Match Builder is a secondary control on the bar and again under Scenario controls. It is not a primary tab. Inspection opens the existing inspector.

`Apply scenario` and `Reset session` reload the current fixture. They do not kick off. There is no simulation-speed model, so the reference speed radios are not drawn. Screenshot and Export are not drawn, because those actions do not exist.

The pair column says `SIMULATED · NOT PRODUCTION SYNC`. The Event Journal is the research log. It is not the Match Report.

## Phone and watch surfaces

The phone is a drawn dark bezel with a live Flutter screen. There is no separate phone photograph in the source set, and the master screenshot’s phone already contains a static UI, so that screen was not rasterized into the bezel.

Before kick-off the phone shows `MATCH READY`, `Not started`, the score, and `KICK-OFF`. After kick-off it shows the phase, the running clock, and the score. Action cards are Capture event, Goal, Caution, Send off, Substitution, and Reports. Flows for goal, yellow, send-off, and substitution stay on the same surface. Recent events are the Match Report lines. The journal is separate.

The watch face is `WatchReferenceApp` clipped to the photographic aperture: phase, clock, score, and the existing actions, including Kick-off before the half starts.

## Icon

`babf46ad-e67a-4b50-b735-5fbfb39b2d15.png` is the SimLab icon. `research/hf_prototype/windows/runner/resources/app_icon.ico` was generated from that file at 16, 24, 32, 48, 64, 128, and 256. Colors and geometry were not redrawn. Production icons under `apps/` were not touched.

`SOURCE ART MODIFIED: NO` except that size/export conversion.

## Behaviour preserved

Match Ready, Kick-off, the continuous first-half clock, Goal, Yellow, direct send-off, second-caution send-off (no automatic send-off), substitution, score projection, frozen event times, and the Match Report. Failure and unknown outcomes stay unresolved until an explicit resolve. Paired research truth is unchanged.

## Visual QA

Linux widget captures at 1672×941, plus layout checks at 1600×900 and 1920×1080. These are not Windows evidence.

| | |
| --- | --- |
| P0 | none |
| P1 | none after the phone action labels were given the loaded Roboto face |
| P2 | none left open |
| P3 | no speed radios; no Screenshot/Export; `Apply scenario` does not start the match; phone bezel is drawn rather than cropped from the master; watch actions remain the real reference routes; journal title is `RESEARCH LOG` unless the sandbox runtime is selected; scenario names are fixture ids |

Huawei GT 4 46 mm at the reference viewport fits the round frame. Garmin stays schematic.

## Windows Founder gate

Required. This cloud run is Linux and does not execute `flutter build windows`. A green Linux suite is not Windows visual or functional proof.

## Production

`packages/` and `apps/` are not part of this wave.
