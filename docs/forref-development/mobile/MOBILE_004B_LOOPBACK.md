# MOBILE 004B — B0 local configuration bridge

Status: implemented on `cursor/forref-mobile-004b-loopback-0e7d`. Automated loopback checks pass. A physical phone check is still **LOCAL GATE REQUIRED**. This branch does not include the Zepp Side Service.

Base: PR #67, `cursor/forref-mobile-003-android-sync`.

## What it serves

Settings, in a debug build only, lists saved matches. The user selects one and taps **Start local bridge**. The phone then listens on `127.0.0.1:47221` and answers `GET /match-configuration` with the version 1 `MatchConfigurationPayload` read from the local match database on that request.

The response is the configuration projection. It does not include score, events, status, or sync. Editing the saved match changes the next response. Choosing another saved match changes the next response. A missing match answers `404` with `{"disposition":"missing"}` and no team names.

The server does not start at launch. Release builds do not create it. A failed bind stays on port `47221` and does not choose another port. The listen address is `127.0.0.1`.

Log lines:

- `FORREF_B0 listening=127.0.0.1:47221 match=<match id>`
- `FORREF_B0 served status=200 match=<match id>`
- `FORREF_B0 stopped match=<match id>`

## Physical check

This check uses a debug install of this branch. A release build has no bridge.

1. Install the debug app and save a match with team names that are not North and South.
2. Open Settings, select that match, and tap Start local bridge. The page should say `Listening on 127.0.0.1:47221`.
3. From the computer, with the phone connected:

```
adb forward tcp:47221 tcp:47221
curl http://127.0.0.1:47221/match-configuration
```

4. The JSON `homeTeamName` and `awayTeamName` are the names saved on the phone. Change those names in the app, leave the bridge running, and curl again. The new names are the next body.
5. Tap Stop local bridge. The next curl fails to connect.

`curl` from the computer reaches the phone only through `adb forward`. It does not show that the Zepp app can fetch the same URL. That is B1.
