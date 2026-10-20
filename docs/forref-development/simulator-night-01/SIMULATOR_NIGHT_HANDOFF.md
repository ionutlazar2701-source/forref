# Simulator Night I handoff

PROGRAM STATUS:
PARTIAL PASS

The research instrument can show a phone, a round watch, and a rectangular watch over one `hf_v2` history, explain frozen commands, and refuse the adversarial cases that were executed. Full pointer replay, a Windows launch, an independent saboteur, and any certification claim are not passed.

EXECUTION BASE SHA:
47fd840b36608f882bc354de67e74d60c57b232b

IMPLEMENTATION SHA:
2dc00f368e1a9590644e751e35797a1075b4fe57

FINAL RESEARCH SHA:
The commit that adds this handoff is the research tip for the documents. A commit cannot contain its own hash. After this file is committed, the branch tip of `cursor/forref-simulator-night-01` is the final research SHA. The session report names that tip.

PRODUCTION AUTHORITY BASELINE:
39a676b25682e2b6930b6d4f7f02340b55ae01a8

PRODUCTION AUTHORITY BEHAVIOR CHANGED:
NO

No edits under `apps/referee_phone/lib`, `packages/forref_match_core/lib`, `packages/forref_match_persistence/lib`, or `packages/match_core`. `tool/verify_cloud.sh` was not modified.

BANK A:
PASS

BANK B:
PASS

BANK C:
PASS

BANK D:
PASS

BANK E:
PASS

BANK F:
PASS

BANK G:
PASS

Bank G passes load, deterministic reset, inspection, and the sequenced trace. Replay is scored on its own line.

BRIDGES:
BRIDGE 1 profile to geometry: PASS
BRIDGE 2 geometry to input safety: PASS
BRIDGE 3 input to hf_v2: PASS
BRIDGE 4 hf_v2 to truth inspector: PASS
BRIDGE 5 hf_v2 to device comparison: PASS
BRIDGE 6 scenarios to trace: PASS

Cross-device pointer replay is not included in bridge 6.

DEVICE PROFILES:
`illustrative-phone-portrait` — illustrative, rectangle, 390x844, raster unknown, physical unknown, touch illustrative supported, crown unsupported. Evidence: PROFILED and SIMULATION READY when the phone layout fits.
`illustrative-round-watch` — illustrative, round, 240x240, raster unknown, physical unknown, touch illustrative supported, crown unknown. SIMULATION READY on the bounded column.
`illustrative-rectangular-watch` — illustrative, rectangle, 192x228, raster unknown, physical unknown, touch illustrative supported, crown unknown. SIMULATION READY on the bounded column.
Pasted schema-1 JSON can add another candidate. A tiny round fixture used in tests is PROFILED and not simulation-ready (`LAYOUT NOT FIT FOR THIS PROFILE`).
No profile is PLATFORM PROVEN. No profile is FORREF CERTIFIED.

CALIBRATION:
FIT: supported. Default. Not a physical measurement.
RASTER_1_TO_1: implemented and unit-tested when raster size and host device-pixel ratio are known and zoom is 1. The lab host evidence stays unknown, so the button shows NOT CALIBRATED.
PHYSICAL_1_TO_1: implemented and unit-tested only with a factual profile, known millimetres, uniform pixel pitch, and host millimetres per logical pixel. The lab does not claim it. Requesting it on a starter shows NOT CALIBRATED and PHYSICAL TARGET SIZE UNKNOWN.

SCENARIOS:
19 core (`s01` through `s19`) and 11 variants. All load through `scenarioFixture`. The inspection rail lists every `ScenarioId`. `scenario_and_bridge_test` loads and resets each one. Widget tests exercised s01, s07, s08, s09, s10, s12, and s16 directly. The other ids were not each clicked in a widget test; their fixtures remain the Session III fixtures.

REPLAY:
PARTIAL

`replaySemanticSteps` drives the instrument and cannot insert a saved record except through `resolveSimulatedCommit`. `replayPointerTrace` accepts only the same profile id and layout policy version 1, and refuses a mismatch without appending. There is no operator button that replays a trace. Replaying a round-watch pointer trace onto the rectangular watch is refused. That cross-device path is HOLD.

TRUTH INSPECTOR:
Reads `ResearchTruthSnapshot` only. Sections: PITCH TRUTH, SIMULATED DIGITAL TRUTH (send-off presence, caution, sending-off, and substitution lines, prior-caution label), UNFINISHED INTENT (team, subject, scope, OUT, IN, pair stage), IN-FLIGHT COMMAND (kind, subject, subject kind, scope, OUT, IN), COMMIT STATE (`commitLabel`), SAFETY STATE (fresh input, armed kind, predecessor, successor, active pointer count), SCENARIO CONTEXT (scenario id, expected digital truth, P0 text). It does not append records.

FINAL-ACTION SAFETY:
hf_v2 `final_action_safety_test.dart` (14 tests) and Session III saboteur file still pass, including Y2 pointer reuse and the in-flight edit attack.
hf_prototype shell: repeat yellow tap does not send off; rebuild keeps the signature; team change invalidates Home 14; shoot-out count does not inherit match cautions; naming OUT and IN does not record a substitution.
hf_prototype adversarial: profile switch, round corner, held subject/scope/pair, unknown outcome, unknown touch, rebuild/comparison, certification spoof, false physical calibration, not-fit, focus loss, direct pathway, similar officials, role order. 21 shell tests passed.

INDEPENDENT SABOTEUR:
NOT AVAILABLE

The adversarial report records the implementer's suite. It is not an independent review.

TESTS:
`cd research/simulator_geometry && dart analyze && dart test` — analyze clean, 20 passed.
`cd research/hf_v2 && dart analyze && dart test` — analyze clean, 61 passed.
`cd research/hf_prototype && flutter analyze && flutter test` — analyze clean, 21 passed.

ANALYZERS:
Those three analyzers reported no issues. Flutter 3.47.2, Dart 3.13.2.

VERIFY_CLOUD:
`./tool/verify_cloud.sh` cannot be executed directly. Both `tool/verify_cloud.sh` and `tool/cloud_bootstrap.sh` are mode 100644 in git, so the kernel returns Permission denied (exit 126 for the first, and the script's bootstrap step fails the same way).

`bash ./tool/verify_cloud.sh` was run. Exit 1. The only failed step is cloud bootstrap, because the script executes `cloud_bootstrap.sh` directly.

The six package steps passed:
analyze `forref_match_core`, no issues; test 347 passed.
analyze `forref_match_persistence`, no issues; test 92 passed.
analyze `apps/referee_phone`, no issues; test 125 passed.

`bash ./tool/cloud_bootstrap.sh` then exited 0 and resolved the workspace. The script file was not changed and was not chmod'd in git.

Research packages are outside that script. Their commands are above.

WINDOWS DESKTOP:
LOCAL GATE REQUIRED

`flutter create --platforms=windows` wrote the runner on Linux. `flutter run -d windows` was not executed. Command: `cd research/hf_prototype && flutter run -d windows`.

SCREENSHOTS:
Captured from the Flutter widget test `capture simulator lab surfaces` at 1280x800 on Linux. DejaVu Sans was loaded as the Roboto family so the glyphs are readable in this environment. The test writes under the system temp directory `forref-sim-visual`. Copies from this run:

`/opt/cursor/artifacts/01-phone-focus.png`
`/opt/cursor/artifacts/02-round-watch-focus.png`
`/opt/cursor/artifacts/03-rectangular-watch-focus.png`
`/opt/cursor/artifacts/04-comparison.png`
`/opt/cursor/artifacts/05-inspection.png`
`/opt/cursor/artifacts/06-y2-send-off-absent.png`
`/opt/cursor/artifacts/07-in-flight-frozen.png`
`/opt/cursor/artifacts/08-save-not-verified.png`
`/opt/cursor/artifacts/09-physical-size-unknown.png`
`/opt/cursor/artifacts/10-layout-not-fit.png`

These are not Windows desktop captures. The device header is capped so the stage keeps height; Touch and Safe area can sit at the bottom of that scroll. Calibration, physical fidelity, target size, evidence, platform, and certification were readable on the phone focus capture.

HUMAN VALIDATION:
NOT RUN

WATCH HARDWARE:
NOT TESTED

PRODUCTION D1:
NOT TESTED BY SIMULATOR

PHONE AUTHORITY CUTOVER:
HOLD

PRODUCTION ENGINEERING:
NOT AUTHORIZED

OPEN RISKS:
The Windows runner has not been compiled or launched.
Host display evidence is always unknown in the lab, so raster and physical 1:1 cannot be shown as honored.
Starter touch `supported` is an illustrative assumption. It is not a measured panel.
Watch rectangles are a bounded research column, not a specified native watch UI.
The roster is not a hit target on that column.
There is no in-app replay control. Cross-device pointer replay stays refused.
The visual test uses a Linux DejaVu path when that file exists. Without it, capture still runs and the test font may draw boxes. The test does not fail closed on a missing font.
`verify_cloud.sh` fails its bootstrap step until the script is invoked through bash, because the committed mode is 644. The file was left unchanged.
No independent reviewer ran.
No human timing, error rate, or referee study was collected.
Cloud widget tests are not phone, watch, wet-screen, battery, or process-death evidence.

NEXT SAFE WINDOW:
On a Windows machine, run `cd research/hf_prototype && flutter run -d windows` and walk the founder diagnostic ids in Focus and Inspection. Do not start phone authority cutover. Do not add a pointer replay that maps one profile's coordinates onto another. A later window can add an operator control that calls `replaySemanticSteps` only.

CHANGED FILES:
`research/simulator_geometry/**` (package, profiles, geometry, layout, tests).
`research/hf_v2/**` (snapshot, replay, sequenced log, instrument notes, tests).
`research/hf_prototype/**` (Simulator Lab shell, adversarial and visual tests, Windows runner scaffolding).
`docs/forref-development/simulator-night-01/**`.

UNVERIFIED CLAIMS:
Windows launch, native watch fidelity, physical calibration on a real display, production D1, human performance, and certification. None of those are claimed as passed.
