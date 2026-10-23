# Event journal contract

The event journal is an observer. It is not Match Memory.

It records, in order:

1. IntentReceived
2. CommandFrozen
3. CaptureAdmissionStarted
4. CommitRequested
5. CommitReturned
6. RecordReadBack
7. ProjectionRebuilt
8. PresentationUpdated

A journal write that throws after the store has committed does not roll the record back. Clearing the journal does not delete the sqlite row.

The lab can render a journal snapshot. That rendering is not a second commit.
