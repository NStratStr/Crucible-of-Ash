import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../shared/models/unit_entity.dart';

enum CombatPhase {
  idle,
  ticking,
  awaitingAction,
  resolvingAction,
  battleEnded,
}

/// GDD v2.6 Section 13.1: The Ashen Reckoning Enrage Phases
enum AshenReckoningPhase {
  normal,          // 0:00 - 1:14 (< 2,250 ticks)
  warning,         // 1:15 - 1:29 (2,250 - 2,699 ticks): Warning Chime
  reckoning,       // 1:30 - 1:44 (2,700 - 3,149 ticks): Phase 1: 2.0x Damage, -50% Heals
  terminalCollapse,// 1:45 - 1:59 (3,150 - 3,599 ticks): Phase 2: Escalating Damage, No Revives
  adjudication,    // 2:00+ (3,600+ ticks): Hard Adjudication — Highest Total HP Wins
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
  double _speedMultiplier = 1.0;

  // GDD v2.6 Sec 13.2: Multi-Phase Boss Tracking (66% and 33% HP Thresholds)
  final Set<double> _bossPhaseThresholdsCrossed = {};
  String? _lastPhaseShiftMessage;

  InitiativeTickManager({
    required List<UnitEntity> initialAllies,
    required List<UnitEntity> initialEnemies,
    this.tickInterval = const Duration(milliseconds: 160),
  })  : _allies = List.unmodifiable(initialAllies),
        _enemies = List.unmodifiable(initialEnemies);

  // Getters
  int get tickCount => _tickCount;
  CombatPhase get phase => _phase;
  UnitEntity? get activeUnit => _activeUnit;
  List<UnitEntity> get allies => _allies;
  List<UnitEntity> get enemies => _enemies;
  double get speedMultiplier => _speedMultiplier;

  // GDD v2.6 Sec 13.1: The Ashen Reckoning enrage clock tracking
  AshenReckoningPhase get reckoningPhase {
    if (_tickCount >= 3600) return AshenReckoningPhase.adjudication;
    if (_tickCount >= 3150) return AshenReckoningPhase.terminalCollapse;
    if (_tickCount >= 2700) return AshenReckoningPhase.reckoning;
    if (_tickCount >= 2250) return AshenReckoningPhase.warning;
    return AshenReckoningPhase.normal;
  }

  /// Damage multiplier based on Ashen Reckoning phase (2.0x in Phase 1 & 2)
  double get reckoningDamageMultiplier =>
      reckoningPhase.index >= AshenReckoningPhase.reckoning.index ? 2.0 : 1.0;

  /// Healing multiplier based on Ashen Reckoning phase (-50% in Phase 1 & 2)
  double get reckoningHealingMultiplier =>
      reckoningPhase.index >= AshenReckoningPhase.reckoning.index ? 0.5 : 1.0;

  /// Whether revives are prohibited by Terminal Collapse
  bool get areRevivesDisabled =>
      reckoningPhase.index >= AshenReckoningPhase.terminalCollapse.index;

  /// GDD v2.6 Section 13.2: Multi-phase boss timer reset to Tick 0.
  void resetReckoningClock() {
    _tickCount = 0;
    notifyListeners();
  }

  String? get lastPhaseShiftMessage => _lastPhaseShiftMessage;
  void clearLastPhaseShiftMessage() {
    _lastPhaseShiftMessage = null;
  }

  /// GDD v2.6 Sec 13.2: Crossing major boss phase thresholds (66% HP, 33% HP)
  /// resets the Reckoning timer to Tick 0, clears Reckoning penalties, and triggers a phase shift.
  bool checkBossPhaseThresholds() {
    final bossList = _enemies.where((u) => u.isBoss && u.isAlive);
    if (bossList.isEmpty) return false;

    final boss = bossList.first;
    final double hpRatio = boss.maxHp > 0 ? (boss.currentHp / boss.maxHp) : 1.0;

    bool shifted = false;

    // Check 66% HP threshold (Phase 2)
    if (hpRatio <= 0.66 && !_bossPhaseThresholdsCrossed.contains(0.66)) {
      _bossPhaseThresholdsCrossed.add(0.66);
      _tickCount = 0; // Reset Reckoning timer to Tick 0
      _lastPhaseShiftMessage = 'PHASE SHIFT: ${boss.name} Enters Phase II! Reckoning Clock Reset.';
      shifted = true;
    }
    // Check 33% HP threshold (Phase 3)
    else if (hpRatio <= 0.33 && !_bossPhaseThresholdsCrossed.contains(0.33)) {
      _bossPhaseThresholdsCrossed.add(0.33);
      _tickCount = 0; // Reset Reckoning timer to Tick 0
      _lastPhaseShiftMessage = 'CRITICAL PHASE: ${boss.name} Blood Frenzy! Reckoning Clock Reset.';
      shifted = true;
    }

    if (shifted) {
      notifyListeners();
    }
    return shifted;
  }

  bool _isBulletTime = false;

  /// Whether bullet-time slow-motion (0.30x speed) is active (e.g. during card drag).
  bool get isBulletTime => _isBulletTime;

  /// Toggles bullet-time slow-motion (0.30x speed) during tactical interactions.
  void setBulletTime(bool active) {
    if (_isBulletTime == active) return;
    _isBulletTime = active;
    if (_phase == CombatPhase.ticking && _loopTimer != null) {
      _loopTimer?.cancel();
      _loopTimer = Timer.periodic(effectiveTickInterval, (_) => advanceTick());
    }
    notifyListeners();
  }

  Duration get effectiveTickInterval {
    final double bulletMultiplier = _isBulletTime ? 0.30 : 1.0;
    final double effectiveSpeed = _speedMultiplier * bulletMultiplier;
    return Duration(
      milliseconds:
          (tickInterval.inMilliseconds / effectiveSpeed).round().clamp(20, 2500),
    );
  }

  List<UnitEntity> get allUnits => [..._allies, ..._enemies];

  TickSnapshot get snapshot => TickSnapshot(
        tickCount: _tickCount,
        allies: _allies,
        enemies: _enemies,
        activeUnit: _activeUnit,
        phase: _phase,
      );

  /// Sets the real-time simulation speed multiplier (e.g. 1.0x, 2.0x).
  void setSpeedMultiplier(double multiplier) {
    if (multiplier <= 0 || _speedMultiplier == multiplier) return;
    _speedMultiplier = multiplier;
    if (_phase == CombatPhase.ticking && _loopTimer != null) {
      _loopTimer?.cancel();
      _loopTimer = Timer.periodic(effectiveTickInterval, (_) => advanceTick());
    }
    notifyListeners();
  }

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
    _loopTimer = Timer.periodic(effectiveTickInterval, (_) => advanceTick());
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

    // GDD v2.6 Sec 13.1: Hard Adjudication at 3,600 ticks (2:00 mark)
    if (_tickCount >= 3600) {
      _adjudicateMatch();
      return;
    }

    // Terminal Collapse: Apply escalating environmental true damage pulse every second (30 ticks)
    if (reckoningPhase == AshenReckoningPhase.terminalCollapse && _tickCount % 30 == 0) {
      final int pulse = ((_tickCount - 3150) ~/ 30 * 15) + 25;
      _allies = _allies.map((u) => u.isAlive ? u.copyWith(currentHp: max(1, u.currentHp - pulse)) : u).toList(growable: false);
      _enemies = _enemies.map((u) => u.isAlive ? u.copyWith(currentHp: max(1, u.currentHp - pulse)) : u).toList(growable: false);
    }

    // GDD v2.6 Sec 3.2 & Sec 4: Increment TM for all surviving combatants:
    // Stun / Freeze pauses AP/TM accumulation.
    // Haste increases BaseSPD by +35%.
    _allies = _allies.map((unit) {
      if (!unit.isAlive) return unit;
      if (unit.isStunned || unit.isFrozen) return unit; // Stun/Freeze pauses AP accumulation
      final double speedMod = unit.hasHaste ? 1.35 : 1.0;
      final double delta = ((unit.speed * speedMod) / 100.0) * tickScale;
      return unit.copyWith(turnMeter: unit.turnMeter + delta);
    }).toList(growable: false);

    _enemies = _enemies.map((unit) {
      if (!unit.isAlive) return unit;
      if (unit.isStunned || unit.isFrozen) return unit; // Stun/Freeze pauses AP accumulation
      final double speedMod = unit.hasHaste ? 1.35 : 1.0;
      final double delta = ((unit.speed * speedMod) / 100.0) * tickScale;
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

  /// Updates squads in-place (e.g., after turn-start DoT, HoT, or trait procs).
  void updateSquads({List<UnitEntity>? allies, List<UnitEntity>? enemies}) {
    if (allies != null) _allies = List.unmodifiable(allies);
    if (enemies != null) _enemies = List.unmodifiable(enemies);
    if (_activeUnit != null) {
      final inAllies = _allies.where((u) => u.id == _activeUnit!.id);
      if (inAllies.isNotEmpty) {
        _activeUnit = inAllies.first;
      } else {
        final inEnemies = _enemies.where((u) => u.id == _activeUnit!.id);
        if (inEnemies.isNotEmpty) {
          _activeUnit = inEnemies.first;
        }
      }
    }
    notifyListeners();
  }

  /// GDD v2.6 Sec 13.2 & 14.1: Advances to next combat wave, resets reckoning timer.
  void advanceWave(List<UnitEntity> nextWaveEnemies) {
    _enemies = List.unmodifiable(nextWaveEnemies);
    resetReckoningClock();
    _phase = CombatPhase.ticking;
    _activeUnit = null;
    start();
    notifyListeners();
  }

  /// GDD v2.6 Sec 13.1: Hard Adjudication at 2:00 mark (highest total remaining squad HP wins)
  void _adjudicateMatch() {
    final int totalAllyHp = _allies.fold(0, (acc, u) => acc + max(0, u.currentHp));
    final int totalEnemyHp = _enemies.fold(0, (acc, u) => acc + max(0, u.currentHp));

    if (totalAllyHp >= totalEnemyHp) {
      _enemies = _enemies.map((e) => e.copyWith(currentHp: 0)).toList(growable: false);
    } else {
      _allies = _allies.map((a) => a.copyWith(currentHp: 0)).toList(growable: false);
    }
    _finishBattle();
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
