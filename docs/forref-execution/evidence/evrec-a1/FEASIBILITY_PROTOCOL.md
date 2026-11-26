# EVREC-A1R provisioning activation

State: **TRANSPORT GATE FAILED** for live Flutter-to-Zepp delivery. **D1 NOT CERTIFIED**. This change does not claim Saved, and it does not show a certified Match Ready state.

## Simulated and physical

Simulated, and covered by the store-port tests:

- The phone stores `CONFIG_PREPARED` and does not insert a generation-1 root.
- The phone inserts that root only inside the `PHONE_AUTHORITY_LOCKED` transaction, and only after a verified watch receipt and `transportAvailable`.
- The watch stays at `WATCH_CONFIG_VERIFIED` until a durable lock receipt is read back as `WATCH_ACTIVATED`.
- `mayAppendSportingRecords` is true only in `WATCH_ACTIVATED`.
- `saved` and `d1Certified` stay false.
- Closing and reopening the SQLite file keeps the locked root. A changed installation UUID, a missing root, a mismatched marker, and an unverifiable read fail closed.

Physical, and not run:

- Amazfit Bip 6 receipt of a provision.
- Side Service delivery inside the Zepp phone app.
- Power loss, process kill on the watch, and Bluetooth drop on hardware.
- D1 certification.

`transportAvailable` in these tests is a boolean on the decision. It is not a radio and not a new bridge.

## Staged protocol

`CONFIG_PREPARED` → `WATCH_CONFIG_VERIFIED` → `PHONE_AUTHORITY_LOCKED` → `WATCH_ACTIVATED`.

Failure states remain `CONFIG_INVALID`, `AUTHORITY_CONFLICT`, `STORAGE_UNVERIFIED`, and `RECOVERY_REQUIRED`.

Display strings:

- `CONFIG PREPARED — AUTHORITY NOT LOCKED`
- `CONFIG VERIFIED — NOT ACTIVATED`
- `PHONE AUTHORITY LOCKED — D1 UNCERTIFIED`
- `WATCH ACTIVATED — D1 UNCERTIFIED`

A valid document does not by itself commit the phone's generation-1 watch-authority root. After `CONFIG_PREPARED`, the phone refuses its own sporting writes for that match. After `PHONE_AUTHORITY_LOCKED`, that refusal still holds. An interrupted verify can be finished with the same canonical document. It does not replace the stored root. A different document is refused.

Loading stored provisioning requires the current persistent installation UUID. An identity mismatch leaves the stored root in place and returns `AUTHORITY_CONFLICT`.

## Transport sources, not cherry-picked

These tips were read and were not merged into this branch. Their clock, Home, and probe edits stay on their own branches.

| Source | Branch | SHA |
| --- | --- | --- |
| MOBILE-003 | `cursor/forref-mobile-003-android-sync` | `19cab68de83ad49904822d12ac18cbb39db97f61` |
| Probe A | `cursor/forref-mobile-004-zepp-probe-a-0e7d` | `4f25df85f0f0a9e06e0c28d518ca9bbad71484e0` |
| MOBILE-004B loopback | `cursor/forref-mobile-004b-loopback-0e7d` | `973aee4646c56426ac60ef8e189927ffca026cfe` |
| MOBILE-004B watch bridge | `cursor/forref-mobile-004b-watch-bridge-0e7d` | `cd64f18ce6167b91ed0d31a6ccc1cdb293389569` |

MOBILE-003 records that `MatchConfigurationPayload` v1 is a local phone projection. It is not a Match Record and it is not sent to a watch. The documented Zepp path is a Device App plus a Side Service inside the official Zepp phone app, using ZML. The Flutter process is not the Bluetooth peer. That pass is `LOCAL GATE REQUIRED`.

Probe A is a static Side Service screen. Founder evidence on that branch is `PROBE A / STORED / STATIC SIDE SERVICE` at 21 Nov 2026, 18:02 Europe/Bucharest. It is not this provision document.

The 004B loopback serves a saved match at `http://127.0.0.1:47221/match-configuration` from `apps/referee_phone/lib/officiate/local_configuration_bridge.dart`. That server is debug-only.

The 004B watch file `apps/forref_watch_zepp/utils/local_bridge.js` pulls that payload with `GET_LOCAL_CONFIGURATION` and answers `LOCAL_CONFIGURATION_STORED` after a write and readback. The payload is `MatchConfigurationPayload` v1. Its hash is FNV-1a, not SHA-256. The same branch also changes clock, Home, and probe files. Those files were not copied.

## Minimum integration still required

One future message must carry the canonical `forref.watch-provision.v1` bytes, not payload v1. It can reuse the 004B request, readback, and stored-ack shape, with this module's SHA-256 and the persistent installation UUID. The Side Service still has to live in the Zepp phone app. The loopback is not that bridge. No such message is implemented here.

## Bip 6 steps, after that message exists

1. Keep the v1.0.14 clock recovery package until a later preview is issued for this module. This commit does not replace that package and does not change CHRON-004 or the Home design.
2. Generate one installation UUID on the watch and keep it. Do not substitute `deviceSource`.
3. Deliver one canonical document and stop before the activation receipt. The watch must show `CONFIG VERIFIED — NOT ACTIVATED` and must not append a sporting record.
4. Lock the phone, then kill and reopen the phone app. The watch writer must still be the root, and a phone goal must still be refused.
5. Deliver the durable lock receipt. Only then may the watch show `WATCH ACTIVATED — D1 UNCERTIFIED`.
6. Kill and reopen the watch. The activated marker must load only when the installation UUID still matches.
7. Repeat the same activation. The marker must not change. A different hash must be refused.

Do not run those steps against this commit and call them passed. The live bridge is not in this branch.
