import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/import_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/extensions/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/parsed_chat.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ChatPreview? _preview;
  String? _path;
  bool _peeking = false;

  Future<void> _pick() async {
    setState(() {
      _peeking = true;
      _preview = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: false,
      );
      final path = result?.files.single.path;
      if (path == null) {
        // Cancelling is not an error — just go back to the empty state.
        if (mounted) setState(() => _peeking = false);
        return;
      }
      final preview = await ref.read(importServiceProvider).peek(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _preview = preview;
        _peeking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _peeking = false);
      _showError('That file could not be opened. $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _analyze() async {
    final path = _path;
    if (path == null) return;
    final session =
        await ref.read(importControllerProvider.notifier).importFile(path);
    if (!mounted) return;
    if (session == null) {
      final error = ref.read(importControllerProvider).error;
      if (error != null) _showError(error);
      ref.read(importControllerProvider.notifier).clearError();
      return;
    }
    context.pushReplacement(Routes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import a chat')),
      body: SafeArea(
        child: importState.busy
            ? _ImportProgressView(progress: importState.progress)
            : _body(),
      ),
    );
  }

  Widget _body() {
    if (_peeking) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = _preview;
    if (preview == null) {
      return _Instructions(onPick: _pick);
    }
    if (!preview.looksValid) {
      return _UnsupportedFile(preview: preview, onPickAgain: _pick);
    }
    return _Preview(preview: preview, onAnalyze: _analyze, onPickAgain: _pick);
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.onPick});
  final VoidCallback onPick;

  static const _steps = <String>[
    'Open the chat in WhatsApp',
    'Tap the chat name, then Export chat',
    'Choose Without media',
    'Save the .txt file to this device',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Get your export', style: theme.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'WhatsApp can save any conversation as a plain text file. That file '
          'is all Nuntius needs.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        // Numbered because these genuinely are sequential steps.
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.accent),
                  ),
                ),
                Expanded(
                  child: Text(_steps[i], style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Choose a .txt file'),
        ),
        const SizedBox(height: 24),
        const PrivacyBadge(
          text: 'Nuntius reads the file here. It is never uploaded.',
        ),
      ],
    );
  }
}

class _UnsupportedFile extends StatelessWidget {
  const _UnsupportedFile({required this.preview, required this.onPickAgain});
  final ChatPreview preview;
  final VoidCallback onPickAgain;

  @override
  Widget build(BuildContext context) => EmptyState(
        emoji: '🤔',
        title: 'That does not look like a WhatsApp export',
        message: '${preview.fileName} has no lines in the format WhatsApp '
            'writes. Export the chat again and choose "Without media" — the '
            'file you want ends in .txt.',
        actionLabel: 'Pick a different file',
        onAction: onPickAgain,
      );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.preview,
    required this.onAnalyze,
    required this.onPickAgain,
  });

  final ChatPreview preview;
  final VoidCallback onAnalyze;
  final VoidCallback onPickAgain;

  String get _formatLabel => switch (preview.dateOrder) {
        DateOrder.dayFirst => 'Day/month dates',
        DateOrder.monthFirst => 'Month/day dates',
        DateOrder.yearFirst => 'Year-first dates',
        null => 'Unknown format',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(preview.fileName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Found in this file'),
                    const SizedBox(height: 16),
                    _Row(
                      label: 'People',
                      value: preview.participants.isEmpty
                          ? '—'
                          : preview.participants.take(4).join(', ') +
                              (preview.participants.length > 4
                                  ? ' +${preview.participants.length - 4}'
                                  : ''),
                    ),
                    _Row(
                      label: 'Starts',
                      value: preview.firstTimestamp?.shortDate ?? '—',
                    ),
                    _Row(label: 'File size', value: Fmt.bytes(preview.bytes)),
                    _Row(label: 'Date format', value: _formatLabel),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Counts are read from the start of the file. The full total '
                'appears once the analysis finishes.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              FilledButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Analyse chat'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onPickAgain,
                child: const Text('Choose a different file'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportProgressView extends StatelessWidget {
  const _ImportProgressView({this.progress});
  final ImportProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = progress?.value ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, v, _) => SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: v == 0 ? null : v,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  Text(
                    '${(value * 100).round()}%',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              progress?.label ?? 'Getting ready',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Everything is happening on this device.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
