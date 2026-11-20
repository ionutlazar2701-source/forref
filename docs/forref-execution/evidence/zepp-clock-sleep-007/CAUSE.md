# Cause — CLOCK-SLEEP-007

PR #59 HEAD `5e534f76c85465c11ea5591d49688437a036c3a9`. Amazfit Bip 6, FORREF 1.0.9:

`L=TIMER r=UNSAMPLED_GAP n=0 x=0 s=? w=2/1/1 I=1 S=ok`

The visible line stops at `S=ok`. Destroy and the checkpoint age are past the point where the round face clipped the 1.0.9 text.

## What is durable

`I=1` means `onInit` set the init flag and a later successful witness write included it. `n=0` means that successful write contained no callback. A `createSysTimer` callback increments `n` before it flushes, so the successful write was not a callback flush. `w=2/1/1` is one failed attempt merged into one success. `r=UNSAMPLED_GAP` is the foreground sampler: the 2500 ms guard held, and the screen-off gap was not added to the match.

`onInit` flushes that record before `createSysTimer` returns. The timer id, a thrown create, and `onDestroy` were not fields in the saved line the founder could read.

## What this does not identify

The four outcomes stay open:

- The timer was not created.
- The service was destroyed before the first callback.
- The timer was created and no callback was delivered.
- A callback ran after the successful write and its own write did not land.

A single-session reading of `w=2/1/1` with `n=0` is a failed flush followed by a non-callback flush. That later flush can be `onDestroy`, but a witness file left from an earlier 1.0.9 launch can produce the same counters from `onInit` alone. The clipped line does not show `D=`.

## What 1.0.10 stores

The match timer stays `createSysTimer(true, 1000, tick)`. Immediately after it returns or throws, the service writes `T` and `id` and reads that record back. `D` is the destroy reason. `F` is the first match callback. `X` is a separate 5000 ms timer that does not sample the match. `A` is `getAllAppServices` on wake, written by the Device App. `b=1` means those timer fields were read back.

The painted line is short enough for the round face:

`T=<ok|fail|-> id=<id> D=<reason> F=<0|1> X=<count|fail|-> A=<1|0|x|-> b=<0|1>`

| Line | Result |
| --- | --- |
| `T=fail` | Timer was not created |
| `T=ok` `D=destroy` or `D=stop` and `F=0` | Destroyed before the first callback |
| `T=ok` `D=-` `F=0` `X=0` `A=1` | Created, still listed, no callback delivered |
| `T=ok` `F=0` `X>=1` | The 5000 ms experiment fired and the 1000 ms match timer did not |
| `T=ok` `D=-` `F=0` `A=0` | The service was no longer listed on wake |
| `F=1` | The first match callback was stored |

`X` is not match time. The foreground clock and the 2500 ms guard are unchanged.
