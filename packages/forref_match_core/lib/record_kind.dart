/// Authoritative Match Record kind. Committed semantics are fixed by kind.
enum RecordKind {
  occurrence,
  humanDetermination,
  action,
  temporalFact,
  correction,
  legalSupersession,
}
