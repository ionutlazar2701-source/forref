import '../match_record.dart';
import '../projection/projection_semantics_resolver.dart';
import 'match_record_semantic_type.dart';

/// Version-aware interpreter: typed identity + historical record → projection contribution.
abstract interface class SchemaSemanticInterpreter {
  int get schemaVersion;

  SemanticProjectionContribution? interpret({
    required MatchRecord record,
    required MatchRecordSemanticIdentity identity,
  });
}
