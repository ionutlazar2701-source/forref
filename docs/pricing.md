# Pricing and plans (paid launch)

Launch commercial model for **Ref App**. Exploration chat used the name “Ref Watch”; the product name here stays **Ref App**. Do not import billing concepts from other products (including Passportify).

This is **not MVP**. Beta is free. Do not implement IAP, paywalls, or entitlements until asked. When billing ships, it lives **outside** `match_core` — [architecture.md](architecture.md), [mvp-scope.md](mvp-scope.md).

USD amounts below are **reference price points**, not live FX conversions. Storefront local currency (App Store / Google Play, later a web provider) is what the user pays. Romania is the first concrete test market (euro amounts frozen below).

## Three concepts (do not mix)

| Concept | What it decides | What it must not decide |
|---|---|---|
| **Geography** (storefront / billing country) | Localized **price** | Plan recommendation, feature set |
| **Referee level** (profile) | Onboarding copy and **which plan to recommend** | Subscription price |
| **Selected plan** (Free / Plus / Pro) | **Entitlements** | Price (price comes from geography) |

```text
Geography determines affordability.
Referee level determines product recommendations.
The selected plan determines entitlements.
```

Do not ask how much the referee earns. Do not verify income. Do not price by match count, competition, or match fees.

```text
referee_level != billing_price
```

Do **not** implement `if referee_level == professional: charge more`. A Romanian youth referee and a Romanian professional see the **same** Pro price for that storefront.

## When this applies

| Phase | Billing |
|---|---|
| MVP / beta | Free for everyone. No plan gates. Full MVP match workflow on the phone. |
| Paid launch | Free / Plus / Pro as in this doc. Limits and paywalls apply only to features that already exist. |

GPS, HR, season libraries, watch clients, and AI insights stay on their existing roadmap — [mvp-scope.md](mvp-scope.md), [platforms.md](platforms.md). This doc only says **which plan may use them once they exist**. It does not pull those features into MVP.

## Plans

Three commercial plans. Referee level is **not** a paid tier.

| Plan | Role | Positioning (pricing page) |
|---|---|---|
| **Free** | Try the product; grassroots / occasional | For trying Ref App. |
| **Plus** | Active amateur season | For active referees. |
| **Pro** | Performance (semi-pro / pro / elite *as a recommendation*) | For referees who want advanced performance insights. Mark **Most popular**. |

Progression the user should understand in about 10 seconds:

**Free = I can referee a match.**
**Plus = I can manage my season.**
**Pro = Ref App helps me become a better referee.**

Free is **$0 / €0** in every region. It is not region-dependent.

## Referee level (profile, not billing)

Onboarding may ask:

```text
What level do you currently referee at?
  Grassroots / Youth
  Amateur
  Semi-pro
  Professional
  Elite / International
```

Store on the **user profile**, not on the Match aggregate:

```text
referee_level: grassroots | amateur | semi_pro | professional | elite
```

Uses: personalization, onboarding, analytics, recommendations. Never price.

Default recommendations (user may still pick any plan; same regional prices):

| `referee_level` | Recommend |
|---|---|
| `grassroots` | Free, with Plus as the next step |
| `amateur` | Plus |
| `semi_pro` | Plus or Pro |
| `professional` | Pro |
| `elite` | Pro |

Example copy (not visual design): grassroots — *Free is a good place to start. Upgrade to Plus when you need unlimited match history and reports.* Professional — *Pro is recommended for referees who want advanced performance analytics.* The Pro **price** on that screen is still the storefront price.

## Entitlements

Gating belongs in a billing/entitlements layer in the phone app (and later watch clients). **`match_core` records a match; it does not know Free vs Pro.**

### Commercial limits (paid launch)

| Limit | Free | Plus | Pro |
|---|---:|---:|---:|
| Matches / month | **5** | unlimited | unlimited |
| History | **30 days** | **12 months** | unlimited |
| PDF / share reports / month | **3** | **10** | unlimited |
| Signed-in devices | **1** | **2** | **5** |
| Watch (when a watch client exists) | Timer + five events | Full event recording | Full + HR / GPS when those features exist |
| Season analytics | — | yes | yes |
| Personal performance / AI insights | — | limited or none | full |
| GPS / HR | — | — | yes, when those features exist |
| Export (CSV etc.) | — | yes | yes |
| Saved competitions / teams / setup templates | — | yes | yes |

Cloud backup / sync remains **signed-in + online**, as today. Device limits apply to a **signed-in account**, not to signed-out local Kick-off. Offline-first and “Kick-off without Auth” do not change.

### How to count limits

- A match counts against the Free monthly cap when it first **Kick-off**s (leaves READY). SETUP-only drafts do not count.
- Over cap: the in-progress match stays usable through Full time / Finish; **new** Kick-off is blocked until the next UTC month or an upgrade. Do not delete local data.
- History windows use the match `date`. Older matches stay on device if already stored; they are hidden from list/search outside the window, not wiped.
- A PDF/share generation counts against the report cap; opening Summary does not.

### Free — Match Ready

Enough to referee a real match on the phone:

- Setup, Live Match, five events, undo/edit, timeline, score, added time, Full time, Finish, basic summary / one PDF template
- **No** per-match event cap, **no** minute cap, **no** hiding score / cards / timeline behind a paywall, **no** blocking event edit

Watch on Free (when it exists): start/pause timer and the same five events. Not GPS/HR. Not every watch platform on day one — [platforms.md](platforms.md).

### Plus — Season Ready

Everything in Free, plus unlimited matches, 12-month history, search/filters, season totals and simple trends, professional PDFs / season report / CSV, saved competitions/teams/templates (when those features exist), full watch event recording on supported platforms.

Plus is not “Free with the cap removed” only. It is the season journal.

### Pro — Performance Ready

Everything in Plus, plus the performance layer **when built**: disciplinary profile, intensity/trends, match and season insights, HR, GPS/heatmap, correlation of effort with events. Reports are performance reports, not just more filters.

Do not sell “Professional referee” as its own SKU.

### Do not gate

- Events per match
- Minutes per month
- Editing or undoing an event
- Score, cards, goals, timeline during the match
- Kick-off on network or Auth (signed-out Free match on the recording device still works)

## Regional pricing

Resolve:

```text
storefront / billing country
        ↓
pricing region (optional country override)
        ↓
localized Plus / Pro monthly and annual prices
        ↓
plan the user selected
```

The client **consumes** a resolved price config from the server / store. Do not hard-code country → price tables in Flutter widgets.

Do **not** use GPS for price. Do **not** reprice an active subscription because the user travelled, changed `referee_level`, refereed more matches, or moved up a competition.

Persist at purchase, for example:

```text
subscription_country = RO
subscription_price_id = refapp_pro_monthly
```

A later trip to Germany must not switch that subscription to the German price.

### Regions (USD reference)

Annual is about **25–30%** off vs 12× monthly. Promote annual; keep monthly visible.

| Region | Plus / month | Plus / year | Pro / month | Pro / year | Intent |
|---|---:|---:|---:|---:|---|
| **A** Premium | $5.99 | $49.99 | $14.99 | $119.99 | Reference global Pro; do not look “cheap” |
| **B** Southern / Central Europe | $4.99 | $39.99 | $11.99 | $94.99 | Affordability without devaluing |
| **C** Eastern Europe / selected LATAM | $3.99 | $34.99 | $8.99 | $79.99 | Volume + affordability (RO test) |
| **D** Lower PPP | $2.99 | $24.99 | $6.99 | $54.99 | Volume markets |
| **E** Emerging | $1.99 | $17.99 | $4.99 | $39.99 | Same product, locally affordable |

$14.99 Pro is the **global reference**, then step down: **$14.99 → $11.99 → $8.99 → $6.99 → $4.99**.

Never compute the consumer price as `USD × today’s FX`. Use fixed psychological storefront prices.

### Country → region

| Region | Countries |
|---|---|
| A | US, CA, GB, AU, NZ, CH, DE, NL, DK, SE, NO, AT, BE, FI, IE, FR, JP, KR, SG, IL |
| B | IT, ES, PT, GR, CZ, SI, SK, HR |
| C | PL, HU, RO, BG, RS, MX, BR, AR, CL |
| D | CO, PE, ZA, MY |
| E | IN, ID, VN, PH, TH |

Unlisted countries: do not invent a region in app code. Add them server-side (default toward a neighbor region, or withhold paid SKUs until listed).

### Country overrides

A region is a **default**. Country-specific storefront prices are allowed and preferred over exact FX.

Frozen **Romania** test market (not USD conversion):

| Plan | Monthly | Annual |
|---|---:|---:|
| Free | €0 | €0 |
| Plus | **€3.99** | **€34.99** |
| Pro | **€8.99** | **€79.99** |

Intended later (not frozen local currency until storefronts are set):

- **PL / HU:** same Plus as C; Pro monthly reference **$9.99** (above C default).
- **TR:** Plus **$2.99** / Pro **$7.99** (not in the region table above; add as its own override when the storefront is configured).
- Example local points from the proposal (still open until entered in the stores): PL Plus 17.99 PLN / Pro 44.99 PLN; DE Plus €5.99 / Pro €14.99; US Plus $5.99 / Pro $14.99.

The UI must **not** show “Region C”, “PPP tier”, or similar. Show plan names and the localized amount:

```text
Free    €0
Plus    €3.99 / month
Pro     €8.99 / month
        €79.99 / year   Save 26%
```

## Catalog and providers

Business product IDs (stable; do not encode the amount):

```text
refapp_plus_monthly
refapp_plus_annual
refapp_pro_monthly
refapp_pro_annual
```

Map each to **provider** price IDs per storefront (App Store, Play, later web). Example:

```text
RO:
  refapp_plus_monthly → <store price id>
  refapp_plus_annual  → <store price id>
  refapp_pro_monthly  → <store price id>
  refapp_pro_annual   → <store price id>
```

Keep configuration independent of the processor. Conceptual types (implementation later, **not** in `match_core`): `BillingProvider`, `Customer`, `Subscription`, `Price`, `Entitlement`.

The app chooses `country + plan + billing_period` and receives a product/price identifier. The provider charges that identifier.

Pricing must be **remotely changeable** (country → region, amounts, currency, plan availability, effective date) without an app release. New prices apply to **new** subscriptions. Existing subscribers are **grandfathered** until an explicit store price-change / migration flow. Never silently raise a price because level, travel, match volume, or the matrix changed.

The architecture should allow, without rewriting core billing: more countries, per-country prices, more currencies, intro/promo prices, grandfathering, association/student discounts, later institutional/team plans.

## Firestore / sync

Do not put billing documents inside the Match aggregate. Do not sync IAP payloads through `match_core`. User profile (`referee_level`) and subscription metadata belong on the account, not on `matches/{matchId}`.

Kick-off still must not wait on billing servers. If the entitlements service is unreachable, honor the last cached entitlements for that account; signed-out local match recording stays available within Free rules once paid launch exists.

## Acceptance (paid launch)

1. A Romanian storefront shows the Romanian/euro prices above.
2. A US storefront shows US (region A) prices.
3. `referee_level` does not change price.
4. Romanian professional and Romanian youth see the same Pro price.
5. Recommendations may differ by `referee_level`.
6. GPS does not control billing.
7. Travel does not change an active subscription.
8. Amounts and country maps are centrally configurable.
9. The Flutter UI does not hard-code the regional matrix.
10. Provider SKUs are mapped, not used as business IDs.
11. Monthly and annual exist for Plus and Pro.
12. Existing subscribers can be grandfathered.
13. Free is $0 everywhere.
14. Adding a country is data, not a billing rewrite.
15. No Passportify (or other-product) billing entities.

## Still open

Record choices here when they exist; do not invent them in code:

- Exact App Store Connect / Play Console price points per storefront (except the frozen RO euro table).
- Billing provider accounts and environment names (tied to Firebase project IDs — [open-decisions.md](open-decisions.md)).
- Paid-launch date (after beta; not automatic after 10–20 matches).
- Promo, intro, student/association, and team/institutional SKUs.
- Market-sizing / referee-count revenue model (proposal only; not a product freeze).
- Exact analytics metric list and insight copy (examples in this doc, not a dashboard spec).
- Visual design of the paywall — [open-decisions.md](open-decisions.md).
