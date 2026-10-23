# MVP scope

Canonical lists for what ships now, what waits, and what v1 must not do. Do not promote a later or never item into MVP unless the user reopens the decision.

## Scope layers

These layers are different. An item in the broader phone list is not authority to build it inside WAVE 1 or inside FTM v1 Match Memory.

| Layer | What it allows |
| --- | --- |
| Foundation / FTM v1 | The boundary in [forref-development/FOUNDATION_FREEZE.md](forref-development/FOUNDATION_FREEZE.md). Product Command acceptance is still pending. Authoritative Injury capture is unavailable. |
| WAVE 1 Goal + Score | Narrower than this page. HOLD until Product Command accepts the Foundation Freeze SHA. It does not include Injury, Yellow implementation, Cautions Recall, Red, Substitution, or watch capture. |
| Phone accessibility | A referee can complete the supported workflow on a phone with no watch. |
| Later product scope | Items below that are outside FTM v1 and outside WAVE 1. |

## Ship now (phone accessibility)

A supported match workflow must be refereeable on the phone, with no watch. This list is not the WAVE 1 build list and it is not permission to add an authoritative Injury writer:

- Match setup, simple squad (number + optional name), optional competition/venue free text, crew names — [ux-pre-post-match.md](ux-pre-post-match.md)
- Main timer, added time as a **phase**, manual pause with visible **Paused** state — [ux-live-match.md](ux-live-match.md)
- Kick-off starts the clock from **READY** (same Live Match screen, not a Ready/Pre-Match screen)
- Explicit **Full time** (1 tap, Undo 5 s); **Finish match** → COMPLETED (confirm only if incomplete events); optional Extra time; Summary + one PDF — [ux-pre-post-match.md](ux-pre-post-match.md)
- Goals are the sporting event inside the future WAVE 1 boundary, and that wave is HOLD. Yellow, red, and substitution are later than WAVE 1. Fast-path mechanics, where they exist, are described in [ux-live-match.md](ux-live-match.md). That UX note is not a WAVE 1 authorization.
- **Injury** is not part of authoritative FTM v1 Match Memory capture. A legacy Injury control must not remain reachable as an authoritative FTM writer. Injury returns only under a later dedicated domain contract. Do not implement it during WAVE 1.
- Event in **1–2 seconds** (2–3 taps, auto-save on last tap, Quick Capture, no multi-field modal); targets ≥ ~48 dp; configurable vibrations
- Match timeline (5–7 recent rows), tap to edit, **Undo 5 s** after save
- Offline save (Drift) and later Firestore sync (signed-in only)
- Match summary + PDF export — one template, not every federation; PDF not stored in Firestore in MVP
- Basic match history; **free during beta** (no billing in the match engine). Paid launch: [pricing.md](pricing.md)
- Localizable UI **RO + EN** from day one (English fallback; no hardcoded widget strings) — [architecture.md](architecture.md)

## After 10–20 real matches

Ship these only after referees have used the MVP on the pitch:

- GPS / heatmap (watch GPS, or phone left at the bench) — stays here; not “never V1”
- Heart-rate alert — stays here; not “never V1”
- Live referee–assistant sync (phones over the network, not watch-to-watch Bluetooth)
- Voice notes transcribed on the phone after the final whistle
- FRF / local federation report templates
- *Assisted* pause suggestion (not automatic pause from motion)
- Penalty, offside, VAR, advantage as Live Match event types (not on the MVP action row)
- Kicks from the penalty mark (post-match)
- Persistent teams, player database, **competition management**
- Extra EU languages beyond RO + EN

## Paid launch (after beta)

Not MVP and not automatic after the 10–20-match list. Beta stays free. When asked to implement billing: [pricing.md](pricing.md). Entitlements and IAP stay **outside** `match_core`. Geography sets price; `referee_level` sets recommendations; plan sets access.

## Never for v1

Do not implement these as product behavior:

- Automatic pause from accelerometer / movement (a referee still runs when the ball is out)
- Live watch-to-watch Bluetooth sync across a 100 m pitch
- On-watch speech-to-text during the match (stadium noise)
- Custom score/timer UI on Xiaomi Band, Huawei Band, or CMF as a sellable product
- Flutter as the watch client (no official watchOS target; Wear OS is unofficial)
- Zepp OS or Garmin as the first platform
- AWS as the MVP cloud (Firebase is enough)
- Live shared events on one match in V1 (crew is names/roles in setup only)
- Corner (or other stats-only events) on the Live Match fast-path row
- Combined Goal+Card capture; second yellow auto-converted to red; two concurrent match clocks
- Starting from a watch-only app with no phone match
- Ready / coin-toss / formation-pitch / Pre-Match **screens as gates** before Live Match (READY is a **state** on Live Match)
- React Native for the phone MVP; Kick-off gated on network or Auth
- Paywalls / IAP inside the match engine; penalty-kick period (`pens`) activated in MVP

Platform order and client levels: [platforms.md](platforms.md), [architecture.md](architecture.md).
