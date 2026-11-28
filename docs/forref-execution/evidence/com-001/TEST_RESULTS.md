# COM-001 software results

State: **SOFTWARE PASS / HARDWARE GATE PENDING**. Not a Level 2 pass. The phone was not installed from this environment. Automated tests do not establish a Bip 6 pass. H1–H11 and E1–E8 stay **LOCAL GATE REQUIRED**.

## Send to Watch

A paired installation is read from the pairing stage. Send to Watch prepares a different saved match with that writer and returns the canonical `forref.watch-provision.v1` document on `pending`. The phone stays Waiting. The watch validates the document, writes it, and reads it back. It then sends `ACK_WATCH_CONFIG_VERIFIED_V1`. The phone shows Configuration Verified only for that acknowledgement. A second acknowledgement is `replay` and does not add a witness or a root. A different installation is refused. A different team name is `conflict` and the stored stage stays. A live match and the pairing fixture are refused before a listener starts. A dropped acknowledgement is retried. A new bridge reloads phase `verified` and shows the same match. Lock and activation are not called. The historical correlation and the pairing writer stay.

## Connect Watch

The side service on the phone fetches `127.0.0.1:47221`. `bridge:installation` is that fetch returning a writer mismatch. `fetch:transport` is the same fetch failing without a timeout, permission, or refused-connection classification. Connect Watch no longer prepares a writer from a typed UUID. The first valid watch request stores the watch installation on a new pairing match. A different later watch is `writer-kept`. The historical stage and correlation stay. The watch retries transport failures three times, then reports `phone-unreachable`. The phone screen shows Connected & Verified, already paired, or the two installation previews. Watch `1.0.34` (`watch-pair-034`, rev `121d2bfea53ce325cea2cc0e69d59f806c828c0b`). `npm test` in `apps/forref_watch_zepp` passed 292 tests before the stamp. The phone pairing tests covered a missing stage, one witness, replay, a kept writer, historical bytes unchanged, and a listener that resumes on the same match.


Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.34` (code 34). Functional commit `121d2bfea53ce325cea2cc0e69d59f806c828c0b`. Stamp commit `a8dce1a`. The preview package is `dist/29566-FORREF-1.0.34-20261128172845.zab` (417686 bytes, sha256 `ecce27ca297465041b0f8923b6988d5bd34e7f8a031eeb8df2667326e1e3133b`). It is not committed. `app.bin` contains `watch-pair-034` and the functional rev. The provision page bundle contains `forref_watch_pair_correlation_v1.txt`, `forref-candidate-v2:`, and `FORREF_PAIR`. The side bundle contains `prepare-only`. The QR expires `2026-12-05 17:28:48` on the machine clock (UTC), which is 19:28 Europe/Bucharest. Decoding the QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/jsFxbRRQPLFpPhBReJRaqrcNbGNYBSOp`. That decode is a package check. This package does not certify a Bip 6 pairing.

```
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀▀▄▄▄ ██ ▀ ▀▄▄██ ██▀█ ▄▄▄▄▄ █
█ █   █ ███▄█ ▄█▀▀█▄██ █▀  ▄█ █ █   █ █
█ █▄▄▄█ ██▄▀▄▀▀ ▄▄ ▀████▀▀▀██▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀▄▀▄▀▄█▄█ █▄█▄▀▄▀ █▄▄▄▄▄▄▄█
█  ▀▄▄▀▄█▀ ▄▄▀   ▄██ █▀ ▀▄█▄▀ █▄▀▀██▀▄█
█ ▄▀██▄▄▀▀▀▄ ▀▄█ ▀  █▄█▄ ███▄▄▀   ▄ ▄ █
██ ▄▄█ ▄▄█ ▄▄▄▄█ ▀ ▀████▀ █▀▀ █▄ ▀ ▀ ▄█
█ ▀█ ██▄ ▀▀▀ ▄▄█▄▀█▀ █▄▀█ █▄ █   ▀█▀█ █
█▄ ▄▀  ▄▀██▄▀▀██ ▄ ▀█ ▀ ▄█ █▀█▄▄ █ ▄▀▄█
█▄▄█▀█ ▄█▄ █▄▀▀ ▄██▀▄▀█▀▄  █ █▄▄▀▄▀█▀▄█
█▄▀▄▄▄▀▄▀▀█▀█▄▄▄ ▄▄█ ▄██▀█▀▀ ▄█▄  ▄▀███
█▄▀ ▄ █▄▀▄▀██▄▄  ▀  ▀▄█▄ ▀▄▀ █▀█▀█▀▀▀ █
█▀▄▀▄▄▀▄▄▄▀▀█▀▄▀▄▀▄██▄▀█ ▄▀█▀▄▀▄▄▀██ ▄█
█ ▄▀█▄ ▄ ▄█▀█▀█▄  █  ▄█▀▀█▄ ▄ ████  ▄▄█
█▄██▄▄█▄█ ▀█ ▄▄▀███▀ ▄▀ █  █  ▄▄▄ ▄▄▄██
█ ▄▄▄▄▄ ██▄▀▀▄  ▄▀▄  ▄▄█ ▀▀█▀ █▄█ █▄█▄█
█ █   █ █ █▀▄▀ ▀ ▄█▀ █▀▀▀█▀ ▄   ▄▄ █ ▀█
█ █▄▄▄█ █▀▄▀ ▀ █ ▀▀ ███▄ ▄▄▀ █▄▀ ▄▀▀▀ █
█▄▄▄▄▄▄▄█▄██▄▄▄█▄█▄█▄▄███▄███▄█▄██▄██▄█
```

## Writer comparison

The 1.0.33 hardware log `tx=identity reason=installation` is the `_classifyOther` branch. That branch runs only when `watch_provision_stages.writer_device_id` is not the request `installationId`. Settings Inspect compares the text field with the picker match. It does not read the watch body, so `changed=none` can be true for the typed UUID while the request UUID is refused. The phone now logs `tx=writer-compare` with both UUIDs, `equal`, `mismatch-at`, the branch, whether `_observeWitness` ran, and Inspect of the same stage using the request UUID. The comparison is not trimmed or lowercased. A matching request stores one version-2 witness. A mismatched request stores none, leaves the writer in place, and Inspect of the stored writer stays `changed` empty while Inspect of the request writer is `writer-device`. A second Enroll tap with a different typed UUID returns `enroll-writer`, leaves the listener and the stage writer, and the new UUID is still `reason=installation`. The watch package stays `1.0.33`. The next Bip 6 step is the read-only procedure in `HARDWARE_PROTOCOL.md`. It is not an enrollment pass.

## 1.0.33 isolated enrollment

The historical correlation is persistent on both sides. The watch reuses `forref_watch_provision_correlation_v1.txt` for the current installation. The phone bridge loads `forref_watch_provision_correlation_v1.json` and will not listen for a different match while that request is bound. `stop` does not delete the file. A second match on those files is not an isolated session.

Enrollment uses `forref_watch_enroll_correlation_v1.txt`, `forref_watch_enroll_v1.root`, `forref_watch_enroll_v1.admission`, and `forref_watch_enroll_correlation_v1.json`. The phone creates one match with team ids `forref-enroll-home` and `forref-enroll-away` only when that enroll file is absent. The next open reuses it. The historical file bytes, stage writer, content hash, principal, canonical text, identity events, generation-1 root, committed-record count, and Drift row are compared before and after. The session does not cancel, lock, activate, or write the historical correlation.

`apps/forref_watch_zepp` `npm test` passed 290 tests, 0 failed. A prepare through the enroll store left the historical correlation text and admission bytes unchanged and reused the enroll request id on the second call. A missing installation uuid with only the enroll file returned `lost-identity-state` and wrote nothing. `flutter test test/watch_enroll_session_test.dart test/watch_provision_debug_settings_test.dart` passed. The phone test started the historical listener, opened the enroll listener on another match, and read `disposition=listening` with `writes=0`. A version-2 witness for the current installation stored one `watch_witness_observed`. The same request returned `reason=replay` and left that one row. Digest version 1 on that request returned `reason=replay-conflict` and left the version-2 row. Another installation returned `reason=recovery-required` and did not add a second eligible witness. The historical stage writer, hash, principal, canonical text, identity event, root, committed records, correlation bytes, and Drift timestamp were unchanged. A corrupt enroll file was left in place. These rows are not Bip 6 results. E1–E8 in `HARDWARE_PROTOCOL.md` stay **LOCAL GATE REQUIRED**.

Functional commit `e0628d1a1fd272862b4642929dd0aea7d3055e70`. Stamp commit `8ec6e34a8c6bba8fc9eccc7566beba5436a433f7`. Boot `build=identity-enroll-033 rev=e0628d1a1fd272862b4642929dd0aea7d3055e70`.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.33` (code 33). The preview package is `dist/29566-FORREF-1.0.33-20261128151319.zab` (413738 bytes, sha256 `9d89033fb92c81b7136b7a5fb654d5793595a12d67d3505133dca3c79a624d63`). It is not committed. `app.bin` contains `identity-enroll-033` and the functional rev. It does not contain `GET_WATCH_PROVISION` or `createConnect`. The provision page bundle contains `forref_watch_enroll_correlation_v1.txt`, `forref-candidate-v2:`, `forref.identity-witness.v1`, and `FORREF_WITNESS`. The side bundle contains `prepare-only`. The QR expires `2026-12-05 15:13:22` on the machine clock (UTC), which is 17:13 Europe/Bucharest. Decoding the QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/wouJhedXVSHmHtAKFrQQHrZLQeqVFMqg`. That decode is a package check. This package does not certify a Bip 6 witness, a Zepp POST, lock, or activation.

```
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀▀▄▄ ▀▄█▄▄▀█▄▄██ ██▀█ ▄▄▄▄▄ █
█ █   █ ███▄█  ▄ ▀█▄▄  █▀  ▄█ █ █   █ █
█ █▄▄▄█ ██▄▀▄▀█ ▄ ▀▀▄███▀▀▀██▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀▄▀▄▀▄█ ▀ █▄█▄▀▄▀ █▄▄▄▄▄▄▄█
█▄▄█▄▄▀▄▀▀▄▄▄▀█▄████▀█▀ ▀▄█▄▀ █▄▀▀██▀▄█
█▀▀▄█▄ ▄▄▀▄▄ ▀█  ▀▀▀▀▄█▄ ███▄▄▀   ▄ ▄ █
█▄█▄▀▀ ▄ ▄ ▄▄▄ █ ▀▄█▀▄██▀ █▀▀ █▄ ▀ ▀ ▄█
██ ▀██ ▄▄▄██ ▄█ ▄ ▄▄▄▄▄▀█ █▄ █   ▀█▀█ █
█▀█▀██ ▄▀▀▄█▀▀████▄▀▀▀▀ ▄█ █▀█▄▄ █ ▄▀▄█
██▄▄ █ ▄▀█▄▄▄▀▀▀▄█▄ ▄██▀▄  █ █▄▄▀▄▀█▀▄█
█▀▄▄█▄▄▄▀▀▄██▄  ▄█ ▀▀███▀█▀▀ ▄█▄  ▄▀███
█▄  █ ▀▄▀▀ ▄█▄█▀▄  █▀▀█▄ ▀▄▀ █▀█▀█▀▀▀ █
█▀█ █▀█▄ ▄ ██▀▀█▄▀ ▀▄█▀█ ▄▀█▀▄▀▄▄▀██ ▄█
█ ▄█  ▄▄▀▀ ▀█▀▄█  █  ▄█▀▀█▄ ▄ ████  ▄▄█
█▄█████▄█ █▀ ▄▄█ ▄▀█ ▄▀ █  █  ▄▄▄ ▄▄▄██
█ ▄▄▄▄▄ ███▄▀▄▀█  ▄▀ ▄▄█ ▀▀█▀ █▄█ █▄█▄█
█ █   █ █ ▀▀▄▀ ▀▄▄█▀ █▀▀▀█▀ ▄   ▄▄ █ ▀█
█ █▄▄▄█ █▀█▄ ▀ █   ▄███▄ ▄▄▀ █▄▀ ▄▀▀▀ █
█▄▄▄▄▄▄▄█▄▄▄▄▄▄██▄▄█▄▄███▄███▄█▄██▄██▄█
```

## 1.0.32 byte-string identifier

Root cause: Zepp OS API_LEVEL 4.2 documents `getDeviceInfo().uuid` as a string of 32 bytes. It does not document 64 hex characters. Build `1.0.31` accepted only `[0-9a-fA-F]{64}`. The founder’s Bip 6 log was `FORREF_WITNESS kind=absent class=unsupported-or-invalid len=32`, with `FORREF_IDENTITY case=fresh created=1` after an explicit uninstall of `1.0.30`. That length matches the documented string. The alphabet was not in the log, so `1.0.32` accepts a 32-code-unit string whose code units are all in 0..255, lowercases it only when every byte is ASCII hex, and hashes `forref-candidate-v2:` plus those 32 bytes. The log adds `hex`, `ascii`, `ctrl`, and `utf8` and still omits the raw identifier. Version-1 hex64 digests stay on `forref-candidate-v1:` and are not recomputed. An existing registry is copied so version 2 can be appended. `UPDATE` and `DELETE` stay aborted. A missing witness is not synthesized. Production authorization stays `authorization-unavailable`. Lock and activation stay disabled.

`packages/forref_match_persistence` `dart test test/watch_identity_test.dart` passed 9 tests. `apps/forref_watch_zepp` `npm test` passed 287 tests, 0 failed. `flutter test test/watch_provision_debug_bridge_test.dart` passed 11 tests. The bridge refused a version-2 fingerprint from another installation with `reason=installation` before any witness existed, then stored `digest_version` 2 for the current writer and returned `reason=recovery-required` for the same digest. The stage writer, canonical text, and generation-1 root were unchanged. These rows are not Bip 6 results. H1–H11 stay **LOCAL GATE REQUIRED**.

Functional commit `12dfb9d197cbea419129f533ad865fbd613a71d6`. Stamp commit `a72acdf60de5253abc73012fd1ef1dc2da90d3cf`. Boot `build=identity-bytes32-032 rev=12dfb9d197cbea419129f533ad865fbd613a71d6`.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.32` (code 32). The preview package is `dist/29566-FORREF-1.0.32-20261128142742.zab` (409318 bytes, sha256 `b78584bdcf9175a5391f165c32fb8eee0191a7f63301dfc79a32054f7d89c922`). It is not committed. `app.bin` contains `identity-bytes32-032` and the functional rev. It does not contain `GET_WATCH_PROVISION` or `createConnect`. The provision page bundle contains `forref-candidate-v2:`, `forref.identity-witness.v1`, and `FORREF_WITNESS`. The side bundle contains `prepare-only`. The QR expires `2026-12-05 14:27:44` on the machine clock (UTC), which is 16:27 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/BmyJZoxkrzcnEbUAnMoPralWcfzHJUkB`. That decode is a package check. This package does not certify a Bip 6 witness, a Zepp POST, lock, or activation.

```
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄  ▄█▀███▀▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄ ▀█▀  ▀█ ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █  ▄█▀▄███ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █▄█ █ ▀▄█▄█ █ ▀ █▄▄▄▄▄▄▄█
█ ▄ ▀▀▄▄█▄  ██▀▀▀ █▀█▀▀▄  █▀▀▄▄  ▄█▀  █
█ ▀▄▀█▀▄▀ ▀█▄██▄▄██▄ ▄█▀▄▀▄█▄▀█▄▀ ▄█ ▄█
████   ▄▀▄▀█▄  █  ▀▀█ ██▀▄▀█▀ █ ▄█ ▀  █
█▄█ ▀█▄▄  █▀▀ ▄▄ ▄█▄▄█▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█▀█ ▄▄▀▄█▄ ███ █ ▀██▀▀▀█ ▀▀█▀   ▀█ ▀█ █
█▀▀ ▀█▄▄ █  ▄██▄▄▄█ ▄▀█▀▄▄▄▀ █▄ █ ▀█▀ █
█▀█ █▀█▄ ▀▀█▄ ▄▀▄▀▀█▀ █▀ ▀▀▄  ▄  █▄█▄▀█
█   ▀▀ ▄▄ █ ▀ ▄▀ ▀██ ▄█▀▄██▀  █▀ █▀▄█▄█
█▄▄▄ ▄▀▄▄▄▀ ██▀█▀ ▄█▄ ▀█  █▀▀▄▀  ███  █
█▄▄▀██▀▄▄▄  ▄██ ▄▀▄▀ ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄▄▄█▄▄▄▀▄ ▄ ▄██ ██▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀  ▀ █▄  █▄▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ██▀███ ▄▀ ▄▀  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▄ ▄█▀█▄█▄▀▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄█▄▄▄▄█▄▄▄█▄▄███▄███▄█▄██▄██▄█
```

## 1.0.31 detection build

Identity detection, functional commit `b4cde9ed17a6ef0ee304265164a146474b7802e9`, boot `build=identity-detect-031 rev=b4cde9ed17a6ef0ee304265164a146474b7802e9`. `packages/forref_match_persistence` `dart test test/watch_identity_test.dart` passed 7 tests. `apps/forref_watch_zepp` `npm test` passed 286 tests, 0 failed. `flutter test test/watch_provision_debug_bridge_test.dart test/watch_provision_debug_settings_test.dart` passed 12 tests. `./tool/verify_cloud.sh` passed. The bridge test observed `reason=observed` for the current writer and `reason=recovery-required` for a second installation, with the stage canonical, writer, and hash unchanged and the generation-1 root absent. `authorizeInstallationEnrollment` returned `authorization-unavailable`. GET `/` returned `listening` and `writes=0`. These rows are not Bip 6 results. H1–H11 in `HARDWARE_PROTOCOL.md` stay **LOCAL GATE REQUIRED**.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.31` (code 31). The preview package is `dist/29566-FORREF-1.0.31-20261128135952.zab` (408519 bytes, sha256 `8820bbf9c1df19b1080d2d4b8ad1855ae645a2f35ba8c8a7be0d38e0581bd325`). It is not committed. `app.bin` contains `identity-detect-031` and does not contain `GET_WATCH_PROVISION` or `createConnect`. The provision page bundle contains `forref.identity-witness.v1` and `FORREF_WITNESS`. The side bundle contains `prepare-only`. The QR expires `2026-12-05 13:59:54` on the machine clock (UTC), which is 15:59 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/TyzGZPhbCOpzQcUWslLCuYMFltCXufoF`. That decode is a package check. This package does not certify a Bip 6 witness, a Zepp POST, lock, or activation.

```
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄ █ ███▄██▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄  ██  ▄  ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █▄▀▄▀ ▄▄██ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █▄█ █▄▀▄█▄█ █ ▀ █▄▄▄▄▄▄▄█
█▄▄ ██ ▄▀▄  ██▄██ ▄██▀▀▄  █▀▀▄▄  ▄█▀  █
█ ▀▄█▀▀▄ ▄▄▀▄██ ▄██  ▀█▀▄▀▄█▄▀█▄▀ ▄█ ▄█
██▄▄▀█▄▄▀▄▀▄▄  ▀█▀ █▄ ██▀▄▀█▀ █ ▄█ ▀  █
█  █▀█▀▄▄ ██▀ ▄▄▄▀█▀ ▄▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█ ▀█▀▀ ▄ ██ ███▀ ▀█▀▀▀▀█ ▀▀█▀   ▀█ ▀█ █
█▀█▄▀ █▄▄▄ ▄▄█▄▀ █▄▄▄██▀▄▄▄▀ █▄ █ ▀█▀ █
█▀  █▀ ▄▄ █▀▄ ██▄ ▀▀▀▀█▀ ▀▀▄  ▄  █▄█▄▀█
█  ▄█▄▄▄ █▀▄▀ ██▄ █▄▄ █▀▄██▀  █▀ █▀▄█▄█
██▄▀▀ ▄▄▀▄▀▀██▀██ ▄▀▄▀▀█  █▀▀▄▀  ███  █
█▄▄█▄ ▀▄█▄ █▄██▀▄ ▄  ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄█▄▄▄▄█▀ ▄▄ ▄█▀ ██▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀▄ ▀ ██ ██ ▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ███ ██ ▄ ▀▄▀  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▀▄▄█▀█ ▀▄▀▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄██▄▄▄█▄█▄█▄▄███▄███▄█▄██▄██▄█
```

Shared digest vector: platform hex `00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff`, SHA-256 domain `forref-candidate-v1:`, digest `26c41755b96d53042c3b66daefff51082ea5ec9c70c4d4c6e0fffb6bde19954c`. The Dart and JavaScript tests both check the `abc` SHA-256 vector `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`, and the JavaScript test checks this domain digest.

Open package: functional commit `b89abb97e2c31162e145f6b62041ee2d6f3aed3d`. Boot stamp `afbb3ae`. Boot name `com-001-open`. App `29566`, version `1.0.22` (code 22). `npm test`: 260 pass, 0 fail.

`1.0.21` still rebooted the Bip 6 from a black screen. That package called `App()` through a helper, and the provision page still imported `@zeppos/zml/3.0/module/messaging/plugin/app`. `1.0.22` restores the direct `App({...})` registration used by `1.0.19`, which opened. No watch page, `app.js`, or app-service file imports `@zeppos/zml`. The built device package contains `FORREF_APP` and `com-001-open`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `BaseApp`, or `hmBle`. Those strings remain in the phone-side bundle only.

This package does not send a provision request. There is no messaging object on the device. A node test still sends the page request through `dispatchSideRequest` to a loopback HTTP server and finishes `transport=recorded` with the fixture content hash. That server stands in for the phone. It is not a Bip 6 result.

`1.0.20` opened through ZML `BaseApp` before `App()` was registered. `BaseApp()` reads `__$$app$$__.__globals__.__scopedGlobals__`. When that object is not ready, the call throws and `App()` never runs. The same module also constructs `TransferFile` and calls `ble.createConnect` during startup.

Settings keeps `WatchProvisionDebugSection` behind `kDebugMode`, and the bridge refuses unless `kDebugMode` is true. The release manifest has no `INTERNET` permission. A debug widget test opens Settings and finds Watch provision, Watch installation UUID, No saved match selected, and Prepare and listen, then selects a saved match. The listening status line is `listening` plus the content hash, written after `bridge.start`. The bridge test posts the pending body to that server and receives `disposition=prepared`.

Earlier debug-readiness note: functional commit `870dab0e2f72532c7ee16f79464c473d443ce4d9`. Boot stamp `85ff4c0`. Boot name `com-001-debug-ready`. Version `1.0.20` (code 20). That is the package that rebooted the watch.

This environment has no Android SDK (`flutter doctor` reports the toolchain missing). The installable debug session is `flutter run -d RZCY11BDMTX` from `apps/referee_phone` on the Windows machine that already sees SM A166B. That command keeps the existing debug signature and the application support files. Steps are in `HARDWARE_PROTOCOL.md`.

Identity hotfix: functional commit `7d8a8fc623307ef7f0d26f141ca9ffa34ec14fe3`. Boot name `com-001-ui-hotfix`. App `29566`, version `1.0.19` (code 19). `npm test` at that commit: 254 pass, 0 fail.

ZML 0.0.38 `BasePage` runs `globalData.messaging.onCall()` inside `onInit`, before the page `build`. The device app globalData is `{ demo: true }` and has no messaging object, so that call throws and the provision screen stays blank. The page is now a plain `Page`. It paints the stored UUID, or `INSTALLATION UNAVAILABLE`, before any handshake. A valid installation file is not rewritten. `1.0.18` reached the route and left this screen blank.

Navigation build: functional commit `3a2f577e90b5bfe06e31851d5a6d8bccdfd2f25c`. Boot stamp `b7c498d`. Boot name `com-001-ui`. App `29566`, version `1.0.18` (code 18). Home keeps OFFICIATE and TRAINING and adds SETTINGS.

Transport functional commit `9b662fbf1c4ee4f75ce01d05b215c1ac589cae34`. Boot stamp commit `f03e1d9d738d1abd9e6c9c989844d0c741df8d41`. Boot name `com-001`.

Baseline: PR #84, commit `e89c2b2041679b9bfaa5132afd903a9e3b921920`. Clock cadence, Goal journal, score, and authority-writer rules are unchanged.

## Receipt rule

`decidePhoneAuthorityLock` still returns early for `authorityConflict`, `recoveryRequired`, and `configInvalid`. It no longer returns early for an existing `phoneAuthorityLocked` root.

A missing receipt, or transport down, stays `configPrepared` with reason `transport-unavailable` and `rootToCommit` null. A present receipt that is not a generation-1 readback stays `configPrepared` with reason `receipt-invalid`. A receipt whose hash or writer disagrees with the document is `authorityConflict` with reason `receipt-mismatch`. The stored root is not deleted and is not inserted again.

`durable` on the debug bridge is true only when that decision state is `phoneAuthorityLocked`. That state is reached for a new lock, or for `idempotent-lock`, only after the receipt in this call is usable. An existing root does not make `readBack: false` durable.

## ZML timeout

`@zeppos/zml` 0.0.38 `dist/zml-side.js` implements Side Service fetch as global `fetch`. The options object is `{timeout:1e4, ...request}`. The Fetch call does not abort on that field, so `timeout: 4000` on `this.fetch` is not a deadline.

The page-to-side `request()` path does abort. Its default is `timeout:6e4`, and a timer rejects with `request id=… timeout in ${t.timeout}ms`. The provision page passes `{ timeout: 8000 }`. The side service wraps `this.fetch` in `fetchWithDeadline` at 4000 ms and does not pass `timeout: 4000` into fetch.

## Correlation

Watch file `forref_watch_provision_correlation_v1.txt`. Phone debug file `forref_watch_provision_correlation_v1.json` under the application support directory. Both keep installation UUID, request UUID, generation 1, match id, and content hash. A retry reuses that request id. A second handshake for the same installation returns `busy` until the first returns. A later phase does not rewrite an earlier phase backwards.

Logs are `FORREF_PROVISION` lines with `tx=request`, `tx=response`, `tx=transition`, or `tx=recover`, plus installation, request, match, hash, generation, http, disposition, and reason. The canonical document and team names are not on those lines.

## Fault injection

| Interruption | Final phone root | Watch admission | Correlation |
| --- | --- | --- | --- |
| Lock response lost after the watch stored the verified document | No root until a later usable receipt | `WATCH_CONFIG_VERIFIED` | Same request id, phase `verified` |
| Phone SQLite lock committed, then the process restarts, then `readBack: false` | One root, same device id | n/a | Same request id, phase stays `locked`, response `receipt-invalid`, `durable` false |
| Same restart, then the original request with `readBack: true` | Same one root, `idempotent-lock`, no second insert | n/a | Same request id |
| A different request id after that lock | Same one root | n/a | Refused `correlation` |
| Activation report lost | Root already locked | `WATCH_ACTIVATED` | Phase `activated`, then a retry reaches `reported` on `recorded` |
| Prepared body for another match after the hash is bound | Unchanged | Unchanged | Refused `binding` |
| Second handshake while the first request is open | n/a | Unchanged | `busy`, one request id |
| HTTP 409, HTTP 500, malformed JSON, contradictory `prepared`/`locked` | No new root | No canonical stored | Request id kept, disposition not a success |
| Lock before any pending | No root | n/a | Refused `order` |

## COM-004R prepared match

Current package: functional commit `29dee454fa5ebba73442387275abf45decfb7499`. Boot stamp `5764472`. Boot name `com-004r-share`. App `29566`, version `1.0.30` (code 30). `npm test`: 282 pass, 0 fail.

No Bip 6 `FORREF_IDENTITY` line was attached for `1.0.29`, and no `tx=probe` line was attached either. Those two observations remain **LOCAL GATE REQUIRED**. This package does not invent them. `1.0.30` still logs `FORREF_IDENTITY` before a tap. A recovery reason sends no request and does not mint a writer. An intact id sends `GET_WATCH_PROVISION_V1` only. The side posts `operation=pending` and still refuses `SUBMIT_WATCH_LOCK_V1` and `REPORT_WATCH_ACTIVATED_V1` with `prepare-only` before fetch. The page does not call `runHandshake` or `runSideDiagnostic`. Correlation and the provision root are written under `data://` and read back. A legacy file is not deleted. The outcome line names `installation`, `request`, `match`, `hash`, and `canonical=accepted` or `canonical=rejected`. It does not include the canonical document or the team names. Comparing that line with the phone `listening` line is **LOCAL GATE REQUIRED**. The phone must show no new authority root.

The built `app.bin` contains `FORREF_APP`, `com-004r-share`, and `29dee45`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `page/gt/provision/index.page.bin` contains `data://`, `FORREF_IDENTITY`, `runPrepare`, and `GET_WATCH_PROVISION`. It does not contain `runHandshake`, `runSideDiagnostic`, or `SUBMIT_WATCH_LOCK`. `app-side.js` contains `tx=side-build` and the lock method names it refuses. It does not contain `tx=recover method=`. This scan is a package check. It is not a Bip 6 result.

## COM-004R installation identity

Current package: functional commit `c2c9555832e899d1f5412a418d9f2b822ea2958c`. Boot stamp `6344d04`. Boot name `com-004r-identity`. App `29566`, version `1.0.29` (code 29). `npm test`: 282 pass, 0 fail.

Across successive Bip 6 builds the displayed installation UUID changed: `166e7c3b-…-e43e`, `03e0d543-…-0a51`, `12a79650-…-f966`. FORREF Mobile kept the previous writer-device id and returned `prepared-conflict`. The watch minted a new random UUID when `forref_watch_installation_v1.txt` read as missing, without looking at correlation, admission, the authority root, or a goal journal. Those files were stored under bare names. Zepp documents `data://` as the directory retained across an application upgrade and removed on uninstall. This repository has no device log that shows the bare files were deleted. The three UUIDs are observed. They are not evidence that Zepp wiped application storage.

`1.0.29` reads `data://forref_watch_installation_v1.txt` and the legacy bare name. The same valid id is reused. A legacy-only id is copied to `data://` and read back. A failed copy is `copy-unverified` and does not mint a replacement. Two different ids, a corrupt file, or an unreadable file is `RECOVERY_REQUIRED` and nothing is written or deleted. A missing id with a correlation file, a provision root, an admission file, goal context, or a `forref_watch_goal_` journal is `RECOVERY_REQUIRED`. The reason is `lost-identity-activated` when admission is `WATCH_ACTIVATED` or the correlation phase is activated or reported, `lost-identity-prepared` when a root, correlation, verified admission, or verified or pending phase is present, and `lost-identity-state` otherwise. A fresh UUID is written only to `data://`, and only when every one of those files is absent. Clock files do not block that create. The UUID is not derived from the version, the build number, or a hardware id, and the phone-stored UUID is not adopted. A provision tap with no intact identity does not send a request. Lock and activation stay refused. The HTTP probe is unchanged and stays a separate trial.

The built `app.bin` contains `FORREF_APP`, `com-004r-identity`, and `c2c9555`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `page/gt/provision/index.page.bin` contains `data://`, `FORREF_IDENTITY`, `runSideDiagnostic`, `GET_SIDE_BUILD`, and `PROBE_BRIDGE`. It does not contain `runHandshake`, `GET_WATCH_PROVISION`, or `SUBMIT_WATCH_LOCK`. `app-side.js` contains `tx=side-build` and does not contain `tx=recover method=`. This scan is a package check. Identity continuity across two Bip 6 builds, side parity, and the HTTP probe remain **NOT TESTED**. LOCK and ACTIVATION stay disabled.

## COM-004R side parity

Current package: functional commit `64f3f2b89e4d8edee1d37d7b961537be8c75888e`. Boot stamp `7a04b98`. Boot name `com-004r-parity`. App `29566`, version `1.0.28` (code 28). `npm test`: 278 pass, 0 fail.

On `1.0.27` the watch page showed `fetch:transport`. The Zepp JS App Log contained minified Side Service source with `tx=recover method=`. That string is the `1.0.25` `dispatchSideRequest` catch. `1.0.26` replaced it with `tx=fetch`. A `1.0.25` catch returns `reason=unavailable` or `reason=deadline` and does not set `hop=fetch`. A `1.0.27` page paints that reply as `watch:unavailable` or `watch:deadline`. The painted `fetch:transport` comes from a reply whose `hop` is `fetch` and whose `reason` is `transport`, which is the `1.0.26` and `1.0.27` side. The source in the log and the service that answered the tap were not shown to be the same process. The log can retain an older side bundle while a newer service is running, and the reverse is also possible. This row is not a certified version comparison.

`1.0.28` puts one build id in both bundles: `build=com-004r-parity`, `rev=64f3f2b89e4d8edee1d37d7b961537be8c75888e`, `version=1.0.28`, `code=28`. The device app logs `tx=device-build` when PROVISION opens. The Side Service logs `tx=side-build` from `onInit` and again when it answers `GET_SIDE_BUILD_V1`. That answer does not call `fetch` and does not write correlation or admission. The tap logs `tx=parity match=1` only when both ids agree. `match=0` stops there. A live `1.0.25` side refuses the new method with `reason=method` and does not fetch.

After `match=1`, the same tap sends `PROBE_BRIDGE_V1`. The side POSTs `{"operation":"probe"}` to `http://127.0.0.1:47221/watch-provision/v1`. The phone debug bridge refuses that body as `message` before it reads or writes a match, a correlation file, or an authority root. A thrown fetch keeps `name`, `code`, and the original `error` text on `tx=probe`. The category `transport` stays, and the message is not replaced by that word. `SUBMIT_WATCH_LOCK_V1` and `REPORT_WATCH_ACTIVATED_V1` are refused with `prepare-only` before `fetch`. The page does not call `runHandshake`.

The Side Service runs inside the Zepp phone app. Installing a preview replaces the watch app when the version code increases, and it delivers a new side bundle to the phone. An already running Side Service keeps the JavaScript it loaded until the Zepp process destroys it. Force-stop Zepp from Android Settings. Do not uninstall Zepp, FORREF Mobile, or FORREF Watch. The watch installation UUID, correlation file, and prepared match stay on the device. Open Zepp again, then open PROVISION.

The built `app.bin` contains `FORREF_APP`, `com-004r-parity`, and `64f3f2b8`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `app-side.js` contains `tx=side-build`, `GET_SIDE_BUILD`, and `PROBE_BRIDGE`. It does not contain `tx=recover method=`. `page/gt/provision/index.page.bin` contains `runSideDiagnostic`, `GET_SIDE_BUILD`, and `PROBE_BRIDGE`. This scan is a package check. It is not a Bip 6 result. PARITY and the HTTP probe remain **NOT TESTED**. LOCK and ACTIVATION stay disabled on this build.

## COM-004 lock handshake

Current package: functional commit `f6efb1680837a4b2a09ac7c002c99ef9dc2300c4`. Boot stamp `ebf2753`. Boot name `com-004-lock`. App `29566`, version `1.0.27` (code 27). `npm test`: 274 pass, 0 fail.

The founder reported two visual results on `1.0.26`, with no console excerpt attached. FORREF Mobile showed `listening` after the selected match was prepared. The first watch Provision tap showed CONFIG PREGĂTIT. Back → PROVISION → Provision showed CONFIG PREGĂTIT again. The installation UUID, request UUID, match id, content hash, generation, canonical acceptance, and watch readback were not compared. These rows are founder-reported visual passes. They are not a certified correlation.

`1.0.27` keeps the direct `App({...})` registration. Opening PROVISION reads the stored correlation and the watch admission and logs `tx=evidence` with installation, request, match, hash, `generation=1`, phase, `canonical=accepted|rejected|absent`, `readback`, `lock`, and `activation`. That read does not allocate a request id and does not write the correlation file. The phone Inspect provision line adds the stored request id and phase from the correlation file and does not include the canonical document. The tap calls `runHandshake`, which repeats the prepared fetch on the same request id, then `SUBMIT_WATCH_LOCK_V1` with the verified readback receipt, and only then `REPORT_WATCH_ACTIVATED_V1`. The phone commits one generation-1 root on a valid lock and records activation without a second root. A lost lock leaves the watch verified and the same request id. A lost activation leaves the watch activated and retries the report. A conflicting hash, device, or receipt is refused. Clock modules and the match-event journal are not on this path.

The built `app.bin` contains `FORREF_APP`, `com-004-lock`, and `f6efb168`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `page/gt/provision/index.page.bin` contains `createConnect`, `runHandshake`, `SUBMIT_WATCH_LOCK`, and `REPORT_WATCH_ACTIVATED`. This scan is a package check. It is not a Bip 6 result for `1.0.27`. LOCK and ACTIVATION remain **NOT TESTED**.

## COM-003R provision diagnosis

Current package: functional commit `b577dd41cbbb82867233203acb6b79b5d7e273da`. Boot stamp `3c3483f`. Boot name `com-003r-prepare`. App `29566`, version `1.0.26` (code 26). `npm test`: 273 pass, 0 fail.

The founder reported the `1.0.25` page, with no console excerpt attached. With Bluetooth connected, PROVISION showed `unavailable`. With Bluetooth disabled, it showed `messaging`. After Bluetooth reconnect, it showed `unavailable`. FORREF Mobile accepted a newly created match and returned `listening`. Previously prepared matches returned `prepared-conflict` across later development builds. `1.0.24` PING, navigation, and Bluetooth reconnect stay the founder-reported pass from the section below.

`unavailable` on `1.0.25` was the collapsed status after a request had been attempted. `acceptPrepared` kept `disposition` and dropped the inner reason, and the side fetch mapped every non-deadline error to the same word. PING never calls that fetch, so a PONG does not show which hop failed. `messaging` is the status when the visit socket is not attached, which is what Bluetooth off produces.

`1.0.26` keeps the direct `App({...})` registration and the prepare-only request. The page status is `hop:category` when the request fails. The hops are `device` (request id generated, or the socket was not attached), `side` (the side service received the method and request id), `fetch` (local HTTP started, with status, category, and elapsed milliseconds), `bridge` (the Flutter debug bridge received the operation and returned a status), and `normalize` (the watch accepted or refused the reply). Categories are `timeout`, `permission`, `connection-refused`, `malformed`, `transport`, and `http-refusal`. A phone refusal such as `installation` stays in `reason` and the page shows `bridge:installation`. Logs name `installation`, `request`, `match`, and `hash`. They do not include the canonical document or the team names. Lock and activation stay refused by the side service before `fetch`.

`prepared-conflict` is the phone refusing to replace a `watch_provision_stages` row. The stored content hash, writer device id, or principal id differs from the document that this build would write. The row is not overwritten. A new match has no row, so it can listen. Debug Settings shows Inspect provision and Cancel prepared. Inspect names the stage and which of `content-hash`, `writer-device`, and `principal` changed, plus whether a generation-1 root or a sporting record is present. It does not show the canonical document. Cancel prepared calls `cancelPreparedWatchMatch` with the stored content hash. That succeeds only when the stage is exactly `CONFIG_PREPARED`, the hash matches, no generation-1 root exists, and no sporting record exists. The authority root is not reset, a conflicting identity is not overwritten, and match history is not deleted. After a successful cancel, Prepare and listen can store the new document for the same match.

The built `app.bin` contains `FORREF_APP`, `com-003r-prepare`, and `b577dd41`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `page/gt/provision/index.page.bin` contains `createConnect`, `GET_WATCH_PROVISION`, `runPrepare`, and `device:messaging`. It does not contain `SUBMIT_WATCH_LOCK`. This scan is a package check. It is not a Bip 6 result for `1.0.26`.

## COM-003 prepare transport

Current package: functional commit `01a29c0b1e06b3e098938df61fa66274b1f5bcbe`. Boot stamp `f8ff017`. Boot name `com-003-prepare`. App `29566`, version `1.0.25` (code 25). `npm test`: 271 pass, 0 fail.

`1.0.25` keeps the direct `App({...})` registration. PROVISION paints the installation UUID before it opens messaging. The tap uses the same visit-owned socket as LINK: one close of a stale object, then one new socket. `runPrepare` sends `GET_WATCH_PROVISION_V1` and accepts the reply only when the installation UUID, request id, match id, content hash, and canonical document agree. It does not send `SUBMIT_WATCH_LOCK_V1` or `REPORT_WATCH_ACTIVATED_V1`. The side service refuses those two methods with `reason=prepare-only` before `fetch`. The clock modules and the match-event journal are not referenced by this path. A prepared watch admission is the local copy of that document. It is not a phone authority root.

The built `app.bin` contains `FORREF_APP`, `com-003-prepare`, and `01a29c0b`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, `hmBle`, or `GET_WATCH_PROVISION`. `page/gt/provision/index.page.bin` contains `createConnect`, `GET_WATCH_PROVISION`, and `runPrepare`. It does not contain `SUBMIT_WATCH_LOCK`. This scan is a package check. It is not a Bip 6 result for `1.0.25`.

## Founder report for 1.0.24

The founder reported a physical pass on the Amazfit Bip 6 for build `1.0.24`: repeated PING/PONG; LINK → Back → LINK → PING/PONG; Bluetooth off, then on, then PING/PONG. No console excerpt or log file was attached to that report. This record does not quote watch lines for those trials.

## COM-002R messaging lifecycle

Package `1.0.24`: functional commit `63bf267d3031941b443f86473187903f3008627f`. Boot stamp `0b3f684`. Boot name `com-002r-link`. App `29566`, version `1.0.24` (code 24). `npm test` at that commit: 268 pass, 0 fail.

`1.0.23` on the Bip 6: repeated PING on one LINK visit returned PONG. Back → Settings → LINK → PING showed DOWN. Fully closing FORREF and opening LINK again returned PONG. PROVISION after the failed navigation showed BUSY / UNAVAILABLE. That package kept the messaging object on `globalData` and treated `request()` as proof the socket was alive. ZML 0.0.38 `connect()` calls `ble.createConnect` and registers call, request, and BLE listeners every time it runs. `disConnect()` sends close, drops the message listener, and clears the module-level handler sets. Calling `connect()` again on the same object would add a second socket and a second set of listeners. The page that opened the socket did not run `onDestroy` on the messaging object, so after navigation the cached object was still readable and the next PING reused it.

`1.0.24` keeps the direct `App({...})` registration. Each LINK visit takes the next integer on `globalData.linkVisit`. Leaving the page sets `linkSocketVisit` to 0 and does not call BLE. The next PING, when the owner differs or `connectStatus` is false or the shake is not complete, calls `disConnect()` once, rejects handlers still in the map, and then constructs one new plugin. If that close throws, the old object stays and no second socket is opened. The same visit with a healthy socket is reused, which is the path that already returned PONG. `linkSeq`, the installation file, and the clock modules are not written by this path. PROVISION reads `messagingUsable`, so a retired visit does not send `GET_WATCH_PROVISION_V1`. Authority lock, activation, and sporting-event replication stay off.

The built `app.bin` contains `FORREF_APP`, `com-002r-link`, and `63bf267d`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `disConnect`, `BaseApp`, or `hmBle`. Home, Settings, and PROVISION binaries do not contain `createConnect`. `page/gt/link/index.page.bin` contains `createConnect`, `disConnect`, `page=destroy`, and `FORREF_LINK`. This scan is a package check. It is not a Bip 6 result for `1.0.24`.

## COM-002 link proof

Package `1.0.23`: functional commit `557f3f54dbf62d88d8a3f723b75ffca7a13a816e`. Boot stamp `4e00633`. Boot name `com-002-link`. App `29566`, version `1.0.23` (code 23). `npm test` at that commit: 263 pass, 0 fail.

`1.0.22` opened, painted the installation UUID and the provision status `messaging`, and sent no request. `1.0.23` keeps that direct `App({...})` registration. `app.js`, Home, and PROVISION still do not import `@zeppos/zml`.

ZML 0.0.38 `BaseApp` is what rebooted `1.0.20`. The module constructs `TransferFile` while it loads, `BaseApp()` reads `__$$app$$__.__globals__.__scopedGlobals__` before `App()` is registered, and its `onCreate` calls `ble.createConnect`. `1.0.21` avoided `BaseApp` and still rebooted. Its `app.bin` had no `createConnect`. Its provision page bundle did, because that page imported `@zeppos/zml/3.0/module/messaging/plugin/app` at load. A dynamic `import()` would keep that module out of the page file, and Zeus 1.10.3 rejects it: the page target is one `output.file`, and a second chunk requires `output.dir`.

`1.0.23` therefore imports that plugin only from `page/gt/link/index.page`. The built `app.bin` contains `FORREF_APP`, `com-002-link`, and `557f3f54`. It does not contain `__scopedGlobals__`, `TransferFile`, `createConnect`, `BaseApp`, or `hmBle`. Home and Settings binaries do not contain them either. `page/gt/link/index.page.bin` contains `createConnect` and `hmBle`. The page paints READY in `build()` and calls `appPlugin` only after PING is tapped. The side service answers `{ method: "PONG", seq }` before `dispatchSideRequest`. `GET_WATCH_PROVISION_V1` is not sent from this page. Authority lock, activation, and sporting-event replication stay off.

This scan is a package check. It is not a Bip 6 result. Opening Home must stay up. If the watch reboots on open, the firmware loaded the LINK page during launch. If Home stays up and LINK reboots before READY, the plugin module failed while the page loaded, before any socket. PING is the first `createConnect`.

## Suite

`npm test` in `apps/forref_watch_zepp` on `1.0.30`: 282 pass, 0 fail. The `1.0.29` tree was 282 pass, 0 fail. The `1.0.28` tree was 278 pass, 0 fail. The `1.0.27` tree was 274 pass, 0 fail. The `1.0.26` tree was 273 pass, 0 fail. The `1.0.25` tree was 271 pass, 0 fail. The `1.0.24` tree was 268 pass, 0 fail. The `1.0.23` tree was 263 pass, 0 fail.

`flutter test test/watch_provision_debug_settings_test.dart test/watch_provision_debug_bridge_test.dart` in `apps/referee_phone`: 10 pass, 0 fail.

`./tool/verify_cloud.sh` on the `1.0.30` tree: PASSED. The `1.0.29` tree PASSED. The same script passed on the `1.0.28`, `1.0.27`, `1.0.26`, and `1.0.25` trees. The phone suite inside those runs reported `All tests passed!`.

## Diagnostic package

Install `1.0.30`. Do not install `1.0.20` or `1.0.21`. Do not uninstall the Zepp app or either FORREF app. Force-stop Zepp, open it again, then open PROVISION. Copy `FORREF_IDENTITY` before any tap. `case=reused` keeps the UUID already on the watch. A recovery reason means this build refused to mint a writer and the tap sends nothing. On an intact id, Prepare and listen on the phone, then tap Provision once. Compare `installation`, `request`, `match`, and `hash`. `1.0.29` remains the previous package. Its identity line and its probe were not attached. For `1.0.28`, copy `tx=device-build` and `tx=side-build` before judging the tap. Tap once. `tx=parity match=1` must name the same build, rev, version, and code. Only then does `tx=probe` run. Copy `name`, `code`, `error`, `http`, and `reason`. The phone root, the correlation file, and the prepared match stay as they were. `1.0.27` showed `fetch:transport` while a log source still contained `tx=recover method=`. Those two observations were not shown to be one running bundle. `1.0.26` showed CONFIG PREGĂTIT, and CONFIG PREGĂTIT again after Back → PROVISION → Provision, while the phone showed `listening`. No console excerpt was attached, so that pair is not a certified correlation.

Opening `1.0.26` must show Home and must not reboot the watch. Home → SETTINGS → PROVISION shows the installation UUID before any tap. On the phone, enter that UUID, choose one saved match, and tap Prepare and listen. If the status is `prepared-conflict`, tap Inspect provision and copy the `changed=` fields. Cancel prepared is available only for a `CONFIG_PREPARED` row whose stored hash matches and that has no generation-1 root and no sporting record. After that cancel, Prepare and listen can return `listening` for the same match. The Zepp app stays open on that phone. Tap Provision on the watch. A failure page shows the hop and category, for example `fetch:timeout` or `bridge:installation`. The watch log contains `tx=request hop=device method=GET_WATCH_PROVISION_V1`, then `tx=side`, `tx=fetch` with `elapsed`, and `outcome=PREPARED` with the same `installation`, `request`, `match`, and `hash` as the phone `listening` line, and `canonical=accepted`. The page shows CONFIG PREPARED. The log does not contain `SUBMIT_WATCH_LOCK_V1` or `REPORT_WATCH_ACTIVATED_V1`. The phone has no new authority root. Leave PROVISION and open it again, then tap Provision. The request id stays the same. A reboot, a lock request, or a hash that differs from the phone fails the trial. Do not lock, activate, or replicate a sporting event.

Home → SETTINGS → PROVISION shows the installation UUID before the tap. The first console line on that page is `FORREF_PROVISION page=init`, then `page=build`, then `device width=` `height=` `layout=` and `installation=` with the 36-character id. A storage failure logs `tx=recover` and draws `INSTALLATION UNAVAILABLE`. Messaging opens on the Provision tap.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.30` (code 30), boot `build=com-004r-share rev=29dee454fa5ebba73442387275abf45decfb7499`. The preview package is `dist/29566-FORREF-1.0.30-20261128123821.zab` (407214 bytes, sha256 `bab14b7ab2591b10c3317bdc074d6e4d444ccc8658e7c7a1b71ca9fed5654b28`). It is not committed. The QR expires `2026-12-05 12:38:23` on the machine clock (UTC), which is 14:38 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/ZUXILazVKfsIjFMzWEMezJdVSTMbptBn`. That decode is a package check. This package does not certify installation continuity, the prepared-match exchange, the HTTP failure, lock, or activation on a Bip 6.

```
[FORREF - 1.0.30]
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▀█ █▄▀▄ ▄ ▀▄  █▄██ ▀ █ ▄▄▄▄▄ █
█ █   █ █▀▀▀█ █ ▀ █▄██▄ ▀ ▀ ▀██ █   █ █
█ █▄▄▄█ █▀ █▀▀█  ▄▀█▄▄▀▀▄▀▀▄▀ █ █▄▄▄█ █
█▄▄▄▄▄▄▄█▄▀ ▀▄█▄▀ █ █ ▀▄█▄█ █ █▄▄▄▄▄▄▄█
█    ▄█▄▄  ▀▄▀▀▄▄▀▀▀▄▀██▀▄▄ ██▄█ █ ▀ ██
█▄█▄   ▄▄▀▄██▀█ ▄█▄▄█▄▀ ███▄  ▄  ▀ ▄▀ █
█▄ ▀▄▀▄▄█▀ ▄█▄▄▄▀▀▄▀▄▀▀▄   ▄█▀▄▄█▄▄ ▀▄█
█  ▀  ▄▄ ▀▀█ ▄▄█▄█▄▀██ ▄█ ▄ ▄   ▀█▀▄█ █
█  ▀▀▄█▄▀▀▀█▄▀▄ █ ▄█▄ █▄▀█ ▄█▀▀▄ ▄▄ ▄▄█
█▄▀▄█▄▀▄ █▀██▀██  ▄▄█ ▀ █ █ ▄▄█▄▄▀█▄ ▄█
█  █ ▀ ▄▄  ▀█▄▄ ▄▀▀▀█ ▀ ▀█ █▄▀█▄▀▄ ▄███
█▀▄▀▀▀▄▄█▄▄█ ▄█▄  █▄▀█▀ █▀▄ ▄▀▄█▀▄██▄ █
█▀▄▄▄█▄▄▀▄▄ ▄▀█▄▀▀ ▀▄ █▄▀▄▄ ██ ▄▀▄▀▄▀▄█
█ █ ▄█▀▄ ▄▄▄█▀▄█  ▄ ▀ ▀▄▀██▄ ███▄▀▄█▄▄█
█▄█████▄▄  ▄█▄ ▄ ▀█▀ ██▄   ▄▄ ▄▄▄   ▀██
█ ▄▄▄▄▄ █▄   ▄▄▄▄ ▄▀█▀ ▄▀▀▄ █ █▄█ ▀█▄▄█
█ █   █ █   ▄▀▀█  ▀▀▀▀█▄▀█ ▄ ▄  ▄ ▄  ▀█
█ █▄▄▄█ █ █▄█▀ ▄▄████▄▀ █▄▄ ▄▀▀▀ ███▄ █
█▄▄▄▄▄▄▄█▄█▄█▄█▄█▄▄████▄▄▄▄▄██▄▄▄▄▄▄▄▄█
```

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.29` (code 29), boot `build=com-004r-identity rev=c2c9555832e899d1f5412a418d9f2b822ea2958c`. The preview package is `dist/29566-FORREF-1.0.29-20261128115804.zab` (405208 bytes, sha256 `84c0fa7d59387c8476bcb9d9d4b34038c62bf59df24522abe8b02e6da6ecd94a`). It is not committed. The QR expires `2026-12-05 11:58:07` on the machine clock (UTC), which is 13:58 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/AtcTuCOkIEWclJqJAGfMrCBiOahhHOaJ`. That decode is a package check. This package does not certify installation continuity, side parity, the HTTP failure, lock, or activation on a Bip 6.

```
[FORREF - 1.0.29]
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀▀▄▄█▄▄▀▀▄ █▄▄██ ██▀█ ▄▄▄▄▄ █
█ █   █ ███▄█  ▄  ▀██▀ █▀  ▄█ █ █   █ █
█ █▄▄▄█ ██▄▀▄▀█▄█ █ █▀██▀▀▀██▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀▄▀▄▀▄█▄▀▄█▄█▄▀▄▀ █▄▄▄▄▄▄▄█
█▄▄▀ ▄█▄██ ▄▄▀▀ ▄▄▀▀ ▄▀ ▀▄█▄▀ █▄▀▀██▀▄█
██▄▄▀▀█▄▀▀█  ▀█▄   ▄█ █▄ ███▄▄▀   ▄ ▄ █
██ █ █▄▄▀▀▄▄▄▄█▀▄ ▄▀ ███▀ █▀▀ █▄ ▀ ▀ ▄█
██▀█▀▄ ▄▀ ▀▀ ▄▄▀  ██  ▄▀█ █▄ █   ▀█▀█ █
██▀▀  ▀▄ ▄  ▀▀▀█ ▄ █▀ ▀ ▄█ █▀█▄▄ █ ▄▀▄█
█ ▀▀▄ ▀▄▄█▄▀▄▀  ▄▀██ ▄█▀▄  █ █▄▄▀▄▀█▀▄█
█   ▄▀▀▄ ██▄█▄  █▄▄▀ ▄██▀█▀▀ ▄█▄  ▄▀███
██ █ █ ▄▀████▄▄▀ █▀▄███▄ ▀▄▀ █▀█▀█▀▀▀ █
█▀   ▀ ▄▄▄  █▀▀▀  ▀▀ ▄▀█ ▄▀█▀▄▀▄▄▀██ ▄█
█ ▄▀█▄▀▄▀█ ██▀▄█ ██▀ ▄█▀▀█▄ ▄ ████  ▄▄█
█▄███▄█▄▄▀█▄ ▄▀█▄█▄▀ ▄▀ █  █  ▄▄▄ ▄▄▄██
█ ▄▄▄▄▄ ███▀▀▄▀ ▄██  ▄▄█ ▀▀█▀ █▄█ █▄█▄█
█ █   █ █ ▀█▄▀ ▀▄▄▄█ █▀▀▀█▀ ▄   ▄▄ █ ▀█
█ █▄▄▄█ █▀▀▀ ▀ █ ▀ ▄███▄ ▄▄▀ █▄▀ ▄▀▀▀ █
█▄▄▄▄▄▄▄█▄▄▄▄▄▄██▄▄█▄▄███▄███▄█▄██▄██▄█
```

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.28` (code 28), boot `build=com-004r-parity rev=64f3f2b89e4d8edee1d37d7b961537be8c75888e`. The preview package is `dist/29566-FORREF-1.0.28-20261128112329.zab` (402308 bytes, sha256 `f1c7131e58d8519af5e4b2bd1389806dccedb594e68daf196c9d3fc3629e6f32`). It is not committed. The QR expires `2026-12-05 11:23:32` on the machine clock (UTC), which is 13:23 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/szAOIhUILPNDldiLflpCQcdhupAITYtt`. That decode is a package check. This package does not certify side parity, the HTTP failure, lock, or activation on a Bip 6.

`1.0.27` remains `dist/29566-FORREF-1.0.27-20261128095218.zab` (403684 bytes, sha256 `493d9f3c825b224f17bbd0e2dd20a63bd1e719ba7bb87d14983b468376944b63`), boot `build=com-004-lock rev=f6efb1680837a4b2a09ac7c002c99ef9dc2300c4`. Its QR expired text was `2026-12-05 09:52:21` UTC, 11:52 Europe/Bucharest. The page showed `fetch:transport`. A Zepp JS App Log source still contained `tx=recover method=`. Those were not correlated.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.27` (code 27), boot `build=com-004-lock rev=f6efb1680837a4b2a09ac7c002c99ef9dc2300c4`. The preview package is `dist/29566-FORREF-1.0.27-20261128095218.zab` (403684 bytes, sha256 `493d9f3c825b224f17bbd0e2dd20a63bd1e719ba7bb87d14983b468376944b63`). It is not committed. The QR expires `2026-12-05 09:52:21` on the machine clock (UTC), which is 11:52 Europe/Bucharest. Decoding the ASCII QR yields `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/mYERKPtHKexgtRLiQotKEMIqGtmdpEzw`. That decode is a package check. This package does not certify lock or activation on a Bip 6.

`1.0.26` remains `dist/29566-FORREF-1.0.26-20261128092614.zab` (402140 bytes, sha256 `f1e21da770d391ed8f5e53d44dcc0c7c151133d4922833aa87a469600b5518e6`), boot `build=com-003r-prepare rev=b577dd41cbbb82867233203acb6b79b5d7e273da`. Its QR expired text was `2026-12-05 09:26:17` UTC, 11:26 Europe/Bucharest. The founder reported the visual CONFIG PREGĂTIT pair above. No console excerpt was attached.

`1.0.25` remains `dist/29566-FORREF-1.0.25-20261128090106.zab` (400886 bytes, sha256 `a54d1c044a2b5812c75ea50bf18861bc55d51b44b9396410a1132777cd28e297`), boot `build=com-003-prepare rev=01a29c0b1e06b3e098938df61fa66274b1f5bcbe`. Its QR expired text was `2026-12-05 09:01:11` UTC, 11:01 Europe/Bucharest. The founder reported the page words above. No console excerpt was attached.

`1.0.24` remains `dist/29566-FORREF-1.0.24-20261128084201.zab` (390810 bytes, sha256 `6325f613bfb7cd730cb43fd665f294059d3df6808acb8f4d12123e9d161b6db7`), boot `build=com-002r-link rev=63bf267d3031941b443f86473187903f3008627f`. Its QR expired text was `2026-12-05 08:42:05` UTC, 10:42 Europe/Bucharest. The founder reported PING, navigation, and Bluetooth reconnect as pass on that build. No console excerpt was attached.

`1.0.23` remains `dist/29566-FORREF-1.0.23-20261128080833.zab` (388548 bytes, sha256 `502844ffdfdd77cf57045c1d2df2945ccb2d73478c711a531475b1cf39015d8c`), boot `build=com-002-link rev=557f3f54dbf62d88d8a3f723b75ffca7a13a816e`. Its QR expired text was `2026-12-05 08:08:35` UTC, 10:08 Europe/Bucharest. On the Bip 6 that package returned PONG for repeated PING on one visit and after a full reopen, and DOWN after Back → Settings → LINK.

The previous open package remains `dist/29566-FORREF-1.0.22-20261128075209.zab` (358060 bytes, sha256 `1903cb8c226cca472b042237d3a3dff21ddab9f9d296a2b6e8dc3deda1e08aeb`), boot `build=com-001-open rev=b89abb97e2c31162e145f6b62041ee2d6f3aed3d`. Its QR expired text was `2026-12-05 07:52:12` UTC, 09:52 Europe/Bucharest.

`1.0.21` (`dist/29566-FORREF-1.0.21-20261128073806.zab`, sha256 `87e5359aeb774a47ed2a41f3695a7af8dc56083d4d6095c0724c72d84c2de835`) rebooted the watch. Its provision page bundle contained `createConnect`. `1.0.20` (`dist/29566-FORREF-1.0.20-20261127215753.zab`, sha256 `5b0d9a44f47dc500883931b6644ada18fbdc1e9d4dff4631e26bdb3f868554bf`) also stayed black and rebooted. `1.0.19` (`dist/29566-FORREF-1.0.19-20261127101748.zab`, sha256 `84a4589771e69967cdc75a376d197434521c3a0e7cdbb1e7f008dc952ae02482`) paints the UUID and does not initialize `globalData.messaging`.

`1.0.18` (`dist/29566-FORREF-1.0.18-20261127100800.zab`, sha256 `38bae40d41a92d9c6aa426810adbc2406b263e69ae28ab604e13d9cf84108583`) is the build that opened a blank provision page. The `1.0.17` package is the earlier transport build.

```
[FORREF - 1.0.28]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀▀▄▄ ███▄█ ▀▄▄██ ██▀█ ▄▄▄▄▄ █
█ █   █ ███▄█  ▄  ██ ▀ █▀  ▄█ █ █   █ █
█ █▄▄▄█ ██▄▀▄▀███ ▀ ▄▀██▀▀▀██▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀▄▀ █ █▄▀ █▄█▄▀▄▀ █▄▄▄▄▄▄▄█
█▄ ▀  ▀▄▀█ ▄▄▀▄  ▄▀▀██▀ ▀▄█▄▀ █▄▀▀██▀▄█
█ ▄▀▀ ▀▄ ▀██ ▀█    ▀▀▀█▄ ███▄▄▀   ▄ ▄ █
██▀ ▀▄▀▄▄▀ ▄▄▄▄▀  ▄█▀▄██▀ █▀▀ █▄ ▀ ▀ ▄█
█▀██  ▄▄ ▄▀▄ ▄▄█▄▀█ ▄ ▄▀█ █▄ █   ▀█▀█ █
█ ▄   █▄▀▀▄ ▀▀█▀▄▄▄▀█ ▀ ▄█ █▀█▄▄ █ ▄▀▄█
█ █ █  ▄▀ ▀▄▄▀ ▀ ██▀▄ █▀▄  █ █▄▄▀▄▀█▀▄█
█████  ▄▀▀▄▀█▄ ▄▄▄█▀▀▄██▀█▀▀ ▄█▄  ▄▀███
█▀  █▄█▄▄ ▄ █▄█ ▄▀ ▀▀██▄ ▀▄▀ █▀█▀█▀▀▀ █
█ █▀ ▄█▄▄ ▀▄█▀▀█ ▀▀▀▄█▀█ ▄▀█▀▄▀▄▄▀██ ▄█
█ ▄ ▀▄ ▄▄▀▄██▀▄ ▄▄█▀ ▄█▀▀█▄ ▄ ████  ▄▄█
█▄█▄▄▄▄▄█    ▄▄▀▀█▀▀ ▄▀ █  █  ▄▄▄ ▄▄▄██
█ ▄▄▄▄▄ ████▀▄ ▀  ▄▀ ▄▄█ ▀▀█▀ █▄█ █▄█▄█
█ █   █ █  ▄▄▀ ▀ ▄ ▀ █▀▀▀█▀ ▄   ▄▄ █ ▀█
█ █▄▄▄█ █▀▄█ ▀ █▄█ ▄███▄ ▄▄▀ █▄▀ ▄▀▀▀ █
█▄▄▄▄▄▄▄█▄▄█▄▄▄██▄▄█▄▄███▄███▄█▄██▄██▄█
```

```
[FORREF - 1.0.27]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀▀▄▄▄▄▄▀▄█▀▀▄▄██ ██▀█ ▄▄▄▄▄ █
█ █   █ ███▄█  ▄▄▄█▄▄█ █▀  ▄█ █ █   █ █
█ █▄▄▄█ ██▄▀▄▀█▀█▄▀ █▀██▀▀▀██▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀▄▀ █▄█ █ █▄█▄▀▄▀ █▄▄▄▄▄▄▄█
█ ▄█▄▄▀▄██▄▄▄▀▀ █▄▀▀██▀ ▀▄█▄▀ █▄▀▀██▀▄█
█ ▄█▀ █▄▀█   ▀█▀▄▄▀▄▀▄█▄ ███▄▄▀   ▄ ▄ █
█▄    █▄▀▀▀▀▄▄▀▀█ █▀ ███▀ █▀▀ █▄ ▀ ▀ ▄█
██▀   █▄▄██▄ ▄▄ ▄███▄▄▄▀█ █▄ █   ▀█▀█ █
██ ▄  █▄▄█▀▀▀▀▄▀▄████ ▀ ▄█ █▀█▄▄ █ ▄▀▄█
█▄██▀▀█▄█▀▄▀▄▀   █▄  ▀█▀▄  █ █▄▄▀▄▀█▀▄█
█▄ █▄█▄▄██ ██▄▄ █▄▄▀█▄██▀█▀▀ ▄█▄  ▄▀███
██▄▄▀ ▀▄▀ ███▄█▀▄█▀██▀█▄ ▀▄▀ █▀█▀█▀▀▀ █
█▀█▀▄  ▄▄████▀██ ▀███▄▀█ ▄▀█▀▄▀▄▄▀██ ▄█
█ ▄▀▀█▄▄█▀▄▄█▀█▀ ██▀ ▄█▀▀█▄ ▄ ████  ▄▄█
█▄██▄▄█▄█  ▀ ▄▄▀▀█ █ ▄▀ █  █  ▄▄▄ ▄▄▄██
█ ▄▄▄▄▄ ██▀█▀▄▀█▄██  ▄▄█ ▀▀█▀ █▄█ █▄█▄█
█ █   █ █ █ ▄▀ ▀▄█▀▀ █▀▀▀█▀ ▄   ▄▄ █ ▀█
█ █▄▄▄█ █▀█▄ ▀ █▄  ▀███▄ ▄▄▀ █▄▀ ▄▀▀▀ █
█▄▄▄▄▄▄▄█▄▄▄▄▄▄██▄██▄▄███▄███▄█▄██▄██▄█
```

```
[FORREF - 1.0.26]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄ ▀██▀▄███▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄▄ █▄▄▀▀  ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █▄▀█▀█▄███ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █▄█▄█▄█ █▄█ █ ▀ █▄▄▄▄▄▄▄█
█   ▀█ ▄▀▄▄ ██▀▀█ ▄▀█ ▀▄  █▀▀▄▄  ▄█▀  █
██▄▄██ ▄▄▄▀▀▄█▄  ▄██ ██▀▄▀▄█▄▀█▄▀ ▄█ ▄█
█ █ █▀█▄▀ ▄▀▄ ▀█ ▀ ██ ██▀▄▀█▀ █ ▄█ ▀  █
█▄▀█▀ ▄▄▀▄▀ ▀ ██▄▀▄▄  ▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█▄▄▄▄  ▄▄▄█▄██▀▀▄▀██  ▀█ ▀▀█▀   ▀█ ▀█ █
█▀▄▄█  ▄▄██▄▄██▄▄ ▄  ██▀▄▄▄▀ █▄ █ ▀█▀ █
██▄ ▀▀▀▄▄▄█▀▄ ▄▀  █▀█ █▀ ▀▀▄  ▄  █▄█▄▀█
██▄ ▀▄▀▄▄ ▄█▀ █▄▄██▀▄██▀▄██▀  █▀ █▀▄█▄█
██▀▄  █▄ █▀▄█████ ▀█▀ ▀█  █▀▀▄▀  ███  █
█▄▄▀█▄▄▄▀ ▀ ▄██▀  █▄ ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄▄▄██▄█ ▄█▄ █▀ ▀▄▀▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀▀ ▀ █ ▄ █▄▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ███▀██ ▄▄▀▄▀  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▀ ▄█▀█ ▄▄▀▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄▄▄▄▄▄██▄▄█▄▄███▄███▄█▄██▄██▄█
```

```
[FORREF - 1.0.24]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █▄▀ ▀ ██▄ ▄▄▄▄▄█ ▀█▄█ █ ▄▄▄▄▄ █
█ █   █ █   █▀▄▀ ▄██▄▄█▀▀▀   ▄█ █   █ █
█ █▄▄▄█ █▄█▀ ▄▀▀▄ ▀▀ ▀▄██▄██▄▄█ █▄▄▄█ █
█▄▄▄▄▄▄▄█▄█ █ █ █ ▀▄█ █▄▀ █▄▀ █▄▄▄▄▄▄▄█
█ ▄▄ █▀▄█ █ ▄ ▀ ▀ ▀ ▄ ▄▄▀██ ▄▄▄█▀▄  ▀▄█
█▀█▄▄ ▄▄█▀▄ ▄▄ ▄▀ ███▄▄▄▄ ▀██▄██▄ █  ██
█▀   ▄█▄█  █▀ ▀  ▀█████▄▄▄  ▀▀  █   █ █
█▄█▀▀ ▀▄▀▄██ █▄▄▀ ██▄█▀██▀█ █▀ ▀ █ ██▀█
█▀▀██ ▄▄ ▀  █▄ ██▄ ▄      ▄█ █ ▀▄█▀▄█▀█
█ ▄▄  ▄▄▀  ▄▀█▄  ▀▀████ ▀▄█▄ ▄▀ ▄█▀▄▄ █
███▀███▄ ▄▄ ██▀▄  █  ▀ ▀▀▄▀██ ██ ▄▀██▄█
█▀▀█▀  ▄▄ ▄ ▀▀ ▄█▄█▄█▄▄▄▄▄ ▀▀██ ██ ▀███
█▄█ █▄▀▄█▄▄█ █▄   ▀█▀█▀▄█ ▄▄▀█▄ ▀ █▄█ █
█▀▄█▄▄▀▄███ █ ▄▄█▄██   █▀▄▄▄▀▄█▄█▀█▄▄██
███▄▄▄█▄▄  █▄▀▄█▀▄█ ▄▄  ▀█▄█▀ ▄▄▄ █▄  █
█ ▄▄▄▄▄ ██▄▄▄ ▄█ ▀  ██▄▄██▄▄▀ █▄█ ██  █
█ █   █ █▀▀█▄  █▀▀█  ▀▄█▀▄▀▄▀▄  ▄ █▀  █
█ █▄▄▄█ █ █▀▄▄▄███▄ ▀█▄▄▄▀ ▀▀█ ▄▄▄ ▀███
█▄▄▄▄▄▄▄█▄███▄█▄▄██████▄▄▄▄▄██▄▄▄▄▄▄▄▄█
```

```
[FORREF - 1.0.23]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ ██▀▀▄▄▄ ███▄██▄▄██▄▀█▀█ ▄▄▄▄▄ █
█ █   █ █▀███ ▀█▄▄▀▄▄▄ ▄▀ ▀▄█▀█ █   █ █
█ █▄▄▄█ █▄▄█▀▀▄▀█▄ ▀█▄█▀▄▀▀▄█ █ █▄▄▄█ █
█▄▄▄▄▄▄▄█▄█ ▀▄█▄▀▄█ █ █▄█▄█ ▀ █▄▄▄▄▄▄▄█
█ ▄▀█▀▄▄▄█ █▄▀▀ ▄▄▄███▀▀▀▄▄▄▀▀██▀ ▄█▀██
███▀██ ▄▀▀▄▄█▀▄▀▄ ▄▄▀▄█ ███▄▄ ▄  ▀▄▄▀ █
█▄▀ █ █▄ ▀ ▄▄▄▄▀▄ ▄▀▄ ██▀ ▀█▀ █▄▄█ ▀ ▄█
█▄▀▀█▄ ▄▄█▀█ ▄█  ▄██▀█▄ █ ▄▄ ▄  ▀▀█ █ █
███▀▄█▀▄▀   ▄▀   ▀▀▀█▀▀▄▀█ ▄▀▀▀▄ ▄  ▄▄█
█▀▄ █▀ ▄▀  ▄▄▀█▄  ██  █▀▄ ▄▀ █▄▄█ ▀█▀▄█
██▀▄▄█▀▄█  ██▄█▄▄▄ ▀▄██▄▀█ ▀ ██▄▀ ▄ ███
██ █▄▀ ▄▀▀ █ ▄▄▀ ▄██▀▄█ █▀▄  ▀▄█▀▄▀█▄ █
█ ▄▀▄▄▀▄█ █▄█▀▀█▄ ██▄ ▀█ ▄█▀▀▄▀▄ ███ ▄█
█ █ █ █▄ █▄ █▀▄▄▄ █▀▀▄█ ▀██ ▄▀██▄█ ▀▄▄█
█▄█▄██▄▄▄▀▄▀█▄█ █  ▀ █▀▄   ▄  ▄▄▄ ▄ ▀██
█ ▄▄▄▄▄ █ ██▀▄█ ▄ ██▄ ▄█ ▀█▀▀ █▄█ █▄█▄█
█ █   █ ███ ▄▀▀▀▄█▀▀▀█▀ ▀█  ▄   ▄▄ ▄ ▀█
█ █▄▄▄█ █▀ ▄█▀ ▄ █▄▄█▄█ █▄▄  ▀▀▀ █▀█▄ █
█▄▄▄▄▄▄▄█▄█▄▄▄▄█▄▄██▄▄███▄███▄█▄██▄██▄█
```

```
[FORREF - 1.0.22]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄ ████▄ ▄█▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄▄▀▄█▄▀█▀ ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █▄▄██ ████ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █ █ █▄█ █▄█ █ ▀ █▄▄▄▄▄▄▄█
█ ▄▄▀█ ▄▀▄  ██▀█▄▀ █▀ ▀▄  █▀▀▄▄  ▄█▀  █
█▀▀ ▄█ ▄▀▀ █▄██▄  ▄▄ ▄█▀▄▀▄█▄▀█▄▀ ▄█ ▄█
██▀ ▄ █▄█▀▄█▄ ▀██ █▀█▀██▀▄▀█▀ █ ▄█ ▀  █
█▀█ ▀█▄▄▄█  ▀ █ ▄▄▄█  ▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█ ▄▀ ▀▄▄  ▄ ██▀█▀▀█▀ ▀▀█ ▀▀█▀   ▀█ ▀█ █
███  ▄ ▄█▀  ▄██▀▄███ ██▀▄▄▄▀ █▄ █ ▀█▀ █
█ ▀▀▄▀ ▄ ▄ ▄▄ ██ ▀▄█▄▀█▀ ▀▀▄  ▄  █▄█▄▀█
██▄  ▀▄▄▀█▀█▀ ▄█ ▄▄  ██▀▄██▀  █▀ █▀▄█▄█
█▄▄ ▄█▀▄ █▄█████▀▀▄█▄ ▀█  █▀▀▄▀  ███  █
█▄▄▀█▄▀▄█ ▀▀▄█▄▀ █▄█ ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄▄█▄█▄▄▀  ▄ ██▄ ▄▀▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀██▀ █▄▄█▄█▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ██ ▄██ ▄█ ▄█  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▀▀▄█▀█▄▄▄▀▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄██▄▄▄█▄███▄▄███▄███▄█▄██▄██▄█
```
