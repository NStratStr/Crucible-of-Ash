import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/main.dart';

void main() {
  testWidgets('AshenCrucibleApp boots up and renders Tactical Arena', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Verify main components render
    expect(find.text('LORD VLADISLAV'), findsOneWidget);
    expect(find.text('Tactical Arena'), findsOneWidget);
    expect(find.text('Crucible Altar'), findsOneWidget);
    expect(find.text('Affinity Codex'), findsOneWidget);
  });
}
