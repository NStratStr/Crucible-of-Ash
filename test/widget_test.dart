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

    // Verify modal appeared with combat attributes and affinity matchup
    expect(find.text('HEXAGONAL AFFINITY MATCHUP'), findsOneWidget);
    expect(find.text('COMBAT ATTRIBUTES'), findsOneWidget);
  });
}
