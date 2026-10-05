import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/infrastructure/competition_rules/match_competition_rules_store.dart';
import 'package:referee_phone/infrastructure/competition_rules/phone_match_capture_context.dart';
import 'package:referee_phone/infrastructure/identity/phone_capture_identity.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';
import 'package:referee_phone/infrastructure/match_memory/match_application_composition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageRoot = await getApplicationSupportDirectory();
  final composition = await MatchApplicationComposition.open(
    storageRoot: storageRoot,
  );
  final identity = await PhoneCaptureIdentityStore(storageRoot).loadOrCreate();
  final rulesStore = MatchCompetitionRulesStore(storageRoot);
  final matchCaptureContext = PhoneMatchCaptureContext(
    identity: identity,
    rulesStore: rulesStore,
  );
  final temporalEvidence = PhoneTemporalEvidenceStore(storageRoot: storageRoot);
  runApp(
    RefereeApp(
      database: LocalMatchDatabase(),
      matchApplication: composition.boundary,
      captureIdentity: identity,
      matchCaptureContext: matchCaptureContext,
      temporalEvidence: temporalEvidence,
    ),
  );
}
