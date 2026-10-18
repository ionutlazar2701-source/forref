# Dependency graph and authority gates

HISTORICAL EXECUTION GRAPH — superseded for current sequencing by [PROGRAM_LEDGER.md](../forref-development/PROGRAM_LEDGER.md) and [FOUNDATION_FREEZE.md](../forref-development/FOUNDATION_FREEZE.md).

Base: `919c9062d607f0af255ad368b8c6cb2658d6c85a`.

```text
FROZEN (already in repo at this audit)
  architecture-authority ADR-001–018
  D1-before-Saved
  v1 semantic vocabulary (temporal + correction/supersession)
  no auto-red
  no watch screens until visual design is decided
HISTORICAL BASELINE AT ORIGINAL AUDIT:
  phone-first
SUPERSEDED BY FOUNDATION DEVICE OPERATING MODEL:
  phone complete fallback
  certified active watch may be primary autonomous in-match authority
        │
        ├─ WAVE NOW (done on cursor/forref-wave1-integration-30fd)
        │    score fail-closed tests
        │    temporal precision attacks
        │    disciplinary fail-closed tests + legacy no-auto-red
        │    research/live_core_a protocol harness (no humans)
        │    research/a_physical geometry checker (no hardware pass)
        │
        ├─ HOLD: 002D-1B human and hardware evidence
        │    object exists on PR #12 at fda5af6, not merged,
        │    static research instrument, no Match Record commits,
        │    no human study, no hardware certification
        │
        ├─ HOLD: A-PHYSICAL certification
        │    LOCAL GATE REQUIRED — device matrix + measured hit regions
        │
        ├─ HOLD: A-REFEREE scored collection
        │    harness exists; participants, pre-registered thresholds,
        │    and an accepted Recall instrument do not
        │
        ├─ HOLD: C-SIDECAR screens
        │    open decision: visual design
        │
        └─ HOLD: Capture Foundation freeze
             needs module ownership accepted by architecture
             AND must not invent Goal/Yellow/Red/Sub rules
                  │
                  └─ HOLD until that SHA exists
                       Goal, Yellow, Red, Substitution branches
                            │
                            └─ HOLD: watch integration, saboteur of that
                               integration, product evidence pack
```

## Package gates

| Package | Prerequisite still open | If missing, the only legal result |
| --- | --- | --- |
| A-PHYSICAL certification | Named measured devices | `DEVICE MATRIX REQUIRED`, `LOCAL GATE REQUIRED` |
| A-REFEREE scored study | Pre-registered thresholds; humans; 002D if the task is Recall depth | Do not invent thresholds or participant results |
| C V2 | Visual-design decision | Do not draw production or prototype screens in this repo |
| 002D-1B | Object exists on PR #12 at fda5af6, not merged, static research instrument, no Match Record commits, no human study, no hardware certification | HUMAN EVIDENCE ABSENT. HARDWARE EVIDENCE ABSENT. Not merged |
| Foundation freeze | Explicit architecture acceptance; no new sporting payload | `FOUNDATION DELTA REQUIRED` or remain draft |
| Goal / Yellow / Red / Sub | Foundation SHA plus that event’s Minimum Irreversible Truth | `DOMAIN CONTRACT REQUIRED` |
| Watch integration / saboteur | The four event SHAs plus Live Core A SHA | Do not start |
| Numeric score display | Score Projection Trust contract (freshness, completeness, uncertainty) | Keep score facet untrusted; no invented numeral |

## Shared files

Root `pubspec.yaml`, `pubspec.lock`, `tool/verify_cloud.sh`, and every `lib/` tree had a single rule this wave: no feature agent edits them. The integration branch still obeys that. Research packages are standalone and are not workspace members.
