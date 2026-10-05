import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';

/// Combines installation identity with persisted match competition rules.
final class PhoneMatchCaptureContext {
  const PhoneMatchCaptureContext({
    required this.identity,
    required this.rulesStore,
  });

  final PhoneCaptureIdentity identity;
  final MatchCompetitionRulesStore rulesStore;

  Future<CaptureContext> captureContextFor(String matchId) async {
    final rules = await rulesStore.loadForMatch(matchId);
    return identity.contextFor(
      matchId,
      competitionRulesContext: rules,
    );
  }
}

/// Whether normal match ending is currently eligible for [matchId].
Future<NormalMatchEndEligibility> assessStoredNormalMatchEndEligibility({
  required PhoneMatchCaptureContext capture,
  required String matchId,
  required List<MatchRecord> records,
}) async {
  final rules = await capture.rulesStore.loadForMatch(matchId);
  return assessNormalMatchEnd(
    records: records,
    disposition: resolveAdditionalPlayingPhase(rules),
  );
}
