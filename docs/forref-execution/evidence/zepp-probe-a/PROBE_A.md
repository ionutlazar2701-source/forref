# MOBILE 004 Probe A — static configuration on the watch

Branch: `cursor/forref-mobile-004-zepp-probe-a-0e7d`

Base: `cursor/clock-004-integration-4ae8` at `d11e9ad873d2c74925da073ea91257e60a3b9445`.

The match clock modules are unchanged. The package identity is app `29566`, version `1.0.12`.

## What the probe does

Home has one added entry, Probe A. That page asks the Zepp Side Service for `GET_CONFIGURATION`. The Side Service answers with a fixed body:

- `payloadVersion` 1
- `probe` `A`
- `matchId` `probe-a-static`
- `homeTeamName` `North`
- `awayTeamName` `South`
- `source` `side-service-static`

The watch checks the content hash, writes `forref_probe_a_config.json`, reads it back, and sends `CONFIGURATION_STORED`. The Side Service records that receipt only when the version, match id, and hash match the static body. The page log is `FORREF_PROBE_A stored=yes` or `stored=no`.

The body is not the Flutter match, not a Match Record, and not the match clock. A hash mismatch, an unknown version, or a failed readback leaves no receipt.

## Hardware result

**LOCAL GATE REQUIRED.** This cloud run has no Amazfit Bip 6 and no Zepp Developer Mode session. Node tests of the exchange are not a device pass.

## Install on the Bip 6

1. Pair the Amazfit Bip 6 with the official Zepp app.
2. In the Zepp app, enable Developer Mode for this mini program.
3. From `apps/forref_watch_zepp`, with Zeus CLI logged in, run `zeus preview -t "Amazfit Bip 6"`. This cloud host has no Zeus CLI, so no `.zab` and no QR were produced here. The preview replaces app `29566`. Keep the CLOCK-004 `1.0.11` package if you still need that exact build.
4. Open FORREF. The existing Home, Live, and clock paths stay in the package.
5. Open Probe A while the phone’s Zepp app is running and the watch is connected.
6. The page should show STORED. In the developer log, the lines are `FORREF_PROBE_A side method=GET_CONFIGURATION disposition=payload`, then `FORREF_PROBE_A stored=yes detail=` followed by the 8-character hash, then `FORREF_PROBE_A side method=CONFIGURATION_STORED disposition=recorded`.
7. NOT STORED, or a log of `stored=no`, is a fail. Copy that log.

A simulator preview does not count.

## Node tests

`npm test` in `apps/forref_watch_zepp` covers the static exchange, the hash refusal, and the readback refusal. Those tests do not open Bluetooth.
