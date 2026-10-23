# Product

Ref App is a football referee match app. It covers the same job as Refsix — time, events, and a match record on a wearable — but it does not require a single watch ecosystem.

## Identity

Two roles. Do not collapse them.

**Implementation and accessibility.** The phone is the preparation, fallback, and post-match surface. A referee with a ~100€ phone and no watch must be able to complete every supported match workflow: timer, added time, pauses, the events that the Foundation contract allows, a simple squad, crew names, local save, and a PDF export.

**Target professional match role.** A supported smartwatch is not a cosmetic upgrade. When its platform profile is certified for the required match-critical capabilities and MATCH READY has established it as the active capture authority, that watch is the primary in-match instrument and must operate autonomously inside its certified envelope. No watch implementation is claimed to exist today, and no watch is production-certified by this page.

Match Core stays device-neutral. The phone is not permanent sporting authority. Canonical wording: `AGENTS.md`. Foundation candidate: [forref-development/FOUNDATION_FREEZE.md](forref-development/FOUNDATION_FREEZE.md). Product Command has not yet accepted that SHA. WAVE 1 Goal + Score stays HOLD.

Authoritative Injury capture is unavailable in FTM v1. It is not part of the phone-complete Foundation workflow and it is not WAVE 1.

## Audience

County, amateur, and youth referees in RO/EU. Not Ultra-watch buyers. Reach comes from a working phone app and from used or mid-range Wear OS watches, not from supporting every 25€ fitness band.

V1 records the **crew as roles on the match** (center, assistant 1, assistant 2, fourth official) as names in setup. Each person uses the app on their own phone. Live shared events on one match are not V1 — see [mvp-scope.md](mvp-scope.md).

## Versus Refsix

| | Refsix-like core | Ref App difference |
|---|---|---|
| Job | Time a match, log events, keep a record | Same job; log an event in 1–2 seconds |
| Devices | Narrow ecosystem | Phone can complete the supported workflow with no watch; a later certified watch is the in-match instrument when MATCH READY assigns it |
| Budget | Flagship watch assumed | A cheap phone is enough for the supported workflow; a watch is not required for that accessibility path |
| Language | Generic UI copy | Referee terminology, localizable; not raw machine translation |
| After MVP | — | Heatmap, HR alerts, live crew sync, voice notes — only after real matches |

Wider device reach is the product bet. Extra features are not the v1 bet.

## UX principle (MVP)

**Match first → event first.**

On the phone, the referee opens the app and can record a supported in-match event in **1–2 seconds** (2–3 taps), with critical time and score visible at a glance. That accessibility path does not make the phone the permanent in-match authority. Mechanics: [ux-live-match.md](ux-live-match.md). Optimize for motion, bright sun, and split attention — not for a dashboard of features. Do not start visual design or watch UI before those mechanics are implemented in spec. No watch UI is claimed here.

## Paid launch (not MVP)

Beta is free. After beta, three plans: **Free** (match), **Plus** (season), **Pro** (performance). **Storefront country** sets the price; **referee level** is a profile field for recommendations only; **plan** sets entitlements. Spec: [pricing.md](pricing.md). Nothing from that model belongs in `match_core`.

## What this doc does not define

Phone stack is **Flutter** + Drift + `match_core`. Schema: [data-model.md](data-model.md). Live Match: [ux-live-match.md](ux-live-match.md). Setup / full time / PDF: [ux-pre-post-match.md](ux-pre-post-match.md). Visual design and Firebase project IDs are open — [open-decisions.md](open-decisions.md). Storefront SKUs except Romania euros: [pricing.md](pricing.md).
