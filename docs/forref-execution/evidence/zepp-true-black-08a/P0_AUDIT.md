# P0 audit — color system on the 23-route Zepp app

Baseline commit `c993055fbeb4e769174aaf86d5aa4889ee95c21d`. Captured 13 Nov 2026, Europe/Bucharest (UTC+2).

Authority read for this pass: `AGENTS.md`, the Drive task `1FroxqkWRKt6UUktAZlH3WiBmEfL831i2`, and the Jony design document `1NZOmw9yZvxwzyTiOwjILPW0fk7ltEpZ3QYyjsNvDLps`. The approved direction is pure black `#000000` for application-owned backgrounds, with turquoise `#3FC3BE` and blue `#2796D6` still provisional. Yellow and red stay disciplinary colors. This audit does not apply that palette.

## Guests

| Shape | What the glass painted | Zeus target used to install | Window |
| --- | --- | --- | --- |
| Rectangular | `390×450 RECT src 10158337`, Amazfit Bip 6 | Amazfit Bip 6 | 390×477 |
| Round | `480×480 ROUND src 10813699`, Amazfit Active Max | Amazfit Active 3 Premium | 480×507 |

The round install target and the round guest identity are different names. The photos follow the painted device source.

The rectangular OS title sits over the top of the framebuffer. The app still paints the full frame, including under that title. Controls stay at or below y=64, which is the app constant `SQUARE_STATUS_BAR`. The round glass has no status bar. Corner radius of every button is 14. Those rectangles are unchanged in the candidate.

## 23 routes

`app.json` registers these pages, in order. Match Controls is route 9. Older notes that stop at 22 do not list it.

1. `page/gt/home/index.page`
2. `page/gt/select/index.page`
3. `page/gt/hub/index.page`
4. `page/gt/warmup/index.page`
5. `page/gt/incident/index.page`
6. `page/gt/ready/index.page`
7. `page/gt/toss/index.page`
8. `page/gt/live/index.page`
9. `page/gt/controls/index.page`
10. `page/gt/display/index.page`
11. `page/gt/event/index.page`
12. `page/gt/player/index.page`
13. `page/gt/review/index.page`
14. `page/gt/settings/index.page`
15. `page/gt/cautions/index.page`
16. `page/gt/neutral/index.page`
17. `page/gt/halftime/index.page`
18. `page/gt/recovery/index.page`
19. `page/gt/finish/index.page`
20. `page/gt/train/index.page`
21. `page/gt/train-warm/index.page`
22. `page/gt/train-live/index.page`
23. `page/gt/train-done/index.page`

The Bip 6 `device.zip` contains `app.bin` plus one `.bin` for each of these 23 pages, 59 entries in total, and two PNGs.

## Where color is decided

Every route paints the canvas in `paintBase`: `FILL_RECT` `0x071d33` across the full framebuffer.

`button()` in `utils/chrome.js` sets `normal_color` to the caller fill or `0x0b2d5b`, `press_color` to `0x3fc3be` for every button, and text `color` to `0xffffff`. A Zepp `BUTTON` has one text color for rest and press. It has no stroke.

Titles use `0x3fc3be`. Warning and “not recorded” lines use `0xc4a35a`. Muted lines use `0x9bb0c7`.

| Surface | Rest fill | Text |
| --- | --- | --- |
| Canvas | `#071D33` | — |
| Default button, including press of every button | `#0B2D5B` / press `#3FC3BE` | `#FFFFFF` |
| Live HOME | `#0E4A48` | `#FFFFFF` |
| Live AWAY | `#1A3A5C` | `#FFFFFF` |
| Kick off, resume, start second half | `#0D5C45` | `#FFFFFF` |
| Pause, suspend | `#6E5418` | `#FFFFFF` |
| End half, full time, abandon, red tile | `#6E2430` | `#FFFFFF` |
| Live back when the phase has no primary action | `#12324D` | `#FFFFFF` |
| Match Controls and other navigation | `#0B2D5B` | `#FFFFFF` |
| Yellow tile | `#8A7430` | `#FFFFFF` |
| Goal tile | `#0E4A48` | `#FFFFFF` |
| Sub tile | `#1A3A5C` | `#FFFFFF` |
| Selected display row | `#0E5C58` | `#FFFFFF` |
| Phase and page titles | none | `#3FC3BE` |
| Clock digits, including unverified dashes | none | `#FFFFFF` |
| Warning, unverified copy, not recorded | none | `#C4A35A` |
| Muted secondary lines | none | `#9BB0C7` |

Unverified live status is still painted with the turquoise title color. The dashes are white. The candidate moves that title to the warning gold and leaves the dashes white.

Stack routes (home, select, hub, warmup, incident, ready, toss, player, review, settings, cautions, neutral, halftime, recovery, finish, train, train-warm, train-live, train-done, controls, display) inherit the canvas and the default button. Display adds the selected fill. Controls reuses the hazard and pause fills for its action rows.

## Simulator baseline

Rectangular session, Romanian, full time 45:22, display C: `baseline/rect-home.png`, `rect-live-now.png`, `rect-live-c.png`, `rect-event.png`, `rect-controls.png`, `rect-display.png`, `rect-settings.png`.

Round session, English, abandoned 45:30, then display switched to C for the last live frame: `baseline/round-home.png`, `round-live.png`, `round-live-c.png`, `round-event.png`, `round-controls.png`, `round-display.png`, `round-settings.png`.

Home still prints the existing device line (`390×450 RECT src 10158337` or `480×480 ROUND src 10813699`). That line is baseline behavior. This color pass does not add or remove it.

## Package, before any theme edit

| Measure | Value |
| --- | --- |
| Source tree, excluding `node_modules` and `dist` | 50 files, 125,907 bytes |
| JavaScript | 38 files, 104,421 bytes |
| Source PNGs | 4 files, 17,662 bytes (`assets/gt.r` and `assets/gt.s`, each `icon.png` 5,594 and `image/logo.png` 3,237) |
| `zeus build` Amazfit Bip 6 | `/tmp/08a-pkg/bip6.zab`, 247,838 bytes |
| `zeus build` Amazfit Active 3 Premium | `/tmp/08a-pkg/round.zab`, 247,940 bytes |
| `device.zip` images | `assets/icon.png` 16,960 bytes on both. Logo 9,728 bytes on Bip 6 and 13,184 bytes on the round target. |
| Fonts shipped in `device.zip` | none |

The two `.zab` files differ by 102 bytes before any color work. After size stays unmeasured until a native color pass exists. No battery measurement was taken.
