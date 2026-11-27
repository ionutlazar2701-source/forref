# CLOCK-007 software results

State: **SOFTWARE PASS / HARDWARE GATE PENDING**. Not a hardware pass.

Functional commit `bb38321f87998a2c9a68b073ef6c8ee3e979bb30`. Boot name `clock-007`.

## Reproduction

The test platform doubles the period of a timer that is already armed when sleep begins. A timer created afterwards keeps its requested delay.

A host that never stops that id produces, after a 10-second sleep, one catch-up to `00:15` and then `dt=2000` `step=2`. `classifyCadence` returns `CALLBACK_2S`. One timer remains.

The foreground host stops that id when `dt` is at least 1500 ms and arms one replacement. For sleeps of 10 seconds, 60 seconds, and 5 minutes the catch-up face equals the UTC projection at that callback. The next callbacks have `dt=1000` and `step=1`. The drawn second is the anchor second. It is not the previous second plus one, and it is not the anchor minus two.

A callback every 1000 ms whose digits jump by two is `RENDER_SKIP`. That path does not stop the timer. A `stopTimer` that throws on the gap does not arm a second id. Returning to Live after sleep leaves one timer, and the next gaps are 1000 ms. The wake lines carry `dt`, `step`, `prepareMs`, `commitMs`, and `paintMs`. No diagnostic file is written.

## Suite

`npm test` in `apps/forref_watch_zepp`: 239 pass, 0 fail. `./tool/verify_cloud.sh`: PASSED.

Goal, score, and Match Memory files are not in the functional diff.

## Diagnostic package

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.16` (code 16). The preview package is `dist/29566-FORREF-1.0.16-20261127091904.zab` (363345 bytes, sha256 `6a35ca45dae88a958ae704e8dcc3ab14229bcf59ac73a3e366d59a0e2a1918f1`). It is not committed. The QR expires `2026-12-04 09:19:06` on the machine clock (UTC), which is 11:19 Europe/Bucharest. The QR was not scanned here.

```
[FORREF - 1.0.16]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▀█ █▄▀█▀ █▄▄▄ █▄██ ▀ █ ▄▄▄▄▄ █
█ █   █ █▀▀▀█ ▀▀▀ █▄▀▀▄ ▀ ▀ ▀██ █   █ █
█ █▄▄▄█ █▀ █▀▀▀  ▄▄ █▄▀▀▄▀▀▄▀ █ █▄▄▄█ █
█▄▄▄▄▄▄▄█▄▀ ▀▄█▄█▄█ ▀ ▀▄█▄█ █ █▄▄▄▄▄▄▄█
█ ▄▄  █▄  ▄▀▄▀▄▄▀▀█▀▀ ██▀▄▄ ██▄█ █ ▀ ██
█▄▄▄█▄█▄█  ▀█▀█▀ █▄▄█▀▀ ███▄  ▄  ▀ ▄▀ █
█▄▄▀█▄▀▄ ▄ ▄█▄▀ ▀ ▄██ ▀▄   ▄█▀▄▄█▄▄ ▀▄█
█▀ ▀▄▄▄▄▀▀█▀ ▄██▄▄▄ ▀▀ ▄█ ▄ ▄   ▀█▀▄█ █
█▄█ ▀▀█▄███▀▄▀█ ▄▀ █▀ █▄▀█ ▄█▀▀▄ ▄▄ ▄▄█
█ █▄▀▀▀▄ ▄█▄█▀█ ▄ █▄▀▄▀ █ █ ▄▄█▄▄▀█▄ ▄█
█ ▀ ██ ▄█  ██▄▄▄▄▀▄▀▄▀▀ ▀█ █▄▀█▄▀▄ ▄███
█   ▀▀█▄ ▄▀▀ ▄█▀ ▀█▀█ ▀ █▀▄ ▄▀▄█▀▄██▄ █
█ █ ▀▄ ▄ █ ▄▄▀▀▄█▀█▀ ▀█▄▀▄▄ ██ ▄▀▄▀▄▀▄█
█ ██▄█ ▄▄▀█ █▀▄ ▄▀█▄▀ ▀▄▀██▄ ███▄▀▄█▄▄█
█▄█▄▄▄▄▄█▀▄ █▄█ ▀▀▄▀ ██▄   ▄▄ ▄▄▄   ▀██
█ ▄▄▄▄▄ █▄▄█ ▄█▀▄▀█▄█▀ ▄▀▀▄ █ █▄█ ▀█▄▄█
█ █   █ █ ▀▀▄▀▀█▄▀▄▀▀▀█▄▀█ ▄ ▄  ▄ ▄  ▀█
█ █▄▄▄█ █ ███▀ ▄▄▄█▀█▄▀ █▄▄ ▄▀▀▀ ███▄ █
█▄▄▄▄▄▄▄█▄▄▄█▄█▄▄█▄████▄▄▄▄▄██▄▄▄▄▄▄▄▄█
```
