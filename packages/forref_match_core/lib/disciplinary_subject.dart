import 'match_participant.dart';
import 'match_team.dart';

/// The only disciplinary subject categories in this program.
enum DisciplinarySubjectKind {
  participant,
  teamOfficial,
}

extension DisciplinarySubjectKindWire on DisciplinarySubjectKind {
  String get wireValue => switch (this) {
        DisciplinarySubjectKind.participant => 'PARTICIPANT',
        DisciplinarySubjectKind.teamOfficial => 'TEAM_OFFICIAL',
      };

  static DisciplinarySubjectKind? parseWire(String? value) => switch (value) {
        'PARTICIPANT' => DisciplinarySubjectKind.participant,
        'TEAM_OFFICIAL' => DisciplinarySubjectKind.teamOfficial,
        _ => null,
      };
}

/// Opaque stable team-official token.
///
/// The raw token does not contain a match id. Display name, role label, and
/// bench position are not this value.
final class MatchTeamOfficialId {
  MatchTeamOfficialId(String raw) : value = _validate(raw);

  final String value;

  static String _validate(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'MatchTeamOfficialId cannot be empty');
    }
    return raw;
  }

  String get wireValue => value;

  static MatchTeamOfficialId parseWire(String wire) => MatchTeamOfficialId(wire);

  @override
  bool operator ==(Object other) =>
      other is MatchTeamOfficialId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MatchTeamOfficialId($value)';
}

/// Match-scoped team-official identity. The same token in two matches differs.
final class MatchScopedTeamOfficialId {
  MatchScopedTeamOfficialId({
    required String matchId,
    required this.teamOfficialId,
  }) : matchId = _nonEmpty(matchId);

  final String matchId;
  final MatchTeamOfficialId teamOfficialId;

  static String _nonEmpty(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'matchId', 'match id cannot be empty');
    }
    return raw;
  }

  Map<String, String> toJson() => {
        'matchId': matchId,
        'teamOfficialId': teamOfficialId.wireValue,
      };

  static MatchScopedTeamOfficialId fromJson(Map<String, String> json) {
    final matchId = json['matchId'];
    final teamOfficialId = json['teamOfficialId'];
    if (matchId == null || teamOfficialId == null) {
      throw ArgumentError.value(
        json,
        'json',
        'match-scoped team-official identity is incomplete',
      );
    }
    return MatchScopedTeamOfficialId(
      matchId: matchId,
      teamOfficialId: MatchTeamOfficialId.parseWire(teamOfficialId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchScopedTeamOfficialId &&
      matchId == other.matchId &&
      teamOfficialId == other.teamOfficialId;

  @override
  int get hashCode => Object.hash(matchId, teamOfficialId);
}

/// Authoritative team association for one team official in one match.
///
/// This is identity evidence. It is not a roster, a bench slot, or a name.
final class TeamOfficialTeamBinding {
  const TeamOfficialTeamBinding({
    required this.matchId,
    required this.teamOfficialId,
    required this.teamId,
  });

  final String matchId;
  final MatchTeamOfficialId teamOfficialId;
  final MatchTeamId teamId;

  Map<String, String> toJson() => {
        'matchId': matchId,
        'teamOfficialId': teamOfficialId.wireValue,
        'teamId': teamId.value,
      };

  static TeamOfficialTeamBinding fromJson(Map<String, String> json) {
    final matchId = json['matchId'];
    final teamOfficialId = json['teamOfficialId'];
    final teamId = json['teamId'];
    if (matchId == null || teamOfficialId == null || teamId == null) {
      throw ArgumentError.value(json, 'json', 'team-official binding is incomplete');
    }
    return TeamOfficialTeamBinding(
      matchId: matchId,
      teamOfficialId: MatchTeamOfficialId.parseWire(teamOfficialId),
      teamId: MatchTeamId(teamId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TeamOfficialTeamBinding &&
      matchId == other.matchId &&
      teamOfficialId == other.teamOfficialId &&
      teamId == other.teamId;

  @override
  int get hashCode => Object.hash(matchId, teamOfficialId, teamId);
}

/// Disciplinary subject. Category is part of equality.
sealed class DisciplinarySubjectRef {
  const DisciplinarySubjectRef();

  DisciplinarySubjectKind get kind;

  /// Raw token only. Equality also includes [kind].
  String get rawId;

  Map<String, String> toJson() => {
        'subjectKind': kind.wireValue,
        'subjectId': rawId,
      };

  static DisciplinarySubjectRef parseJson(Map<String, Object?> json) {
    final kind = DisciplinarySubjectKindWire.parseWire(json['subjectKind'] as String?);
    final rawId = json['subjectId'];
    if (kind == null || rawId is! String || rawId.isEmpty) {
      throw ArgumentError.value(json, 'json', 'disciplinary subject is incomplete');
    }
    return switch (kind) {
      DisciplinarySubjectKind.participant =>
        ParticipantDisciplinarySubject(MatchParticipantId(rawId)),
      DisciplinarySubjectKind.teamOfficial =>
        TeamOfficialDisciplinarySubject(MatchTeamOfficialId(rawId)),
    };
  }
}

final class ParticipantDisciplinarySubject extends DisciplinarySubjectRef {
  const ParticipantDisciplinarySubject(this.participantId);

  final MatchParticipantId participantId;

  @override
  DisciplinarySubjectKind get kind => DisciplinarySubjectKind.participant;

  @override
  String get rawId => participantId.value;

  @override
  bool operator ==(Object other) =>
      other is ParticipantDisciplinarySubject &&
      participantId == other.participantId;

  @override
  int get hashCode => Object.hash(kind, participantId);

  @override
  String toString() => 'ParticipantDisciplinarySubject(${participantId.value})';
}

final class TeamOfficialDisciplinarySubject extends DisciplinarySubjectRef {
  const TeamOfficialDisciplinarySubject(this.teamOfficialId);

  final MatchTeamOfficialId teamOfficialId;

  @override
  DisciplinarySubjectKind get kind => DisciplinarySubjectKind.teamOfficial;

  @override
  String get rawId => teamOfficialId.value;

  @override
  bool operator ==(Object other) =>
      other is TeamOfficialDisciplinarySubject &&
      teamOfficialId == other.teamOfficialId;

  @override
  int get hashCode => Object.hash(kind, teamOfficialId);

  @override
  String toString() => 'TeamOfficialDisciplinarySubject(${teamOfficialId.value})';
}

/// Result of looking up one trusted team-official binding.
sealed class TeamOfficialBindingAssessment {
  const TeamOfficialBindingAssessment();
}

final class TrustedTeamOfficialBinding extends TeamOfficialBindingAssessment {
  const TrustedTeamOfficialBinding(this.binding);

  final TeamOfficialTeamBinding binding;
}

final class MissingTeamOfficialBinding extends TeamOfficialBindingAssessment {
  const MissingTeamOfficialBinding();
}

final class AmbiguousTeamOfficialBinding extends TeamOfficialBindingAssessment {
  const AmbiguousTeamOfficialBinding();
}

/// One applicable team, or a closed failure. Two teams do not collapse.
TeamOfficialBindingAssessment assessTeamOfficialTeamBinding({
  required String matchId,
  required MatchTeamOfficialId teamOfficialId,
  required List<TeamOfficialTeamBinding> bindings,
}) {
  final teams = <MatchTeamId>{};
  TeamOfficialTeamBinding? chosen;
  for (final binding in bindings) {
    if (binding.matchId != matchId || binding.teamOfficialId != teamOfficialId) {
      continue;
    }
    teams.add(binding.teamId);
    chosen ??= binding;
  }
  if (teams.isEmpty) return const MissingTeamOfficialBinding();
  if (teams.length != 1) return const AmbiguousTeamOfficialBinding();
  return TrustedTeamOfficialBinding(
    chosen!.teamId == teams.single
        ? chosen
        : TeamOfficialTeamBinding(
            matchId: matchId,
            teamOfficialId: teamOfficialId,
            teamId: teams.single,
          ),
  );
}
