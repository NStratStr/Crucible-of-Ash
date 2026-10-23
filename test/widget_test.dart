import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/safe_teleport_modal.dart';
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
    await tester.tap(find.text('Lord Vladislav').first);
    await tester.pumpAndSettle();

    // Verify modal appeared with level progression and affinity matchup
    expect(find.text('HEXAGONAL AFFINITY MATCHUP', skipOffstage: false), findsOneWidget);
    expect(find.text('LEVEL PROGRESSION'), findsOneWidget);
  });

  testWidgets('Appointing a new Commander via GeneralSelectionDialog updates brigade profile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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

  testWidgets('Opening Endgame Gauntlet renders trials and allows engaging World Titan', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp(enableAutoBattle: false));
    await tester.pump();

    // On Campaign Map, tap ENDGAME GAUNTLET button
    expect(find.text('ENDGAME GAUNTLET'), findsOneWidget);
    await tester.tap(find.text('ENDGAME GAUNTLET'));
    await tester.pumpAndSettle();

    // Verify modal appeared with trials
    expect(find.text('THE ENDGAME GAUNTLET'), findsOneWidget);
    expect(find.text('THE ASHEN WORLD TITAN'), findsOneWidget);

    // Tap ENGAGE TRIAL for World Titan
    await tester.tap(find.text('ENGAGE TRIAL').first);
    await tester.pumpAndSettle();

    // Verify engaged into Battle Arena
    expect(find.textContaining('THE ASHEN WORLD TITAN'), findsOneWidget);
  });

  testWidgets('Tapping Citadel War Room Home button opens HomeScreen and navigates to Crucible', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Tap Home icon in Campaign Map AppBar
    final homeButton = find.byTooltip('Citadel War Room (Home)');
    expect(homeButton, findsOneWidget);
    await tester.tap(homeButton);
    await tester.pumpAndSettle();

    // Verify Home Screen modal opened
    expect(find.text('COMMAND CITADEL • CHAPTER HEADQUARTERS'), findsOneWidget);
    expect(find.text('RESONANCE BEACON'), findsOneWidget);
    expect(find.text('THE CRUCIBLE ALTAR'), findsWidgets);
    expect(find.text('THE RELIC FORGE'), findsWidgets);

    // Tap THE CRUCIBLE ALTAR interactive building
    await tester.tap(find.text('THE CRUCIBLE ALTAR').first);
    await tester.pumpAndSettle();

    // Verify switched to Crucible Altar screen
    expect(find.text('THE CRUCIBLE OF BLOOD'), findsOneWidget);
  });

  testWidgets('Tapping Settings opens Imperial Archives with Telco & Connectivity options', (WidgetTester tester) async {
    await tester.pumpWidget(const AshenCrucibleApp());
    await tester.pump();

    // Tap Home button to open Home Screen
    await tester.tap(find.byTooltip('Citadel War Room (Home)'));
    await tester.pumpAndSettle();

    // Tap SETTINGS button in Home Screen header
    await tester.tap(find.text('SETTINGS').first);
    await tester.pumpAndSettle();

    // Verify Imperial Archives & Settings dialog opened
    expect(find.text('IMPERIAL ARCHIVES & SETTINGS'), findsOneWidget);
    expect(find.text('TELCO & DATA'), findsOneWidget);

    // Switch to Telco & Data tab
    await tester.tap(find.text('TELCO & DATA'));
    await tester.pumpAndSettle();

    // Verify telco settings rendered
    expect(find.text('Telco Low-Data Mode'), findsOneWidget);
    expect(find.text('Active Carrier Profile'), findsOneWidget);
    expect(find.text('Offline Local Storage Cache'), findsOneWidget);
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

  testWidgets('CampaignMapScreen renders linear stage ladder and allows toggling to catacomb dungeon', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AshenCrucibleApp(enableAutoBattle: false));
    await tester.pumpAndSettle();

    // Verify Linear Campaign mode rendered by default
    expect(find.text('CAMPAIGN'), findsOneWidget);
    expect(find.text('DUNGEON'), findsOneWidget);
    expect(find.text('STAGE 1-1'), findsOneWidget);
    expect(find.text('ASHEN OUTPOST'), findsOneWidget);

    // Toggle to DUNGEON mode
    await tester.tap(find.text('DUNGEON'));
    await tester.pumpAndSettle();

    // Verify catacomb delve node graph rendered
    expect(find.text('Sunken Trench'), findsWidgets);

    // Toggle back to CAMPAIGN mode
    await tester.tap(find.text('CAMPAIGN'));
    await tester.pumpAndSettle();

    expect(find.text('STAGE 1-1'), findsOneWidget);
  });
}


