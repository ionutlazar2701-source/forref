# MOBILE 003 — configuration payload audit and Zepp delivery contract

Status: proposal. No Zepp code, payload version 2, sporting-event replication, or clock change is included.

Phone persistence evidence stays in [MOBILE_003_ANDROID_BASELINE.md](MOBILE_003_ANDROID_BASELINE.md). That result is a physical Android functional pass. It is not a watch test.

## Payload v1 audit

`MatchConfigurationPayload` version 1 projects fixture identity, team ids and names, half length, extra-time settings, and crew names from the legacy match document.

The preparation screen also stores squad players on that same document. Each added player receives a new UUID from `clientId()` as `Player.playerId`, plus an optional shirt number and an optional name. `Player.role` exists on the model as starter or substitute. The add-player dialog does not set a role. After force-stop, the Founder confirmed that players, including a modified player, were still present. Those rows are in the legacy match document. Version 1 does not copy them.

A watch pre-match surface needs a stable row for each prepared player: which team, an opaque id, the shirt label, and the display name. Version 1 cannot supply that.

Identity rules for any later version:

- `Player.playerId` is the squad token already stored on the phone. It is scoped to that legacy match document.
- Shirt number is a label. Two players may show the same number. The number does not select or merge them.
- `MatchParticipantId` is a Match Core token. The phone preparation flow does not mint one. A configuration payload must not present `Player.playerId` as a `MatchParticipantId`.
- Crew fields in version 1 are names. They have no stable id.

Version 1 remains the implemented projection. The next payload version, when implemented, adds squad rows and nothing from the match record stream:

| Field | Source | Meaning |
| --- | --- | --- |
| `squadPlayerId` | `Player.playerId` | Opaque squad token |
| `teamId` | home or away `teamId` | Team that owns the row |
| `shirtNumber` | `Player.shirtNumber` | Optional label |
| `displayName` | `Player.name` | Optional label |

Score, events, status, clock, and sync state stay out of the payload.

## Supported Zepp path

Zepp’s published mini-program architecture has three parts. The Device App runs on the watch. The Settings App and the Side Service run inside the official Zepp phone app. Bluetooth is between the Device App and the Side Service. The Settings App does not reach the Device App except through the Side Service.

The raw channel carries binary buffers. Zepp’s ZML library is the supported session layer:

- The Device App calls `this.request`. The Side Service answers in `onRequest`.
- The Side Service calls `this.call`. The Device App receives `onCall`.

The Side Service’s documented way to reach a program outside the Zepp app is the Fetch API. Zepp does not document a Bluetooth API whose peer is the FORREF Flutter process. `@zos/ble` on the watch is the Device App end of the Side Service channel.

There is no Zepp app in this repository. Platform order still places a Zepp client after Wear OS, watchOS, and Garmin. This document does not start that client.

## Smallest delivery contract

```text
FORREF phone
  writes the legacy match document
  projects MatchConfigurationPayload
Zepp Side Service, inside the official Zepp app
  holds one current configuration projection
Zepp Device App
  pulls that projection and stores it as watch-local configuration
receipt
  returns along the same path
```

The phone remains the only writer of the match document. The watch stores a disposable configuration projection. Delivery does not create a Match Record, does not grant capture authority, and does not move the match clock.

Message sequence, using the documented request/response direction:

1. The Device App sends `this.request` with method `GET_CONFIGURATION`.
2. The Side Service responds with the current payload bytes and a content hash, or with disposition `empty`.
3. The Device App accepts the body only when the version is one it implements and the hash matches the body. It then replaces its stored configuration projection with the whole document.
4. The Device App sends `this.request` with method `CONFIGURATION_STORED`, the payload version, the match id, and the content hash.
5. The Side Service keeps that receipt. The phone may show that the watch stored the configuration only after the phone bridge reads this receipt.

The same hash stored again returns the same receipt. An unsupported version, a hash mismatch, or a truncated body produces no receipt and leaves the watch’s previous configuration projection in place.

A Side Service `call` may tell an open Device App that a newer projection is waiting. The store receipt is still the `CONFIGURATION_STORED` request above.

That receipt means the Device App stored this configuration projection. It is not a D1 Saved acknowledgement.

## Hardware blockers

These block implementation of the delivery path:

- **LOCAL GATE REQUIRED.** No Zepp watch, Zepp app session, or mini-program install was part of the Android persistence pass.
- The FORREF process is not the documented Bluetooth peer. A bridge from the Flutter app into the Side Service still has to be proven on the Founder’s phone with the official Zepp app installed and paired. Fetch-to-cloud is the documented external Side Service path and is outside the offline touchline case.
- The official messaging page does not publish a payload size ceiling. A squad-sized message must be measured on a device before a chunking scheme is chosen.
- One Zepp package targets declared device sources. A build for one Amazfit model does not cover the watch family.
- The Zepp app owns the Bluetooth session and the Side Service lifetime. A receipt cannot be inferred from the phone having sent bytes.
