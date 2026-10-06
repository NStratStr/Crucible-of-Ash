import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../shared/models/unit_entity.dart';
import '../combat/initiative_tick_manager.dart';

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
  final String generalId;
  final String generalName;

  int _currentFocus;
  double _accumulatedDamageProgress = 0.0;

  GeneralCommandService({
    required this.tickManager,
    required this.generalId,
    required this.generalName,
    int initialFocus = 1,
  }) : _currentFocus = initialFocus.clamp(0, maxFocusCap);

  int get currentFocus => _currentFocus;
  int get maxFocus => maxFocusCap;
  double get focusProgressRatio =>
      (_accumulatedDamageProgress / focusChargeThreshold).clamp(0.0, 1.0);

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
  // LORD VLADISLAV (VAMPIRE) ORDERS
  // ===========================================================================

  /// Siphon Vitality (Cost: 1 Focus):
  /// Drains 15% of the target enemy's current HP and splits the stolen amount
  /// evenly across surviving Vanguard (frontline) allies.
  OrderResult executeSiphonVitality(String targetEnemyId) {
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> enemies = List.of(tickManager.enemies);
    final int enemyIdx = enemies.indexWhere((u) => u.id == targetEnemyId && u.isAlive);
    if (enemyIdx == -1) {
      throw ArgumentError('Target enemy $targetEnemyId not found or already defeated.');
    }

    final UnitEntity target = enemies[enemyIdx];
    final int drainAmount = max(1, (target.currentHp * 0.15).round());
    final UnitEntity updatedTarget = target.copyWith(
      currentHp: max(0, target.currentHp - drainAmount),
    );
    enemies[enemyIdx] = updatedTarget;

    // Distribute drained vitality to surviving Vanguard units (slots 0, 1, 2)
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

  /// Sanguine Ward (Cost: 2 Focus):
  /// Sacrifices 15% current HP from all surviving allies, converting it into
  /// a team-wide flat defense buff or barrier.
  OrderResult executeSanguineWard() {
    const int cost = 2;
    _spendFocus(cost);

    int totalSacrificedHp = 0;
    List<UnitEntity> allies = List.of(tickManager.allies);

    // Sacrifice 15% current HP (clamped to keep unit alive with at least 1 HP)
    allies = allies.map((unit) {
      if (!unit.isAlive) return unit;
      final int sacrifice = max(1, (unit.currentHp * 0.15).round());
      final int newHp = max(1, unit.currentHp - sacrifice);
      totalSacrificedHp += (unit.currentHp - newHp);
      return unit.copyWith(currentHp: newHp);
    }).toList();

    // Barrier / Armor value = 200% of sacrificed vitality, distributed to defenses
    final int defenseBuffPerUnit = max(5, ((totalSacrificedHp * 2.0) / allies.length).round());
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

  /// Feast of Ruin (Cost: 3 Focus):
  /// High-tier execution. If the target is below 20% max HP, instantly executes them
  /// and grants all allies +50% Turn Meter.
  OrderResult executeFeastOfRuin(String targetEnemyId) {
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
      // Successful execution
      enemies[enemyIdx] = target.copyWith(currentHp: 0);
      allies = allies.map((u) {
        if (!u.isAlive) return u;
        return u.copyWith(turnMeter: u.turnMeter + 50.0);
      }).toList();
      summary = 'Executed ${target.name}! Roster surged with +50% Turn Meter.';
    } else {
      // Failed execution: deals standard true damage chunk without reset
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
  // LADY VALERIA (PALADIN) ORDERS
  // ===========================================================================

  /// Stand Resolute (Cost: 1 Focus):
  /// Fortifies target Vanguard ally with +40% Armor.
  OrderResult executeStandResolute(String targetAllyId) {
    const int cost = 1;
    _spendFocus(cost);

    final List<UnitEntity> allies = List.of(tickManager.allies);
    final int allyIdx = allies.indexWhere((u) => u.id == targetAllyId && u.isAlive);
    if (allyIdx == -1) {
      throw ArgumentError('Target ally $targetAllyId not found or already defeated.');
    }

    final UnitEntity target = allies[allyIdx];
    final int armorBoost = (target.defense * 0.40).round();
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

  void _applyStateToTickManager(List<UnitEntity> allies, List<UnitEntity> enemies) {
    tickManager.consumeTurn(
      retainedOverflow: true,
      updatedAllies: allies,
      updatedEnemies: enemies,
      autoResume: false,
    );
  }
}
