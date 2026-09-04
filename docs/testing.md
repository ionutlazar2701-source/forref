# Testing

You can get far without owning every watch. You cannot call a referee product real from emulators alone.

## Emulators (UI and flow)

Use these for layout, navigation, and fake sensors — not for a 90-minute outdoor match:

- **Android Studio** — Wear OS (round/square), simulated GPS and heart rate, Bluetooth cut
- **Xcode** — Apple Watch (macOS only)
- **Garmin Connect IQ Simulator** — many models, strong for Garmin work
- **Zepp OS Simulator** — UI and flow only, not match conditions

Emulator GPS is clean. Heart rate is fake. Sun, rain, gloves, and sweat do not exist.

## One physical Wear OS watch

Before treating the product as validated, test on **one** real Wear OS watch (a used Galaxy Watch 4/5/6 is enough at the start).

Remote hardware: **Samsung Remote Test Lab** is the useful Galaxy Watch option. BrowserStack / AWS Device Farm help more for phones than for watches.

What to rent, and what not to: [hardware-test-matrix.md](hardware-test-matrix.md).

## Beta on the pitch

The test that matters is a real match with county-league referees:

- iOS: TestFlight
- Android / Wear OS: Play Internal / Closed testing
- Garmin: Connect IQ private/beta, when that client exists

Five to ten referees on the pitch beat any device farm.

## Match checklist

The outdoor 90-minute checklist lives in [hardware-test-matrix.md](hardware-test-matrix.md). GPS, battery, sweat, and Bluetooth drop are hardware-test items, not emulator items.
