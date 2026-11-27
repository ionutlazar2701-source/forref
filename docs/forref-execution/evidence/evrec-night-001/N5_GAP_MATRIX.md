# N5 gap matrix

This is a review of contracts still required before Yellow, Send-off, or Substitution can be authoritative writers. No writer for those events was enabled.

| Topic | Already present | Still required before an authoritative writer |
| --- | --- | --- |
| Yellow | `YellowCardPayload` identifies a participant caution. `YellowCardPayloadV2` identifies a disciplinary subject. Two cautions do not create a send-off. | An approved reason catalog with exact codes and legal applicability. An approved enrichment record that can classify a committed Yellow later without rewriting it. A storage rule for `REASON_PENDING` and for SKIP that cannot discard the caution. |
| Send-off | `SendOffPayload` distinguishes `DIRECT` from `SECOND_CAUTION`. `SECOND_CAUTION` carries two caution record references. | The same reason-catalog decision if a send-off is to carry a reason. A proof that the two referenced cautions are the standing ones for that subject. No automatic conversion from a second Yellow. |
| Substitution | `SubstitutionPayload` names outgoing and incoming participant ids and a team id. | An approved eligibility profile. A provisioning contract for stable `MatchParticipantId` values. Shirt numbers and legacy player aliases are not those ids. |
| Participant provisioning | `MatchParticipantId` exists and is not a shirt number. | The list of participants for a match, who may create those ids, and how the watch receives them. That list is not in `forref.watch-provision.v1`. |
| Disciplinary reasons | The product decision says a skipped reason stays pending and the sanction stays immutable. | The catalog, the enrichment schema, and the durability rule for that enrichment. None of those is approved in this mission. |
| Goal | Local journal and local test score exist for a provisioned match. | Watch-local D1 certification before any of this may be called Saved or KnownScore. |

`HUMAN GATE PENDING — CONTRACT REQUIRED` for Yellow reasons, send-off reason attachment, substitution eligibility, and participant provisioning. Goal local recording does not remove those gates.
