import 'package:flutter_test/flutter_test.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

void main() {
  late LocalMatchDatabase db;

  setUp(() {
    db = LocalMatchDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('shell builds', (tester) async {
    await tester.pumpWidget(RefereeApp(database: db));
    await tester.pumpAndSettle();
    expect(find.text('Matches'), findsOneWidget);
  });

  testWidgets('New Match → Live Match → Kick-off → Goal', (tester) async {
    await tester.pumpWidget(RefereeApp(database: db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Match'));
    await tester.pumpAndSettle();
    expect(find.text('Match setup'), findsOneWidget);

    await tester.tap(find.text('Live Match'));
    await tester.pumpAndSettle();
    expect(find.text('Kick-off'), findsOneWidget);
    expect(find.textContaining('Ready'), findsWidgets);

    await tester.tap(find.text('Kick-off'));
    await tester.pumpAndSettle();
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Goal'), findsWidgets);
    final stored = await db.listNewestFirst();
    expect(stored, hasLength(1));
    expect(stored.single.events, hasLength(1));
    expect(stored.single.score.home, 1);
  });

  testWidgets('English fallback localizations load', (tester) async {
    await tester.pumpWidget(RefereeApp(database: db));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.text('Matches')),
    );
    expect(l10n.newMatch, 'New Match');
  });
}
