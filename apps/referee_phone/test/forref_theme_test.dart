import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:referee_phone/design/forref_colors.dart';
import 'package:referee_phone/design/forref_theme.dart';

void main() {
  test('light and dark themes keep the instrument palette', () {
    final light = ForrefTheme.light();
    final dark = ForrefTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(light.colorScheme.primary, ForrefColors.navy);
    expect(light.scaffoldBackgroundColor, ForrefColors.lightSurface);
    expect(light.colorScheme.primary, isNot(ForrefColors.turquoise));

    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, ForrefColors.darkSurface);
    expect(dark.colorScheme.surface, ForrefColors.darkSurface);
    expect(dark.colorScheme.primary, isNot(ForrefColors.turquoise));
  });
}
