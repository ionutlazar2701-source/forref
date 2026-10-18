# a_physical — watch hit-region geometry (research)

Pure-Dart instrumentation under `research/a_physical/`. It checks whether **declared** Central Instrument hit regions are internally consistent. It does **not** certify touch accuracy, wake behavior, rain resistance, battery life, or Always On display behavior.

## Central Instrument regions

Required region ids (one rectangle each, unique id):

- `timePhase`
- `score`
- `capture`
- `cautions`

## Checker outcomes

| Result | Meaning |
| --- | --- |
| `deviceMatrixRequired` | No operator-supplied measured profiles (default for the uncertified candidate catalog). |
| `geometryInconsistent` | Overlap, duplicate id, missing required region, gap violation, or negative / violated edge clearance. |
| `readyForPhysicalGate` | Operator-measured profile with all four regions, positive `interRegionGap`, non-negative `edgeClearance`, and consistent layout. **Not** hardware approval. |

There is **no** `PHYSICAL_PASS`, `CERTIFIED`, or `hardwareApproved` outcome.

## Uncertified candidates

`uncertifiedWatchCandidates()` lists four rental targets from `docs/hardware-test-matrix.md` with `WatchProfileStatus.uncertifiedCandidate` only. Geometry fields stay null or empty where unknown. `checkCandidateCatalog()` always returns `deviceMatrixRequired`.

## Cloud vs local gates

Cloud CI can run `dart test` and `dart analyze` here. **LOCAL GATE REQUIRED** for on-wrist measurement, human-factors validation, and reliability testing. This package refuses to emit a physical-pass verdict.

## Run

```bash
cd research/a_physical
dart pub get
dart analyze
dart test
```

Use `fvm dart` when the repo pin requires it.
