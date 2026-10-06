import 'dart:convert';

import 'package:forref_match_core/forref_match_core.dart';

/// Adapter-local storage encoding for one [MatchRecord].
///
/// ADAPTER-LOCAL STORAGE ENCODING. This JSON text is the SQLite row
/// representation used for local round-trip and duplicate/conflict checks.
/// It is not the frozen cross-device or network canonical wire format.
const adapterLocalStorageEncoding = 'adapter-local-v1';

const _structuredPayloadType = 'structured';
const _temporalTransitionType = 'v1-temporal-transition';
const _temporalCorrectionType = 'v1-temporal-correction';
const _correctionType = 'v1-correction';
const _legalSupersessionType = 'v1-legal-supersession';
const _goalType = 'v1-goal';
const _participantRegisteredType = 'v1-participant-registered';
const _participantBindingCorrectedType = 'v1-participant-binding-corrected';
const _participantIdentityReconciliationType =
    'v1-participant-identity-reconciliation';
const _yellowCardType = 'v1-yellow-card';

const _rootKeys = {
  'storageEncoding',
  'recordId',
  'matchId',
  'recordKind',
  'schemaVersion',
  'recordedAt',
  'originDeviceId',
  'originSequence',
  'temporalContext',
  'authorityContext',
  'relationships',
  'payload',
  'integrity',
};

Map<String, Object?> encodeMatchRecordForStorage(MatchRecord record) {
  return {
    'storageEncoding': adapterLocalStorageEncoding,
    'recordId': record.recordId,
    'matchId': record.matchId,
    'recordKind': record.recordKind.name,
    'schemaVersion': record.schemaVersion,
    'recordedAt': record.recordedAt.toUtc().toIso8601String(),
    'originDeviceId': record.originDeviceId,
    'originSequence': record.originSequence,
    'temporalContext': record.temporalContext == null
        ? null
        : {
            'evidenceIds': record.temporalContext!.evidenceIds,
            'domainClockPolicyVersion':
                record.temporalContext!.domainClockPolicyVersion,
            if (record.temporalContext!.explicitUncertainty)
              'explicitUncertainty': true,
          },
    'authorityContext': record.authorityContext == null
        ? null
        : {
            'scope': record.authorityContext!.scope is MainRefereeScope
                ? 'MAIN_REFEREE'
                : null,
            'principalId': record.authorityContext!.principal?.principalId,
            'activeCaptureDeviceId':
                record.authorityContext!.activeCaptureDevice?.deviceId,
            'generation': record.authorityContext!.generation?.value,
          },
    'relationships': [
      for (final link in record.relationships)
        {
          'kind': _relationshipKind(link),
          'targetRecordId': link.targetRecordId,
        },
    ],
    'payload': _encodePayload(record.payload),
    'integrity': {
      'evidenceRefs': record.integrity.evidenceRefs,
    },
  };
}

MatchRecord decodeMatchRecordFromStorage(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw FormatException('Stored Match Record is not an object');
  }
  final json = _stringKeyMap(decoded);
  _requireKnownKeys(json, _rootKeys, 'record');

  final storageEncoding = json['storageEncoding'];
  if (storageEncoding != null &&
      storageEncoding != adapterLocalStorageEncoding) {
    throw FormatException(
      'Unsupported adapter storage encoding: $storageEncoding',
    );
  }

  final payload = json['payload'];
  if (payload is! Map) {
    throw FormatException('Stored payload is missing');
  }
  final payloadMap = _stringKeyMap(payload);
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    throw FormatException('Stored schemaVersion is missing');
  }

  final integrity = json['integrity'];
  if (integrity is! Map) {
    throw FormatException('Stored integrity metadata is missing');
  }
  final integrityMap = _stringKeyMap(integrity);
  _requireKnownKeys(integrityMap, {'evidenceRefs'}, 'integrity');
  final evidenceRefs = integrityMap['evidenceRefs'];
  if (evidenceRefs is! List) {
    throw FormatException('Stored integrity refs are missing');
  }

  return MatchRecord(
    recordId: json['recordId'] as String,
    matchId: json['matchId'] as String,
    recordKind: _recordKind(json['recordKind'] as String),
    schemaVersion: schemaVersion,
    recordedAt: DateTime.parse(json['recordedAt'] as String).toUtc(),
    originDeviceId: json['originDeviceId'] as String,
    originSequence: json['originSequence'] as int,
    temporalContext: _temporal(json['temporalContext']),
    authorityContext: _authority(json['authorityContext']),
    relationships: _relationships(json['relationships']),
    payload: _decodePayload(
      payloadMap,
      schemaVersion: schemaVersion,
      storageEncoding: storageEncoding as String?,
    ),
    integrity: IntegrityMetadata(
      evidenceRefs: [for (final ref in evidenceRefs) ref as String],
    ),
  );
}

String encodeMatchRecordJson(MatchRecord record) {
  return jsonEncode(encodeMatchRecordForStorage(record));
}

Map<String, Object?> _encodePayload(MatchRecordPayload payload) {
  if (payload is StructuredPayload) {
    return {
      'type': _structuredPayloadType,
      'fields': payload.fields,
    };
  }
  if (payload is V1SemanticPayload) {
    return {
      'type': _v1PayloadType(payload),
      'semanticType': payload.semanticType.wireValue,
      if (payload is TemporalTransitionPayload && payload.period != null)
        'periodIndex': payload.period!.index,
      if (payload is GoalPayload) ...{
        'creditedSide': payload.creditedSide.wireValue,
        'captureIntentId': payload.captureIntentId,
      },
      if (payload is ParticipantRegisteredPayload) ...{
        'matchParticipantId': payload.matchParticipantId.value,
        'teamSide': payload.teamSide.wireValue,
        'binding': ParticipantBindingWire.encode(payload.binding),
        if (payload.initialStatus != null)
          'initialStatus': payload.initialStatus!.wireValue,
      },
      if (payload is ParticipantBindingCorrectionPayload) ...{
        'matchParticipantId': payload.matchParticipantId.value,
        'binding': ParticipantBindingWire.encode(payload.correctedBinding),
      },
      if (payload is ParticipantIdentityReconciliationPayload) ...{
        'fromParticipantId': payload.fromParticipantId.value,
        'toParticipantId': payload.toParticipantId.value,
      },
      if (payload is YellowCardPayload) ...{
        'participantRef': ParticipantRefWire.encode(payload.participantRef),
        'participantStatusAtDetermination':
            payload.participantStatusAtDetermination.wireValue,
        'disciplinaryAccountingScope':
            payload.disciplinaryAccountingScope.wireValue,
        'captureIntentId': payload.captureIntentId,
        if (payload.reason != null) 'reason': payload.reason,
      },
      if (payload.domainContractVersion != null)
        'domainContractVersion': payload.domainContractVersion!.value,
      if (payload.competitionRulesContext != null)
        'competitionRulesContext': _encodeCompetitionRules(
          payload.competitionRulesContext!,
        ),
    };
  }
  throw FormatException(
    'Unsupported payload type for storage encoding: ${payload.runtimeType}',
  );
}

String _v1PayloadType(V1SemanticPayload payload) {
  return switch (payload) {
    TemporalTransitionPayload() => _temporalTransitionType,
    TemporalCorrectionPayload() => _temporalCorrectionType,
    CorrectionPayload() => _correctionType,
    LegalSupersessionPayload() => _legalSupersessionType,
    GoalPayload() => _goalType,
    ParticipantRegisteredPayload() => _participantRegisteredType,
    ParticipantBindingCorrectionPayload() => _participantBindingCorrectedType,
    ParticipantIdentityReconciliationPayload() =>
      _participantIdentityReconciliationType,
    YellowCardPayload() => _yellowCardType,
  };
}

MatchRecordPayload _decodePayload(
  Map<String, Object?> payload, {
  required int schemaVersion,
  required String? storageEncoding,
}) {
  final type = payload['type'];
  if (type == _structuredPayloadType) {
    _requireKnownKeys(payload, {'type', 'fields'}, 'structured payload');
    final fields = payload['fields'];
    if (fields is! Map) {
      throw FormatException('Stored payload fields are missing');
    }
    return StructuredPayload(_deepNormalizeMap(fields));
  }

  if (type == _temporalTransitionType ||
      type == _temporalCorrectionType ||
      type == _correctionType ||
      type == _legalSupersessionType ||
      type == _goalType ||
      type == _participantRegisteredType ||
      type == _participantBindingCorrectedType ||
      type == _participantIdentityReconciliationType ||
      type == _yellowCardType) {
    if (storageEncoding != adapterLocalStorageEncoding) {
      throw FormatException(
        'Typed payload is missing adapter storage encoding',
      );
    }
    if (schemaVersion != 1) {
      throw FormatException(
        'Typed v1 payload cannot be decoded for schemaVersion $schemaVersion',
      );
    }
    _requireKnownKeys(
      payload,
      switch (type) {
        _goalType => {
            'type',
            'semanticType',
            'creditedSide',
            'captureIntentId',
            'domainContractVersion',
            'competitionRulesContext',
          },
        _participantRegisteredType => {
            'type',
            'semanticType',
            'matchParticipantId',
            'teamSide',
            'binding',
            'initialStatus',
            'domainContractVersion',
            'competitionRulesContext',
          },
        _participantBindingCorrectedType => {
            'type',
            'semanticType',
            'matchParticipantId',
            'binding',
            'domainContractVersion',
            'competitionRulesContext',
          },
        _participantIdentityReconciliationType => {
            'type',
            'semanticType',
            'fromParticipantId',
            'toParticipantId',
            'domainContractVersion',
            'competitionRulesContext',
          },
        _yellowCardType => {
            'type',
            'semanticType',
            'participantRef',
            'participantStatusAtDetermination',
            'disciplinaryAccountingScope',
            'captureIntentId',
            'reason',
            'domainContractVersion',
            'competitionRulesContext',
          },
        _ => {
            'type',
            'semanticType',
            'periodIndex',
            'domainContractVersion',
            'competitionRulesContext',
          },
      },
      'typed payload',
    );
    return _decodeV1Payload(payload, type as String);
  }

  throw FormatException('Unsupported stored payload type: $type');
}

V1SemanticPayload _decodeV1Payload(
  Map<String, Object?> payload,
  String type,
) {
  final rawType = payload['semanticType'];
  if (rawType is! String) {
    throw FormatException('Stored semanticType is missing');
  }
  final code = V1SemanticTypeCodeWire.parseWire(rawType);
  if (code == null) {
    throw FormatException('Unknown semantic type: $rawType');
  }

  final domain = _domainContract(payload['domainContractVersion']);
  final rules = _competitionRules(payload['competitionRulesContext']);

  return switch (type) {
    _temporalTransitionType =>
      _temporalTransition(payload, code, domain, rules),
    _temporalCorrectionType => _exactCode(
        code,
        V1SemanticTypeCode.temporalCorrection,
        () => TemporalCorrectionPayload(
          domainContractVersion: domain,
          competitionRulesContext: rules,
        ),
      ),
    _correctionType => _exactCode(
        code,
        V1SemanticTypeCode.correction,
        () => CorrectionPayload(
          domainContractVersion: domain,
          competitionRulesContext: rules,
        ),
      ),
    _legalSupersessionType => _exactCode(
        code,
        V1SemanticTypeCode.legalSupersession,
        () => LegalSupersessionPayload(
          domainContractVersion: domain,
          competitionRulesContext: rules,
        ),
      ),
    _goalType => _goalPayload(payload, code, domain, rules),
    _participantRegisteredType =>
      _participantRegisteredPayload(payload, code, domain, rules),
    _participantBindingCorrectedType =>
      _participantBindingCorrectedPayload(payload, code, domain, rules),
    _participantIdentityReconciliationType =>
      _participantIdentityReconciliationPayload(payload, code, domain, rules),
    _yellowCardType => _yellowCardPayload(payload, code, domain, rules),
    _ => throw FormatException('Unsupported stored payload type: $type'),
  };
}

YellowCardPayload _yellowCardPayload(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  if (code != V1SemanticTypeCode.yellowCard) {
    throw FormatException(
      'Payload semantic type ${code.wireValue} does not match YELLOW_CARD',
    );
  }
  final participantRefRaw = payload['participantRef'];
  if (participantRefRaw is! Map) {
    throw FormatException('Stored YELLOW_CARD participantRef is missing');
  }
  final statusRaw = payload['participantStatusAtDetermination'];
  if (statusRaw is! String) {
    throw FormatException(
      'Stored YELLOW_CARD participantStatusAtDetermination is missing',
    );
  }
  final status = ParticipantStatusAtDeterminationWire.parseWire(statusRaw);
  if (status == null) {
    throw FormatException(
      'Stored YELLOW_CARD participantStatusAtDetermination is invalid',
    );
  }
  final scopeRaw = payload['disciplinaryAccountingScope'];
  if (scopeRaw is! String) {
    throw FormatException(
      'Stored YELLOW_CARD disciplinaryAccountingScope is missing',
    );
  }
  final scope = DisciplinaryAccountingScopeWire.parseWire(scopeRaw);
  if (scope == null) {
    throw FormatException(
      'Stored YELLOW_CARD disciplinaryAccountingScope is invalid',
    );
  }
  final intent = payload['captureIntentId'];
  if (intent is! String || intent.isEmpty) {
    throw FormatException('Stored YELLOW_CARD captureIntentId is invalid');
  }
  return YellowCardPayload(
    participantRef: ParticipantRefWire.decode(_stringKeyMap(participantRefRaw)),
    participantStatusAtDetermination: status,
    disciplinaryAccountingScope: scope,
    captureIntentId: intent,
    reason: payload['reason'] as String?,
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

GoalPayload _goalPayload(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  if (code != V1SemanticTypeCode.goal) {
    throw FormatException(
      'Payload semantic type ${code.wireValue} does not match GOAL',
    );
  }
  final side = payload['creditedSide'];
  if (side is! String) {
    throw FormatException('Stored GOAL creditedSide is missing');
  }
  final creditedSide = CreditedSideWire.parseWire(side);
  if (creditedSide == null) {
    throw FormatException('Stored GOAL creditedSide is invalid');
  }
  final intent = payload['captureIntentId'];
  if (intent is! String || intent.isEmpty) {
    throw FormatException('Stored GOAL captureIntentId is invalid');
  }
  return GoalPayload(
    creditedSide: creditedSide,
    captureIntentId: intent,
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

ParticipantRegisteredPayload _participantRegisteredPayload(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  if (code != V1SemanticTypeCode.participantRegistered) {
    throw FormatException(
      'Payload semantic type ${code.wireValue} does not match PARTICIPANT_REGISTERED',
    );
  }
  final teamSide = ParticipantTeamSideWire.parseWire(
    _nonEmptyString(payload['teamSide']),
  );
  if (teamSide == null) {
    throw FormatException('Stored participant teamSide is invalid');
  }
  final bindingRaw = payload['binding'];
  if (bindingRaw is! Map) {
    throw FormatException('Stored participant binding is missing');
  }
  final statusRaw = payload['initialStatus'];
  return ParticipantRegisteredPayload(
    matchParticipantId: MatchParticipantId(
      _nonEmptyString(payload['matchParticipantId']),
    ),
    teamSide: teamSide,
    binding: ParticipantBindingWire.decode(_stringKeyMap(bindingRaw)),
    initialStatus: statusRaw == null
        ? null
        : ParticipantStatusAtDeterminationWire.parseWire(statusRaw as String),
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

ParticipantBindingCorrectionPayload _participantBindingCorrectedPayload(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  if (code != V1SemanticTypeCode.participantBindingCorrected) {
    throw FormatException(
      'Payload semantic type ${code.wireValue} does not match PARTICIPANT_BINDING_CORRECTED',
    );
  }
  final bindingRaw = payload['binding'];
  if (bindingRaw is! Map) {
    throw FormatException('Stored participant binding is missing');
  }
  return ParticipantBindingCorrectionPayload(
    matchParticipantId: MatchParticipantId(
      _nonEmptyString(payload['matchParticipantId']),
    ),
    correctedBinding: ParticipantBindingWire.decode(_stringKeyMap(bindingRaw)),
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

ParticipantIdentityReconciliationPayload
    _participantIdentityReconciliationPayload(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  if (code != V1SemanticTypeCode.participantIdentityReconciliation) {
    throw FormatException(
      'Payload semantic type ${code.wireValue} does not match PARTICIPANT_IDENTITY_RECONCILIATION',
    );
  }
  return ParticipantIdentityReconciliationPayload(
    fromParticipantId: MatchParticipantId(
      _nonEmptyString(payload['fromParticipantId']),
    ),
    toParticipantId: MatchParticipantId(
      _nonEmptyString(payload['toParticipantId']),
    ),
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

String _nonEmptyString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Stored string field is invalid');
  }
  return value;
}

TemporalTransitionPayload _temporalTransition(
  Map<String, Object?> payload,
  V1SemanticTypeCode code,
  DomainContractVersion? domain,
  CompetitionRulesContext? rules,
) {
  final isTransition = switch (code) {
    V1SemanticTypeCode.matchStarted ||
    V1SemanticTypeCode.periodStarted ||
    V1SemanticTypeCode.periodEnded ||
    V1SemanticTypeCode.temporarySuspensionStarted ||
    V1SemanticTypeCode.temporarySuspensionEnded ||
    V1SemanticTypeCode.matchAbandoned ||
    V1SemanticTypeCode.matchEnded ||
    V1SemanticTypeCode.refereeEnteredFieldForMatchStart ||
    V1SemanticTypeCode.refereeLeftFieldAfterMatch =>
      true,
    V1SemanticTypeCode.temporalCorrection ||
    V1SemanticTypeCode.correction ||
    V1SemanticTypeCode.legalSupersession ||
    V1SemanticTypeCode.goal ||
    V1SemanticTypeCode.participantRegistered ||
    V1SemanticTypeCode.participantBindingCorrected ||
    V1SemanticTypeCode.participantIdentityReconciliation ||
    V1SemanticTypeCode.yellowCard =>
      false,
  };
  if (!isTransition) {
    throw FormatException(
      'Payload type $_temporalTransitionType cannot carry ${code.wireValue}',
    );
  }
  final period = _periodIdentity(payload['periodIndex'], code);
  return TemporalTransitionPayload(
    semanticType: code,
    period: period,
    domainContractVersion: domain,
    competitionRulesContext: rules,
  );
}

PeriodIdentity? _periodIdentity(Object? value, V1SemanticTypeCode code) {
  final requiresPeriod = code == V1SemanticTypeCode.periodStarted ||
      code == V1SemanticTypeCode.periodEnded ||
      code == V1SemanticTypeCode.temporarySuspensionStarted ||
      code == V1SemanticTypeCode.temporarySuspensionEnded;
  final forbidsPeriod =
      code == V1SemanticTypeCode.refereeEnteredFieldForMatchStart ||
          code == V1SemanticTypeCode.refereeLeftFieldAfterMatch;
  if (forbidsPeriod && value != null) {
    throw FormatException('${code.wireValue} must not carry periodIndex');
  }
  if (value == null) {
    if (requiresPeriod) {
      throw FormatException('${code.wireValue} requires periodIndex');
    }
    return null;
  }
  if (!requiresPeriod) {
    throw FormatException(
      'periodIndex is only valid on PERIOD_STARTED, PERIOD_ENDED, TEMPORARY_SUSPENSION_STARTED, and TEMPORARY_SUSPENSION_ENDED',
    );
  }
  if (value is! int || value < 1) {
    throw FormatException('Stored periodIndex is invalid');
  }
  return PeriodIdentity(index: value);
}

T _exactCode<T>(
  V1SemanticTypeCode actual,
  V1SemanticTypeCode expected,
  T Function() build,
) {
  if (actual != expected) {
    throw FormatException(
      'Payload semantic type ${actual.wireValue} does not match ${expected.wireValue}',
    );
  }
  return build();
}

DomainContractVersion? _domainContract(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('Stored domainContractVersion is invalid');
  }
  return DomainContractVersion(value);
}

CompetitionRulesContext? _competitionRules(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Stored competitionRulesContext is invalid');
  }
  final json = _stringKeyMap(value);
  _requireKnownKeys(
    json,
    {
      'rulesetId',
      'additionalPlayingPhase',
      'penaltyShootOutAfterMatchEnd',
      'disciplinarySystem',
    },
    'competitionRulesContext',
  );
  final rulesetId = json['rulesetId'];
  if (rulesetId is! String || rulesetId.isEmpty) {
    throw FormatException('Stored competition rulesetId is invalid');
  }
  return CompetitionRulesContext(
    rulesetId: rulesetId,
    additionalPlayingPhase:
        _additionalPlayingPhase(json['additionalPlayingPhase']),
    penaltyShootOutAfterMatchEnd:
        _penaltyShootOutAfterMatchEnd(json['penaltyShootOutAfterMatchEnd']),
    disciplinarySystem: _disciplinarySystem(json['disciplinarySystem']),
  );
}

Map<String, Object?> _encodeCompetitionRules(CompetitionRulesContext rules) {
  return {
    'rulesetId': rules.rulesetId,
    if (rules.additionalPlayingPhase !=
        AdditionalPlayingPhaseDisposition.unresolved)
      'additionalPlayingPhase': rules.additionalPlayingPhase.wireValue,
    if (rules.penaltyShootOutAfterMatchEnd)
      'penaltyShootOutAfterMatchEnd': true,
    if (rules.disciplinarySystem != DisciplinarySystem.unresolved)
      'disciplinarySystem': rules.disciplinarySystem.wireValue,
  };
}

DisciplinarySystem _disciplinarySystem(Object? value) {
  if (value == null) return DisciplinarySystem.unresolved;
  if (value is! String) {
    throw FormatException('Stored disciplinarySystem is invalid');
  }
  final parsed = DisciplinarySystemWire.parseWire(value);
  if (parsed == null) {
    throw FormatException('Stored disciplinarySystem is invalid');
  }
  return parsed;
}

AdditionalPlayingPhaseDisposition _additionalPlayingPhase(Object? value) {
  if (value == null) return AdditionalPlayingPhaseDisposition.unresolved;
  if (value is! String) {
    throw FormatException('Stored additionalPlayingPhase is invalid');
  }
  final parsed = AdditionalPlayingPhaseDispositionWire.parseWire(value);
  if (parsed == null) {
    throw FormatException('Stored additionalPlayingPhase is invalid');
  }
  return parsed;
}

bool _penaltyShootOutAfterMatchEnd(Object? value) {
  if (value == null) return false;
  if (value is! bool) {
    throw FormatException('Stored penaltyShootOutAfterMatchEnd is invalid');
  }
  return value;
}

String _relationshipKind(RecordRelationship link) {
  return switch (link) {
    CausalDependency() => 'CAUSAL',
    CorrectionTarget() => 'CORRECTION',
    LegalSupersessionTarget() => 'SUPERSESSION',
    RelatesTo() => 'RELATES_TO',
  };
}

RecordKind _recordKind(String name) {
  for (final kind in RecordKind.values) {
    if (kind.name == name) return kind;
  }
  throw FormatException('Unknown record kind: $name');
}

TemporalContext? _temporal(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Stored temporal context is invalid');
  }
  final json = _stringKeyMap(value);
  _requireKnownKeys(
    json,
    {'evidenceIds', 'domainClockPolicyVersion', 'explicitUncertainty'},
    'temporalContext',
  );
  final evidenceIds = json['evidenceIds'];
  if (evidenceIds is! List) {
    throw FormatException('Stored temporal evidence ids are missing');
  }
  final uncertainty = json['explicitUncertainty'];
  if (uncertainty != null && uncertainty is! bool) {
    throw FormatException('Stored temporal explicitUncertainty is invalid');
  }
  return TemporalContext(
    evidenceIds: [for (final id in evidenceIds) id as String],
    domainClockPolicyVersion: json['domainClockPolicyVersion'] as String?,
    explicitUncertainty: uncertainty == true,
  );
}

AuthorityContext? _authority(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Stored authority context is invalid');
  }
  final json = _stringKeyMap(value);
  _requireKnownKeys(
    json,
    {'scope', 'principalId', 'activeCaptureDeviceId', 'generation'},
    'authorityContext',
  );
  final scopeName = json['scope'] as String?;
  final AuthorityScope? scope = switch (scopeName) {
    null => null,
    'MAIN_REFEREE' => const MainRefereeScope(),
    _ => throw FormatException('Unsupported authority scope: $scopeName'),
  };
  final principalId = json['principalId'] as String?;
  final deviceId = json['activeCaptureDeviceId'] as String?;
  final generation = json['generation'] as int?;
  return AuthorityContext(
    scope: scope,
    principal: principalId == null
        ? null
        : AuthorityPrincipal(principalId: principalId),
    activeCaptureDevice:
        deviceId == null ? null : ActiveCaptureDevice(deviceId: deviceId),
    generation:
        generation == null ? null : AuthorityGeneration(value: generation),
  );
}

List<RecordRelationship> _relationships(Object? value) {
  if (value is! List) {
    throw FormatException('Stored relationships are missing');
  }
  return [
    for (final item in value)
      if (item is Map)
        _relationship(_stringKeyMap(item))
      else
        throw FormatException('Stored relationship is invalid'),
  ];
}

RecordRelationship _relationship(Map<String, Object?> json) {
  _requireKnownKeys(json, {'kind', 'targetRecordId'}, 'relationship');
  final target = json['targetRecordId'] as String;
  return switch (json['kind'] as String) {
    'CAUSAL' => CausalDependency(targetRecordId: target),
    'CORRECTION' => CorrectionTarget(targetRecordId: target),
    'SUPERSESSION' => LegalSupersessionTarget(targetRecordId: target),
    'RELATES_TO' => RelatesTo(targetRecordId: target),
    final kind => throw FormatException('Unknown relationship kind: $kind'),
  };
}

void _requireKnownKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  String label,
) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw FormatException(
          'Unknown $label field cannot be reconstructed: $key');
    }
  }
}

Map<String, Object?> _stringKeyMap(Map<Object?, Object?> value) {
  return {
    for (final entry in value.entries) entry.key as String: entry.value,
  };
}

Map<String, Object?> _deepNormalizeMap(Map<Object?, Object?> source) {
  return {
    for (final entry in source.entries)
      entry.key as String: _deepNormalize(entry.value),
  };
}

Object? _deepNormalize(Object? value) {
  if (value is Map) return _deepNormalizeMap(value);
  if (value is List) {
    return [for (final item in value) _deepNormalize(item)];
  }
  return value;
}
