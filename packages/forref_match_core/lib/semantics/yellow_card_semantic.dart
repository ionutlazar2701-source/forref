/// Frozen canonical meaning for [V1SemanticTypeCode.yellowCard].
///
/// YELLOW_CARD means the referee has authoritatively **administered** a caution
/// to the identified participant within an applicable ordinary IFAB caution scope.
///
/// It does NOT mean:
/// - decision to caution
/// - intention to caution
/// - pending caution
/// - misconduct observation
/// - physical card object
/// - automatic second-yellow consequence
abstract final class YellowCardSemantic {
  static const canonicalMeaning =
      'YELLOW_CARD means the referee has authoritatively administered a '
      'caution to the identified participant within an applicable ordinary '
      'IFAB caution scope.';
}
