# Governance delta

Status: APPLIED TO `AGENTS.md` IN WAVE 0D — OTHER COPIES UNTOUCHED

Product Command acceptance of the Foundation Freeze SHA is PENDING. This file is the historical contradiction record. The canonical operating model is the Device operating model section in `AGENTS.md`. Do not treat the quoted proposal below as a second current policy.

WAVE 0D edited `AGENTS.md` only. It did not edit `docs/architecture-authority.md`, `docs/platforms.md`, `docs/open-decisions.md`, `docs/product.md`, `docs/mvp-scope.md`, or `.cursor/rules/product-context.mdc`. Those files can still show the superseded sentence "the phone is the product; the watch is an upgrade."

Parent inspected: `32eded4e8d18fa0165bb170209afe9b3b0ee5e29`.
Historical anchor, already an ancestor, not a reset target: `main` `919c9062d607f0af255ad368b8c6cb2658d6c85a`.

Planning input, not repository truth: `FORREF_DEVELOPMENT_MASTER_RESEARCH_V2_138b.md`, section `WAVE_0_AUTHORITY_CONTRACT_FREEZE`. Repository evidence overrides that file where they differ.

## What the repository still says

These sentences are in force at the parent. They were not changed.

`AGENTS.md`:

> The **phone is the product**; the watch is an upgrade. A referee with a cheap phone and no watch must complete a full match.

> **Phone-first.** Build order: phone → Wear OS → watchOS → Garmin → Zepp last.

`docs/platforms.md` heading "Build order (frozen)":

> 1. **Phone app (Flutter, Android + iOS)** — real budget compatibility: no watch required
> 2. **Wear OS native**
> 3. **watchOS**
> 4. **Garmin Connect IQ**
> 5. **Zepp OS** — only after match data and sync are stable

`docs/open-decisions.md`, still open:

> **Visual design** (and design system). Do not draw screens until asked. Do not adapt to watch until asked.

`docs/architecture-authority.md` repository cutover:

> **Keep:** Flutter shell, i18n, routing, offline phone boundary.

The same index, ADR-012, already says local capture after Match Ready does not depend on phone, network, cloud, Firebase, or peer. That durability rule is not the contradiction. It stays. A proposed product-role change must not weaken it.

`docs/product.md`:

> The **phone is the product**. The watch is an upgrade, not a condition of use.

That page also says a phone-only referee must be able to record goals, cards, substitutions, and injuries.

`docs/mvp-scope.md` ships a phone match with no watch, including goals, yellow and red cards, substitutions, and injuries.

`docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` at this parent classifies "Phone is the product; watch is later" as FROZEN CONTRACT. That classification is itself part of the contradiction. This wave does not reclassify it.

`.cursor/rules/product-context.mdc` repeats the same phone-is-the-product rule and the same build order. It was not edited.

## What the V2 research and the previous Product Command charter say

The V2 research, and the charter carried into this mission, say all of the following together:

- The watch is primary during the match when it is present.
- The phone is primary before and after the match.
- The phone remains the integration bench for Match Authority while it is the implemented client.
- Central Instrument A is a validation baseline.
- Candidate C is a challenger.
- Build order does not redefine sporting authority.

The research also says First Trustworthy Match is demonstrated first on the phone because that client exists, and that this sequencing does not mean "phone is product, watch is upgrade."

No founder-signed charter file was found in the repository at the parent SHA. The charter text above is the mission statement plus the V2 research. It is not a freeze.

`docs/open-decisions.md` still lists visual design as open. Central Instrument A and Candidate C are therefore not a visual-design decision. `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md` already calls Central Instrument A a baseline rather than production UX, and calls Candidate C absent. That audit line was left in place.

## Contradiction

The repository tells agents that the phone is the product, the watch is an upgrade, the build order is phone then Wear OS then watchOS then Garmin then Zepp, and visual design is open.

The V2 research and the previous Product Command charter tell agents that, when a watch is present, it is the primary instrument during the match, the phone is primary before and after, Central Instrument A is the validation baseline, Candidate C is only a challenger, and build order must not be read as sporting authority.

Both cannot be operational doctrine at once. An agent that follows `AGENTS.md` will refuse watch-primary product work. An agent that follows the research will treat phone-first build order as non-authoritative for match truth. This wave does not pick a winner.

A second, related scope contradiction sits beside it. `docs/product.md` and `docs/mvp-scope.md` include injury in the phone-complete match. The V2 First Trustworthy Match table leaves injury outside the drafted Goal / Yellow / Red / Substitution set and requires a founder decision: hide or disable injury for that match, or stop until an Injury contract exists. This wave does not choose. See `FIRST_TRUSTWORTHY_MATCH.md`.

## Proposed edits (not applied)

Founder sign-off is REQUIRED. Until that sign-off is recorded by the founder in the canonical docs, the sentences below are a quotation, not instructions.

Proposed replacement for the product-identity paragraph in `AGENTS.md` and for the matching sentences in `docs/product.md` and `.cursor/rules/product-context.mdc`:

> The phone is the integration surface and the primary instrument before and after the match. When a watch is the autonomous capture device and is present, the watch is the primary instrument during the match. A referee with a phone and no watch must still be able to complete a match on the phone. Build order does not redefine sporting authority. Match Memory, D1, and projection rules are the same on every client.

Proposed note under the frozen build-order list in `docs/platforms.md`:

> This list is an implementation sequence. It does not decide which device is the sporting authority during a match. Phone remains mandatory for a referee who has no watch. Wear OS remains the first watch client. watchOS, Garmin, and Zepp stay later.

Proposed addition to `docs/open-decisions.md`, only after the founder accepts it:

> Product role of phone and watch during a match is decided: watch primary in-match when present; phone primary before and after; phone remains sufficient with no watch. Visual design, including Central Instrument A as a drawn production screen, remains open until a separate visual-design decision. Candidate C remains a challenger and is not approved UI.

Proposed non-change for `docs/architecture-authority.md`:

> Do not edit ADR-001 through ADR-018 in this delta. ADR-012 already requires autonomous capture after Match Ready. A founder product-role decision must cite that rule and must not replace it.

No other wording is proposed. Applying the quotations above without founder sign-off is forbidden.

## What this delta does not decide

- It does not freeze Goal, Yellow, Red, Substitution, score trust, or cautions recall.
- It does not approve Central Instrument A as production UI.
- It does not approve Candidate C.
- It does not hide or keep Injury.
- It does not merge any pull request.
- It does not issue a Founder, Match Authority, Don, or Tony PASS.
