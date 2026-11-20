# Limitations — CLOCK-SLEEP-005

- The foreground sampler from 1.0.6 is unchanged.
- The Live line is a diagnostic readout. It is not match time and it is not Match Memory.
- A 1 or 2 second wake with `off=0` can still be exact because of the 2500 ms foreground window. It is not evidence that the service ticked.
- The App Service does not write the witness while the screen is on. `witness=held` is that choice.
- `max=0` with `off=1` means one off-screen callback and no earlier callback to compare.
- Hardware certification is pending. PR #52 through PR #57 are not rewritten. Native Familiarity V5 is not in this build.
