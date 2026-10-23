import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:test/test.dart';

void main() {
  const phoneSlots = [
    ActionSlot(
      id: 'yellow',
      preferred: DeviceRect(16, 180, 150, 48),
      minimumWidth: minimumActionExtent,
      minimumHeight: minimumActionExtent,
    ),
    ActionSlot(
      id: 'sendOff',
      preferred: DeviceRect(220, 180, 160, 48),
      minimumWidth: minimumActionExtent,
      minimumHeight: minimumActionExtent,
    ),
    ActionSlot(
      id: 'substitution',
      preferred: DeviceRect(16, 250, 200, 48),
      minimumWidth: minimumActionExtent,
      minimumHeight: minimumActionExtent,
    ),
  ];
  const roster = ActionSlot(
    id: 'roster',
    preferred: DeviceRect(16, 8, 320, 150),
    minimumWidth: minimumActionExtent,
    minimumHeight: minimumActionExtent,
  );

  test('fit transform round-trips and letterboxes the portrait phone', () {
    final view = assessView(
      profile: illustrativePhonePortrait,
      stageWidth: 800,
      stageHeight: 600,
      requested: CalibrationMode.fit,
    );
    expect(view.usable, isTrue);
    expect(view.calibrationLabel, 'FIT');
    expect(view.physicalFidelityLabel, notCalibratedLabel);
    expect(view.showsFit, isTrue);
    const sample = DevicePoint(100, 200);
    final back = view.transform.toDevice(view.transform.toStage(sample));
    expect(back.x, closeTo(100, 1e-9));
    expect(back.y, closeTo(200, 1e-9));

    final outside = view.transform.toDevice(const StagePoint(4, 4));
    final geometry = viewportFor(illustrativePhonePortrait);
    expect(geometry.containsVisible(outside.x, outside.y), isFalse);
  });

  test('zoom changes scale and still round-trips', () {
    final plain = assessView(
      profile: illustrativeRoundWatch,
      stageWidth: 500,
      stageHeight: 500,
      requested: CalibrationMode.fit,
    );
    final zoomed = assessView(
      profile: illustrativeRoundWatch,
      stageWidth: 500,
      stageHeight: 500,
      requested: CalibrationMode.fit,
      zoom: 2,
    );
    expect(zoomed.transform.scale, closeTo(plain.transform.scale * 2, 1e-9));
    const sample = DevicePoint(20, 30);
    final back = zoomed.transform.toDevice(zoomed.transform.toStage(sample));
    expect(back.x, closeTo(20, 1e-9));
    expect(back.y, closeTo(30, 1e-9));
  });

  test('invalid zoom and unproven calibration stay uncalibrated', () {
    final zoom = assessView(
      profile: illustrativePhonePortrait,
      stageWidth: 400,
      stageHeight: 400,
      requested: CalibrationMode.fit,
      zoom: 0,
    );
    expect(zoom.zoomAccepted, isFalse);
    expect(zoom.requestHonored, isTrue);

    final raster = assessView(
      profile: illustrativeRoundWatch,
      stageWidth: 400,
      stageHeight: 400,
      requested: CalibrationMode.raster1to1,
      host: const HostDisplayEvidence(devicePixelRatio: 2),
    );
    expect(raster.requestHonored, isFalse);
    expect(raster.calibrationLabel, notCalibratedLabel);

    final physical = assessView(
      profile: illustrativePhonePortrait,
      stageWidth: 400,
      stageHeight: 400,
      requested: CalibrationMode.physical1to1,
      host: const HostDisplayEvidence(millimetresPerLogicalPixel: 0.1),
    );
    expect(physical.requestHonored, isFalse);
    expect(physical.calibrationLabel, notCalibratedLabel);
    expect(physical.physicalFidelityLabel, notCalibratedLabel);
    expect(
      physicalTargetSize(
        profile: illustrativePhonePortrait,
        rect: const DeviceRect(0, 0, 48, 48),
      ),
      isNull,
    );
  });

  test('proven raster and physical scales are honored only with evidence', () {
    final profile = (parseProfile('''
{
  "schemaVersion": 1,
  "profileId": "measured-rect",
  "displayName": "Measured rectangle",
  "deviceClass": "smartwatch",
  "screenShape": "rectangle",
  "classification": "factual",
  "logicalViewport": {"width": 100, "height": 200},
  "rasterDimensions": {"known": true, "width": 200, "height": 400},
  "physicalDisplayDimensionsMm": {"known": true, "width": 20, "height": 40},
  "safeArea": {"kind": "insets", "left": 2, "top": 2, "right": 2, "bottom": 2},
  "edgeClipping": "none",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unsupported",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "independentlyMeasured",
    "sourceReference": "Bench measurement log M-1",
    "observedDate": "2026-02-01",
    "measurementMethod": "caliper on the visible glass"
  }
}
''') as ProfileAccepted)
        .profile;

    final raster = assessView(
      profile: profile,
      stageWidth: 800,
      stageHeight: 800,
      requested: CalibrationMode.raster1to1,
      host: const HostDisplayEvidence(devicePixelRatio: 2),
    );
    expect(raster.requestHonored, isTrue);
    expect(raster.calibrationLabel, 'RASTER_1_TO_1');
    expect(raster.physicalFidelityLabel, notCalibratedLabel);
    expect(raster.transform.scale, closeTo(1, 1e-9));

    final physical = assessView(
      profile: profile,
      stageWidth: 800,
      stageHeight: 800,
      requested: CalibrationMode.physical1to1,
      host: const HostDisplayEvidence(millimetresPerLogicalPixel: 0.2),
    );
    expect(physical.requestHonored, isTrue);
    expect(physical.calibrationLabel, 'PHYSICAL_1_TO_1');
    expect(physical.physicalFidelityLabel, 'PHYSICAL_1_TO_1');
    final size = physicalTargetSize(
      profile: profile,
      rect: const DeviceRect(0, 0, 50, 40),
    );
    expect(size, isNotNull);
    expect(size!.widthMm, closeTo(10, 1e-9));
    expect(size.heightMm, closeTo(8, 1e-9));
  });

  test('round clipping and safe area reject the bounding-box corner', () {
    final geometry = viewportFor(illustrativeRoundWatch);
    expect(geometry.containsVisible(120, 120), isTrue);
    expect(geometry.containsVisible(0, 0), isFalse);
    expect(geometry.containsVisible(239, 120), isTrue);
    expect(geometry.containsSafe(120, 120), isTrue);
    expect(geometry.containsVisible(4, 120), isTrue);
    expect(geometry.containsSafe(4, 120), isFalse);
  });

  test('phone preferred rectangles fit and a tiny round viewport does not', () {
    final phone = resolveActionLayout(
      viewport: viewportFor(illustrativePhonePortrait),
      actions: phoneSlots,
      roster: roster,
    );
    expect(phone.fits, isTrue);
    expect(phone.usedPreferred, isTrue);
    expect(phone.rects['yellow'], const DeviceRect(16, 180, 150, 48));
    expect(phone.rects['yellow']!.overlaps(phone.rects['sendOff']!), isFalse);

    final round = resolveActionLayout(
      viewport: viewportFor(illustrativeRoundWatch),
      actions: phoneSlots,
      roster: roster,
    );
    expect(round.fits, isTrue);
    expect(round.usedPreferred, isFalse);
    final geometry = viewportFor(illustrativeRoundWatch);
    for (final id in ['yellow', 'sendOff', 'substitution']) {
      expect(geometry.rectInsideSafe(round.rects[id]!), isTrue, reason: id);
    }
    expect(round.rects['yellow']!.overlaps(round.rects['sendOff']!), isFalse);

    final rectangular = resolveActionLayout(
      viewport: viewportFor(illustrativeRectangularWatch),
      actions: phoneSlots,
    );
    expect(rectangular.fits, isTrue);
    expect(rectangular.usedPreferred, isFalse);

    final tiny = (parseProfile('''
{
  "schemaVersion": 1,
  "profileId": "tiny-round",
  "displayName": "Tiny round",
  "deviceClass": "smartwatch",
  "screenShape": "round",
  "classification": "illustrative",
  "logicalViewport": {"width": 80, "height": 80},
  "rasterDimensions": {"known": false},
  "physicalDisplayDimensionsMm": {"known": false},
  "safeArea": {"kind": "circularInset", "inset": 4},
  "edgeClipping": "circularMask",
  "cornerRadius": 0,
  "inputCapabilities": {
    "touchscreen": "supported",
    "crown": "unknown",
    "physicalButtons": "unknown",
    "rotatingBezel": "unknown",
    "gestureInput": "unknown",
    "accessibilityInvocation": "unknown"
  },
  "typography": {"minimumLogicalSp": 12},
  "provenance": {
    "sourceType": "illustrative",
    "sourceReference": "FORREF research fixture. Dimensions are illustrative, not a measured product.",
    "observedDate": null,
    "measurementMethod": null
  }
}
''') as ProfileAccepted)
        .profile;
    final unfit = resolveActionLayout(
      viewport: viewportFor(tiny),
      actions: phoneSlots,
    );
    expect(unfit.fits, isFalse);
    expect(unfit.label, layoutNotFitLabel);
    expect(unfit.rects, isEmpty);
  });

  test('profile changes do not share transform state', () {
    final first = assessView(
      profile: illustrativePhonePortrait,
      stageWidth: 300,
      stageHeight: 600,
      requested: CalibrationMode.fit,
    );
    final second = assessView(
      profile: illustrativeRoundWatch,
      stageWidth: 300,
      stageHeight: 600,
      requested: CalibrationMode.fit,
    );
    expect(first.transform.deviceWidth, isNot(second.transform.deviceWidth));
    expect(
      evidenceStageFor(geometryAcceptsProfile: true, layoutFits: true),
      SimulatorEvidenceStage.simulationReady,
    );
    expect(
      evidenceStageFor(geometryAcceptsProfile: true, layoutFits: false),
      SimulatorEvidenceStage.profiled,
    );
  });

  test('host pointer origin is removed before the stage transform', () {
    final stage = hostToStage(
      const HostPoint(140, 90),
      stageOriginX: 40,
      stageOriginY: 20,
    );
    expect(stage.x, 100);
    expect(stage.y, 70);
  });
}
