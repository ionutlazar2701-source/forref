# Hardware protocol — experimental Live telemetry

This is a short founder check on a physical Amazfit Bip 6. It is not a certification and it is not a 90-minute test. Stop at the first lag, heat, or restart.

1. Install the watch build from this branch. Confirm the app id is 29566 and the label is FORREF. Do not install the SENS V2 lab over it.
2. From READY, whistle kick-off before any GPS icon turns ready. The match clock must move immediately. If it waits on GPS, heart rate, or storage, stop and treat that as a failure.
3. Walk a short straight line during the first half, then stand still. The compact line may stay at `0,00 km` until a second valid fix clears the 4 m hold. That is expected. Do not read the figure as an official distance.
4. Whistle half-time and walk. The distance figure must not increase. Heart rate may stay visible. GPS should not add meters.
5. Start the second half. The first fix after the whistle must not jump the total by the distance walked at half-time.
6. Pause, then walk, then resume. Meters added after resume start from a new anchor.
7. Open Match Controls and an event screen, then return. The clock and the distance figure must still be the same session.
8. Whistle full time. The figure freezes. Leave the app. A later open must not keep counting.
9. Optional recovery: while the half is running, leave the app so the process ends, then open Live again. Expect `TIME UNVERIFIED` and the last accepted figure, not a bridged line. Continue from last, then confirm the next fix does not add the gap.

Do not use Workout, the sport-data API, or a native distance total as a comparison that could be written back into this figure. Do not continue into a full match. Record only whether the clock ever waited, whether a closed phase gained meters, and whether the watch lagged, heated, or restarted.
