# CLOCK-004 temporal authority contract

Status: integrated into FORREF watch app `29566`, version `1.0.11`. This contract covers the watch display clock. It does not change Match Core or Match Memory.

Source experiment: PR #65 (`cursor/chron-004-hardware-validation-4ae8`). Baseline clock: PR #61 (`cursor/clock-sleep-007-4ae8`).

The founder reported, on one physical Amazfit Bip 6, that the CHRON-004 probe kept 90 minutes of match time across screen sleep, app relaunch, Bluetooth off, pause/resume, and a second-half start at `45:00`, with about 2 percentage points of battery used. That report is not exhaustive certification, and it is not a result of this integrated build. The integrated package has its own hardware protocol and is **NOT TESTED** on a watch until that protocol is filled in.

## What calculates elapsed time

A running period stores one UTC anchor: `openStartUtc`, plus the already closed milliseconds of that period.

While the period is running and the record is healthy:

```
elapsed = closedMs + (queryUtc - openStartUtc)
```

The one-second JavaScript timer only asks for a new paint. It does not add one second, and it does not write the slot. Sleep, a capture page, or a process exit does not erase the anchor. The next paint subtracts the same anchor from the current `Time.getTime()` value.

`Time.getTime()` is civil UTC from the watch, not a monotonic clock.

## Two engines

| Engine | How a running display moves | Sleep longer than 2.5 s |
| --- | --- | --- |
| `utc_segment` | Project from the stored anchor. | Healthy. Digits follow the anchor. Integrity stays `UTC_ASSUMED`. |
| `sampler` (the previous clock, and any session with no `engine` field) | Admit a step only when it is within `DISPLAY_CONTINUITY_MS` (`2500`). | `UNSAMPLED_GAP`. Digits hidden. Trust `TIME_UNVERIFIED`. |

`DISPLAY_CONTINUITY_MS` is unchanged. It binds the sampler. It does not apply to a healthy `utc_segment` anchor.

New Live boots use `utc_segment` unless `forref_clock004_engine.txt` contains the single word `sampler`.

## Integrity

| Label | Meaning |
| --- | --- |
| `UTC_ASSUMED` | The segment math ran. Nothing proved the civil clock was continuous. A successful `utc_segment` read is always this, never `PROVEN_TIME`. |
| `PROVEN_TIME` | Sampler only, and only after an observation chain was admitted inside 2.5 s (`trust` `OBSERVED_UNVERIFIED`). |
| `TIME_UNKNOWN` | The record was rejected. Digits are hidden. Trust is `TIME_UNVERIFIED`. |

Ordinary sleep does not become `TIME_UNKNOWN` just because no JavaScript callback was delivered.

## Fail closed

These reject the running segment, clear its open anchor, hide the digits, and persist a new sequence so the rejection survives restart:

- `queryUtc` missing, or no open anchor.
- `queryUtc` earlier than the anchor or earlier than the last committed UTC (`BACKWARD`).
- Open segment longer than 6 hours (`SEGMENT_OUTSIDE_WINDOW`). This is a diagnostic bound, not a football rule.
- Epoch identity changed and the step from the last committed UTC is wider than 2.5 s (`EPOCH`).
- A live `onPhoneTimeSetting` callback while the period is running (`PHONE_TIME_SETTING`).
- Torn slot text, a checksum mismatch, or two slots with the same sequence and different bodies (`CORRUPT`, `CONFLICT`).

A rejected running segment folds only the last committed anchor (`lastUtc - openStartUtc` at the last phase change). It does not keep the painted projection from the interval that just failed. Kick-off's committed anchor is the kick-off instant, so a phone-time callback before the next phase change drops that open half to zero and hides it. Pause, half-time, and full time have already folded their elapsed time, so a later clock step does not rewrite them.

## What this does not prove

An undetected civil-time correction is still possible. If the watch or phone changes the clock while this process is not running, `onPhoneTimeSetting` does not fire. The next paint still returns `UTC_ASSUMED` and can be wrong by the size of the step. That result must not be called `PROVEN_TIME`.

Reconstructed display timestamps are not Match Memory events. This package does not promote them into authoritative match records.

## Match transitions

Kick-off, pause, resume, end first half, half-time, start second half, suspend, resume game, abandon, and full time still go through `applyIntent`. A phase change commits the segment. A paint does not.

The half length is `halfLimitMs` on the v2 record. The watch has no competition-duration setting, so a new record stores `REGULATION_HALF_MS` (45 minutes) explicitly. A different positive `halfLimitMs` changes the display mark (`40:00`, `80 + mm:ss`). Added time is still display-only. `45:00` and `90:00` do not end a period by themselves.

Second-half display is `halfLimitMs` plus the open second-half segment. With the default limit, start of the second half shows `45:00`.

## Rollback

See `MIGRATION_ROLLBACK.md`. The sampler functions remain. Writing `sampler` into `forref_clock004_engine.txt` sends the next boot through `loadSession` and the 2.5 s gate.
