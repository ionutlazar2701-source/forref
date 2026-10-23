# S2.4 — Paired Simulation Foundation

PROGRAM: FORREF SIMULATOR LAB  
BASE: `33c18bb26066ce56128650d7d8f7ac769ffc243d` (S2.3.5)

## Intent

The lab presents **Mobile Session + conceptual pair link + Watch Session** over one
`ResearchController`, one `ResearchInstrument`, and one `HfPresentationRuntime`.
This is deterministic product simulation, not production phone/watch sync.

## Paired session model

- `ResearchFixture` — non-authoritative bootstrap (match name, teams, scenario, profiles).
- `PairedSessionState` — connection label, last origin, propagation note.
- `SimulatedActionOrigin` — `MOBILE UI`, `WATCH UI`, `OPERATOR FIXTURE`, `SANDBOX TOOL`, `SYSTEM SCENARIO`.

Watch intents may use `IntentOrigin.mobileUi` (trace label `MOBILE UI ACTION`).

## Commit labels (frozen)

Research: `SIMULATED SAVED — not production D1`, etc.  
Sandbox: `SANDBOX D1 COMMITTED` only after durable readback.

## Assets

Intake folder (Google Drive) is not loaded at runtime.  
Repository path: `research/hf_prototype/assets/sim_lab/`.  
Missing files: **ASSET NOT AVAILABLE** — schematic shells remain.

## Windows test harness

- `generateCaptureReport()` in `simulator_sandbox` replaces `dart run bin/capture_report.dart` in tests.
- Widget tests use frozen `test/fixtures/sandbox_capture_report.json`.
- Live capture: `test/capture_report_regression_test.dart`.

## Deferred bridges

Watch → production D1, phone ↔ watch transport, MATCH READY cutover — **HOLD**.
