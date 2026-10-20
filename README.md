# Ref App

Football referee match app for phone and smartwatches across more than one ecosystem.

FORREF supports a complete phone workflow. A certified supported smartwatch is the target primary autonomous in-match instrument when MATCH READY assigns it active capture authority. Canonical operating rules: [AGENTS.md](AGENTS.md).

This repository is in legacy cutover: it contains an executable Flutter phone shell, legacy mutable match workflows, and a separate new Match Core / persistence foundation. It is not claimed production-ready. Product decisions for agents live in the docs below.

## Code

```text
apps/referee_phone/                  Flutter phone shell
packages/match_core/                 Legacy mutable match workflows
packages/forref_match_core/          New Match Core foundation
packages/forref_match_persistence/   Persistence foundation
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
- [Live Match mechanics](docs/ux-live-match.md) — control center, interaction mechanics, Quick Capture, edge cases. FTM availability follows the Foundation Freeze, not the broader event list.
- [Pre- and post-match mechanics](docs/ux-pre-post-match.md) — setup, full time, extra time, summary, PDF

Legacy (historical — describes current mutable aggregate, not new core):

- [Architecture](docs/architecture.md) — pre-FORREF stack; includes superseded last-local-wins plan
- [Data model](docs/data-model.md) — legacy Match/Event JSON, clock cache, Drift
- [Example match JSON](docs/examples/match-canonical.json) — legacy fixture for current code- [Platforms](docs/platforms.md) — Wear OS first; Zepp last; bands are not apps
- [Testing](docs/testing.md) — emulators vs one physical watch vs beta
- [Test hardware (rental)](docs/hardware-test-matrix.md) — which watches to rent and what to validate on the pitch
- [Pricing and plans](docs/pricing.md) — paid launch (not MVP); Free / Plus / Pro; regional prices
- [Open decisions](docs/open-decisions.md) — what agents must not decide alone
