import 'active_period_elapsed.dart';
import 'projection_trust.dart';

/// Display admission for an existing [ActivePeriodElapsedProjection].
///
/// This reads no clock and writes no record.
/// [ActivePeriodElapsedProjection.periodEnded] and the 45:00 display mark
/// are not inputs. A missing elapsed value stays absent.
///
/// Exact admission requires certified trusted exact continuity. Bounded
/// admission accepts trusted or incomplete evidence and does not require
/// certification. An uncertified exact sample stays unresolved.
sealed class TemporalDisplayAdmission {
  const TemporalDisplayAdmission();

  /// Returns exact, bounded, or unresolved. Unresolved carries no [Duration].
  static TemporalDisplayAdmission admit(ActivePeriodElapsedProjection projection) {
    final exact = _exactElapsed(projection);
    if (exact != null) {
      return ExactElapsedAdmission(exact);
    }
    final bounds = _boundedRange(projection);
    if (bounds != null) {
      return BoundedElapsedAdmission(lower: bounds.$1, upper: bounds.$2);
    }
    return const UnresolvedElapsedAdmission();
  }
}

/// Certified exact elapsed. Not a range and not a period-end fact.
final class ExactElapsedAdmission extends TemporalDisplayAdmission {
  const ExactElapsedAdmission(this.elapsed);

  final Duration elapsed;

  @override
  bool operator ==(Object other) =>
      other is ExactElapsedAdmission && elapsed == other.elapsed;

  @override
  int get hashCode => Object.hash(TemporalDisplayAdmission, elapsed);
}

/// Inclusive elapsed range. Not an exact reading.
final class BoundedElapsedAdmission extends TemporalDisplayAdmission {
  const BoundedElapsedAdmission({
    required this.lower,
    required this.upper,
  });

  final Duration lower;
  final Duration upper;

  @override
  bool operator ==(Object other) =>
      other is BoundedElapsedAdmission &&
      lower == other.lower &&
      upper == other.upper;

  @override
  int get hashCode => Object.hash(TemporalDisplayAdmission, lower, upper);
}

/// No digits. Missing evidence is not [Duration.zero].
final class UnresolvedElapsedAdmission extends TemporalDisplayAdmission {
  const UnresolvedElapsedAdmission();

  @override
  bool operator ==(Object other) => other is UnresolvedElapsedAdmission;

  @override
  int get hashCode => Object.hash(UnresolvedElapsedAdmission, 0);
}

Duration? _exactElapsed(ActivePeriodElapsedProjection projection) {
  final elapsed = projection.exactElapsed;
  if (projection.continuity != TemporalContinuityStatus.exactContinuity ||
      elapsed == null ||
      projection.temporalTrust != ProjectionTrust.trusted ||
      !projection.precisionSafeToShow ||
      !projection.certified) {
    return null;
  }
  return elapsed;
}

(Duration, Duration)? _boundedRange(ActivePeriodElapsedProjection projection) {
  final lower = projection.elapsedLowerBound;
  final upper = projection.elapsedUpperBound;
  final trust = projection.temporalTrust;
  if (projection.continuity != TemporalContinuityStatus.boundedContinuity ||
      lower == null ||
      upper == null ||
      lower > upper ||
      (trust != ProjectionTrust.trusted && trust != ProjectionTrust.incomplete) ||
      !projection.precisionSafeToShow) {
    return null;
  }
  return (lower, upper);
}
