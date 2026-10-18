# live_core_a — Central Instrument A trial harness (research)

Standalone pure-Dart instrumentation for **protocol completeness** measurement in future Central Instrument A referee studies. This package is **not** production match capture, does **not** write Match Memory, and is **not** part of the root workspace `pubspec.yaml`.

## Status

- **No human participants were tested** using this harness in this repository state.
- **Release thresholds: UNREGISTERED** (`InstrumentAThresholds.registration`).
- **002D Recall instrument: HOLD** — not present in this repo; cautions trials set `recallInstrument = unavailable` and are **not** `formal002dScorable`.

Central Instrument A is a **validation baseline** for TIME+PHASE and SCORE as zero-navigation facts and CAPTURE and CAUTIONS as one-contact destinations. This package does not implement UI screens (visual design remains an open decision).

## Usage

```bash
cd research/live_core_a
dart pub get
dart test
```

## Scope

- Counterbalanced trial order from an integer seed (deterministic).
- Telemetry event names and per-trial completeness verdicts.
- JSON export when the caller supplies a directory (tests use a temp dir).
- Score grading pure function with team attribution checks.

## Non-goals

- No claims about referee performance or field trials.
- No `Saved` / D1 acknowledgements or match database filenames.
- No dependency on `forref_match_core`, `match_core`, Flutter, or Firebase.
