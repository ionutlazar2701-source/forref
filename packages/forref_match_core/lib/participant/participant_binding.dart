import 'participant_team_side.dart';

/// Durable identity evidence associated with one [MatchParticipantId].
sealed class ParticipantBinding {
  const ParticipantBinding();
}

/// Roster-linked participant from setup.
final class RosterLinkedBinding extends ParticipantBinding {
  const RosterLinkedBinding({required this.rosterParticipantId});

  final String rosterParticipantId;

  @override
  bool operator ==(Object other) =>
      other is RosterLinkedBinding &&
      rosterParticipantId == other.rosterParticipantId;

  @override
  int get hashCode => rosterParticipantId.hashCode;
}

/// Team-scoped shirt number. Never globally unique.
final class TeamScopedNumberBinding extends ParticipantBinding {
  const TeamScopedNumberBinding({required this.shirtNumber});

  final int shirtNumber;

  @override
  bool operator ==(Object other) =>
      other is TeamScopedNumberBinding && shirtNumber == other.shirtNumber;

  @override
  int get hashCode => shirtNumber.hashCode;
}

/// Free-form provisional descriptor when roster evidence is incomplete.
final class FreeformDescriptorBinding extends ParticipantBinding {
  const FreeformDescriptorBinding({required this.descriptor});

  final String descriptor;

  @override
  bool operator ==(Object other) =>
      other is FreeformDescriptorBinding && descriptor == other.descriptor;

  @override
  int get hashCode => descriptor.hashCode;
}

/// Named team official when identity is known.
final class IdentifiedOfficialBinding extends ParticipantBinding {
  const IdentifiedOfficialBinding({this.displayName});

  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is IdentifiedOfficialBinding && displayName == other.displayName;

  @override
  int get hashCode => displayName.hashCode;
}

/// Law 5 senior-coach-present role slot when the individual is unknown.
final class SeniorCoachPresentBinding extends ParticipantBinding {
  const SeniorCoachPresentBinding();

  @override
  bool operator ==(Object other) => other is SeniorCoachPresentBinding;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Wire encoding helpers for persistence.
abstract final class ParticipantBindingWire {
  static Map<String, Object?> encode(ParticipantBinding binding) {
    return switch (binding) {
      RosterLinkedBinding(:final rosterParticipantId) => {
          'kind': 'ROSTER_LINKED',
          'rosterParticipantId': rosterParticipantId,
        },
      TeamScopedNumberBinding(:final shirtNumber) => {
          'kind': 'TEAM_SCOPED_NUMBER',
          'shirtNumber': shirtNumber,
        },
      FreeformDescriptorBinding(:final descriptor) => {
          'kind': 'FREEFORM_DESCRIPTOR',
          'descriptor': descriptor,
        },
      IdentifiedOfficialBinding(:final displayName) => {
          'kind': 'IDENTIFIED_OFFICIAL',
          if (displayName != null) 'displayName': displayName,
        },
      SeniorCoachPresentBinding() => {'kind': 'SENIOR_COACH_PRESENT'},
    };
  }

  static ParticipantBinding decode(Map<String, Object?> json) {
    final kind = json['kind'];
    return switch (kind) {
      'ROSTER_LINKED' => RosterLinkedBinding(
          rosterParticipantId: _nonEmptyString(json['rosterParticipantId']),
        ),
      'TEAM_SCOPED_NUMBER' => TeamScopedNumberBinding(
          shirtNumber: _positiveInt(json['shirtNumber']),
        ),
      'FREEFORM_DESCRIPTOR' => FreeformDescriptorBinding(
          descriptor: _nonEmptyString(json['descriptor']),
        ),
      'IDENTIFIED_OFFICIAL' => IdentifiedOfficialBinding(
          displayName: json['displayName'] as String?,
        ),
      'SENIOR_COACH_PRESENT' => const SeniorCoachPresentBinding(),
      _ => throw FormatException('Unknown participant binding kind: $kind'),
    };
  }

  static String _nonEmptyString(Object? value) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Participant binding string is invalid');
    }
    return value;
  }

  static int _positiveInt(Object? value) {
    if (value is! int || value < 0) {
      throw FormatException('Participant binding shirt number is invalid');
    }
    return value;
  }
}

/// Team side plus binding evidence for validation and display.
final class ParticipantBindingContext {
  const ParticipantBindingContext({
    required this.teamSide,
    required this.binding,
  });

  final ParticipantTeamSide teamSide;
  final ParticipantBinding binding;

  @override
  bool operator ==(Object other) =>
      other is ParticipantBindingContext &&
      teamSide == other.teamSide &&
      binding == other.binding;

  @override
  int get hashCode => Object.hash(teamSide, binding);
}
