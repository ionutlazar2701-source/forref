# Platforms

Where the app runs, in which order, and which devices are not a product surface.

## Build order (implementation sequencing)

This order is how clients are built. It does not make the phone the permanent in-match authority. It does not make a watch a presentation-only upgrade. A supported watch, once its platform profile is certified and MATCH READY has established it as the active capture authority, may operate as the autonomous in-match instrument under [forref-development/FOUNDATION_FREEZE.md](forref-development/FOUNDATION_FREEZE.md). No watch is production-certified by this page. WAVE 1 remains HOLD.

1. **Phone app (Flutter, Android + iOS)** — accessibility: the supported workflow must not require a watch
2. **Wear OS native** — largest Android watch set, including used Galaxy Watch 4/5/6 (~80–150€)
3. **watchOS** — so Refsix is not alone on Apple
4. **Garmin Connect IQ** — battery life; separate language (Monkey C)
5. **Zepp OS** — only after match data and sync are stable

Do not skip ahead (Zepp-first, Garmin-first, watch-only). A used Wear OS watch is a more honest cheap-watch strategy than “works on any 25€ band.”

## Why Wear OS is first among watches

Samsung Galaxy Watch is the common Wear OS device in RO/EU. Pixel Watch covers stock Wear OS and small screens. Together they catch most Wear OS fragmentation (One UI vs stock, large vs small, RAM/UI differences).

## Why Zepp is last

Zepp OS can do GPS and heart rate in its SDK, but UI, memory, and store distribution are limited. It is a port of a stable match core, not a place to discover the product.

## Bands are not apps

Xiaomi Band, Huawei Band, and CMF do not get a custom score/timer UI as a sellable product. There is no serious third-party store path. At most: notification + vibration. The match UI stays on the phone.

Xiaomi is fragmented: some watches are Wear OS (the Wear app runs); others are RTOS/Vela. Do not treat “HyperOS Watch SDK” as a wide European market.

## LTE vs Bluetooth

The real case is Bluetooth + phone at the touchline. Do not prioritize LTE watch variants. See [hardware-test-matrix.md](hardware-test-matrix.md).

## Phone vs watch toolkits

Phone is **Flutter**. Watches stay native. Flutter is not a watch target. Do not use React Native for the MVP phone app.
