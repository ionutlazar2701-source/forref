# Limitations — CLOCK-SLEEP-007

- The foreground sampler from 1.0.6 is unchanged.
- `DISPLAY_CONTINUITY_MS` stays 2500.
- The 1000 ms match timer is unchanged. The 5000 ms timer is a separate counter and is not match time.
- `b=1` means a timer, destroy, callback, or experiment record was read back. An init-only write leaves `b=0`.
- If the process dies before any of those writes succeed, the line stays `T=-`.
- The painted line omits the long 1.0.9 fields so destroy and the timer id stay on screen.
- PR #52 through PR #59 are not rewritten. The carousel V5 branch is not modified. Native Familiarity V5 is not in this build.
