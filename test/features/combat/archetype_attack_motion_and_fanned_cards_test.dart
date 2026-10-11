import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/wargaming_spell_card.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Tactile Archetype Attack Animations & Fanned Hand Tests', () {
    const allyAssassin = UnitEntity(
      id: 'assassin_1',
      speciesId: 'crimson_flayer',
      name: 'Crimson Flayer',
      generation: 1,
      archetype: Archetype.assassin,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 30,
      currentHp: 800,
      maxHp: 800,
      attack: 160,
      defense: 70,
      speed: 120,
      resist: 30,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyMarksman = UnitEntity(
      id: 'marksman_1',
      speciesId: 'ashen_ranger',
      name: 'Ashen Ranger',
      generation: 1,
      archetype: Archetype.marksman,
      slot: FormationSlot.back1,
      level: 10,
      maxLevel: 30,
      currentHp: 750,
      maxHp: 750,
      attack: 150,
      defense: 60,
      speed: 110,
      resist: 35,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyOccultist = UnitEntity(
      id: 'occultist_1',
      speciesId: 'solar_hierophant',
      name: 'Solar Hierophant',
      generation: 1,
      archetype: Archetype.occultist,
      slot: FormationSlot.back2,
      level: 10,
      maxLevel: 30,
      currentHp: 700,
      maxHp: 700,
      attack: 140,
      defense: 65,
      speed: 95,
      resist: 60,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyJuggernaut = UnitEntity(
      id: 'footman_1',
      speciesId: 'iron_footman',
      name: 'Iron Footman',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front2,
      level: 10,
      maxLevel: 30,
      currentHp: 1200,
      maxHp: 1200,
      attack: 110,
      defense: 120,
      speed: 80,
      resist: 50,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const enemyHusk = UnitEntity(
      id: 'husk_1',
      speciesId: 'rotting_husk',
      name: 'Rotting Husk',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 30,
      currentHp: 1000,
      maxHp: 1000,
      attack: 100,
      defense: 80,
      speed: 85,
      resist: 30,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    testWidgets('Fanned hand renders collectible WargamingSpellCard instances in active combat', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tickManager = InitiativeTickManager(
        initialAllies: [allyJuggernaut],
        initialEnemies: [enemyHusk],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
      );
      commandService.initializeGrimoire();

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
              startInPreBattleSetup: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Collectible WargamingSpellCards render fanned in the player command dock
      expect(find.byType(WargamingSpellCard), findsWidgets);
      expect(find.text('BURN'), findsOneWidget);
      expect(find.byType(Draggable<GeneralOrderDefinition>), findsWidgets);

      tickManager.pause();
    });

    testWidgets('WargamingSpellCard resolves correct spell image asset based on order theme', (tester) async {
      const siphonOrder = GeneralOrderDefinition(
        id: 'siphon_vitality',
        name: 'SIPHON',
        focusCost: 1,
        description: 'Drain vitality.',
        icon: Icons.water_drop,
      );
      const revivalOrder = GeneralOrderDefinition(
        id: 'sanguine_revival',
        name: 'REVIVAL',
        focusCost: 4,
        description: 'Revive ally.',
        icon: Icons.healing,
      );
      const wardOrder = GeneralOrderDefinition(
        id: 'sanguine_ward',
        name: 'WARD',
        focusCost: 2,
        description: 'Armor barrier.',
        icon: Icons.shield,
      );
      const executeOrder = GeneralOrderDefinition(
        id: 'feast_of_ruin',
        name: 'EXECUTE',
        focusCost: 3,
        description: 'Execute foe.',
        icon: Icons.dangerous,
      );

      expect(WargamingSpellCard.resolveSpellAsset(siphonOrder), contains('Sanguine Siphon.jpg'));
      expect(WargamingSpellCard.resolveSpellAsset(revivalOrder), contains('Sanguine Revival.jpg'));
      expect(WargamingSpellCard.resolveSpellAsset(wardOrder), contains('Ash Armour.jpg'));
      expect(WargamingSpellCard.resolveSpellAsset(executeOrder), contains('Soul Shatter.jpg'));
    });
  });
}
