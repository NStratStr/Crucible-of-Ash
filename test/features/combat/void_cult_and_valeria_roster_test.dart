import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/features/summoning/summoning_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Option C: Lady Valeria & Occult Void Cult Expansion Tests (GDD §9 / Recipe 2 & §12.4)', () {
    late InitiativeTickManager tickManager;
    late GeneralCommandService valeriaService;

    setUp(() {
      tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createAshLegionPlayerSquad(),
        initialEnemies: StarterBrigades.createCryptStalkersEnemySquad(),
      );

      valeriaService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
        initialFocus: 7,
        maxFocus: 7,
      );
    });

    test('Occult Void Cult squad creation correctly maps all 5 units to Occult Void Cult faction with obsidian plinths', () {
      final voidSquad = StarterBrigades.createVoidCultSquad();
      expect(voidSquad.length, equals(5));

      final names = voidSquad.map((u) => u.name).toList();
      expect(names, contains('Void-Bound Thrall'));
      expect(names, contains('Shadow Flayer'));
      expect(names, contains('Acolyte Slinger'));
      expect(names, contains('Cultist Apprentice'));
      expect(names, contains('Chanter of the Void'));

      for (final unit in voidSquad) {
        expect(unit.factionName, equals('Occult Void Cult'));
        expect(unit.faction, equals('Occult Void Cult'));
        expect(unit.plinthMaterial, equals(PlinthMaterial.obsidian));
      }
    });

    test('SummoningService.voidCovenant banner summons Occult Void Cult specialists', () {
      final banner = SummoningService.banners[SummonBannerType.voidCovenant]!;
      expect(banner.title, equals('VOID INCURSION & RIFT GLASS'));
      expect(banner.usesSigils, isTrue);
      expect(banner.singleCost, equals(1));
      expect(banner.multiCost, equals(9));
      expect(banner.gen1Rate + banner.gen2Rate + banner.gen3Rate, closeTo(1.0, 0.001));

      final result = SummoningService.performSummon(
        bannerType: SummonBannerType.voidCovenant,
        count: 5,
        currentIchor: 0,
        currentSigils: 10,
        rng: Random(42),
      );

      expect(result.summonedUnits.length, equals(5));
      for (final unit in result.summonedUnits) {
        expect(unit.factionName, equals('Occult Void Cult'));
        expect(unit.plinthMaterial, equals(PlinthMaterial.obsidian));
      }
    });

    test('Lady Valeria default Grimoire deck has exactly 10 cards and includes new sun-scorched holy slips', () {
      valeriaService.initializeGrimoire();
      expect(valeriaService.deckLimit, equals(10));
      expect(valeriaService.hand.length, equals(3));
      expect(valeriaService.grimoireDeck.length, equals(7));

      final pool = GeneralCommandService.getAvailableOrderPoolForGeneral(GeneralType.valeria);
      final poolIds = pool.map((o) => o.id).toSet();
      expect(poolIds, contains('solar_aegis'));
      expect(poolIds, contains('purging_light'));
      expect(poolIds, contains('dawn_resurgence'));
      expect(poolIds, contains('hallowed_ground'));
      expect(poolIds, contains('stand_resolute'));
      expect(poolIds, contains('retributive_stride'));
      expect(poolIds, contains('smite_the_wicked'));
    });

    test('Lady Valeria: Solar Aegis (2 Focus) grants 400 Aegis Shield and cleanses debuff', () {
      final ally = tickManager.allies.first;
      // Add a bleed debuff to the ally
      final debuffedAlly = ally.copyWith(
        activeEffects: [
          const StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 30),
        ],
      );
      tickManager = InitiativeTickManager(
        initialAllies: [debuffedAlly, ...tickManager.allies.sublist(1)],
        initialEnemies: tickManager.enemies,
      );
      valeriaService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
        initialFocus: 7,
        maxFocus: 7,
      );

      final res = valeriaService.executeSolarAegis(debuffedAlly.id);
      expect(res.focusSpent, equals(2));
      expect(valeriaService.currentFocus, equals(5));

      final updatedAlly = tickManager.allies.firstWhere((a) => a.id == ally.id);
      expect(updatedAlly.activeEffects.any((e) => e.type == StatusEffectType.bleed), isFalse);
      expect(updatedAlly.activeEffects.any((e) => e.type == StatusEffectType.shield), isTrue);
    });

    test('Lady Valeria: Purging Light (2 Focus) inflicts Holy damage + bonus true damage based on target armor', () {
      valeriaService.upgradePhylactery(GeneralType.valeria); // Rank 2
      final enemy = tickManager.enemies.first;
      final initialHp = enemy.currentHp;

      final res = valeriaService.executePurgingLight(enemy.id);
      expect(res.focusSpent, equals(2));

      final updatedEnemy = tickManager.enemies.firstWhere((e) => e.id == enemy.id);
      expect(updatedEnemy.currentHp, lessThan(initialHp));
      expect(res.summary, contains('Purging Light'));
    });

    test('Lady Valeria: Dawn Resurgence (3 Focus) revives fallen ally with 50% HP and fortifies Vanguard', () {
      valeriaService.upgradePhylactery(GeneralType.valeria);
      valeriaService.upgradePhylactery(GeneralType.valeria); // Rank 3
      final ally = tickManager.allies.first;
      final fallenAlly = ally.copyWith(currentHp: 0);

      tickManager = InitiativeTickManager(
        initialAllies: [fallenAlly, ...tickManager.allies.sublist(1)],
        initialEnemies: tickManager.enemies,
      );
      valeriaService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
        initialFocus: 7,
        initialPhylacteryRanks: {GeneralType.valeria: 3},
      );

      final res = valeriaService.executeDawnResurgence(fallenAlly.id);
      expect(res.focusSpent, equals(3));

      final revivedAlly = tickManager.allies.firstWhere((a) => a.id == ally.id);
      expect(revivedAlly.isAlive, isTrue);
      expect(revivedAlly.currentHp, equals((ally.maxHp * 0.50).round()));
      expect(revivedAlly.reviveCount, equals(1));
    });

    test('Lady Valeria: Dawn Resurgence is blocked during Terminal Collapse', () {
      valeriaService.upgradePhylactery(GeneralType.valeria);
      valeriaService.upgradePhylactery(GeneralType.valeria); // Rank 3
      final ally = tickManager.allies.first;
      final fallenAlly = ally.copyWith(currentHp: 0);

      tickManager = InitiativeTickManager(
        initialAllies: [fallenAlly, ...tickManager.allies.sublist(1)],
        initialEnemies: tickManager.enemies,
      );
      valeriaService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
        initialFocus: 7,
        initialPhylacteryRanks: {GeneralType.valeria: 3},
      );

      // Fast forward past 3,150 ticks to trigger Terminal Collapse
      while (tickManager.tickCount < 3151) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.areRevivesDisabled, isTrue);

      expect(
        () => valeriaService.executeDawnResurgence(fallenAlly.id),
        throwsStateError,
      );
    });

    test('Lady Valeria: Hallowed Ground (1 Focus) fortifies all frontline Vanguard allies', () {
      final vanguardAllies = tickManager.allies.where((u) => u.isVanguard).toList();
      final initialArmors = vanguardAllies.map((u) => u.defense).toList();

      final res = valeriaService.executeHallowedGround();
      expect(res.focusSpent, equals(1));

      final updatedVanguard = tickManager.allies.where((u) => u.isVanguard).toList();
      for (int i = 0; i < updatedVanguard.length; i++) {
        expect(updatedVanguard[i].defense, greaterThan(initialArmors[i]));
        expect(updatedVanguard[i].activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
      }
    });

    test('SpatialCombatEngine signature skills and card resolutions for Void Cult and Valeria', () {
      final engine = SpatialCombatEngine(
        commandService: valeriaService,
      );

      // Test signature skill names for Void Cult units
      final sentinel = CombatUnitState(
        id: 'void_bound_01',
        templateId: 'obsidian_sentinel',
        name: 'Obsidian Sentinel',
        level: 1,
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: [const GridNode(column: 0, row: 0)],
        maxHp: 900,
        hp: 900,
        maxArmor: 140,
        armor: 140,
        attack: 110,
        speed: 90,
        archetype: UnitArchetype.vanguardMelee,
      );
      expect(sentinel.signatureSkillName, equals('Rift Shockwave Pulse'));

      final flayer = CombatUnitState(
        id: 'shadow_flayer_01',
        templateId: 'void_ripper',
        name: 'Void Ripper',
        level: 1,
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: [const GridNode(column: 1, row: 0)],
        maxHp: 650,
        hp: 650,
        maxArmor: 70,
        armor: 70,
        attack: 155,
        speed: 130,
        archetype: UnitArchetype.reachMidline,
      );
      expect(flayer.signatureSkillName, equals('Phase Shadow Rend'));

      final slinger = CombatUnitState(
        id: 'acolyte_slinger_01',
        templateId: 'void_ray_stalker',
        name: 'Void Ray Stalker',
        level: 1,
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: [const GridNode(column: 2, row: 1)],
        maxHp: 580,
        hp: 580,
        maxArmor: 60,
        armor: 60,
        attack: 170,
        speed: 112,
        archetype: UnitArchetype.reachMidline,
      );
      expect(slinger.signatureSkillName, equals('Continuous Void Beam'));

      final warlock = CombatUnitState(
        id: 'cultist_apprentice_01',
        templateId: 'blight_arch_warlock',
        name: 'Blight Arch-Warlock',
        level: 1,
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: [const GridNode(column: 3, row: 1)],
        maxHp: 560,
        hp: 560,
        maxArmor: 65,
        armor: 65,
        attack: 165,
        speed: 95,
        archetype: UnitArchetype.backlineCaster,
      );
      expect(warlock.signatureSkillName, equals('Singularity Gravity Pull'));

      final chanter = CombatUnitState(
        id: 'chanter_void_01',
        templateId: 'herald_dark_gate',
        name: 'Herald of the Dark Gate',
        level: 1,
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: [const GridNode(column: 4, row: 0)],
        maxHp: 740,
        hp: 740,
        maxArmor: 88,
        armor: 88,
        attack: 115,
        speed: 104,
        archetype: UnitArchetype.vanguardMelee,
      );
      expect(chanter.signatureSkillName, equals('Dimensional Rift Surge'));

      // Test card playing in spatial engine
      engine.setupSunderAtAshenGate();
      engine.startBattle(); // transitions from isPreBattlePhase
      engine.focus = 7;
      const solarAegisCard = SpatialCombatCard(
        id: 'solar_aegis',
        name: 'Solar Aegis',
        focusCost: 2,
        description: 'Grant Aegis Shield & cleanse debuffs',
        pattern: TargetPattern.singleTarget,
      );
      engine.hand.add(solarAegisCard);

      final played = engine.castCard('solar_aegis', targetUnit: engine.playerUnits.first);
      expect(played, isTrue);
      expect(engine.playerUnits.first.aegisShield, greaterThan(0));
    });
  });
}
