import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../shared/models/relic_entity.dart';
import '../../shared/models/unit_entity.dart';

@immutable
class UnitRelicBonuses {
  final int bonusAttack;
  final int bonusDefense;
  final int bonusHp;
  final int bonusSpeed;
  final double bonusCritRate;
  final double bonusCritDamage;
  final double bonusLifesteal;
  final List<RelicSetType> activeSetBonuses;

  const UnitRelicBonuses({
    this.bonusAttack = 0,
    this.bonusDefense = 0,
    this.bonusHp = 0,
    this.bonusSpeed = 0,
    this.bonusCritRate = 0.0,
    this.bonusCritDamage = 0.0,
    this.bonusLifesteal = 0.0,
    this.activeSetBonuses = const [],
  });
}

class RelicService extends ChangeNotifier {
  final List<RelicEntity> _relics = [];
  final Random _rng;

  RelicService({List<RelicEntity>? initialRelics, Random? rng})
      : _rng = rng ?? Random() {
    if (initialRelics != null) {
      _relics.addAll(initialRelics);
    } else {
      _relics.addAll(createStarterRelics());
    }
  }

  List<RelicEntity> get allRelics => List.unmodifiable(_relics);

  List<RelicEntity> get unequippedRelics =>
      _relics.where((r) => r.equippedUnitId == null).toList();

  List<RelicEntity> getRelicsForUnit(String unitId) =>
      _relics.where((r) => r.equippedUnitId == unitId).toList();

  /// Equips a relic onto a unit. Unequips any existing relic in that same slot on that unit.
  void equipRelic({required String relicId, required String unitId}) {
    final int relicIndex = _relics.indexWhere((r) => r.id == relicId);
    if (relicIndex == -1) {
      throw ArgumentError('Relic $relicId not found.');
    }

    final RelicEntity relicToEquip = _relics[relicIndex];

    // Check if unit already has something in this slot
    for (int i = 0; i < _relics.length; i++) {
      if (_relics[i].equippedUnitId == unitId && _relics[i].slot == relicToEquip.slot) {
        _relics[i] = _relics[i].copyWith(clearEquipped: true);
      }
    }

    // Equip target relic
    _relics[relicIndex] = relicToEquip.copyWith(equippedUnitId: unitId);
    notifyListeners();
  }

  /// Unequips a relic
  void unequipRelic(String relicId) {
    final int idx = _relics.indexWhere((r) => r.id == relicId);
    if (idx != -1) {
      _relics[idx] = _relics[idx].copyWith(clearEquipped: true);
      notifyListeners();
    }
  }

  /// Computes all stat bonuses and active set effects for a given unit
  UnitRelicBonuses calculateBonuses(String unitId) {
    final equipped = getRelicsForUnit(unitId);
    if (equipped.isEmpty) return const UnitRelicBonuses();

    int atk = 0;
    int def = 0;
    int hp = 0;
    int spd = 0;
    double critRate = 0.0;
    double critDmg = 0.0;
    double lifesteal = 0.0;

    final Map<RelicSetType, int> setCounts = {};

    for (final relic in equipped) {
      atk += relic.bonusAttack;
      def += relic.bonusDefense;
      hp += relic.bonusHp;
      spd += relic.bonusSpeed;
      critRate += relic.bonusCritRate;

      setCounts[relic.setType] = (setCounts[relic.setType] ?? 0) + 1;
    }

    final List<RelicSetType> activeSets = [];

    // Check 2-piece sets
    if ((setCounts[RelicSetType.bloodleech] ?? 0) >= 2) {
      lifesteal += 0.15;
      activeSets.add(RelicSetType.bloodleech);
    }
    if ((setCounts[RelicSetType.ironclad] ?? 0) >= 2) {
      def += (def * 0.20).round() + 25;
      activeSets.add(RelicSetType.ironclad);
    }
    if ((setCounts[RelicSetType.tempest] ?? 0) >= 2) {
      spd += 12;
      activeSets.add(RelicSetType.tempest);
    }
    // Check 4-piece sets
    if ((setCounts[RelicSetType.executioner] ?? 0) >= 4) {
      critDmg += 0.30;
      critRate += 0.10;
      activeSets.add(RelicSetType.executioner);
    }

    return UnitRelicBonuses(
      bonusAttack: atk,
      bonusDefense: def,
      bonusHp: hp,
      bonusSpeed: spd,
      bonusCritRate: critRate,
      bonusCritDamage: critDmg,
      bonusLifesteal: lifesteal,
      activeSetBonuses: activeSets,
    );
  }

  /// Forges a new random relic from Crucible Ichor
  RelicEntity forgeRandomRelic({RelicRarity rarity = RelicRarity.rare}) {
    final slots = RelicSlot.values;
    final sets = RelicSetType.values;

    final slot = slots[_rng.nextInt(slots.length)];
    final setType = sets[_rng.nextInt(sets.length)];

    final int roll = _rng.nextInt(100);
    final RelicRarity rollRarity = rarity != RelicRarity.rare
        ? rarity
        : (roll < 55 ? RelicRarity.rare : (roll < 85 ? RelicRarity.epic : RelicRarity.legendary));

    final multiplier = rollRarity == RelicRarity.legendary
        ? 2.2
        : (rollRarity == RelicRarity.epic ? 1.6 : 1.0);

    int atk = 0;
    int def = 0;
    int hp = 0;
    int spd = 0;
    double crit = 0.0;

    switch (slot) {
      case RelicSlot.weapon:
        atk = (35 * multiplier).round();
        crit = (0.05 * multiplier);
        break;
      case RelicSlot.armor:
        def = (30 * multiplier).round();
        hp = (180 * multiplier).round();
        break;
      case RelicSlot.talisman:
        spd = (8 * multiplier).round();
        hp = (120 * multiplier).round();
        break;
      case RelicSlot.sigil:
        atk = (20 * multiplier).round();
        def = (15 * multiplier).round();
        spd = (5 * multiplier).round();
        break;
    }

    final newRelic = RelicEntity(
      id: 'relic_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(9999)}',
      name: '${rollRarity.name.toUpperCase()} ${_slotPrefix(slot)} of ${RelicEntity.setName(setType)}',
      slot: slot,
      rarity: rollRarity,
      setType: setType,
      bonusAttack: atk,
      bonusDefense: def,
      bonusHp: hp,
      bonusSpeed: spd,
      bonusCritRate: crit,
      description: 'Forged in the Ashen Crucible from concentrated ichor.',
    );

    _relics.add(newRelic);
    notifyListeners();
    return newRelic;
  }

  static String _slotPrefix(RelicSlot slot) {
    switch (slot) {
      case RelicSlot.weapon:
        return 'Blade';
      case RelicSlot.armor:
        return 'Cuirass';
      case RelicSlot.talisman:
        return 'Pendant';
      case RelicSlot.sigil:
        return 'Sigil';
    }
  }

  static List<RelicEntity> createStarterRelics() {
    return [
      const RelicEntity(
        id: 'starter_relic_01',
        name: 'Bloodhound Fang',
        slot: RelicSlot.weapon,
        rarity: RelicRarity.rare,
        setType: RelicSetType.bloodleech,
        bonusAttack: 40,
        bonusCritRate: 0.05,
        description: 'Jagged bone knife saturated with dark vampiric ichor.',
      ),
      const RelicEntity(
        id: 'starter_relic_02',
        name: 'Sanguine Chalice Talisman',
        slot: RelicSlot.talisman,
        rarity: RelicRarity.rare,
        setType: RelicSetType.bloodleech,
        bonusHp: 160,
        bonusSpeed: 6,
        description: 'Vessel humming with ancestral essence.',
      ),
      const RelicEntity(
        id: 'starter_relic_03',
        name: 'Ironclad Breastplate',
        slot: RelicSlot.armor,
        rarity: RelicRarity.rare,
        setType: RelicSetType.ironclad,
        bonusDefense: 35,
        bonusHp: 200,
        description: 'Heavy beaten iron forged to withstand crushing strikes.',
      ),
      const RelicEntity(
        id: 'starter_relic_04',
        name: 'Bulwark Crest Sigil',
        slot: RelicSlot.sigil,
        rarity: RelicRarity.rare,
        setType: RelicSetType.ironclad,
        bonusDefense: 25,
        bonusAttack: 15,
        description: 'Embossed insignia of the Iron Justiciar.',
      ),
      const RelicEntity(
        id: 'starter_relic_05',
        name: 'Zephyr Stride Talisman',
        slot: RelicSlot.talisman,
        rarity: RelicRarity.rare,
        setType: RelicSetType.tempest,
        bonusSpeed: 10,
        bonusHp: 100,
        description: 'Feathered relic pulsing with gale winds.',
      ),
    ];
  }
}
