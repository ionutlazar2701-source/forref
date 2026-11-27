# COM-001 Bip 6 protocol

State: **NOT TESTED**. Fill every row on a physical Amazfit Bip 6 with the phone debug bridge. Unit tests do not certify the handshake. Do not mark Level 2 from this file until every row has a copied log.

App id `29566`, version `1.0.17` (code 17), boot `build=com-001 rev=9b662fbf1c4ee4f75ce01d05b215c1ac589cae34`. Install `dist/29566-FORREF-1.0.17-20261127093720.zab`. The QR is in `TEST_RESULTS.md`. It expires 11:37 Europe/Bucharest on 4 December 2026.

This is the Android-local debug route only: Flutter debug bridge on `127.0.0.1:47221`, path `/watch-provision/v1`, then the Zepp Side Service, then the watch page. It is not a production transport. An active match must not need this link. Goal capture stays on the watch. This protocol does not enable Goal-to-phone replication.

## What to copy

From the watch console and the phone debug console, copy the `FORREF_PROVISION` lines for the trial. Each line is one of `tx=request`, `tx=response`, `tx=transition`, `tx=recover`. Keep `installation`, `request`, `match`, `hash`, `generation`, `http`, `disposition`, and `reason`.

Do not paste the canonical document or the team names. After the trial, record three facts in the Result column:

- Phone root: absent, or the one device id.
- Watch admission: the state named by the page or the last `tx=transition`.
- Correlation: the request id, and whether a retry used that same id.

A line with `disposition=prepared`, `locked`, or `recorded` while `http` is not 200, or while `durable` is true on a prepared or recorded body, fails the trial. A second authority root fails the trial. A new request id on a retry of the same watch and match fails the trial.

## Trial matrix

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| PREPARE | On the phone, prepare one watch-operated match and start the debug bridge. Open the watch provision page. | One `tx=request` for pending, one `tx=response` `disposition=prepared`, one `tx=transition` `phase=verified`. No root yet. | NOT TESTED |
| LOCK | Leave the page on that match until the lock request returns. | `disposition=locked`, `durable` true, one phone root whose device id is the watch installation. Watch phase `activated`. Same request id as PREPARE. | NOT TESTED |
| REPORT | Stay on the page until the activation report returns. | `disposition=recorded`. Watch phase `reported`. Same request id. Still one root. `saved` and `d1Certified` stay false. | NOT TESTED |
| LOST-LOCK | After PREPARE, turn Bluetooth off before the lock response is visible, then turn it back on and open the provision page again. | The retry uses the same request id. One root. No second `phase` that goes backwards. | NOT TESTED |
| LOST-REPORT | After the watch shows activated, turn Bluetooth off before `recorded`, then reconnect and open the page again. | Watch stays activated. The retry reports `recorded` with the same request id. One root. | NOT TESTED |
| SIDE | After PREPARE, force-stop the Zepp app side and open the provision page again. | Same request id. No second root. The page does not show a prepared document for a different match. | NOT TESTED |
| BRIDGE | After LOCK, stop and start the Flutter debug process, then repeat the lock from the watch. | The phone correlation file still has the same request id. A `readBack` failure is `receipt-invalid` and `durable` false. A valid retry is `idempotent-lock` and does not insert a second root. | NOT TESTED |
| REPEAT | Send the same pending, lock, and activation again without changing the match. | Dispositions stay prepared, locked, and recorded. Request id unchanged. One root. | NOT TESTED |
| LIVE | Kick off. Turn Bluetooth off for 30 s during the half. | The clock and local goal path continue. No provision request is required to keep the half running. | NOT TESTED |

HTTP 409, HTTP 500, malformed JSON, and a contradictory body are covered by the software rows in `TEST_RESULTS.md`. They are not a substitute for the rows above.
