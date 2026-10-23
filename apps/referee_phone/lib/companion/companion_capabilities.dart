import 'companion_device.dart';

/// Unknown names are omitted. They do not become supported capabilities.
Set<CompanionCapability> capabilitiesFromNames(Iterable<String> names) {
  final parsed = <CompanionCapability>{};
  for (final name in names) {
    for (final capability in CompanionCapability.values) {
      if (capability.name == name) {
        parsed.add(capability);
      }
    }
  }
  return Set.unmodifiable(parsed);
}

bool capabilitySupported(Set<CompanionCapability> capabilities, String name) {
  final parsed = capabilitiesFromNames([name]);
  if (parsed.isEmpty) return false;
  return capabilities.contains(parsed.single);
}
