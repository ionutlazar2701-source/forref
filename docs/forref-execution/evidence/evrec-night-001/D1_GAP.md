# D1 gap — EVREC-NIGHT-001

`MATCH MEMORY AUTHORITY ON WATCH: NOT ENABLED`

`D1 / POWER-LOSS: NOT CERTIFIED`

`SAVED: NOT EMITTED`

`KNOWN SCORE ON WATCH: NOT EMITTED`

The local goal journal can verify that the bytes just written are the bytes just read, inside one process or after a new journal object reads the same memory or file double. That observation is `LOCAL RECORD VERIFIED — D1 UNCERTIFIED`. It is not `DurableCommitSuccess`.

`captureStorageCertified` is hard-coded false. `authoritativeCaptureAdmitted` is therefore false. The public Zepp file API used by the clock still has no `fsync` and no documented power-loss barrier. This mission did not change that API and did not run a power cut.

Simulated short writes, torn tails, and process-object recreation are fail-closed software tests. They do not certify physical power-loss durability.

The phone SQLite store still uses `journal_mode=DELETE` and `synchronous=FULL`. Those settings were not weakened. Phone D1 for the provision stage is the existing store contract. It does not certify the watch journal.
