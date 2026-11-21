# Hardware gate — CLOCK-SLEEP-007

Status: **LOCAL GATE REQUIRED**.

The 1.0.9 line proves init without a durable callback. It does not prove whether `createSysTimer` returned an id, threw, or was destroyed before the first callback. Cloud tests do not show a Bip 6 timer id.

Do not merge a clock change from this package. The next physical line is the evidence that can support a fix.
