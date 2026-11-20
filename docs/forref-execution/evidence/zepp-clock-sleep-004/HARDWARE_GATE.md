# Hardware gate — CLOCK-SLEEP-004

Status: **LOCAL GATE REQUIRED**.

1.0.6 on Amazfit Bip 6 kept the match clock during Goal, Card, Substitution, Match Controls, and leaving and reopening the app. Screen-off still produced `TIME_UNVERIFIED`. The log that would name the broken link was not part of that report.

1.0.7 is the evidence build for that link. Cloud tests inject the UTC values. They do not show that `createSysTimer` fired on this watch. Certification waits until the 5, 30, and 120 second screen-off steps in `HARDWARE_PROTOCOL.md` pass.
