import '../authority.dart';
import '../semantics/v1_semantic_payload.dart';

/// Explicit capture authority and identity context for one authoritative record.
///
/// V1 scope is [MainRefereeScope] only. Authority is never inferred from UI
/// labels, crew names, device type, or legacy Match aggregates.
final class CaptureContext {
  const CaptureContext({
    required this.matchId,
    required this.originDeviceId,
    required this.authorityScope,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
    required this.projectionAuthorityGeneration,
    this.activeCaptureDeviceId,
    this.domainContractVersion,
    this.competitionRulesContext,
    this.schemaVersion = 1,
  }) : assert(authorityGeneration >= 1),
       assert(projectionAuthorityGeneration >= 1);

  final String matchId;
  final String originDeviceId;
  final AuthorityScope authorityScope;
  final String authorityPrincipalId;
  final int authorityGeneration;

  /// Generation boundary supplied to deterministic projection for this match.
  final int projectionAuthorityGeneration;
  final String? activeCaptureDeviceId;
  final DomainContractVersion? domainContractVersion;
  final CompetitionRulesContext? competitionRulesContext;
  final int schemaVersion;
}
