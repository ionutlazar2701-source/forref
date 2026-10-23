import 'dart:io';

/// Refuses a sandbox database path that is not a single simulator file.
final class SandboxPathRejected implements Exception {
  SandboxPathRejected(this.message);

  final String message;

  @override
  String toString() => 'SandboxPathRejected: $message';
}

/// `<simulator-root>/forref-simulator/<session-id>/match-memory.sqlite`
final class SandboxDatabasePath {
  const SandboxDatabasePath._(this.file, this.sessionId);

  final File file;
  final String sessionId;

  static final RegExp _session = RegExp(r'^[a-z0-9][a-z0-9-]{7,63}$');

  static SandboxDatabasePath resolve({
    required Directory simulatorRoot,
    required String sessionId,
  }) {
    if (!simulatorRoot.isAbsolute) {
      throw SandboxPathRejected('simulator root must be absolute');
    }
    if (sessionId.contains('..') ||
        sessionId.contains('/') ||
        sessionId.contains('\\') ||
        sessionId.contains(':')) {
      throw SandboxPathRejected('session id is not a single path segment');
    }
    if (!_session.hasMatch(sessionId)) {
      throw SandboxPathRejected('session id is not a synthetic sandbox id');
    }
    final root = simulatorRoot.absolute.path;
    final separator = Platform.pathSeparator;
    final directory = '$root${separator}forref-simulator$separator$sessionId';
    final path = '$directory${separator}match-memory.sqlite';
    if (path.contains(':memory:') || path.endsWith('$separator:memory:')) {
      throw SandboxPathRejected('an in-memory database is refused');
    }
    final prefix = root.endsWith(separator) ? root : '$root$separator';
    final marker = '$separator'
        'forref-simulator'
        '$separator'
        '$sessionId'
        '$separator';
    if (!path.startsWith(prefix) || !path.contains(marker)) {
      throw SandboxPathRejected('resolved path escaped the simulator root');
    }
    return SandboxDatabasePath._(File(path), sessionId);
  }

  void ensureParent() {
    file.parent.createSync(recursive: true);
  }
}
