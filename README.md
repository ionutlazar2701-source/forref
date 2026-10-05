# Ref App

Football referee match app for phone and smartwatches across more than one ecosystem.

The **phone is the product**; the watch is an upgrade. A referee with a cheap phone and no watch must complete a full match.

This repository has a Flutter **project skeleton** (no screens, no engine logic). Product decisions for agents live in the docs below.

## Code

```text
apps/referee_phone/     Flutter shell (empty feature pages)
packages/match_core/    Pure Dart match engine (models + unimplemented APIs)
```

Needs **Flutter 3.47.2** and **Dart 3.13.2** (pinned in `.fvm/fvm_config.json`; use [FVM](https://fvm.app/) locally with `fvm install && fvm use`). On a fresh Linux cloud workspace, run `./tool/cloud_bootstrap.sh` then `./tool/verify_cloud.sh`. Then:

```bash
dart pub get
cd packages/match_core && dart test
cd apps/referee_phone && flutter create . --project-name referee_phone
```

`flutter create .` adds Android/iOS folders; do not treat that as UI work.

## Documentation

Start here if you are an agent (or a human implementing with an agent):

- [AGENTS.md](AGENTS.md) — operational authority, frozen Match Core rules, execution discipline
- [Architecture authority index](docs/architecture-authority.md) — FORREF ADR index, flow, prohibitions (**authoritative for new Match Core**)

Product and UX (read when relevant — not Match Memory authority):

- [Product](docs/product.md) — identity, audience, versus Refsix
- [Live Match mechanics](docs/ux-live-match.md) — control center, five event flows, Quick Capture, edge cases
- [Pre- and post-match mechanics](docs/ux-pre-post-match.md) — setup, full time, extra time, summary, PDF

Legacy (historical — describes current mutable aggregate, not new core):

- [Architecture](docs/architecture.md) — pre-FORREF stack; includes superseded last-local-wins plan
- [Data model](docs/data-model.md) — legacy Match/Event JSON, clock cache, Drift
- [Example match JSON](docs/examples/match-canonical.json) — legacy fixture for current code- [Platforms](docs/platforms.md) — Wear OS first; Zepp last; bands are not apps
- [Testing](docs/testing.md) — emulators vs one physical watch vs beta
- [Test hardware (rental)](docs/hardware-test-matrix.md) — which watches to rent and what to validate on the pitch
- [Pricing and plans](docs/pricing.md) — paid launch (not MVP); Free / Plus / Pro; regional prices
- [Open decisions](docs/open-decisions.md) — what agents must not decide alone
