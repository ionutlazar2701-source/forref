# Hold packets

## TEAM_OFFICIAL_IDENTITY_DOMAIN

DOMAIN: team-official disciplinary subject

EXACT QUESTION: Which already-frozen typed identity represents a team official, if any?

WHY IT BLOCKS: The frozen package says a team official can be a disciplinary subject, and it also says not to invent a TeamOfficial identity and not to treat a team official as `MatchParticipantId` unless that meaning is already explicit. The repository has no such typed identity.

WHAT CONTINUED: Participant identity, participant Yellow, caution awareness, and the field-entry fact.

SMALLEST NEXT DECISION: Name the typed subject for a team official, or state that FTM Yellow excludes team officials.

BANK B label: PARTICIPANT-YELLOW BANK ONLY. It does not claim complete Yellow-domain coverage.

## BANK D — SEND_OFF

DOMAIN: explicit sending-off payload

EXACT QUESTION: What is the minimum typed pathway vocabulary, and does a second-caution sending-off require links to prior Yellow records?

WHY IT BLOCKS: Foundation Freeze says direct sending-off and second-caution sending-off are distinct pathways. It does not define the payload fields. The historical red draft says the basis vocabulary is unresolved and must not be invented. Choosing wire names, required links, or what happens when those Yellow records are later withdrawn would be a new sporting rule.

WHAT CONTINUED: Identity, participant Yellow, awareness, and field entry. Two standing Yellow records do not create a SEND_OFF record. `SEND_OFF`, `RED`, and `SECOND_YELLOW` are not semantic codes.

SMALLEST NEXT DECISION: Freeze a two-value pathway and whether prior-caution links are required, absent, or forbidden.

## BANK E — completed substitution

DOMAIN: lawful incoming entry

EXACT QUESTION: Which frozen competition profile proves that an incoming participant may enter?

WHY IT BLOCKS: A completed substitution requires lawful entry. No current canonical rules profile defines return substitutions, substitution count, or the default when the profile is silent. Committing a completed substitution would invent eligibility.

WHAT CONTINUED: `ParticipantSituation` exists only as historical context on a Yellow record. It is not a status-transition writer. `SUBSTITUTION` is not a semantic code. Caution history is not cleared by a situation value.

SMALLEST NEXT DECISION: Freeze the FTM eligibility profile, including the result when the profile is absent.

## PHONE AUTHORITY CUTOVER

DOMAIN: phone participant selection

EXACT QUESTION: How does the referee select a `MatchParticipantId` before an authoritative Yellow commit?

WHY IT BLOCKS: The current capture overlay identifies a subject by squad list, unknown, or a typed shirt number. Shirt number is not identity. A new selection surface is a product UX decision. This program does not redesign that overlay.

WHAT CONTINUED: Match Core Yellow admission and the read model. The phone still uses the legacy Yellow writer. That path is NOT MIGRATED. It is not claimed as MATCH_MEMORY Yellow.

SMALLEST NEXT DECISION: Approve a selection control that resolves a stable participant id, with RO and EN copy for unavailable and conflicted awareness, before cutting MATCH_MEMORY Yellow over.

## BRIDGES HELD WITH THEIR BANKS

WAVE 9 status ↔ awareness: HOLD because BANK E is HOLD.

WAVE 10 awareness ↔ SEND_OFF: HOLD because BANK D is HOLD.
