import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/features/live_match/yellow_card_read_surface.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';
import 'package:referee_phone/match/new_match.dart';

enum MatchSummaryRowKind { goal, yellowAuthority, legacyEvent }

final class MatchSummaryRow {
  const MatchSummaryRow({
    required this.kind,
    required this.sortKey,
    required this.title,
    this.subtitle = '',
  });

  final MatchSummaryRowKind kind;
  final int sortKey;
  final String title;
  final String subtitle;
}

List<MatchSummaryRow> buildMatchSummaryRows({
  required Match match,
  required GoalMatchProjection goalProjection,
  required DisciplinaryMatchProjection disciplinary,
  required ParticipantIdentityProjection identities,
  required List<MatchRecord> records,
  required Map<String, TemporalEvidence> evidenceById,
  required AppLocalizations l10n,
  List<PhoneParticipantRegistryEntry> registryEntries = const [],
}) {
  final policy = legacyYellowDataPolicy(
    legacyEvents: match.events,
    disciplinary: disciplinary,
  );
  final recordSequence = {
    for (final record in records) record.recordId: record.originSequence,
  };
  final rows = <MatchSummaryRow>[];

  for (final goal in goalProjection.goals) {
    final sequence = recordSequence[goal.recordId] ?? 0;
    rows.add(
      MatchSummaryRow(
        kind: MatchSummaryRowKind.goal,
        sortKey: sequence,
        title:
            '${formatProjectedGoalTime(goal.temporal, l10n)}  ${l10n.goal}',
        subtitle: goal.creditedSide == CreditedSide.home
            ? homeLabel(match, l10n)
            : awayLabel(match, l10n),
      ),
    );
  }

  if (policy != LegacyYellowDataPolicy.legacyOnly) {
    for (final yellow in buildYellowCardHistoryRows(
      match: match,
      disciplinary: disciplinary,
      identities: identities,
      records: records,
      evidenceById: evidenceById,
      l10n: l10n,
      registryEntries: registryEntries,
    )) {
      rows.add(
        MatchSummaryRow(
          kind: MatchSummaryRowKind.yellowAuthority,
          sortKey: yellow.originSequence,
          title: '${yellow.timeLabel}  ${l10n.yellow}',
          subtitle: yellow.detailLine.isEmpty
              ? yellow.participantLabel
              : '${yellow.participantLabel} · ${yellow.detailLine}',
        ),
      );
    }
  }

  for (var index = 0; index < match.events.length; index++) {
    final event = match.events[index];
    if (event.type == EventType.goal) continue;
    if (event.type == EventType.yellowCard &&
        policy != LegacyYellowDataPolicy.legacyOnly) {
      continue;
    }
    rows.add(
      MatchSummaryRow(
        kind: MatchSummaryRowKind.legacyEvent,
        sortKey: index,
        title:
            '${formatMatchClock(event.matchTime)}  ${eventTypeLabel(event.type, l10n)}'
            '${event.status == EventStatus.incomplete ? ' · ${l10n.incomplete}' : ''}',
        subtitle: event.data.teamId == null
            ? ''
            : teamLabel(match, event.data.teamId!, l10n),
      ),
    );
  }

  rows.sort((left, right) => right.sortKey.compareTo(left.sortKey));
  return rows;
}
