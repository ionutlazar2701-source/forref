import 'package:flutter/material.dart';
import 'package:simulator_geometry/simulator_geometry.dart';

import 'device_facts.dart';
import 'lab_theme.dart';

/// One evidence row. Unknown is shown as UNKNOWN; it is never a blank or a zero.
final class EvidenceRow {
  const EvidenceRow({
    required this.label,
    required this.value,
    required this.status,
    this.sourceIds = const [],
    this.derivation,
    this.uncertainty,
  });

  final String label;
  final String value;
  final FactStatus status;
  final List<String> sourceIds;
  final String? derivation;
  final String? uncertainty;
}

final class EvidenceGroup {
  const EvidenceGroup(this.title, this.rows);

  final String title;
  final List<EvidenceRow> rows;
}

EvidenceRow _fact<T>(String label, EvidenceFact<T> fact,
    {String Function(T)? format}) {
  final value = fact.value;
  final text = !fact.hasValue || value == null
      ? unknownFactLabel
      : (format == null ? '$value' : format(value));
  return EvidenceRow(
    label: label,
    value: text,
    status: fact.status,
    sourceIds: fact.sourceIds,
    derivation: fact.derivation,
    uncertainty: fact.uncertainty,
  );
}

String _mm(double value) => '${_number(value)} mm';
String _px(double value) => '${_number(value)} px';
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _shape(ScreenShape shape) => switch (shape) {
      ScreenShape.round => 'round',
      ScreenShape.rectangle => 'rectangle',
      ScreenShape.roundedRectangle => 'rounded rectangle',
    };

EvidenceRow _control(String label, ControlFact fact) {
  final availability = switch (fact.availability) {
    ControlAvailability.supported => 'supported',
    ControlAvailability.unsupported => 'unsupported',
    ControlAvailability.unknown => unknownFactLabel,
    ControlAvailability.systemReserved => 'system reserved',
  };
  final count = fact.count;
  final countText = count == null
      ? ''
      : (count.hasValue
          ? ' · count ${count.value}'
          : ' · count $unknownFactLabel');
  final simulate = fact.availability == ControlAvailability.supported
      ? (fact.appMaySimulate
          ? ' · app may simulate'
          : ' · app does not simulate')
      : '';
  return EvidenceRow(
    label: label,
    value: '$availability$countText$simulate',
    status: fact.availability == ControlAvailability.unknown
        ? FactStatus.unknown
        : FactStatus.known,
    sourceIds: fact.sourceIds,
    uncertainty: fact.uncertainty,
  );
}

/// Builds the six evidence groups from one profile. Pure. No fabricated values.
List<EvidenceGroup> deviceEvidenceGroups(DeviceProfileV2 profile) {
  final identity = profile.identity;
  final display = profile.display;
  final caseFacts = profile.caseFacts;
  final controls = profile.controls;
  final manifest = shellManifestFor(profile);
  final viewport = viewportContextFor(profile);

  final safeArea = display.safeArea;
  final safeValue = safeArea.value;
  final safeText = switch (safeArea.status) {
    FactStatus.unknown => unknownFactLabel,
    _ => safeValue == null
        ? unknownFactLabel
        : (safeValue.isCircular
            ? 'circular inset ${_number(safeValue.circularInset!)}'
            : 'insets L ${_number(safeValue.left)} T ${_number(safeValue.top)} '
                'R ${_number(safeValue.right)} B ${_number(safeValue.bottom)}'),
  };
  final aperture = display.shellAperture;
  final apertureText =
      aperture.status == FactStatus.unknown || aperture.value == null
          ? unknownFactLabel
          : aperture.value.toString();

  return [
    EvidenceGroup('IDENTITY', [
      EvidenceRow(
          label: 'Profile id',
          value: identity.profileId,
          status: FactStatus.known),
      _fact('Manufacturer', identity.manufacturer),
      _fact('Family', identity.family),
      _fact('Model', identity.model),
      _fact('Variant', identity.variant),
      EvidenceRow(
        label: 'Device class',
        value: identity.deviceClass.name,
        status: FactStatus.known,
      ),
      _fact('Platform family', identity.platformFamily),
    ]),
    EvidenceGroup('DISPLAY', [
      _fact('Shape', display.shape, format: _shape),
      _fact('Raster width', display.rasterWidth, format: _px),
      _fact('Raster height', display.rasterHeight, format: _px),
      _fact('Display width', display.widthMm, format: _mm),
      _fact('Display height', display.heightMm, format: _mm),
      _fact('Diagonal', display.diagonalInches,
          format: (v) => '${_number(v)} in'),
      _fact('Pixel density', display.ppi, format: (v) => '${_number(v)} ppi'),
      _fact('Corner radius', display.cornerRadiusPx, format: _px),
      _fact('Native logical width', display.nativeLogicalWidth, format: _px),
      _fact('Native logical height', display.nativeLogicalHeight, format: _px),
      _fact('Design width', display.designWidth, format: _px),
      _fact('Design height', display.designHeight, format: _px),
      _fact('Design basis', display.designBasis),
      EvidenceRow(
        label: 'Safe area',
        value: safeText,
        status: safeArea.status,
        sourceIds: safeArea.sourceIds,
        derivation: safeArea.derivation,
        uncertainty: safeArea.uncertainty,
      ),
      EvidenceRow(
        label: 'Shell aperture',
        value: apertureText,
        status: aperture.status,
        sourceIds: aperture.sourceIds,
        derivation: aperture.derivation,
        uncertainty: aperture.uncertainty,
      ),
      EvidenceRow(
        label: 'Viewport basis',
        value: viewport.basisLabel,
        status: viewport.usesNativeLogicalViewport
            ? FactStatus.known
            : FactStatus.derived,
      ),
    ]),
    EvidenceGroup('CASE', [
      _fact('Case width', caseFacts.widthMm, format: _mm),
      _fact('Case height', caseFacts.heightMm, format: _mm),
      _fact('Case depth', caseFacts.depthMm, format: _mm),
      _fact('Case shape', caseFacts.shape, format: _shape),
    ]),
    EvidenceGroup('INPUT', [
      _control('Touchscreen', controls.touchscreen),
      _control('Crown', controls.crown),
      _control('Crown rotation', controls.crownRotation),
      _control('Crown press', controls.crownPress),
      _control('Physical buttons', controls.physicalButtons),
      _control('Rotating bezel', controls.rotatingBezel),
      _control('Gesture input', controls.gestureInput),
      _control('Haptics', controls.haptics),
    ]),
    EvidenceGroup('FIDELITY', [
      EvidenceRow(
        label: 'Evidence stage',
        value: deviceEvidenceStageLabel(profile),
        status: FactStatus.derived,
        derivation:
            'Computed by profileV2EvidenceStage from the profile facts. '
            'A profile document cannot set it.',
      ),
      EvidenceRow(
        label: 'Shell fidelity',
        value: shellFidelityLabel(profile),
        status: FactStatus.derived,
        derivation: manifest.apertureEvidence,
      ),
      EvidenceRow(
        label: 'Shell representation',
        value: manifest.representation.name,
        status: FactStatus.known,
      ),
      EvidenceRow(
        label: 'Shell canvas unit',
        value: manifest.canvasUnit,
        status: FactStatus.known,
      ),
      const EvidenceRow(
        label: 'PLATFORM PROVEN',
        value: 'NOT ESTABLISHED',
        status: FactStatus.unknown,
        uncertainty:
            'Requires platform execution evidence. Not computable in this lab.',
      ),
      const EvidenceRow(
        label: 'FORREF CERTIFIED',
        value: 'NOT ESTABLISHED',
        status: FactStatus.unknown,
        uncertainty:
            'Requires physical device certification. Not authorized in S2.3.5.',
      ),
    ]),
    EvidenceGroup('PROVENANCE', [
      _fact('Shell reference', profile.shellReference),
      EvidenceRow(
        label: 'Shell asset',
        value: manifest.assetProvenance,
        status: FactStatus.known,
      ),
      for (final source in profile.sources)
        EvidenceRow(
          label: source.id,
          value: '${source.title} · retrieved ${source.retrieved}',
          status: FactStatus.known,
          uncertainty: source.note.isEmpty ? null : source.note,
          derivation: source.url,
        ),
    ]),
  ];
}

/// Device Evidence inspector section.
class DeviceEvidenceView extends StatelessWidget {
  const DeviceEvidenceView({super.key, required this.profile});

  final DeviceProfileV2? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null) {
      return const Padding(
        padding: EdgeInsets.all(LabMetrics.gutter),
        child: Text(
          'No factual device profile is bound. The geometry diagnostic stage uses illustrative starter profiles, not DeviceProfileV2 evidence.',
          key: Key('device-evidence-none'),
          style: LabText.caption,
        ),
      );
    }
    final groups = deviceEvidenceGroups(profile);
    final unknownCount = groups
        .expand((group) => group.rows)
        .where((row) => row.status == FactStatus.unknown)
        .length;
    return SingleChildScrollView(
      key: const Key('device-evidence'),
      padding: const EdgeInsets.all(LabMetrics.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DEVICE EVIDENCE · DeviceProfileV2', style: LabText.label),
          const SizedBox(height: 4),
          Text(deviceDisplayName(profile),
              key: const Key('evidence-device-name'), style: LabText.panelTitle),
          const SizedBox(height: 4),
          Text(
            '$unknownCount facts are $unknownFactLabel. Unknown stays unknown; the shell never fills a missing number.',
            key: const Key('evidence-unknown-count'),
            style: LabText.caption,
          ),
          const SizedBox(height: LabMetrics.tight),
          for (final group in groups) _GroupCard(group: group),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final EvidenceGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LabMetrics.tight),
      child: Material(
        color: LabColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: LabColors.line),
          borderRadius: BorderRadius.circular(LabMetrics.controlRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.title,
                  key: Key('evidence-group-${group.title}'),
                  style: LabText.label),
              const SizedBox(height: 6),
              for (final row in group.rows)
                _RowTile(row: row, group: group.title),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.group});

  final EvidenceRow row;
  final String group;

  @override
  Widget build(BuildContext context) {
    final hasDetail = row.sourceIds.isNotEmpty ||
        row.derivation != null ||
        row.uncertainty != null;
    // Label and badge share the first line; the value gets the full width
    // beneath so UNKNOWN is never broken mid-word in a narrow inspector.
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(row.label, style: LabText.caption)),
            const SizedBox(width: 6),
            StatusBadge(status: row.status),
          ],
        ),
        Text(
          row.value,
          key: Key('evidence-value-$group-${row.label}'),
          style: row.status == FactStatus.unknown
              ? LabText.numeric.copyWith(color: LabColors.unknownFact)
              : LabText.numeric,
        ),
      ],
    );
    if (!hasDetail) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4), child: head);
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: head,
        children: [
          if (row.derivation != null)
            Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('Derivation: ${row.derivation}', style: LabText.caption),
            ),
          if (row.uncertainty != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Uncertainty: ${row.uncertainty}',
                  style: LabText.caption),
            ),
          if (row.sourceIds.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Sources: ${row.sourceIds.join(', ')}',
                  style: LabText.caption),
            ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final FactStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FactStatus.known => LabColors.navy,
      FactStatus.derived => LabColors.steel,
      FactStatus.unknown => LabColors.unknownFact,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(LabMetrics.chipRadius),
      ),
      child: Text(
        factStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
