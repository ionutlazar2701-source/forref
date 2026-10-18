/// Release / success thresholds for Instrument A trials are not registered.
enum ThresholdRegistration {
  unregistered,
}

/// Placeholder registry: no numeric gates are defined in this harness.
class InstrumentAThresholds {
  const InstrumentAThresholds._();

  static const ThresholdRegistration registration =
      ThresholdRegistration.unregistered;

  static Map<String, Object?> toJson() => {
        'registration': registration.name,
        'note':
            'No release thresholds are defined; do not infer pass/fail rates.',
      };
}
