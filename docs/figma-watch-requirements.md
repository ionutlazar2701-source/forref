# Figma file requirements for the FORREF watch

Checklist for the watch design file before a screen is implemented in `apps/forref_watch_zepp`. Visual design stays an open decision in [open-decisions.md](open-decisions.md). This page records what the file needs so a frame can be built with Zepp OS widgets instead of guessed layout.

Source file used for Home: [Untitled](https://www.figma.com/design/8eNkAxIUDXKrfkN4zg5bnK/Untitled). Home is frame `00_Home_Mode_Select` (`14:70`) and component `Home_Mode_Option` (`14:6`). That frame is a 480 circle with a named component, auto-layout, color and spacing variables, and real text. The file is still that one circle.

## What Home already provides

- Component `Home_Mode_Option`, described as a text-only touch zone with no icons.
- Equal flex halves, 12 px safe margin, 16 px horizontal padding, 8 px gap.
- Variables: background black, primary text white, secondary text `#b3cbd7`, accent `#3fc3be`.
- Text styles on the 480 frame: title 32 / line 40, subtitle 20 / line 28.

## Add these before the next screen

1. **Both watches, one frame per screen.** Keep the 480×480 round frame. Place a 390×450 rectangular frame beside it for the Amazfit Bip 6, same screen, same components. On the rectangle, leave the top 64 px as the system status bar and 12 px on the sides and bottom. Name frames after the routes, for example `00_Home_Mode_Select`, `01_Select_Match`, `02_Live`.

2. **Components with properties.** Follow `Home_Mode_Option`. Each control is a component, with a description of what it contains. Title and subtitle are component properties. Add the Romanian copy as a language variant or a second set of properties. English-only text is translated in code without the founder's wording.

3. **Variants for states that change pixels.** Add pressed. Add disabled when a zone can be unavailable. For Live, add the states the app already has: ready, running, paused, half-time, full time, and time unverified. Add icons, carousel dots, or other chrome only when that screen should show them.

4. **Variables bound to every fill and text style.** Keep the Home colors and the 8 px, 16 px, and 12 px spacing. Add the remaining watch colors as variables with the same names the code uses: warning `#c4a35a`, and the button roles primary, navigation, neutral, yellow, red, caution, and selected. The current role values are in `apps/forref_watch_zepp/utils/theme.js`. Accent hexes stay open for founder acceptance. Canvas black is fixed.

5. **Type the watch can draw.** Keep the 480-frame sizes. Zepp draws the system font. It has no Inter Bold, no Inter Medium, and no letter-spacing. Note on the text style that hierarchy is size and color. Set the max width in the frame when a line must stay one line. The long subtitle wraps first at 390 px width.

6. **Solid fills.** Build screens from flat rectangles and text. The divider is a 1 px rectangle. A square zone has radius 0. The circle is the round glass, not a corner radius on the buttons.

7. **Touch zones as their own layers.** The tappable area is a layer with a fixed size, as the two Home halves are. The label sits inside that layer. A useful target on this app is at least about 40×28 px. Equal halves are a layout rule on the component.

Code Connect, linking each Figma component to the Zepp widget in the repo, is useful after those components exist. It is not required to implement the next screen.

## How a frame is implemented

Read the frame with the Figma tools, including the screenshot, variables, and component properties. Implement it in Zepp OS JavaScript and `@zos/ui`. Reuse `apps/forref_watch_zepp/utils/theme.js` and the RO + EN strings in `apps/forref_watch_zepp/utils/text.js`. Lay the 480 frame out in its own pixels, and scale type from that frame onto the 390×450 rectangle while keeping the status-bar and 12 px insets. Leave Match Core, match timing, persistence, and screens outside the requested frame unchanged.
