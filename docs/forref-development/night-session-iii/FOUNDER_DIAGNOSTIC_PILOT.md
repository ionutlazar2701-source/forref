# Founder diagnostic pilot

Status of this file: RECORD

Role: DIAGNOSTIC ONLY.

Founder results do not count in a decisive human-performance acceptance.

Purpose: find broken mechanics, confusing instructions, and obvious comprehension defects, and check that the research log matches what was tapped.

## Before the first task

- Device shows `FORREF RESEARCH PROTOTYPE`.
- Operator panel can load a scenario and can show the log.
- Capture column does not contain the scenario list.
- Say this once: "Acesta este un prototip de cercetare. Salvat aici nu înseamnă că meciul a fost scris în memoria de producție."
- English if needed: "This is a research prototype. Saved here does not mean the match was written to production memory."

## Order

Run these scenarios in order. Pitch text is on the capture column after load. Expected truth is in [SCENARIO_EXPECTED_TRUTH.md](SCENARIO_EXPECTED_TRUTH.md).

1. `s01YellowNoPrior`
2. `s03YellowPriorUnavailable`
3. `s05Y2SendOffContinuation`
4. `s07RapidRepeatAfterY2`
5. `s08DirectRedWithPriorYellow`
6. `s09Home14ThenAway14`
7. `s10SimilarOfficials`
8. `s12SubstitutionInFirst`
9. `s14SubstitutionInterruptAfterPair`
10. `s16SaveNotVerified`
11. `s17FinishLaterSimulatedRestart`
12. `s18MatchToShootout`
13. `s19SentOffHistoricalReview`

After each one, ask the four core questions from the protocol. Add the prior-caution, sending-off, save, or substitution questions when that scenario is about them.

On `s17`, the moderator points at `SIMULATED RECOVERY BEHAVIOR` and asks whether the referee thinks the production app already does this. The acceptable understanding is no.

## Log check

After `s05` and `s07`, open Operator and confirm the log contains a yellow activation and does not contain a sending-off activation unless the Founder used the sending-off rectangle on purpose.

## Stop

Reproducible P0: stop, note the scenario id, and do not continue the pilot as if the instrument were sound.

## Output

A filled sheet with the measures that were actually observed. Blank where not observed. No score is invented after the session.
