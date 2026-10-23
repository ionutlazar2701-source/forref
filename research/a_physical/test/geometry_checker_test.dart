import 'package:a_physical/a_physical.dart';
import 'package:test/test.dart';

WatchGeometryProfile _consistentMeasuredProfile({
  List<HitRegion>? regions,
  double gap = 4,
  double clearance = 2,
  double viewport = 200,
}) {
  return WatchGeometryProfile(
    deviceLabel: 'lab-fixture',
    status: WatchProfileStatus.uncertifiedCandidate,
    operatorSuppliedMeasurement: true,
    viewportWidth: viewport,
    viewportHeight: viewport,
    interRegionGap: gap,
    edgeClearance: clearance,
    regions: regions ??
        [
          HitRegion(
            id: CentralInstrumentRegionIds.timePhase,
            x: 10,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.score,
            x: 60,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.capture,
            x: 10,
            y: 50,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.cautions,
            x: 60,
            y: 50,
            width: 40,
            height: 30,
          ),
        ],
  );
}

void main() {
  const checker = WatchHitGeometryChecker();

  group('WatchHitGeometryChecker', () {
    test('empty measured matrix yields deviceMatrixRequired', () {
      expect(
        checker.checkMeasuredMatrix([]),
        GeometryCheckResult.deviceMatrixRequired,
      );
    });

    test('overlapping regions are geometryInconsistent', () {
      final profile = _consistentMeasuredProfile(
        regions: [
          HitRegion(
            id: CentralInstrumentRegionIds.timePhase,
            x: 10,
            y: 10,
            width: 50,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.score,
            x: 40,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.capture,
            x: 10,
            y: 50,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.cautions,
            x: 60,
            y: 50,
            width: 40,
            height: 30,
          ),
        ],
      );
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.geometryInconsistent,
      );
    });

    test('gap violation is geometryInconsistent', () {
      final profile = _consistentMeasuredProfile(gap: 20);
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.geometryInconsistent,
      );
    });

    test('missing capture region is geometryInconsistent', () {
      final profile = _consistentMeasuredProfile(
        regions: [
          HitRegion(
            id: CentralInstrumentRegionIds.timePhase,
            x: 10,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.score,
            x: 60,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.cautions,
            x: 60,
            y: 50,
            width: 40,
            height: 30,
          ),
        ],
      );
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.geometryInconsistent,
      );
    });

    test('operator-supplied consistent profile is readyForPhysicalGate', () {
      final profile = _consistentMeasuredProfile();
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.readyForPhysicalGate,
      );
      expect(
        checker.checkMeasuredMatrix([profile]),
        GeometryCheckResult.readyForPhysicalGate,
      );
    });

    test('duplicate region ids are geometryInconsistent', () {
      final profile = _consistentMeasuredProfile(
        regions: [
          HitRegion(
            id: CentralInstrumentRegionIds.timePhase,
            x: 10,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.timePhase,
            x: 60,
            y: 10,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.capture,
            x: 10,
            y: 50,
            width: 40,
            height: 30,
          ),
          HitRegion(
            id: CentralInstrumentRegionIds.cautions,
            x: 60,
            y: 50,
            width: 40,
            height: 30,
          ),
        ],
      );
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.geometryInconsistent,
      );
    });

    test('missing or non-finite viewport is geometryInconsistent', () {
      final base = _consistentMeasuredProfile();
      for (final profile in [
        WatchGeometryProfile(
          deviceLabel: base.deviceLabel,
          status: base.status,
          operatorSuppliedMeasurement: true,
          edgeClearance: base.edgeClearance,
          interRegionGap: base.interRegionGap,
          regions: base.regions,
        ),
        WatchGeometryProfile(
          deviceLabel: base.deviceLabel,
          status: base.status,
          operatorSuppliedMeasurement: true,
          edgeClearance: base.edgeClearance,
          interRegionGap: base.interRegionGap,
          viewportWidth: 30,
          regions: base.regions,
        ),
        WatchGeometryProfile(
          deviceLabel: base.deviceLabel,
          status: base.status,
          operatorSuppliedMeasurement: true,
          edgeClearance: base.edgeClearance,
          interRegionGap: base.interRegionGap,
          viewportWidth: double.nan,
          viewportHeight: double.nan,
          regions: base.regions,
        ),
        WatchGeometryProfile(
          deviceLabel: base.deviceLabel,
          status: base.status,
          operatorSuppliedMeasurement: true,
          edgeClearance: base.edgeClearance,
          interRegionGap: base.interRegionGap,
          viewportWidth: double.infinity,
          viewportHeight: double.infinity,
          regions: base.regions,
        ),
      ]) {
        expect(
          checker.checkProfile(profile),
          GeometryCheckResult.geometryInconsistent,
          reason: profile.deviceLabel,
        );
        expect(
          checker.checkMeasuredMatrix([profile]),
          GeometryCheckResult.geometryInconsistent,
        );
      }
    });

    test('negative edge clearance is geometryInconsistent', () {
      final profile = WatchGeometryProfile(
        deviceLabel: 'lab',
        status: WatchProfileStatus.uncertifiedCandidate,
        operatorSuppliedMeasurement: true,
        edgeClearance: -1,
        interRegionGap: 4,
        viewportWidth: 200,
        viewportHeight: 200,
        regions: _consistentMeasuredProfile().regions,
      );
      expect(
        checker.checkProfile(profile),
        GeometryCheckResult.geometryInconsistent,
      );
    });

    test('HitRegion rejects non-positive dimensions', () {
      expect(
        () => HitRegion(id: 'a', x: 0, y: 0, width: 0, height: 10),
        throwsArgumentError,
      );
      expect(
        () => HitRegion(id: 'a', x: 0, y: 0, width: 10, height: -1),
        throwsArgumentError,
      );
    });
  });

  group('uncertified candidate catalog', () {
    test('returns four candidates', () {
      expect(uncertifiedWatchCandidates(), hasLength(4));
      for (final c in uncertifiedWatchCandidates()) {
        expect(c.status, WatchProfileStatus.uncertifiedCandidate);
        expect(c.operatorSuppliedMeasurement, isFalse);
      }
    });

    test('catalog check is deviceMatrixRequired not readyForPhysicalGate', () {
      final result = checkCandidateCatalog();
      expect(result, GeometryCheckResult.deviceMatrixRequired);
      expect(result, isNot(GeometryCheckResult.readyForPhysicalGate));
    });
  });
}
