# First five seconds — CLOCK-SLEEP-005

PR #57 has no Bip 6 log. The issue comments and the evidence folder contain the 1.0.7 protocol and the cloud matrix, not a captured `tick=` line from the watch.

Physical result for FORREF 1.0.7 on Amazfit Bip 6:

- Wake about 1 second after screen-off: the match clock continues.
- Wake about 3–4 seconds after screen-off: `TIME_UNVERIFIED`.

That pattern matches the unchanged 2500 ms rule with no admitted sample during the sleep. A 1 second wake can still see the last foreground checkpoint. A 3 second wake cannot. The result does not show that the App Service produced, committed, or recovered a background observation. It shows that whatever ran did not leave an admitted checkpoint inside the window.

Cloud checks for the same intervals, with no background tick:

| Screen-off | Step from the last admission | Result |
| --- | --- | --- |
| 1 s | 1000 ms | admitted, exact `00:01` |
| 2 s | 2000 ms | admitted, exact `00:02` |
| 3 s | 3000 ms | `UNSAMPLED_GAP`, closed time unchanged, digits null |
| 4 s | 4000 ms | `UNSAMPLED_GAP`, closed time unchanged, digits null |
| 5 s | 5000 ms | `UNSAMPLED_GAP`, closed time unchanged, digits null |

A chain of off-screen ticks at 1 second intervals through 5 seconds does resume. That case is the one the on-watch line has to confirm or rule out.

## On-watch line

Live shows one line that is stored in `forref_clock001c_witness.json` and read again after wake:

`S=<start> off=<count> max=<ms> ck=<age> r=<reason>`

| Field | Meaning |
| --- | --- |
| `S` | `start` class: `ok`, `listed`, `permission`, `limit`, `unavailable`, or `-` if start was not seen |
| `off` | Callbacks recorded while `screen=off`. A screen-on callback does not increment this and does not write the witness from the service |
| `max` | Largest `dt` among those off-screen callbacks. `0` with `off=1` means the first callback had no previous one to measure |
| `ck` | Age in milliseconds of the last successful checkpoint. `none` means no checkpoint was committed |
| `r` | Latest admission, or the `loadSession` reason when no later admission was stored |

The Device App writes `S`, `ck`, and `r` while the screen is on. The App Service writes `off` and `max` only when the screen is off. A file write from the service is not required, and is not attempted, while the screen is on.

How to read the next run:

| Screen | Meaning |
| --- | --- |
| `off=0` and `r=TICK` at 1–2 s | Foreground window only. No committed background observation |
| `off=0` and `r=UNSAMPLED_GAP` or `r=RECOVERY_REQUIRED` at 3–5 s | No background observation was committed before the window closed |
| `off>=1`, `max` at most 2500, `ck` at most 2500, `r=TICK` or `r=CONTINUITY_RESUMED` | An off-screen observation was produced, committed, and recovered |
| `off>=1` and `r=UNSAMPLED_GAP` | A callback was produced, and the chain still did not recover. `ck=none` means it was not committed |
