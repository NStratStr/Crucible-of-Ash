import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';
import 'initiative_tick_manager.dart';

@immutable
class ActionResult {
  final UnitEntity attacker;
  final UnitEntity target;
  final int damageDealt;
  final bool isCritical;
  final bool isGlancing;
  final double affinityMultiplier;
  final bool targetDefeated;
  final int lifestealRecovered;

  const ActionResult({
    required this.attacker,
    required this.target,
    required this.damageDealt,
    required this.isCritical,
    required this.isGlancing,
    required this.affinityMultiplier,
    required this.targetDefeated,
    required this.lifestealRecovered,
  });
}

class CombatResolutionService {
  final InitiativeTickManager tickManager;
  final Random _rng;

  CombatResolutionService({
    required this.tickManager,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Executes a single-target basic attack from the current active unit,
  /// calculates affinity and damage curves, applies HP changes, and consumes the turn.
  ActionResult executeBasicAttack({
    required String targetUnitId,
    double skillCoefficient = 1.0,
    double lifestealRatio = 0.0,
    bool autoResumeTickEngine = true,
  }) {
    final UnitEntity? attacker = tickManager.activeUnit;
    if (attacker == null || tickManager.phase != CombatPhase.awaitingAction) {
      throw StateError('Cannot execute attack: No active unit awaiting action.');
    }

    final bool attackerIsAlly = tickManager.allies.any((u) => u.id == attacker.id);
    final List<UnitEntity> opposingSquad = attackerIsAlly ? tickManager.enemies : tickManager.allies;

    final int targetIndex = opposingSquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    if (targetIndex == -1) {
      throw ArgumentError('Target unit $targetUnitId is either not found or already defeated.');
    }

    final UnitEntity target = opposingSquad[targetIndex];

    // 1. Evaluate Hex Affinity and Glancing Blow status
    final double affinityMod = CombatMath.getAffinityMultiplier(attacker.archetype, target.archetype);
    final bool isGlancing = CombatMath.isGlancingBlow(attacker.archetype, target.archetype, _rng);

    // 2. Evaluate Critical Strike (suppressed if the blow glanced)
    final bool isCritical = !isGlancing && (_rng.nextDouble() < attacker.critRate);
    final double critMod = isCritical ? attacker.critDamage : 1.0;

    // 3. Compute Asymptotic Defense Mitigation
    final double mitigation = CombatMath.calculateMitigation(target.defense);

    // 4. Compute Base and Final Damage with 0.95 - 1.05 variance
    final double baseDamage = attacker.attack * skillCoefficient * mitigation;
    final double variance = 0.95 + (_rng.nextDouble() * 0.10);

    double totalDamage = baseDamage * affinityMod * critMod * variance;
    if (isGlancing) {
      totalDamage *= 0.70; // Additional 30% reduction on glancing hits
    }

    final int finalDamage = max(1, totalDamage.round());

    // 5. Apply Damage to Defender
    final int newTargetHp = max(0, target.currentHp - finalDamage);
    final UnitEntity updatedTarget = target.copyWith(currentHp: newTargetHp);

    // 6. Resolve Lifesteal (if applicable)
    int lifestealRecovered = 0;
    UnitEntity updatedAttacker = attacker;
    if (lifestealRatio > 0.0 && attacker.isAlive) {
      lifestealRecovered = (finalDamage * lifestealRatio).round();
      final int newAttackerHp = min(attacker.maxHp, attacker.currentHp + lifestealRecovered);
      updatedAttacker = attacker.copyWith(currentHp: newAttackerHp);
    }

    // 7. Reconstruct Squad State
    List<UnitEntity> updatedAllies = List.of(tickManager.allies);
    List<UnitEntity> updatedEnemies = List.of(tickManager.enemies);

    if (attackerIsAlly) {
      updatedAllies = updatedAllies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();
    } else {
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedAllies = updatedAllies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();
    }

    // 8. Commit squad changes and consume Turn-Meter on the Tick Manager
    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: autoResumeTickEngine,
    );

    return ActionResult(
      attacker: updatedAttacker,
      target: updatedTarget,
      damageDealt: finalDamage,
      isCritical: isCritical,
      isGlancing: isGlancing,
      affinityMultiplier: affinityMod,
      targetDefeated: updatedTarget.currentHp == 0,
      lifestealRecovered: lifestealRecovered,
    );
  }
}
