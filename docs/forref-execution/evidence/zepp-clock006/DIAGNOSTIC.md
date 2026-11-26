# CLOCK-006 notification diagnostic

Baseline: PR #77, FORREF 1.0.14. On a Bip 6 the founder ran about 60 minutes.

- Switching to another watch app and returning: PASS.
- Receiving a notification, opening it, and returning: FAIL. The face advanced about 2–3 seconds, then showed TIME_UNVERIFIED.
- Persistent two-second jumps were not seen on that run.

App switching already passes on 1.0.14, so a process restart alone does not explain the notification failure. The extra 2–3 seconds mean the UTC anchor was still projecting after the return, and a later check then invalidated it. One registered path can do that without a backward reading: `Time.onPhoneTimeSetting` calls `noteDiscontinuity`, which writes `TIME_UNKNOWN` over the open segment. This package does not treat that as proven. A notification is not assumed to be a civil-time correction.

## Observe mode

This build sets `PHONE_OBSERVE` true. The callback stays registered. When it fires, the log and the side file are written first. The UTC segment is not changed, the slot is not rewritten, and the face stays `UTC_ASSUMED`. Live shows the diagnostic warning. The side file `forref_clock006_anchor.json` keeps the last healthy open UTC and counts phone callbacks. Nothing reads that file back into the match.

`PHONE_OBSERVE` false still fail-closes through `noteDiscontinuity`. That path is in this source and is covered by the existing phone-time test. This package does not turn it off as a production rule.

## Log lines

```
FORREF_CLOCK006 LIFE kind=onCreate|onDestroy|boot|live-build|live-destroy epoch= utc=
FORREF_CLOCK006 PHONE callback=1 source=onPhoneTimeSetting mode=observe utc= anchor= open= epoch= seq= phase= trust= screen=
FORREF_CLOCK006 UNKNOWN reason= utc= anchor= open= epoch= seq= persist=
```

`PHONE` means the callback fired. It does not say whether the notification was received, vibrating, opened, or dismissed. The API does not pass that stage. One action per trial separates them. `UNKNOWN` is a real invalidation, with the reason that cleared the anchor. `LIFE` separates an app or page restart from a callback that left the process up.

## How to read one failed return

| What is in the log | Meaning |
| --- | --- |
| `PHONE` and the warning, digits still moving, no `UNKNOWN` | The callback fired. Observe mode kept the anchor. |
| `UNKNOWN reason=BACKWARD` | The UTC reading moved earlier than the anchor. |
| `UNKNOWN reason=CLOCK_UNAVAILABLE` | `Time.getTime()` was missing. |
| `UNKNOWN reason=PHONE_TIME_SETTING` | Enforce mode wrote the failure. This package does not do that. |
| `LIFE kind=onDestroy` then `onCreate` and no `PHONE` | The notification relaunched the app. |
| `LIFE kind=live-destroy` then `live-build` and no `onCreate` | The page was rebuilt inside the same process. |
