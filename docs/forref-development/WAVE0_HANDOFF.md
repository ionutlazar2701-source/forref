# WAVE 0 handoff

STATUS: HOLD

This is not a PASS. Founder scope is not signed off. Match Authority freeze is not issued. Don PASS is not issued. Tony PASS is not issued.

Requested model: grok-4.7-high.
Actual model: Grok 4.7.
Subagent: FORREF WAVE 0 domain/architecture reviewer.

Branch: `cursor/forref-wave0-contract-freeze-30fd`
Parent SHA: `32eded4e8d18fa0165bb170209afe9b3b0ee5e29`
Historical anchor, ancestor of the parent, not a reset target: `919c9062d607f0af255ad368b8c6cb2658d6c85a`
002D correction SHA: `35c10a20016d9955eee92f84f911ebd2c5a85374`
EXECUTION SHA: the tip of this branch after the contract-pack commit. Read it with `git rev-parse HEAD`. The contract-pack commit cannot inline its own hash. A later stamp, if present, only records test evidence and that hash.

The older branch `cursor/forref-wave1-integration-30fd` is a previous test and harness wave. It added adversarial tests and research harnesses. It is not V2 WAVE 1. V2 WAVE 1 means Goal+Score in the V2 research sense.

NEXT WAVE: V2 WAVE 1 (Goal+Score) is HOLD until an accepted WAVE 0 SHA is explicitly supplied by Product Command. Do not start it. This HOLD is the recommendation.

## What was done

Documentation and evidence only. No production feature. No sporting-law invention. No merge. No pull request.

Contracts under `docs/forref-development/` are DRAFT — NOT FROZEN. Each lists invariants, fail-closed modes, minimum tests, and unresolved questions.

Stale sentences that said `fda5af6` or `research/watch_core_r1` were absent were corrected in `docs/forref-execution/`. New fact, used there: object exists on PR #12 at fda5af6, not merged, static research instrument, no Match Record commits, no human study, no hardware certification. The rest of those execution documents was not rewritten into a new audit.

## Files written

- `docs/forref-development/GOVERNANCE_DELTA.md`
- `docs/forref-development/FIRST_TRUSTWORTHY_MATCH.md`
- `docs/forref-development/DOMAIN_CONTRACT_GOAL.md`
- `docs/forref-development/DOMAIN_CONTRACT_YELLOW.md`
- `docs/forref-development/DOMAIN_CONTRACT_RED.md`
- `docs/forref-development/DOMAIN_CONTRACT_SUBSTITUTION.md`
- `docs/forref-development/CORRECTION_SUPERSESSION_CONTRACT.md`
- `docs/forref-development/SCORE_TRUST_CONTRACT.md`
- `docs/forref-development/CAUTIONS_RECALL_CONTRACT.md`
- `docs/forref-development/EXISTING_BRANCH_REUSE_MATRIX.md`
- `docs/forref-development/PROGRAM_LEDGER.md`
- `docs/forref-development/WAVE0_HANDOFF.md`

Surgical edits:

- `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md`
- `docs/forref-execution/RISK_REGISTER.md`
- `docs/forref-execution/NEXT_WAVE.md`
- `docs/forref-execution/DEPENDENCY_GRAPH.md`
- `docs/forref-execution/WAVE_EXECUTION_PLAN.md`
- `docs/forref-execution/HANDOFF_RO.md`

## Tests

Command: `cd packages/forref_match_core && dart test`

Result: pending in this draft of the handoff until the command is run on this tree. The committed handoff replaces this paragraph with the count, the SHA tested, and TEST EXECUTED PASS or TEST EXECUTED FAIL.

The test label does not authorize domain semantics. SQLite durability settings were not changed and were not weakened. No hardware result and no referee result was fabricated.

LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED. REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT. HARDWARE EVIDENCE ABSENT.

## Contradiction

Repository governance still says the phone is the product, the watch is an upgrade, the build order is phone → Wear OS → watchOS → Garmin → Zepp, and visual design is open (`AGENTS.md`, `docs/platforms.md`, `docs/open-decisions.md`, also `docs/product.md` and `.cursor/rules/product-context.mdc`).

The V2 research and the previous Product Command charter say the watch is primary during the match when present, the phone is primary before and after, Central Instrument A is a validation baseline, Candidate C is a challenger, and build order does not redefine sporting authority.

`GOVERNANCE_DELTA.md` quotes a proposed doc change and does not apply it. Founder sign-off is REQUIRED. ADR-012 (capture after Match Ready does not depend on phone or network) is not part of the contradiction and was not proposed for edit.

Injury is a second open product question: the phone product docs include it, and the FTM draft leaves it outside the event set. The decision hide/disable versus a separate Injury contract was not made.

## Reuse one-liners

- PR #2 `3c2a37d` REBASE. Goal PARTIAL. Score CONFLICTING (`empty` is `0–0`). Not the ancestor of the yellow line.
- PR #3 `4e60248` REBASE. Goal phone cutover PARTIAL. Score CONFLICTING. Red and substitution still legacy writers.
- PR #4 `3c07f1a` PARTIAL REUSE. Read surfaces on the PR #3 projection. Not contained in PR #10. Score still integer zeros.
- PR #5 `901601f` PARTIAL REUSE. Identity and MATCH/SHOOTOUT scope. No yellow record yet.
- PR #6 `92d3a70` PARTIAL REUSE. Typed administered `YELLOW_CARD` and persistence. No phone UI on this head.
- PR #7 `b8eae3c` PARTIAL REUSE. Tip commit is correction-conflict propagation, not the nickname "disciplinary projection". The head tree also contains the standing-caution projection from ancestor commits. No synthesized red. Recall PARTIAL.
- PR #8 `4b52f5d` REJECT for domain reuse. Cloud-env install only.
- PR #9 `ac82959` PARTIAL REUSE. Yellow phone UI is in the history. Tip also gates kick-off on field-entry D1 and changes the SQLite serializer. Not approved.
- PR #10 `a85aa33` PARTIAL REUSE. Yellow read surfaces. Legacy red, substitution, and injury writers remain.
- PR #11 `1159b7a` UNKNOWN. Watch `TemporalDisplayState` only. Not merged. Not an event-contract audit.
- PR #12 `fda5af6` PARTIAL REUSE as a static research instrument only. Not production, not human evidence, not hardware evidence.

Nickname refs `origin/cursor/goal-cutover-011a-085f`, `goal-capture-cutover-78f6`, `participant-identity-foundation-78f6`, `yellow-card-commit-620c`, `yellow-card-phone-ui-620c`, and `watch-core-002d-1-8340` are MISSING. PR heads above were used instead.

## Material drift

Repository evidence overrides the research where they differ.

1. Research WAVE 0 prompt names execution base `main` at `919c906`. This mission's parent is `32eded4`, which contains that commit. Work started at `32eded4`. `main` was not checked out.
2. All six nickname branch refs are missing. The PR SHAs resolve and match the brief.
3. Research calls PR #7 a disciplinary-projection branch named `cursor/yellow-card-commit-620c`. The tip subject is "Propagate disciplinary correction conflicts". The projection is in ancestor commits on the same PR. The matrix classifies the head diff.
4. Research nicknames PR #9 as yellow phone UI. The tip subject is the kick-off field-entry gate. Yellow UI commits are in that history. Both are present. The branch also changes `SqliteDurableMatchStore` scheduling. The research text inspected here does not describe that store edit.
5. PR #4 is a real head (`3c07f1a`) and is not an ancestor of the yellow stack. PR #6, PR #8, PR #10, and PR #11 are additional heads. PR #8 is an environment fix. PR #11 was not in the mandatory list and stays UNKNOWN.
6. Previous execution docs said `fda5af6` could not be resolved. That claim is stale. The object exists on PR #12 and is not merged. The research sentence that the 002D-1B hold should be removed from the DAG overstates the correction. Object-access is no longer the hold. Human evidence and hardware evidence remain absent. 002D-1B is not closed.
7. Research acceptance for WAVE 0 includes Founder, Match Authority, and architecture sign-off with no sporting ambiguity left. Those signatures were not given. Drafts stay DRAFT. STATUS stays HOLD.
8. Research describes PR #2 as already implementing most of the proposed goal contract and PR #3 as the phone cutover to rebase onto. The payloads disagree (`scoringSide`+`period`+optional player versus `creditedSide`+`captureIntentId`). They cannot both be reused unchanged.
9. Parent score facet has no numeral. That matches the research. PR #2 and PR #3 then introduce `homeScore`/`awayScore` and an empty value of `0`/`0`, which conflicts with UNKNOWN SCORE ≠ KNOWN 0–0.
10. On PR #10, goal and yellow leave the legacy overlay. Red, substitution, and injury still call `session.saveEvent`. The research FTM rule forbids a hidden legacy injury writer and does not choose hide versus a new Injury contract. `docs/product.md` and `docs/mvp-scope.md` still include injury in the phone match. Not chosen.
11. PR #9's `REFEREE_ENTERED_FIELD_FOR_MATCH_START` is not in the drafted FTM event list. Not adopted.
12. Law-of-the-game citations in the research stay planning notes. They were not expanded.
13. Research calendar bars were not copied. They are not a schedule this wave accepts.
14. `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` classifies phone-is-the-product as a frozen contract. That is the governance side of the contradiction. It was not silently reclassified except for the 002D absence row.

## Authority questions still open

- Founder: accept or reject the governance delta. Not signed.
- Founder: visual design remains open. Central Instrument A as a drawn product screen is not approved. Candidate C is not approved.
- Founder: Injury — hide/disable for FTM, or stop for an Injury contract. Not chosen.
- Founder: whether enter-field from PR #9 is inside FTM. Not chosen.
- Match Authority: Goal payload shape (PR #2 versus PR #3). Not frozen.
- Match Authority: own-goal representation. Not frozen.
- Match Authority: yellow target set, reason field, and disciplinary-system list. Not frozen.
- Match Authority: red basis vocabulary and who may be sent off. Not frozen.
- Match Authority: substitution completion and return-profile behavior. Not frozen.
- Match Authority: typed sporting effect of correction versus legal supersession. Not frozen.
- Match Authority: when a known `0–0` is allowed. Not frozen.
- Match Authority: when cautions recall may say "No", and what D2/D6/D10 require beyond fixture labels. Not frozen.
- Engineering: PR #9 SQLite serializer change. Not approved. Pragmas were not relaxed by this wave.
- Don: REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT.
- Tony: LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED. HARDWARE EVIDENCE ABSENT.

## Exclusive owners

Listed in `PROGRAM_LEDGER.md`. Semantic registry, `record_storage_encoding.dart`, phone Live Match boundary, root `pubspec.yaml` / `pubspec.lock`, and phone ARB/l10n files were found and not modified.

## Recommendation

V2 WAVE 1 stays HOLD. Do not start Goal+Score implementation until Product Command explicitly supplies an accepted WAVE 0 SHA. The SHA of this branch is a HOLD record, not that acceptance.
