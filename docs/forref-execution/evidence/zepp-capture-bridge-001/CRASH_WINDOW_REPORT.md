# ZC21 crash-window report

Baseline at the start of this work: `f805997a596e766731a5f0d3a20186712c749199` on `cursor/zepp-autonomous-capture-001-30fd`. That commit is the previous PR #48 head. This report covers the controller added after it.

The Drive task text was read in full. The raw file bytes were not re-hashed in this session, so this report does not claim a match to `33db2af0ba1580efff6a1bb3765abb663dfb49c22e59fbe6581a2649200873ea`.

The crash window is the gap between a journal append and the volatile `state().captureIntentId`. After a restart that id is empty. The old review path then called append with an empty id and allocated another sequence. `decideCaptureTap` now refuses that tap when a readable line already has the same canonical payload. `NEW CAPTURE` is the only path that allocates another id for that payload. Binding a row in `VIEW LOCAL` stores the existing id and does not append.

Schema stays `1`. No historical line is rewritten. The phone Match Memory writer is unchanged. The clock files and the 23 routes are unchanged. Nothing here is `Saved`, an official score, a certified minute, an authoritative Match Record, or D1.

## Matrix

| Row | Result | Evidence |
| --- | --- | --- |
| ZC21-01 | PASS | Work started at `f805997`. Edits stay in the watch review decision, its strings, and the journal tests. |
| ZC21-02 | PASS | `a lost intent id after a verified append duplicates until reconcile refuses` shows the empty-id append becoming sequence `2`, then the controller refusing the same bytes. |
| ZC21-03 | PASS | `bindRecoveredCandidate` returns the recovered id. Both guests logged `reconcile=bind seq=1 id=CB1-UNPROVISIONED_DEVICE-0001`. |
| ZC21-04 | PASS | Bind and `VIEW LOCAL` do not append. After the refuse, the next successful retry was still sequence `1`. |
| ZC21-05 | PASS | Bound retry is `IDEMPOTENT duplicate=1` in the node test and on both guests. |
| ZC21-06 | PASS | `NEW CAPTURE` allocated `CB1-UNPROVISIONED_DEVICE-0004` on both guests. The node test keeps two yellow lines and no send-off kind. |
| ZC21-07 | PASS | A supplied yellow id replayed as a goal is `CONFLICT` and the file is unchanged. A different shirt with an empty id is `RECONCILE_REQUIRED`, because the yellow payload has `participantId: null`. The review screen clears the open id when team, event, player, or fixture changes. |
| ZC21-08 | PASS | A corrupt prefix makes `decideCaptureTap` return `REFUSE`. Append does not change those bytes. |
| ZC21-09 | PASS | Throw before any byte stays `WRITE_EXCEPTION`. A read thrown after the entry bytes are written returns `READBACK_MISMATCH` with `ok: false` and keeps the attempted id. A later empty-id decision refuses. Replaying that id is idempotent. |
| ZC21-10 | PARTIAL | Active Max `480×480` round, source `10813699`, showed refuse, bind, idempotent retry, and sequence `4`. The exact post-append process kill is BLOCKED. |
| ZC21-11 | PARTIAL | Bip 6 `390×450` rectangular, source `10158337`, showed the same four outcomes, including `duplicate=0` on the refuse. The exact post-append process kill is BLOCKED. |
| ZC21-12 | PASS | `npm test` in `apps/forref_watch_zepp`: geometry pass, then 44 node tests, 0 failed. `./tool/verify_cloud.sh`: exit 0, Match Core 377, persistence 92, phone 126. |

## Guest crash-window injection

BLOCKED. `append` and the assignment of `captureIntentId` are consecutive statements in one QuickJS turn. The QEMU guest has no instruction breakpoint on that boundary, and the production path was not given a delay or a crash hook. Closing and reopening the guest on the same norflash proves recovery of the existing lines. It does not prove a kill between the append and the UI acknowledgement, and it does not prove physical power-loss durability.

## What remains uncertified

- Hardware D1 and power loss.
- Match Memory authority on the watch. The phone store remains the only writer.
- Official score, certified match minutes, and a match report on the watch.
- A guest process interrupted inside the post-append / pre-acknowledgement window.
