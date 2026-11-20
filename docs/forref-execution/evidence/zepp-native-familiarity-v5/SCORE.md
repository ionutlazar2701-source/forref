# Score and discipline adapters — not implemented

The Founder score rule used here: a verified new match may show 0–0 when initialization and both teams are known. Later changes require an authoritative confirmed goal record. An own goal credits the benefiting team. Corrections stay auditable.

This watch build does not have that projection. Team abbreviations and kit colors are not configured. The capture candidate is not a saved goal record. The Live buttons therefore keep the existing labels `HOME · NO SCORE` and `AWAY · NO SCORE`. They do not show 0–0, a sample score, or kit color.

A later read-only adapter would have to supply, for each side, a verified 2–4 character abbreviation, two configured colors, and one of:

- `initial-zero` only when the match and both teams are known and no goal record exists yet
- a score taken from confirmed goal records
- `unavailable`

Until that adapter exists, the UI stays on the unavailable labels.

Cautions stay on the existing blocked copy: open design gate G1, no complete ledger. The page does not write a card and does not invent a list. The ledger adapter remains an open domain gate.
