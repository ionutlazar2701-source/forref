# Hardware gate — CLOCK-CONTINUITY-003

Status: **LOCAL GATE REQUIRED**.

Cloud tests and the Zeus package do not certify Amazfit Bip 6. FORREF 1.0.5 already showed a permission prompt and still lost the clock during screen sleep and during Goal, Card, and Substitution. 1.0.6 is a diagnostic build of the boundary in `ROOT_CAUSE.md`. Install it only to collect logs.

Certification waits until the protocol in `HARDWARE_PROTOCOL.md` passes on the watch. Until then, do not treat a displayed time after an unexplained gap as verified match time.
