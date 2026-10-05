/// Produces stable random [MatchRecord.recordId] values.
///
/// Must not derive identity from timestamps or origin sequence.
abstract interface class RecordIdentityGenerator {
  String newRecordId();
}
