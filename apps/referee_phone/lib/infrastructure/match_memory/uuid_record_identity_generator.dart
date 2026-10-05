import 'package:forref_match_core/forref_match_core.dart';
import 'package:uuid/uuid.dart';

/// Stable random record identity using UUID v4.
final class UuidRecordIdentityGenerator implements RecordIdentityGenerator {
  const UuidRecordIdentityGenerator();

  @override
  String newRecordId() => const Uuid().v4();
}
