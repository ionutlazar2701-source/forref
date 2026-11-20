# Limitations — CLOCK-SLEEP-006

- The foreground sampler from 1.0.6 is unchanged.
- `DISPLAY_CONTINUITY_MS` stays 2500. A gap still fail-closes and adds no elapsed time.
- The Live line is a diagnostic readout. It is not match time and it is not Match Memory.
- `S=ok` remains the host start code. `I=1` is the service's own durable init.
- If every witness write fails, the file still shows `I=0` and `n=0`. A rejected write that never succeeds cannot be distinguished from a service that did not run.
- A screen-on write is attempted and is allowed to fail. The 5-second result is the line after wake.
- No new temporal source is added. PR #52 through PR #58 are not rewritten. Native Familiarity V5 is not in this build.
