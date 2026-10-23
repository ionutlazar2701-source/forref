# MOBILE 001 handoff

Branch: `cursor/forref-mobile-command-skeleton-001`

Start SHA: `03d2b735a923f8ebd54d918e0488116e7ecb88ba`

Parent tip on `cursor/forref-simulator-s2-5-product-operations` had moved past that SHA with research-only commits. This branch starts at the S2.5R SHA. PR #27 was not merged. `packages/forref_match_core`, `packages/forref_match_persistence`, `packages/match_core`, and `research/` are not part of the change.

Contract: [MOBILE_001_COMMAND_FOUNDATION.md](MOBILE_001_COMMAND_FOUNDATION.md).

## What landed

- Typed mobile command envelope, stable `commandId`, freeze, status, dispatcher, and authority gate.
- Phone-only runtime. Kick-off and Goal on Live go through that runtime into the existing commit boundary.
- Catalog: kick-off and goal available; yellow, both send-offs, substitution, full time, and finish match are not yet cut over.
- Companion read model, protocol version 1, `NoPeerTransport`, and a simulated handshake used by tests.
- Devices route and a live command-availability panel. No companion stays explicit. A fixture companion does not control the match.
- Goal draft may hold a scorer label and a display time. Those fields never enter `GoalCommandPayload`.

## What did not land

Real sync, Bluetooth, Wear OS Data Layer, WatchConnectivity, Huawei connectivity, Garmin, Zepp, cloud sync, Firebase live sync, authority transfer, and a second sporting writer.

## Firewall

| Path | Expected |
| --- | --- |
| `packages/forref_match_core` | Empty diff against the start SHA |
| `packages/forref_match_persistence` | Empty diff against the start SHA |
| `packages/match_core` | Empty diff |
| `research/` | Empty diff |

## Verification

Record the exact `flutter analyze`, `flutter test`, Android debug build, and `./tool/verify_cloud.sh` results in the wave handoff message. Do not treat a Linux run as an iOS build or as AppGallery certification. `tool/cloud_bootstrap.sh` may still fail with `Permission denied`. Report that line. Do not chmod the script to hide it.
