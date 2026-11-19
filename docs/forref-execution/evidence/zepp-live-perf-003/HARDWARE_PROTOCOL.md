# Bip 6 short validation — LOCAL GATE REQUIRED

Do not merge pull request #52 from this protocol. Do not start a 90-minute match. Stop at the first sign of lag, abnormal heat, or a reboot, and write down the phase, the clock reading, and the GPS word on screen. Do not record coordinates or individual pulse numbers.

## Install

App id **29566**, name FORREF, version **1.0.2**. This is not sensor lab app id 30101.

1. On the phone paired to the Bip 6, open the Zepp app with developer mode available.
2. Scan the QR in `PREVIEW_QR.txt`. Zeus printed the expiry `2026-11-26 21:26:56` on the UTC build clock, which is **23:26 Europe/Bucharest on 26 Nov 2026**.
3. If that QR has expired, from `apps/forref_watch_zepp` run `zeus preview -t "Amazfit Bip 6"` and scan the new code. Confirm the label is `FORREF - 1.0.2` and the device is Amazfit Bip 6.
4. The side package is `29566-FORREF-1.0.2-20261119212654.zab`, sha256 `bfcefa1e6fca63a3c272ed40e2c8e66210f3146141a524cd3d899b5d87568bed`. It is not in git.
5. Cold-launch FORREF. The boot log, if captured, should contain `build=live-tel-003 rev=62f57dabe5d523bdc5fd0e6833331bdde13c7468`.

## Steps

1. At READY, the screen must open without waiting for GPS or heart rate.
2. Press KICK-OFF without waiting for a fix. The match clock must advance immediately. Heart rate may read `HR ...` / `PULS ...` until a valid sample, then `HR 142 bpm` style text. GPS may read `GPS ...` and later `GPS OK`. A number must not appear for a stale or last-known pulse.
3. Walk a short known section in the first half. Record only the displayed distance and whether it moved. The line is experimental (`~` before the kilometers). `— km` means no anchor yet, which is different from `~0,00 km` / `~0.00 km`.
4. End the first half. Walk during HALF-TIME. The two-decimal total must stay unchanged.
5. Start the second half and walk again. The first fix after the whistle must not jump the total by the half-time walk. The total must be first half plus second half.
6. Pause, walk, resume. The pause walk must not change the total. Open Match Controls, open an event, and return to Live. The clock must keep running and the distance must not jump.
7. Full time freezes the distance. Leave the app on that screen briefly. Confirm it does not restart and does not heat.
8. Screen-off sampling is a separate later check. Do not infer it from the clock still being on screen.

## Record

Version, boot revision, Pass/Fail per step, the GPS word, and the displayed first-half, second-half, and total distance. No raw coordinates. No pulse log. Any failure stays a blocker.
