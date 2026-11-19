# Visual gate

## Simulator

`zeus status` during this run: login present (`userID` `7086278471`), simulator `disconnected` on `127.0.0.1:7650`. No `qemu-system-arm` binary and no emulator cache were present under the Zeus install. `zeus dev` was not started, because there was no guest to attach.

**SIMULATOR VISUAL GATE BLOCKED** for rectangular 390×450 runtime frames and for round 480×480 runtime frames. No screenshots were fabricated. PR #45 concept images are not runtime evidence for this build.

`DISPLAY=:1` was set on the VM. That display does not provide a Zepp guest.

## Builds that did complete

| Target | Result |
| --- | --- |
| Amazfit Bip 6 | `zeus preview` package, square `390x450`, sources `9765120`, `9765121`, `10158337` |
| Amazfit Active Max | `zeus build` package, round `480x480`, sources `10813697`, `10813699` |

The Active Max package proves the same source compiles for the round profile. It was not previewed, not installed, and is not the founder QR. Its file is `29566-FORREF-1.0.3-20261119221708.zab`, sha256 `80572214b045816770e547d0f7be5f51efd54138fedc5e632ded4b85120e545b`, and it includes the CLI intermediate `.ip-package`. It is not in git.

## OS chrome

The app fill still starts at `0,0` and covers the framebuffer, which is the previous geometry. On a square device the top 64px remains the OS status strip. Black there is the app fill behind the system icons. This run did not capture that strip.

## Founder visual review

Install only after the separate PR #52 T15-B test. Then compare, in daylight if possible:

1. Home canvas is black, Officiate is turquoise with black type, Train and Settings are blue with black type.
2. Live A and Live C: white timer, secondary distance line, black score buttons with white labels, press turning `#163A4A`.
3. Pause reads brown-gold, end half / full time / abandon read dark red, kick-off reads turquoise.
4. Event yellow and red stay distinct from goal and substitution.
5. TIME_UNVERIFIED phase text is gold, not turquoise.
6. Yellow-card white on `#8A7430` is the closest contrast pair (4.54:1). Reject it if it fails in sun.

Stop if the watch freezes, heats, reboots, or an action no longer hits. Do not treat a short look as a 90-minute or GPS certification.
