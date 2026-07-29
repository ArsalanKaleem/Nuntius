import 'package:flutter/material.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/chat_message.dart';
import '../../../models/parsed_chat.dart';

/// Full-text search across the imported chat.
///
/// Runs a single linear scan over the in-memory message list — no index to
/// build, nothing extra to store on disk. The scan counts every match but
/// collects only the first few hundred, so a common word in a 250k-message
/// chat does not try to build a quarter of a million widgets.
class SearchTab extends StatefulWidget {
  const SearchTab({super.key, required this.chat});
  final ParsedChat chat;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  String _query = '';
  String? _sender;
  int? _year;

  late final List<int> _years = () {
    final years = <int>{};
    for (final message in widget.chat.messages) {
      years.add(message.timestamp.year);
    }
    final sorted = years.toList()..sort();
    return sorted;
  }();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One pass: the true match count and the capped list of rows to render.
  ({List<ChatMessage> rows, int total}) _search() {
    final query = _query.trim().toLowerCase();
    final rows = <ChatMessage>[];
    var total = 0;

    for (final message in widget.chat.messages) {
      if (message.isSystem) continue;
      if (_sender != null && message.sender != _sender) continue;
      if (_year != null && message.timestamp.year != _year) continue;
      if (query.isNotEmpty && !message.body.toLowerCase().contains(query)) {
        continue;
      }
      total++;
      if (rows.length < 300) rows.add(message);
    }
    return (rows: rows, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final search = _search();
    final results = search.rows;
    final total = search.total;
    final filtering =
        _query.trim().isNotEmpty || _sender != null || _year != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search messages',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final name in widget.chat.participants)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(Fmt.name(name, max: 14)),
                    selected: _sender == name,
                    onSelected: (selected) =>
                        setState(() => _sender = selected ? name : null),
                  ),
                ),
              for (final year in _years)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$year'),
                    selected: _year == year,
                    onSelected: (selected) =>
                        setState(() => _year = selected ? year : null),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                filtering
                    ? '${Fmt.n(total)} matches'
                    : '${Fmt.n(widget.chat.messageCount)} messages',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              if (total > results.length)
                Text(
                  'showing first ${results.length}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? NoResults(query: _query.trim().isEmpty ? null : _query.trim())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _MessageRow(
                    message: results[i],
                    participants: widget.chat.participants,
                    query: _query.trim(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.participants,
    required this.query,
  });

  final ChatMessage message;
  final List<String> participants;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = participants.indexOf(message.sender ?? '');
    final color = AppColors.forParticipant(index < 0 ? 0 : index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.sender ?? 'System',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
              const SizedBox(width: 8),
              Text(
                '${message.timestamp.shortDate} · '
                '${message.timestamp.timeOfDay}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Highlighted(
            text: message.type == MessageType.text
                ? message.body
                : message.type.label,
            query: query,
            style: theme.textTheme.bodyLarge!,
          ),
        ],
      ),
    );
  }
}

/// Bolds the matched span so the reason a message came back is obvious.
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.text,
    required this.query,
    required this.style,
  });

  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: 6,
          overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
      );
      start = index + query.length;
    }

    return RichText(
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: spans),
    );
  }
}
