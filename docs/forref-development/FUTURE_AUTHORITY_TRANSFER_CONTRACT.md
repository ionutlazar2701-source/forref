# Future authority transfer

NOT IMPLEMENTED IN WAVE 1.

This file documents frozen fencing semantics so a generation-1 design does not make a later transfer impossible. It does not create an implementation task. It does not authorize generation 2, federation, leases, quorum, device election, or watch synchronization.

DOMAIN: FROZEN

ARCHITECTURE: FROZEN CANDIDATE

RELIABILITY: FROZEN CANDIDATE

SIMPLICITY: FROZEN CANDIDATE

PRODUCT COMMAND: PENDING FINAL ACCEPTANCE

## F-R5

A generation number alone is not fencing.

A future transfer is complete only when both are true:

- predecessor append authority is proven lost;
- successor append authority is proven granted.

A future transfer requires durable predecessor fencing evidence and a closed predecessor origin frontier.

If predecessor fencing cannot be proven, the transfer is not complete.

Until that proof exists, the successor must not append authoritative records as if the transfer had finished, and the predecessor frontier must not be treated as closed by assumption.

## What generation 1 must leave possible

The generation-1 MAIN_REFEREE root on one capture device must be able, later, to record that its append authority ended and that a successor's append authority began, without rewriting historical Goals and without using arrival time as authority.

This file does not specify the record schema for that future evidence.

## Recovery separation

Historical Goal validity does not grant future write authority.

Loss of the current authority root:

- does not erase independently valid Goals;
- may make the score unavailable when completeness cannot be proven;
- blocks new authoritative capture;
- does not allow silent recreation of generation 1.

## Out of scope

No transfer workflow. No second device. No watch sync. No Bluetooth or cloud replication. No election.
