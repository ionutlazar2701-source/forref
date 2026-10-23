# FORREF Watch Reference App contract

Package: `research/watch_reference_ui`

Allowed dependencies: Flutter and `simulator_presentation`.

The app reads `WatchPresentationState` and emits `WatchIntent`. It does not import `hf_v2`, Match Memory, SQLite, Firebase, legacy `match_core`, or the production phone app.

It is a reference implementation for Simulator Lab. It is not a production watch binary.

## Surfaces

| Route | What it shows |
| --- | --- |
| Live core | Phase, clock, score, match identity, Capture, Awareness, History |
| Capture menu | Yellow, Sending-off, Substitution. Goal is stated as not offered by this research runtime |
| Yellow | Team participants and officials as id plus shirt label, prior-caution awareness, explicit Record yellow |
| Send-off | Record direct and Record second-caution are separate buttons |
| Substitution | OUT and IN stay separate, then an explicit Record substitution |
| Awareness | Known none, standing, unavailable, or conflicted, plus successor state |
| History | Caution count, send-off count, substitution stage |

Clock and score stay unavailable when the research snapshot has no clock or score. The app does not invent 0-0 or 00:00.

Shirt text is a label. The intent carries the participant id.

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
