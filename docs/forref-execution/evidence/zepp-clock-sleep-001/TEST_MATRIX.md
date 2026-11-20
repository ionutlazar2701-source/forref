# Test matrix — clock sleep

`DISPLAY_CONTINUITY_MS` remains 2500. The new tests call `admitDisplay`, `liveFrame`, `projectFrame`, `loadSession`, and `runServiceTick`. They are not string checks alone. The wiring test also reads the service, the bind module, and `app.json`.

| Case | Result in cloud |
| --- | --- |
| 1 s observation chain for 5 s, 30 s, and 120 s | exact elapsed, trust stays verified, stored epoch kept |
| One paint at 5 s, 30 s, or 120 s with no intermediate observation | `UNSAMPLED_GAP`, closed milliseconds unchanged, digits null, last known kept |
| Stale page plus a stored checkpoint inside 2500 ms | continued digits |
| Stored checkpoint absent or also stale | unverified, gap not added |
| Page timer stopped, service ticks continue, then paint | continued digits |
| Sampler permission denied | no write; a later large paint unverifies from the last good observation |
| `loadSession` with `now` inside 2500 ms, including a new epoch string | `CONTINUITY_RESUMED`, exact digits |
| `loadSession` at 30 s, 120 s, or with `now` omitted | `RECOVERY_REQUIRED`, gap not added |
| Pause, half-time, and a stopped ready session | sampler stops; elapsed does not grow |
| Five seconds past 45:00 | still the first half, added time shown, no automatic end |
| Second half | display starts at 45:00 and advances only with observations |
| Backward UTC, a 3 s jump, a duplicate timestamp, an older checkpoint | no fabricated elapsed time |
| Readback failure and file/kv conflict | no exact match time |
| Newer running checkpoint versus an older or unverified write | newer checkpoint kept |
| Relaunch, phone-time callback, reboot reload | not used as a clock; `reload: false` |

Cloud commands on 20 Nov 2026, Europe/Bucharest:

- `apps/forref_watch_zepp` `npm test`: geometry pass, 92 node tests pass.
- `apps/forref_sensor_lab` `npm test`: 34 pass.
- `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

Simulator connect status was disconnected. No simulator frames were captured. Device rows are empty on purpose.
