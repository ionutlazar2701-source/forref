# Presentation runtime contract

Package: `research/simulator_presentation`

Pure Dart. No Flutter, no Match Memory, no SQLite, no Firebase, no `hf_v2`.

## Runtime

`SimulatorPresentationRuntime` exposes:

- `watchState`
- `watchStates`
- `intentTrace`
- `dispatch(WatchIntent)`

`InMemoryPresentationRuntime` records navigation and team selection. Activate does not invent a save and does not create disciplinary lists.

## State

`WatchPresentationState` is disposable. It carries header, clock, score, selection, discipline, substitution, frozen command, commit, navigation, roster, and officials.

Clock and score are unavailable unless a runtime has those facts. Unavailable is not 0-0 and not 00:00.

Shirt label is display text. Participant id is identity. Home 14 and Away 14 stay different ids.

Prior awareness keeps known none, known standing, unavailable, and conflicted distinct.

## Intents

`IntentOrigin.watchUi` traces as `ACTUAL WATCH UI INTERACTION`.

`IntentOrigin.operatorFixture` traces as `OPERATOR FIXTURE ACTION`.

## Research adapter

Package: `research/simulator_hf_bridge`

`projectResearchSnapshot` copies the instrument snapshot. It does not append records.

`HfPresentationRuntime.dispatch` calls accepted instrument methods: team, subject, scope, offer, select out, select in, `accessibilityInvoke`, `resolveSimulatedCommit`, acknowledge, focus loss, device-change cancel, profile note, and scenario load.

Commit text is copied from the instrument:

- `Idle`
- `Saving — simulated`
- `SIMULATED SAVED — not production D1`
- `NOT SAVED — known simulated failure`
- `SAVE NOT VERIFIED — outcome is not known`

`bindProfile` stores the profile id and the v2 viewport context. It does not append a research record. Unknown safe area stays unknown.

The instrument remains the only research writer of cautions, send-offs, and substitutions.
