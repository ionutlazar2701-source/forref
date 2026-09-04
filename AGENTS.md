# AGENTS.md

Ref App is a football referee match app in the Refsix space, with wider device reach. The **phone is the product**; the watch is an upgrade. A referee with a cheap phone and no watch must complete a full match.

There is a Flutter **architecture skeleton** (`apps/referee_phone`, `packages/match_core`). Do not add visual design or match-engine logic unless asked. Schema: [docs/data-model.md](docs/data-model.md).

## Read order

Before changing product behavior or proposing architecture, read in this order:

1. [docs/product.md](docs/product.md) — identity, audience, Refsix delta
2. [docs/mvp-scope.md](docs/mvp-scope.md) — ship now vs later vs never
3. [docs/architecture.md](docs/architecture.md) — Flutter phone, offline-first, Firebase
4. [docs/data-model.md](docs/data-model.md) — Match aggregate, events, `matchTime`
5. [docs/platforms.md](docs/platforms.md) — Wear OS first; Zepp last; bands are not apps
6. [docs/open-decisions.md](docs/open-decisions.md) — what you must not decide alone

Also:

- [docs/ux-live-match.md](docs/ux-live-match.md) when the task is Live Match, events, or in-match UX
- [docs/ux-pre-post-match.md](docs/ux-pre-post-match.md) when the task is setup, kick-off bookends, full time, extra time, summary, or PDF
- [docs/testing.md](docs/testing.md) when the task is test strategy or hardware
- [docs/hardware-test-matrix.md](docs/hardware-test-matrix.md) when recommending watches to rent or buy

## Invariants

Do not reverse these. Full rationale lives in `docs/`; `.cursor/rules/` restates the short form.

- **Phone-first.** Do not start with watch-only code. The first shippable client is the phone.
- **Build order:** (1) phone, (2) native Wear OS, (3) watchOS, (4) Garmin Connect IQ, (5) Zepp OS last.
- **Offline-first.** Match data is saved locally on the device that recorded it. Cloud sync is later, when a connection exists. A match must not be lost if Bluetooth drops in minute 70.
- **Phone stack:** Flutter (Android + iOS). Pure Dart `match_core` (no Material). Drift + SQLite. Flutter is not a watch target. Not React Native.
- **i18n:** RO + EN; English fallback; no hardcoded UI strings.
- **Watches are native.** Kotlin + Wear Compose; SwiftUI on Apple Watch.
- **Firebase:** Auth (email, Google, Apple) + Firestore replica. Auth does not block Kick-off. Last-local-wins. No billing in match_core. AWS waits.
- **ChatGPT / Gemini notes are not source of truth.** Informal AI chat is exploration only. Canonical decisions are this file and `docs/`.

## Open-decision protocol

If the task requires any item in [docs/open-decisions.md](docs/open-decisions.md) (visual design, Firebase project IDs, pause-confirm tests):

1. Stop.
2. Ask the user.
3. Do not invent a default and proceed.

## After implementation starts

When code exists, keep docs in sync with behavior. Do not silently reopen a frozen decision; the user must say so.
