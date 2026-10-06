/// FORREF Match Core v1 foundation — immutable records and pure ports.
library;

export 'capture/authoritative_record_builder.dart';
export 'capture/authoritative_record_commit_request.dart';
export 'capture/capture_context.dart';
export 'capture/record_identity_generator.dart';
export 'authority.dart';
export 'integrity.dart';
export 'match_record.dart';
export 'payload.dart';
export 'ports.dart';
export 'projection/deterministic_match_projector.dart';
export 'projection/match_projection_state.dart';
export 'projection/foundation_payload_semantics_resolver.dart';
export 'projection/projection_context.dart';
export 'projection/projection_semantics_resolver.dart';
export 'projection/projection_trust.dart';
export 'projection/temporal_match_projection.dart';
export 'projection/active_period_elapsed.dart';
export 'projection/goal_match_projection.dart';
export 'projection/normal_match_end_eligibility.dart';
export 'projection/participant_identity_projection.dart';
export 'projection/disciplinary_authority_projection.dart';
export 'participant/disciplinary_accounting_scope.dart';
export 'participant/identity_confidence.dart';
export 'participant/match_participant_id.dart';
export 'participant/participant_binding.dart';
export 'participant/participant_ref.dart';
export 'participant/participant_status_at_determination.dart';
export 'participant/participant_team_side.dart';
export 'semantics/additional_playing_phase_policy.dart';
export 'semantics/match_record_semantic_type.dart';
export 'semantics/production_payload_contract.dart';
export 'semantics/v1_semantic_contract.dart';
export 'semantics/v1_semantic_payload.dart';
export 'semantics/yellow_card_semantic.dart';
export 'semantics/disciplinary_system.dart';
export 'semantics/yellow_card_disciplinary_system_support.dart';
export 'semantics/production_semantics_resolver.dart';
export 'semantics/schema_semantic_interpreter.dart';
export 'semantics/v1_schema_semantic_interpreter.dart';
export 'record_kind.dart';
export 'reference/reference_match_memory.dart';
export 'relationships.dart';
export 'temporal.dart';

/// Foundation package marker for dependency and version checks.
const forrefMatchCoreFoundationVersion = '0.1.0';
