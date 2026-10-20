# Scenario expected truth

Status of this file: RECORD

Load these from the Operator list in `research/hf_prototype`. Reset by loading the same id again.

Simulated commit success is the script unless the row says otherwise. None of these write production Match Memory.

| ID | Start | Pitch truth | Digital truth | Unfinished | P0 | P1 | Log markers | Questions | Reset |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| s01 | Home trusted, player 9, no saved caution | No earlier caution | Known verified absence | Yellow not saved | A standing caution before save | Referee cannot say the prior state is absence | scenarioStarted, priorCautionShown | Core plus prior caution | Reload s01 |
| s02 | One saved caution | One standing caution already | One saved caution, not two | Second yellow open | Two cautions before the second save | Count is misread as a sending-off | priorCautionShown | Prior caution, sending-off | Reload s02 |
| s03 | Prior unavailable | History incomplete | Unavailable, not known none | Nothing saved | Unavailable shown as verified none | Referee treats the label as none | priorCautionShown | Prior caution | Reload s03 |
| s04 | Prior conflicted | History disagrees | Conflicted, not known none | Nothing saved | Conflicted shown as verified none | Referee treats the label as a normal caution | priorCautionShown | Prior caution | Reload s04 |
| s05 | One saved caution | Second caution on the pitch, no send-off yet | SEND_OFF absent until a fresh action | Second yellow, then a separate send-off | Yellow gesture records SEND_OFF | Referee cannot find the second control | finalActionActivated yellow, then a later send-off only if tapped | Sending-off question | Reload s05 |
| s06 | One saved caution | Send-off happens later | SEND_OFF stays absent across interruption | New action after resume | Interruption records SEND_OFF | Referee thinks the interruption finished the send-off | interruption, resume | Sending-off, unfinished | Reload s06 |
| s07 | One saved caution | Two taps on yellow | Yellow only | Second tap is not a send-off | Repeat contact records SEND_OFF | Hesitation about which control is live | one yellow activation | Sending-off | Reload s07 |
| s08 | One saved caution | Direct send-off | Pathway DIRECT | Direct action not yet saved | Second-caution inferred from the yellow | Pathway label ignored | direct activation | Pathway question | Reload s08 |
| s09 | Home 14 selected | It was Away 14 | No caution for either 14 | Home 14 invalidated on team change | Home 14 survives as Away 14 | Wrong 14 corrected only after a prompt | subjectInvalidated | Core identity questions | Reload s09 |
| s10 | No official selected | Two Alex Popescu roles | Nothing saved | No automatic official | Similar name auto-selects | Referee picks a role and cannot explain it | officialSelected only after a tap | Who was selected | Reload s10 |
| s11 | No pair | OUT first | No substitution | OUT only | OUT-only records a substitution | OUT control is hard to find | outSelected | Who is OUT | Reload s11 |
| s12 | No pair | IN first | No substitution | IN only | IN-only records a substitution | IN is spoken as OUT | inSelected | Who is IN, recorded? | Reload s12 |
| s13 | No pair | Interrupt after OUT | No substitution | OUT remains OUT | Interruption clears or swaps OUT | Referee abandons rather than resumes | interruption, resume, outSelected | Unfinished | Reload s13 |
| s14 | No pair | Pair named, not recorded | No substitution | Roles stay | Reorder or interruption reverses roles | Pair is believed saved | pairReviewed, no substitution activation | OUT, IN, recorded? | Reload s14 |
| s15 | Yellow offered into save | Interrupt while saving | No new caution | Save not verified | Interruption marks Saved | Referee equates interruption with failure without reading the label | interruption | Save questions | Reload s15 |
| s16 | Scripted unknown outcome | Commit ends unknown | Not saved and not a known failure | Blind resubmit refused | Unknown shown as Saved or Not saved | Referee would submit again immediately | simulatedCommitOutcome saveNotVerified | Do you know if it was saved | Reload s16 |
| s17 | Already save-not-verified, disclaimer on | Come back later | No production recovery | Unknown stays unknown | Disclaimer read as a production guarantee | Referee misses the simulated label | scenarioStarted, disclaimer visible | Is this the production app | Reload s17 |
| s18 | One match caution | Next action is the shoot-out | Ledgers stay separate | Shoot-out does not inherit the match count | Counts combine | Scope chip is missed | scope | Prior caution in each scope | Reload s18 |
| s19 | Two cautions and a saved send-off | History still inspectable | Active surface closed, history kept | No new yellow from review | History deleted | Referee thinks the yellows vanished | priorCautionShown | History versus active | Reload s19 |

## Variants

Also loadable, same reset rule:

| ID | What it adds | P0 if |
| --- | --- | --- |
| vDuplicateShirt | Two home players wear 7 | The two ids collapse |
| vCrossTeamShirt | Home 14 and Away 14 | The shirt selects both |
| vSimilarNames | Similar outfield names | The other id replaces the tap |
| vLongOfficialName | Long official name and role | Truncation selects someone else |
| vTemporarilyOff | Player remains listed | The player disappears |
| vSubstituted | Substituted player remains listed | The player disappears |
| vStaleStatus | Status may be stale | A new id is minted |
| vUnavailableStatus | Presence unknown | The row becomes on-field certainty or hides |
| vConflictedStatus | Presence conflicted | The row looks like ordinary on-field with no mark |
| vTeamTrusted | Home already trusted | The task demands a team tap that changes nothing and then records the wrong team |
| vTeamAbsent | No team yet | A subject is accepted with no team |

Research log kinds the moderator can see: scenario started, surface entered, team context applied, team manually changed, subject selected, subject invalidated, official selected, prior caution shown, OUT selected, IN selected, pair reviewed, final action armed, final action activated, simulated commit started, simulated commit outcome, interruption, resume, scope, user correction, scenario completed, scenario abandoned.
