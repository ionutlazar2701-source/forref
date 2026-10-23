# S2.3.5 handoff — John design integration

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.3.5
STATUS: PASS as desktop research presentation

INPUT SHA: `25a7320` (verified S2.3 tip)
CODE TIP: `334851b6fa626b7b7e1be0172cbc9dfa51c982e7`

Local commits on `cursor/forref-simulator-v2-john-design`, oldest first:

| SHA | Message |
| --- | --- |
| `3265d0d17ae4ee7484f237389b73e4e2340082af` | refactor(sim): establish John V1 lab workspace shell |
| `18e6112f07b39038410000423e46026df8e719df` | test(sim): migrate lab tests to the John V1 workspaces |
| `296cda35b7c2716561e0f93bc6db30dad2ca9a50` | fix(sim): refine John V1 lab presentation details |
| `334851b6fa626b7b7e1be0172cbc9dfa51c982e7` | test(sim): add John design integration and responsive gates |

The docs commit for this handoff follows the code tip; its SHA is in
`git log`, not predicted here.

The brief suggested six commits split by bank. The lab scaffold imports
every workspace, so the shell, selector, focus, command, compare, inspector,
and placeholder landed in one compiling commit (`3265d0d`) instead of four.
Test migration, presentation fixes, new gates, and docs are separate.

PRODUCTION AUTHORITY MODIFIED: NO

`git diff 25a7320 -- packages apps` is empty. `apps/referee_phone/lib/**`,
`packages/forref_match_core/lib/**`, `packages/forref_match_persistence/lib/**`,
and `packages/match_core/**` are untouched. No SQLite durability setting was
changed. `tool/verify_cloud.sh` and `tool/cloud_bootstrap.sh` were not changed.

## Banks

| Bank | Result |
| --- | --- |
| A Shell, workspaces, inspector closed by default | PASS |
| B Device Selector from `DeviceProfileV2` facts | PASS |
| C Focus hero stage | PASS |
| D Command Lab rail, geometry stage as ADVANCED | PASS |
| E Compare, one input owner | PASS |
| F Inspector: Truth, causal Event Journal, Device Evidence | PASS |
| G Match Builder placeholder | PASS as placeholder, writes nothing |
| H Responsive regimes, resize cancels held input | PASS at 1600 / 1440 / 1280 / 1100 / 900 / 760 |

## Bridges

| Bridge | Result |
| --- | --- |
| Watch aperture tap → runtime → `hf_v2` | PASS, `ACTUAL WATCH UI INTERACTION` |
| Rail action → runtime → same instrument | PASS, `OPERATOR FIXTURE ACTION` |
| Snapshot → Truth inspector | PASS |
| `JournalEntry` → causal stages | PASS, `NOT OBSERVED` when absent |
| `DeviceProfileV2` → selector, footer, evidence | PASS, unknown stays unknown |
| Compare owner switch → `inputEpoch` guard | PASS |
| Regime change → epochs and `focusLost()` | PASS |
| Research watch input → SQLite D1 | NOT BUILT. NOT CLAIMED. |

Detail: `S2_3_5_JOHN_DESIGN_INTEGRATION.md`.

## Tests

Each package suite was run separately from its own directory.

| Package | Command | Result |
| --- | --- | --- |
| `research/simulator_geometry` | `dart test` | 37 passed |
| `research/simulator_presentation` | `dart test` | 3 passed |
| `research/hf_v2` | `dart test` | 61 passed |
| `research/simulator_hf_bridge` | `dart test` | 9 passed |
| `research/watch_reference_ui` | `flutter test` | 3 passed |
| `research/simulator_sandbox` | `dart test` | 7 passed |
| `research/hf_prototype` | `flutter analyze` | No issues found |
| `research/hf_prototype` | `flutter test` | 58 passed |

`hf_prototype` detail: 23 new tests in `john_design_test.dart` (default
launch, workspace navigation, device selector, compare ownership, watch
Yellow safety, Y2 repeat, regime change during a press, focus loss, event
journal causality, sandbox distinction, device evidence, match builder,
responsive matrix, narrow dropdown), 1 capture test in
`john_visual_test.dart`, and the 34 pre-existing tests migrated to the new
workspaces. No old test was deleted. Assertions that referenced removed
surfaces were replaced with equally strong assertions on the surface that
replaced them: the geometry stage is opened explicitly through
`openGeometryStage()`, operator actions are found in the Command Lab rail,
and truth text is found in the Truth inspector.

### verify_cloud

`bash ./tool/verify_cloud.sh` from the repository root exited **1**.

- `cloud bootstrap`: FAIL — `tool/cloud_bootstrap.sh` is committed mode
  `100644` and the step was `Permission denied`. Same pre-existing condition
  recorded in `MASTER_HANDOFF.md`.
- `analyze packages/forref_match_core`: PASS. `test`: 347 passed.
- `analyze packages/forref_match_persistence`: PASS. `test`: 92 passed.
- `analyze apps/referee_phone`: PASS. `test`: 125 passed.

This is not a PASS of the aggregate command. The scripts were not modified
to make this wave look green.

## Visual evidence

`01-john-focus.png` … `10-john-watch-yellow.png` plus `11-john-compact-900.png`
and `12-john-narrow-760.png`, with `john-evidence-manifest.json`, under
`$TMP/forref-sim-v2/` and `/opt/cursor/artifacts/`. Stamps carry the SHA of
HEAD at capture time (`334851b`), workspace, profileId, runtime, scenario,
and fidelity. Linux widget-test captures at 1440 × 900. Not Windows evidence.

## Holds and gates

WINDOWS LOCAL GATE REQUIRED. Not run in this session. From the repository
root on Windows with Flutter 3.47.2:

```
cd research\hf_prototype
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

PHONE AUTHORITY CUTOVER: HOLD

NATIVE WATCH CLIENT: NOT AUTHORIZED

HARDWARE CERTIFICATION: NOT AUTHORIZED

PLATFORM PROOF: NOT CLAIMED. Only `PROFILED` is displayed.

INDEPENDENT SABOTEUR NOT AVAILABLE

HUMAN VALIDATION: NOT RUN

WATCH HARDWARE: NOT TESTED

REMOTE GIT: no push, no PR, no merge. Local commits only, per the wave brief.

## Open risks

- Seed apertures remain schematic; safe areas and apertures are unknown for
  every profile. The lab says so on every stage.
- The watch canvas is laid out at on-screen aperture size. Small compact
  windows fail closed with `LAYOUT NOT FIT FOR THIS PROFILE` instead of
  scaling the reference UI.
- The round Huawei aperture clips the rectangular reference UI at the
  corners. The reference UI has no round-safe layout.
- Sandbox evidence in the Event Journal comes from `capture_report.dart`
  because SQLite does not complete inside the Flutter widget-test binding.
- Icon glyphs render as boxes in Linux captures; the Material icon font is
  not loaded in the test binding.

## Next safe wave

S2.4 Complete Synthetic Match Builder: MATCH / TEAMS & SQUADS / OFFICIALS &
CREW / FORMAT / REVIEW producing a synthetic, non-authoritative research
fixture for the lab, with phone shells. Phone authority cutover stays HOLD.
