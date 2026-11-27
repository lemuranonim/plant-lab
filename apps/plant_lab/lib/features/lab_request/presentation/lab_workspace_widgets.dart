import 'package:flutter/material.dart';
import '../../../app/theme/lab_theme.dart';

class LabQueueHero extends StatelessWidget {
  const LabQueueHero({super.key, required this.scope, required this.mode});
  final String scope, mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<LabPalette>() ??
        LabPalette(theme.brightness == Brightness.dark);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.sunken, palette.heroEnd]),
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scope, style: theme.textTheme.labelMedium),
            const SizedBox(height: 10),
            Text(
              'Antrean pengujian Lab',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(mode, style: theme.textTheme.labelMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LabLotTitle extends StatelessWidget {
  const LabLotTitle({super.key, required this.lot, required this.reference});

  final String lot;
  final String reference;

  static double toolbarHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(56) + 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lot,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: LabTheme.codeFeatures,
          ),
        ),
        Text(
          reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class LabMenuGrid extends StatelessWidget {
  const LabMenuGrid({super.key, required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) {
      final gap = 10.0;
      final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
      final columns = limits.maxWidth >= 320 && !largeText ? 2 : 1;
      final width = (limits.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}

class LabFormSections extends StatelessWidget {
  const LabFormSections({
    super.key,
    required this.sections,
    required this.targets,
  });
  final List<String> sections;
  final List<GlobalKey> targets;

  @override
  Widget build(BuildContext context) {
    assert(sections.length == targets.length);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (index, section) in sections.indexed)
            OutlinedButton(
              onPressed: () {
                final target = targets[index].currentContext;
                if (target != null) Scrollable.ensureVisible(target);
              },
              child: Text(section),
            ),
        ],
      ),
    );
  }
}

class LabHelp extends StatelessWidget {
  const LabHelp({
    super.key,
    this.label = 'Bantuan singkat',
    required this.text,
  });
  final String label, text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      icon: const Icon(Icons.info_outline, size: 18),
      label: Text(label),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Flexible(child: SingleChildScrollView(child: Text(text))),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup bantuan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LabLabel extends StatelessWidget {
  const LabLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class LabFormCard extends StatelessWidget {
  const LabFormCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.hint,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class LabReadOnlyIntro extends StatelessWidget {
  const LabReadOnlyIntro({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title, description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LabFormCard(
    title: title,
    icon: icon,
    children: [
      const Align(
        alignment: Alignment.centerLeft,
        child: LabLabel('Baca saja'),
      ),
      const SizedBox(height: 8),
      Text(description),
    ],
  );
}

/// Reflows the existing widgets without changing their order or controllers.
class LabFieldGrid extends StatelessWidget {
  const LabFieldGrid({
    super.key,
    required this.fields,
    this.maxColumns = 2,
    this.minFieldWidth = 166,
  });

  final List<Widget> fields;
  final int maxColumns;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 12.0;
      final scaler = MediaQuery.textScalerOf(context);
      final roomy = box.hasBoundedWidth && scaler.scale(16) <= 20;
      var columns = 1;
      while (roomy &&
          columns < maxColumns &&
          columns < fields.length &&
          box.maxWidth >= minFieldWidth * (columns + 1) + gap * columns) {
        columns++;
      }
      final width = box.hasBoundedWidth
          ? (box.maxWidth - (columns - 1) * gap) / columns
          : minFieldWidth;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final field in fields) SizedBox(width: width, child: field),
        ],
      );
    },
  );
}

class LabMetricTile extends StatelessWidget {
  const LabMetricTile({super.key, required this.title, required this.value});
  final String title, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontFeatures: LabTheme.codeFeatures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved observation, not an input. In particular, an empty value is not 0.
class LabRecordValue extends StatelessWidget {
  const LabRecordValue(this.label, this.value, {super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = value == null || value!.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          missing ? 'Belum dicatat' : value!,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
            fontFeatures: LabTheme.codeFeatures,
          ),
        ),
      ],
    );
  }
}

class LabMenuCard extends StatelessWidget {
  const LabMenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });
  final IconData icon;
  final String label, caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<LabPalette>() ??
        LabPalette(theme.brightness == Brightness.dark);
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: palette.line),
    );
    return Semantics(
      button: true,
      child: Material(
        shape: border,
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: palette.mint,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  child: Icon(icon, size: 18),
                ),
                const SizedBox(height: 9),
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 5),
                Text(caption, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LabQueueLoading extends StatelessWidget {
  const LabQueueLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<LabPalette>() ??
        LabPalette(theme.brightness == Brightness.dark);
    return Semantics(
      liveRegion: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Memuat antrean', style: theme.textTheme.titleMedium),
          for (final height in [118.0, 72.0, 72.0])
            Container(
              height: height,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: palette.sunken,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.line),
              ),
            ),
        ],
      ),
    );
  }
}
