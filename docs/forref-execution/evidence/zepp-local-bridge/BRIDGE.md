# MOBILE 004B — watch side of the local bridge

Branch: `cursor/forref-mobile-004b-watch-bridge-0e7d`

Base: PR #68, `cursor/forref-mobile-004-zepp-probe-a-0e7d`.

Package `29566`, version `1.0.13`. The match-clock modules are unchanged. Probe A remains the static side-service page.

## B1

Home has one added entry, PHONE CONFIG. That page asks the Side Service for `GET_LOCAL_CONFIGURATION`. The Side Service calls `http://127.0.0.1:47221/match-configuration` through its Fetch API. A version 1 phone payload is checked, hashed, and sent to the watch. The watch writes `forref_local_bridge_config.json` and reads it back.

The page paints the `homeTeamName` and `awayTeamName` from that payload. A null name is `NAME NOT SET`. The page does not contain a compiled team-name fallback.

A refused body, a connection error, or a `404` is `unavailable`. The watch does not replace a previously stored phone payload. The page then shows NOT STORED, the saved names, and SAVED COPY.

## B2 — physical checks, not yet run

These require the debug phone build from the B0 branch and this `1.0.13` package on the Amazfit Bip 6. Node tests are not a device pass.

1. On the phone, save a match whose team names are not North and South. Settings, select it, start the local bridge. The phone says `Listening on 127.0.0.1:47221`.
2. Keep the phone app process alive. In the Zepp app, install this package with `zeus preview -t "Amazfit Bip 6"` after `npm install` in `apps/forref_watch_zepp`.
3. Open PHONE CONFIG. The names on the watch are the names saved on the phone, and the status is STORED. Log line: `FORREF_B1 stored=yes` with those names.
4. Change the saved names on the phone. Open PHONE CONFIG again. The new names replace the old ones.
5. Stop the phone bridge, or force-stop the phone app. Open PHONE CONFIG. The status is NOT STORED. If a previous payload was stored, the old names remain and the page says SAVED COPY. The names are not North and South unless those were the saved names.
6. Turn off Wi-Fi and mobile data on the phone, start the bridge again, and open PHONE CONFIG. STORED with the saved names is the offline check. A cloud host is not part of this path.

B1 and B2 stay **LOCAL GATE REQUIRED** until those lines exist from the Bip 6. Do not merge.
