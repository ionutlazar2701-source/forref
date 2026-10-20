# Cautions recall

Status: HISTORICAL WAVE 0 DRAFT — not the canonical contract

Canonical statement: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md). Product Command acceptance of that freeze SHA is still pending. WAVE 1 must not implement Cautions Recall.

Cautions recall is a read model. It does not commit Match Records. It does not create yellow or red records.

Parent new core has a `disciplinary` facet id and no recall surface. `research/live_core_a` on this parent is a protocol harness and is not Match Core.

## Hard rules (verbatim)

Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.

MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.

UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

The score rule is restated because a recall surface that also shows score must not fill an unknown score with zeros. Recall itself must not answer an unknown caution with "no".

## Parent and branch evidence

PR #7 `b8eae3cea9b468ea56f75dfd6aee3f08595aec55` contains `PriorCautionState` with `none`, `standing`, and `unresolved`. `PriorCautionAssessment.none` and `.unresolved` both carry `standingCautionCount: 0`. The projection comment says a missing map entry is `none` only when identity and disciplinary evidence are trustworthy; otherwise the answer is unresolved. `isSecondStandingCaution` is described as advisory and not dismissal authority. Ledger keys use canonical participant id and accounting scope, not shirt number.

That is a candidate read model. The zero count on the unresolved value is dangerous if a UI reads the count and ignores the state. This draft does not accept the count as the answer.

PR #10 adds phone yellow read surfaces on that projection. This review did not find a recall flow that is limited to yes/no under a frozen completeness predicate. Classification: PARTIAL. Not a PASS.

PR #12 `fda5af6eb9013e6c37b4455d70fb8f811c4b3962` has research fixtures named `buildMatchNegativeD2`, `buildMatchNegativeD6`, and `buildMatchNegativeD10`, plus positive, admission, send-off, and shootout fixtures. The instrument sets `wroteMatchRecord: false` and keeps `matchRecords` empty. Those names are not a frozen protocol and are not human results. HUMAN EVIDENCE ABSENT. HARDWARE EVIDENCE ABSENT.

## Invariants

- Recall is read-only.
- The key is the stable participant id plus accounting scope. Shirt number is not the key.
- MATCH and SHOOTOUT are separate. A match caution is not carried into the shootout ledger by recall.
- Historical cautions and standing cautions are distinct. A withdrawn caution can remain visible as history and absent from the standing answer.
- "Yes" (has a standing caution) and "No" (has none) are legal only when completeness, identity, authority, and scope are sufficient.
- Otherwise the answer is unavailable or unknown. Unknown is not "No".
- A standing count of zero is not, by itself, the answer "No".
- Sent-off state is explicit. It is not inferred by turning two yellow rows into a red row inside recall.
- Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.
- Second-caution awareness may be shown from standing yellows. It is not a sending-off record.
- UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

## Fail-closed modes

- Unknown rendered as "No": forbidden.
- Shirt number reused by another player: do not show that player's cautions on the first id.
- Identity conflict: unknown, not a merged list.
- A missing yellow that the completeness rule requires: not "No".
- Stale replica: not the current recall.
- Match caution displayed inside shootout recall: forbidden.
- Recall tap path that commits a record: forbidden.
- Interrupted navigation that returns a false "No" or a false exact score: forbidden.

## Minimum tests

The research names D2, D6, and D10 as minimum recall tests. On PR #12 those strings are fixture depth labels (`D2`, `D6`, `D10`) in a static instrument. This draft does not define what each depth must prove. A later protocol has to define them before they can be acceptance tests. Until then they stay names, not gates.

Also required, independent of those labels:

- Positive: a standing yellow is "Yes" for that id and that scope only.
- Negative: "No" only under the frozen completeness predicate.
- Incomplete or unavailable: not "Yes" and not "No".
- Reconciliation from provisional id to canonical id: recall follows the canonical id when the map is trustworthy.
- Send-off shown only from an explicit red record, once red exists. Two yellows alone do not show a synthesized red.
- Second-caution awareness derived from two standing yellows, with no red record created by opening recall.
- Historical inspection of a withdrawn yellow: visible as history, not standing.
- Interrupted navigation: reopening does not change the answer and does not commit.
- MATCH versus SHOOTOUT: each scope answers from its own ledger.
- A score rendered beside recall does not use `0–0` for unknown.

## Unresolved questions

- Match Authority: the completeness predicate that allows "No". Not defined here.
- Match Authority: what D2, D6, and D10 require. The fixture names are not a definition.
- Match Authority: whether recall shows officials, bench, and substituted players, and how an incomplete roster is labeled.
- Don: whether the unknown state is understandable at speed. Not issued. REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT.
- Tony: watch reachability of a recall control. Not in this contract. HARDWARE EVIDENCE ABSENT. LOCAL GATE REQUIRED.
- Engineering: do not treat `standingCautionCount == 0` on `PriorCautionState.unresolved` as a reusable "no caution" API.

## Authority

Match Authority owns when "No" is true. Not issued.
Engineering owns the read-only projection after that predicate exists. Not issued.
Don owns comprehension. Not issued.
Tony owns physical operation. Not issued.
