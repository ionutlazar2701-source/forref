import '../match_record.dart';
import '../participant/disciplinary_accounting_scope.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';
import 'participant_identity_projection.dart';
import 'temporal_match_projection.dart';

/// Derived card-authority and disciplinary accounting state.
final class DisciplinaryAuthorityProjection {
  const DisciplinaryAuthorityProjection({
    required this.cardDisplayAuthorityOpen,
    required this.accountingScope,
    required this.refereeEnteredFieldCommitted,
    required this.refereeLeftFieldCommitted,
    required this.matchStarted,
    required this.matchEnded,
    required this.participantIdentity,
  });

  static const empty = DisciplinaryAuthorityProjection(
    cardDisplayAuthorityOpen: false,
    accountingScope: DisciplinaryAccountingScope.unresolved,
    refereeEnteredFieldCommitted: false,
    refereeLeftFieldCommitted: false,
    matchStarted: false,
    matchEnded: false,
    participantIdentity: ParticipantIdentityProjection.empty,
  );

  final bool cardDisplayAuthorityOpen;
  final DisciplinaryAccountingScope accountingScope;
  final bool refereeEnteredFieldCommitted;
  final bool refereeLeftFieldCommitted;
  final bool matchStarted;
  final bool matchEnded;
  final ParticipantIdentityProjection participantIdentity;

  static DisciplinaryAuthorityProjection derive({
    required List<MatchRecord> records,
    CompetitionRulesContext? competitionRules,
  }) {
    final ordered = [...records]..sort(deterministicRecordOrder);
    MatchRecord? entered;
    MatchRecord? left;
    var matchStarted = false;
    var matchEnded = false;

    for (final record in ordered) {
      final payload = record.payload;
      if (payload is TemporalTransitionPayload) {
        switch (payload.semanticType) {
          case V1SemanticTypeCode.matchStarted:
            matchStarted = true;
          case V1SemanticTypeCode.matchEnded:
            matchEnded = true;
          case V1SemanticTypeCode.refereeEnteredFieldForMatchStart:
            entered = record;
          case V1SemanticTypeCode.refereeLeftFieldAfterMatch:
            left = record;
          default:
            break;
        }
      }
    }

    final enteredCommitted = entered != null;
    final leftCommitted = left != null;
    final open = entered != null &&
        (left == null || entered.originSequence > left.originSequence);

    final accountingScope = _deriveAccountingScope(
      cardDisplayOpen: open,
      matchStarted: matchStarted,
      matchEnded: matchEnded,
      competitionRules: competitionRules,
    );

    return DisciplinaryAuthorityProjection(
      cardDisplayAuthorityOpen: open,
      accountingScope: accountingScope,
      refereeEnteredFieldCommitted: enteredCommitted,
      refereeLeftFieldCommitted: leftCommitted,
      matchStarted: matchStarted,
      matchEnded: matchEnded,
      participantIdentity: ParticipantIdentityProjection.derive(
        records: records,
      ),
    );
  }
}

DisciplinaryAccountingScope _deriveAccountingScope({
  required bool cardDisplayOpen,
  required bool matchStarted,
  required bool matchEnded,
  required CompetitionRulesContext? competitionRules,
}) {
  if (!cardDisplayOpen) {
    return DisciplinaryAccountingScope.unresolved;
  }
  if (matchEnded &&
      (competitionRules?.penaltyShootOutAfterMatchEnd ?? false)) {
    return DisciplinaryAccountingScope.shootout;
  }
  if (matchStarted || !matchEnded) {
    return DisciplinaryAccountingScope.match;
  }
  if (matchEnded) {
    return DisciplinaryAccountingScope.match;
  }
  return DisciplinaryAccountingScope.unresolved;
}
