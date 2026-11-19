# Limits that remain after FORREF-LIVE-TEL-003

- Telemetry is experimental. It is not a Match Record, not D1, and `distanceSaved` is never true. `~` on the distance marks that.
- The Bip 6 guest simulator was disconnected (`127.0.0.1:7650`). This run did not recapture Live A/C frames. Layout is covered by the geometry tests. Walking distance and a real pulse were not observed on a guest screen.
- Zepp Geolocation does not provide a fix timestamp on the callback. A callback is admitted by the generation captured at `onChange` and by the host clock at delivery. A sample whose delivery clock is missing is `UNCERTAIN` and adds no meters. A fix that the OS delayed inside one generation can still be read as current when the callback runs.
- Provisional totals restore only when the stored kick-off intent id matches the clock session. A process restart with no kick-off id does not reuse the previous match. The checkpoint is a readback of `forref_tel_003_state.txt`. It is not a durable Saved state. The file stores no coordinates and no pulse.
- `hr.start` / `hr.stop` are not used. Heart rate stays available during pause and half-time for display. Those samples are not gameplay distance.
- If `offChange` throws, the host keeps the leaked listener, refuses a second subscription, and ignores the old closure for meters.
- The installable package from `zeus build -t "Amazfit Bip 6"` is the rectangular 390×450 target. The 480×480 layout was not built as a guest package in this run.
- Heat map is pending. Workout Extension, `getSportData`, and native sport totals are not used.
- Screen-off sample continuity, battery, and a 90-minute match are not certified.
- Physical GPS accuracy, heat, and reboot behavior are `LOCAL GATE REQUIRED`.
