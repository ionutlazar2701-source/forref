# Sync contract research

This package is a headless research model of phone and watch sync facts.
It is not production sync, not a watch client, and not Match Memory.

Nothing here pairs a device, opens a socket, reads a battery, or writes a
match record. `readyForThisContext` is a simulated label. It is not a
production watch-ready claim.

Transport acknowledgements are `notSent`, `sent`, `received`, and `admitted`.
None of them means Saved. Watch-origin durability is not proven here.

An authority lease is not implemented. That needs Architecture, Gene, Domain,
and Tony before any production wire exists. Founder decides production cutover.

The phone app’s `NoPeerTransport` is unchanged. These tests do not call it.
