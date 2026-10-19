# Night program ledger

Status of this file: RECORD

Canonical contracts: [FOUNDATION_FREEZE.md](../FOUNDATION_FREEZE.md), [architecture-authority.md](../../architecture-authority.md). This directory does not copy Foundation semantics.

START BASE SHA: `6ec364cee2af78dc3f2f3d2c4110b95f4660f780`

That SHA descends from production baseline `fa4a7976e153e7a0096aaad2958116a3a97f5bc1` and Foundation `5772671a9674e00c372268047d5f54073610af22`.

Library diff `fa4a7976..6ec364c` under `packages/**/lib` and `apps/**/lib` is empty. The two commits after production are test attacks and this evidence record.

WAVE 1: ACCEPTED / CLOSED

WAVE 2+: AUTHORIZED ONLY THROUGH THIS NIGHT PROGRAM DAG

Branch: `cursor/forref-night-program-30fd`

NIGHT_EXECUTION_BASE_SHA: `6ec364cee2af78dc3f2f3d2c4110b95f4660f780`

N0 record SHA: `1a627090e59607eaa8015fe62af75224ff9af4ca`

BANK A SHA: `6d9549da23e87b66e4a7528e71dcae2ec767fbf5`

BANK B / C / F behavior SHA: `f0f5e968925921139e41da06a9a384cc2078ba78`

Analyzer-only production tip: `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c`

Saboteur tests: `cd6e2a952a7412cce8628f5bddf99f7e43bf459a`

BANK D: HOLD. BANK E: HOLD. Phone cutover: HOLD. See [HOLD_PACKETS.md](HOLD_PACKETS.md).

`./tool/verify_cloud.sh` on `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c`: PASSED. Exit 0. Core 260, persistence 58, phone 125. TEST EXECUTED PASS. Not CI PASS.
