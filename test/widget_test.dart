import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuntius/core/theme/app_theme.dart';
import 'package:nuntius/core/widgets/empty_state.dart';
import 'package:nuntius/core/widgets/eyebrow.dart';
import 'package:nuntius/core/widgets/stat_tile.dart';
import 'package:nuntius/core/widgets/tick_progress.dart';
import 'package:nuntius/core/widgets/word_cloud.dart';
import 'package:nuntius/models/stat_types.dart';
import 'package:nuntius/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _host(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('StatTile shows its label and value', (tester) async {
    await tester.pumpWidget(
      await _host(
        const SizedBox(
          width: 200,
          height: 160,
          child: StatTile(
            label: 'Messages',
            value: '1,204',
            detail: 'since January',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('1,204'), findsOneWidget);
    expect(find.text('since January'), findsOneWidget);
  });

  testWidgets('StatTile animates up to a numeric value', (tester) async {
    await tester.pumpWidget(
      await _host(
        const SizedBox(
          width: 200,
          height: 160,
          child: StatTile(label: 'Words', value: '500', numericValue: 500),
        ),
      ),
    );

    // Part-way through the count-up the number should not be the target yet.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('500'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('500'), findsOneWidget);
  });

  testWidgets('EmptyState offers its action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      await _host(
        EmptyState(
          title: 'Nothing here yet',
          message: 'Import a chat to get started.',
          actionLabel: 'Import a chat',
          onAction: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet'), findsOneWidget);
    await tester.tap(find.text('Import a chat'));
    expect(tapped, isTrue);
  });

  testWidgets('WordCloud renders the words it is given', (tester) async {
    await tester.pumpWidget(
      await _host(
        const SizedBox(
          width: 320,
          height: 300,
          child: WordCloud(
            words: [
              NamedValue('biryani', 40),
              NamedValue('deadline', 22),
              NamedValue('rain', 9),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('biryani'), findsOneWidget);
    expect(find.text('deadline'), findsOneWidget);
    expect(find.text('rain'), findsOneWidget);
  });

  testWidgets('WordCloud sizes the most frequent word largest', (tester) async {
    await tester.pumpWidget(
      await _host(
        const SizedBox(
          width: 320,
          height: 300,
          child: WordCloud(
            words: [NamedValue('often', 100), NamedValue('rarely', 1)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double sizeOf(String word) =>
        tester.widget<Text>(find.text(word)).style!.fontSize!;

    expect(sizeOf('often'), greaterThan(sizeOf('rarely')));
  });

  testWidgets('Eyebrow uppercases its label', (tester) async {
    await tester.pumpWidget(await _host(const Eyebrow('busiest hour')));
    await tester.pumpAndSettle();

    expect(find.text('BUSIEST HOUR'), findsOneWidget);
  });

  testWidgets('TickProgress paints one mark per card', (tester) async {
    await tester.pumpWidget(
      await _host(
        const SizedBox(
          width: 300,
          height: 40,
          child: TickProgress(count: 6, current: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TickProgress), findsOneWidget);
  });
}
