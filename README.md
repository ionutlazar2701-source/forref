# Ref App

Football referee match app for phone and smartwatches across more than one ecosystem.

The **phone is the product**; the watch is an upgrade. A referee with a cheap phone and no watch must complete a full match.

This repository has a Flutter **project skeleton** (no screens, no engine logic). Product decisions for agents live in the docs below.

## Code

```text
apps/referee_phone/     Flutter shell (empty feature pages)
packages/match_core/    Pure Dart match engine (models + unimplemented APIs)
```

Needs Flutter on PATH (SDK is at `D:\flutter\flutter`). Then:

```bash
dart pub get
cd packages/match_core && dart test
cd apps/referee_phone && flutter create . --project-name referee_phone
```

`flutter create .` adds Android/iOS folders; do not treat that as UI work.

## Documentation

Start here if you are an agent (or a human implementing with an agent):

- [AGENTS.md](AGENTS.md) — read order, invariants, open-decision protocol

Source of truth:

- [Product](docs/product.md) — identity, audience, versus Refsix
- [Live Match mechanics](docs/ux-live-match.md) — control center, five event flows, Quick Capture, edge cases
- [Pre- and post-match mechanics](docs/ux-pre-post-match.md) — setup, full time, extra time, summary, PDF
- [Architecture](docs/architecture.md) — Flutter phone, offline-first, Firebase
- [Data model](docs/data-model.md) — canonical Match/Event JSON, clock cache, Drift, Firestore
- [Example match JSON](docs/examples/match-canonical.json)
- [Platforms](docs/platforms.md) — Wear OS first; Zepp last; bands are not apps
- [Testing](docs/testing.md) — emulators vs one physical watch vs beta
- [Test hardware (rental)](docs/hardware-test-matrix.md) — which watches to rent and what to validate on the pitch
- [Open decisions](docs/open-decisions.md) — what agents must not decide alone
