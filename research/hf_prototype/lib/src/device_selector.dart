import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import '../research_app.dart';
import 'device_facts.dart';
import 'lab_theme.dart';

/// Top-bar device summary. Opens the catalog panel.
class DeviceSummaryButton extends StatelessWidget {
  const DeviceSummaryButton({
    super.key,
    required this.controller,
    required this.compact,
  });

  final ResearchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final profile = controller.shellProfile;
    final manufacturer =
        profile == null ? 'DEVICE' : deviceManufacturer(profile).toUpperCase();
    final model =
        profile == null ? 'Select a device' : deviceModelLine(profile);
    return InkWell(
      key: const Key('device-summary'),
      borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
      onTap: () =>
          controller.setDeviceSelectorOpen(!controller.deviceSelectorOpen),
      child: Container(
        height: LabMetrics.controlHeight - 6,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LabColors.softWhite,
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Text(
                '$manufacturer · ',
                style: const TextStyle(
                    color: LabColors.inkMuted,
                    fontSize: 11,
                    letterSpacing: 0.6),
              ),
            ],
            Flexible(
              child: Text(
                model,
                key: const Key('device-summary-model'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LabColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: LabColors.navy),
          ],
        ),
      ),
    );
  }
}

/// Device catalog over the factual seed profiles.
///
/// Shows only facts the profile carries. The evidence stage is computed by the
/// geometry package. No tier is inferred from the presence of a shell.
class DeviceSelectorPanel extends StatelessWidget {
  const DeviceSelectorPanel({
    super.key,
    required this.controller,
    required this.maxWidth,
  });

  final ResearchController controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = (maxWidth - 2 * LabMetrics.gutter).clamp(280.0, 760.0);
    final columns = width >= 620 ? 2 : 1;
    return Padding(
      padding: const EdgeInsets.only(top: LabMetrics.tight),
      child: Material(
        key: const Key('device-selector'),
        elevation: 8,
        color: LabColors.surface,
        borderRadius: BorderRadius.circular(LabMetrics.surfaceRadius),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(LabMetrics.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('TARGET DEVICE', style: LabText.label),
                    ),
                    IconButton(
                      key: const Key('device-selector-close'),
                      tooltip: 'Close',
                      onPressed: () => controller.setDeviceSelectorOpen(false),
                      icon: const Icon(Icons.close,
                          size: 18, color: LabColors.navy),
                    ),
                  ],
                ),
                const Text(
                  'Facts come from the device profile. Shells are schematic. PROFILED is not platform proof.',
                  style: LabText.caption,
                ),
                const SizedBox(height: LabMetrics.tight),
                _DeviceGrid(controller: controller, columns: columns),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceGrid extends StatelessWidget {
  const _DeviceGrid({required this.controller, required this.columns});

  final ResearchController controller;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final profiles = factualSeedProfiles;
    final rows = <Widget>[];
    for (var index = 0; index < profiles.length; index += columns) {
      final slice = profiles.sublist(
        index,
        index + columns > profiles.length ? profiles.length : index + columns,
      );
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: LabMetrics.tight),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: LabMetrics.tight),
                  Expanded(
                    child: column < slice.length
                        ? DeviceCard(
                            profile: slice[column],
                            selected: slice[column].identity.profileId ==
                                controller.shellProfileId,
                            onTap: () => controller.openDeviceShell(
                                slice[column].identity.profileId),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final DeviceProfileV2 profile;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final id = profile.identity.profileId;
    return InkWell(
      key: Key('device-card-$id'),
      borderRadius: BorderRadius.circular(LabMetrics.controlRadius + 2),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? LabColors.canvas : LabColors.surface,
          border: Border.all(
            color: selected ? LabColors.navy : LabColors.line,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius + 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShapeMark(profile: profile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deviceManufacturer(profile).toUpperCase(),
                      style: LabText.label),
                  const SizedBox(height: 2),
                  Text(deviceModelLine(profile), style: LabText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    '${deviceRasterLine(profile)} · ${deviceShapeLine(profile)}',
                    style: LabText.caption,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Badge(text: deviceEvidenceStageLabel(profile)),
                      const SizedBox(width: 6),
                      if (selected)
                        const _Badge(text: 'SELECTED', strong: true),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ShapeMark extends StatelessWidget {
  const _ShapeMark({required this.profile});

  final DeviceProfileV2 profile;

  @override
  Widget build(BuildContext context) {
    final shape = profile.display.shape;
    final decoration = switch (shape.hasValue ? shape.value : null) {
      ScreenShape.round =>
        const BoxDecoration(color: LabColors.navy, shape: BoxShape.circle),
      ScreenShape.rectangle => const BoxDecoration(color: LabColors.navy),
      ScreenShape.roundedRectangle => BoxDecoration(
          color: LabColors.navy,
          borderRadius: BorderRadius.circular(8),
        ),
      null => BoxDecoration(
          border: Border.all(color: LabColors.unknownFact, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
    };
    return Container(
      width: 34,
      height: 40,
      decoration: decoration,
      alignment: Alignment.center,
      child: shape.hasValue
          ? null
          : const Text('?',
              style: TextStyle(color: LabColors.unknownFact, fontSize: 14)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? LabColors.navy : LabColors.canvas,
        border: Border.all(color: strong ? LabColors.navy : LabColors.line),
        borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: strong ? LabColors.softWhite : LabColors.navy,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
