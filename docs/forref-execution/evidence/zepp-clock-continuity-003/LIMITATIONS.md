# Limitations — CLOCK-CONTINUITY-003

- Hardware certification is pending. The package is a diagnostic install, not a passed Bip 6 result.
- The Device App timer is for screen-on navigation. Screen-off continuity depends on the App Service. The fetched `createTimer` page does not promise that the app timer runs with the screen off.
- `createSysTimer` during physical screen-off is still unproven on this Bip 6. A cloud test that injects UTC is not that proof.
- The service file write is specified only for screen-off and AOD. A tick in memory while the screen is on is not a checkpoint.
- LocalStorage is not required for the screen-off pair. If both the file and the mirror fail readback, the tick is not saved and the next admission fail-closes.
- An empty service list restarts at most three times, then `services=gave-up`. The clock does not invent the missing interval.
- `setWakeUpRelaunch` reopens the mini program. It is not a time source. `reload: false` still refuses to continue across a reboot gap.
- The 2500 ms window is unchanged. Pause, half-time, and sporting-event capture semantics are unchanged.
- This clock is a watch prototype. It is not Match Memory, and it does not write a Match Record.
- Native Familiarity V5 is not in this build. PR #52 through PR #55 are not rewritten.
