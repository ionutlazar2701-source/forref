# EVREC-A1 Bip 6 feasibility

State: **TRANSPORT GATE FAILED**. **D1 NOT CERTIFIED**. This package does not claim Saved, and it does not show a certified Match Ready state.

## Failed gate

The live Flutter-to-Zepp transport is not in this repository.

- MOBILE-003 and MOBILE-004B have no implementation on `cursor/clock-p0-recovery-4ae8`.
- The watch app does not import a Zepp Side Service, `@zos/ble`, or a messaging client.
- `@zeppos/zml` is listed in `apps/forref_watch_zepp/package.json` and is not imported.
- No cloud transport was added.

A physical Bip 6 cannot receive a provision until that bridge exists. A memory-store test is not a radio test and is not power-loss evidence.

## What the software does

`forref.watch-provision.v1` is parsed in Dart and JavaScript from one canonical fixture. The content hash is SHA-256 of those UTF-8 bytes. The hash checks content. It does not authenticate the device.

The watch admission chain is `UNPROVISIONED → CONFIG_RECEIVED → ROOT_VERIFIED → MATCH_READY`. `MATCH_READY` is returned only after the root and the admission marker are read back from the store port. The display string is `LOCAL READBACK — D1 UNCERTIFIED`. `saved` and `d1Certified` stay false.

Failure states are `CONFIG_INVALID`, `AUTHORITY_CONFLICT`, `STORAGE_UNVERIFIED`, and `RECOVERY_REQUIRED`. A missing or corrupt root is not rewritten when sporting records already exist. An identical document replays. A different document is refused after a root exists. The writer device id must be the provisioned installation UUID, not `deviceSource`.

The phone preparation stores a generation-1 root whose device id is that watch UUID. It does not append `GOAL`, `YELLOW`, `SEND_OFF`, `SUBSTITUTION`, `MATCH_STARTED`, or `PERIOD_STARTED`. A later phone `commitGoal` from the phone installation id is refused. A match that already has phone sporting records is refused.

## Bip 6 steps, after a bridge exists

1. Confirm the boot line is still the v1.0.14 clock recovery build unless a later preview is issued for this module. This commit does not replace that package.
2. Generate one installation UUID on the watch and keep it. Do not substitute `deviceSource`.
3. Send one canonical `forref.watch-provision.v1` document whose `writerDeviceId` is that UUID.
4. Kill and reopen FORREF. The stored document must still load. The face must not say Saved.
5. Turn Bluetooth off. The stored document must remain.
6. Send a different team id. The store must keep the first document.
7. Compare the watch hash with the phone hash of the same canonical string.

Do not run those steps against this commit and call them passed. The bridge is absent.
