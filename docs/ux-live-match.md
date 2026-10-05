# Live Match interaction mechanics

Speed during the match beats visual polish. This doc freezes **interaction mechanics** for the phone Live Match screen. It is not a visual design, not a watch spec, and not a data-schema ADR.

Defaults below are frozen. ChatGPT Alts are test-later options, not competing specs. Do not implement a **Do not**.

Work order (do not skip ahead):

1. Live Match information architecture (this doc)
2. Five event flows (this doc)
3. Error / edge cases (this doc)
4. Pre-match and post-match workflow — [ux-pre-post-match.md](ux-pre-post-match.md)
5. Visual design — not yet
6. Smartwatch adaptation — not yet

## Live Match as control center

One screen, staying open for the whole match (including half-time). Structural regions only (layout, type, and color are not specified):

| Region | Always shows | Job |
|---|---|---|
| Time + period + match state | Clock, period, **READY** / **LIVE** / **Paused** / **FULL TIME** | Where am I; is time running |
| Match-state actions | Kick-off (from READY), Pause, Resume, Start 2nd Half, Extra time, Full time | Separate from events. **Do not** put these in the Goal/Card/Sub/Injury row. **Do not** add a second Start Match control |
| Score | Team names from setup (fallback HOME / AWAY) | Score at a glance |
| Event actions | Goal, Yellow, Red, Sub, Injury only | Start a 2–3 tap capture |
| Recent events | About **5–7** rows | Confirm save; tap to edit |

The ASCII sketch in product chat is a **wire of regions**, not the final UI.

Targets for the five event actions: one-handed; at least ~48×48 dp/pt, larger in the main zone. Do not rely on precise gestures as the only capture method.

## Match clock and states

- Entering Live Match is state **READY**: clock `00:00`, match not started. Visible as READY, not LIVE.
- Clock starts only on explicit **Kick-off** (1 tap). Not on the first event, not on opening the screen, not on a separate Start Match.
- **Start / Resume:** 1 tap. **Pause:** 1 tap (extra confirm only if real matches prove accidental pauses; not the default).
- **Paused** is a persistent, visible state. Do not infer pause only from a button label `Resume`.
- Events stay recordable while paused and while **READY** or **FULL TIME**. Same five flows; no extra steps.
- **Added time** is a **phase**, not a second timer. The main clock continues: 90:00 → 90:01 → 90:02. `+N` is match info for the **current period**, set with a **compact stepper** on Live Match (`−  N  +` or chips like +1 +2 +3 +5 +10). No separate “Start added time” tap. No second clock.
- **Half-time** is an explicit state: Live Match stays open, clock stopped. **Start 2nd Half** is 1 tap and resumes the clock. Do not reopen Match Setup between halves. Do not use a generic Resume that silently flips to 2H unless we later reopen that Alt.
- **Full time** and **Extra time / Finish / COMPLETED:** [ux-pre-post-match.md](ux-pre-post-match.md). Full time is 1 tap + Undo 5 s (no confirm). Finish match is what closes the record. Penalty kicks are not MVP.
- Clock math: **monotonic elapsed time + match-state timestamps**, not UI `+1` on an interval. On return from background/sleep, recompute displayed time from state. Do not assume JS/UI timers keep ticking while the app is asleep. Details: [architecture.md](architecture.md).

## Principles

- **Progressive capture**, not a form. No multi-field modal during play. No combined Goal+Card flow.
- Last **valid** tap **auto-saves**. Do not add a Done after a flow that already used 3 selections.
- **Quick Capture:** incomplete events are valid. Enrich later from the timeline (tap row → edit). Example: yellow Team #7 at 67:23 now; reason later.
- Capture is **reentrant**: a second event must not wait on the first UI, and must not be eaten by a global lock. Goal + card within ~2s = two independent saves.
- **Debounce / idempotency** on the five actions: two identical taps in ~**500 ms** = one event. Then tune on real matches. Do not treat every tap as a new event.
- Fast path must work with **empty or incomplete squad**. Do not force Setup/Squad before logging. Do not ask for team names during an event (names come from setup; fallback HOME/AWAY).

## The five fast paths

Team step shows **setup names**, fallback HOME/AWAY.

Player step: **number + name**, with **Unknown** prominent. **Free number** (not on the squad) is allowed. Unknown / skip still saves.

Change **event type mid-flow** if the mistake is caught before save (Yellow → Red without restart). Do not save a Yellow and implicitly convert it to Red.

**Back** abandons the draft (nothing on the timeline). Tap-outside does nothing. **No timeout** that discards the flow. An incomplete draft is not a saved event.

If the app is killed, rotated, or interrupted (call) **mid-flow**: restore the draft; do not treat it as saved; do not duplicate if it had already saved. Silent abort of the flow is forbidden.

### Goal

`Goal → Home or Away → D1 → confirmation`

The credited side is the initial sporting truth. That is at most two deliberate taps. Player, shirt number, manual minute, text, and a confirmation modal are not required before D1. The visible score and goal history update from the goal projection after D1. A failed commit leaves the score and history unchanged. Own-goal is not a separate fast-path choice.

### Yellow card

`Yellow → Team → Player (or unknown / free number) → auto-save`

No reason on the fast path. Two yellows for the same player = **two yellow events**. **Do not auto-generate a red.** The app does not take the disciplinary decision.

### Red card

Same shape as yellow. Type can be switched from Yellow before save.

### Substitution

`Sub → Team → OUT (or unknown) → IN (or unknown) → auto-save`

OUT and IN may both be Unknown. Do not require a second team pick when OUT and IN are the same team. Same flow in added time and while paused.

### Injury

`Injury → Team → Player (or unknown / free number) → auto-save`

Injury is **only an event**. It must not auto-pause. A non-blocking “Pause?” hint is optional and must not delay the save; full assisted-pause behavior stays after real matches — [mvp-scope.md](mvp-scope.md).

## What is saved immediately

Locally, before any network:

- Event type
- Team, if the flow got that far
- Player(s) if chosen, else unknown or free number
- For sub: OUT and/or IN, each optional unknown
- Match-clock timestamp
- Created-at (device time) for recovery

A row appears in Recent events at once.

## Edit later

**Tap** a recent row = edit. Do not assign **long-press** yet (no fat contextual menu during play).

MVP edit may change: **type, team, player, timestamp, note/reason**, plus event-specific fields that already exist. No photos, voice, or law references.

- Type change is allowed. Goal ↔ non-goal **recalculates score atomically**. Keep an **internal modification history** (schema still open).
- Timestamp: set a new **match-clock** time, plus **±30 s nudges**. Do not use wall-clock time unless we later need it.
- Swipe-to-delete is **not** the primary in-match control.

**Undo last save:** visible **Undo for 5 seconds** after save. Then timeline edit/delete is the fallback.

## Edge cases (MVP tests)

| Situation | Required behavior |
|---|---|
| Goal + card almost together | Two reentrant saves; no global tap lock |
| Double-tap same action | One event (~500 ms debounce) |
| Wrong substitution | Edit or delete the row; no extra “correction” event type |
| Player with no number / not on squad | Unknown or free number; save anyway |
| Empty squad | Still capture; do not force Setup |
| Injury, player unknown | Save with unknown; fill later |
| Accidental tap | 5 s Undo, then edit/delete |
| Yellow meant Red mid-flow | Change type; do not implicit-convert a saved yellow |
| Second yellow | Second yellow event; no auto-red |
| Own goal | Edit later; not a fast-path branch |
| Match paused / added time | Same five flows; paused state visible |
| Half-time | Live Match open, clock stopped; Start 2nd Half 1 tap |
| App killed mid-draft | Restore draft; not a saved event |
| App killed after save | Events persist (offline-first); no duplicate |
| OS interruption / rotation | Keep draft; no silent abort |
| No network | Capture does not wait on sync |
| Wrong timestamp | Edit: match-clock pick and ±30 s |
| Phone sleeps | Recompute clock from monotonic state |

## Not on the Live Match action row

Do not add events because other referee apps have them.

| Type | Bucket |
|---|---|
| Penalty, offside, VAR, advantage | After real matches — [mvp-scope.md](mvp-scope.md) |
| Corner and other stats-only events | Never v1 on this row |

## Out of scope here

- Visual design, design system, icons, colors (target **size** above is a mechanic, not a theme)
- Watch layout or watch gestures
- JSON schema, IDs, sync protocol — [open-decisions.md](open-decisions.md)
- Pre-match, full time, extra time, summary, PDF — [ux-pre-post-match.md](ux-pre-post-match.md)
