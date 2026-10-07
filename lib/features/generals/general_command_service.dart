import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../combat/initiative_tick_manager.dart';

enum GeneralType {
  vladislav,
  valeria,
  malakor,
  morrigan,
}

@immutable
class GeneralOrderDefinition {
  final String id;
  final String name;
  final int focusCost;
  final String description;
  final IconData icon;
  final bool requiresTargetEnemy;
  final bool requiresTargetAlly;
  final int requiredPhylacteryRank;

  const GeneralOrderDefinition({
    required this.id,
    required this.name,
    required this.focusCost,
    required this.description,
    required this.icon,
    this.requiresTargetEnemy = false,
    this.requiresTargetAlly = false,
    this.requiredPhylacteryRank = 1,
  });
}

@immutable
class GeneralProfile {
  final GeneralType type;
  final String id;
  final String name;
  final String title;
  final String auraName;
  final String auraDescription;
  final Color themeColor;
  final IconData icon;
  final List<GeneralOrderDefinition> orders;

  const GeneralProfile({
    required this.type,
    required this.id,
    required this.name,
    required this.title,
    required this.auraName,
    required this.auraDescription,
    required this.themeColor,
    required this.icon,
    required this.orders,
  });

  static const List<GeneralProfile> allGenerals = [
    GeneralProfile(
      type: GeneralType.vladislav,
      id: 'vladislav_01',
      name: 'Lord Vladislav',
      title: 'The Blood Sovereign',
      auraName: 'Crimson Tithe',
      auraDescription: 'Squad gains +8% Lifesteal against wounded and Bleeding targets.',
      themeColor: Color(0xFFB3261E),
      icon: Icons.bloodtype,
      orders: [
        GeneralOrderDefinition(
          id: 'siphon_vitality',
          name: 'SIPHON',
          focusCost: 1,
          description: 'Drain 15% HP from target enemy; heal frontline Vanguard allies.',
          icon: Icons.water_drop,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'sanguine_ward',
          name: 'WARD',
          focusCost: 2,
          description: 'Sacrifice 15% team HP to create an Armor barrier equal to 200% of sacrificed vitality.',
          icon: Icons.shield,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'feast_of_ruin',
          name: 'EXECUTE',
          focusCost: 3,
          description: 'Instantly execute enemy below 20% HP and surge squad with +50% Turn Meter.',
          icon: Icons.dangerous,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
    GeneralProfile(
      type: GeneralType.valeria,
      id: 'valeria_01',
      name: 'Lady Valeria',
      title: 'The Iron Justiciar',
      auraName: 'Iron Aegis',
      auraDescription: 'Frontline Vanguard gains +25% Armor and reflects 15% physical damage.',
      themeColor: Color(0xFFD4AF37),
      icon: Icons.shield_moon,
      orders: [
        GeneralOrderDefinition(
          id: 'stand_resolute',
          name: 'RESOLUTE',
          focusCost: 1,
          description: 'Fortify targeted ally with +40% Armor.',
          icon: Icons.security,
          requiresTargetAlly: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'retributive_stride',
          name: 'COUNTER',
          focusCost: 2,
          description: 'All Vanguard allies execute an immediate free counter-strike against enemies.',
          icon: Icons.flash_on,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'smite_the_wicked',
          name: 'SMITE',
          focusCost: 3,
          description: 'High-impact divine strike scaling with 80% of total squad Armor.',
          icon: Icons.bolt,
          requiresTargetEnemy: true,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
    GeneralProfile(
      type: GeneralType.malakor,
      id: 'malakor_01',
      name: 'Malakor',
      title: 'The Blight Father',
      auraName: 'Carrion Miasma',
      auraDescription: 'When an ally falls, all enemies gain 2 stacks of Blight.',
      themeColor: Color(0xFF2E7D32),
      icon: Icons.coronavirus,
      orders: [
        GeneralOrderDefinition(
          id: 'corpse_burst',
          name: 'BURST',
          focusCost: 1,
          description: 'Detonate necrotic miasma dealing 140 poison damage to all enemies and inflicting Blight.',
          icon: Icons.bubble_chart,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'virulent_cascade',
          name: 'CASCADE',
          focusCost: 2,
          description: 'Trigger 160 burst damage on all blighted foes and add a Blight stack.',
          icon: Icons.grain,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'rebind_flesh',
          name: 'REBIND',
          focusCost: 3,
          description: 'Resurrect a fallen ally with 40% HP and 100% TM (or heal team if none fallen).',
          icon: Icons.healing,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
    GeneralProfile(
      type: GeneralType.morrigan,
      id: 'morrigan_01',
      name: 'Morrigan',
      title: 'The Ashen Oracle',
      auraName: 'Temporal Threads',
      auraDescription: 'Squad gains +10% Speed; critical hits grant +5% Turn Meter.',
      themeColor: Color(0xFF7B1FA2),
      icon: Icons.hourglass_full,
      orders: [
        GeneralOrderDefinition(
          id: 'quicken',
          name: 'QUICKEN',
          focusCost: 1,
          description: 'Immediately grant target ally 100% Turn Meter so they act next.',
          icon: Icons.fast_forward,
          requiresTargetAlly: true,
          requiredPhylacteryRank: 1,
        ),
        GeneralOrderDefinition(
          id: 'unravel_hex',
          name: 'UNRAVEL',
          focusCost: 2,
          description: 'Cleanse all debuffs from squad and strip 30% Armor from all enemies.',
          icon: Icons.auto_fix_high,
          requiredPhylacteryRank: 2,
        ),
        GeneralOrderDefinition(
          id: 'echoing_hourglass',
          name: 'HOURGLASS',
          focusCost: 3,
          description: 'Grant all allies +40% Turn Meter and reduce skill cooldowns by 1.',
          icon: Icons.update,
          requiredPhylacteryRank: 3,
        ),
      ],
    ),
  ];

  static GeneralProfile getByType(GeneralType type) {
    return allGenerals.firstWhere(
      (g) => g.type == type,
      orElse: () => allGenerals.first,
    );
  }
}

@immutable
class OrderResult {
  final String orderId;
  final String orderName;
  final int focusSpent;
  final int remainingFocus;
  final String summary;
  final List<UnitEntity> updatedAllies;
  final List<UnitEntity> updatedEnemies;

  const OrderResult({
    required this.orderId,
    required this.orderName,
    required this.focusSpent,
    required this.remainingFocus,
    required this.summary,
    required this.updatedAllies,
    required this.updatedEnemies,
  });
}

class GeneralCommandService extends ChangeNotifier {
  static const int maxFocusCap = 3;
  static const double focusChargeThreshold = 500.0; // Damage dealt/taken per 1 Focus point

  final InitiativeTickManager tickManager;
  GeneralType _activeGeneralType;

  int _currentFocus;
  double _accumulatedDamageProgress = 0.0;

  final Map<GeneralType, int> _phylacteryRanks = {
    GeneralType.vladislav: 1,
    GeneralType.valeria: 1,
    GeneralType.malakor: 1,
    GeneralType.morrigan: 1,
  };

  GeneralCommandService({
    required this.tickManager,
    String? generalId,
    String? generalName,
    GeneralType generalType = GeneralType.vladislav,
    int initialFocus = 1,
    Map<GeneralType, int>? initialPhylacteryRanks,
  })  : _activeGeneralType = generalType,
        _currentFocus = initialFocus.clamp(0, maxFocusCap) {
    if (initialPhylacteryRanks != null) {
      _phylacteryRanks.addAll(initialPhylacteryRanks);
    }
  }

  GeneralType get activeGeneralType => _activeGeneralType;
  GeneralProfile get currentProfile => GeneralProfile.getByType(_activeGeneralType);

  String get generalId => currentProfile.id;
  String get generalName => currentProfile.name;
  int get currentFocus => _currentFocus;
  int get maxFocus => maxFocusCap;
  bool get isFocusMaxed => _currentFocus >= maxFocusCap;
  double get focusProgressRatio =>
      (_accumulatedDamageProgress / focusChargeThreshold).clamp(0.0, 1.0);
  double get focusChargeProgress => focusProgressRatio;

  Map<GeneralType, int> get allPhylacteryRanks => Map.unmodifiable(_phylacteryRanks);

  int get activePhylacteryRank => getPhylacteryRank(_activeGeneralType);

  int getPhylacteryRank(GeneralType type) => _phylacteryRanks[type] ?? 1;

  double get potencyMultiplier {
    final rank = activePhylacteryRank;
    if (rank >= 3) return 1.35; // Rank 3 Mastery
    if (rank >= 2) return 1.20; // Rank 2 Potency
    return 1.0;
  }

  /// Checks if an order is unlocked under the current General's active Phylactery rank.
  bool isOrderUnlocked(GeneralOrderDefinition order) {
    return activePhylacteryRank >= order.requiredPhylacteryRank;
  }

  /// Checks if an order is unlocked for a specific general type.
  bool isOrderUnlockedForGeneral(GeneralType type, GeneralOrderDefinition order) {
    return getPhylacteryRank(type) >= order.requiredPhylacteryRank;
  }

  bool upgradePhylactery(GeneralType type) {
    final current = getPhylacteryRank(type);
    if (current >= 3) return false;
    _phylacteryRanks[type] = current + 1;
    notifyListeners();
    return true;
  }

  void setActiveGeneral(GeneralType type) {
    if (_activeGeneralType == type) return;
    _activeGeneralType = type;
    notifyListeners();
  }

  /// Accumulates damage dealt or taken across the squad and converts it to Focus points.
  void registerCombatDamage(int damage) {
    if (_currentFocus >= maxFocusCap || damage <= 0) return;

    _accumulatedDamageProgress += damage;

    while (_accumulatedDamageProgress >= focusChargeThreshold && _currentFocus < maxFocusCap) {
      _accumulatedDamageProgress -= focusChargeThreshold;
      _currentFocus++;
    }

    if (_currentFocus == maxFocusCap) {
      _accumulatedDamageProgress = 0.0;
    }

    notifyListeners();
  }

  /// Manually grants flat Focus (e.g. from Altar rewards or Relic triggers).
  void grantFocus(int points) {
    _currentFocus = (_currentFocus + points).clamp(0, maxFocusCap);
    notifyListeners();
  }

  void _validateOrderUnlocked(String orderId) {
    final order = currentProfile.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => throw ArgumentError('Unknown order $orderId for ${currentProfile.name}.'),
    );
    if (!isOrderUnlocked(order)) {
      throw StateError(
        'Order ${order.name} is sealed! Requires Phylactery Rank ${order.requiredPhylacteryRank}. Anoint ${currentProfile.name} in the Phylactery.',
      );
    }
  }

  /// Validates and spends focus points. Throws an error if insufficient.
  void _spendFocus(int cost) {
    if (_currentFocus < cost) {
      throw StateError(
        'Insufficient Command Focus: Attempted to spend $cost, but only have $_currentFocus.',
      );
    }
    _currentFocus -= cost;
    notifyListeners();
  }

  // ===========================================================================
  // 1. LORD VLADISLAV (VAMPIRE) ORDERS
  // ===========================================================================

  /// Siphon Vitality (Cost: 1 Focus)
  OrderResult executeSiphonVitality(String targetEnemyId) {
    _validateOrderUnlocked('siphon_vitality');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    final UnitEntity target = enemies[enemyIdx];
    final int drainAmount = max(1, ((target.currentHp * 0.15) * potencyMultiplier).round());
    final UnitEntity updatedTarget = target.copyWith(
      currentHp: max(0, target.currentHp - drainAmount),
    );
    enemies[enemyIdx] = updatedTarget;

    List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> aliveVanguard = allies.where((u) => u.isVanguard && u.isAlive).toList();

    if (aliveVanguard.isNotEmpty) {
      final int healPerVanguard = max(1, (drainAmount / aliveVanguard.length).round());
      allies = allies.map((u) {
        if (u.isVanguard && u.isAlive) {
          final int newHp = min(u.maxHp, u.currentHp + healPerVanguard);
          return u.copyWith(currentHp: newHp);
        }
        return u;
      }).toList();
    }

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'siphon_vitality',
      orderName: 'Siphon Vitality',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Drained $drainAmount HP from ${target.name} and healed frontline.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Sanguine Ward (Cost: 2 Focus)
  OrderResult executeSanguineWard() {
    _validateOrderUnlocked('sanguine_ward');
    const int cost = 2;
    _spendFocus(cost);

    int totalSacrificedHp = 0;
    List<UnitEntity> allies = List.of(tickManager.allies);

    allies = allies.map((unit) {
      if (!unit.isAlive) return unit;
      final int sacrifice = max(1, (unit.currentHp * 0.15).round());
      final int newHp = max(1, unit.currentHp - sacrifice);
      totalSacrificedHp += (unit.currentHp - newHp);
      return unit.copyWith(currentHp: newHp);
    }).toList();

    final int defenseBuffPerUnit = max(5, (((totalSacrificedHp * 2.0) * potencyMultiplier) / allies.length).round());
    allies = allies.map((unit) {
      if (!unit.isAlive) return unit;
      return unit.copyWith(defense: unit.defense + defenseBuffPerUnit);
    }).toList();

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'sanguine_ward',
      orderName: 'Sanguine Ward',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Sacrificed $totalSacrificedHp team HP to bolster all units with +$defenseBuffPerUnit Armor.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Feast of Ruin (Cost: 3 Focus)
  OrderResult executeFeastOfRuin(String targetEnemyId) {
    _validateOrderUnlocked('feast_of_ruin');
    const int cost = 3;
    _spendFocus(cost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    final UnitEntity target = enemies[enemyIdx];
    final double hpRatio = target.currentHp / target.maxHp;

    List<UnitEntity> allies = List.of(tickManager.allies);
    String summary;

    if (hpRatio <= 0.20) {
      enemies[enemyIdx] = target.copyWith(currentHp: 0);
      allies = allies.map((u) {
        if (!u.isAlive) return u;
        return u.copyWith(turnMeter: u.turnMeter + 50.0);
      }).toList();
      summary = 'Executed ${target.name}! Roster surged with +50% Turn Meter.';
    } else {
      final int flatDamage = (target.maxHp * 0.15).round();
      enemies[enemyIdx] = target.copyWith(currentHp: max(0, target.currentHp - flatDamage));
      summary = '${target.name} HP above 20% threshold. Dealt $flatDamage physical damage.';
    }

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'feast_of_ruin',
      orderName: 'Feast of Ruin',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: summary,
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 2. LADY VALERIA (PALADIN) ORDERS
  // ===========================================================================

  /// Stand Resolute (Cost: 1 Focus)
  OrderResult executeStandResolute(String targetAllyId) {
    _validateOrderUnlocked('stand_resolute');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    final UnitEntity target = allies[allyIdx];
    final int armorBoost = max(10, ((target.defense * 0.40) * potencyMultiplier).round());
    allies[allyIdx] = target.copyWith(defense: target.defense + armorBoost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'stand_resolute',
      orderName: 'Stand Resolute',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Fortified ${target.name} with +$armorBoost Armor.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Retributive Stride (Cost: 2 Focus)
  /// All surviving Vanguard allies strike the front enemy directly for 100% of their ATK.
  OrderResult executeRetributiveStride() {
    _validateOrderUnlocked('retributive_stride');
    const int cost = 2;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final int targetIdx = enemies.indexWhere((e) => e.isAlive);
    if (targetIdx == -1) {
      throw StateError('No living enemy to counter-strike.');
    }

    final livingVanguard = allies.where((u) => u.isVanguard && u.isAlive).toList();
    int totalDamage = 0;
    for (final v in livingVanguard) {
      totalDamage += v.attack;
    }

    final target = enemies[targetIdx];
    final int newHp = max(0, target.currentHp - totalDamage);
    enemies[targetIdx] = target.copyWith(currentHp: newHp);

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'retributive_stride',
      orderName: 'Retributive Stride',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Vanguard counter-attack unleashed! Dealt $totalDamage physical damage to ${target.name}.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Smite the Wicked (Cost: 3 Focus)
  /// High-impact divine strike scaling with 80% of total brigade armor.
  OrderResult executeSmiteTheWicked(String targetEnemyId) {
    _validateOrderUnlocked('smite_the_wicked');
    const int cost = 3;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    int totalBrigadeArmor = 0;
    for (final ally in allies) {
      if (ally.isAlive) {
        totalBrigadeArmor += ally.defense;
      }
    }

    final int radiantDamage = max(150, ((totalBrigadeArmor * 0.80) * potencyMultiplier).round());
    final target = enemies[enemyIdx];
    final int newHp = max(0, target.currentHp - radiantDamage);
    enemies[enemyIdx] = target.copyWith(currentHp: newHp);

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'smite_the_wicked',
      orderName: 'Smite the Wicked',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Radiant Smite channeled total armor ($totalBrigadeArmor DEF) dealing $radiantDamage holy damage to ${target.name}!',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 3. MALAKOR (THE BLIGHT FATHER) ORDERS
  // ===========================================================================

  /// Corpse Burst (Cost: 1 Focus)
  /// Detonates necrotic miasma dealing 140 poison damage to all enemies and inflicting Blight.
  OrderResult executeCorpseBurst() {
    _validateOrderUnlocked('corpse_burst');
    const int cost = 1;
    _spendFocus(cost);

    final int burstDamage = max(1, (140 * potencyMultiplier).round());
    final List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    enemies = enemies.map((enemy) {
      if (!enemy.isAlive) return enemy;
      final int newHp = max(0, enemy.currentHp - burstDamage);
      final updatedEffects = List<StatusEffect>.from(enemy.activeEffects)
        ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
      return enemy.copyWith(currentHp: newHp, activeEffects: updatedEffects);
    }).toList();

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'corpse_burst',
      orderName: 'Corpse Burst',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Corpse Burst detonated! Dealt $burstDamage poison damage and blighted all enemies.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Virulent Cascade (Cost: 2 Focus)
  /// Deals 160 instant damage to all blighted or bleeding foes, and adds a Blight stack.
  OrderResult executeVirulentCascade() {
    _validateOrderUnlocked('virulent_cascade');
    const int cost = 2;
    _spendFocus(cost);

    final int cascadeDamage = max(1, (160 * potencyMultiplier).round());
    final List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    int targetsAfflicted = 0;
    enemies = enemies.map((enemy) {
      if (!enemy.isAlive) return enemy;
      final bool isAfflicted = enemy.isBlighted || enemy.isBleeding;
      if (isAfflicted) {
        targetsAfflicted++;
        final int newHp = max(0, enemy.currentHp - cascadeDamage);
        final updatedEffects = List<StatusEffect>.from(enemy.activeEffects)
          ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 50));
        return enemy.copyWith(currentHp: newHp, activeEffects: updatedEffects);
      }
      return enemy;
    }).toList();

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'virulent_cascade',
      orderName: 'Virulent Cascade',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Virulent Cascade tore through $targetsAfflicted afflicted enemies for $cascadeDamage burst damage!',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Rebind Flesh (Cost: 3 Focus)
  /// Resurrects a fallen ally with 40% HP and 100% TM. If none fallen, heals team for 35% HP.
  OrderResult executeRebindFlesh() {
    _validateOrderUnlocked('rebind_flesh');
    const int cost = 3;
    _spendFocus(cost);

    List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    final deadIdx = allies.indexWhere((u) => !u.isAlive);
    String summary;

    if (deadIdx != -1) {
      final deadUnit = allies[deadIdx];
      final int restoredHp = max(100, (deadUnit.maxHp * 0.40).round());
      allies[deadIdx] = deadUnit.copyWith(
        currentHp: restoredHp,
        turnMeter: 100.0,
      );
      summary = 'Rebound flesh! Resurrected ${deadUnit.name} with $restoredHp HP and 100% Turn Meter.';
    } else {
      allies = allies.map((u) {
        final heal = (u.maxHp * 0.35).round();
        return u.copyWith(currentHp: min(u.maxHp, u.currentHp + heal));
      }).toList();
      summary = 'Necrotic surge restored 35% vitality across all surviving allies.';
    }

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'rebind_flesh',
      orderName: 'Rebind Flesh',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: summary,
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  // ===========================================================================
  // 4. MORRIGAN (THE ASHEN ORACLE) ORDERS
  // ===========================================================================

  /// Quicken (Cost: 1 Focus)
  /// Immediately grant target ally 100% Turn Meter.
  OrderResult executeQuicken(String targetAllyId) {
    _validateOrderUnlocked('quicken');
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    final UnitEntity target = allies[allyIdx];
    allies[allyIdx] = target.copyWith(turnMeter: 100.0);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'quicken',
      orderName: 'Quicken',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Spun temporal threads! ${target.name} surged to 100% Turn Meter.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Unravel Hex (Cost: 2 Focus)
  /// Cleanses all debuffs on allies and strips 30% Armor from all enemies.
  OrderResult executeUnravelHex() {
    _validateOrderUnlocked('unravel_hex');
    const int cost = 2;
    _spendFocus(cost);

    List<UnitEntity> allies = List.of(tickManager.allies);
    List<UnitEntity> enemies = List.of(tickManager.enemies);

    allies = allies.map((u) {
      if (!u.isAlive) return u;
      return u.copyWith(activeEffects: const []);
    }).toList();

    enemies = enemies.map((e) {
      if (!e.isAlive) return e;
      final int armorShred = (e.defense * 0.30).round();
      return e.copyWith(defense: max(10, e.defense - armorShred));
    }).toList();

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'unravel_hex',
      orderName: 'Unravel Hex',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'All ally debuffs purged and 30% Armor stripped from all enemies!',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  /// Echoing Hourglass (Cost: 3 Focus)
  /// Grants all allies +40% Turn Meter and reduces skill cooldowns by 1.
  OrderResult executeEchoingHourglass() {
    _validateOrderUnlocked('echoing_hourglass');
    const int cost = 3;
    _spendFocus(cost);

    List<UnitEntity> allies = List.of(tickManager.allies);
    final List<UnitEntity> enemies = List.of(tickManager.enemies);

    allies = allies.map((u) {
      if (!u.isAlive) return u;
      final updatedSkills = u.resolvedSkills.map((s) {
        if (s.currentCooldown > 0) {
          return s.copyWith(currentCooldown: s.currentCooldown - 1);
        }
        return s;
      }).toList();
      return u.copyWith(
        turnMeter: u.turnMeter + 40.0,
        skills: updatedSkills,
      );
    }).toList();

    _applyStateToTickManager(allies, enemies);

    return OrderResult(
      orderId: 'echoing_hourglass',
      orderName: 'Echoing Hourglass',
      focusSpent: cost,
      remainingFocus: _currentFocus,
      summary: 'Time rewound! Squad gained +40% Turn Meter and reduced skill cooldowns.',
      updatedAllies: allies,
      updatedEnemies: enemies,
    );
  }

  void _applyStateToTickManager(List<UnitEntity> allies, List<UnitEntity> enemies) {
    tickManager.consumeTurn(
      retainedOverflow: true,
      updatedAllies: allies,
      updatedEnemies: enemies,
      autoResume: false,
    );
  }
}
