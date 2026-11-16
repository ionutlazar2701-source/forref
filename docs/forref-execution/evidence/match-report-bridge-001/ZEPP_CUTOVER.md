# Zepp cutover boundary

The watch flow today is:

1. `page/gt/event/index.page.js` writes `state().event` to `YELLOW`, `RED`, `GOAL`, or `SUB` and pushes Player. The header is the not-recorded label.
2. `page/gt/player/index.page.js` writes `state().player` (`PLAYER 9`, `PLAYER 4`, or `UNKNOWN`) and pushes Review.
3. `page/gt/review/index.page.js` shows the selection and `DEMO — RECORDING NOT AVAILABLE`.
4. The prototype clock in `utils/clock_device.js` uses `LocalStorage` key `forref_clock001c_state`. That file is display continuity for the prototype. It is not Match Memory and it is not a match minute for a report line.

## One writer

During cutover exactly one component may append Match Records for a match: the phone `SqliteDurableMatchStore` behind `MatchApplicationBoundary`. The watch must not also append, and the legacy Drift `MatchSession` must not receive a copy of the same capture.

A future watch command is a capture intent, not a report row:

- match id
- capture intent id
- semantic kind already implemented: goal, yellow, direct send-off, second-caution send-off, substitution, or a temporal transition the phone boundary already commits
- the subject, team, and pathway fields those payloads already require

The phone boundary commits that command, returns `DurableCommitSuccess` only after D1, and the report is `readMatchReport` rebuilt from the committed rows. A transport accept, a Bluetooth send, or a LocalStorage write is not that success.

The JavaScript app does not import `package:forref_match_core`. Sharing the projection means sharing committed record bytes and running the same Dart projection on the phone, or a later native port of that projection. It does not mean calling Dart from the Zepp page.

`RED` on the watch grid is not a send-off record. A send-off still requires an explicit direct or second-caution command. `UNKNOWN` player stays an unknown subject until a real participant id is admitted. The report must not invent one.

## Not this change

No Zepp page writes Match Memory in this branch. No color, GPS, or heart-rate work.
