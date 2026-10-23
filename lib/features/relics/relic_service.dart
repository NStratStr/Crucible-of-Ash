import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../shared/models/relic_entity.dart';

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

  /// Overwrites the full relic collection (used for restoring saved state).
  void setAllRelics(List<RelicEntity> newRelics) {
    _relics.clear();
    _relics.addAll(newRelics);
    notifyListeners();
  }

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

  /// Upgrades / Refines an existing relic (+1 to +5).
  /// - Base stats scale by +25% per refinement tier.
  /// - At refinement milestones (+2, +4, and +5), unlocks or boosts a Sub-Stat / Sub-Star (e.g. Crit Rate, Crit DMG, Speed, Lifesteal).
  RelicEntity upgradeRelic(String relicId) {
    final int idx = _relics.indexWhere((r) => r.id == relicId);
    if (idx == -1) {
      throw ArgumentError('Relic $relicId not found.');
    }
    final current = _relics[idx];
    if (!current.canUpgrade) {
      throw StateError('Relic has reached maximum refinement tier (+5).');
    }

    final int nextLevel = current.upgradeLevel + 1;
    final updatedSubStats = List<RelicSubStat>.from(current.subStats);

    // Roll or boost sub-stats at milestones +2, +4, and +5
    if (nextLevel == 2 || nextLevel == 4 || nextLevel == 5) {
      final rollType = _randomSubStatType();
      final rollVal = _randomSubStatValue(rollType);

      final existingIdx = updatedSubStats.indexWhere((s) => s.type == rollType);
      if (existingIdx != -1) {
        // Boost existing sub-stat
        final prev = updatedSubStats[existingIdx];
        updatedSubStats[existingIdx] = RelicSubStat(type: rollType, value: prev.value + rollVal);
      } else {
        // Unlock new sub-stat slot
        updatedSubStats.add(RelicSubStat(type: rollType, value: rollVal));
      }
    }

    final upgraded = current.copyWith(
      upgradeLevel: nextLevel,
      bonusAttack: (current.bonusAttack * 1.25).round(),
      bonusDefense: (current.bonusDefense * 1.25).round(),
      bonusHp: (current.bonusHp * 1.25).round(),
      bonusSpeed: current.bonusSpeed > 0 ? current.bonusSpeed + 2 : 0,
      subStats: updatedSubStats,
    );

    _relics[idx] = upgraded;
    notifyListeners();
    return upgraded;
  }

  RelicSubStatType _randomSubStatType() {
    final types = RelicSubStatType.values;
    return types[_rng.nextInt(types.length)];
  }

  double _randomSubStatValue(RelicSubStatType type) {
    switch (type) {
      case RelicSubStatType.critRate:
        // +3.0% to +6.0% Crit Rate
        return 0.03 + (_rng.nextInt(31) / 1000.0);
      case RelicSubStatType.critDamage:
        // +10.0% to +20.0% Crit Damage
        return 0.10 + (_rng.nextInt(101) / 1000.0);
      case RelicSubStatType.speed:
        // +3 to +6 Speed
        return (3 + _rng.nextInt(4)).toDouble();
      case RelicSubStatType.lifesteal:
        // +4.0% to +8.0% Lifesteal
        return 0.04 + (_rng.nextInt(41) / 1000.0);
      case RelicSubStatType.attack:
        // +15 to +30 ATK
        return (15 + _rng.nextInt(16)).toDouble();
      case RelicSubStatType.defense:
        // +15 to +30 DEF
        return (15 + _rng.nextInt(16)).toDouble();
      case RelicSubStatType.hp:
        // +60 to +120 HP
        return (60 + _rng.nextInt(61)).toDouble();
    }
  }

  /// Computes all stat bonuses and active set effects for a given unit
  UnitRelicBonuses calculateBonuses(String unitId) {
    return calculateBonusesForRelics(getRelicsForUnit(unitId));
  }

  /// Computes all stat bonuses and active set effects for a given collection of relics
  UnitRelicBonuses calculateBonusesForRelics(List<RelicEntity> equipped) {
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
      atk += relic.totalAttack;
      def += relic.totalDefense;
      hp += relic.totalHp;
      spd += relic.totalSpeed;
      critRate += relic.totalCritRate;
      critDmg += relic.totalCritDamage;
      lifesteal += relic.totalSubLifesteal;

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
    if ((setCounts[RelicSetType.shadowstalker] ?? 0) >= 2) {
      critRate += 0.15;
      spd += 10;
      activeSets.add(RelicSetType.shadowstalker);
    }
    // Check 4-piece sets
    if ((setCounts[RelicSetType.executioner] ?? 0) >= 4) {
      critDmg += 0.30;
      critRate += 0.10;
      activeSets.add(RelicSetType.executioner);
    }
    if ((setCounts[RelicSetType.blightweaver] ?? 0) >= 4) {
      atk += (atk * 0.15).round() + 20;
      activeSets.add(RelicSetType.blightweaver);
    }
    if ((setCounts[RelicSetType.dreadnought] ?? 0) >= 4) {
      hp += (hp * 0.30).round() + 150;
      activeSets.add(RelicSetType.dreadnought);
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

  /// Forges a new random relic from Crucible Ichor with Mission-specific Sets & World Tier depth gating.
  RelicEntity forgeRandomRelic({
    RelicRarity? rarity,
    int chapter = 1,
    int stageDepth = 1,
  }) {
    final slots = RelicSlot.values;
    // Mission-specific equipment sets: each chapter features distinct thematic gear
    final allowedSets = RelicEntity.setsForChapter(chapter);

    final slot = slots[_rng.nextInt(slots.length)];
    final setType = allowedSets[_rng.nextInt(allowedSets.length)];

    RelicRarity rollRarity;
    if (rarity != null) {
      rollRarity = rarity;
    } else {
      // Depth-gated rarity progression:
      // Early depth (1-4): 75% Common, 25% Rare, 0% Epic, 0% Legendary
      // Mid depth (5-8): 35% Common, 50% Rare, 15% Epic, 0% Legendary
      // Deep depth (9-10): 10% Common, 40% Rare, 35% Epic, 15% Legendary
      final int roll = _rng.nextInt(100);
      if (chapter == 1 && stageDepth <= 4) {
        rollRarity = roll < 75 ? RelicRarity.common : RelicRarity.rare;
      } else if (chapter == 1 && stageDepth <= 8) {
        rollRarity = roll < 35 ? RelicRarity.common : (roll < 85 ? RelicRarity.rare : RelicRarity.epic);
      } else if (chapter == 1) {
        rollRarity = roll < 15 ? RelicRarity.common : (roll < 55 ? RelicRarity.rare : (roll < 85 ? RelicRarity.epic : RelicRarity.legendary));
      } else {
        // Later chapters naturally bias towards high-tier relics
        rollRarity = roll < 10 ? RelicRarity.common : (roll < 45 ? RelicRarity.rare : (roll < 80 ? RelicRarity.epic : RelicRarity.legendary));
      }
    }

    final multiplier = rollRarity == RelicRarity.legendary
        ? 2.2
        : (rollRarity == RelicRarity.epic ? 1.6 : (rollRarity == RelicRarity.rare ? 1.0 : 0.65));

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

    // Generate initial sub-stats based on relic rarity:
    // Common: 0, Rare: 1, Epic: 2, Legendary: 3
    final int initialSubStatCount = rollRarity == RelicRarity.legendary
        ? 3
        : (rollRarity == RelicRarity.epic ? 2 : (rollRarity == RelicRarity.rare ? 1 : 0));

    final List<RelicSubStat> initialSubStats = [];
    final Set<RelicSubStatType> usedTypes = {};
    for (int i = 0; i < initialSubStatCount; i++) {
      RelicSubStatType type;
      int attempts = 0;
      do {
        type = _randomSubStatType();
        attempts++;
      } while (usedTypes.contains(type) && attempts < 10);
      usedTypes.add(type);
      initialSubStats.add(RelicSubStat(type: type, value: _randomSubStatValue(type)));
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
      subStats: initialSubStats,
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
        subStats: [
          RelicSubStat(type: RelicSubStatType.critRate, value: 0.04),
        ],
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
        subStats: [
          RelicSubStat(type: RelicSubStatType.speed, value: 3.0),
        ],
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
        subStats: [
          RelicSubStat(type: RelicSubStatType.defense, value: 18.0),
        ],
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
        subStats: [
          RelicSubStat(type: RelicSubStatType.hp, value: 80.0),
        ],
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
        subStats: [
          RelicSubStat(type: RelicSubStatType.critDamage, value: 0.12),
        ],
        description: 'Feathered relic pulsing with gale winds.',
      ),
    ];
  }
}
