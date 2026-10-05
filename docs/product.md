# Product

Ref App is a football referee match app. It covers the same job as Refsix — time, events, and a match record on a wearable — but it does not require a single watch ecosystem.

## Identity

The **phone is the product**. The watch is an upgrade, not a condition of use.

A referee with a ~100€ phone and no watch must be able to referee a complete match: timer, added time, pauses, goals, cards, substitutions, injuries, a simple squad, crew names, local save, and a PDF export.

## Audience

County, amateur, and youth referees in RO/EU. Not Ultra-watch buyers. Reach comes from a working phone app and from used or mid-range Wear OS watches, not from supporting every 25€ fitness band.

V1 records the **crew as roles on the match** (center, assistant 1, assistant 2, fourth official) as names in setup. Each person uses the app on their own phone. Live shared events on one match are not V1 — see [mvp-scope.md](mvp-scope.md).

## Versus Refsix

| | Refsix-like core | Ref App difference |
|---|---|---|
| Job | Time a match, log events, keep a record | Same job; log an event in 1–2 seconds |
| Devices | Narrow ecosystem | Phone-complete first, then several watch platforms |
| Budget | Flagship watch assumed | Cheap phone is enough; watch is optional |
| Language | Generic UI copy | Referee terminology, localizable; not raw machine translation |
| After MVP | — | Heatmap, HR alerts, live crew sync, voice notes — only after real matches |

Wider device reach is the product bet. Extra features are not the v1 bet.

## UX principle (MVP)

**Phone first → match first → event first.**

The referee opens the app and can record any in-match event in **1–2 seconds** (2–3 taps), with critical time and score visible at a glance. Mechanics: [ux-live-match.md](ux-live-match.md). Optimize for motion, bright sun, and split attention — not for a dashboard of features. Do not start visual design or watch UI before those mechanics are implemented in spec.

## Paid launch (not MVP)

Beta is free. After beta, three plans: **Free** (match), **Plus** (season), **Pro** (performance). **Storefront country** sets the price; **referee level** is a profile field for recommendations only; **plan** sets entitlements. Spec: [pricing.md](pricing.md). Nothing from that model belongs in `match_core`.

## What this doc does not define

Phone stack is **Flutter** + Drift + `match_core`. Schema: [data-model.md](data-model.md). Live Match: [ux-live-match.md](ux-live-match.md). Setup / full time / PDF: [ux-pre-post-match.md](ux-pre-post-match.md). Visual design and Firebase project IDs are open — [open-decisions.md](open-decisions.md). Storefront SKUs except Romania euros: [pricing.md](pricing.md).
