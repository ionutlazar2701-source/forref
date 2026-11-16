# LOTG reason annotations — follow-up contract

Not implemented. V1 `YellowCardPayload`, `YellowCardPayloadV2`, and `SendOffPayload` have no offence article, location, or LOTG reason field. Adding one would be a schema decision under ADR-018: new readers and writers, no rewrite of committed bytes.

## Decision required before any code

Approve a new payload schema version, or a new record that references the existing disciplinary record id. The annotation must be its own committed record or an additive payload version. It must not update the Yellow or send-off row in place.

Until that decision:

- The report line carries the subject, scope, pathway, standing, and legal effect the current resolvers already return.
- It does not display an offence name, article number, or "unsporting behaviour" label.
- Research S2.5R labels are not copied into production as reasons.

This scope stops here. Goal, Yellow, send-off, substitution, and temporal projection do not depend on it.
