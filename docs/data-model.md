# Data model

> **HISTORICAL / LEGACY — NOT AUTHORITATIVE FOR NEW MATCH CORE**
>
> This document defines the **mutable Match aggregate** (`events[]` + in-place edits + `currentState` checkpoint + **last-local-wins** sync). That model is **legacy** and conflicts with frozen Match Memory (immutable records, supersession, projection rebuild).
>
> **Authoritative for new core:** [AGENTS.md](../AGENTS.md), [architecture-authority.md](architecture-authority.md).
>
> **Legacy fixture only:** [examples/match-canonical.json](examples/match-canonical.json) — describes current code shape, not FORREF record envelopes.

Canonical local-first **Match** aggregate. Example: [examples/match-canonical.json](examples/match-canonical.json).

`events` + period/clock transitions are authoritative. `score` and `currentState` are **derived caches** persisted for recovery. Do not keep a competing score or clock.

IDs are **client UUIDs**. Schema fields that are unknown use JSON `null`. Arrays are always present (`[]`). `schemaVersion` starts at `1`.

Quick Capture and complete capture use the **same** event schema. Do not invent per-UI event models.

## Enums

**`status` (match):** `setup | ready | live | paused | half_time | full_time | completed`

- No `review` (Summary is a screen, not a status — [ux-pre-post-match.md](ux-pre-post-match.md)).
- Extra time: stay `live` or `paused`; `currentState.periodId` is `et1` / `et2`.

**`period.id`:** `1h | 2h | et1 | et2 | pens`

- `pens` is **reserved**. Do not activate penalty kicks in MVP.

**`period.status`:** `pending | active | paused | completed`

**`event.type`:** `goal | yellow_card | red_card | substitution | injury`

**`event.status`:** `complete | incomplete` — **this is the only incomplete flag**. Do not add `data.incomplete`.

**`sync.syncState`:** `local_only | pending | synced | error`

**`player.role`:** `starter | substitute | null`

## Time and clock cache

- `matchTime` = official seconds from **period start** (period `1h`, `421` → `07:01` in that half).
- `createdAt` / `updatedAt` / `runningSince` = UTC instants.

`currentState`:

```json
{
  "periodId": "1h",
  "clockRunning": true,
  "elapsedSeconds": 642,
  "runningSince": "2026-09-03T18:10:00.000Z",
  "addedTimeSeconds": 0
}
```

- `elapsedSeconds` = checkpoint at last pause/resume/period change.
- While `clockRunning`: `currentElapsed = elapsedSeconds + floor((now - runningSince) / 1000)`.
- On pause: write `elapsedSeconds = currentElapsed`, `clockRunning = false`, `runningSince = null`.
- On resume: `clockRunning = true`, `runningSince = now`.
- Do not persist a UI tick every second. Do not assume a Dart timer survives process death.

`addedTimeSeconds` on the period and in `currentState` is the announced `+N`, not a second clock.

## Player refs in `data`

```json
{
  "playerId": "uuid-or-null",
  "shirtNumber": 9,
  "name": "string-or-null",
  "isUnknown": false
}
```

- Squad link: `playerId` set, `isUnknown` false.
- Free number: `playerId` null, `shirtNumber` set, `isUnknown` true (sub `in` with #18 can still be `event.status: complete`).
- Unknown: all ids/numbers null, `isUnknown` true → typically `event.status: incomplete` for goal/card/injury.

## Event `data` by type

Shared outer event: `eventId`, `matchId`, `type`, `status`, `periodId`, `matchTime`, `createdAt`, `updatedAt`, `data`.

**Goal** — `teamId`, `player`, `isOwnGoal`, `note`, `reason`.

Own goal: `isOwnGoal: true` and `teamId` is the team that **concedes** (the player’s team). Score derivation awards the **other** side. Never patch `score` by hand.

**Yellow / red** — `teamId`, `player`, `note`, `reason`. No extra reason on capture; fill on edit.

**Substitution** — `teamId`, `out`, `in` (same player-ref shape), `note`, `reason`. Either side may be unknown.

**Injury** — `teamId`, `player`, `note`, `reason`.

## History

Append-only. **Full snapshots** of the event (or match fields) in `previousValue` / `newValue`, not diffs. `eventId` never changes.

```json
{
  "historyId": "history-001",
  "eventId": "event-goal-001",
  "action": "update",
  "changedAt": "2026-09-03T18:15:00.000Z",
  "previousValue": {},
  "newValue": {}
}
```

Match-level edits: `eventId` is `null`. Goal → not-goal: same `eventId`, new `type`; **rebuild score** from current `events[]`. No compensating “score correction” event. Undo uses `action: "undo"`.

## Incomplete

Authoritative: `"status": "incomplete"`. `data` still uses the canonical shape with nulls / `isUnknown`. Never block Full time, Finish, or PDF.

## Local writes

One **transaction**: event + history + derived `score` / `currentState`. Store: **Drift + SQLite** — [architecture.md](architecture.md). Not Hive, not JSON files as primary DB.

## Sync (replica)

Firestore: `users/{userId}/matches/{matchId}` with `events/{eventId}` and `history/{historyId}` subcollections. Match doc holds metadata, teams, crew, squads, periods, `currentState`, `score`, `sync`. Preserve client IDs. **Last-local-wins** via `updatedAt`. No CRDT.

Not synced: PDFs, analytics, GPS, HR, watch, UI drafts, billing.

Not on the Match document: `referee_level`, subscription plan, entitlements, or store price IDs. Those belong on the user account at paid launch — [pricing.md](pricing.md).

Sync only if signed in **and** online **and** unsynced changes (connectivity, sign-in, resume, local save). Kick-off never waits.
