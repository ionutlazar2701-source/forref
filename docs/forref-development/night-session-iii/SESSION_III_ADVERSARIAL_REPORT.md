# Night Session III adversarial report

Status of this file: RECORD

Reviewer: Grok `bc-2032ba8f-2da1-57fc-b9c1-e20342f6ee06`

Production code edits by the reviewer: NONE

The reviewer added test-only attacks in `research/hf_v2/test/adversarial/session_iii_saboteur_attack_test.dart` and did not edit `lib/` to make a test pass.

## First review

HOLD on BANK I, BRIDGE 2, and CROSS-BANK.

`resolveSimulatedCommit` read the live subject, scope, and substitution pair. It also reported Saved when the write was skipped.

The other banks and bridges were PASS on that pass. Tests then: 11 passed, 1 failed.

## Repair

`b8bf57d45d6812f9659d1945c64e0e53d7b41bc4` freezes subject, subject kind, scope, and the OUT/IN pair at activation. The simulated write uses only that snapshot. Saved is reported only when a record is appended. A snapshot that cannot produce a record stays Save not verified and stores nothing.

## Second review

The same reviewer re-read the repair and re-ran `dart test` in `research/hf_v2`. Result: 48 passed, 0 failed.

| Surface | Result |
| --- | --- |
| BANK H | PASS |
| BANK I | PASS |
| BANK J | PASS |
| BANK K | PASS |
| BANK L | PASS |
| BANK M | PASS |
| BRIDGE 1 | PASS |
| BRIDGE 2 | PASS |
| BRIDGE 3 | PASS |
| BRIDGE 4 | PASS |
| BRIDGE 5 | PASS |
| CROSS-BANK | PASS |

P0 found on the second review: NONE

New attacks on the second review: the reviewer re-checked yellow, direct send-off, second-caution send-off, an official caution, and substitution. Subject, scope, pathway, and pair edits during saving do not retarget the record. A valid snapshot still appends and reports Saved. A scripted failure writes nothing and stays Not saved. An unknown script writes nothing and stays Save not verified. No extra test file was kept.

## Attack groups

| Group | What was attacked | Result |
| --- | --- | --- |
| A Isolation | Production Match Memory, D1, and the phone writer from a research action | Impossible from this package. No production import. Phone lib does not import the prototype. |
| B Y2 authority | Double tap, old position, carried pointer, delayed release, focus loss, rebuild, second pointer | Yellow may save. Sending-off stays absent until a fresh activation inside the sending-off region. |
| C Identity | Home 14 then Away, same shirt number, participant versus official, similar official names | Home 14 is invalidated. Shirt 14 on each team is a different id. Officials are not aliased to players. Similar names stay unselected until an explicit choice. |
| D Prior caution | Unavailable, conflicted, before Y2, after Y2 saved | Unavailable and conflicted are not verified absence. Two cautions appear only after the second simulated save. |
| E Direct red | Prior yellow, then direct send-off | Direct pathway. No second-caution dependency. |
| F Substitution | IN first, interrupt, roster reorder, resume, second selection | Roles stay put. The second selection does not record the substitution. |
| G Commitment | Saving, Not saved, Save not verified, interruption, unknown result, in-flight retarget | Saving is not Saved. Not saved is not Save not verified. Interruption does not create a record. Blind resubmit returns false. The in-flight command keeps the activated identity. |
| H Scope | Match cautions, then a shoot-out fixture | Ledgers stay separate. |
| I Recovery claims | Docs and labels where Bank K says not proven | Finish later is `SIMULATED RECOVERY BEHAVIOR`. No production recovery guarantee sentence. |
