# FORREF True Black live 004

Execution ID: `FORREF-TRUE-BLACK-LIVE-004`.

Color-only candidate on the PR #52 head `29d3a80a4ab6a221d42bcd667e1ea716d252846c`. Theme commit `5b68fa59d7540e1bc1e043fb32233f5a1f79e7d5`. Branch `cursor/zepp-true-black-live-004-4ae8`. Base branch `cursor/live-perf-002-30fd`. PR #52 was not modified, rebased, or merged.

Authorities used: `AGENTS.md`, the Drive execution task `19wU58Z74imBjIQEIfLy-rUTpEZfnbj-z`, and the color task `1NZOmw9yZvxwzyTiOwjILPW0fk7ltEpZ3QYyjsNvDLps`. Design reference remains PR #45 (`9a180270e39c7982cbd36eea3f26de91f36eea42`) and the Figma study `https://www.figma.com/design/9qYb5Y2tQksmx4TD75yqjV`. Native code does not depend on PR #45.

## Palette

Tokens live in `apps/forref_watch_zepp/utils/theme.js`. `paintBase` fills the existing full-screen rectangle with `CANVAS` `0x000000`. Button text and press colors come from `styleFor`. An unknown fill resolves to navigation, so a leftover navy number cannot paint `#0B2D5B`.

| Role | Rest | Press | Label |
| --- | --- | --- | --- |
| Canvas | `#000000` | same | |
| Primary text, timer | `#FFFFFF` | | |
| Secondary text | `#B3CBD7` | | |
| Warning / TIME_UNVERIFIED | `#C4A35A` | | |
| Title accent | `#3FC3BE` | | |
| Primary and selected | `#3FC3BE` | `#D7F6F5` | `#000000` |
| Navigation | `#2796D6` | `#D6EDFA` | `#000000` |
| Team, goal, substitution | `#000000` | `#163A4A` | `#FFFFFF` |
| Yellow card | `#8A7430` | `#5C4C18` | `#FFFFFF` |
| Red card / end / abandon | `#6E2430` | `#4A1820` | `#FFFFFF` |
| Pause / suspend | `#6E5418` | `#3A2C0C` | `#FFFFFF` |

Measured contrast of label against the fill: primary 9.76 / 18.39, navigation 6.42 / 17.35, neutral 21.00 / 12.08, yellow 4.54 / 8.39, red 10.73 / 14.56, caution 7.13 / 13.59. Secondary text on the canvas is 12.44. Warning text on the canvas is 8.73.

Yellow at rest is the candidate `#8A7430` with white type. It clears 4.5:1 and is the closest pair to that line. Mark `FOUNDER VISUAL REVIEW`.

Team, goal, and substitution buttons use a black fill on the black canvas. The white label is the resting affordance. Press fills `#163A4A`. No border widget was added. Mark `FOUNDER VISUAL REVIEW`.

Primary turquoise is limited to Home Officiate, Select fixture, Ready Open Live, and the live affirmative clock actions (kick-off, resume, start second half, resume game). Review capture stays navigation blue so it does not read as Saved. Display selection uses the selected role, which shares the primary pair, against navigation blue.

Live phase text uses the warning color when time is unverified. The timer stays white. The distance line uses secondary text and keeps the existing `~` / `— km` formatter.

## What stayed in place

`paintBase` still covers `x:0,y:0,w,h` of the device. The square 64px status strip is still the OS icon row drawn over that fill. Button coordinates, radius, type size formula, handlers, and route ids are unchanged.

These files match PR #52: `match_clock.js`, `live_session.js`, `telemetry.js`, `telemetry_host.js`, `telemetry_bind.js`, `telemetry_store.js`, `geometry.js`, `text.js`, sensor lab, Match Core, persistence, and the phone app.

Package identity is app id `29566`, version `1.0.3` code `3`, description `FORREF TRUE BLACK TEST BUILD`, boot name `true-black-004`. Sensor lab app id `30101` is unchanged.

## Founder visual gate

This build is a test candidate. Accent hexes, sunlight readability, and the black team buttons remain `FOUNDER VISUAL ACCEPT / REVISE / REJECT`. Hardware certification is not claimed.
