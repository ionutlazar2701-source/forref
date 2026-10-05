# Architecture authority index

**Status:** AUTHORITATIVE for **new** Match Core semantics.

Upstream contracts are frozen: **FORREF Match Core Architecture v1.0** (18 ADRs), **Match Operating Model v1.0**, **Domain Clock Policy v1**, **Product Failure Suite v1**, **SC-1→SC-5 Corruption Contract**.

This index does **not** reproduce ADR bodies. It maps ADR numbers to invariant groups so agents know where to look upstream and what must hold in code.

Legacy mutable-aggregate docs: [architecture.md](architecture.md), [data-model.md](data-model.md) — **not authoritative** for new core.

---

## Canonical flow

```text
User action (match-critical)
  → build immutable Match Record (envelope + payload + links)
  → D1 local commit (append-only Match Memory)
  → rebuild projection (deterministic)
  → Saved / UI acknowledgement

Replication (later):
  exchange immutable Match Records only
  never overwrite mutable "current match"
  never transfer MAIN_REFEREE capture authority via sync alone
```

---

## Eight foundational prohibitions

1. **No mutable authoritative Match object** — the aggregate document is not Match Memory.
2. **No in-place correction** — do not update or delete committed records to fix history.
3. **No cloud/network as Match Memory** — Firestore and peers are replicas, not capture authority.
4. **No network-required capture** after Match Ready on the autonomous device.
5. **No Saved before D1 commit** — RAM, queues, and transport accept are not Saved.
6. **No Last Write Wins** — no sync by replacing current match state.
7. **No timer/checkpoint as temporal authority** — display and checkpoints are projection inputs only.
8. **No snapshot/projection as recovery authority** — rebuild from records; snapshots accelerate only.

---

## ADR index (001 → 018)

| ADR | Topic (summary) | Invariant group |
| --- | --- | --- |
| ADR-001 | Match Memory = immutable Match Records | Authority & History |
| ADR-002 | Current state is derived projection, not source of truth | Authority & History |
| ADR-003 | Stable record identity; match identity separate from record | Authority & History |
| ADR-004 | Record kind and schema version on every record | Serialization / Evolution |
| ADR-005 | Origin device and origin sequence | Authority & History |
| ADR-006 | Scoped authority model (`MAIN_REFEREE` in v1) | Authority & History |
| ADR-007 | Authority principal and authority generation | Authority & History |
| ADR-008 | Causal, correction, and supersession links | Authority & History |
| ADR-009 | Immutable payload; committed semantics preserved | Authority & History |
| ADR-010 | Integrity evidence on records | Integrity / Admission |
| ADR-011 | D1 commit before Saved acknowledgement | Durability & ACK |
| ADR-012 | Offline autonomous capture after Match Ready | Durability & ACK |
| ADR-013 | Deterministic, rebuildable, disposable projection | Projection & Conflict |
| ADR-014 | Single writable Match Authority; no dual-core writes | Projection & Conflict |
| ADR-015 | Domain clock policy; temporal transitions as authority | Temporal Truth |
| ADR-016 | Temporal evidence and temporal corrections | Temporal Truth |
| ADR-017 | Replication exchanges records; no LWW; no authority transfer | Replication |
| ADR-018 | Schema evolution without rewriting historical meaning | Serialization / Evolution |

**Also frozen (named contracts, not numbered here):**

| Contract | Group |
| --- | --- |
| Match Operating Model v1.0 | Authority & History; Projection & Conflict |
| Domain Clock Policy v1 | Temporal Truth |
| Product Failure Suite v1 | Durability & ACK; Integrity / Admission |
| SC-1 → SC-5 Corruption Contract | Integrity / Admission |
| Snapshots (acceleration only, never authority) | Snapshots |

---

## Invariant groups (quick reference)

### Authority & History

Match Memory is append-only immutable records. Corrections supersede via new records. V1 sporting scope: `MAIN_REFEREE`; later scopes must remain possible.

### Durability & ACK

Local durable commit is the gate for Saved. Capture after Match Ready does not depend on phone, network, cloud, Firebase, or peer.

### Projection & Conflict

Projection is deterministic and discardable. One writable authority per match during cutover. Conflict resolution is not "latest aggregate wins."

### Temporal Truth

Official time comes from temporal transition records + evidence + domain clock policy — not widget state, not `elapsedSeconds` alone as authority.

### Replication

Replicas receive immutable records. No mutable-state overwrite. No Last Write Wins. Sync does not grant capture authority.

### Serialization / Evolution

Records carry kind and schema version. Upgrades add new readers/writers; they do not silently change committed meaning.

### Integrity / Admission

Admission rejects corrupt or unauthorized records per SC-1→SC-5. Integrity evidence travels with the record.

### Snapshots

Optional cache for speed. Rebuild must succeed without them. Never treat a snapshot as Match Memory.

---

## Repository cutover (governance)

- **Keep:** Flutter shell, i18n, routing, offline phone boundary.
- **Replace:** legacy `packages/match_core` authority path (`Match`, `EventReducer`, mutable `currentState`, document snapshot store).
- **New package:** pure Dart; no dependency on legacy `match_core`, Flutter, or Firebase.
- **Cutover boundary:** UI → single **MatchCommit** port → new Match Memory only. Legacy `MatchSession.replace` must not receive new captures after cutover.

See [AGENTS.md](../AGENTS.md) for agent operational rules.
