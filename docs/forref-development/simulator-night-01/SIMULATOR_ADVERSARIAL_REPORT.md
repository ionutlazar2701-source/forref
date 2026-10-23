# Simulator Night I adversarial report

This suite was run by the implementer. It is not an independent saboteur review.

INDEPENDENT SABOTEUR NOT AVAILABLE.

Commands that passed on Linux, Flutter 3.47.2 / Dart 3.13.2:

```bash
(cd research/hf_v2 && dart test)
(cd research/simulator_geometry && dart test)
(cd research/hf_prototype && flutter test)
```

Results: hf_v2 61 passed, simulator_geometry 20 passed, hf_prototype 21 passed. No scenario expectation was edited to hide a failure.

Session III attacks in `research/hf_v2/test/adversarial/session_iii_saboteur_attack_test.dart` and `final_action_safety_test.dart` still pass, including the in-flight freeze.

## Cases

### A. Y2 does not carry into SEND_OFF

Reproduction: `s07RapidRepeatAfterY2`, show yellow, tap Record yellow.

Expected: two research cautions, no sending-off, fresh input required for a later sending-off.

Observed: shell test `a repeat tap on yellow does not record a sending-off` finds `Two cautions recorded`, does not find `Sending-off recorded`, and a second tap on the yellow rect leaves `sendOffs` empty. `final_action_safety_test.dart` cases A through E agree. Severity if regressed: P0. Not observed.

### B. Old-position repeat tap

The same shell test taps the yellow rect again after the continuation target exists. The second tap does not append a sending-off. `final_action_safety_test` case E taps the old yellow location. Observed: no sending-off.

### C. Profile switch mid-gesture

Reproduction: widget test `C profile switch cancels an open pointer`. Pointer down on Record yellow, then tap Round watch, then release.

Expected: no final action from the stale pointer.

Observed: cautions stay empty. `cancelOpenInputForDeviceChange` logs the cancellation. `truth_snapshot_test` `device change cancels an open pointer and writes nothing` covers the instrument.

### D. Scale and clipping

Reproduction: widget test `D a round-watch corner does not activate a target`, plus geometry test `round clipping and safe area reject the bounding-box corner`.

Expected: a point in the square corner, outside the disc or the safe inset, arms nothing.

Observed: no caution. The geometry test rejects the corner. The painted-target test checks the phone yellow rect against the same transform used to place it.

### E. In-flight subject

Reproduction: widget test `E F G held resolution keeps the frozen command`, with Hold simulated resolution. Activate yellow on Home 14 (`s09Home14ThenAway14`), then Away.

Expected: frozen subject remains Home 14.

Observed: in-flight snapshot subject stays `p-home-14` and cautions stay empty until resolve. `truth_snapshot_test` and the Session III cross-bank test agree.

### F. In-flight scope

Same held test. Activate a match-scoped yellow, then Shoot-out scope.

Expected: frozen scope stays match.

Observed: in-flight scope stays `match`. Unfinished scope can change. No record until resolve, and resolve uses the frozen command.

### G. In-flight substitution

Same held test. OUT `p-home-9`, IN `p-home-7`, activate Record substitution, then change IN to `p-home-14`.

Expected: frozen pair stays 9 to 7.

Observed: in-flight OUT/IN stay `p-home-9` and `p-home-7`. Substitutions stay empty until resolve.

### H. Unknown outcome

Reproduction: `s16SaveNotVerified`, tap Record yellow.

Expected: `SAVE NOT VERIFIED — outcome is not known`. Not saved, and not a known failure. No appended caution.

Observed: widget test `H` and `truth_snapshot_test` `unknown outcome is neither saved nor a known failure`. The instrument refuses a blind resubmit while the outcome is unverified (`blind-resubmit-refused`). The UI does not present that resubmit as safe; Acknowledge unknown does not submit.

### I. No-touch profile

Reproduction: import a profile whose touchscreen capability is `unknown`, tap Record yellow.

Expected: no silent touch. The capability stays unknown.

Observed: widget test `I` appends nothing until the explicit switch `SIMULATED TOUCH OVERRIDE — not a device capability` is on. A second tap with the override can append, and the profile capability remains `unknown`. Profile test `a no-touch profile can say touch is unsupported or unknown` covers both statuses. The override control is hidden when the profile already claims touch supported.

### J. Rebuild and comparison

Reproduction: rebuild the app, enter Inspection, Compare devices, resize to 1100x700.

Expected: no record from rendering.

Observed: widget test `J`. Caution count unchanged, sending-offs empty, one ACTIVE, READ ONLY present.

### K. Multitouch and focus

Reproduction: pointer down on Record yellow, `focusLost`, pointer up.

Expected: no caution.

Observed: widget test `K L M N` and `final_action_safety_test` cases F and G. Focus loss clears the open pointer and does not activate.

### L. Direct red with a prior yellow

Reproduction: `s08DirectRedWithPriorYellow`, Record sending-off.

Expected: pathway stays DIRECT. The prior yellow is not rewritten as a second-caution sending-off.

Observed: `sendOffs.single.pathway` is `direct`. Caution count stays 1. Snapshot test `unavailable history and direct pathway stay distinct` covers the label split.

### M. Similar officials

Reproduction: `s10SimilarOfficials`.

Expected: two stable ids. No auto-selection from a similar name.

Observed: both Alex Popescu labels are present, `selectedOfficialId` is null until the team-doctor control is tapped, then `o-alex-doctor`.

### N. Substitution roles

Reproduction: `s12SubstitutionInFirst`. Select IN then OUT. Reorder the roster.

Expected: roles stay OUT 9 and IN 7. No saved substitution from the pair alone.

Observed: `outId` `p-home-9`, `inId` `p-home-7`, `substitutionRecorded` false. `scenario_and_bridge_test` `roster reorder does not reverse substitution roles` agrees. The shell test `naming OUT and IN does not record the substitution` agrees.

### O. Certification spoof

Reproduction: paste illustrative JSON that adds `forrefCertified: true`.

Expected: rejection. Active profile unchanged. No certification claim on screen.

Observed: widget test `O`. `importAccepted` is false. Screen text is `Certification: not claimed`. `FORREF CERTIFIED` is absent. Profile test `a profile cannot self-assign certification or host calibration` covers the parser.

### P. False physical calibration

Reproduction: Request physical 1:1 on the illustrative phone, whose physical size is unknown and whose host evidence is unknown.

Expected: `Calibration: NOT CALIBRATED`, `Physical fidelity: NOT CALIBRATED`, `PHYSICAL TARGET SIZE UNKNOWN`. The label `Calibration: PHYSICAL_1_TO_1` is absent.

Observed: widget test `P` and geometry test `invalid zoom and unproven calibration stay uncalibrated`. A separate unit fixture with a factual profile, known millimetres, and host millimetres per logical pixel does honor `PHYSICAL_1_TO_1`. The lab does not supply that host evidence.

## Not claimed

No wet-screen, battery, process-death, physical D1, native crown, or watch-hardware attack was run. Those remain untested.
