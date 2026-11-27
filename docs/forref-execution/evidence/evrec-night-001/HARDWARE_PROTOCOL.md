# Bip 6 protocol — not executed

`HARDWARE GATE PENDING`

No Amazfit Bip 6 was attached to this run. None of the steps below was performed on hardware. A passing unit test is not a result for any step.

## Setup

Install the watch package built from this branch. Pair the Bip 6 with the phone that runs FORREF. Prepare one real match on the phone. Record the watch installation UUID before kick-off and confirm the phone reservation uses that UUID.

## Scenarios

1. First provision. The watch receives `forref.watch-provision.v1` for that match. The installation UUID matches. Home and away team ids match the phone. The watch shows config verified, then phone authority locked, then watch activated. Every line still says D1 uncertified. The context file exists only after the activation readback.

2. Process termination. Force-stop FORREF on the watch and open it again. The same provision and any recorded goals are still present. The installation UUID is unchanged.

3. Bluetooth disconnect. Turn Bluetooth off after activation. The journal already on the watch remains. A new provision must not arrive. Local goal capture must not require the radio.

4. Two goals. Record one goal for home and one for away. The button labels become the English `HOME 1` and `AWAY 1`, or the Romanian equivalents. Repeat the same confirm action. The count does not rise. A new confirm is a new goal.

5. Score persistence. Leave the app and reopen it. Leave the live screen and return. The same counts are shown. If the journal cannot be read, the buttons must not show zero.

6. Notification. Open a notification during the match, return, and confirm the clock did not restart and the score did not reset.

7. Another app. Leave to another app and return. Elapsed time continues from the clock already on this branch. This mission must not have changed that cadence.

8. Duration. Run one uninterrupted 45-minute session and one uninterrupted 90-minute session. Record whether the displayed elapsed time jumps by about two seconds and stays there.

9. Battery and storage. Note battery percent and the size of `forref_watch_goal_journal_v1.journal` at the start and end of the 90-minute session.

10. Interrupted acknowledgement. Confirm a goal and kill the app before the confirm page returns. Reopen. The goal is present once. Confirming again with the recovered intent does not add a second goal.

11. Power loss. Only if it can be done without damaging the device: cut power after a goal write and before the next paint. On restart, report whether the frame is complete, torn, or absent. Do not treat a torn frame as a goal, and do not delete it.

## What this run cannot sign

No `.zab` was produced here. No QR and no install URL are attached. CHRON-004 and CLOCK-006 were not modified and were not re-certified on a device.
