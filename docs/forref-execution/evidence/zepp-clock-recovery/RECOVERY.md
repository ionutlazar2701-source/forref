# CLOCK recovery and display cadence

Hardware on Amazfit Bip 6, founder, builds through 1.0.13:

- 13-minute screen sleep passed.
- Leaving FORREF and opening Live Fixture again showed TIME_UNVERIFIED.
- The visible clock still sometimes stepped by two seconds.

## Process restart

`app.js` stores a new process id in `clockEpoch` on every `onCreate` (`e` plus `Date.now()`). The UTC segment treated a different process id, together with a gap over `DISPLAY_CONTINUITY_MS` (2500 ms), as reason `EPOCH`. `failClosed` then set `TIME_UNKNOWN`, cleared the open anchor, and the first Live paint wrote that failed session over the healthy slot.

A new process id is not a civil-time correction. The persisted open UTC stays the elapsed-time anchor. Recovery after 30 seconds, 2 minutes, and 13 minutes projects `closed + (now - openStartUtc)` and does not rewrite the slot. The sampler still refuses an unsampled gap at 2500 ms. Backward UTC, a segment outside the diagnostic window, corrupt or conflicting storage, and a detected phone-time change still fail closed. A failed evaluation is what may be written. A healthy slot is not replaced before that evaluation.

## Two-second face

1.0.12 removed the second Live timer. The Bip 6 still stepped by two seconds, so that explanation is not sufficient. The founder report does not include `FORREF_CLOCK_CADENCE` lines, so this run cannot yet label the device trace `CALLBACK_2S` or `RENDER_SKIP`. Both of the following were still on the 1-second callback:

- The callback wrote the witness file and destroyed and recreated the digit widgets on every healthy paint. If that work runs past 1000 ms, `createTimer` delivers the next wake late. The log then shows `dt` near 2000 and `step` 2 (`CALLBACK_2S`). The anchor time is still correct. The missed second is only a missed paint.
- Deleting and creating the text widget every second can be presented only on the next frame. The log then shows `dt` near 1000 and `step` 2 (`RENDER_SKIP`).

The patch does not add a timer and does not invent seconds. A healthy `UTC_ASSUMED` or `HELD` paint no longer writes the witness. The digit widgets stay and receive the new text. The repeat period stays 1000 ms. The first delay waits until the next UTC second. Faults still write the witness. The match slots are unchanged on a healthy paint.

Expected on-wrist cost while Live is visible is lower than 1.0.13: one wake per second, less flash, fewer widget allocations. Not measured on a watch.

## Next hardware read

Grep `FORREF_CLOCK_CADENCE`. Five lines with `dt` 700–1400 and `step=1` are the one-second face. Five lines with `dt` 1500–2600 and `step` of 2 or more are still `CALLBACK_2S`. Five lines with `dt` 700–1400 and `step` of 2 or more are still `RENDER_SKIP`. After leaving the app and reopening Live, the face must match the anchor, and the slot must not be `TIME_UNKNOWN` unless the clock moved backward, storage failed, or a phone-time change was detected.
