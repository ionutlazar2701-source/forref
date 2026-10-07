import 'dart:convert';
import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';

/// Non-authoritative UI recovery state for one in-progress Yellow interaction.
///
/// Match Memory remains the only authority. This state only preserves the
/// selected participant and capture intent so process/lifecycle recovery can
/// reconcile before another commit is offered.
enum YellowCardDraftPhase {
  selecting,
  checking,
  retryable,
  secondCautionAcknowledgement,
}

final class PhoneYellowCardDraft {
  const PhoneYellowCardDraft({
    required this.matchId,
    required this.phase,
    this.participantId,
    this.participantStatus,
    this.captureIntentId,
    this.committedRecordId,
    this.priorCautionExisted = false,
  });

  final String matchId;
  final YellowCardDraftPhase phase;
  final MatchParticipantId? participantId;
  final ParticipantStatusAtDetermination? participantStatus;
  final String? captureIntentId;
  final String? committedRecordId;
  final bool priorCautionExisted;

  PhoneYellowCardDraft copyWith({
    YellowCardDraftPhase? phase,
    MatchParticipantId? participantId,
    ParticipantStatusAtDetermination? participantStatus,
    String? captureIntentId,
    String? committedRecordId,
    bool? priorCautionExisted,
  }) {
    return PhoneYellowCardDraft(
      matchId: matchId,
      phase: phase ?? this.phase,
      participantId: participantId ?? this.participantId,
      participantStatus: participantStatus ?? this.participantStatus,
      captureIntentId: captureIntentId ?? this.captureIntentId,
      committedRecordId: committedRecordId ?? this.committedRecordId,
      priorCautionExisted: priorCautionExisted ?? this.priorCautionExisted,
    );
  }
}

/// Small file-backed store for parked Yellow capture UI state.
///
/// The file is not Match Memory and never makes a capture Saved. Entries are
/// keyed by match so one match draft cannot silently overwrite another.
final class PhoneYellowCardDraftStore {
  PhoneYellowCardDraftStore(Directory storageRoot)
      : _file =
            File('${storageRoot.path}/forref_yellow_card_capture_drafts.json');

  final File _file;

  Future<PhoneYellowCardDraft?> load(String matchId) async {
    final all = await _readAll();
    final raw = all[matchId];
    return raw == null ? null : _decode(matchId, raw);
  }

  Future<void> save(PhoneYellowCardDraft draft) async {
    final all = await _readAll();
    all[draft.matchId] = _encode(draft);
    await _writeAll(all);
  }

  Future<void> delete(String matchId) async {
    final all = await _readAll();
    if (all.remove(matchId) == null) return;
    await _writeAll(all);
  }

  Future<Map<String, Map<String, Object?>>> _readAll() async {
    if (!_file.existsSync()) return {};
    final raw = await _file.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Yellow capture draft store is invalid');
    }
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: {
            for (final value in (entry.value as Map).entries)
              value.key as String: value.value,
          },
    };
  }

  Future<void> _writeAll(
    Map<String, Map<String, Object?>> all,
  ) async {
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    await _file.writeAsString(jsonEncode(all), flush: true);
  }

  Map<String, Object?> _encode(PhoneYellowCardDraft draft) => {
        'phase': draft.phase.name,
        if (draft.participantId != null)
          'participantId': draft.participantId!.value,
        if (draft.participantStatus != null)
          'participantStatus': draft.participantStatus!.wireValue,
        if (draft.captureIntentId != null)
          'captureIntentId': draft.captureIntentId,
        if (draft.committedRecordId != null)
          'committedRecordId': draft.committedRecordId,
        if (draft.priorCautionExisted) 'priorCautionExisted': true,
      };

  PhoneYellowCardDraft _decode(
    String matchId,
    Map<String, Object?> raw,
  ) {
    final phaseName = raw['phase'];
    final phase = YellowCardDraftPhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    if (phase == null) {
      throw const FormatException('Yellow capture draft phase is invalid');
    }
    final participantId = raw['participantId'];
    final participantStatus = raw['participantStatus'];
    final captureIntentId = raw['captureIntentId'];
    final committedRecordId = raw['committedRecordId'];
    return PhoneYellowCardDraft(
      matchId: matchId,
      phase: phase,
      participantId: participantId is String && participantId.isNotEmpty
          ? MatchParticipantId(participantId)
          : null,
      participantStatus: participantStatus is String
          ? ParticipantStatusAtDeterminationWire.parseWire(participantStatus)
          : null,
      captureIntentId: captureIntentId is String && captureIntentId.isNotEmpty
          ? captureIntentId
          : null,
      committedRecordId:
          committedRecordId is String && committedRecordId.isNotEmpty
              ? committedRecordId
              : null,
      priorCautionExisted: raw['priorCautionExisted'] == true,
    );
  }
}
