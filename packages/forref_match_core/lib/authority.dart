/// Sporting authority scope. Sealed for future extension; V1 exposes [MainRefereeScope] only.
sealed class AuthorityScope {
  const AuthorityScope();
}

/// V1 capture scope: main referee (`MAIN_REFEREE`).
final class MainRefereeScope extends AuthorityScope {
  const MainRefereeScope();
}

/// V1 domain constant for the sole usable authority scope.
const AuthorityScope v1AuthorityScope = MainRefereeScope();

/// Who exercised authority when the record was captured.
final class AuthorityPrincipal {
  const AuthorityPrincipal({required this.principalId});

  final String principalId;
}

/// Device that held active capture authority at record time.
final class ActiveCaptureDevice {
  const ActiveCaptureDevice({required this.deviceId});

  final String deviceId;
}

/// Monotonic generation counter for a given [AuthorityScope].
final class AuthorityGeneration {
  const AuthorityGeneration({required this.value});

  final int value;
}

/// Optional authority envelope on a Match Record.
final class AuthorityContext {
  const AuthorityContext({
    this.scope,
    this.principal,
    this.activeCaptureDevice,
    this.generation,
  });

  final AuthorityScope? scope;
  final AuthorityPrincipal? principal;
  final ActiveCaptureDevice? activeCaptureDevice;
  final AuthorityGeneration? generation;
}
