# Research prototype spec

Status of this file: RECORD

The prototype is a study instrument. It is not the referee phone.

## Where it lives

- Instrument: `research/hf_v2`
- Shell: `research/hf_prototype`

Neither package is a member of the root pub workspace. Neither imports `forref_match_core` or `forref_match_persistence`. The phone router does not import `hf_prototype`.

Run it from `research/hf_prototype` with Flutter. Do not run `apps/referee_phone` and call that this instrument.

The first screen reads `FORREF RESEARCH PROTOTYPE`.

## What the referee surface can do

Live, yellow, red card, substitution, players, team officials, and commitment are chips on the research shell. Home and Away set team context. They do not infer a team from the last event or from which side of the screen was touched.

Record yellow and Record sending-off are separate rectangles. The research layout is not a production pixel law.

Operator, scenario list, interruption, and the research log are on a different panel. Opening it removes the capture column.

## What a simulated save means

`SIMULATED SAVED — not production D1`

`NOT SAVED — known simulated failure`

`SAVE NOT VERIFIED — outcome is not known`

`SIMULATED RECOVERY BEHAVIOR` when the scenario is a simulated restart.

The shell never calls a durable commit port.

## State

The instrument keeps pitch text, simulated digital records, unfinished selection, and the commit label in separate fields. Widget rebuild reads those fields. It does not create a record.

Two saved cautions do not create a sending-off. A sending-off starts only from a later pointer or an explicit accessibility invoke after the yellow gesture has finished, and only inside the sending-off rectangle.

Changing team clears a subject from the other team. Home 14 and Away 14 are different ids.

Match and shoot-out cautions are stored apart.

OUT alone, IN alone, and a named pair do not become a substitution until Record substitution succeeds.

## In-flight command

When a final action is activated, the instrument freezes the subject, the subject kind, the scope, and the OUT/IN pair. A later team change, a later subject tap, a scope change, or a new IN selection stays on the unfinished layer. The simulated result writes only the frozen command.

`SIMULATED SAVED` is reported only when that write appends a record. A scripted success that cannot append a record stays `SAVE NOT VERIFIED` and stores nothing. A scripted failure stays `NOT SAVED` and stores nothing. An unknown script stays `SAVE NOT VERIFIED` and stores nothing.
