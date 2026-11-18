# SENS V2 evidence matrix

Task file `1_NUT2I5Lb2SyMuOD_rGf0hXywKTwSnn5` downloaded as `FORREF_SENS_V2_NATIVE_RUNNING_REBUILD.md`. The Drive tool returns base64, and this workspace did not persist those exact bytes before hashing, so this record does not claim a match to `5c22d2a8e6c200617cbc172eca5cb070de084fb61c8adfc99aa2965d103e4f52`. The decoded text is the SENS V2 brief used for this rebuild.

Diagnostic build: app id `30101`, version code `2`, version name `2.0.0`, label `SENS V2`.
Branch: `cursor/zepp-sens-001-30fd`. Baseline before this rebuild: `5503afd7e8466e2d9c1091f502dd96941ad7bd34`.
This lab does not write Match Memory. Do not merge on this evidence.

## Verified findings

- The previous host called `snapshot()` twice per sample through `append()`, and `onGnss` read the journal for the active session. That path is gone. `lib/host.js` contains no `readAll`, `parseJournal`, or `snapshot(`.
- A sensor callback now updates memory and arms a one-second flush timer. Five thousand GPS callbacks with a timer that does not fire produced no chunk write, left the queue at or below 32, and counted the overflow as dropped and uncertified.
- Heart-rate preview uses `getLast()` as last known. A live sample is a separate transition. Null, zero, and out-of-range samples are unavailable. Preview samples are not queued.
- GPS acquisition stays on for an invalid status and for `satellitesUsed === 0`. Distance is not added across a gap. The next accepted point does not bridge the gap.
- `stop()` and `release()` remove the GPS and heart-rate listeners and call `geo.stop()`. A second `startSession()` does not register a second listener.
- The Bip 6 guest showed `SENS V2` with GPS stopped before any button. Enable HR showed `HR LAST KNOWN` while GPS stayed stopped. HR ONLY showed `NO GPS / DISTANCE UNAVAILABLE`. START SESSION showed `GPS READY` with `DISTANCE UNAVAILABLE` and no coordinates. STOP returned `GPS STOPPED`. Diagnostics showed `NOT SAVED`, `GPS CB 2`, `HR CB 0`, `Q 2 DROP 0`, `FLUSH 1 FAIL 0 UNCERTIFIED 0`, `PERF UNAVAILABLE`, `NOT A MATCH RECORD`.
- `npm test` in `apps/forref_sensor_lab`: 28 passed, 0 failed.
- `zeus build -t "Amazfit Bip 6"` wrote `dist/30101-SENS_V2-2.0.0-20261118211304.zab`. That package is gitignored.
- `zeus preview -t "Amazfit Bip 6"` printed a QR labeled `SENS V2 - 2.0.0` for Amazfit Bip 6. The CLI said it expires `2026-11-25 21:13:14` UTC (`23:13` Europe/Bucharest). The package is not committed.

## Hypothesis, not a measurement

The founder reported that the previous build showed no GPS fix, then lagged, froze, and restarted a physical Bip 6, while native Outdoor Walking received a fix and the lab had previously read heart rate and battery. The unbounded journal parse is a verified code defect and a plausible cause. This session did not re-measure that physical failure and does not claim it is the proven cause.

## Guest limits

The Bip 6 guest GPS status `READY` is synthetic. The guest heart-rate callback did not fire (`HR CB 0`); the screen showed last known, not a live sample. `getPerformance` returned unavailable. No-fix, lost, recovered, stress, and corrupt storage were exercised by unit tests, not by clicking those cases on the guest. The short guest session did not freeze. That is not hardware stability.

## Gates

| Gate | Verdict | Why |
| --- | --- | --- |
| S2-01 | PASS | Incident recorded separately from the code finding. The unsafe build was not put on a watch in this session. |
| S2-02 | PARTIAL | Unit tests separate last-known, live, null, and unworn. The guest showed last known with GPS stopped and did not emit a live callback. |
| S2-03 | PASS | Deterministic searching, ready, weak, lost, recovered, permission, and error tests. The guest showed ready and stopped. |
| S2-04 | PASS | Invalid GNSS leaves heart rate live and does not add distance across the gap. |
| S2-05 | PASS | No full-journal read in the host. Queue 32, chunk 16, short write is unverified. |
| S2-06 | PASS | Repeated start/stop and release drop both listeners and stop GPS. Guest STOP showed GPS stopped. |
| S2-07 | PARTIAL | Queue and UI rebuild are bounded in tests. Guest memory was unavailable. |
| S2-08 | PARTIAL | Guest battery read 88% from the slow timer. Performance numbers were unavailable. |
| S2-09 | PARTIAL | Guest covered boot, HR-only, combined ready, stop, and diagnostics. Gap recovery and stress stayed in unit tests. |
| S2-10 | PASS | Version `2.0.0` package and an expiring preview QR. Production app id 29566 and its 23 routes are unchanged. |
| S2-11 | BLOCKED | No physical retest. See `FOUNDER_30S_RETEST.md`. |
| S2-12 | PASS | Sensor-lab `npm test`: 28 passed, 0 failed. `./tool/verify_cloud.sh` exit 0: Match Core 377, persistence 92, phone 126. No Match Memory edits. PR stays open and unmerged. |

Screen-off GNSS, match-length recording, and Workout Extension on Bip 6 remain **not certified**.
