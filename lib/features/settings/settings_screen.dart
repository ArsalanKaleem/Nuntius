import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/glass_card.dart';
import '../../providers/providers.dart';
import '../../repositories/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _storedBytes;

  @override
  void initState() {
    super.initState();
    _measureStorage();
  }

  Future<void> _measureStorage() async {
    final bytes = await ref.read(fileServiceProvider).totalStoredBytes();
    if (mounted) setState(() => _storedBytes = bytes);
  }

  Future<void> _deleteEverything() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'Every imported chat, every saved report and every setting will be '
              'removed from this device. Nothing was ever sent anywhere else, so '
              'this deletes all of it. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => context.pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    await ref.read(fileServiceProvider).deleteEverything();
    await ref.read(reportsProvider.notifier).deleteAll();
    ref.read(sessionProvider.notifier).state = null;
    await _measureStorage();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Everything has been deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final reports = ref.watch(reportsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const SectionHeader('Appearance'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Theme'),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) =>
                      controller.setThemeMode(selection.first),
                ),
                const SizedBox(height: 22),
                const Eyebrow('Animation'),
                const SizedBox(height: 6),
                Text(
                  'Counters, charts and the Wrapped story. Choose Off if '
                      'movement is distracting — the app also follows your '
                      'system-wide reduce-motion setting on its own.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final speed in AnimationSpeed.values)
                      ChoiceChip(
                        label: Text(speed.label),
                        selected: settings.animationSpeed == speed,
                        onSelected: (_) => controller.setAnimationSpeed(speed),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader('Storage'),
          SurfaceCard(
            child: Column(
              children: [
                _Row(
                  label: 'Saved chats',
                  value: Fmt.n(reports.length),
                ),
                _Row(
                  label: 'Space used',
                  value: _storedBytes == null
                      ? '…'
                      : Fmt.bytes(_storedBytes!),
                  detail: 'Copies of your exports, kept so chats can reopen',
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteEverything,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete everything'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader('Privacy'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      AppInfo.privacyLine,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Nuntius has no account, no server and no analytics. Your '
                      'export is read and analysed on this device, and the only '
                      'copy it keeps lives in the app\'s private storage. Images '
                      'and PDFs are only shared when you tap share.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader('About'),
          SurfaceCard(
            child: Column(
              children: [
                _Row(label: 'Version', value: AppInfo.version),
                _Row(
                  label: 'Made by',
                  value: 'Nuntius',
                  detail: AppInfo.tagline,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: AppInfo.name,
                      applicationVersion: AppInfo.version,
                    ),
                    child: const Text('Open source licences'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (detail != null)
                  Text(detail!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Flexible rather than a bare Text: some of these values are words
          // ("Perfectly balanced", "Standard") rather than short numbers, and
          // at a large text scale a fixed child would run off the row.
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
