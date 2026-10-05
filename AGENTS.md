# AGENTS.md

Ref App is a football referee match app. The **phone is the product**; the watch is an upgrade. A referee with a cheap phone and no watch must complete a full match.

This repository is in **legacy cutover**: the Flutter shell is reusable; **`packages/match_core` is legacy** and must not define new Match Core semantics.

## Authority hierarchy

Read only what the task needs. Do not read `/docs` wholesale.

| Priority | Source | Use |
| --- | --- | --- |
| 1 | **This file** | Operational rules for every session |
| 2 | [docs/architecture-authority.md](docs/architecture-authority.md) | Frozen FORREF Match Core index (ADR-001→018), flow, prohibitions |
| 3 | **Current code + tests** | What the repo actually does today (legacy truth) |
| 4 | Task-specific UX/product docs | Mechanics only — not Match Memory authority |
| 5 | Legacy docs (bannered) | Historical reference for the old mutable aggregate |

Upstream contracts (frozen outside this repo): **FORREF Match Core Architecture v1.0** (18 ADRs), **Match Operating Model v1.0**, **Domain Clock Policy v1**, **Product Failure Suite v1**, **SC-1→SC-5 Corruption Contract**. The index in `docs/architecture-authority.md` maps them; do not reopen without reporting an explicit contradiction.

## Frozen Match Core rules

Non-negotiable for **new** Match Core work:

- **Match Memory** = immutable authoritative **Match Records**. Current match state = **deterministic, rebuildable, disposable projection**.
- Committed records are **never mutated or deleted** to correct history. Correction and legal supersession create **new** records.
- **D1 durable commit** completes **before** any successful **Saved** acknowledgement. Saved cannot mean RAM, queue, API accepted, Firestore accepted, Bluetooth sent, or phone received.
- After the autonomous capture device enters **Match Ready**, match-critical capture must require **no phone, network, cloud, Firebase, or peer** (on the phone app: local capture only; on a future watch: autonomous on-device).
- Timer rendering and clock checkpoints are **not** temporal authority. Temporal truth derives from authoritative temporal transitions, evidence, domain clock policy, and temporal corrections.
- **Replication** exchanges immutable Match Records. **No Last Write Wins.** Replication does **not** transfer sporting capture authority.
- Schema upgrades must **not** rewrite historical record semantics.
- **Snapshots** are optimization only — never authority.
- During legacy cutover: **exactly one writable Match Authority**. Legacy `Match` / `MatchSession` and new Match Memory must not both accept writes for the same match.
- New Match Core must **not** depend on legacy `package:match_core`, Flutter, or Firebase.

## Cursor execution discipline

- **Current code and tests** = implementation truth for legacy behavior.
- **Frozen architecture / domain docs** (via `architecture-authority.md`) = intended semantics for new core.
- **Historical legacy docs** (`docs/architecture.md`, `docs/data-model.md`, etc.) = reference only — see their banners.
- Use **compact delta execution briefs**; do not re-audit the whole repo unless asked.
- Do not reopen frozen decisions without reporting an explicit contradiction to the user.
- Do not treat ChatGPT/Gemini notes as source of truth.

## Product invariants (still valid)

- **Phone-first.** Build order: phone → Wear OS → watchOS → Garmin → Zepp last.
- **Offline-first.** Local save on the recording device; cloud is later replica, not capture gate.
- **Phone stack:** Flutter + Drift + SQLite shell. **New** Match Core: pure Dart, no Flutter/Firebase.
- **i18n:** RO + EN; English fallback; no hardcoded UI strings.
- **Watch clients:** native only (Kotlin + Wear Compose; SwiftUI). Flutter is not a watch target.
- **MVP UX:** Kick-off from READY. Full time ≠ Finish. No billing in match engine. Paid launch: [docs/pricing.md](docs/pricing.md).

## Task-specific reads

When the task touches these areas, read the named doc — not the full tree:

- Live Match UX → [docs/ux-live-match.md](docs/ux-live-match.md)
- Setup / full time / summary / PDF → [docs/ux-pre-post-match.md](docs/ux-pre-post-match.md)
- Scope → [docs/mvp-scope.md](docs/mvp-scope.md)
- Platforms → [docs/platforms.md](docs/platforms.md)
- Product identity → [docs/product.md](docs/product.md)
- Open items → [docs/open-decisions.md](docs/open-decisions.md)

## Open-decision protocol

If a task requires an item in [docs/open-decisions.md](docs/open-decisions.md) (visual design, Firebase project IDs, pause-confirm tests):

1. Stop.
2. Ask the user.
3. Do not invent a default and proceed.

## Legacy code

`packages/match_core` and `apps/referee_phone/lib/match/match_session.dart` implement a **mutable Match aggregate**. That is legacy. Do not extend it for new authority semantics. New work goes in a **separate package** behind a single commit port (see Legacy Reconciliation Audit 001).

When code exists, keep **task-relevant** docs in sync with behavior. Do not silently reopen frozen architecture; the user must say so.

## Cursor Cloud specific instructions

- Run `./tool/verify_cloud.sh` from the repository root before reporting **COMPLETE**. Do not report complete when verification fails.
- Cloud environments are **Linux**. Use repository-relative paths; never assume Windows drive letters, `C:\...`, or backslash-only path handling.
- Never weaken Match Core, D1, authority, temporal, integrity, or fail-closed invariants for cloud convenience.
- Never modify SQLite durability settings (`journal_mode`, `synchronous`, etc.) merely to make cloud tests faster.
- Do not claim physical-device, field, or signing certification from cloud execution alone.
- Hardware- or credential-dependent tasks must report **`LOCAL GATE REQUIRED`** — see [docs/local-gates.md](docs/local-gates.md).
- Do not attempt Garmin/watch deployment or on-device validation as cloud verification.
- Do not treat cloud VM performance measurements as phone or watch performance certification.
- Use isolated temporary directories for file-backed tests; do not depend on founder-specific filesystem state.
