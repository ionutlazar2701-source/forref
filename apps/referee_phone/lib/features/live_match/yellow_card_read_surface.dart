import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/features/live_match/goal_time_label.dart';
import 'package:referee_phone/features/live_match/yellow_card_capture_overlay.dart';
import 'package:referee_phone/features/live_match/yellow_card_phone_read_model.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/l10n/match_labels.dart';

Map<String, TemporalEvidence> temporalEvidenceById(
  Iterable<TemporalEvidence> evidence,
) {
  return {for (final item in evidence) item.evidenceId: item};
}

String legacyYellowPolicyNotice(
  LegacyYellowDataPolicy policy,
  AppLocalizations l10n,
) {
  return switch (policy) {
    LegacyYellowDataPolicy.authorityOnly => '',
    LegacyYellowDataPolicy.legacyOnly => l10n.yellowCardLegacyDataLimitation,
    LegacyYellowDataPolicy.mixedWithheldLegacy =>
      l10n.yellowCardMixedLegacyWithheld,
  };
}

/// One Yellow Card row derived from Match Memory (not legacy events).
final class YellowCardHistoryRow {
  const YellowCardHistoryRow({
    required this.recordId,
    required this.originSequence,
    required this.timeLabel,
    required this.participantLabel,
    required this.detailLine,
    required this.standingEffect,
    required this.accountingScope,
  });

  final String recordId;
  final int originSequence;
  final String timeLabel;
  final String participantLabel;
  final String detailLine;
  final CautionStandingEffect standingEffect;
  final DisciplinaryAccountingScope accountingScope;

  bool get countsAsStanding =>
      standingEffect == CautionStandingEffect.standing;
}

enum LegacyYellowDataPolicy {
  /// New-authority cautions only; no legacy yellow events on the match.
  authorityOnly,

  /// Legacy SQLite events contain Yellow rows but Match Memory does not.
  legacyOnly,

  /// Both exist; authority rows are shown and legacy yellow events are withheld.
  mixedWithheldLegacy,
}

LegacyYellowDataPolicy legacyYellowDataPolicy({
  required List<MatchEvent> legacyEvents,
  required DisciplinaryMatchProjection disciplinary,
}) {
  final legacyYellow =
      legacyEvents.any((event) => event.type == EventType.yellowCard);
  final authorityYellow = disciplinary.historicalCautions.isNotEmpty;
  if (legacyYellow && authorityYellow) {
    return LegacyYellowDataPolicy.mixedWithheldLegacy;
  }
  if (legacyYellow) return LegacyYellowDataPolicy.legacyOnly;
  return LegacyYellowDataPolicy.authorityOnly;
}

List<YellowCardHistoryRow> buildYellowCardHistoryRows({
  required Match match,
  required DisciplinaryMatchProjection disciplinary,
  required ParticipantIdentityProjection identities,
  required List<MatchRecord> records,
  required Map<String, TemporalEvidence> evidenceById,
  required AppLocalizations l10n,
  List<PhoneParticipantRegistryEntry> registryEntries = const [],
  bool standingOnly = false,
  int? limit,
}) {
  final recordById = {
    for (final record in records) record.recordId: record,
  };
  final cautions = standingOnly
      ? disciplinary.standingCautions
      : disciplinary.historicalCautions;
  final options = buildYellowParticipantOptions(
    match: match,
    identities: identities,
    disciplinary: disciplinary,
    homeLabel: homeLabel(match, l10n),
    awayLabel: awayLabel(match, l10n),
    registryEntries: registryEntries,
  );
  final optionByParticipantId = {
    for (final option in options)
      option.participantRef.matchParticipantId.value: option,
  };

  final rows = <YellowCardHistoryRow>[];
  for (final caution in cautions) {
    final record = recordById[caution.recordId];
    if (record == null) continue;
    final temporal = projectedPlayingTimeAtRecord(
      record: record,
      records: records,
      evidenceById: evidenceById,
    );
    final participantId =
        caution.canonicalParticipantId ??
            caution.participantRefAtDetermination.matchParticipantId;
    final option = optionByParticipantId[participantId.value];
    final participantLabel = option != null
        ? _participantLabel(option)
        : _fallbackParticipantLabel(caution, l10n);
    final detailParts = <String>[
      participantStatusLabel(caution.participantStatusAtDetermination, l10n),
      if (caution.accountingScope == DisciplinaryAccountingScope.shootout)
        l10n.yellowCardShootoutScope,
      if (caution.standingEffect == CautionStandingEffect.legallySuperseded)
        l10n.yellowCardSuperseded,
      if (caution.standingEffect == CautionStandingEffect.unresolved)
        l10n.yellowCardStandingUnresolved,
      if (caution.standingOrdinal != null && caution.countsAsStanding)
        l10n.yellowCardStandingOrdinal(caution.standingOrdinal!),
    ];
    rows.add(
      YellowCardHistoryRow(
        recordId: caution.recordId,
        originSequence: record.originSequence,
        timeLabel: formatProjectedGoalTime(temporal, l10n),
        participantLabel: participantLabel,
        detailLine: detailParts.where((part) => part.isNotEmpty).join(' · '),
        standingEffect: caution.standingEffect,
        accountingScope: caution.accountingScope,
      ),
    );
  }
  rows.sort((left, right) => right.originSequence.compareTo(left.originSequence));
  if (limit != null && rows.length > limit) {
    return rows.sublist(0, limit);
  }
  return rows;
}

String participantStatusLabel(
  ParticipantStatusAtDetermination status,
  AppLocalizations l10n,
) {
  return switch (status) {
    ParticipantStatusAtDetermination.onFieldPlayer => l10n.onField,
    ParticipantStatusAtDetermination.substitute => l10n.substitute,
    ParticipantStatusAtDetermination.substitutedPlayer =>
      l10n.substitutedPlayer,
    ParticipantStatusAtDetermination.teamOfficial => l10n.teamOfficial,
    ParticipantStatusAtDetermination.seniorCoachPresent =>
      l10n.seniorCoachPresent,
  };
}

String _participantLabel(YellowParticipantOption option) {
  final number = option.shirtNumber;
  final name = option.displayName?.trim();
  if (number != null && name != null && name.isNotEmpty) {
    return '#$number $name';
  }
  if (number != null) return '#$number';
  if (name != null && name.isNotEmpty) return name;
  return option.teamLabel;
}

String _fallbackParticipantLabel(
  ProjectedHistoricalCaution caution,
  AppLocalizations l10n,
) {
  final binding = caution.participantRefAtDetermination.binding;
  return switch (binding) {
    TeamScopedNumberBinding(:final shirtNumber) => '#$shirtNumber',
    FreeformDescriptorBinding(:final descriptor) => descriptor,
    IdentifiedOfficialBinding(:final displayName) =>
      displayName ?? l10n.teamOfficial,
    SeniorCoachPresentBinding() => l10n.seniorCoachPresent,
    RosterLinkedBinding() => caution.participantRefAtDetermination.teamSide ==
            ParticipantTeamSide.home
        ? l10n.homeFallback
        : l10n.awayFallback,
  };
}
