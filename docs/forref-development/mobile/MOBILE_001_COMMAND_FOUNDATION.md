# MOBILE 001 — command foundation

Phone command skeleton for the existing Flutter app in `apps/referee_phone`. This wave does not implement transport, pairing radios, or authority transfer.

Start SHA: `03d2b735a923f8ebd54d918e0488116e7ecb88ba` (S2.5R). Branch: `cursor/forref-mobile-command-skeleton-001`. Production Match Core packages are unchanged.

## Purpose

The phone is the referee's Match Control Center, the full fallback instrument, and the post-match record surface. A later certified watch may capture autonomously. The phone must keep working with no watch, and it must not become a second sporting writer beside that watch.

## Phone roles

| Role | This wave |
| --- | --- |
| Match Control Center | Existing setup, matches, and settings remain. Command availability and device readiness are visible on Live and Devices. Roster, crew, and competition completion stay for MOBILE 002. |
| Phone-only fallback | Kick-off and Goal still commit on the phone through `MatchApplicationBoundary`. Removing the peer adapter does not block that path. |
| Post-match control center | Score projection remains the production report content. Cards, send-offs, and substitutions are not synthesized into a report. Summary, notes, and export stay on their existing screens. |

The phone is not a permanent watch master, a remote button pad, a network authority, or a live dual writer.

## Command model

Three layers stay separate.

| Layer | Type | Meaning |
| --- | --- | --- |
| Intent | `MobileIntentDraft`, `GoalCaptureDraft` | Ephemeral selection. Scorer label and display match time may sit on the goal draft. |
| Command | `MobileCommandEnvelope` | Frozen request. Not Match Memory. |
| Record | Existing Match Records | Created only by the current production commit port after D1. |

Flow: UI → `MobileCommandPreparation` → `CommandAuthorityGate` → `MobileCommandDispatcher` → `MatchApplicationCommandWriter` → `MatchApplicationBoundary` → durable result → existing projection refresh.

`MobileCommandEnvelope` carries `commandId`, `matchId`, `commandType`, `origin` (`mobileUi`), `originDeviceId`, `createdAtLocal`, `schemaVersion` (1), and `payload`. Origin is where the request was formed. It is not sporting authority.

`commandId` is allocated by `UuidCommandIdSource` (tests may inject `SequenceCommandIdSource`). It is not a widget id and not a timestamp. The same activation keeps `commandId` and, for Goal, `captureIntentId`. A new tap calls `beginActivation()` and receives new ids. Transport retry must reuse the frozen envelope. The dispatcher does not allocate a new id.

Freeze is first-write-wins on `commandId` inside `MobileCommandPreparation`. A later change to the draft does not retarget that activation.

Status values: `draft`, `ready`, `dispatching`, `saved`, `failed`, `outcomeUnknown`, `unsupported`, `authorityUnavailable`. `saved` is recorded only after `MobileWriterSaved`, which the writer returns only for `DurableCommitSuccess`, `KickOffAuthorityCommitted`, or `KickOffAlreadyStarted`. `PeerTransportReceipt` has `notSent` and `outcomeUnknown` only. Enqueue on `MobileCommandOutbox` is not Saved.

A known failure may be dispatched again with the same `commandId` and the same canonical body. `outcomeUnknown` is returned again and the writer is not called. The same `commandId` with a different canonical body fails closed (`command_identity_conflict`) and does not write. Sporting idempotency stays the production capture-intent key. This layer does not add a second one.

## Availability and authority gate

`CommandAuthorityGate` answers only: may this device dispatch this command to the existing writer?

Order: not in `ProductionCommandCatalog` → `notYetCutOver`; `watchPrimaryFuture` → `authorityRequired`; `companionHoldsCaptureAuthority` → `authorityRequired` (`single_writer`), even if local capture is also true; local capture false → `authorityRequired`; otherwise `available`.

The gate does not mutate authority, does not transfer it, and does not read Bluetooth or connection state.

`AuthorityContinuity.afterPeerDisconnect` returns the same snapshot. Connection loss does not make the phone the writer and does not clear a companion authority flag.

`MobileCommandRuntime.phoneOnly` always installs `MobileAuthoritySnapshot.phoneOnly` (`localCaptureAuthorized: true`, `companionHoldsCaptureAuthority: false`, mode `phoneOnly`). `watchPrimaryFuture` is unreachable from that factory. It exists so tests can prove the gate refuses it.

The catalog may show Kick-off as unavailable after a phase hint says kick-off is already committed. That hint is display only. The dispatcher uses `evaluate`, so an already-started kick-off still reaches the boundary and comes back as the existing already-started result.

## Production commands

Cut over in this catalog:

| Command | Writer |
| --- | --- |
| Kick-off | `MatchApplicationBoundary.commitKickOff` |
| Goal | `MatchApplicationBoundary.commitGoal` |

Goal payload is `scoringTeamId` and `captureIntentId` only. `GoalCaptureDraft.scorerLabel` and `displayMatchTime` are dropped at freeze. They are not production Goal semantics.

Not cut over, and unable to reach the writer:

| Command | Reason |
| --- | --- |
| Yellow | `not_yet_cut_over` |
| Direct send-off | `not_yet_cut_over` |
| Second-caution send-off | `not_yet_cut_over` |
| Substitution | `not_yet_cut_over` |
| Full time | `not_yet_cut_over` |
| Finish match | `not_yet_cut_over` |

`commitMatchEnded` still exists on the boundary and is still called by the existing End Match control. The new envelope does not route Finish, because that commit needs a period-ended record id this layer does not invent. Yellow, send-off, and substitution payloads exist in Match Core and are not given new phone writers here. Research `SavedGoal`, `SavedCaution`, `SavedSendOff`, and `SavedSubstitution` are not imported.

Live still has legacy writers for setup, summary, added time, and non-goal capture (`MatchSession.saveEvent`, including yellow, red, substitution, and injury). Full time remains the legacy session path. Those paths were not retargeted. New kick-off and goal commands do not call them. A failed or rejected goal returns before `saveEvent`.

`MobileMatchReportState` exposes the production score projection only. `includesDisciplinaryRows` and `includesSubstitutionRows` are false.

## Companion model

`CompanionDevice` is an application read model: `deviceId`, `displayName`, `platformFamily`, `capabilities`, `connectionState`, `certificationState`, `pairingReadiness`. `holdsCaptureAuthority` defaults false. `CompanionRegistry.present` throws if a fixture sets it true. Pairing cannot assign capture authority.

`PlatformFamily` is `wearOs`, `watchOs`, `garmin`, `zepp`, `huawei`, `unknown`. The `huawei` value is not a Huawei Watch support claim and not an AppGallery claim.

Capabilities are an explicit set. Unknown names are ignored. An unknown capability is not treated as supported.

Certification (`unknown`, `known`, `compatible`, `certified`) is separate from connection and from authority. Pairing readiness (`unpaired`, `discoverable`, `pairing`, `paired`, `readyForProvisioning`, `incompatible`) describes the device relationship only. No discovery runs.

`MobileMatchReadiness` is a read model: match configured, local storage, temporal evidence, authority known, companion present, companion certified, companion provisioned. None of those flags grant authority.

Operating mode is derived: no device → `phoneOnly`; certified or ready for provisioning → `companionPrepared`; otherwise `phonePrimary`. `watchPrimaryFuture` is returned only when the authority snapshot already says so.

## Pairing versus authority

| Concept | Meaning in this wave |
| --- | --- |
| Pairing | Device relationship. Not implemented on a radio. |
| Connection | Transport availability. `NoPeerTransport` reports absent. |
| Provisioning | Future match and context transfer. The readiness flag exists. No transfer runs. |
| Replication | Future exchange of immutable Match Records. `PeerRecordNotice` is not admission. |
| Authority | Permission to append Match Records. Generation-1 phone capture for kick-off and goal only. |

A lost connection updates `connectionState` to `connectionLost` and leaves sporting records and the authority snapshot unchanged.

## Protocol and transport seams

`PeerProtocol.version` is 1. `PeerHandshake` accepts that version and a non-empty `deviceId`. Any other version is `PeerHelloRejected`. There is no negotiation and no cryptographic pairing.

Ports: `PeerCommandTransport`, `PeerRecordTransport`, `PeerConnectionStatePort`, `PeerCapabilitiesPort`. Production default: `NoPeerTransport` (`notSent`, empty records, absent connection, empty capabilities). `SimulatedPeerAdapter` is a test double. It rejects a repeated `messageId`.

`authoritativeRecordOrder` returns the committed record ids it was given and ignores transport arrival order. No Last Write Wins.

The dispatcher does not enqueue to the outbox and does not call the peer transport on the local success path. Future transport can attach behind these ports without changing command types.

Future transport may report `outcomeUnknown` when the request was sent and the result was lost. That status must stay unknown. It must not become failure or Saved, and it must not be retried blindly.

If a future watch transport fails, the phone must not silently become the writer. Fallback requires an explicit authority procedure that this wave does not implement.

## Platforms

Shared command code is Dart with no `dart:io`, no Flutter imports in `mobile_commands/`, `companion/`, or `presentation/`, and no Android-only types. Sporting semantics do not branch on platform.

Android may later use a replaceable Wear OS Data Layer adapter. iOS may later use WatchConnectivity behind the same ports. Neither adapter exists.

Huawei phone: core match operation does not require Google Sign-In, Firebase Auth, FCM, Play Services, or Google location. `apps/referee_phone/pubspec.yaml` does not depend on Firebase or `google_sign_in`. The Android app Gradle files do not apply Play Services. `google()` Maven in the Android Gradle setup is a build repository for Flutter artifacts, not a runtime GMS client.

`FirebaseConfig` and `MatchSyncService` are empty placeholders. They are not imported by the command layer, not required for launch, and not a capture gate. They are unused optional-replica shells.

Huawei watch: not claimed. Huawei phone compatibility and Huawei watch compatibility are separate.

App launch without Google APIs was exercised by the phone-only widget tests on this Linux agent. That is not a Huawei device proof. AppGallery was not tested.

## Security assumptions for later pairing

This wave does not authenticate peers. Later work must close:

| Threat | Requirement before a real adapter |
| --- | --- |
| Spoofed peer | Authenticated device identity. Hello alone is not trust. |
| Replayed command | Stable `commandId` plus the production capture-intent key. |
| Duplicate command | Same as replay. Do not allocate a new id on transport retry. |
| Stale match id | Writer already rejects a capture context whose match id or origin device differs from the envelope. |
| Stale authority generation | Existing generation-1 root checks stay in the commit port. |
| Unsupported protocol | Handshake already rejects a version other than 1. |
| Reordered messages | Ordering authority stays the committed record chain, not arrival time. |
| Lost connection | Must not change authority. `AuthorityContinuity` encodes that. |
| Stale capability | Unknown or missing capabilities stay unsupported. |
| Wrong device identity | Empty `deviceId` is rejected. A future adapter must bind the physical device, the app instance, the protocol version, the match, and the authority generation separately. |

## Tests

New suites:

- `apps/referee_phone/test/mobile_command_core_test.dart` — M1–M12, plus dispatching visibility, identity conflict, catalog closure, and a source firewall.
- `apps/referee_phone/test/mobile_companion_readiness_test.dart` — P1–P10, plus transport receipt, single-writer block, and outbox.
- `apps/referee_phone/test/mobile_phone_only_test.dart` — F1–F7 and a simulated companion that is visible and not authoritative.

Existing kick-off and goal source checks now follow `freezeKickOff` / `freezeGoal` → `runtime.dispatcher.dispatch` → `MatchApplicationCommandWriter` → `commitKickOff` / `commitGoal`. They still forbid `session.kickOff`, `.kickOff(`, `commitMatchStarted`, `MatchSession` inside the writer, and the legacy live score line.

## Remaining authority gates

- Yellow, direct send-off, second-caution send-off, and substitution have no phone writer in this catalog.
- Finish stays on the existing End Match control, outside the new envelope.
- Full time stays legacy.
- `watchPrimaryFuture` and any companion that holds capture authority cannot dispatch phone commands.
- Authority transfer is not authorized.
- Real Wear OS, watchOS, Garmin, Zepp, and Huawei watch adapters are not started.

## Later waves (not implemented)

| Wave | Scope |
| --- | --- |
| MOBILE 002 | Match setup, roster, and crew product completion. |
| MOBILE 003 | Phone Live Match product completion. |
| MOBILE 004 | Match report, summary, and correction UI for production-supported content. |
| PAIRING 001 | Experimental Wear OS pairing and Data Layer adapter. |
| PAIRING 002 | watchOS WatchConnectivity adapter. |
| PAIRING 003 | Huawei watch compatibility research and an adapter decision. |
| AUTHORITY TRANSFER 001 | Only after Referee Domain, Architecture, and Mission Reliability approval. |
