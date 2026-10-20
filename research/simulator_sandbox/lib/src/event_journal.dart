/// Observer of a sandbox capture. This is not Match Memory.
enum JournalEventKind {
  intentReceived,
  commandFrozen,
  captureAdmissionStarted,
  commitRequested,
  commitReturned,
  recordReadBack,
  projectionRebuilt,
  presentationUpdated,
}

final class JournalEntry {
  const JournalEntry({
    required this.sequence,
    required this.kind,
    required this.detail,
  });

  final int sequence;
  final JournalEventKind kind;
  final String detail;
}

/// In-memory observation log. Deleting it does not delete Match Records.
final class EventJournal {
  final List<JournalEntry> _entries = [];
  JournalEventKind? failOn;

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  void observe(JournalEventKind kind, String detail) {
    if (failOn == kind) {
      failOn = null;
      throw StateError('journal failed on ${kind.name}');
    }
    _entries.add(
      JournalEntry(
        sequence: _entries.length + 1,
        kind: kind,
        detail: detail,
      ),
    );
  }

  void clear() {
    _entries.clear();
  }
}
