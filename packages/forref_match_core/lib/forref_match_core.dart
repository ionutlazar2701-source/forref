/// FORREF Match Core v1 foundation — immutable records and pure ports.
library;

export 'capture/authoritative_record_builder.dart';
export 'capture/authoritative_record_commit_request.dart';
export 'capture/capture_context.dart';
export 'capture/record_identity_generator.dart';
export 'authority.dart';
export 'authority_root.dart';
export 'capture/capture_intent.dart';
export 'match_authority_mode.dart';
export 'match_team.dart';
export 'integrity.dart';
export 'match_record.dart';
export 'payload.dart';
export 'ports.dart';
export 'projection/deterministic_match_projector.dart';
export 'projection/effective_goal_resolver.dart';
export 'projection/match_projection_state.dart';
export 'projection/score_completeness_proof.dart';
export 'projection/score_projection.dart';
export 'projection/foundation_payload_semantics_resolver.dart';
export 'projection/projection_context.dart';
export 'projection/projection_semantics_resolver.dart';
export 'projection/projection_trust.dart';
export 'projection/temporal_match_projection.dart';
export 'projection/active_period_elapsed.dart';
export 'projection/normal_match_end_eligibility.dart';
export 'semantics/additional_playing_phase_policy.dart';
export 'semantics/match_record_semantic_type.dart';
export 'semantics/production_payload_contract.dart';
export 'semantics/v1_semantic_contract.dart';
export 'semantics/v1_semantic_payload.dart';
export 'semantics/production_semantics_resolver.dart';
export 'semantics/schema_semantic_interpreter.dart';
export 'semantics/v1_schema_semantic_interpreter.dart';
export 'record_kind.dart';
export 'reference/reference_match_memory.dart';
export 'relationships.dart';
export 'temporal.dart';

/// Foundation package marker for dependency and version checks.
const forrefMatchCoreFoundationVersion = '0.1.0';
