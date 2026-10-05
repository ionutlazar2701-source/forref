# Architecture

> **HISTORICAL / LEGACY — NOT AUTHORITATIVE FOR NEW MATCH CORE**
>
> This document describes the **pre-FORREF mutable `Match` aggregate** and a **Last-local-wins Firestore replica** plan. Both are **superseded** for new Match Core work.
>
> **Authoritative for new core:** [AGENTS.md](../AGENTS.md), [architecture-authority.md](architecture-authority.md).
>
> **Implementation truth (legacy):** `packages/match_core`, `apps/referee_phone/lib/match/match_session.dart`, Drift tables in `local_match_database.dart`.

Phone-first, offline-first, one match core. Clock: [ux-live-match.md](ux-live-match.md). Aggregate: [data-model.md](data-model.md). Remaining opens: [open-decisions.md](open-decisions.md).

## Phone stack (frozen)

**Flutter** for Android + iOS. Shared Dart **match core** (clock, events, derive score/state) separate from UI, so Wear OS / watchOS / Garmin can reuse the model later — they stay **native clients**, not Flutter watches.

- **Alt:** native phone later, only if Flutter cannot meet sensor/performance needs.
- **Do not:** React Native for MVP.

## i18n (frozen)

**RO + EN** from day one. **English is fallback.** Romanian is an explicit locale. Every UI string is localizable (no hardcoded copy in widgets). Do not ship RO-only and “add translations later.”

## Phone-first

The first client is the phone. Every MVP match feature in [mvp-scope.md](mvp-scope.md) must work there with no wearable attached.

Watches consume the same match core. They do not own a separate match model.

## One match core, four client levels

| Level | Device | What runs there |
|---|---|---|
| Required | Flutter phone (Android / iOS) | Timer, cards, substitutions, report, local save, sync |
| Premium / mid | Wear OS, Apple Watch, Garmin | Native standalone: time, events, GPS, heart rate |
| Budget watch (later) | Amazfit / Zepp OS | Mini-app: time + 2–3 large buttons; sync to phone |
| Band 20–50€ | Xiaomi / Huawei Band | Vibration + notification only; UI stays on the phone |

Build order: [platforms.md](platforms.md).

## Match clock

Part of the match core, not a UI counter. Reconstruct from `currentState` — [data-model.md](data-model.md).

- `matchTime` = official seconds from **period start**; wall time is `createdAt` / `runningSince`.
- On pause/resume update `elapsedSeconds` + `runningSince`; never persist a 1 Hz UI counter.
- No two concurrent clocks. `addedTimeSeconds` is `+N` on the period.

## Local persistence

**Drift + SQLite.** Transaction: event + history + derived state. Survives kill/background. No network for local save.

**Do not:** Hive or JSON files as the primary match DB.

## Dart `match_core`

```text
apps/referee_phone/     Flutter UI shell, l10n, routing, empty features
packages/match_core/    Pure Dart engine (no Flutter, no Firebase)
```

Implemented in `match_core` (no UI): canonical JSON, clock, period bookends (pause/resume, half-time, 2H, extra time, full time, finish), event factory + validator + reducer, derived score (own goal), append-only history, Undo restore (5 s window is UI).

Local persistence: Drift + SQLite in `apps/referee_phone/lib/infrastructure/database/` — one transaction writes match document + events + history (derived `score` / `currentState` on the match row). File DB for the app; in-memory executor for tests. `match_core` does not import Drift.

Phone app (mechanical UI, no visual design): match list, optional setup, Live Match control center (kick-off / pause / capture / undo), summary + finish. Offline-only; Firebase waits on project IDs.

Not yet: Firebase, visual design, PDF, watch, billing (paid launch: [pricing.md](pricing.md)).

## Offline-first

- The device that records an event stores it locally immediately.
- Cloud upload when there is an **account** and a connection.
- Bluetooth drop in minute 70 must not lose the match.
- **Kick-off / Start must not wait on internet or server Auth.**

## Cloud for MVP

Firebase: **Auth + Firestore**. Storage (PDFs) and Analytics later. AWS waits.

- Account required **to sync**, not to referee. Signed-out full match workflow.
- Providers: **email/password, Google, Apple**. Show sign-in from Settings, explicit sync, or first cloud feature — **never** at Kick-off, clock start, event capture, or on network loss.
- **Anonymous Auth is not default** and not required for offline.
- Firestore: `users/{userId}/matches/{matchId}/events/{eventId}` and `…/history/{historyId}`. Client UUIDs kept. **Last-local-wins**.
- Sync when signed in + online + unsynced changes (resume, sign-in, connectivity, save while online). Kick-off never waits.
- Do not sync PDFs, analytics, GPS, HR, watch, UI drafts, billing.
- **Billing:** not in MVP; **free during beta**. No IAP, paywalls, or entitlements in `match_core`. Paid-launch plans and regional prices: [pricing.md](pricing.md) (account/profile + store, not the Match aggregate).

## Watch clients

Native only:

- Wear OS: Kotlin + Wear Compose
- Apple Watch: SwiftUI
- Garmin: Connect IQ (Monkey C), after phone + Wear OS core is stable
- Zepp OS: last

Flutter is **not** a watch target.
