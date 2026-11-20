# Hardware gate — CLOCK-SLEEP-006

Status: **LOCAL GATE REQUIRED**.

The 1.0.8 line is explained in `CAUSE.md`. Cloud tests inject the UTC values and the witness fields. They do not show that `onInit` or `createSysTimer` ran on this Bip 6.

Certification waits until one controlled 5-second screen-off copies the 1.0.9 Live line. That line names the first durable link. It does not widen the 2500 ms rule and it does not create elapsed time.
