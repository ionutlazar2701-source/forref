# Hardware gate — Native Familiarity V5

Status: **LOCAL GATE REQUIRED**.

The package is `29566-FORREF-1.0.6-nfv5-20261120232226.zab`. Boot line: `build=native-familiarity-v5 rev=75f6757b361962290156ff2f415994c223a52617`. QR expiry: 28 Nov 2026, 01:22:29 Europe/Bucharest (27 Nov 2026, 23:22:29 UTC). Zeus did not report a connected simulator.

Do not install this over a watch that is in a CLOCK-SLEEP test. Sideloading replaces app 29566.

On the watch, after kick-off from READY:

1. Confirm Live is the page that appears, with the middle dot active and the clock running.
2. Tap Match Controls. Pause, the half-end actions that the phase already allows, and abandon confirmation must still require the existing second tap. Leaving the page must drop that confirmation.
3. Tap Cautions. The ledger must stay blocked. Tap Back to Live. The clock must show the same running match, not a reset.
4. From Cautions, press the hardware Back key and also slide from the left edge. Both should return to Live rather than exit the match. From Live, the same slide should leave Live as it does today.
5. Open Goal, Card, or Substitution and return. Live must be the default page and the foreground clock must still be continuous.
6. Repeat the glance on both A and C.

Cloud tests inject UTC and geometry. They do not show a finger on the Bip 6.
