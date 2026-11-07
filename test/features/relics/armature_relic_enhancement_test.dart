import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/relic_entity.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Option D: Armature Relic Gear Slots & +1 to +10 Enhancement Engine (GDD §7.3 & Recipe 3)', () {
    test('Armature Relic Gear Slots have correct metadata and core categorization', () {
      expect(RelicSlot.weapon.isCoreArmatureSlot, isTrue);
      expect(RelicSlot.armor.isCoreArmatureSlot, isTrue);
      expect(RelicSlot.boots.isCoreArmatureSlot, isTrue);
      expect(RelicSlot.offhand.isCoreArmatureSlot, isFalse);
      expect(RelicSlot.talisman.isCoreArmatureSlot, isFalse);
      expect(RelicSlot.sigil.isCoreArmatureSlot, isFalse);

      expect(RelicSlot.weapon.armatureSlotName, contains('Weapon Edge'));
      expect(RelicSlot.weapon.armatureRoleDescription, contains('ATK & Critical'));

      expect(RelicSlot.armor.armatureSlotName, contains('Core Plating'));
      expect(RelicSlot.armor.armatureRoleDescription, contains('Armor, Resistance & Max HP'));

      expect(RelicSlot.boots.armatureSlotName, contains('Kinetic Gyro'));
      expect(RelicSlot.boots.armatureRoleDescription, contains('Speed & AP'));
    });

    test('Refinement from +0 to +10 scales base stats smoothly and triggers sub-stat milestones', () {
      final service = RelicService(
        initialRelics: [
          const RelicEntity(
            id: 'test_blade',
            name: 'Crucible Flensing Edge',
            slot: RelicSlot.weapon,
            rarity: RelicRarity.legendary,
            setType: RelicSetType.bloodleech,
            bonusAttack: 100,
            bonusCritRate: 0.10,
            description: 'Living mineral blade edge.',
          ),
        ],
        rng: Random(42),
      );

      RelicEntity relic = service.allRelics.first;
      expect(relic.upgradeLevel, 0);
      expect(relic.isMasterwork, isFalse);
      expect(relic.canUpgrade, isTrue);
      expect(relic.totalAttack, 100);

      // Upgrade step-by-step from +1 to +10
      for (int lvl = 1; lvl <= 10; lvl++) {
        relic = service.upgradeRelic('test_blade');
        expect(relic.upgradeLevel, lvl);

        // Milestones at +2, +4, +6, +8, +10 add or enhance sub-stats
        if (lvl == 2 || lvl == 4 || lvl == 6 || lvl == 8 || lvl == 10) {
          expect(relic.subStats.isNotEmpty, isTrue);
        }
      }

      // Reached +10 Masterwork Armature Awakening!
      expect(relic.upgradeLevel, 10);
      expect(relic.isMasterwork, isTrue);
      expect(relic.canUpgrade, isFalse);
      expect(relic.displayName, contains('★'));
      expect(relic.displayName, contains('+10 [MASTERWORK]'));

      // +10 grants +10% Masterwork resonance on top of base stat scaling
      expect(relic.totalAttack, greaterThan(500));

      // Attempting to upgrade past +10 throws StateError
      expect(() => service.upgradeRelic('test_blade'), throwsStateError);
    });

    test('Chapter Refinement Caps enforce progression gate (+3 in Ch 1, +6 in Ch 2, +10 in Ch 3+)', () {
      expect(RelicEntity.maxRefinementTierForChapter(1), 3);
      expect(RelicEntity.maxRefinementTierForChapter(2), 6);
      expect(RelicEntity.maxRefinementTierForChapter(3), 10);
      expect(RelicEntity.maxRefinementTierForChapter(4), 10);

      const relicAtLvl3 = RelicEntity(
        id: 'r_lvl3',
        name: 'Iron Guard',
        slot: RelicSlot.armor,
        rarity: RelicRarity.rare,
        setType: RelicSetType.ironclad,
        description: '',
        upgradeLevel: 3,
      );

      expect(relicAtLvl3.canUpgradeForChapter(1), isFalse);
      expect(relicAtLvl3.canUpgradeForChapter(2), isTrue);
      expect(relicAtLvl3.canUpgradeForChapter(3), isTrue);

      const relicAtLvl6 = RelicEntity(
        id: 'r_lvl6',
        name: 'Iron Guard',
        slot: RelicSlot.armor,
        rarity: RelicRarity.rare,
        setType: RelicSetType.ironclad,
        description: '',
        upgradeLevel: 6,
      );

      expect(relicAtLvl6.canUpgradeForChapter(2), isFalse);
      expect(relicAtLvl6.canUpgradeForChapter(3), isTrue);
    });

    test('Batch enhance respects chapter progression caps and target levels', () {
      final service = RelicService(
        initialRelics: [
          const RelicEntity(
            id: 'batch_gyro',
            name: 'Piston Gyro',
            slot: RelicSlot.boots,
            rarity: RelicRarity.epic,
            setType: RelicSetType.tempest,
            bonusSpeed: 10,
            description: 'Clockwork gyro.',
          ),
        ],
        rng: Random(100),
      );

      // Attempt to enhance to +8 while in Chapter 1 (cap +3)
      final ch1Result = service.batchEnhanceRelic(
        relicId: 'batch_gyro',
        targetLevel: 8,
        maxChapter: 1,
      );
      expect(ch1Result.upgradeLevel, 3);

      // Now advance to Chapter 2 and batch enhance to +8 (cap +6)
      final ch2Result = service.batchEnhanceRelic(
        relicId: 'batch_gyro',
        targetLevel: 8,
        maxChapter: 2,
      );
      expect(ch2Result.upgradeLevel, 6);

      // Now advance to Chapter 3 and batch enhance to +10 (cap +10)
      final ch3Result = service.batchEnhanceRelic(
        relicId: 'batch_gyro',
        targetLevel: 10,
        maxChapter: 3,
      );
      expect(ch3Result.upgradeLevel, 10);
      expect(ch3Result.isMasterwork, isTrue);
    });

    test('Enhancement currency costs scale monotonically from +1 to +10', () {
      for (int lvl = 0; lvl < 10; lvl++) {
        final relic = RelicEntity(
          id: 'cost_test',
          name: 'Cost Test',
          slot: RelicSlot.weapon,
          rarity: RelicRarity.rare,
          setType: RelicSetType.bloodleech,
          description: '',
          upgradeLevel: lvl,
        );
        expect(relic.upgradeCostIchor, equals((lvl + 1) * 85));
        expect(relic.upgradeCostOre, equals(((lvl + 1) * 6).clamp(5, 50)));
      }
    });

    test('CombatUnitState incorporates Kinetic Gyro AP rate and Weapon Edge / Armor bonuses', () {
      final unit = CombatUnitState(
        id: 'vanguard_test',
        name: 'Iron Vanguard',
        templateId: 'iron_footman',
        isPlayer: true,
        footprint: UnitFootprint.single1x1,
        occupiedNodes: const [GridNode(column: 0, row: 0)],
        maxHp: 1000,
        hp: 1000,
        maxArmor: 200,
        armor: 200,
        attack: 150,
        speed: 100,
        apRateMultiplier: 1.35, // +35% AP accumulation from Kinetic Gyro & Piston Joint
        critRateBonus: 0.15,
        critDamageBonus: 0.25,
        armorPenetrationBonus: 0.30,
        lifestealBonus: 0.20,
      );

      // Effective speed is multiplied by apRateMultiplier (100 * 1.35 = 135)
      expect(unit.effectiveSpeed, 135);

      // Taking damage with armor penetration
      final damageTakenWithPen = unit.takeDamage(100, isPhysical: true, armorPenetration: 0.50);
      final damageTakenNoPen = unit.takeDamage(100, isPhysical: true, armorPenetration: 0.0);

      // Higher armor penetration penetrates armor reduction, dealing more damage
      expect(damageTakenWithPen, greaterThanOrEqualTo(damageTakenNoPen));
    });

    test('SpatialCombatEngine integrates equipped Armature Relics into unit combat states', () {
      final relicService = RelicService(
        initialRelics: [
          const RelicEntity(
            id: 'unit_weapon',
            name: 'Bloodhound Weapon Edge',
            slot: RelicSlot.weapon,
            rarity: RelicRarity.epic,
            setType: RelicSetType.bloodleech,
            bonusAttack: 60,
            bonusCritRate: 0.10,
            subStats: [
              RelicSubStat(type: RelicSubStatType.critRate, value: 0.05),
              RelicSubStat(type: RelicSubStatType.critDamage, value: 0.20),
            ],
            description: '',
            equippedUnitId: 'iron_footman_1',
            upgradeLevel: 5,
          ),
          const RelicEntity(
            id: 'unit_armor',
            name: 'Ironclad Core Plating',
            slot: RelicSlot.armor,
            rarity: RelicRarity.epic,
            setType: RelicSetType.ironclad,
            bonusDefense: 50,
            bonusHp: 300,
            description: '',
            equippedUnitId: 'iron_footman_1',
            upgradeLevel: 5,
          ),
          const RelicEntity(
            id: 'unit_gyro',
            name: 'Zephyr Kinetic Gyro',
            slot: RelicSlot.boots,
            rarity: RelicRarity.epic,
            setType: RelicSetType.tempest,
            bonusSpeed: 25,
            subStats: [
              RelicSubStat(type: RelicSubStatType.ultimateCharge, value: 0.25),
            ],
            description: '',
            equippedUnitId: 'iron_footman_1',
            upgradeLevel: 5,
          ),
        ],
      );

      final bonuses = relicService.calculateBonuses('iron_footman_1');
      expect(bonuses.bonusAttack, 60);
      expect(bonuses.bonusHp, 300);
      expect(bonuses.bonusSpeed, 25);
      expect(bonuses.bonusCritRate, closeTo(0.15, 0.001));
      expect(bonuses.bonusCritDamage, closeTo(0.20, 0.001));
      expect(bonuses.bonusUltimateCharge, closeTo(0.25, 0.001));

      final testUnit = UnitEntity(
        id: 'iron_footman_1',
        name: 'Iron Footman',
        speciesId: 'iron_footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 20,
        currentHp: 600,
        maxHp: 600,
        attack: 50,
        defense: 40,
        speed: 50,
        nativeTraitId: 'iron_will',
        lineageAncestors: const [],
      );

      final enemyUnit = UnitEntity(
        id: 'enemy_husk_1',
        name: 'Rotting Husk',
        speciesId: 'rotting_husk',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 20,
        currentHp: 400,
        maxHp: 400,
        attack: 30,
        defense: 20,
        speed: 40,
        nativeTraitId: 'undead_grit',
        lineageAncestors: const [],
      );

      final engine = SpatialCombatEngine(
        initialPlayerEntities: [testUnit],
        initialEnemyEntities: [enemyUnit],
        relicService: relicService,
      );

      final combatUnit = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman_1');

      // Attack: 50 + 60 = 110
      expect(combatUnit.attack, 110);
      // HP: 600 + 300 = 900
      expect(combatUnit.maxHp, 900);
      // Speed: 50 + 25 = 75
      expect(combatUnit.speed, 75);
      // AP Rate Multiplier accelerated by Kinetic Gyro
      expect(combatUnit.apRateMultiplier, greaterThan(1.0));
      // Effective speed boosted by apRateMultiplier
      expect(combatUnit.effectiveSpeed, greaterThan(75));
    });
  });
}
