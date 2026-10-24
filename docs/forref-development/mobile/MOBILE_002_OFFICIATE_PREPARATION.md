# MOBILE 002 — Officiate preparation

Phone product shell for Matches and one Preparation workspace. Live Match is the existing screen.

Branch: `cursor/forref-mobile-002-officiate-preparation`

Start commit: `9cd76ec9e431263fae6ad1b218bd61d435f6ed66` (MOBILE 001, PR #29). No later commits were on that branch. The watch-banks branch was not merged.

Final commit: filled in after the implementation commit is created.

## Scope that shipped

- Matches is the officiating entry. It lists fixtures in this order: current, upcoming, needs attention, not started, completed.
- Current means an authoritative Match Memory start that has not normally ended, or a legacy in-progress status (`live`, `paused`, `halfTime`, `fullTime`). A scheduled date, a `ready` status, or the last opened row does not make a match current.
- Completed means legacy `completed` or an authoritative normal end. Full time stays current.
- Incomplete names stay "Home team not set" / "Away team not set". The list does not invent HOME/AWAY as a fixture name.
- Preparation is one screen: Match, Teams, Crew, Readiness, then Enter Live Match. It is not a wizard.
- Team names and a positive half length are required for that entry. Competition, venue, crew names, and squad names are optional and do not block.
- Readiness is derived by `assessPreparation`. It is not stored. "Ready to officiate on this phone" requires a complete identity, local storage, a known capture identity, and temporal evidence. Without temporal evidence the label stays "Match setup ready". Without a known capture identity the label is "Recording authority unconfirmed" and Live Match stays closed.
- Preparation text is written back onto the existing match aggregate and restored on the next open.
- Enter Live Match still calls the existing `goReady` and opens the existing Live Match for that match id. Kick-off and Goal stay on the MOBILE 001 command path.
- Settings remains a secondary language screen. There is no Training destination and no Devices destination.

## Scope that did not ship

Training, watch pairing, watch readiness, authority transfer, replication, a match-report product, roster or club management, and any new sporting command. Yellow, both send-offs, substitution, full time, and finish match stay fail-closed in the command catalog.

`DevicesPage` remains in the tree and is not routed. The companion model is unchanged and is not shown as product functionality.

## Boundaries

Preparation edits the existing local match document through `MatchSession.replace`. That document is setup data. The new path does not append Match Records and does not call the legacy kick-off writer.

Match list classification reads Match Memory through the existing projection port. A failed or missing read is not treated as a start.

No package under `packages/forref_match_core`, `packages/forref_match_persistence`, or `packages/match_core` changes in this wave.

## Founder review

From the repository root, the phone app is `apps/referee_phone`. A local run uses `flutter run` inside that directory. The first screen is Matches. New Match opens Preparation. Enter Live Match stays disabled until both team names are set. Restarting the app reloads those names from the local database. No account and no watch are required.

Reset a local install by clearing the application support directory for the app, or by uninstalling it. Tests use an in-memory database and do not need that reset.

## Tests

`./tool/verify_cloud.sh` from the repository root, after the last product change:

- `tool/cloud_bootstrap.sh`: Permission denied. The script is mode `644` and was not modified. This is the only failed step.
- `packages/forref_match_core`: analyze clean, 347 tests passed.
- `packages/forref_match_persistence`: analyze clean, 92 tests passed.
- `apps/referee_phone`: analyze clean, 170 tests passed.

`flutter build apk --debug` in `apps/referee_phone` stops with `No Android SDK found` (`ANDROID_HOME` unset). No Android or iOS device run is claimed.

## Known limits

The phone does not yet offer a separate post-match record product beyond the existing summary screen for a completed fixture. Legacy non-goal capture on Live Match is unchanged. "Ready to officiate on this phone" means the wired phone operating profile (local store, known capture identity, temporal-evidence store), not a watch check and not a stored ready flag.
