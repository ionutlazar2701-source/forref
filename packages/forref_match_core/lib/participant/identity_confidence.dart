/// Derived projection trust for one participant identity.
///
/// Never stored as mutable authoritative state.
enum IdentityConfidence {
  resolved,
  provisional,
  ambiguous,
  conflicted,
}
