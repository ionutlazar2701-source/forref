# Pre-match and post-match mechanics

Mechanics only — not visual design, not watch. Live Match capture stays in [ux-live-match.md](ux-live-match.md). Aggregate: [data-model.md](data-model.md).

Same idea as in play: **minimum input when the ball is in play; enrich when there is time.**

ChatGPT proposed extra **screens** (Pre-Match, Ready, Review, Report). Those stay **rejected as gates**. We keep the **states** and the Full time ≠ Finished split.

## Spine

```text
Match list
  → New Match (local, immediate)
  → Setup (optional; recap on the same surface, not a second screen)
  → Live Match / state READY     (clock 00:00, not started)
  → Kick-off → LIVE → …          (in-play: live-match doc)
  → Full time                    (playing ended; still the match)
  → Summary                      (review + timeline + notes)
  → Finish match → COMPLETED
  → PDF / history
```

**Do not** add: Ready screen, Pre-Match screen, coin toss, competition catalog, formation pitch, a second “Start Match” besides Kick-off, “Are you sure?” on Kick-off / Pause / Resume / Full time.

## State machine

```text
SETUP  →  READY  →  LIVE  ⇄  PAUSED
                    LIVE  →  HALF-TIME  →  LIVE (2H)
                    LIVE  →  EXTRA TIME (optional)  →  …
                    LIVE  →  FULL TIME  →  Summary  →  COMPLETED
```

- **READY** = Live Match, clock `00:00`, Kick-off not pressed. Visible as READY (not LIVE).
- **FULL TIME** = whistle; clock frozen; not completed.
- **COMPLETED** = Finish match; no longer “in play”; data stays editable.

## Match list (Matches)

MVP home: **newest first**. CTA **New Match** (1 tap) creates a local match and opens Setup. No search, no KPI/stat dashboard.

Visible status: Ready, Live, Paused, Half-time, Extra time, Full time, Completed.

Group by day (Today / Yesterday / Older) is enough.

- Not started → Setup or READY (wherever they left).
- In play / paused / half-time / extra time / full time → Live Match in that state.
- Completed → Summary.

## Before the whistle

### Setup — useful, not a gate

Live Match / READY is **always** 1 tap away, including empty names and empty squads.

| Field | Default | Notes |
|---|---|---|
| Home name, Away name | empty → HOME / AWAY | Not typed during an event |
| Date | today | |
| Competition, venue | empty | **Optional free text.** Not a competition manager, not a catalog ([mvp-scope.md](mvp-scope.md) keeps that after real matches) |
| Half length | 45 | Both halves |
| Crew | empty | Center, AR1, AR2, fourth — **names** |
| Squad | empty | Number + optional name. Optional starter / substitute **flag** — not a mandatory XI |

Added-time `+N` is **not** setup. Set during Live Match.

Bottom of Setup is a **recap** (names, duration, crew), not a form and not a new route. CTAs: **Live Match** (→ READY), edit fields in place.

### READY (on Live Match, not a screen)

- Clock `00:00`. Score 0–0. State visible: **READY**.
- Kick-off is the **only** start (1 tap) → LIVE, internal start timestamp. Do not start the clock on entering this screen. Do not add a separate Start Match control.
- Setup/squad/crew still editable (settings / back to Setup).
- Five event actions work (same Quick Capture; timestamps at 00:00 if before Kick-off). Back to list is allowed.

## After the final whistle

Playing vs closed are different:

| | Full time | Finish match |
|---|---|---|
| Meaning | Ball-in-play is over | Record is closed (`COMPLETED`) |
| Clock | Frozen | Frozen |
| Five actions | Still available | No new live capture; **edit** (and add-from-timeline) still allowed |
| Confirm | **None** (1 tap). **Undo 5 s** restores previous period/clock | Only if there are **incomplete** events |

### Full time (1 tap)

Match-state row, not with Goal/Card/Sub/Injury. Not automatic at 90:00.

After tap: state **FULL TIME**, clock frozen, score obvious, five actions still work, primary CTA **Summary**. Undo 5 s = cancel FT.

Extra time remains as already specified (1 tap **before** FT, same screen, ET from 0:00, default 15). Penalty kicks: after real matches.

### Incomplete events

An event is **incomplete** if a player is Unknown (goal/card/injury) or a sub has Unknown OUT or IN. Mark it (e.g. warning on the row). **Never block** Full time, Summary, Finish, or PDF.

From the row: **Edit** or leave incomplete.

### Summary (review + report on one surface)

Not three screens (Review / Summary / Report).

- Score, duration, added time, crew, optional competition/venue
- Counts: goals, yellows, reds, subs, injuries
- **Full timeline** (tap = edit). Incomplete rows visible
- Light checklist (not a form): teams, score, time, events — glance only, not required ticks
- Optional **match notes** (one free-text field, not required)
- CTAs: **Finish match**, **PDF**, **+ Add event**, **Back to match** (still FULL TIME), list

### Add event after COMPLETED (and from Summary)

`+ Add event` → the same five types (Goal, Yellow, Red, Sub, Injury) and the same capture logic as Live Match. **Do not** open an 8–10 field form.

Timestamp is not “now”: set **match time** (type or pick) and/or **±30 s**, then the usual team → player auto-save. Further edit uses the same edit-later rules.

### Finish match → COMPLETED

- If incomplete count is 0: 1 tap.
- If incomplete count > 0: confirm once — **Finish anyway** / **Review events**. No confirm when there is nothing to warn about.
- After Finish: history item is completed; Summary is the home for that match; PDF uses latest data; edits still recalculate score.

### PDF

One template, offline, OS share sheet. Regenerable after edits. Allowed with incomplete events and empty timeline. During beta this is unlimited. Paid-launch caps (Free 3 / Plus 10 / Pro unlimited per month): [pricing.md](pricing.md). Do not implement those caps in MVP.

## Edge cases

| Situation | Required behavior |
|---|---|
| Skip setup | READY with HOME/AWAY, empty squad, Kick-off works |
| App killed in READY | Resume READY; match exists locally |
| App killed after Kick-off | Resume LIVE with clock from state |
| App killed in FULL TIME | Resume Live Match FULL TIME or Summary — never a blank match |
| App killed after Finish | Resume Summary as COMPLETED |
| FT during an event draft | Keep draft (not a saved event); FT still applies |
| Accidental FT | Undo 5 s |
| Accidental Finish | Edits remain; do not require a new match |
| Two New Match taps | Two local matches |
| Competition / venue empty | Fine; PDF omits them |

## Out of scope here

- Visual design / design system
- Watch
- Dashboard beyond list + new match
- Persistent competitions / seasons / team libraries
- Coin toss, lineup graphic, VAR, penalties
- Payload IDs — [open-decisions.md](open-decisions.md)
