# MOBILE 004 Probe B — offline path from the Side Service to the Flutter payload

Status: investigated. Not implemented. Not a pass.

Probe A’s Side Service holds a fixed body compiled into `app-side/index.js`. It does not read the FORREF Flutter app.

## What the platform allows

The Side Service runs inside the official Zepp phone app. Its documented peers are the watch Device App, over the Zepp Bluetooth session, and an external server, through the Fetch API. It has no API that opens another Android app’s files.

The Flutter configuration is in the phone app’s private store, `ref_app_matches` under the app support directory. The Zepp app process cannot read that SQLite file.

## Offline options that stay unbuilt

A local bridge would have to be something the Side Service can already call without a cloud host. The only documented call that leaves the Zepp app is Fetch. A loopback address on the phone would still be an unproven use of that call, and it needs the Flutter app to be serving the payload while the Zepp app is the process making the request. That bridge is not in this branch.

Cloud synchronization is not a substitute. It is not approved for this probe.

## Blocker

**LOCAL GATE REQUIRED** before any Probe B code. The missing proof is a Side Service request that returns the Flutter match-configuration payload while the phone has no route to a cloud host. Until that trace exists, the watch cannot be said to hold the match the phone saved.
