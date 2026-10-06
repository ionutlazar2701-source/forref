/// Separates in-match and penalty-shoot-out caution ledgers.
enum DisciplinaryAccountingScope {
  match,
  shootout,
  unresolved,
}

extension DisciplinaryAccountingScopeWire on DisciplinaryAccountingScope {
  String get wireValue => switch (this) {
        DisciplinaryAccountingScope.match => 'MATCH',
        DisciplinaryAccountingScope.shootout => 'SHOOTOUT',
        DisciplinaryAccountingScope.unresolved => 'UNRESOLVED',
      };

  static DisciplinaryAccountingScope? parseWire(String value) => switch (value) {
        'MATCH' => DisciplinaryAccountingScope.match,
        'SHOOTOUT' => DisciplinaryAccountingScope.shootout,
        'UNRESOLVED' => DisciplinaryAccountingScope.unresolved,
        _ => null,
      };
}
