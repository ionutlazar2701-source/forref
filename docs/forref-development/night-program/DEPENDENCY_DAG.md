# Night program dependency DAG

A later wave starts only when every named dependency is PASS.

| Wave | Bank or bridge | Depends on |
| --- | --- | --- |
| N0 | Baseline lock | Evidence SHA `6ec364c` |
| 2 | BANK A participant identity | N0 |
| 3 | BANK B participant Yellow | BANK A |
| 4 | BANK C caution awareness | BANK A, BANK B |
| 5 | BANK D SEND_OFF | BANK A. Sufficiency check before code |
| 6 | BANK E substitution / status | BANK A. Lawful-entry proof before commit |
| 7 | BANK F referee field-entry | N0. Independent of Yellow |
| 8 | Identity ↔ Yellow ↔ awareness | BANK A, BANK B, BANK C |
| 9 | Status ↔ awareness | BANK C, BANK E |
| 10 | Awareness ↔ SEND_OFF | BANK B, BANK C, BANK D |
| 11 | Lifecycle ↔ discipline | BANK F and the disciplinary banks that passed |
| 12 | Phone cutover | Only PASS banks and bridges |
| 13 | Cross-domain attack | Implemented banks |
| 14 | `./tool/verify_cloud.sh` | Implemented banks |
| 15 | Morning handoff | The record of what passed and what is held |
