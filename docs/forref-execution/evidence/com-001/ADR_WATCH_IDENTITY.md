# ADR: Watch identity events

Status: detection-only. Not a hardware certification. Not an authority handoff.

## Decision

FORREF Mobile stores identity history in `watch_identity_events` inside the same SQLite file as `watch_provision_stages`. The table is append-only. Triggers abort `UPDATE` and `DELETE`. There is no foreign key to `watch_provision_stages`, because cancel deletes that stage row. There is no `recovery_authorized` event kind. `authorizeInstallationEnrollment` returns `authorization-unavailable` and writes nothing.

Three facts stay separate:

- The platform candidate is a SHA-256 digest. The raw platform id is not sent, stored, or logged.
- The installation id is the FORREF software UUID.
- The match writer is `watch_provision_stages.writer_device_id` and, after lock, `generation_one_authority_roots.device_id`.

## Digest

Version 1 input is the UTF-8 bytes of `forref-candidate-v1:` plus 64 lowercase hex characters. Only a string matching `[0-9a-fA-F]{64}` is folded to lowercase. Any other value, including a missing `uuid` and API evidence below 4.2, is `unavailable` or `unsupported-or-invalid`. It does not become a digest.

Shared vector, checked by the Dart and JavaScript tests:

- Platform hex: `00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff`
- Digest: `26c41755b96d53042c3b66daefff51082ea5ec9c70c4d4c6e0fffb6bde19954c`
- Log preview: `26c4...954c`

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
digestVersion = 1
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
| N3.1 hex64 only; no silent Unicode folding | ACCEPT |
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
