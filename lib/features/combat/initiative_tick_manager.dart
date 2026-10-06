import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/models/unit_entity.dart';

enum CombatPhase {
  idle,
  ticking,
  awaitingAction,
  resolvingAction,
  battleEnded,
}

@immutable
class TickSnapshot {
  final int tickCount;
  final List<UnitEntity> allies;
  final List<UnitEntity> enemies;
  final UnitEntity? activeUnit;
  final CombatPhase phase;

  const TickSnapshot({
    required this.tickCount,
    required this.allies,
    required this.enemies,
    required this.activeUnit,
    required this.phase,
  });
}

class InitiativeTickManager extends ChangeNotifier {
  static const double maxTurnMeter = 100.0;
  static const double tickScale = 10.0;

  List<UnitEntity> _allies;
  List<UnitEntity> _enemies;
  int _tickCount = 0;
  CombatPhase _phase = CombatPhase.idle;
  UnitEntity? _activeUnit;

  Timer? _loopTimer;
  final Duration tickInterval;

  InitiativeTickManager({
    required List<UnitEntity> initialAllies,
    required List<UnitEntity> initialEnemies,
    this.tickInterval = const Duration(milliseconds: 100),
  })  : _allies = List.unmodifiable(initialAllies),
        _enemies = List.unmodifiable(initialEnemies);

  // Getters
  int get tickCount => _tickCount;
  CombatPhase get phase => _phase;
  UnitEntity? get activeUnit => _activeUnit;
  List<UnitEntity> get allies => _allies;
  List<UnitEntity> get enemies => _enemies;

  List<UnitEntity> get allUnits => [..._allies, ..._enemies];

  TickSnapshot get snapshot => TickSnapshot(
        tickCount: _tickCount,
        allies: _allies,
        enemies: _enemies,
        activeUnit: _activeUnit,
        phase: _phase,
      );

  /// Starts the automatic real-time tick engine.
  void start() {
    if (_phase == CombatPhase.ticking) return;
    if (_isBattleOver()) {
      _phase = CombatPhase.battleEnded;
      notifyListeners();
      return;
    }

    _phase = CombatPhase.ticking;
    notifyListeners();

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(tickInterval, (_) => advanceTick());
  }

  /// Pauses the automatic timer.
  void pause() {
    _loopTimer?.cancel();
    _loopTimer = null;
    if (_phase == CombatPhase.ticking) {
      _phase = CombatPhase.idle;
      notifyListeners();
    }
  }

  /// Advances the engine by exactly one discrete tick.
  /// Can be driven by [Timer.periodic] or invoked manually in turn tests.
  void advanceTick() {
    if (_phase != CombatPhase.ticking && _phase != CombatPhase.idle) {
      return;
    }

    if (_isBattleOver()) {
      _finishBattle();
      return;
    }

    _tickCount++;

    // Increment TM for all surviving combatants: delta = (Speed / 100) * tickScale
    _allies = _allies.map((unit) {
      if (!unit.isAlive) return unit;
      final double delta = (unit.speed / 100.0) * tickScale;
      return unit.copyWith(turnMeter: unit.turnMeter + delta);
    }).toList(growable: false);

    _enemies = _enemies.map((unit) {
      if (!unit.isAlive) return unit;
      final double delta = (unit.speed / 100.0) * tickScale;
      return unit.copyWith(turnMeter: unit.turnMeter + delta);
    }).toList(growable: false);

    // Filter units that have met or exceeded the 100% threshold
    final List<UnitEntity> readyUnits = allUnits
        .where((unit) => unit.isAlive && unit.turnMeter >= maxTurnMeter)
        .toList();

    if (readyUnits.isNotEmpty) {
      // Tie-breaker:
      // 1. Highest raw TM overflow
      // 2. Highest base speed
      // 3. Player side (allies) priority
      readyUnits.sort((a, b) {
        final int tmCompare = b.turnMeter.compareTo(a.turnMeter);
        if (tmCompare != 0) return tmCompare;

        final int spdCompare = b.speed.compareTo(a.speed);
        if (spdCompare != 0) return spdCompare;

        final bool aIsAlly = _allies.any((u) => u.id == a.id);
        final bool bIsAlly = _allies.any((u) => u.id == b.id);
        if (aIsAlly && !bIsAlly) return -1;
        if (!aIsAlly && bIsAlly) return 1;

        return 0;
      });

      _activeUnit = readyUnits.first;
      _phase = CombatPhase.awaitingAction;
      _loopTimer?.cancel();
      _loopTimer = null;
    }

    notifyListeners();
  }

  /// Completes the active unit's action, resets their TM, and resumes combat.
  /// If [retainedOverflow] is true, surplus above 100 TM is preserved.
  void consumeTurn({
    bool retainedOverflow = false,
    List<UnitEntity>? updatedAllies,
    List<UnitEntity>? updatedEnemies,
    bool autoResume = true,
  }) {
    if (_phase != CombatPhase.awaitingAction || _activeUnit == null) {
      return;
    }

    _phase = CombatPhase.resolvingAction;

    // Apply any battle state changes passed from combat resolution (damage, buffs)
    if (updatedAllies != null) _allies = List.unmodifiable(updatedAllies);
    if (updatedEnemies != null) _enemies = List.unmodifiable(updatedEnemies);

    final double newTm = retainedOverflow
        ? (_activeUnit!.turnMeter - maxTurnMeter).clamp(0.0, maxTurnMeter)
        : 0.0;

    final String activeId = _activeUnit!.id;

    _allies = _allies.map((unit) {
      return unit.id == activeId ? unit.copyWith(turnMeter: newTm) : unit;
    }).toList(growable: false);

    _enemies = _enemies.map((unit) {
      return unit.id == activeId ? unit.copyWith(turnMeter: newTm) : unit;
    }).toList(growable: false);

    _activeUnit = null;

    if (_isBattleOver()) {
      _finishBattle();
      return;
    }

    // Check if another unit is already primed to act before advancing ticks
    final List<UnitEntity> remainingReady = allUnits
        .where((unit) => unit.isAlive && unit.turnMeter >= maxTurnMeter)
        .toList();

    if (remainingReady.isNotEmpty) {
      remainingReady.sort((a, b) {
        final int tmCompare = b.turnMeter.compareTo(a.turnMeter);
        if (tmCompare != 0) return tmCompare;
        return b.speed.compareTo(a.speed);
      });
      _activeUnit = remainingReady.first;
      _phase = CombatPhase.awaitingAction;
      notifyListeners();
    } else {
      _phase = CombatPhase.idle;
      notifyListeners();
      if (autoResume) {
        start();
      }
    }
  }

  /// Instant TM manipulation (e.g. +20% TM boost or -30% TM drain).
  void modifyTurnMeter(String unitId, double deltaPercent) {
    _allies = _allies.map((u) {
      if (u.id != unitId || !u.isAlive) return u;
      return u.copyWith(turnMeter: (u.turnMeter + deltaPercent).clamp(0.0, 200.0));
    }).toList(growable: false);

    _enemies = _enemies.map((u) {
      if (u.id != unitId || !u.isAlive) return u;
      return u.copyWith(turnMeter: (u.turnMeter + deltaPercent).clamp(0.0, 200.0));
    }).toList(growable: false);

    notifyListeners();
  }

  bool _isBattleOver() {
    final bool alliesDefeated = _allies.every((u) => !u.isAlive);
    final bool enemiesDefeated = _enemies.every((u) => !u.isAlive);
    return alliesDefeated || enemiesDefeated;
  }

  void _finishBattle() {
    _phase = CombatPhase.battleEnded;
    _activeUnit = null;
    _loopTimer?.cancel();
    _loopTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }
}
