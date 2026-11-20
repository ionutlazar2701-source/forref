# Pause and half-time isolation

The 1.0.4 founder note says HALF-TIME / PAUSE failed, and the exact symptom was not classified. The cloud tests separate two cases.

## A verified clock

`PAUSE` and `END_FIRST_HALF` on a verified running session, with the UTC step inside 2500 ms, freeze the last good elapsed. The displayed time does not grow afterward. This path does not need the background service. The page timer is enough while the screen stays on.

## An already unverified clock

A single paint 30 seconds after the last observation is `UNSAMPLED_GAP`. `PAUSE` and `END_FIRST_HALF` then return `UNVERIFIED`. The closed elapsed stays at the last good observation. The whistle is refused because the clock is already unverified, not because the pause transition itself added time.

On 1.0.4 the sampler never started, so every screen-off of 5, 30, and 120 seconds took this path. A later pause or half-time whistle on that unverified clock is the same failure. That is the classified cloud explanation. It is not a hardware trace of the whistle the founder pressed.

## Once the sampler is actually running

A running service image must not write over a committed pause or half-time. `preferObserved` keeps the frozen checkpoint, and `commitForward` returns `KEPT_HOLD` instead of restoring the running phase. A service tick then stops.

## What the next hardware pass must record

If the match clock is still showing exact time when the whistle is pressed, record `FORREF_CLOCK_SLEEP intent=PAUSE` or `intent=END_FIRST_HALF`. A failure in that state is a new defect. If the clock is already `TIME_UNVERIFIED` before the whistle, the failure belongs to the screen-off chain.
