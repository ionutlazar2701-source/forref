# Existing branch reuse matrix

Status: AUDIT — NOT A MERGE PLAN

This matrix is evidence from WAVE 0. It is not the Foundation Freeze. Canonical contracts are [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md) and [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). Do not reuse a branch that represents unknown score as integer 0–0.

No branch is cherry-picked. No pull request is merged. Green tests on an old branch are not contract correctness.

Parent: `32eded4e8d18fa0165bb170209afe9b3b0ee5e29`.
Merge-base of every `origin/pr-*` below with `919c9062d607f0af255ad368b8c6cb2658d6c85a` is `919c906` itself. None of these heads is on `origin/main`. None is an ancestor of the parent.

Nickname refs were looked up and are missing:

- `origin/cursor/goal-cutover-011a-085f` — MISSING
- `origin/cursor/goal-capture-cutover-78f6` — MISSING
- `origin/cursor/participant-identity-foundation-78f6` — MISSING
- `origin/cursor/yellow-card-commit-620c` — MISSING
- `origin/cursor/yellow-card-phone-ui-620c` — MISSING
- `origin/cursor/watch-core-002d-1-8340` — MISSING

The PR head SHAs are the evidence.

## How to read a cell

Against the draft contracts in this directory:

- IMPLEMENTED — the diff shows the invariant, and this review did not see a contradicting default.
- PARTIAL — some of the invariant is present.
- ABSENT — the diff does not implement it.
- CONFLICTING — the diff contradicts a hard rule or keeps a second writer for that concern.
- UNKNOWN — not determined from the diff. PR #11 stays in this class for the event columns.

A reuse word is about the branch as a whole, not a license to copy files.

## Lineage actually observed

- PR #2 is a goal fork. It is not an ancestor of PR #3.
- PR #3 is an ancestor of PR #4, PR #5, PR #6, PR #7, PR #9, and PR #10.
- PR #4 is not an ancestor of PR #5. The yellow line does not contain the PR #4 read-surface commit.
- PR #5 is an ancestor of PR #6, PR #7, PR #9, and PR #10.
- PR #6 is an ancestor of PR #7, PR #9, and PR #10.
- PR #7 is an ancestor of PR #9 and PR #10.
- PR #9 is an ancestor of PR #10.
- PR #8, PR #11, and PR #12 do not sit on that stack.

## Matrix

| PR | SHA | Subject | Reuse | Goal | Yellow | Red | Sub | Score | Cautions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| #2 | `3c2a37dada8560765c45597975b67edd8d422448` | Freeze GOAL as a main-referee determination. | REBASE | PARTIAL | ABSENT | ABSENT | ABSENT | CONFLICTING | ABSENT |
| #3 | `4e602485c2a9bb85754b7cdb060ac16ac1318aed` | Cut Live Match Goal capture over to Match Memory. | REBASE | PARTIAL | ABSENT | CONFLICTING | CONFLICTING | CONFLICTING | ABSENT |
| #4 | `3c07f1a09d4cd6272acc04acd8113fccfff736ff` | Consolidate Goal/score read surfaces onto GoalMatchProjection | PARTIAL REUSE | PARTIAL | ABSENT | CONFLICTING | CONFLICTING | CONFLICTING | ABSENT |
| #5 | `901601f2d5a6b16ed46333021e1fbf5c62b2c0da` | Participant identity and disciplinary authority foundation (012C-1) | PARTIAL REUSE | PARTIAL | PARTIAL | CONFLICTING | CONFLICTING | CONFLICTING | ABSENT |
| #6 | `92d3a70c48e66c7c123b334010a6db36f8538956` | Typed YELLOW_CARD V1 semantic contract and persistence (012C-2) | PARTIAL REUSE | PARTIAL | PARTIAL | CONFLICTING | CONFLICTING | CONFLICTING | ABSENT |
| #7 | `b8eae3cea9b468ea56f75dfd6aee3f08595aec55` | Propagate disciplinary correction conflicts | PARTIAL REUSE | PARTIAL | PARTIAL | PARTIAL | CONFLICTING | CONFLICTING | PARTIAL |
| #8 | `4b52f5d93a56f143ae80d857f000702dae805fea` | Fix cloud environment install | REJECT | ABSENT | ABSENT | ABSENT | ABSENT | ABSENT | ABSENT |
| #9 | `ac82959585df3f0fe0847abb6be53d288bb634ae` | Gate Kick-off on explicit field-entry D1 before match start | PARTIAL REUSE | PARTIAL | PARTIAL | CONFLICTING | CONFLICTING | CONFLICTING | PARTIAL |
| #10 | `a85aa330b960d431c02bd10b8c4db8a437491f86` | Consolidate yellow card read surfaces onto disciplinary projection | PARTIAL REUSE | PARTIAL | PARTIAL | CONFLICTING | CONFLICTING | CONFLICTING | PARTIAL |
| #11 | `1159b7a1f34e8286c3b5c713b9c7bac4b627b0de` | Watch TemporalDisplayState projection | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |
| #12 | `fda5af6eb9013e6c37b4455d70fb8f811c4b3962` | 002D-1 referee validation research instrument | PARTIAL REUSE | ABSENT | ABSENT | ABSENT | ABSENT | ABSENT | ABSENT |

PARTIAL REUSE for PR #12 means the tree may be read as a static research instrument. It is REJECT as production software, as a Match Core change, as human evidence, and as hardware evidence.

## Notes that the cells compress

### PR #2 — REBASE

Goal is PARTIAL: `GOAL` is a `humanDetermination`; credited side is required (`GoalScoringSide`); own goal is described as that same credited side; optional player fields are not required; period is on the payload; admission refuses abandoned matches, ambiguous lineage, ended matches, and a suspended period; legal supersession is described as withdrawing the scoring effect while the goal record remains. There is no `captureIntentId` on this payload.

Score is CONFLICTING: `GoalMatchProjection.empty` sets `homeScore: 0` and `awayScore: 0`.

This fork is not the base of the yellow stack. Rebase only after the goal payload question in `DOMAIN_CONTRACT_GOAL.md` is answered. Do not merge beside PR #3.

### PR #3 — REBASE

Goal is PARTIAL: phone `commitGoal` returns `DurableCommitResult` and the boundary comment says a failure is not a saved goal and must not write a legacy goal row beside it. Payload is `creditedSide` plus `captureIntentId`. Period and player are not on the payload. Own-goal wording from PR #2 is not in this payload.

Score is CONFLICTING: same integer empty default. Live Match shows `_goalProjection.homeScore` or, if the boundary is unavailable, `match.score` from the legacy match.

Red and substitution are CONFLICTING: the new goal path exists, and red, substitution, and injury still go through `EventType` and the legacy session. That is a second writer, not an implementation of red or substitution.

### PR #4 — PARTIAL REUSE

Extra relative to the research mandatory list. The research wave table did ask to reuse PR #2–#4. The head adds `goal_match_read_model.dart` and points Live Match, summary, and match list at `GoalMatchProjection`. It inherits PR #3's integer score. It is not in the yellow ancestry, so a later integration cannot assume PR #10 contains this read-surface commit.

### PR #5 — PARTIAL REUSE

Yellow column is PARTIAL only for identity groundwork: `MatchParticipantId` is documented as not a shirt number; `DisciplinaryAccountingScope` is `match`, `shootout`, `unresolved`; registration, binding correction, and reconciliation payloads exist. There is no `YELLOW_CARD` record on this head. Cautions recall is ABSENT. Goal and score stay at the PR #3 classification. Red and substitution stay CONFLICTING because the PR #3 phone routing is in the tree.

### PR #6 — PARTIAL REUSE

Yellow is PARTIAL: administered-caution meaning, participant ref, status, scope, capture intent, optional reason, persistence encoding. The semantic text rejects an automatic second-yellow consequence. Phone yellow capture is not this commit. Standing projection is not this commit. Cautions recall is ABSENT.

### PR #7 — PARTIAL REUSE

Research nicknames this `cursor/yellow-card-commit-620c` and "disciplinary projection". That ref is missing. The tip subject is correction-conflict propagation. The tip diff against its parent is `disciplinary_match_projection.dart` and its test (conflict propagation). The projection itself is an ancestor commit on this PR (`aaab03a` and neighbors), so the head tree does contain it. Classification uses the head diff against `919c906`, not the nickname.

Yellow is PARTIAL: standing ledger, `isSecondStandingCaution`, `nextCautionWouldBeSecond`, comments that these are not dismissal authority.

Red is PARTIAL: the "do not synthesize a red" prohibition is present as the absence of a red writer plus those comments. An explicit `RED_CARD` act is ABSENT. The cell is PARTIAL for that reason, not IMPLEMENTED.

Cautions is PARTIAL: `none` / `standing` / `unresolved` exist, and unresolved is not supposed to be reported as none. Both `none` and `unresolved` still store `standingCautionCount: 0`. There is no frozen completeness predicate and no recall navigation contract.

Substitution remains CONFLICTING through the inherited phone legacy path. Score remains CONFLICTING through the inherited goal projection.

### PR #8 — REJECT

Confirmed. Diff is `.cursor/Dockerfile`, `.cursor/environment.json`, and executable-bit changes on `tool/cloud_bootstrap.sh` and `tool/verify_cloud.sh` (zero content lines). No sporting semantics. Do not reuse for domain work. Cloud install value, if any, is out of this matrix.

### PR #9 — PARTIAL REUSE

Research nicknames this the yellow phone UI and then, in the fetched subject, it is the kick-off gate. Both are in the history. The tip commit gates kick-off on field entry. Ancestors include "Cut live Yellow capture to Match Memory" and "Add explicit Enter field action for yellow card authority". Yellow phone UI is actually in this history.

The head also adds `REFEREE_ENTERED_FIELD_FOR_MATCH_START` and `REFEREE_LEFT_FIELD_AFTER_MATCH`. Those codes are outside the drafted event set. Not adopted.

`SqliteDurableMatchStore` on this line replaces the future queue serializer with `Future.sync` and adds `abortBeforeReadForTest`. Journal mode and `synchronous` were not what that diff changed. The serializer change is still a durability-path edit. It is not approved by this audit and is a reason the branch is not REUSE.

### PR #10 — PARTIAL REUSE

Yellow read surfaces (`yellow_card_read_surface.dart`, summary read surface) sit on the disciplinary projection. Cautions stays PARTIAL. The goal file change exports `projectedPlayingTimeAtRecord` for period-anchored records. It does not add an unknown score state. Red, substitution, and injury still reach the legacy overlay for types other than goal and yellow (`live_match_page.dart` keeps `CaptureOverlay` and `session.saveEvent` for those types).

### PR #11 — UNKNOWN

Not in the mandatory research list. Diff is `temporal_display_state.dart`, a small change to `temporal_match_projection.dart`, the barrel export, and tests. The type is documented as a disposable watch-facing temporal projection, not Match Memory and not a timer authority. This review did not audit it against Domain Clock Policy and did not classify its event columns. Do not merge from this wave.

### PR #12 — PARTIAL REUSE as an instrument only

`research/watch_core_r1/` exists at this SHA: `index.html`, `src/app.js`, `src/clock.js`, `src/fixtures.js`, `src/model.js`, `styles.css`, and tests. `model.js` states it is research only, capture footprints never create match records, and scenario transitions are simulations. Taps set `wroteMatchRecord: false`. `matchRecords` stays empty. Fixture labels include D2, D6, and D10. That is not production software, not a human study, and not hardware certification.

Goal, yellow, red, substitution, score, and cautions are ABSENT as Match Memory behavior. Research controls with those labels do not implement the contracts.

## What not to do next

- Do not merge PR #2 and PR #3. The goal payloads disagree.
- Do not treat PR #4 as already contained in PR #10.
- Do not treat PR #7's tip message as the whole disciplinary design, or the nickname as the tip message.
- Do not treat PR #9 as yellow-only or as field-entry-only. It is both, plus a store serializer change.
- Do not promote PR #12 to an engineering PASS.
- Do not start V2 WAVE 1 from any of these SHAs. WAVE 1 waits for an accepted WAVE 0 SHA from Product Command. This matrix is not that acceptance.
