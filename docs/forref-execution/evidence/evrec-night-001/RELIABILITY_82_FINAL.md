# EVREC-82-FINAL

Software reliability closure on draft PR #82. Parent `bcf48f39c625d7dfa836ea21ca7f182b9a547fa6`. Official Match Records stay closed. `authoritativeCaptureAdmitted` stays false. D1 stays uncertified. This is recovery evidence, not a power-loss certification. No hardware pass.

## Path selection

`selectGoalJournalPath` returns `{ ok, path, reason }`.

- A missing legacy journal is absent. A new v2 journal may be selected.
- A fully valid legacy journal owned only by the active match is reused. Its historical frames are not rewritten.
- A fully valid legacy journal owned only by another match is left untouched. The active match uses its own v2 path.
- An unreadable, corrupt, torn, mixed-owner, or otherwise unassignable legacy journal returns `ok: false`. `openLocalGoal` does not open a file in that case.
- A legacy journal and a newer journal that both contain the same match return `ambiguous-journal`.
- An uncertain journal is not treated as an empty history.

## Filenames

New journals are `forref_watch_goal_journal_v2.<sha256>.journal`. Pending captures are `forref_watch_goal_pending_v2.<sha256>.json`. The digest is the lowercase SHA-256 of the exact UTF-8 `matchId`. The same vectors are asserted in Dart `sha256Hex` and the watch `sha256Hex`:

- `mățch` → `f088f7e75f4b2eb5ad3179eb7d82ca18f23d731092e2149b9071da7a154811bd`
- `home team` → `8ecabaa201d7ef377839350ed3e66404ca87d80a9f52529faa8cce59e56d4600`
- `a/b` → `c14cddc033f64b9dea80ea675cf280a015e672516090a5626781153dc68fea11`

Existing v1 paths are recognized. They are not renamed, merged, overwritten, or deleted. Two pending files for one match are `ambiguous-pending`.

## Close

`createFileGoalStore` requires an integer file descriptor, a `writeSync` length equal to the frame, and `closeSync() === 0`. An exception, a short write, or any other close result is `UNCERTAIN`. A readable frame after a failed close is not a successful new append. The same intent later resolves as idempotent and does not add a second frame.

## Manifest

`forref.watch-goal-manifest.v2` records the exact match id, generation, writer device id, journal schema, acknowledged sequence, and the hash of the last acknowledged frame. Sequence zero uses a null hash. The marker is created and read back before a local 0–0. It advances only after a verified append. A missing manifest after recorded frames, a manifest ahead of the journal, or a corrupt manifest is recovery and does not display 0–0. A journal one frame ahead is reconciled only when the pending capture intent, record id, and match id match that frame.

## Tests

`npm test` in `apps/forref_watch_zepp`: 228 tests, 0 failed, exit 0. The new file is `test/reliability_final.test.js`. `./tool/verify_cloud.sh` from the repository root: exit 0.

Clock cadence, the foreground timer, and `paintAll` are unchanged. `paintAll` still does not read the journal.
