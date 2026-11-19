# Build and gates

## Package

| | PR #52 baseline | True Black candidate |
| --- | --- | --- |
| File | `29566-FORREF-1.0.2-20261119212654.zab` | `29566-FORREF-1.0.3-20261119221637.zab` |
| Bytes | 239729 | 255796 |
| sha256 | `bfcefa1e6fca63a3c272ed40e2c8e66210f3146141a524cd3d899b5d87568bed` | `ce81e87e82e6643dc37fdaa99f2f3bc53b98f5b950245b003ba955aedd76a6e9` |
| Entries | zpk + json | zpk 255213 + manifest 311 |
| Screen | square 390×450 | square 390×450 |
| Version | 1.0.2 code 2 | 1.0.3 code 3 |

Delta of the preview package against the baseline package: **+16067 bytes**. Asset files remain the four existing PNGs (`gt.r` and `gt.s` icon and logo). `chrome.js` still creates three widgets: fill, text, button. No bitmap was added. Battery change is **UNKNOWN**.

An earlier `zeus build` of the same Bip 6 target wrote `29566-FORREF-1.0.3-20261119221301.zab` (328160 bytes) because it embedded `.ip-package` (72239 bytes). `zeus preview` replaced `dist/` with the package above, which has no intermediate product. The QR matches the 255796-byte file.

Preview label: `FORREF - 1.0.3`, Amazfit Bip 6. CLI expiry on the UTC clock: `2026-11-26 22:16:40` (`00:16` Europe/Bucharest on 27 Nov 2026). QR text: `PREVIEW_QR.txt`. The `.zab` is gitignored.

Boot line: `build=true-black-004 rev=5b68fa59d7540e1bc1e043fb32233f5a1f79e7d5`.

## Commands

| Command | Result |
| --- | --- |
| `npm test` in `apps/forref_watch_zepp` | 80 pass, 0 fail |
| `npm test` in `apps/forref_sensor_lab` | 34 pass, 0 fail |
| `./tool/verify_cloud.sh` | PASSED. Match Core 377 pass. Persistence 92 pass. Phone 126 pass. Analyzers reported no issues. |

Watch count includes the new `test/theme.test.js` cases for canvas `0x000000`, absence of `0x071d33` and `0x0b2d5b` on paint paths, role contrast, 23 routes, unverified warning color, protected modules, and frozen A/C/event rectangles.

## Gate matrix

| Gate | Status | Evidence |
| --- | --- | --- |
| TB01 BASELINE | PASS | PR #52 head `29d3a80a4ab6a221d42bcd667e1ea716d252846c` unchanged. This branch starts there. |
| TB02 BLACK CANVAS | PASS | `CANVAS` is `0x000000`. All 23 routes use `stack` or `paintBase`. OS status icons were not captured. |
| TB03 SEMANTIC COLOR | PASS | Role table in `IMPLEMENTATION_REPORT.md`. Yellow 4.54:1 and black team buttons are `FOUNDER VISUAL REVIEW`. |
| TB04 VIEW FIDELITY | PASS | Frozen rectangles in `ROUTE_MATRIX.md` and `test/theme.test.js`. Handlers and route ids unchanged. |
| TB05 TELEMETRY FIDELITY | PASS | Clock, session, telemetry, geometry, and copy files have no diff against PR #52. Watch telemetry tests passed. |
| TB06 REAL DEVICE TARGET | PASS | App id 29566, version 1.0.3, sha256 above, QR in `PREVIEW_QR.txt`. Founder has not installed it. |
| TB07 SIMULATOR RECT | BLOCKED | Simulator disconnected. No guest frames. `SIMULATOR VISUAL GATE BLOCKED`. |
| TB08 SIMULATOR ROUND | PARTIAL | Active Max `480x480` package compiled. No round guest frames. `SIMULATOR VISUAL GATE BLOCKED` for pixels. |
| TB09 I18N / ACCESSIBILITY | PASS | Strings untouched. Contrast measured for every role. Yellow and neutral buttons await founder eyes. |
| TB10 NO BLOAT | PASS | +16067 bytes on the comparable package. No new bitmaps. No battery claim. |
| TB11 REGRESSIONS | PASS | Watch 80, sensor lab 34, Match Core 377, persistence 92, phone 126. `verify_cloud.sh` exit 0. |
| TB12 FOUNDER ACCEPTANCE | LOCAL GATE REQUIRED | Bip 6 visual and interaction review is not done. |
| TB13 STACK SAFETY | PASS | New branch and new PR only. PR #52 head still `29d3a80`. No merge. |

## Diff boundary

Theme edits are under `apps/forref_watch_zepp` plus this evidence directory: `theme.js`, `theme.test.js`, `chrome.js`, `app.json`, `package.json`, `build_stamp.js`, and the pages that passed a color or a role name. Match Clock, GPS/HR telemetry, distance accounting, navigation targets, and Match Memory were not edited.
