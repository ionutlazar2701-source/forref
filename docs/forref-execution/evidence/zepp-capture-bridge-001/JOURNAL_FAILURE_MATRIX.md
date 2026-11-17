# Journal failure matrix

Command: `npm test` in `apps/forref_watch_zepp`.
The capture cases are `test/capture_candidate.test.js`. The adapter under test is the in-process `memoryAdapter`. It can append, throw before mutation, or return a 4-byte short write.

| Case | Result |
| --- | --- |
| Fixture goal payload | `VALID_STRUCTURED_CANDIDATE`. Payload team id is `SIM_TEAM_HOME`. No `HOME` display token and no shirt number. |
| Fixture off, HOME and AWAY goals | `INCOMPLETE_IDENTITY`. `matchTeamId` is null. |
| Yellow, substitution, second caution without dependencies | `INCOMPLETE_IDENTITY`. |
| Red button | `RED_BUTTON`, `UNSUPPORTED_SEMANTICS`, `sendOff: false`. |
| Two yellow appends | Two yellow lines. No send-off kind. |
| Append, close the journal object, open another on the same adapter | Same ids and sequences `1`, `2`. Evidence on read is `RECREATION_RECOVERED`. `d1` is `HARDWARE_D1_UNCERTIFIED`. |
| Same id, same payload | `duplicate`, one line. |
| Same id, other team payload | `CONFLICT`. The first payload bytes stay. |
| Short write after one valid line | `SHORT_WRITE`, `UNVERIFIED_STORAGE`. The first id remains in `readablePrefix`. A later append is refused and does not add its id. |
| Throw before any byte | `WRITE_EXCEPTION`. The buffer stays empty. The same id then appends once. |
| Torn tail, checksum damage, sequence gap, schema 2 | `ok: false`. Append does not change the bytes. |
| `maxEntries: 2` | Third append is `CAPACITY`. The first two ids remain. |
| Same yellow, retry tap | One line. The second call is `IDEMPOTENT`. |
| Same yellow, new-capture tap | Two lines. The payloads match and the ids differ. |
| `stat` throws `ENOENT` or returns null | The reader reports `absent` and does not open the file. |
| `stat` or `read` throws `EIO` | `READ_EXCEPTION`, `UNVERIFIED_STORAGE`. `append` is not called. |
| The capacity re-read throws | `READ_EXCEPTION` before any append. The attempted id is kept for a retry. The file stays empty. |
| Match filter | `SIM_MATCH_002` matches nothing. The fixture match does not absorb the unprovisioned line. |
| Empty id after a verified yellow, the pre-fix page path | A second append allocates sequence `2` and a different id. |
| Same bytes, `decideCaptureTap` with no open id | `REFUSE` / `RECONCILE_REQUIRED`. The buffer is unchanged. A different shirt token still refuses, because the yellow payload does not carry it. |
| Bind the recovered id, then retry | No append on bind. The retry is `IDEMPOTENT` and the id stays. |
| `fresh: true` after that bind | Sequence `2`, a different id, still `YELLOW`, no send-off kind. |
| Open yellow id replayed as a goal | `CONFLICT`. The first payload bytes stay. |
| Corrupt prefix | `decideCaptureTap` returns `REFUSE`. A following append does not change the bytes. Bind returns not ok. |
| Read throws after the entry bytes are written | `READBACK_MISMATCH`, `ok: false`, `UNVERIFIED_STORAGE`, attempted id kept. A later empty-id decision refuses. Replaying the attempted id is `IDEMPOTENT` and does not append. |

The Dart reader `apps/referee_phone/test/capture_candidate_envelope_test.dart` parses `test/fixtures/valid_goal_envelope.json` and checks the wire fields only. It does not call the phone commit boundary and does not execute the JavaScript app.
