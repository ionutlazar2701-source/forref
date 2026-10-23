# WAVE 0F governance reconciliation

Parent: `78eba6fbbc012453f15ad123ff4298ad3b71c487`

Governance reconciliation candidate. Product Command acceptance is still pending. WAVE 1 stays HOLD. The Foundation contracts were not reopened. No production code was changed.

## Closed in this wave

- `README.md` no longer says the phone is the product or that the watch is an upgrade. It points at `AGENTS.md` and describes the repository as legacy cutover, not an empty skeleton.
- `docs/ux-live-match.md` keeps the historical Injury flow and marks it unavailable for FTM v1 and for WAVE 1.
- `docs/ux-pre-post-match.md` keeps the historical Injury mentions and excludes Injury from FTM v1 and from a MATCH_MEMORY add-event path.
- `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` classifies “Phone is the product; watch is later” as SUPERSEDED GOVERNANCE / HISTORICAL BASELINE. Flutter remains not a watch client.
- `docs/forref-execution/DEPENDENCY_GRAPH.md` is a historical execution graph. `phone-first` is the original-audit baseline, not current authority.

## Occurrence classification

Searched for: “The phone is the product”, “watch is an upgrade”, “phone-first”, “Phone first”, “Phone-first”, “Injury”, “injuries”, “five event”, “five actions”.

| Location | Class | Why |
| --- | --- | --- |
| `AGENTS.md` device operating model | ACTIVE COMPATIBLE | Canonical current model. “Not a cosmetic companion” denies the superseded thesis. |
| `.cursor/rules/product-context.mdc`, `docs/product.md`, `docs/mvp-scope.md`, `docs/platforms.md` | ACTIVE COMPATIBLE | Aligned in WAVE 0E. Injury capture unavailable. Build order is sequencing. |
| `docs/forref-development/FOUNDATION_FREEZE.md` | ACTIVE COMPATIBLE | Canonical freeze. Injury unavailable. Product Command still pending. WAVE 0F does not change the freeze semantics. |
| `docs/forref-development/WAVE1_GOAL_SCORE_CONTRACT.md` | ACTIVE COMPATIBLE | Unchanged. Goal + Score only. Injury excluded. WAVE 1 not launched. |
| `README.md` | ACTIVE COMPATIBLE | Phone workflow plus certified-watch target. No superseded device sentence. |
| `docs/ux-live-match.md`, `docs/ux-pre-post-match.md` | ACTIVE COMPATIBLE | Current-authority banners. Injury flow is historical and not FTM v1 or WAVE 1. |
| `docs/pricing.md` “five events” | ACTIVE COMPATIBLE | Paid-launch entitlement shorthand. It does not name Injury and it does not authorize FTM Match Memory capture. |
| `docs/forref-execution/DEPENDENCY_GRAPH.md` `phone-first` | HISTORICAL / SUPERSEDED | Under “HISTORICAL BASELINE AT ORIGINAL AUDIT”. File banner says the graph is not current sequencing. |
| `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` device-role row | HISTORICAL / SUPERSEDED | Class is SUPERSEDED GOVERNANCE / HISTORICAL BASELINE. The baseline fact is preserved. |
| `docs/forref-development/WAVE0E_GOVERNANCE.md` table that still names the old README sentence | HISTORICAL / SUPERSEDED | Header says WAVE 0F closed those items and the table is not current. |
| `docs/forref-development/GOVERNANCE_DELTA.md`, `WAVE0_HANDOFF.md` | HISTORICAL / SUPERSEDED | Historical records. Quotations and the pre-repair analysis are not current policy. |
| `docs/forref-development/FIRST_TRUSTWORTHY_MATCH.md`, `DOMAIN_CONTRACT_SUBSTITUTION.md`, other WAVE 0 domain drafts | HISTORICAL / SUPERSEDED | Header: historical draft, not the canonical contract. Injury “do not choose” is not current. |
| `docs/forref-development/EXISTING_BRANCH_REUSE_MATRIX.md`, `PROGRAM_LEDGER.md` WAVE 0 injury rows | HISTORICAL / SUPERSEDED | Audit and ledger evidence of legacy writers. Not an authorization to implement Injury. |
| `docs/architecture.md` “Phone-first” | HISTORICAL / SUPERSEDED | File banner: historical legacy, not authoritative for new Match Core. |
| `docs/data-model.md` `injury` event type | LEGACY CODE/DOC | File banner: legacy mutable aggregate. |
| `packages/match_core` and `apps/referee_phone` Injury strings | LEGACY CODE/DOC | Existing legacy implementation. Not changed. Not an FTM Match Memory authorization. |

ACTIVE CONTRADICTIONS: none.
