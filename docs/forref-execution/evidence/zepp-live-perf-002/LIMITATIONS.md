# Limitations

- Experimental telemetry only. It is not a Match Record, not D1, and not a saved distance. The phone Match Memory writer is unchanged.
- The match clock remains the only phase authority. Sensor failures are caught after the clock commit.
- Distance is accumulated only while the trust is not `TIME_UNVERIFIED` and the phase is `FIRST_HALF_RUNNING` or `SECOND_HALF_RUNNING`. Ready, paused, half-time, suspended, full time, and abandoned add nothing.
- A segment closes when the active phase ends. The next active phase needs a new valid GNSS anchor. Gaps, pauses, halves, and unverified time are not bridged.
- The 4 m hold, the 12 m/s teleport reject, and the isolated spike rule are the SENS V2 2.1.0 rules. A first step faster than 6 m/s after a new anchor moves the anchor and adds no meters.
- Shown distance is kilometers with two decimals. Romanian uses a comma. Storage and totals stay in meters.
- The compact line is one 16 px row under the clock on Live A and Live C. It is painted on the existing one-second clock pass. It does not rebuild the buttons.
- Heart rate and GPS are status words. The line does not print a pulse or a coordinate.
- GPS runs only during an accepted running half. Heart rate may stay in measurement from kick-off until full time or abandon. Neither one blocks the clock.
- Totals are flushed as one short line at a phase change, on release, and at most every five seconds. A callback does not write the file. A full or failed write marks the total uncertified and does not change the clock.
- Process death closes the segment. The next launch can restore the accepted meters and must take a new anchor. Continuous GNSS through screen-off is not certified.
- Ninety-minute reliability is not certified. The earlier storage ceiling still refuses a 90-minute GNSS journal. This file is only the two half totals.
- Heat map is pending. No screen was added.
- Workout Extension, `getSportData`, and native sport totals are not used on Bip 6.
- The Bip 6 simulator showed the line, the unverified recovery, pause, resume, and navigation. Its injected position did not walk, so the simulator did not demonstrate accumulated meters. The heart-rate injector was left at 20, which is outside the 30–230 display band, so the status stayed in measurement and no pulse was shown.
- A physical Bip 6 run is still required. Cloud and simulator execution do not certify the device.
