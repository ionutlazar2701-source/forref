import 'package:simulator_geometry/simulator_geometry.dart';
import 'package:test/test.dart';

void main() {
  test('four seed shells stay schematic and keep unknown profile apertures', () {
    expect(factualSeedProfiles, hasLength(4));
    final ids = <String>{};
    for (final profile in factualSeedProfiles) {
      final shell = shellManifestFor(profile);
      ids.add(shell.profileId);
      expect(shell.fidelity, VisualFidelityGrade.schematic);
      expect(shell.representation, ShellRepresentationKind.procedural);
      expect(shell.apertureIsMeasured, isFalse);
      expect(shell.apertureEvidence, contains('NOT A MEASURED APERTURE'));
      expect(shell.caption, contains('Not certified'));
      expect(profile.display.shellAperture.status, FactStatus.unknown);
      expect(profile.display.safeArea.status, FactStatus.unknown);
      final center = shellSurfaceAt(
        shell,
        shell.aperture.left + shell.aperture.width / 2,
        shell.aperture.top + shell.aperture.height / 2,
      );
      expect(center, ShellSurface.aperture);
    }
    expect(ids, {
      'amazfit-gts4',
      'huawei-watch-gt4-46',
      'apple-watch-series9-45',
      'garmin-approach-s60',
    });
  });

  test('Huawei bezel, strap, and dead corner are not the aperture', () {
    final shell = shellManifestFor(huaweiWatchGt446);
    expect(shell.clip, ScreenShape.round);
    expect(shell.controls.map((item) => item.id), contains('crown'));
    expect(shell.controls.every((item) => item.simulatedChannel == false), isTrue);
    final bezel = shellSurfaceAt(
      shell,
      shell.body.left + shell.body.width / 2,
      shell.aperture.top - 0.4,
    );
    expect(bezel, ShellSurface.bezel);
    final strap = shellSurfaceAt(shell, shell.canvasWidth / 2, 1);
    expect(strap, ShellSurface.strap);
    final deadCorner = shellSurfaceAt(shell, shell.body.left + 0.2, shell.body.top + 0.2);
    expect(deadCorner, isNot(ShellSurface.aperture));
    expect(deadCorner, isNot(ShellSurface.bezel));
  });

  test('Amazfit shell uses the design aspect and does not name the key a crown', () {
    final shell = shellManifestFor(amazfitGts4);
    expect(shell.canvasUnit, contains('not millimetres'));
    expect(shell.clip, ScreenShape.roundedRectangle);
    expect(shell.cornerRadius, isNotNull);
    expect(shell.controls.map((item) => item.label), isNot(contains('Crown')));
    expect(shell.controls, isNotEmpty);
    final ratio = shell.aperture.width / shell.aperture.height;
    expect(ratio, closeTo(390 / 450, 0.001));
  });

  test('Apple shell keeps an unmeasured inset and Garmin does not invent a watch shape', () {
    final apple = shellManifestFor(appleWatchSeries945);
    expect(apple.cornerRadiusMeasured, isFalse);
    expect(apple.canvasUnit, contains('millimetre'));
    expect(apple.controls.map((item) => item.id), contains('crown'));
    final garmin = shellManifestFor(garminApproachS60);
    expect(garmin.straps, isEmpty);
    expect(garmin.controls, isEmpty);
    expect(garmin.clip, ScreenShape.rectangle);
    expect(garmin.caption, contains('No watch silhouette is invented'));
    expect(garmin.apertureEvidence, contains('CASE GEOMETRY UNKNOWN'));
  });

  test('control anchors and outside points do not count as the display', () {
    final shell = shellManifestFor(huaweiWatchGt446);
    final crown = shell.controls.firstWhere((item) => item.id == 'crown');
    expect(shellSurfaceAt(shell, crown.x, crown.y), ShellSurface.control);
    expect(shellSurfaceAt(shell, -1, -1), ShellSurface.outside);
    expect(shellSurfaceAt(shell, double.nan, 0), ShellSurface.outside);
  });
}