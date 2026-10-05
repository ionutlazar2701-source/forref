import 'package:forref_match_core/forref_match_core.dart';

/// Rebuilds disposable match projection from committed Match Memory.
abstract interface class MatchProjectionReadPort {
  Future<MatchProjectionState> project(
    String matchId, {
    required int evaluatedAuthorityGeneration,
  });
}
