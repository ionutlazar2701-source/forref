/// Field-level evidence for device facts.
///
/// Unknown is a status. It is not a stored zero and it is not known-none.
enum FactStatus { known, unknown, derived }

final class EvidenceFact<T> {
  const EvidenceFact.unknown({
    this.sourceIds = const [],
    this.uncertainty,
  }) : status = FactStatus.unknown,
       value = null,
       derivation = null;

  const EvidenceFact.known({
    required T this.value,
    required this.sourceIds,
    this.uncertainty,
  }) : status = FactStatus.known,
       derivation = null;

  const EvidenceFact.derived({
    required T this.value,
    required this.sourceIds,
    required this.derivation,
    this.uncertainty,
  }) : status = FactStatus.derived;

  final FactStatus status;
  final T? value;
  final List<String> sourceIds;
  final String? derivation;
  final String? uncertainty;

  bool get isUnknown => status == FactStatus.unknown;

  bool get hasValue => status != FactStatus.unknown && value != null;
}

enum ControlAvailability { supported, unsupported, unknown, systemReserved }

/// A hardware control claim.
///
/// [appMaySimulate] is true only when [availability] is supported.
/// Supported does not require simulation. Unknown is not unsupported.
final class ControlFact {
  const ControlFact({
    required this.availability,
    required this.sourceIds,
    required this.appMaySimulate,
    this.uncertainty,
    this.count,
  });

  final ControlAvailability availability;
  final List<String> sourceIds;
  final bool appMaySimulate;
  final String? uncertainty;
  final EvidenceFact<int>? count;

  bool get isSupported => availability == ControlAvailability.supported;
}
