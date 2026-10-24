import 'package:flutter/material.dart';

import 'forref_colors.dart';
import 'forref_spacing.dart';

enum ForrefNoticeTone { neutral, attention, unavailable }

/// Section title with an optional required/optional marker.
class ForrefSectionHeader extends StatelessWidget {
  const ForrefSectionHeader({
    super.key,
    required this.title,
    this.marker,
    this.quiet = false,
  });

  final String title;
  final String? marker;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = quiet
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ForrefSpace.s20,
        ForrefSpace.s24,
        ForrefSpace.s20,
        ForrefSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
          if (marker != null) Text(marker!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Fixture name first, metadata second.
class ForrefFixtureIdentity extends StatelessWidget {
  const ForrefFixtureIdentity({
    super.key,
    required this.title,
    this.detail,
    this.large = false,
    this.color,
  });

  final String title;
  final String? detail;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (large
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.titleLarge)
              ?.copyWith(color: color),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: ForrefSpace.s4),
          Text(
            detail!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color ?? theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Readiness or uncertainty. Meaning is the words, not the fill.
class ForrefNotice extends StatelessWidget {
  const ForrefNotice({
    super.key,
    required this.title,
    this.lines = const [],
    this.tone = ForrefNoticeTone.neutral,
    this.titleKey,
  });

  final String title;
  final List<String> lines;
  final ForrefNoticeTone tone;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (background, foreground, border) = switch (tone) {
      ForrefNoticeTone.attention => (
          dark
              ? ForrefColors.darkAttentionSurface
              : ForrefColors.attentionSurface,
          dark ? ForrefColors.darkAttentionInk : ForrefColors.attentionInk,
          dark ? const Color(0xFF6A5430) : const Color(0xFFE4D3B8),
        ),
      ForrefNoticeTone.unavailable => (
          theme.colorScheme.surfaceContainerLow,
          theme.colorScheme.onSurface,
          theme.colorScheme.outline,
        ),
      ForrefNoticeTone.neutral => (
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurface,
          theme.colorScheme.outlineVariant,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ForrefSpace.s16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ForrefSpace.radiusSurface),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: titleKey,
            style: theme.textTheme.titleMedium?.copyWith(color: foreground),
          ),
          for (final line in lines)
            if (line.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: ForrefSpace.s8),
                child: Text(
                  line,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
        ],
      ),
    );
  }
}

/// Full-width primary action kept clear of the keyboard by the scaffold.
class ForrefBottomAction extends StatelessWidget {
  const ForrefBottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final bottomGap =
        keyboardOpen ? ForrefSpace.s12 : ForrefSpace.s12 + media.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ForrefSpace.s20,
        ForrefSpace.s12,
        ForrefSpace.s20,
        bottomGap,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
