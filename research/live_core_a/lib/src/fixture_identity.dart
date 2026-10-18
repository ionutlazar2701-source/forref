/// Opaque fixture / team identifiers for research stimuli (not production IDs).
extension type OpaqueTeamId(String value) {
  Map<String, Object?> toJson() => {'value': value};

  static OpaqueTeamId fromJson(Map<String, Object?> json) {
    return OpaqueTeamId(json['value']! as String);
  }
}

extension type OpaqueFixtureId(String value) {
  Map<String, Object?> toJson() => {'value': value};

  static OpaqueFixtureId fromJson(Map<String, Object?> json) {
    return OpaqueFixtureId(json['value']! as String);
  }
}
