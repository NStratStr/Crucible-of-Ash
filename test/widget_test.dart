import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/safe_teleport_modal.dart';
import 'package:ashen_crucible/shared/widgets/app_shell.dart';
import 'package:ashen_crucible/main.dart';

void main() {
  testWidgets('AshenCrucibleApp boots up and renders main navigation tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Verify main navigation bar items render
    expect(find.text('Sanctuary'), findsWidgets);
    expect(find.text('Campaign'), findsWidgets);
    expect(find.text('Trials'), findsWidgets);
    expect(find.text('Blood Altar'), findsWidgets);
    expect(find.text('Relic Forge'), findsWidgets);
    expect(find.text('Roster'), findsWidgets);
  });

  testWidgets('Tapping Roster tab opens Lineage Roster', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Roster'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('BRIGADE LINEAGE ROSTER'), findsOneWidget);
  });

  testWidgets('Opening Endgame Gauntlet renders trials', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AshenCrucibleApp(enableAutoBattle: false));
    await tester.pump(const Duration(milliseconds: 200));

    // Tap ENDGAME GAUNTLET button on Campaign Map
    expect(find.text('ENDGAME GAUNTLET'), findsOneWidget);
    await tester.tap(find.text('ENDGAME GAUNTLET'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify modal appeared with trials
    expect(find.text('THE ENDGAME GAUNTLET'), findsOneWidget);
    expect(find.text('THE ASHEN WORLD TITAN'), findsOneWidget);
  });

  testWidgets('SafeTeleportModal renders run haul and confirms extraction', (WidgetTester tester) async {
    bool extracted = false;
    bool continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => SafeTeleportModal.show(
                ctx,
                accumulatedIchor: 350,
                accumulatedOre: 45,
                accumulatedSigils: 1,
                onConfirmExtraction: () => extracted = true,
                onContinueDelve: () => continued = true,
              ),
              child: const Text('OPEN TELEPORT MODAL'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('OPEN TELEPORT MODAL'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('RUNIC TELEPORT CIRCLE'), findsOneWidget);
    expect(find.text('SAFE DUNGEON EXTRACTION THRESHOLD'), findsOneWidget);
    expect(find.text('+350'), findsOneWidget);
    expect(find.text('+45'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('EXTRACT (100% LOOT)'), findsOneWidget);
    expect(find.text('PRESS DEEPER'), findsOneWidget);

    // Tap EXTRACT
    await tester.tap(find.text('EXTRACT (100% LOOT)'));
    await tester.pumpAndSettle();

    expect(extracted, isTrue);
    expect(continued, isFalse);
  });

  testWidgets('CampaignMapScreen renders linear stage ladder and allows toggling to expedition mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AshenCrucibleApp(enableAutoBattle: false));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Linear Story mode rendered by default
    expect(find.text('STORY'), findsOneWidget);
    expect(find.text('EXPEDITION'), findsOneWidget);
    expect(find.text('STAGE 1-1'), findsOneWidget);
    expect(find.text('ASHEN OUTPOST'), findsOneWidget);

    // Toggle to EXPEDITION mode
    await tester.tap(find.text('EXPEDITION'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify expedition delve node graph rendered
    expect(find.text('Sunken Trench'), findsWidgets);

    // Toggle back to STORY mode
    await tester.tap(find.text('STORY'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('STAGE 1-1'), findsOneWidget);
  });

  testWidgets('Phone held in portrait (393x852) automatically loads and locks UI in landscape (852x393)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(const AshenCrucibleApp(enableAutoBattle: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RotatedBox), findsWidgets);
    final shellContext = tester.element(find.byType(AppShell));
    final mq = MediaQuery.of(shellContext);
    expect(mq.size.width, equals(852));
    expect(mq.size.height, equals(393));
    // Physical top (59px Dynamic Island) maps to Landscape Left (+6px clearance), Physical bottom (34px) maps to Landscape Right
    expect(mq.padding.left, equals(65));
    expect(mq.padding.right, equals(34));
  });
}
