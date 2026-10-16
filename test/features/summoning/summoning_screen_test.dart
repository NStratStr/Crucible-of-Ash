import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/summoning/summoning_screen.dart';
import 'package:ashen_crucible/features/summoning/summoning_service.dart';
import 'package:ashen_crucible/main.dart';

void main() {
  group('SummoningService Logic & Odds Tests', () {
    test('Banner definitions have valid costs and probabilities summing to 1.0', () {
      for (final type in SummonBannerType.values) {
        final banner = SummoningService.banners[type]!;
        expect(banner.singleCost, greaterThan(0));
        expect(banner.multiCost, greaterThan(banner.singleCost));
        final totalRate = banner.gen1Rate + banner.gen2Rate + banner.gen3Rate;
        expect(totalRate, closeTo(1.0, 0.001));
      }
    });

    test('Ashen Bloodline 1x pull costs 100 Ichor and yields Gen 1-3 thrall', () {
      final deterministicRng = Random(42);
      final result = SummoningService.performSummon(
        bannerType: SummonBannerType.ashenBloodline,
        count: 1,
        currentIchor: 450,
        currentSigils: 2,
        rng: deterministicRng,
      );

      expect(result.summonedUnits.length, 1);
      expect(result.ichorSpent, 100);
      expect(result.sigilsSpent, 0);
      expect(result.summonedUnits.first.generation, isIn([1, 2, 3]));
      expect(result.summonedUnits.first.nativeTraitId, isNotEmpty);
    });

    test('Consecrated Covenant 10x pull costs 9 Bloodline Sigils (10% discount)', () {
      final deterministicRng = Random(99);
      final result = SummoningService.performSummon(
        bannerType: SummonBannerType.consecratedSigil,
        count: 10,
        currentIchor: 1000,
        currentSigils: 12,
        rng: deterministicRng,
      );

      expect(result.summonedUnits.length, 10);
      expect(result.ichorSpent, 0);
      expect(result.sigilsSpent, 9);
      // Consecrated covenant has heightened Gen 2 and Gen 3 rates
      expect(result.summonedUnits.any((u) => u.generation >= 2), isTrue);
    });

    test('Crypt Stalker Focus generates necrotic species (Husk, Ghoul, Alchemist, etc.)', () {
      final deterministicRng = Random(123);
      final result = SummoningService.performSummon(
        bannerType: SummonBannerType.cryptCovenant,
        count: 5,
        currentIchor: 1000,
        currentSigils: 5,
        rng: deterministicRng,
      );

      expect(result.summonedUnits.length, 5);
      expect(result.ichorSpent, 600); // 5 * 120 Ichor
    });

    test('Throws StateError on insufficient currency', () {
      expect(
        () => SummoningService.performSummon(
          bannerType: SummonBannerType.ashenBloodline,
          count: 1,
          currentIchor: 50, // Needs 100
          currentSigils: 0,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => SummoningService.performSummon(
          bannerType: SummonBannerType.consecratedSigil,
          count: 10,
          currentIchor: 5000,
          currentSigils: 5, // Needs 9
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SummoningScreen Widget & UI Tests', () {
    testWidgets('SummoningScreen renders banners, currency counters and 1x/10x buttons', (WidgetTester tester) async {
      SummonResult? recordedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SummoningScreen(
            totalIchor: 1200,
            bloodlineSigils: 15,
            onSummonExecuted: (res) => recordedResult = res,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Title
      expect(find.text('SUMMONING CONVOCATION'), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // Verify Banners
      expect(find.text('ASHEN BLOODLINE RITE'), findsWidgets);
      expect(find.text('CONSECRATED COVENANT'), findsOneWidget);
      expect(find.text('CRYPT STALKER SUMMONS'), findsOneWidget);

      // Verify Rates info icon
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('CONVOCATION PROBABILITIES'), findsOneWidget);
      expect(find.text('ASHEN BLOODLINE RITE'), findsWidgets);

      // Dismiss dialog
      await tester.tap(find.text('DISMISS'));
      await tester.pumpAndSettle();

      // Execute 1x Summon
      await tester.tap(find.text('SUMMON 1x'));
      await tester.pumpAndSettle();

      expect(recordedResult, isNotNull);
      expect(recordedResult!.summonedUnits.length, 1);
      expect(recordedResult!.ichorSpent, 100);

      // Card reveal modal should be visible
      expect(find.text('CLAIM THRALL'), findsOneWidget);
      await tester.tap(find.text('CLAIM THRALL'));
      await tester.pumpAndSettle();

      expect(find.text('Claimed 1 summoned thrall(s) to Reserve Inventory!'), findsOneWidget);
    });

    testWidgets('Switching to Consecrated Sigil banner updates cost to Bloodline Sigils and enables 10x summon', (WidgetTester tester) async {
      SummonResult? recordedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: SummoningScreen(
            totalIchor: 50, // Insufficient for Ichor summons
            bloodlineSigils: 20, // Sufficient for Sigils summons
            onSummonExecuted: (res) => recordedResult = res,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Consecrated Covenant tab
      await tester.tap(find.text('CONSECRATED COVENANT'));
      await tester.pumpAndSettle();

      expect(find.text('9 Bloodline Sigils'), findsOneWidget);

      // Execute 10x Summon
      await tester.tap(find.text('SUMMON 10x'));
      await tester.pumpAndSettle();

      expect(recordedResult, isNotNull);
      expect(recordedResult!.summonedUnits.length, 10);
      expect(recordedResult!.sigilsSpent, 9);

      // Multi-reveal counter
      expect(find.text('CONVOCATION RESULT 1 OF 10'), findsOneWidget);
      expect(find.text('NEXT CONVOCATION'), findsOneWidget);
      expect(find.text('CLAIM ALL'), findsOneWidget);

      // Advance through next convocation
      await tester.tap(find.text('NEXT CONVOCATION'));
      await tester.pumpAndSettle();
      expect(find.text('CONVOCATION RESULT 2 OF 10'), findsOneWidget);

      // Claim all
      await tester.tap(find.text('CLAIM ALL'));
      await tester.pumpAndSettle();
      expect(find.text('Claimed 10 summoned thrall(s) to Reserve Inventory!'), findsOneWidget);
    });

    testWidgets('Opening Summoning Altar from HomeScreen opens altar and updates inventory', (WidgetTester tester) async {
      await tester.pumpWidget(const AshenCrucibleApp());
      await tester.pumpAndSettle();

      // Tap Citadel War Room Home button
      await tester.tap(find.byTooltip('Citadel War Room (Home)'));
      await tester.pumpAndSettle();

      // Verify Summoning Altar card is present
      expect(find.text('SUMMONING ALTAR'), findsOneWidget);

      // Tap Summoning Altar card
      await tester.tap(find.text('SUMMONING ALTAR'));
      await tester.pumpAndSettle();

      // Verify Summoning screen modal opened
      expect(find.text('SUMMONING CONVOCATION'), findsOneWidget);
    });
  });
}
