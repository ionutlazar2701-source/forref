# EVREC-NIGHT-001R

Software corrections on draft PR #82. Parent `e352ecd1b481b7d439b9fd177cf99f98bd08ce37`. Official Match Records stay closed. `authoritativeCaptureAdmitted` stays false. D1 stays uncertified. No hardware pass.

## Before

`node --test test/reliability_001r.test.js` in `apps/forref_watch_zepp`, against that parent, exited 1. Six tests failed. The log is `001R_BEFORE.txt`.

- An interrupted third `writeFileSync` replaced the file. The two accepted frames were no longer the prefix (`false !== true`).
- A goal whose `matchId` was another match still scored `home: 1`.
- `paintAll` called `goalPreview` on the clock tick.
- The live page had no `localTestPresentation`, so numerals did not depend on the warning fitting.
- Live and review copied `localInstallationId` from `context.writerDeviceId`.
- The confirm screen minted `goal-` plus `Date.now()` whenever volatile state was empty.

## After

The same file, plus the recreation, cross-match, admission, and score-cache tests, is in the watch suite.

- `npm test` in `apps/forref_watch_zepp`: 219 tests, 0 failed, exit 0.
- `./tool/verify_cloud.sh` from the repository root: exit 0. Match core, persistence, and the phone app passed. That script does not run the watch suite.

A fresh UI object with an empty `goalIntentId` recovers the pending `captureIntentId` and does not allocate another. A failed append that leaves the journal empty retries that same id once the store accepts writes, and the journal then holds one goal. A pending id whose frame is already present is idempotent after a new journal object is created.

A legacy `forref_watch_goal_journal_v1.journal` that belongs to one match stays on that path. Another match writes `forref_watch_goal_journal_v1.<matchId>.journal`. The legacy bytes are unchanged. Scoring the other match's entries against the first match returns no numeral.

`admitLocalGoal` reads the installation file and the provision root. A goal-context JSON writer id is not copied. A missing installation beside an existing root is `missing-installation` and does not mint a replacement. `authoritativeCaptureAdmitted` and `captureStorageCertified` stay false.

The file store appends one frame with `O_WRONLY | O_CREAT | O_APPEND`. It does not call `writeFileSync`. A short third append leaves the two accepted frames in place and blocks the next append.

`paintAll` reads the published score. The journal is loaded from `restoreScore` on page build and again when a confirm finishes. Five paints after one publish do not reload. If `LOCAL TEST` does not fit, the buttons do not show numerals.

## Still open

No Bip 6 run. No `.zab`. The Side Service still does not deliver the four provision messages to a device. `HARDWARE GATE PENDING`.
