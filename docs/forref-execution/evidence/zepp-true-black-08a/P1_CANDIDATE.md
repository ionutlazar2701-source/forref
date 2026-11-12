# P1 candidate — color only, same rectangles

This is a proposal. It is not applied to the watch.

Geometry comes from `layoutLive`, `layoutEvent`, and `layoutStack` at 390×450 and 480×480. Button radius stays 14. Labels, order, and hit boxes stay as they are. The boards in `candidate/` place the current navy palette on the left and this candidate on the right.

The live boards use a ready clock and a paused clock so the primary action is on screen. The simulator photos in `baseline/` are the restored sessions: rectangular full time, round abandoned, including Live C after the display switch.

Figma file: https://www.figma.com/design/9qYb5Y2tQksmx4TD75yqjV

The file write returned 21 frames (Live A, Live C, Choose Event, and Settings on both shapes, plus display, pressed, and unverified) and the variable collection `FORREF True Black`. A follow-up export hit the Figma Starter plan tool limit, so these PNGs are the review copies.

## Why the fills are paired this way

A Zepp `BUTTON` stores one text color. Rest and press share it.

White text on `#3FC3BE` is 2.15:1. White text on `#2796D6` is 3.27:1. Both fail the 4.5:1 target for normal text. Black text on those fills passes. A black rest fill with black text would disappear, and a black rest fill with white text cannot then press into a bright accent, because the text color cannot change.

So each button keeps one text color, and the press changes luminance:

| Role | Rest | Press | Text | Contrast rest / press |
| --- | --- | --- | --- | --- |
| Canvas | `#000000` | — | — | — |
| Title | — | — | `#3FC3BE` | 9.76 on black |
| Clock digits | — | — | `#FFFFFF` | 21.00 on black |
| Secondary text | — | — | `#B3CBD7` | 12.44 on black. Current muted `#9BB0C7` is 9.43 on black. |
| Warning, not recorded, TIME UNVERIFIED title | — | — | `#C4A35A` | 8.73 on black |
| Primary action (kick off, resume, start second) | `#3FC3BE` | `#D7F6F5` | `#000000` | 9.76 / 18.39 |
| Navigation and unselected display row | `#2796D6` | `#D6EDFA` | `#000000` | 6.42 / 17.35 |
| Selected display row | `#3FC3BE` | `#D7F6F5` | `#000000` | 9.76 / 18.39 |
| Team, goal, and sub | `#000000` | `#163A4A` | `#FFFFFF` | 21.00 / 12.08 |
| Yellow | `#8A7430` | `#5C4C18` | `#FFFFFF` | 4.54 / 8.39 |
| Red, end half, full time, abandon | `#6E2430` | `#4A1820` | `#FFFFFF` | 10.73 / 14.56 |
| Pause, suspend | `#6E5418` | `#3A2C0C` | `#FFFFFF` | 7.13 / 13.59 |

Yellow and red stay yellow and red when pressed. They do not turn turquoise. Pause stays amber. White on the current yellow tile is 4.54:1, just above 4.5:1, so the press goes darker and the white text stays.

Team, goal, and sub are the large rectangles. Their rest fill matches the black canvas, and the white label is the control. The press fill `#163A4A` is used only while the finger is down. It is not a resting navy card.

Navigation bars stay filled, recolored from `#0B2D5B` to `#2796D6`, with black text. That is what keeps a full-width settings row visible and legal under the one-text-color limit.

TIME UNVERIFIED uses the warning gold for the status line. The digits stay white dashes. Turquoise is reserved for titles and the primary action, not for an unverified clock.

## Boards

| File | What it compares |
| --- | --- |
| `candidate/live-a-rect.png` | Live A, 390×450 |
| `candidate/live-a-round.png` | Live A, 480×480 |
| `candidate/live-c-rect.png` | Live C, 390×450 |
| `candidate/live-c-round.png` | Live C, 480×480 |
| `candidate/event-rect.png` | Choose Event, 390×450 |
| `candidate/event-round.png` | Choose Event, 480×480 |
| `candidate/settings-rect.png` | Settings, 390×450 |
| `candidate/settings-round.png` | Settings, 480×480 |
| `candidate/display-rect.png` | Selected A against unselected C |
| `candidate/live-a-rect-pressed.png` | Primary press and team press together |
| `candidate/event-rect-pressed-yellow.png` | Yellow press stays yellow |
| `candidate/live-a-rect-unverified.png` | TIME UNVERIFIED in warning gold |
| `candidate/tokens.png` | The hex list |

## Decision

ACCEPT, REVISE, or REJECT this set:

1. Canvas `#000000`.
2. Primary `#3FC3BE` / press `#D7F6F5` / text `#000000`.
3. Navigation `#2796D6` / press `#D6EDFA` / text `#000000`.
4. Large team, goal, and sub cards: rest `#000000`, press `#163A4A`, text `#FFFFFF`.
5. Yellow `#8A7430` / press `#5C4C18`, red `#6E2430` / press `#4A1820`, pause `#6E5418` / press `#3A2C0C`, all with white text.
6. Unverified title `#C4A35A`. Secondary text `#B3CBD7`.

Until that reply, the native theme stays unstarted.
