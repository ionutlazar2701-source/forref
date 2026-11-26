# CLOCK-006 Bip 6 protocol

State: **NOT TESTED**. Install `29566-FORREF-1.0.15-20261126220335.zab` (sha256 `b32f5ab7b06caa7bf85a50b4c34952896c6a078183386fcc5a390f8c258131a8`). The QR expires 4 Dec 2026, 00:03:38 Europe/Bucharest. Boot line `clock-006-observe`. The face warning "DIAGNOSTIC: phone-time callback. UTC assumed." means the callback was seen and the anchor was left in place. It does not mean the time is proven.

Compare every row with an independent stopwatch. Copy the `FORREF_CLOCK006` lines. Do one action per row.

| Test | Steps | What decides the cause | Result |
| --- | --- | --- | --- |
| SWITCH | Open another watch app and return. No notification. | Digits match the stopwatch. No `PHONE`. No `UNKNOWN`. | NOT TESTED |
| NOTE-CLOSED | Receive a notification. Do not open it. Return if the watch left FORREF. Vibration on. | If `PHONE` appears, the callback fired without opening the notice. | NOT TESTED |
| NOTE-OPEN | Open the notification, then dismiss it and return. Vibration on. | `PHONE` versus `LIFE onCreate` versus `UNKNOWN`. | NOT TESTED |
| VIBRATE-OFF | Repeat NOTE-CLOSED and NOTE-OPEN with vibration off. | Whether `PHONE` still appears. | NOT TESTED |
| LOCAL | Bluetooth off. Raise a local watch notification if the device can. | Whether `PHONE` still appears with the phone disconnected. | NOT TESTED |
| PHONE-CLOCK | Separately, change the phone time while a match is running. | `PHONE` must appear. Elapsed time must not be rewritten into a proven value. The warning stays UTC assumed. | NOT TESTED |

A row fails closed only when an `UNKNOWN` line is present. Record its `reason`, `utc`, `anchor`, `open`, `epoch`, `seq`, and `persist`.
