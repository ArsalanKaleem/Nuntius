import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/eyebrow.dart';
import '../../models/chat_message.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

/// Reads the conversation back, a month at a time.
///
/// One month is shown at a time rather than one endless scroll. That is a
/// performance decision as much as a design one: these exports run to hundreds
/// of thousands of messages, and a single list of all of them makes the
/// scrollbar meaningless and any "jump to a date" gesture a guess. A month is a
/// unit people actually remember things in — you look for the week you were on
/// holiday, not for message 84,000.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  /// yyyymm key of the month on screen. Null until the first build resolves it
  /// to the most recent month, which is where people usually want to land.
  int? _month;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'No chat open',
          message: 'Import a chat to read it back.',
          actionLabel: 'Import a chat',
          onAction: () => context.go(Routes.import),
        ),
      );
    }

    final months = _MonthIndex.of(session.chat.messages);

    if (months.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const EmptyState(
          title: 'Nothing to show',
          message: 'This export has no readable messages in it.',
        ),
      );
    }

    final selected = _month ?? months.last.key;
    final month = months.firstWhere(
      (m) => m.key == selected,
      orElse: () => months.last,
    );
    final participants = session.chat.participants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Jump to a month',
            onPressed: () => _pickMonth(months, month.key),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _MonthStrip(
            months: months,
            selected: month.key,
            onSelect: (key) => setState(() => _month = key),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Text(
                  month.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Eyebrow('${Fmt.n(month.messages.length)} messages'),
              ],
            ),
          ),
          Expanded(
            child: _MonthBody(
              messages: month.messages,
              participants: participants,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(List<_Month> months, int current) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: SectionHeader('Jump to a month'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                // Newest first, matching how anyone scans back through a chat.
                itemCount: months.length,
                itemBuilder: (context, i) {
                  final month = months[months.length - 1 - i];
                  return ListTile(
                    selected: month.key == current,
                    selectedColor: AppColors.accent,
                    title: Text(month.label),
                    trailing: Text(Fmt.compact(month.messages.length)),
                    onTap: () => Navigator.of(context).pop(month.key),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _month = picked);
  }
}

// ------------------------------------------------------------------ grouping

class _Month {
  _Month(this.key, this.label);

  /// yyyymm, so months sort correctly as integers.
  final int key;
  final String label;
  final List<ChatMessage> messages = [];
}

abstract final class _MonthIndex {
  /// Groups messages into months in one pass, preserving chronological order.
  static List<_Month> of(List<ChatMessage> messages) {
    final months = <int, _Month>{};

    for (final message in messages) {
      final date = message.timestamp;
      final key = date.year * 100 + date.month;
      (months[key] ??= _Month(key, date.monthYear)).messages.add(message);
    }

    final ordered = months.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ordered;
  }
}

// ------------------------------------------------------------------- widgets

class _MonthStrip extends StatelessWidget {
  const _MonthStrip({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  final List<_Month> months;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: months.length,
        itemBuilder: (context, i) {
          final month = months[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(month.label),
              selected: month.key == selected,
              onSelected: (_) => onSelect(month.key),
            ),
          );
        },
      ),
    );
  }
}

/// One month, with a light divider whenever the day changes.
class _MonthBody extends StatelessWidget {
  const _MonthBody({required this.messages, required this.participants});

  final List<ChatMessage> messages;
  final List<String> participants;

  @override
  Widget build(BuildContext context) {
    // Rows are precomputed so the list stays lazy: the builder never has to
    // look at neighbouring messages to decide whether a day has changed.
    final rows = <_Row>[];
    var lastDay = 0;
    String? lastSender;

    for (final message in messages) {
      final day = message.timestamp.day;
      if (day != lastDay) {
        rows.add(_Row.day(message.timestamp));
        lastDay = day;
        lastSender = null;
      }
      rows.add(
        _Row.message(
          message,
          // Consecutive messages from the same person lose the name label, the
          // way they do in a real chat window.
          showSender: message.sender != lastSender,
        ),
      );
      lastSender = message.sender;
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row.date != null) return _DayDivider(date: row.date!);
        return _Bubble(
          message: row.message!,
          participants: participants,
          showSender: row.showSender,
        );
      },
    );
  }
}

class _Row {
  _Row.day(this.date)
      : message = null,
        showSender = false;
  _Row.message(this.message, {required this.showSender}) : date = null;

  final DateTime? date;
  final ChatMessage? message;
  final bool showSender;
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Text(date.longDate, style: theme.textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.participants,
    required this.showSender,
  });

  final ChatMessage message;
  final List<String> participants;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Text(
          message.body,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall,
        ),
      );
    }

    final index = participants.indexOf(message.sender ?? '');
    final colorIndex = index < 0 ? 0 : index;
    final color = AppColors.forParticipant(colorIndex);

    // The first participant sits on the left and everyone else on the right,
    // which reproduces the them-and-you shape of the original chat without
    // needing to know which name belonged to the phone's owner.
    final mine = colorIndex > 0;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine
                ? (isDark
                    ? AppColors.primaryDark.withOpacity(0.55)
                    : AppColors.lightGreen)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppTheme.radiusSmall),
              topRight: const Radius.circular(AppTheme.radiusSmall),
              bottomLeft: Radius.circular(mine ? AppTheme.radiusSmall : 4),
              bottomRight: Radius.circular(mine ? 4 : AppTheme.radiusSmall),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender && participants.length > 1) ...[
                Text(
                  message.sender ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 4),
              ],
              if (message.type == MessageType.text)
                Text(message.body, style: theme.textTheme.bodyLarge)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(message.type),
                      size: 16,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message.body.isEmpty
                            ? message.type.label
                            : message.body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  message.timestamp.timeOfDay,
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(MessageType type) => switch (type) {
        MessageType.image => Icons.photo_outlined,
        MessageType.video => Icons.videocam_outlined,
        MessageType.audio || MessageType.voiceNote => Icons.mic_none_rounded,
        MessageType.document => Icons.description_outlined,
        MessageType.sticker => Icons.emoji_emotions_outlined,
        MessageType.gif => Icons.gif_box_outlined,
        MessageType.contact => Icons.person_outline_rounded,
        MessageType.location => Icons.place_outlined,
        MessageType.deleted => Icons.block_rounded,
        MessageType.poll => Icons.poll_outlined,
        _ => Icons.attachment_rounded,
      };
}
