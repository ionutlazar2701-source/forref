# Open decisions

> **Note:** Rows marked **(legacy doc)** describe the old mutable aggregate. **New Match Core** authority is [architecture-authority.md](architecture-authority.md) — no Last Write Wins, immutable records.

Agents must **not** invent answers here. If a task needs one of these, stop and ask the user.

## Closed (do not reopen)

| Topic | Frozen in |
|---|---|
| Phone stack | Flutter shell; Drift+SQLite in app — [architecture.md](architecture.md) (legacy doc). **New** engine: separate pure-Dart package per [architecture-authority.md](architecture-authority.md) |
| MVP languages | RO + EN, English fallback |
| Match JSON / events / history / clock cache | **(legacy doc)** [data-model.md](data-model.md), [examples/match-canonical.json](examples/match-canonical.json) — current code only; superseded for new core |
| Firestore | **(legacy doc)** `users/{id}/matches/{id}` + events/history; last-local-wins — **superseded**; new replication: immutable records, no LWW — [architecture-authority.md](architecture-authority.md) || Auth | Email + Google + Apple; match works signed-out; no anonymous-as-default |
| Billing (MVP) | Not in MVP; free beta; nothing in `match_core` |
| Paid-launch model | Geography → price; `referee_level` → recommendation; plan → entitlements. Free / Plus / Pro; five regions; RO euro test prices — [pricing.md](pricing.md) |
| Added time / match list / add-after-completed | UX docs |

## Still open

- **Visual design** (and design system). Do not draw screens until asked. Do not adapt to watch until asked.
- **Pause extra confirm** — only if real matches prove accidental pauses.
- **Firebase project / Google account / environment names** (ops, not schema).
- **Storefront price points** except the frozen RO euro table in [pricing.md](pricing.md); billing provider accounts; paid-launch date; promo / team SKUs.

## How to resolve

1. Ask the user with a short list of options.
2. After they choose, record the decision in the canonical doc.
3. Do not treat chat speculation as a freeze.
