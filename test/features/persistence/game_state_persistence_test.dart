import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/campaign/endgame_gauntlet_dialog.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/features/persistence/game_state_persistence_service.dart';
import 'package:ashen_crucible/shared/models/relic_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Game State Persistence & Serialization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('UnitEntity serializes to JSON and deserializes identically', () {
      const original = UnitEntity(
        id: 'unit_test_99',
        speciesId: 'feral_hound',
        name: 'Cerberus Dreadspawn',
        generation: 3,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front3,
        level: 25,
        maxLevel: 45,
        currentHp: 820,
        maxHp: 1100,
        attack: 260,
        defense: 175,
        speed: 130,
        critRate: 0.22,
        critDamage: 1.70,
        nativeTraitId: 'pack_instinct',
        graftedTraitId: 'rend_flesh',
        lineageAncestors: ['bloodline_beast', 'feral_hound', 'unit_parent_1'],
        currentXp: 350,
      );

      final json = original.toJson();
      final restored = UnitEntity.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.speciesId, equals(original.speciesId));
      expect(restored.name, equals(original.name));
      expect(restored.generation, equals(3));
      expect(restored.archetype, equals(Archetype.skirmisher));
      expect(restored.slot, equals(FormationSlot.front3));
      expect(restored.level, equals(25));
      expect(restored.maxHp, equals(1100));
      expect(restored.attack, equals(260));
      expect(restored.nativeTraitId, equals('pack_instinct'));
      expect(restored.graftedTraitId, equals('rend_flesh'));
      expect(restored.lineageAncestors, contains('bloodline_beast'));
      expect(restored.currentXp, equals(350));
    });

    test('RelicEntity serializes to JSON and deserializes identically', () {
      const original = RelicEntity(
        id: 'relic_blade_01',
        name: 'Bloodforged Cleaver',
        slot: RelicSlot.weapon,
        rarity: RelicRarity.epic,
        setType: RelicSetType.bloodleech,
        bonusAttack: 45,
        bonusHp: 150,
        bonusCritRate: 0.08,
        description: 'Vampiric edge hungry for arterial spray.',
        equippedUnitId: 'unit_test_99',
        upgradeLevel: 3,
      );

      final json = original.toJson();
      final restored = RelicEntity.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.slot, equals(RelicSlot.weapon));
      expect(restored.rarity, equals(RelicRarity.epic));
      expect(restored.setType, equals(RelicSetType.bloodleech));
      expect(restored.bonusAttack, equals(45));
      expect(restored.equippedUnitId, equals('unit_test_99'));
      expect(restored.upgradeLevel, equals(3));
      expect(restored.displayName, equals('Bloodforged Cleaver +3'));
    });

    test('GameStatePersistenceService saves and loads player progress', () async {
      const hero = UnitEntity(
        id: 'hero_persisted_1',
        speciesId: 'rusted_footman',
        name: 'Iron Juggernaut',
        generation: 2,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 15,
        maxLevel: 35,
        currentHp: 1200,
        maxHp: 1200,
        attack: 190,
        defense: 210,
        speed: 95,
        nativeTraitId: 'shield_bash',
        lineageAncestors: ['rusted_footman'],
      );

      const relic = RelicEntity(
        id: 'relic_persisted_1',
        name: 'Iron Wall Armor',
        slot: RelicSlot.armor,
        rarity: RelicRarity.rare,
        setType: RelicSetType.ironclad,
        bonusDefense: 50,
        description: 'Heavy armor plating.',
        upgradeLevel: 2,
      );

      final saveData = GameSaveData(
        totalIchor: 1450,
        cursedOre: 220,
        bloodlineSigils: 8,
        activeGeneralType: GeneralType.valeria,
        phylacteryRanks: {
          GeneralType.vladislav: 2,
          GeneralType.valeria: 3,
          GeneralType.malakor: 1,
          GeneralType.morrigan: 1,
        },
        currentChapter: 2,
        maxUnlockedChapter: 3,
        allies: [hero],
        reserveInventory: [],
        relics: [relic],
        clearedGauntletTrials: {EndgameTrialType.worldTitan, EndgameTrialType.lineageCrypt},
        lastSavedTimestamp: 1728345600000,
      );

      final saveSuccess = await GameStatePersistenceService.save(saveData);
      expect(saveSuccess, isTrue);

      final loaded = await GameStatePersistenceService.load();
      expect(loaded, isNotNull);
      expect(loaded!.totalIchor, equals(1450));
      expect(loaded.cursedOre, equals(220));
      expect(loaded.bloodlineSigils, equals(8));
      expect(loaded.activeGeneralType, equals(GeneralType.valeria));
      expect(loaded.phylacteryRanks[GeneralType.valeria], equals(3));
      expect(loaded.currentChapter, equals(2));
      expect(loaded.maxUnlockedChapter, equals(3));
      expect(loaded.allies.length, equals(1));
      expect(loaded.allies.first.name, equals('Iron Juggernaut'));
      expect(loaded.relics.length, equals(1));
      expect(loaded.clearedGauntletTrials, contains(EndgameTrialType.worldTitan));
      expect(loaded.clearedGauntletTrials, contains(EndgameTrialType.lineageCrypt));
    });
  });
}
