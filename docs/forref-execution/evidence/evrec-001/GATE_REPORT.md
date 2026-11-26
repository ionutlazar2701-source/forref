# EVREC-001 gate report

Status: HUMAN GATE PENDING — CONTRACT REQUIRED

Baseline: FORREF smartwatch v1.0.14 / PR #77. CLOCK-006 v1.0.15 remains a pending clock diagnostic and is not this package.

No stage was implemented. The watch `SIM_*` journal stays a research candidate.

Founder decision A names the watch as the autonomous `MAIN_REFEREE` instrument for an explicitly provisioned match. Founder decision B names the reason screen that follows a durably committed Yellow. The mechanism those decisions need is not in the contracts this task named, and those contracts forbid filling it in.

## Stage A — Capture authority

The generation-1 root is a phone record with no predecessor and no transfer operation. `GenerationOneAuthorityRoot` in `packages/forref_match_core/lib/authority_root.dart` fixes generation 1 and `predecessorAbsent`.

`docs/forref-development/FOUNDATION_FREEZE.md` still limits that wave to a generation-1 root on the phone and lists autonomous watch capture as prohibited. `docs/forref-development/FUTURE_AUTHORITY_TRANSFER_CONTRACT.md` records fencing intent, states that the evidence schema is unspecified, and carries `PRODUCT COMMAND: PENDING FINAL ACCEPTANCE`. `docs/forref-execution/evidence/zepp-capture-bridge-001/D1_CERTIFICATION_GAP.md` still marks Match Memory authority as not enabled and Zepp `writeSync` as `HARDWARE_D1_UNCERTIFIED`. A successful readback is not Saved.

Missing before any watch writer:

- The watch-authority amendment that binds one `MAIN_REFEREE` writer, one device, and generation 1 without a second writable mode.
- The provisioning contract for stable match, team, participant, and device identities. The simulator fixture does not transfer.
- A device-local D1 proof. Power loss stays a separate physical gate. This stage will not claim Saved.

## Stage B — Goal and Score

Phone Goal and Score already follow `docs/forref-development/WAVE1_GOAL_SCORE_CONTRACT.md`. `GoalPayload` carries `scoringTeamId` and `captureIntentId`. `KnownScore` is the only numeric state. A verified generation-1 history with no goals is `KnownScore(0–0)`. An empty or gapped history stays `ScoreUnavailable`. The phone Live headline draws numerals only for `KnownScore`.

The watch Live page has no score. This task did not include an approved Figma frame for that face. A new watch score would also read an authority the watch does not hold.

## Stage C — Yellow and Red

`YellowCardPayloadV2` and `SendOffPayload` already exist. A send-off is `DIRECT` or `SECOND_CAUTION`. The second-caution pathway requires two distinct caution record ids. Two Yellow records do not create a send-off.

Neither Yellow payload has a reason. `CorrectionPayload` can repair team, participant, scope, and substitution identities. It has no disciplinary-reason field. No versioned IFAB Law 12, 2026/27 catalog was supplied. The enrichment record that would keep the committed Yellow immutable and attach a later classification was not supplied. The reason screen, `SKIP — COMPLETE LATER`, and `REASON_PENDING` stay specified behavior until that catalog and that enrichment contract exist. No reason code was added.

## Stage D — Substitution

`SubstitutionPayload` is a completed transition: outgoing id, incoming id, team id, and capture intent. `evaluateSubstitutionAdmission` admits that shape from team bindings and does not consult a competition profile. This task requires competition-rule eligibility, and no eligibility rules were supplied. There is no separate draft-substitution record. An incomplete substitution was not stored as a completed one.

## Stage E — Verification

No implementation SHA, changed-file report, Zepp package, or Bip 6 protocol. This pull request adds only this report. CLOCK-006 on v1.0.15 remains a pending clock diagnostic and is not this package.

Supply these contracts and the corresponding stage can be implemented:

1. Watch-authority amendment over the generation-1 root: one writer, device identity, offline provisioning, and the D1 condition that is allowed to become Saved.
2. Versioned Law 12 reason catalog, plus the enrichment record that links a later reason to an already committed Yellow.
3. Competition-rule eligibility for a completed substitution.
4. The approved Figma frame for the Live Match score.
