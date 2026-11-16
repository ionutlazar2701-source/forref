# PHONE MATCH REPORT UI 002

Task file: `TASK_CURSOR_MR_002_PHONE_MATCH_REPORT.md` (Drive `11MljxWOswboViXgVWAuNilRufysLwmKM`).
SHA-256 of the downloaded file bytes: `5562b286be498ad08403ed923ea534375a7ce55cae9de8420ed27a402be04c5c` (match).
Baseline: PR #46 `00587741abceb4bf5900e97c0a034aede8cf46c4` on `cursor/match-report-bridge-001-30fd`. Local and origin matched that SHA before this branch was created.

## Verdict

- IMPLEMENTATION: PASS
- AUTHORITY MODE ROUTING: PASS
- UI VISIBLE: PASS as Flutter widget captures of the real route. No phone emulator or device was available on this cloud VM, so these are not device screenshots.
- RO/EN: PASS
- RESTART SAME SQLITE FILE: PASS
- MR02-01 through MR02-14: PASS

No persisted per-match authority selector exists. The phone classifies a match from the generation-one root and the committed-row count. That does not change a frozen Match Core contract. Unknown stays unknown. A root with no committed records does not open an empty successful report.

## Route

`/match-report` takes the match id as the route argument. The screen calls `MatchApplicationBoundary.readMatchReport()` only after the read path is Match Memory and the local match row supplies the home and away team ids. Those names are presentation labels. The screen says they are labels only.

| Evidence | Route |
| --- | --- |
| Generation-one root and at least one readable committed record, no legacy sporting history | Match Report |
| No root and no committed records, legacy row present | Legacy Summary for a completed match |
| Root and records plus a legacy event or a non-zero legacy score | Fail closed: ambiguous |
| Committed records without a generation-one root | Fail closed: ambiguous |
| Root and zero committed records | Fail closed: unknown |
| Quarantine or a row that will not decode | Fail closed: unreadable |
| Read throws | Fail closed: could not be loaded, with Retry |

Legacy sporting history means a legacy event or a non-zero legacy score. A fresh 0–0 row is not sporting history. `matchApplication != null` is not treated as Match Memory.

## Navigation trace

Before this branch, a completed match always opened `/summary`. The live page exposed Summary at full time. There was no Match Report route.

After this branch:

- Every match row has a Match report button that pushes `/match-report`.
- The live page has a Match report button that pushes `/match-report`.
- A completed legacy-only match still opens `/summary` from the row.
- A completed Match Memory match opens `/match-report` from the row.
- Ambiguous, unknown, and unreadable matches open the fail-closed report state, not Summary.
- The report has Back and Refresh. It does not call `saveEvent`, `finish`, or a commit.

## Widget captures

Source: `apps/referee_phone/test/match_report_ui_test.dart`.
Each PNG is `OffsetLayer.toImage` of the running widget after real SQLite commits. DejaVu Sans is loaded as the Roboto family so the glyphs are readable. Flutter's test font is not used for these captures. They are not emulator screenshots.

| File | What it shows |
| --- | --- |
| `mr02-known-score-en.png` | Kick-off, goal, yellow. Score `HOME 1 — 0 AWAY`. Every line says Time unavailable. |
| `mr02-score-unavailable-en.png` | Goal for a team outside the two setup ids. Score unavailable. No 0–0. |
| `mr02-two-yellows-en.png` | Two yellows and the sentence that they are not a send-off. |
| `mr02-second-caution-unavailable-en.png` | Second caution whose yellow records are missing. |
| `mr02-conflict-en.png` | Competing goal corrections. Score conflict. Goal: Conflict. No chosen score. |
| `mr02-unsupported-en.png` | Structured payload `{event: goal, minute: 12}` shown as unsupported, not as a goal. |
| `mr02-unreadable-en.png` | Quarantined SQLite row. No legacy summary and no score. |
| `mr02-unknown-en.png` | Generation-one root and no committed records. |
| `mr02-empty-readable-en.png` | Root plus a committed referee-entered record. Proven 0–0 and no report lines. |
| `mr02-legacy-summary-en.png` | Legacy completed match still on Summary, including its legacy clock. |
| `mr02-legacy-only-en.png` | Match report button on that match stays off the blank report. |
| `mr02-ambiguous-en.png` | Legacy event and Match Memory goal. Authority ambiguous. |
| `mr02-ro-narrow.png` | Romanian, 320×640. Long team names wrap. |

## MR02 results

| Id | Result |
| --- | --- |
| MR02-01 | PASS. List button and live button open `/match-report`. |
| MR02-02 | PASS. Kick-off, goal, and yellow appear in commit order. |
| MR02-03 | PASS. Outside-team goal stays a line. Score unavailable. No 0–0. |
| MR02-04 | PASS. Home goal with the existing proof shows `HOME 1 — 0 AWAY`. |
| MR02-05 | PASS. Every line says Time unavailable. No `00:00` and no `recordedAt`. |
| MR02-06 | PASS. Two yellows do not show a red or a send-off. A second-caution record with missing yellows shows dependency unavailable. |
| MR02-07 | PASS. Competing corrections show Score conflict and Goal: Conflict. The unsupported payload shows its record id and no goal line. |
| MR02-08 | PASS. A corrupted row shows "Match report cannot be read". Legacy events stay put. |
| MR02-09 | PASS. `abortBeforeCommitForTest` leaves no yellow line and no Saved text. |
| MR02-10 | PASS. Close and reopen the same `match_memory.sqlite`. The visible texts match. |
| MR02-11 | PASS. Legacy completed match opens Summary. Mixed legacy event plus Match Memory fails closed. Neither history is rewritten. |
| MR02-12 | PASS. Romanian long labels at 320×640, semantics label, refresh adds the second yellow, back returns to Meciuri. |
| MR02-13 | PASS. Opening the report does not change live status, committed count, or `matchNormallyEnded`. No Finish control. |
| MR02-14 | PASS. Diff stays in the phone shell, localization, and this evidence folder. No Zepp, Match Core semantics, LOTG schema, sensor API, or True Black edit. |

Phone widget suite for this slice: 15 tests, all passed (`flutter test test/match_report_ui_test.dart`).

## Untested

- A running phone emulator or a physical device. This VM has no Flutter device target.
- PDF or export. Out of scope.
- LOTG reason text. Out of scope.
- Zepp cutover. Out of scope.

## Cloud verification

Command: `./tool/verify_cloud.sh` from the repository root.
Exit: 0.

| Suite | Result |
| --- | --- |
| cloud bootstrap | PASS |
| analyze `packages/forref_match_core` | PASS |
| test `packages/forref_match_core` | PASS, 383 |
| analyze `packages/forref_match_persistence` | PASS |
| test `packages/forref_match_persistence` | PASS, 92 |
| analyze `apps/referee_phone` | PASS |
| test `apps/referee_phone` | PASS, 143 |

An earlier run of the same command exited 1 because `flutter analyze` reported an unused import and an unused local in the new widget test. Those two diagnostics were removed. The run above is the one after that fix.

Two taps in the widget log warn that a Match report button center sits outside the 800×600 root (`MR02-10` at x=-116, `MR02-13` on the live page). The assertions still passed, including the reopened score line and the live-match report. The warnings are not failures.

Toolchain: Dart 3.13.2, Flutter 3.47.2. SQLite journal and synchronous settings were not changed.
