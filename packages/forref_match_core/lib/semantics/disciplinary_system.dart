/// Competition disciplinary system governing Yellow Card V1 semantics.
enum DisciplinarySystem {
  /// Standard IFAB caution semantics are supported.
  ordinaryIfab,

  /// Modified system (e.g. temporary dismissal). Ordinary Yellow Card V1 unsupported.
  temporaryDismissal,

  /// Disciplinary system not established sufficiently for authoritative capture.
  unresolved,
}

extension DisciplinarySystemWire on DisciplinarySystem {
  String get wireValue => switch (this) {
        DisciplinarySystem.ordinaryIfab => 'ORDINARY_IFAB',
        DisciplinarySystem.temporaryDismissal => 'TEMPORARY_DISMISSAL',
        DisciplinarySystem.unresolved => 'UNRESOLVED',
      };

  static DisciplinarySystem? parseWire(String value) => switch (value) {
        'ORDINARY_IFAB' => DisciplinarySystem.ordinaryIfab,
        'TEMPORARY_DISMISSAL' => DisciplinarySystem.temporaryDismissal,
        'UNRESOLVED' => DisciplinarySystem.unresolved,
        _ => null,
      };
}
