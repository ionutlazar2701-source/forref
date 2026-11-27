# Architecture decisions — EVREC-NIGHT-001

Base commit: `167f108b3871c8496dd55acca6f351b07a2a4e4c` (PR #81, EVREC-A1R). PR #81 was not rebased.

## Authority

Preparation of `CONFIG_PREPARED` checks committed sporting history and an existing generation-1 root inside the same `BEGIN IMMEDIATE` transaction as the insert. A matching canonical document is idempotent. A different document does not overwrite the stored row.

After a watch-provision stage exists, `commitGenerationOneAuthorityRoot` refuses to insert a phone or forged watch root. The lock transaction remains the only root insert for a reserved match.

`authorityActivated` is true only for `WATCH_ACTIVATED`. `captureStorageCertified` stays false. `authoritativeCaptureAdmitted` stays false. `mayAppendSportingRecords` follows that last flag, so activation is not permission to append a Match Record.

Cancellation deletes only a `CONFIG_PREPARED` row whose match id and content hash match, and only when no root and no sporting rows exist. It does not create a phone root. After `PHONE_AUTHORITY_LOCKED` it refuses.

## Local goal

A goal may be appended to the watch journal when authority is activated. That append is not an authoritative Match Record and is not Saved. The success text is `LOCAL RECORD VERIFIED — D1 UNCERTIFIED`. `saved`, `d1Certified`, and `authoritativeCaptureAdmitted` stay false.

The envelope uses the existing Dart meaning: semantic type `GOAL`, record kind `humanDetermination`, scope `MAIN_REFEREE`, generation 1, `scoringTeamId` as `MatchTeamId`, and `CaptureIntentKey(matchId, MAIN_REFEREE, captureIntentId)`. HOME and AWAY remain display tokens. The journal file is `forref_watch_goal_journal_v1.journal`, separate from `forref_capture_bridge_001`.

The origin sequence is inside the framed entry. There is no side counter. SHA-256 covers the canonical entry bytes only. It does not authenticate the watch and it does not prove D1.

An uncertain append keeps the capture intent. A later read that finds that exact entry reuses it. A healthy absence allows the same intent again. A second deliberate goal uses a new intent. Corruption blocks further appends and is not rewritten.

## Score

The numerals on the existing HOME and AWAY buttons are rebuilt from verified goal entries. An empty healthy activated journal is local-test 0–0. That object sets `knownScore` to false. Unknown history keeps `HOME · NO SCORE` / `AWAY · NO SCORE`. Conflict and incomplete history do not show a number. The Dart projector is unchanged and remains the only KnownScore path.

`LOCAL TEST` is drawn in the existing detail slot under the clock when the line fits. If it does not fit, the page logs `FORREF_SCORE outcome=visual-pending reason=no-slot` and does not paint a control over the buttons. Clock cadence, CHRON-004, and CLOCK-006 were not modified.

## Transport

The four message names are `GET_WATCH_PROVISION_V1`, `WATCH_PROVISION_VERIFIED_V1`, `ACTIVATE_WATCH_V1`, and `WATCH_ACTIVATED_V1`. A verified receipt requires `readBack: true`. An activation response without `durable: true` is not completion. The installation UUID is generated once into its own file and is not derived from a device name or address. A failed read does not mint a replacement.

This is a message codec and a file adapter exercised in process. No Side Service, Bluetooth socket, or cloud relay was added. A write that does not read back is unverified.

The live score reads `forref_watch_goal_context_v1.json`. The activation handler writes that file only after `WATCH_ACTIVATED`. No page currently receives the four messages from a phone process, so a device still has no path that creates the file.

## Cards and substitutions

No Yellow, Send-off, Substitution, or Injury writer was enabled. The missing contracts are in `N5_GAP_MATRIX.md`.
