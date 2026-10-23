# Sandbox Match Memory contract

Package: `research/simulator_sandbox`

This package may import `forref_match_core` and `forref_match_persistence`. It does not change their semantics. No other research package imports them.

The database file is:

`<absolute simulator root>/forref-simulator/<session-id>/match-memory.sqlite`

The session id is one synthetic segment. A relative root, a `..` segment, and `:memory:` are refused. The phone database is not opened.

The match id is `sim-sandbox-match`. Participant ids and capture intent ids must start with `sim-` or `sim-intent-`.

The first capture path is the existing v1 yellow `MatchRecord` committed through `SqliteDurableMatchStore.commit`. Durability pragmas are the store's own settings.

`SANDBOX D1 COMMITTED` is set only when the store returns `DurableCommitSuccess` for a new row and `getById` reads that row back and the deterministic projection contains the record id.

An idempotent retry of the same capture intent uses `SANDBOX D1 ALREADY COMMITTED` and does not add a row.

A thrown abort before `COMMIT` uses `SANDBOX COMMIT FAILED`. The yellow row is absent.

Timings and file sizes are `DESKTOP SANDBOX MEASUREMENT`. They are not watch or phone performance certification.

Closing the session and opening the same file rebuilds the projection without Flutter state.
