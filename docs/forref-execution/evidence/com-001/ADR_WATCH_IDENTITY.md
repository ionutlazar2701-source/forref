# ADR: Watch identity events

Status: detection-only. Not a hardware certification. Not an authority handoff.

## Decision

FORREF Mobile stores identity history in `watch_identity_events` inside the same SQLite file as `watch_provision_stages`. The table is append-only. Triggers abort `UPDATE` and `DELETE`. There is no foreign key to `watch_provision_stages`, because cancel deletes that stage row. There is no `recovery_authorized` event kind. `authorizeInstallationEnrollment` returns `authorization-unavailable` and writes nothing.

Three facts stay separate:

- The platform candidate is a SHA-256 digest. The raw platform id is not sent, stored, or logged.
- The installation id is the FORREF software UUID.
- The match writer is `watch_provision_stages.writer_device_id` and, after lock, `generation_one_authority_roots.device_id`.

## Digest

Zepp OS API_LEVEL 4.2 documents `getDeviceInfo().uuid` as a string, “32 bytes in length” ([getDeviceInfo](https://docs.zepp.com/docs/reference/device-app-api/newAPI/device/getDeviceInfo/), Chinese source `长度 32 字节`). The page does not say hexadecimal and does not say 64 characters. Permission `data:os.device.info` is already on the watch manifest.

Build `1.0.31` required `[0-9a-fA-F]{64}`. On the Amazfit Bip 6 the founder recorded `FORREF_WITNESS kind=absent class=unsupported-or-invalid len=32`. That JavaScript length matches the documented 32-byte string and falsifies the 64-character assumption. The log did not record the alphabet, so length 32 is not by itself a character-set proof. `1.0.30` was uninstalled before that install, so `FORREF_IDENTITY case=fresh created=1` is a new installation, not a failed in-place upgrade.

Version 1 is unchanged. Its input is the UTF-8 bytes of `forref-candidate-v1:` plus 64 lowercase hex characters. Stored version-1 rows are not recomputed. A version-1 digest is not a version-2 digest.

Version 2 accepts a JavaScript string of exactly 32 code units, each in 0..255. That is the documented 32-byte string. When every byte is ASCII hex, those bytes are lowercased. Any other byte is hashed unchanged. The input is the UTF-8 bytes of `forref-candidate-v2:` followed by those 32 bytes. A code unit above 255 is `non-byte32` and is not hashed. Any other length, a missing value, or a non-string stays without a digest.

The witness log names `class` (`hex32` or `bytes32`), `len`, `utf8`, `hex`, `ascii`, `ctrl`, `preview`, and `v`. It does not contain the platform string or the full digest. `hex=1` means the 32 bytes were ASCII hex. `hex=0` means they were not. That profile is how the next hardware log shows the alphabet without another research build.

Shared vectors, checked by the Dart and JavaScript tests:

- Version 1 platform hex: `00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff`
- Version 1 digest: `26c41755b96d53042c3b66daefff51082ea5ec9c70c4d4c6e0fffb6bde19954c`
- Version 1 preview: `26c4...954c`
- Version 2 platform hex: `00112233445566778899aabbccddeeff`
- Version 2 digest: `3be95c18a1a81de5a4165d603696e4fe42725cf7c1bc54b5807e1a6ad46358a0`
- Version 2 preview: `3be9...58a0`
- Version 2 opaque bytes: 31 times `0x11`, then `0x80`
- Version 2 opaque digest: `cc618c08acccf2e1aeebcaa197faf07a188a72bf7de0088dfeb535372581f17a`

An existing `watch_identity_events` table whose check allows only digest version 1 is copied into a table that allows versions 1 and 2. The copy keeps every column value. `DROP TABLE` is the schema change. Row `UPDATE` and `DELETE` stay aborted. A version-1 digest is not rewritten as version 2.

SHA-256 here is a correlation handle. It is not encryption, anonymity, possession proof, or device authentication. HMAC was not used. A key stored in this database travels with every copy. A key stored only in Android Keystore would make the same watch unrecognizable after a phone reinstall, which is the case this table exists to detect.

## Events

| Kind | When | Eligible for a later match |
| --- | --- | --- |
| `prepare_intent` | The stage insert commits. Grade `typed-installation`. Digest is null. | No |
| `watch_witness_observed` | A pending request from the current writer carries a valid digest. Grade `watch-message-observed/unverified-device-identity`. | Yes, for that match and that writer |
| `candidate_seen` | A different installation presents that same digest for the selected match. | No. The response is `recovery-required`. |

A stage that already exists and has no witness projects as `unverified-pre-registry`. No synthetic witness is inserted. Cancel removes the stage and leaves the events. The projection then becomes `absent`.

Order is `event_sequence`. `created_at_ms` is audit only. The same `(match_id, protocol_request_id, event_kind)` returns the stored row. The same request with a different digest returns `replay-conflict` and writes nothing.

A digest match is scoped to the selected match. The phone does not search other matches by digest. Two different digests for the current writer withdraw eligibility (`candidate-conflict`). Model-only and absent evidence return `identity-evidence-unavailable`. A different digest returns `installation-conflict`. A request with no witness object keeps the existing `installation` refusal.

## Witness envelope

Optional object on the existing `operation=pending` body. It is not part of `forref.watch-provision.v1` and does not change the content hash.

```text
schema = forref.identity-witness.v1
candidateKind = platform_uuid
candidateDigest = 64 lowercase hex characters
digestVersion = 1 or 2
evidenceGrade = watch-message-observed/unverified-device-identity
sourceBuilds = diagnostic, at most 160 characters
```

A `uuid` or `platformUuid` field makes the witness malformed. On the current writer, a malformed witness does not change the prepared response and stores no event. On another installation, it returns `identity-evidence-unavailable`.

## Listen

Settings in a debug build has Listen. It calls `start` for the selected match and does not call `prepareSavedMatch`. GET `http://127.0.0.1:47221/` returns `disposition=listening` and `writes=0`. That is a software check. A Zepp POST remains a hardware gate. Localhost is not a production transport.

## N3 items

| Item | Verdict |
| --- | --- |
| N3.0 six contracts | ACCEPT |
| N3.1 hex64 only; no silent Unicode folding | MODIFY. API_LEVEL 4.2 and the Bip 6 both give a 32-byte string. Hex64 remains version 1. A 32-byte string is version 2. Code units above 255 and every other length stay unhashed. Version-1 rows are copied, not reinterpreted. |
| N3.2 evidence grade string | ACCEPT |
| N3.3 listener independent of Prepare | ACCEPT. MODIFY the message shape: the witness rides on `GET_WATCH_PROVISION_V1`, which the Side Service already forwards. A second operation would not. |
| N3.4 denial rows and a synthetic pre-registry row | MODIFY. Refusals are not stored. An old stage with no witness is `unverified-pre-registry` in the projection. |
| N3.5 separate message types | MODIFY, same reason as N3.3. The reason enum is implemented. |
| N3.6 authorization unavailable and no writer change | ACCEPT |
| N3.7 H1–H11 | ACCEPT as `LOCAL GATE REQUIRED` |

## Code

- `packages/forref_match_persistence/lib/sqlite_durable_match_store.dart`
- `packages/forref_match_persistence/lib/watch_identity.dart`
- `packages/forref_match_persistence/test/watch_identity_test.dart`
- `apps/referee_phone/lib/officiate/watch_provision_debug_bridge.dart`
- `apps/referee_phone/lib/features/settings/watch_provision_debug_section.dart`
- `apps/forref_watch_zepp/utils/identity_witness.js`
- `apps/forref_watch_zepp/page/gt/provision/index.page.js`
