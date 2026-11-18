# Sensor session protocol

The lab is a separate app, `FORREF SENS`, app id `30101`, namespace `forref_sens_001`, file `forref_sens_001.journal`. It is not a match, not a Match Record, and not a Saved acknowledgement.

## Opt-in

1. Open `FORREF SENS`. The home line reads `STOPPED — NOT A MATCH`.
2. `START` is the consent to sample. It allocates the next session id (`LAB-0001`, then `LAB-0002`, without rewriting earlier lines) and starts foreground Geolocation and continuous heart rate.
3. `STOP` calls `offChange`, `geo.stop`, `offCurrentChange`, and distance `offChange`, then writes `LIFECYCLE STOP`.
4. `STATUS` shows fix or no fix, on-watch coordinates only when both are present, heart rate or `HR UNAVAILABLE`, `DISTANCE UNIT UNRESOLVED`, and battery or `BATTERY UNAVAILABLE`.
5. `TRACK` uses the latest `sessionId` only. It shows that id, experimental meters, experimental max speed or `MAX SPEED UNAVAILABLE`, and the gap count. Heart rate is two lines: `HR SAMPLES valid/total` is the valid-sample ratio, and `HR TIME` is the measured share of the session span. A sample ratio is not time coverage. Neither line is a diagnosis. Samples with another session id are ignored. A call without a session id returns `SESSION_REQUIRED` and distance 0.
6. `HEAT` looks only at the latest session. It shows `HEAT MAP UNAVAILABLE` when that session has no status-`A` fix, otherwise `NO FIELD CALIBRATION`. It does not draw a map and does not invent pitch corners.
7. `DELETE LOCAL`, then `CONFIRM DELETE`, unlinks the journal. Absence after delete is success.
8. `HR SERVICE — NO GNSS` stops GNSS first, then starts `app-service/hr_only` with `reload: false`. The service does not call Geolocation.

## What a sample is

Each line is schema 1, FNV-1a checked, attribution `EXPERIMENTAL`. Kinds are `GNSS`, `HR`, `DISTANCE`, `LIFECYCLE`, and `GAP`. `diagnosticElapsedMs` and `diagnosticUtcMs` are `Date.now()` deltas. They are not match minutes and they are not a monotonic clock authority.

A GNSS row stores latitude and longitude only when status is `A`. Status `V` stores null coordinates and flag `NO_FIX`.

## Storage bound

Maximum 4096 entries or 1,048,576 bytes. There is no rotation and no startup deletion. When the cap is reached, sampling stops and the home line can show `STORAGE FULL`.

A 90-minute referee session at 1 Hz GNSS plus 1 Hz heart rate needs 10,800 entries and 4,989,648 bytes. `refereeStorageLimit()` reports `enduranceReady: false` and `fitsNinetyMinutes: false`. The byte cap is the tighter limit: 1,134 pairs, 1,134 seconds (18 minutes 54 seconds) for a 458-byte GNSS line and a 466-byte heart-rate line at sequence 4096. The 4096-entry cap would allow 2,048 pairs only if the lines were smaller. The lab is not endurance-ready.

Heart-rate service lines omit `sessionId`. Track does not mix them into a named GNSS session.

A missing file reads as empty. A torn tail, bad checksum, sequence gap, or short write refuses further appends. Power-loss durability is not certified.

## Privacy

The journal on the watch may contain coordinates and pulse. Console lines do not. Do not photograph a status screen that shows a real fix or a real pulse, and do not commit a journal, a path map, or a health export. Delete local data when the session is finished. Retention is on the device until that delete.

## Navigation is not screen-off

Leaving home to open Status, Track, or Heat writes `LIFECYCLE APP_EXIT` because the home page is destroyed. That name is not `DISPLAY_OFF` and is not a power loss. In the guest, GNSS callbacks stopped at that navigation. Treat the hole as a measured interruption, not as continuous recording.
