import '../match_record.dart';
import '../payload.dart';
import '../projection/projection_semantics_resolver.dart';
import 'match_record_semantic_type.dart';
import 'production_payload_contract.dart';
import 'schema_semantic_interpreter.dart';
import 'v1_schema_semantic_interpreter.dart';
import 'v1_semantic_payload.dart';

/// Production-facing typed semantic resolver.
///
/// Interprets committed records through explicit typed payload semantics and
/// version-aware interpreters. Never reads foundation/test payload keys and
/// never infers sporting meaning from [MatchRecord.recordKind] alone.
final class ProductionSemanticsResolver implements ProjectionSemanticsResolver {
  ProductionSemanticsResolver({
    Map<int, SchemaSemanticInterpreter>? interpretersBySchemaVersion,
  }) : _interpretersBySchemaVersion =
            interpretersBySchemaVersion ?? _defaultInterpreters;

  static final Map<int, SchemaSemanticInterpreter> _defaultInterpreters = {
    1: const V1SchemaSemanticInterpreter(),
  };

  final Map<int, SchemaSemanticInterpreter> _interpretersBySchemaVersion;

  @override
  SemanticProjectionContribution resolve(MatchRecord record) {
    if (!ProductionPayloadContract.registeredSchemaVersions
        .contains(record.schemaVersion)) {
      return _unsupported;
    }

    final interpreter = _interpretersBySchemaVersion[record.schemaVersion];
    if (interpreter == null) return _unsupported;

    final identity = _parseIdentity(record);
    if (identity == null) return _unsupported;

    final contribution = interpreter.interpret(
      record: record,
      identity: identity,
    );
    return contribution ?? _unsupported;
  }

  MatchRecordSemanticIdentity? _parseIdentity(MatchRecord record) {
    final payload = record.payload;
    if (payload is V1SemanticPayload) {
      return MatchRecordSemanticIdentity(
        schemaVersion: record.schemaVersion,
        code: payload.semanticType,
      );
    }
    if (payload is! StructuredPayload) return null;
    final rawType = payload.fields[ProductionPayloadContract.semanticType];
    if (rawType is! String) return null;

    final code = V1SemanticTypeCodeWire.parseWire(rawType);
    if (code == null) return null;

    return MatchRecordSemanticIdentity(
      schemaVersion: record.schemaVersion,
      code: code,
    );
  }

  static const _unsupported = SemanticProjectionContribution(
    status: SemanticSupportStatus.unsupported,
  );
}
