# MOBILE 002V — Professional mobile visual system

Visual presentation for the phone instrument. Product navigation and match semantics stay as MOBILE 002 left them.

Branch: `cursor/forref-mobile-002v-visual-system`

Start: `de92d5996b4715ffed52655fd696c4c979fc2f26` on `cursor/forref-mobile-002-officiate-preparation`.

## What changed

Shared theme, type, spacing, and a few surfaces live in `apps/referee_phone/lib/design/`. Matches, Preparation, Live Match, Settings, and the existing summary use that system.

Navy, deep navy, and steel identify the product. Turquoise is not a Saved, ready, or trusted signal. Readiness still prints its claim and its blockers. A blocked Enter Live Match stays disabled and the blocker text stays on the page.

The Linux window opens at 400×860 so a desktop run is phone-shaped. That is not an Android or iOS device run. This host has no Android or iOS simulator. The settings portal does not report a dark color scheme, so a review launch can pass `--dart-define=FORREF_BRIGHTNESS=dark` to show `ForrefTheme.dark()`. Without that define, theme mode follows the platform.

## What did not change

Sporting semantics, Match Memory, authority, and the production command catalog. Kick-off and Goal stay the supported production commands. Training, Devices, and a watch surface stay absent.
