import '../match_record.dart';
import '../participant/identity_confidence.dart';
import '../participant/match_participant_id.dart';
import '../participant/participant_binding.dart';
import '../participant/participant_ref.dart';
import '../participant/participant_status_at_determination.dart';
import '../participant/participant_team_side.dart';
import '../semantics/v1_semantic_payload.dart';
import 'temporal_match_projection.dart';

/// One participant identity rebuilt from committed Match Memory.
final class ProjectedParticipantIdentity {
  const ProjectedParticipantIdentity({
    required this.registeredId,
    required this.canonicalId,
    required this.teamSide,
    required this.binding,
    required this.confidence,
    this.initialStatus,
    this.registrationRecordId,
  });

  /// Original [MatchParticipantId] assigned at registration.
  final MatchParticipantId registeredId;

  /// Identity after explicit reconciliation chain.
  final MatchParticipantId canonicalId;
  final ParticipantTeamSide teamSide;
  final ParticipantBinding binding;
  final IdentityConfidence confidence;
  final ParticipantStatusAtDetermination? initialStatus;
  final String? registrationRecordId;

  ParticipantRef toRef() => ParticipantRef(
        matchParticipantId: canonicalId,
        teamSide: teamSide,
        binding: binding,
      );

  @override
  bool operator ==(Object other) {
    return other is ProjectedParticipantIdentity &&
        registeredId == other.registeredId &&
        canonicalId == other.canonicalId &&
        teamSide == other.teamSide &&
        binding == other.binding &&
        confidence == other.confidence &&
        initialStatus == other.initialStatus &&
        registrationRecordId == other.registrationRecordId;
  }

  @override
  int get hashCode => Object.hash(
        registeredId,
        canonicalId,
        teamSide,
        binding,
        confidence,
        initialStatus,
        registrationRecordId,
      );
}

/// Deterministic, disposable participant identity projection.
final class ParticipantIdentityProjection {
  const ParticipantIdentityProjection({
    required this.participantsByRegisteredId,
    required this.overallConfidence,
  });

  static const empty = ParticipantIdentityProjection(
    participantsByRegisteredId: {},
    overallConfidence: IdentityConfidence.resolved,
  );

  final Map<String, ProjectedParticipantIdentity> participantsByRegisteredId;
  final IdentityConfidence overallConfidence;

  ProjectedParticipantIdentity? operator [](MatchParticipantId id) =>
      participantsByRegisteredId[id.value];

  MatchParticipantId resolveCanonical(MatchParticipantId id) {
    final entry = participantsByRegisteredId[id.value];
    return entry?.canonicalId ?? id;
  }

  IdentityConfidence confidenceFor(MatchParticipantId id) {
    final entry = participantsByRegisteredId[id.value];
    if (entry != null) return entry.confidence;
    final canonical = resolveCanonical(id);
    return participantsByRegisteredId[canonical.value]?.confidence ??
        IdentityConfidence.provisional;
  }

  static ParticipantIdentityProjection derive({
    required List<MatchRecord> records,
  }) {
    final ordered = [...records]..sort(deterministicRecordOrder);
    final registrations = <String, _RegistrationState>{};
    final bindingOverrides = <String, ParticipantBinding>{};
    final reconciliations = <String, String>{};

    for (final record in ordered) {
      final payload = record.payload;
      switch (payload) {
        case ParticipantRegisteredPayload():
          registrations[payload.matchParticipantId.value] = _RegistrationState(
            recordId: record.recordId,
            teamSide: payload.teamSide,
            binding: payload.binding,
            initialStatus: payload.initialStatus,
          );
        case ParticipantBindingCorrectionPayload():
          bindingOverrides[payload.matchParticipantId.value] =
              payload.correctedBinding;
        case ParticipantIdentityReconciliationPayload():
          reconciliations[payload.fromParticipantId.value] =
              payload.toParticipantId.value;
        default:
          break;
      }
    }

    final canonicalResolver = _CanonicalResolver(reconciliations);
    final participants = <String, ProjectedParticipantIdentity>{};

    for (final entry in registrations.entries) {
      final registeredId = MatchParticipantId(entry.key);
      final canonical = canonicalResolver.resolve(registeredId);
      final registration = entry.value;
      final binding =
          bindingOverrides[entry.key] ?? registration.binding;
      participants[entry.key] = ProjectedParticipantIdentity(
        registeredId: registeredId,
        canonicalId: canonical.id,
        teamSide: registration.teamSide,
        binding: binding,
        initialStatus: registration.initialStatus,
        registrationRecordId: registration.recordId,
        confidence: IdentityConfidence.resolved,
      );
    }

    _applyConfidence(participants, canonicalResolver);
    final overall = _overallConfidence(participants.values);

    return ParticipantIdentityProjection(
      participantsByRegisteredId: participants,
      overallConfidence: overall,
    );
  }
}

final class _RegistrationState {
  const _RegistrationState({
    required this.recordId,
    required this.teamSide,
    required this.binding,
    this.initialStatus,
  });

  final String recordId;
  final ParticipantTeamSide teamSide;
  final ParticipantBinding binding;
  final ParticipantStatusAtDetermination? initialStatus;
}

final class _CanonicalResolution {
  const _CanonicalResolution(this.id, this.conflicted);

  final MatchParticipantId id;
  final bool conflicted;
}

final class _CanonicalResolver {
  _CanonicalResolver(this._links);

  final Map<String, String> _links;

  _CanonicalResolution resolve(MatchParticipantId id) {
    final visited = <String>{};
    var current = id.value;
    while (_links.containsKey(current)) {
      if (visited.contains(current)) {
        return _CanonicalResolution(id, true);
      }
      visited.add(current);
      current = _links[current]!;
    }
    return _CanonicalResolution(MatchParticipantId(current), false);
  }
}

void _applyConfidence(
  Map<String, ProjectedParticipantIdentity> participants,
  _CanonicalResolver resolver,
) {
  final numberIndex = <String, List<String>>{};
  for (final entry in participants.entries) {
    final binding = entry.value.binding;
    if (binding is TeamScopedNumberBinding) {
      final key = '${entry.value.teamSide.wireValue}:${binding.shirtNumber}';
      numberIndex.putIfAbsent(key, () => []).add(entry.key);
    }
  }

  for (final entry in participants.entries.toList()) {
    final resolution = resolver.resolve(entry.value.registeredId);
    var confidence = IdentityConfidence.resolved;

    if (resolution.conflicted) {
      confidence = IdentityConfidence.conflicted;
    } else if (entry.value.binding is FreeformDescriptorBinding) {
      confidence = IdentityConfidence.provisional;
    } else if (entry.value.binding is TeamScopedNumberBinding) {
      final numberBinding = entry.value.binding as TeamScopedNumberBinding;
      final key =
          '${entry.value.teamSide.wireValue}:${numberBinding.shirtNumber}';
      final sameNumber = numberIndex[key] ?? const [];
      final distinctCanonical = {
        for (final id in sameNumber)
          resolver.resolve(MatchParticipantId(id)).id.value,
      };
      if (distinctCanonical.length > 1) {
        confidence = IdentityConfidence.ambiguous;
      }
    }

    participants[entry.key] = ProjectedParticipantIdentity(
      registeredId: entry.value.registeredId,
      canonicalId: resolution.id,
      teamSide: entry.value.teamSide,
      binding: entry.value.binding,
      initialStatus: entry.value.initialStatus,
      registrationRecordId: entry.value.registrationRecordId,
      confidence: confidence,
    );
  }
}

IdentityConfidence _overallConfidence(
  Iterable<ProjectedParticipantIdentity> participants,
) {
  var overall = IdentityConfidence.resolved;
  for (final participant in participants) {
    overall = _maxConfidence(overall, participant.confidence);
  }
  return overall;
}

IdentityConfidence _maxConfidence(
  IdentityConfidence left,
  IdentityConfidence right,
) {
  const order = [
    IdentityConfidence.resolved,
    IdentityConfidence.provisional,
    IdentityConfidence.ambiguous,
    IdentityConfidence.conflicted,
  ];
  return order.indexOf(left) >= order.indexOf(right) ? left : right;
}
