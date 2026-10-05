import 'package:forref_match_core/forref_match_core.dart';

/// Authoritative phone-side commit boundary for one immutable [MatchRecord].
///
/// Success means [DurableCommitSuccess] only. No Saved acknowledgement before
/// durable commit completes.
abstract interface class MatchCommitPort {
  Future<DurableCommitResult> commit(MatchRecord record);
}
