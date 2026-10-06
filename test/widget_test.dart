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
}
