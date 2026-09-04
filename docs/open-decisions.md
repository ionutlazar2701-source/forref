# Open decisions

Agents must **not** invent answers here. If a task needs one of these, stop and ask the user.

## Closed (do not reopen)

| Topic | Frozen in |
|---|---|
| Phone stack | Flutter; `packages/match_core`; Drift+SQLite — [architecture.md](architecture.md) |
| MVP languages | RO + EN, English fallback |
| Match JSON / events / history / clock cache | [data-model.md](data-model.md), [examples/match-canonical.json](examples/match-canonical.json) |
| Firestore | `users/{id}/matches/{id}` + events/history; last-local-wins |
| Auth | Email + Google + Apple; match works signed-out; no anonymous-as-default |
| Billing | Not in MVP; free beta; nothing in `match_core` |
| Added time / match list / add-after-completed | UX docs |

## Still open

- **Visual design** (and design system). Do not draw screens until asked. Do not adapt to watch until asked.
- **Pause extra confirm** — only if real matches prove accidental pauses.
- **Firebase project / Google account / environment names** (ops, not schema).

## How to resolve

1. Ask the user with a short list of options.
2. After they choose, record the decision in the canonical doc.
3. Do not treat chat speculation as a freeze.
