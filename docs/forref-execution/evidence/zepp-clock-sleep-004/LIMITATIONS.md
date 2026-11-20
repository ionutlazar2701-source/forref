# Limitations — CLOCK-SLEEP-004

- The foreground sampler from 1.0.6 is unchanged. This build adds logs around it and inside the App Service.
- Hardware certification is pending. A cloud `CHAIN` uses injected one-second callbacks. It is not a Bip 6 screen-off.
- The Zepp document says `createSysTimer` runs with the screen off. It does not prove the 1000 ms period on this firmware. `dt` is the measurement. A `dt` above 2500 ms fail-closes.
- `Time.onPerMinute` and a single alarm cannot fill a 5, 30, or 120 second sleep inside the admission window. They are not used as a time source.
- There is no monotonic clock in this app. UTC is the observation clock. A missing callback is a missing observation.
- File writes from the service remain specified for screen-off and AOD. `pair=miss` during `screen=off` is a persistence failure, not a reason to show a guessed elapsed time.
- The service stops on pause, half-time, full time, abandon, and an unverified clock. `stop-reason` separates those.
- This clock is a watch prototype. It is not Match Memory. PR #52 through PR #56 are not rewritten. Native Familiarity V5 is not in this build.
