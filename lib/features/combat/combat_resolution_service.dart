import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../generals/general_command_service.dart';
import '../relics/relic_service.dart';
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
  final GeneralCommandService? commandService;
  final RelicService? relicService;
  final Random _rng;

  CombatResolutionService({
    required this.tickManager,
    this.commandService,
    this.relicService,
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

    return _executeOffensiveSkill(
      attacker: attacker,
      opposingSquad: opposingSquad,
      targetUnitId: targetUnitId,
      skill: skill,
      attackerIsAlly: attackerIsAlly,
      autoResumeTickEngine: autoResumeTickEngine,
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

    final int healValue = max(50, (target.maxHp * 0.25).round());
    final int newHp = min(target.maxHp, target.currentHp + healValue);
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
      } else if (s.currentCooldown > 0) {
        return s.copyWith(currentCooldown: s.currentCooldown - 1);
      }
      return s;
    }).toList();

    final UnitEntity updatedAttacker = attacker.id == updatedTarget.id
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
      isCritical: false,
      isGlancing: false,
      affinityMultiplier: 1.0,
      targetDefeated: false,
      lifestealRecovered: 0,
      healAmount: healValue,
      skillName: skill.name,
      appliedStatusName: skill.appliedStatus?.displayName,
    );
  }

  ActionResult _executeOffensiveSkill({
    required UnitEntity attacker,
    required List<UnitEntity> opposingSquad,
    required String targetUnitId,
    required SkillEntity skill,
    required bool attackerIsAlly,
    required bool autoResumeTickEngine,
  }) {
    final int targetIndex = opposingSquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    if (targetIndex == -1) {
      throw ArgumentError('Target unit $targetUnitId is either not found or already defeated.');
    }

    final UnitEntity target = opposingSquad[targetIndex];

    final attackerRelics = relicService?.calculateBonuses(attacker.id) ?? const UnitRelicBonuses();
    final targetRelics = relicService?.calculateBonuses(target.id) ?? const UnitRelicBonuses();

    // 1. Evaluate Hex Affinity and Glancing Blow status
    final double affinityMod = CombatMath.getAffinityMultiplier(attacker.archetype, target.archetype);
    final bool isGlancing = CombatMath.isGlancingBlow(attacker.archetype, target.archetype, _rng);

    // 2. Evaluate Critical Strike
    final double effectiveCritRate = (attacker.critRate + attackerRelics.bonusCritRate).clamp(0.0, 1.0);
    final double effectiveCritDmg = attacker.critDamage + attackerRelics.bonusCritDamage;
    final bool isCritical = !isGlancing && (_rng.nextDouble() < effectiveCritRate);
    final double critMod = isCritical ? effectiveCritDmg : 1.0;

    // 3. Compute Defense Mitigation
    int baseDefense = target.defense + targetRelics.bonusDefense;
    // Valeria's Iron Aegis: Frontline Vanguard allies gain +25% Armor
    if (!attackerIsAlly && commandService?.activeGeneralType == GeneralType.valeria && target.isVanguard) {
      baseDefense = (baseDefense * 1.25).round();
    }
    final int effectiveDefense = skill.ignoresArmor ? (baseDefense * 0.5).round() : baseDefense;
    final double mitigation = CombatMath.calculateMitigation(effectiveDefense);

    // 4. Compute Base and Final Damage
    final int effectiveAttack = attacker.attack + attackerRelics.bonusAttack;
    final double baseDamage = effectiveAttack * skill.damageCoefficient * mitigation;
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
    double effectiveLifestealRatio = skill.lifestealRatio + attackerRelics.bonusLifesteal;
    // Vladislav's Crimson Tithe: +8% Lifesteal against wounded or bleeding targets
    if (attackerIsAlly && commandService?.activeGeneralType == GeneralType.vladislav) {
      if (target.isBleeding || target.currentHp < target.maxHp) {
        effectiveLifestealRatio += 0.08;
      }
    }

    int lifestealRecovered = 0;
    int attackerHp = attacker.currentHp;
    if (effectiveLifestealRatio > 0.0 && attacker.isAlive) {
      lifestealRecovered = (finalDamage * effectiveLifestealRatio).round();
      attackerHp = min(attacker.maxHp, attackerHp + lifestealRecovered);
    }

    // Valeria's Iron Aegis: If enemy attacks an allied Vanguard, 15% physical damage reflected back to attacker
    if (!attackerIsAlly && commandService?.activeGeneralType == GeneralType.valeria && target.isVanguard) {
      final int reflected = max(1, (finalDamage * 0.15).round());
      attackerHp = max(0, attackerHp - reflected);
    }

    // Morrigan's Temporal Threads: Crits grant +5% Turn Meter
    double bonusTmFromCrit = 0.0;
    if (attackerIsAlly && commandService?.activeGeneralType == GeneralType.morrigan && isCritical) {
      bonusTmFromCrit = 5.0;
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
      turnMeter: attacker.turnMeter + bonusTmFromCrit,
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

    // Malakor's Carrion Miasma: When an ally falls, all enemies gain 2 stacks of Blight
    if (commandService?.activeGeneralType == GeneralType.malakor) {
      final bool allyJustDied = (attackerIsAlly && updatedAttacker.currentHp == 0) ||
          (!attackerIsAlly && updatedTarget.currentHp == 0);
      if (allyJustDied) {
        updatedEnemies = updatedEnemies.map((e) {
          if (!e.isAlive) return e;
          final effects = List<StatusEffect>.from(e.activeEffects)
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40))
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
          return e.copyWith(activeEffects: effects);
        }).toList();
      }
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
}
