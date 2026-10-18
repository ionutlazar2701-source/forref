# WAVE 0E governance reconciliation

WAVE 0F closed the five active items named in the table below. This table is the WAVE 0E classification, not the current one. Current classification: [WAVE0F_GOVERNANCE.md](WAVE0F_GOVERNANCE.md).

Parent: `e71fa24d2d22eb63952209170ec82e1b6eb4e954`

The Foundation contracts were not reopened. WAVE 1 stays HOLD. Product Command has not accepted the Foundation Freeze SHA.

This wave was allowed to edit `.cursor/rules/product-context.mdc`, `docs/product.md`, `docs/mvp-scope.md`, `docs/platforms.md`, and status notes under `docs/forref-development/`. It did not edit `README.md`, task UX docs, or `docs/forref-execution/`.

## Aligned in this wave

- `.cursor/rules/product-context.mdc` now states the device operating model and points at `AGENTS.md`. It no longer says the phone is the product or that the watch is an upgrade.
- `docs/product.md` separates phone accessibility from the certified-watch in-match role. It states that no watch implementation is claimed.
- `docs/mvp-scope.md` separates phone accessibility, FTM v1, and WAVE 1. Authoritative Injury capture is unavailable in FTM v1 and is not WAVE 1.
- `docs/platforms.md` keeps the build order and labels it implementation sequencing.

## Occurrence classification

| Location | Class | Why |
| --- | --- | --- |
| `AGENTS.md` device operating model | BENIGN CONTEXT | Current canonical model. |
| `.cursor/rules/product-context.mdc` | BENIGN CONTEXT | Aligned always-applied rule. "Not a cosmetic upgrade" denies the superseded thesis. |
| `.cursor/rules/non-goals.mdc` | BENIGN CONTEXT | Always applied. Rejects a watch-only app with no phone match. It does not say the phone is the product or that the watch is an upgrade. |
| `docs/product.md`, `docs/mvp-scope.md`, `docs/platforms.md` | BENIGN CONTEXT | Aligned in this wave. "Not a cosmetic upgrade" denies the superseded thesis. |
| `docs/forref-development/FOUNDATION_FREEZE.md` | BENIGN CONTEXT | Canonical freeze. Injury unavailable. WAVE 1 HOLD. Acceptance still pending. |
| `docs/forref-development/GOVERNANCE_DELTA.md` quotations and WAVE 0 analysis | HISTORICAL / BANNERED | Header: historical contradiction record, not current policy. Proposed-edits quotation was not adopted. |
| `docs/forref-development/WAVE0_HANDOFF.md` | HISTORICAL / BANNERED | Header: historical packet. Later sentences that still describe the pre-repair repository are not current policy. |
| `docs/forref-development/FIRST_TRUSTWORTHY_MATCH.md` and other `DOMAIN_CONTRACT_*.md` / `SCORE_TRUST_CONTRACT.md` / `CORRECTION_SUPERSESSION_CONTRACT.md` / `CAUTIONS_RECALL_CONTRACT.md` lines that say the Injury decision was not chosen | HISTORICAL / BANNERED | Header: historical WAVE 0 draft, not the canonical contract. The freeze says Injury capture is unavailable. |
| `docs/architecture.md` "Phone-first" | HISTORICAL / BANNERED | File banner: historical legacy, not authoritative for new Match Core. |
| `docs/data-model.md` `injury` event type | HISTORICAL / BANNERED | File banner: historical legacy mutable aggregate, not authoritative for new Match Core. |
| `README.md` line "The phone is the product; the watch is an upgrade." | ACTIVE CONTRADICTION | Unbannered repository introduction. Outside the WAVE 0E file list. |
| `docs/ux-live-match.md` Injury capture (`Injury → Team → Player → auto-save`; event row includes Injury) | ACTIVE CONTRADICTION | Unbannered task doc. `AGENTS.md` tells agents to read it for Live Match mechanics. It still specifies Injury as a current save path and does not say Injury is outside FTM v1. Outside the WAVE 0E file list. |
| `docs/ux-pre-post-match.md` injury counts and `+ Add event` including Injury | ACTIVE CONTRADICTION | Unbannered task doc. Same authority path as Live Match mechanics. Outside the WAVE 0E file list. |
| `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` row classifying "Phone is the product; watch is later" as FROZEN CONTRACT | ACTIVE CONTRADICTION | No superseded banner. The row still presents that doctrine as a frozen contract. Outside the WAVE 0E file list. |
| `docs/forref-execution/DEPENDENCY_GRAPH.md` "phone-first" inside the FROZEN block | ACTIVE CONTRADICTION | No superseded banner. The block still lists phone-first as frozen. Outside the WAVE 0E file list. |

Legacy code still contains an Injury event type. That is current legacy implementation, not a product-doctrine sentence, and this wave did not change code.

No `lib/` or test file was changed. No watch certification is claimed.
