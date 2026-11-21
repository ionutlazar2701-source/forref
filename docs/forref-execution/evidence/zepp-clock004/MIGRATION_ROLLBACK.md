# CLOCK-004 migration and rollback

The v1 checkpoint is unchanged:

- `forref_clock001c_state.json`
- `forref_clock001c_state.mirror.json`
- LocalStorage key `forref_clock001c_state`

Those files stay schema `v:1` plus the FNV-1a trailer. CLOCK-004 never writes them.

The new record is a pair of slots:

- `forref_clock004_a.json`
- `forref_clock004_b.json`

Envelope `{ v: 2, raw, hash }`. `raw` is a JSON body with `v: 2` and `engine: "utc_segment"`. The sequence number chooses the slot (`even` → A, `odd` → B). A commit reads the slot back and refuses a non-monotonic sequence, a same-sequence conflict, or a body that does not match the readback.

`forref_clock004_engine.txt` is the rollback switch. Absent or empty means `utc_segment`. The exact text `sampler` means the previous clock.

## Boot

1. If the engine file says `sampler`, load the v1 checkpoint with `loadSession`. The 2.5 s gate still applies. Segment slots are left in place and are not displayed.
2. Otherwise read the two slots. The higher sequence wins. One intact slot is enough. Two torn slots, or the same sequence with two different bodies, fail closed. A corrupt segment store does not fall through to the v1 file.
3. If both slots are empty, decode the v1 checkpoint without applying the 2.5 s gate. A running v1 record with a live anchor and trust other than `TIME_UNVERIFIED` becomes a `utc_segment` session, so a match that was already running can be reconstructed after sleep. A v1 record that is already `TIME_UNVERIFIED` stays unverified. An empty v1 store starts a fresh `utc_segment` ready state.
4. A migrated session is committed to the new slots once. The v1 bytes are not rewritten.

## What is not authority

The App Service still watches only the v1 file pair. Live boot does not start it for a `utc_segment` session. The service is not required for the segment clock, and it is not retargeted onto the new files.

Display projection is not a Match Record. Phase changes are the commits. A failed readback does not acknowledge the phase change.

## Rollback

1. Create `forref_clock004_engine.txt` containing `sampler` and nothing else.
2. Restart the app. The next boot uses `loadSession` on the v1 files.
3. Remove that file to return to the segment store. If the slots are intact, they win over v1. If they are corrupt, boot fails closed instead of inventing a match from v1.

Rollback does not delete the slots. Uninstall clears the app data directory, including both generations.

A v1 file that the old sampler service already marked `TIME_UNVERIFIED` cannot be repaired by removing the engine file. The segment slots, if committed, remain the live record while the engine file is absent.

## Safe recovery

- Empty slots and empty v1: ready, no match invented.
- One good slot: that slot.
- Both slots torn, or a same-sequence conflict: `TIME_UNKNOWN`, kick-off refused.
- Legacy conflict or corrupt v1, with empty slots: `TIME_UNKNOWN`, kick-off refused.
- Detected discontinuity: new sequence, digits hidden, previous slot retained as the prior record.
