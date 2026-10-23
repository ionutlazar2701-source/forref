/// Outcome of geometry consistency checking. Never implies hardware certification.
enum GeometryCheckResult {
  /// No operator-supplied measured profiles in the matrix.
  deviceMatrixRequired,

  /// Declared regions fail internal consistency rules.
  geometryInconsistent,

  /// Geometry is internally consistent; physical gate may proceed locally.
  readyForPhysicalGate,
}
