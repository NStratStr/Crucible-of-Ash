import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
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
  final String skillName;
  final String? appliedStatusName;
  final int healAmount;

  const ActionResult({
    required this.attacker,
    required this.target,
    required this.damageDealt,
    required this.isCritical,
    required this.isGlancing,
    required this.affinityMultiplier,
    required this.targetDefeated,
    required this.lifestealRecovered,
    this.skillName = 'Basic Strike',
    this.appliedStatusName,
    this.healAmount = 0,
  });
}

class CombatResolutionService {
  final InitiativeTickManager tickManager;
  final Random _rng;

  CombatResolutionService({
    required this.tickManager,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Executes basic attack for backwards-compatibility
  ActionResult executeBasicAttack({
    required String targetUnitId,
    double skillCoefficient = 1.0,
    double lifestealRatio = 0.0,
    bool autoResumeTickEngine = true,
  }) {
    return executeSkill(
      targetUnitId: targetUnitId,
      skill: SkillEntity(
        id: 'basic_attack',
        name: 'Basic Strike',
        description: 'Standard physical attack',
        damageCoefficient: skillCoefficient,
        lifestealRatio: lifestealRatio,
      ),
      autoResumeTickEngine: autoResumeTickEngine,
    );
  }

  /// Checks if active unit is stunned and skips turn if so
  bool checkAndHandleStun() {
    final active = tickManager.activeUnit;
    if (active == null || !active.isStunned) return false;

    // Decrement or remove stun
    final updatedEffects = active.activeEffects
        .map((e) => e.type == StatusEffectType.stun
            ? StatusEffect(type: e.type, durationTurns: e.durationTurns - 1, value: e.value)
            : e)
        .where((e) => e.durationTurns > 0)
        .toList();

    final updatedActive = active.copyWith(activeEffects: updatedEffects);

    final bool isAlly = tickManager.allies.any((u) => u.id == active.id);
    final updatedAllies = isAlly
        ? tickManager.allies.map((u) => u.id == active.id ? updatedActive : u).toList()
        : tickManager.allies;
    final updatedEnemies = !isAlly
        ? tickManager.enemies.map((u) => u.id == active.id ? updatedActive : u).toList()
        : tickManager.enemies;

    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: true,
    );

    return true;
  }

  /// Executes a designated skill from the active unit
  ActionResult executeSkill({
    required String targetUnitId,
    required SkillEntity skill,
    bool autoResumeTickEngine = true,
  }) {
    final UnitEntity? attacker = tickManager.activeUnit;
    if (attacker == null || tickManager.phase != CombatPhase.awaitingAction) {
      throw StateError('Cannot execute skill: No active unit awaiting action.');
    }

    final bool attackerIsAlly = tickManager.allies.any((u) => u.id == attacker.id);
    final List<UnitEntity> opposingSquad = attackerIsAlly ? tickManager.enemies : tickManager.allies;
    final List<UnitEntity> friendlySquad = attackerIsAlly ? tickManager.allies : tickManager.enemies;

    // Healing / Friendly skill
    if (skill.targetType == SkillTargetType.singleAlly || skill.damageCoefficient == 0.0) {
      return _executeSupportSkill(
        attacker: attacker,
        friendlySquad: friendlySquad,
        targetUnitId: targetUnitId,
        skill: skill,
        attackerIsAlly: attackerIsAlly,
        autoResumeTickEngine: autoResumeTickEngine,
      );
    }

    final int targetIndex = opposingSquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    if (targetIndex == -1) {
      throw ArgumentError('Target unit $targetUnitId is either not found or already defeated.');
    }

    final UnitEntity target = opposingSquad[targetIndex];

    // 1. Evaluate Hex Affinity and Glancing Blow status
    final double affinityMod = CombatMath.getAffinityMultiplier(attacker.archetype, target.archetype);
    final bool isGlancing = CombatMath.isGlancingBlow(attacker.archetype, target.archetype, _rng);

    // 2. Evaluate Critical Strike
    final bool isCritical = !isGlancing && (_rng.nextDouble() < attacker.critRate);
    final double critMod = isCritical ? attacker.critDamage : 1.0;

    // 3. Compute Defense Mitigation
    final int effectiveDefense = skill.ignoresArmor ? (target.defense * 0.5).round() : target.defense;
    final double mitigation = CombatMath.calculateMitigation(effectiveDefense);

    // 4. Compute Base and Final Damage
    final double baseDamage = attacker.attack * skill.damageCoefficient * mitigation;
    final double variance = 0.95 + (_rng.nextDouble() * 0.10);

    double totalDamage = baseDamage * affinityMod * critMod * variance;
    if (isGlancing) {
      totalDamage *= 0.70;
    }

    final int finalDamage = max(1, totalDamage.round());

    // 5. Apply Damage to Defender & Status Effects
    final int newTargetHp = max(0, target.currentHp - finalDamage);
    List<StatusEffect> targetEffects = List.of(target.activeEffects);
    if (skill.appliedStatus != null && !isGlancing && newTargetHp > 0) {
      targetEffects.add(skill.appliedStatus!);
    }

    final UnitEntity updatedTarget = target.copyWith(
      currentHp: newTargetHp,
      activeEffects: targetEffects,
    );

    // 6. Resolve Lifesteal
    int lifestealRecovered = 0;
    int attackerHp = attacker.currentHp;
    if (skill.lifestealRatio > 0.0 && attacker.isAlive) {
      lifestealRecovered = (finalDamage * skill.lifestealRatio).round();
      attackerHp = min(attacker.maxHp, attackerHp + lifestealRecovered);
    }

    // 7. Update Cooldowns and Ultimate Charge
    final double newUltimate = skill.isLimitBurst
        ? 0.0
        : (attacker.ultimateCharge + 25.0).clamp(0.0, 100.0);

    final List<SkillEntity> updatedSkills = attacker.resolvedSkills.map((s) {
      if (s.id == skill.id) {
        return s.copyWith(currentCooldown: s.cooldownTurns);
      } else if (s.currentCooldown > 0) {
        return s.copyWith(currentCooldown: s.currentCooldown - 1);
      }
      return s;
    }).toList();

    final UnitEntity updatedAttacker = attacker.copyWith(
      currentHp: attackerHp,
      ultimateCharge: newUltimate,
      skills: updatedSkills,
    );

    // 8. Reconstruct Squad State
    List<UnitEntity> updatedAllies = List.of(tickManager.allies);
    List<UnitEntity> updatedEnemies = List.of(tickManager.enemies);

    if (attackerIsAlly) {
      updatedAllies = updatedAllies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();
    } else {
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedAllies = updatedAllies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();
    }

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
      skillName: skill.name,
      appliedStatusName: skill.appliedStatus?.displayName,
    );
  }

  ActionResult _executeSupportSkill({
    required UnitEntity attacker,
    required List<UnitEntity> friendlySquad,
    required String targetUnitId,
    required SkillEntity skill,
    required bool attackerIsAlly,
    required bool autoResumeTickEngine,
  }) {
    final int targetIndex = friendlySquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    final UnitEntity target = targetIndex != -1 ? friendlySquad[targetIndex] : attacker;

    final int healAmount = (target.maxHp * 0.25).round();
    final int newHp = min(target.maxHp, target.currentHp + healAmount);

    List<StatusEffect> effects = List.of(target.activeEffects);
    if (skill.appliedStatus != null) {
      effects.add(skill.appliedStatus!);
    }

    final UnitEntity updatedTarget = target.copyWith(
      currentHp: newHp,
      activeEffects: effects,
    );

    final List<SkillEntity> updatedSkills = attacker.resolvedSkills.map((s) {
      if (s.id == skill.id) {
        return s.copyWith(currentCooldown: s.cooldownTurns);
      }
      return s;
    }).toList();

    final UnitEntity updatedAttacker = attacker.id == target.id
        ? updatedTarget.copyWith(skills: updatedSkills)
        : attacker.copyWith(skills: updatedSkills);

    List<UnitEntity> updatedAllies = List.of(tickManager.allies);
    List<UnitEntity> updatedEnemies = List.of(tickManager.enemies);

    if (attackerIsAlly) {
      updatedAllies = updatedAllies.map((u) {
        if (u.id == updatedAttacker.id) return updatedAttacker;
        if (u.id == updatedTarget.id) return updatedTarget;
        return u;
      }).toList();
    } else {
      updatedEnemies = updatedEnemies.map((u) {
        if (u.id == updatedAttacker.id) return updatedAttacker;
        if (u.id == updatedTarget.id) return updatedTarget;
        return u;
      }).toList();
    }

    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: autoResumeTickEngine,
    );

    return ActionResult(
      attacker: updatedAttacker,
      target: updatedTarget,
      damageDealt: 0,
      healAmount: healAmount,
      isCritical: false,
      isGlancing: false,
      affinityMultiplier: 1.0,
      targetDefeated: false,
      lifestealRecovered: 0,
      skillName: skill.name,
      appliedStatusName: skill.appliedStatus?.displayName,
    );
  }
}
