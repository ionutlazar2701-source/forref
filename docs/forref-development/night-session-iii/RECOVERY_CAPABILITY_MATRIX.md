# Recovery capability matrix

Status of this file: RECORD

This map describes the repository as exercised in Night Session III. It does not add a production draft store. A simulated research label is not a production guarantee.

Authority order used while reading the results:

1. Authoritative Match Memory in the SQLite file.
2. A returned durable commit result.
3. A non-authoritative research draft, which this repository does not store.
4. Volatile widget state.

Probe: `packages/forref_match_persistence/test/research/session_iii_recovery_probe_test.dart`

Phone lifecycle search: `apps/referee_phone/lib` has no `WidgetsBindingObserver` and no draft table. That search is not a device test.

| Class | Current implementation | Test method | Result | Class | May be promised | Must not be promised | Future proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. Navigation away from an unfinished action | Phone session and the research instrument keep unfinished selection in memory. No draft table. | Research rebuild test. Code search. | A widget rebuild keeps the in-memory research signature. Leaving the process drops it. | NOT SUPPORTED for a durable unfinished draft | The uncommitted action is not saved. | The unfinished yellow, send-off, or substitution will be waiting after the screen is left and the process ends. | A draft checkpoint with an explicit non-authority label, if Product Command asks for one. |
| 2. Screen lock / lifecycle pause | No lifecycle observer in the phone library. | Code search only. | No runtime evidence. | NOT PROVEN | Nothing about pause. | Locking the phone restores or saves an unfinished action. | Instrumented lifecycle test on a device. |
| 3. App backgrounding | Same as pause. | Code search only. | No runtime evidence. | NOT PROVEN | Nothing about backgrounding. | Backgrounding preserves an unfinished action. | Device lifecycle trace. |
| 4. Process recreation | Committed rows live in the SQLite file. Unfinished research state does not. | Not run as process death. | UI recreation is unmeasured. | NOT PROVEN for the interface. File reopen is covered by class 5. | Nothing about a recreated phone process. | The unfinished screen comes back as it was. | Kill and relaunch on a device, then read the same file. |
| 5. App restart of the store file | `SqliteDurableMatchStore.open` on the same file. | Probe closes the store and opens the same file. | The committed yellow is present. Send-off payloads in that file: none. | SUPPORTED for committed rows in that file. NOT SUPPORTED for uncommitted selection. | A row that was committed can be read again from the same file. | Restart restores an action that never committed. | Phone-level restart with the app's real database path. |
| 6. OS termination | No OS kill was performed. | None. | No evidence. | NOT PROVEN | Nothing. | The operating system killing the app is covered by the file probe. | Device termination test. |
| 7. Phone restart | No phone restart was performed. | None. | No evidence. | NOT PROVEN | Nothing. | Rebooting the phone preserves unfinished work or was tested. | Device reboot with the real database. |
| 8. App crash | The probe throws inside the test abort hook. That is a caught failure, not a killed process. | `abortBeforeCommitForTest` | The API returns `DurableCommitFailure`. The row is absent. The admission count is 0. | SUPPORTED for this caught failure. NOT PROVEN for a hard crash. | A returned failure means that attempt did not commit. | A crash without a returned result is the same as this caught failure. | Kill the process during `BEGIN IMMEDIATE` and reopen the file. |
| 9. D1 outcome uncertain | Success and failure are distinct return values. A read of an id that was never submitted is null and is not a failure object. | Probe plus the research instrument's `saveNotVerified` label. | The store does not collapse "no row" into `DurableCommitFailure`. The phone UI does not show Save not verified. | SUPPORTED for the return values when a call finishes. NOT PROVEN for a caller that died before reading the result. | Do not tell the referee an event failed only because a read missed it. | The production phone already shows Save not verified after an uncertain commit. | Persist the in-flight intent before the commit call, then resolve it on the next open. |
| 10. Same capture-intent reconciliation | Existing admission. The probe does not change it. | Retry the same intent with a new record id. | Success returns the original record id. One yellow remains. No send-off appears. | SUPPORTED | The same intent is not a second yellow. | A new intent is a safe way to "check" an uncertain save. | Keep this behavior when a phone retry exists. |
| 11. Yellow durable, SEND_OFF absent | A full read of the test file. | `readCommittedForMatch` after the yellow commit. | The yellow is present. `SendOffPayload` count is 0. | SUPPORTED for a complete read of that file. NOT PROVEN for a partial or untrusted read. | On a complete read of this file, no sending-off row was stored. | A partial read, a failed open, or an unavailable awareness result means the sending-off did not happen. | Phone projection must keep using the completeness proof before it says none. |
| 12. Substitution draft, one player named | No draft row. Research `outId` is memory. | Research interrupt test. No store column was added. | OUT remains OUT in memory. A new process would not have it. | NOT SUPPORTED | Nothing durable. | Finish later restores the named player. | Only if a future draft contract is authorized. |
| 13. Substitution pair complete, not committed | Same. Roles are memory fields. | Research reorder and interrupt test. | OUT and IN do not swap in memory. They are not in SQLite. | NOT SUPPORTED as storage. NOT PROVEN across process death. | Nothing durable. | The pair is safe on disk before the final action. | Same as class 12. |
| 14. Stale local draft versus Match Memory | There is no draft record to be stale. | Code search. Probe reads only committed rows. | Match Memory is the committed file. RAM is not a second memory. | NOT SUPPORTED for draft reconciliation, because there is no draft. | Committed rows outrank the research screen. | A research selection corrects or overrides a committed row. | Not required until a draft exists. |

## Finish later

FINISH LATER PRODUCTION GUARANTEE: NO

The research scenario `s17FinishLaterSimulatedRestart` shows `SIMULATED RECOVERY BEHAVIOR`. That sentence is the whole promise.

## Save not verified

Known failure: the store returned `DurableCommitFailure`.

Unknown: the caller does not have a result. Absence on an incomplete read is not that failure.

The research instrument can show `SAVE NOT VERIFIED — outcome is not known` and refuses `submitWhileUnverified`. The production phone does not show that state. Do not describe the research label as recovery that already ships.
