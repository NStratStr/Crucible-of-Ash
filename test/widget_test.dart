import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/main.dart';

void main() {
  testWidgets('AshenCrucibleApp boots up and renders main navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Verify main navigation bar items render
    expect(find.text('Campaign Map'), findsOneWidget);
    expect(find.text('Battle Arena'), findsOneWidget);
    expect(find.text('Crucible Altar'), findsOneWidget);
    expect(find.text('Relic Forge'), findsOneWidget);
    expect(find.text('Brigade Roster'), findsOneWidget);
    expect(find.text('Affinity Codex'), findsOneWidget);
  });

  testWidgets('Tapping a unit in Brigade Roster opens PedigreeInspectorDialog', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Tap Brigade Roster tab
    await tester.tap(find.text('Brigade Roster'));
    await tester.pumpAndSettle();

    // Verify roster header
    expect(find.text('YOUR LINEAGE ROSTER'), findsOneWidget);
    expect(find.text('TAP UNIT TO INSPECT PEDIGREE'), findsOneWidget);

    // Tap the first unit card in roster
    await tester.tap(find.text('Feral War-Hound Alpha').first);
    await tester.pumpAndSettle();

    // Verify modal appeared with level progression and affinity matchup
    expect(find.text('HEXAGONAL AFFINITY MATCHUP'), findsOneWidget);
    expect(find.text('LEVEL PROGRESSION'), findsOneWidget);
  });

  testWidgets('Appointing a new Commander via GeneralSelectionDialog updates brigade profile', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Go to Brigade Roster
    await tester.tap(find.text('Brigade Roster'));
    await tester.pumpAndSettle();

    // Initially Lord Vladislav is active
    expect(find.text('LORD VLADISLAV'), findsOneWidget);

    // Tap SWITCH button
    await tester.tap(find.text('SWITCH'));
    await tester.pumpAndSettle();

    // Verify Phylactery of Commanders modal opened
    expect(find.text('PHYLACTERY OF COMMANDERS'), findsOneWidget);
    expect(find.text('LADY VALERIA'), findsOneWidget);

    // Tap APPOINT for Lady Valeria
    await tester.tap(find.text('APPOINT').first);
    await tester.pumpAndSettle();

    // Verify Commander switched to Lady Valeria
    expect(find.text('LADY VALERIA'), findsOneWidget);
  });
}

