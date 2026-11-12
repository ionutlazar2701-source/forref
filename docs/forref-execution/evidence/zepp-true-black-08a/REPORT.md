# TASK 08A — Jony True Black, P0 audit and P1 candidate

Functional baseline: PR #44, `c993055fbeb4e769174aaf86d5aa4889ee95c21d` on `cursor/zepp-live-match-flow-002-30fd`. Fetched again on 13 Nov 2026. Local and `origin` both point at that commit. PR #44 stays open and unmerged.

Design branch: `cursor/zepp-true-black-08a-30fd`, taken from that commit. This branch adds the audit and the color candidate. It does not change Zepp paint code, Match Core, clock logic, or persistence.

## Completion contract

| Field | Result |
| --- | --- |
| AUDIT STATUS | P0 complete. 23 registered routes. Historical 22 is superseded by Match Controls. |
| FIGMA CANDIDATES | File [FORREF True Black — P1 candidates](https://www.figma.com/design/9qYb5Y2tQksmx4TD75yqjV). The write returned 21 frames and the token collection `FORREF True Black`. A later read was refused by the Figma Starter plan tool limit, so the review images in `candidate/` are the pixel boards of the same geometry and the same hexes. |
| FOUNDER P1 VISUAL GATE | **Open.** ACCEPT, REVISE, or REJECT the candidate and the accent hexes. The approved True Black direction is not screen approval. |
| NATIVE IMPLEMENTATION STATUS | Not started. Theme code stays on the current navy palette. |
| 23-ROUTE COVERAGE | Source audit 23/23. Every route paints through `paintBase`. Simulator photos cover the live, event, settings, controls, display, and home surfaces on both shapes. The remaining stack routes share that chrome. |
| ROUND / RECTANGULAR COVERAGE | Rectangular Amazfit Bip 6, 390×450, device source 10158337. Round guest paints 480×480, device source 10813699 (Active Max). Zeus was aimed at “Amazfit Active 3 Premium” for the round install. Those two names stay separate. |
| CONTRAST | Measured in `P1_CANDIDATE.md`. Current press fill `#3FC3BE` with white text is 2.15:1. The candidate keeps one text color per button and stays at or above 4.5:1 in rest and press. |
| PACKAGE SIZE BEFORE / AFTER | Before: Bip 6 `.zab` 247,838 bytes; round-target `.zab` 247,940 bytes. After: not measured. No theme bytes have changed. |
| SCREENSHOTS / LOGS | `baseline/` holds the simulator frames. `candidate/` holds the before/after boards. Package copies are `/tmp/08a-pkg/bip6.zab` and `/tmp/08a-pkg/round.zab`. |
| BRANCH / SHA / PR | `cursor/zepp-true-black-08a-30fd` from `c993055`. The PR on this branch is the design review. It is not a merge of PR #44. |
| NEXT SINGLE BLOCKER | Founder decision on the P1 candidate and the accent hexes. |

No battery figure is claimed. No D1, temporal, or signing certification is claimed.

## Gate

THEME: BLOCKED — FOUNDER VISUAL GATE

Reply with one of:

- ACCEPT — use these hexes and this rest/press treatment in the native color pass.
- REVISE — name the hex or the surface to change. Geometry stays frozen.
- REJECT — stop the candidate. The navy palette stays.

Details and the contrast table are in [P1_CANDIDATE.md](P1_CANDIDATE.md). The route and package audit is in [P0_AUDIT.md](P0_AUDIT.md).
