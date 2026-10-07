import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/shared/models/relic_entity.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';

void main() {
  group('RelicService & Equipment Set Tests', () {
    late RelicService relicService;

    setUp(() {
      relicService = RelicService(initialRelics: [
        const RelicEntity(
          id: 'test_blade',
          name: 'Vampire Blade',
          slot: RelicSlot.weapon,
          rarity: RelicRarity.rare,
          setType: RelicSetType.bloodleech,
          bonusAttack: 50,
          bonusCritRate: 0.05,
          description: 'Test weapon',
        ),
        const RelicEntity(
          id: 'test_amulet',
          name: 'Vampire Amulet',
          slot: RelicSlot.talisman,
          rarity: RelicRarity.rare,
          setType: RelicSetType.bloodleech,
          bonusHp: 200,
          description: 'Test talisman',
        ),
        const RelicEntity(
          id: 'test_armor',
          name: 'Iron Breastplate',
          slot: RelicSlot.armor,
          rarity: RelicRarity.epic,
          setType: RelicSetType.ironclad,
          bonusDefense: 40,
          description: 'Test armor',
        ),
      ]);
    });

    test('Equipping a relic links it to the unit and updates unequipped list', () {
      expect(relicService.unequippedRelics.length, equals(3));

      relicService.equipRelic(relicId: 'test_blade', unitId: 'unit_alpha');

      expect(relicService.unequippedRelics.length, equals(2));
      final unitRelics = relicService.getRelicsForUnit('unit_alpha');
      expect(unitRelics.length, equals(1));
      expect(unitRelics.first.id, equals('test_blade'));
    });

    test('Equipping into same slot replaces previous relic cleanly', () {
      relicService.equipRelic(relicId: 'test_blade', unitId: 'unit_alpha');

      final newBlade = const RelicEntity(
        id: 'new_blade',
        name: 'New Greatsword',
        slot: RelicSlot.weapon,
        rarity: RelicRarity.legendary,
        setType: RelicSetType.executioner,
        bonusAttack: 100,
        description: 'Upgraded weapon',
      );
      final serviceWithNewBlade = RelicService(initialRelics: [
        relicService.allRelics[0],
        newBlade,
      ]);

      serviceWithNewBlade.equipRelic(relicId: 'test_blade', unitId: 'unit_alpha');
      serviceWithNewBlade.equipRelic(relicId: 'new_blade', unitId: 'unit_alpha');

      final equipped = serviceWithNewBlade.getRelicsForUnit('unit_alpha');
      expect(equipped.length, equals(1));
      expect(equipped.first.id, equals('new_blade'));
    });

    test('2-Piece Bloodleech set activates +15% lifesteal bonus', () {
      // Equip 1 piece
      relicService.equipRelic(relicId: 'test_blade', unitId: 'unit_alpha');
      var bonuses = relicService.calculateBonuses('unit_alpha');
      expect(bonuses.bonusLifesteal, equals(0.0));
      expect(bonuses.activeSetBonuses.contains(RelicSetType.bloodleech), isFalse);

      // Equip 2nd piece of same set
      relicService.equipRelic(relicId: 'test_amulet', unitId: 'unit_alpha');
      bonuses = relicService.calculateBonuses('unit_alpha');
      expect(bonuses.bonusLifesteal, equals(0.15));
      expect(bonuses.activeSetBonuses.contains(RelicSetType.bloodleech), isTrue);
      expect(bonuses.bonusAttack, equals(50));
      expect(bonuses.bonusHp, equals(200));
    });

    test('Forging a random relic adds it to inventory', () {
      final initialCount = relicService.allRelics.length;
      final forged = relicService.forgeRandomRelic();

      expect(relicService.allRelics.length, equals(initialCount + 1));
      expect(forged.id, isNotEmpty);
      expect(forged.name, isNotEmpty);
    });

    test('Refining and upgrading a relic scales stats by +25% per tier and caps at +5', () {
      final initialRelic = relicService.allRelics.firstWhere((r) => r.id == 'test_blade');
      expect(initialRelic.upgradeLevel, equals(0));
      expect(initialRelic.bonusAttack, equals(50));

      // Upgrade to +1
      final upgraded1 = relicService.upgradeRelic('test_blade');
      expect(upgraded1.upgradeLevel, equals(1));
      expect(upgraded1.displayName, equals('Vampire Blade +1'));
      expect(upgraded1.bonusAttack, equals((50 * 1.25).round())); // 63

      // Upgrade to +5
      relicService.upgradeRelic('test_blade'); // +2
      relicService.upgradeRelic('test_blade'); // +3
      relicService.upgradeRelic('test_blade'); // +4
      final upgraded5 = relicService.upgradeRelic('test_blade'); // +5
      expect(upgraded5.upgradeLevel, equals(5));
      expect(upgraded5.canUpgrade, isFalse);

      // Attempting to upgrade beyond +5 throws StateError
      expect(() => relicService.upgradeRelic('test_blade'), throwsStateError);
    });
  });
}
