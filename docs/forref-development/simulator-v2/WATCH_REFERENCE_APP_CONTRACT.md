# FORREF Watch Reference App contract

Package: `research/watch_reference_ui`

Allowed dependencies: Flutter and `simulator_presentation`.

The app reads `WatchPresentationState` and emits `WatchIntent`. It does not import `hf_v2`, Match Memory, SQLite, Firebase, legacy `match_core`, or the production phone app.

It is a reference implementation for Simulator Lab. It is not a production watch binary.

## Surfaces

| Route | What it shows |
| --- | --- |
| Live core | Approved layout A (centered score) or C (score beside the clock). Phase, trusted or unavailable clock, verified or unavailable score, Capture, cautions list. Layout and shape are presentation only. |
| Capture menu | Yellow, Red, Goal, and Sub. Round places them top, right, bottom, left. Rectangle places yellow/sub on the top row and goal/red on the bottom row. A family tap starts a presentation journey. It does not activate a record. |
| Team step | Home left, away right, after a family tap, or from the lab team frame. Round color edge or rectangular team chips. Kit color is painted only when both colors are supplied and they differ. Selection emits set-team and does not activate. Substitution then opens the existing substitution route, where OUT and IN stay separate. |
| Participant step | After team, except substitution. Number grid on round, grid pager on rectangle. Officials use two columns. A single leftover chip is centered. One horizontal swipe reaches team officials. Extra player pages are labeled when the roster does not fit. Yellow then offers yellow. Red opens the existing send-off route. Goal offers goal and then reapplies the team and participant, because the research offer clears them. None of these taps activate a record. |
| Yellow | Team participants and officials as id plus shirt label, prior-caution awareness, explicit Record yellow |
| Send-off | Record direct and Record second-caution are separate buttons |
| Substitution | OUT and IN stay separate, then an explicit Record substitution |
| Awareness | Known none, standing, unavailable, or conflicted, plus successor state |
| History | Caution count, send-off count, substitution stage |

Clock and score stay unavailable when the research snapshot has no clock or score. The app does not invent 0-0 or 00:00. A counted research score, including a known 0–0, stays visible because `available` is true.

Yellow, send-off, goal, substitution, awareness, history, and match report keep the existing research controls. Full-screen boards for those steps were not in the approved source package.

Layout A/C, face shape, the team frame, and the participant frame do not append a Match Record. `BEYOND 90:00` is shown only when the lab asks for that caption and the clock is available. The clock numeral stays the presentation label.

Shirt text is a label. The intent carries the participant id.

`canOpenCapture` is the research projection `freshInputEligible || inFlight != null`. After a simulated save the commit is no longer idle, so the flag is false while the research instrument still accepts the next offer. The flag is therefore not a menu lock and not an inspect-only mode. The Capture ring stays a navigation control. It does not say "Capture unavailable", and it does not activate a record. Record authority stays on the later explicit Record actions. A separate disable flag would be a contract change.

Capture, cautions, back, family, and participant targets keep a logical-pixel floor inside the simulated aperture. If that floor does not fit, the surface shows `LAYOUT HOLD` instead of shrinking those targets. The floor is not a millimetre and not a device safe area. Decorative bars beside the capture ring are not controls. The capture center dot is not a control.

The capture ring draws an implementation whistle glyph. Each family draws an implementation hexagon glyph. Those glyphs are reconstructed from the approved boards. They are not frozen source SVG files and they do not mean Saved.

## Research commit labels

| State | Label |
| --- | --- |
| Idle | Idle |
| Simulated save in progress | Saving — simulated |
| Scripted success | SIMULATED SAVED — not production D1 |
| Known simulated failure | NOT SAVED — known simulated failure |
| Unknown outcome | SAVE NOT VERIFIED — outcome is not known |

Those phrases are not production D1.

## Final action

Record yellow offers the yellow action and then invokes it, because selecting a participant clears a previous offer. That sequence still goes through the research instrument. It does not append the caution list from the widget.

Second-caution send-off is only an invoke. It does not create a successor and it does not record a send-off before one exists.

A pointer that slides off a button does not commit. A pointer that is still down when `inputEpoch` changes does not commit.
