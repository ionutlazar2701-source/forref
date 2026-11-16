# Provisional candidate protocol

Namespace: `forref_capture_bridge_001`.
File: `forref_capture_bridge_001.journal`.
Schema: `1`.
Module: `apps/forref_watch_zepp/utils/capture_candidate.js`.
Watch adapter: `apps/forref_watch_zepp/utils/capture_device.js` (`openSync`, `writeSync`, `readSync`, `closeSync`, `statSync`).

The journal is append-only text. The first line is a header. Each later line is `CB1|E|<sequence>|<byteLength>|<fnv1a>|<json>`. The checksum covers the envelope JSON. A second checksum covers the canonical payload. Order is `localSequence`, never `createdUtcDiagnosticOnly`. That UTC field is stored as `null` from the watch screen.

## Admission states

These are not `DurableCommitSuccess` and not Match Report classifications.

| State | When |
| --- | --- |
| `VALID_STRUCTURED_CANDIDATE` | Fixture mode and a goal whose team token maps to `SIM_TEAM_HOME` or `SIM_TEAM_AWAY`. A direct send-off or second caution reaches this state only when the caller supplies the stable ids the payload requires. The watch buttons do not supply them. |
| `INCOMPLETE_IDENTITY` | Goal without the fixture, any yellow, any substitution, or a send-off missing its ids. The canonical payload uses `null`, not `HOME`, `AWAY`, or a shirt number. |
| `UNSUPPORTED_SEMANTICS` | The red button. Kind `RED_BUTTON`, `sendOff: false`. |
| `CONFLICT` | The same `captureIntentId` is replayed with a different canonical payload. The file is left unchanged. |
| `CORRUPT` | The journal prefix, checksum, sequence, or schema does not validate. Append is refused. |
| `UNVERIFIED_STORAGE` | The write throws, returns a short byte count, or the following full read does not match. |

## Idempotency and ids

`captureIntentId` and `candidateId` are the same string. A caller may pass an id matching `[A-Z0-9_-]{4,64}`. Otherwise the journal allocates `CB1-<deviceId>-<sequence>` from the next sequence. The id is not a UTC timestamp. The same id and the same payload return the existing line and do not append. A new deliberate capture uses the next sequence.

## Capacity

Default bounds are 32 entries and 16384 bytes. A further append returns `CAPACITY`, writes nothing, and leaves the earlier lines in place. There is no rotation and no startup deletion.

## What the screen may say

| Moment | English | Romanian |
| --- | --- | --- |
| Before capture | `DEMO — NOT RECORDED` | `DEMO — NEÎNREGISTRAT` |
| Validated readback of a structured candidate | `LOCAL CANDIDATE #N — NOT A MATCH RECORD` | `CANDIDAT LOCAL #N — NU E RECORD DE MECI` |
| Missing identity | `INCOMPLETE — NOT A MATCH RECORD` | `INCOMPLET — NU E RECORD DE MECI` |
| App recreation of a readable journal | `LOCAL CANDIDATE RECOVERED — D1 UNVERIFIED` | `CANDIDAT LOCAL RECUPERAT — D1 NEVERIFICAT` |
| Write or journal failure | `CAPTURE FAILED / JOURNAL UNVERIFIED` | `CAPTURĂ EȘUATĂ / JURNAL NEVERIFICAT` |

The screen does not say Saved, official, match report, or a numeric score, and it does not render an exact match minute. Live A/C and the clock files are unchanged. The review actions stay on the existing review route. The app still has 23 routes.
