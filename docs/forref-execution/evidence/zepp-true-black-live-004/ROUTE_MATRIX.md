# 23-route color matrix

Routes are the `app.json` list. Count is 23, including `controls`. Every route paints through `stack` or `paintBase`, and both call the shared black canvas.

| Route | Paint | Button roles |
| --- | --- | --- |
| home | stack | Officiate primary; Train and Settings navigation; device line secondary |
| select | stack | Fixture primary; back navigation; unverified warning |
| hub | stack | Coin, warmup, incident, prepare, back navigation; stopped-clock warning |
| warmup | stack | Back navigation; stopped-clock warning |
| incident | stack | Back navigation |
| ready | stack | Open Live primary; back navigation; body warning |
| toss | stack | Choices navigation; winner secondary; not-recorded warning |
| live | paintBase | Scores neutral; kick-off, resume, second half, resume game primary; pause and suspend caution; end half, full time, abandon red; other clock actions and Match Controls navigation; unverified phase warning |
| controls | stack | End half, full time, abandon red; suspend caution; remaining actions navigation; unverified status warning |
| display | stack | Selected layout selected; other layout and back navigation |
| event | paintBase | Yellow, red, goal neutral, sub neutral, back navigation; title warning |
| player | stack | Player choices navigation; context secondary |
| review | stack | Capture actions navigation; status warning |
| settings | stack | All actions navigation; mode line warning |
| cautions | stack | Back navigation |
| neutral | stack | Half-time, recovery, finish, back navigation |
| halftime | stack | Back navigation |
| recovery | stack | Back navigation |
| finish | stack | Back navigation |
| train | stack | Warm, live, done, back navigation |
| train-warm | stack | Back navigation |
| train-live | stack | Back navigation |
| train-done | stack | Back navigation |

Live A and Live C share this page. Frozen hit rectangles, asserted in `test/theme.test.js`:

| Profile | Mode | Home | Away | Primary | Back |
| --- | --- | --- | --- | --- | --- |
| 390×450 | A | 10,196 181×108 | 199,196 181×108 | 10,392 181×46 | 199,392 181×46 |
| 390×450 | C | 10,72 370×80 | 10,260 370×80 | 10,394 181×44 | 199,394 181×44 |
| 480×480 | A | 70,188 166×100 | 244,188 166×100 | 70,328 166×46 | 244,328 166×46 |
| 480×480 | C | 103,58 274×72 | 103,250 274×72 | 103,352 133×44 | 244,352 133×44 |

Event 2×2 on 390×450 stays yellow 73,92 118×118 and red 199,92 118×118. Round goal stays 108,214 128×128.

RO and EN strings were not edited. Existing live-surface coverage still requires both languages for the match-control keys.
