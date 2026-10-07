import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/campaign/blood_altar_dialog.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/shared/models/expedition_boon.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

UnitEntity buildBoonTestUnit({
  required String id,
  required String name,
  required Archetype archetype,
  int hp = 1000,
  int attack = 200,
  int defense = 100,
  double turnMeter = 0.0,
}) {
  return UnitEntity(
    id: id,
    speciesId: 'proto_species',
    name: name,
    generation: 1,
    archetype: archetype,
    slot: FormationSlot.front1,
    level: 10,
    maxLevel: 30,
    currentHp: hp,
    maxHp: hp,
    attack: attack,
    defense: defense,
    speed: 100,
    critRate: 0.0, // avoid crit RNG in comparison
    critDamage: 1.50,
    turnMeter: turnMeter,
    nativeTraitId: 'none',
    lineageAncestors: const [],
  );
}

void main() {
  group('Expedition Boon & Blood Altar Covenant Tests', () {
    testWidgets('BloodAltarDialog displays Sanguine Covenant option', (WidgetTester tester) async {
      BloodAltarChoice? chosen;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosen = await BloodAltarDialog.show(ctx, squadLivingCount: 5);
                },
                child: const Text('OPEN ALTAR'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN ALTAR'));
      await tester.pumpAndSettle();

      expect(find.text('ALTAR OF ANCESTRAL BLOOD'), findsOneWidget);
      expect(find.text('COVENANT OF SANGUINE & ASH (SACRIFICE 30% HP)'), findsOneWidget);
      expect(find.textContaining('+15% Squad ATK'), findsOneWidget);

      await tester.tap(find.text('COVENANT OF SANGUINE & ASH (SACRIFICE 30% HP)'));
      await tester.pumpAndSettle();

      expect(chosen, equals(BloodAltarChoice.covenantBlessing));
    });

    test('CombatResolutionService applies sanguine covenant attack bonus', () {
      final hero = buildBoonTestUnit(id: 'hero', name: 'Hero', archetype: Archetype.juggernaut, turnMeter: 100.0);
      final enemy = buildBoonTestUnit(id: 'enemy', name: 'Enemy', archetype: Archetype.juggernaut, hp: 2000);

      // Standard run without boon
      final standardTick = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [enemy],
      );
      standardTick.advanceTick();
      final standardCombat = CombatResolutionService(
        tickManager: standardTick,
        rng: Random(100),
        activeBoons: const {},
      );
      final standardResult = standardCombat.executeBasicAttack(
        targetUnitId: 'enemy',
        autoResumeTickEngine: false,
      );

      // Boon run with Sanguine Covenant
      final boonTick = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [enemy],
      );
      boonTick.advanceTick();
      final boonCombat = CombatResolutionService(
        tickManager: boonTick,
        rng: Random(100),
        activeBoons: const {ExpeditionBoon.sanguineCovenant},
      );
      final boonResult = boonCombat.executeBasicAttack(
        targetUnitId: 'enemy',
        autoResumeTickEngine: false,
      );

      // Sanguine Covenant (+15% Attack) deals strictly more damage
      expect(boonResult.damageDealt, greaterThan(standardResult.damageDealt));
    });

    test('CombatResolutionService applies vitality wellspring lifesteal bonus', () {
      final damagedHero = buildBoonTestUnit(id: 'hero', name: 'Hero', archetype: Archetype.juggernaut, hp: 300, turnMeter: 100.0);
      final enemy = buildBoonTestUnit(id: 'enemy', name: 'Enemy', archetype: Archetype.juggernaut, hp: 2000);

      final boonTick = InitiativeTickManager(
        initialAllies: [damagedHero],
        initialEnemies: [enemy],
      );
      boonTick.advanceTick();
      final boonCombat = CombatResolutionService(
        tickManager: boonTick,
        rng: Random(100),
        activeBoons: const {ExpeditionBoon.vitalityWellspring},
      );
      final boonResult = boonCombat.executeBasicAttack(
        targetUnitId: 'enemy',
        autoResumeTickEngine: false,
      );

      // Vitality Wellspring gives 10% lifesteal
      expect(boonResult.lifestealRecovered, greaterThan(0));
    });
  });
}
