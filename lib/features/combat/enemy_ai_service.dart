import 'dart:math';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import 'combat_resolution_service.dart';
import 'initiative_tick_manager.dart';
import '../generals/general_command_service.dart';

class EnemyAiService {
  final InitiativeTickManager tickManager;
  final CombatResolutionService combatService;
  final GeneralCommandService commandService;
  final Random _rng;

  EnemyAiService({
    required this.tickManager,
    required this.combatService,
    required this.commandService,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Checks if the current active unit is an enemy awaiting action
  bool get isEnemyTurn {
    final active = tickManager.activeUnit;
    if (active == null || tickManager.phase != CombatPhase.awaitingAction) {
      return false;
    }
    return tickManager.enemies.any((u) => u.id == active.id && u.isAlive);
  }

  /// GDD v2.6 Section 3.3: Dynamic Targeting Hierarchy
  /// 1. Hard Constraints: Vanguard protection (melee targets must strike Vanguard before Arcanum)
  /// 2. Primary Priority Flag: Lowest EHP (Effective Health Points)
  /// 3. Tie-Breaker Metric: Slot proximity / lowest raw HP
  /// 4. Fallback: Nearest valid living ally
  UnitEntity? selectTargetAlly({UnitEntity? actingUnit}) {
    final aliveVanguard = tickManager.allies.where((u) => u.isVanguard && u.isAlive).toList();
    final List<UnitEntity> candidatePool = aliveVanguard.isNotEmpty
        ? aliveVanguard
        : tickManager.allies.where((u) => u.isAlive).toList();

    if (candidatePool.isEmpty) return null;

    // Sort by Lowest EHP (GDD Sec 3.1 & 3.3)
    candidatePool.sort((a, b) {
      final ehpCompare = a.ehp.compareTo(b.ehp);
      if (ehpCompare != 0) return ehpCompare;
      return a.currentHp.compareTo(b.currentHp);
    });

    return candidatePool.first;
  }

  /// Selects a friendly enemy target (for healing / buffs)
  UnitEntity? selectFriendlyTarget() {
    final wounded = tickManager.enemies.where((u) => u.isAlive && u.currentHp < u.maxHp).toList();
    if (wounded.isNotEmpty) {
      wounded.sort((a, b) => (a.currentHp / a.maxHp).compareTo(b.currentHp / b.maxHp));
      return wounded.first;
    }
    final alive = tickManager.enemies.where((u) => u.isAlive).toList();
    return alive.isNotEmpty ? alive.first : null;
  }

  /// Predicts the impending action intent of the enemy unit for telegraphing (GDD Sec 13.5)
  SkillEntity? predictNextSkill(UnitEntity enemy) {
    final readySkills = enemy.resolvedSkills.where((s) => s.isReady).toList();
    if (readySkills.isEmpty) return null;
    return readySkills.firstWhere(
      (s) => s.isLimitBurst && enemy.ultimateCharge >= 100.0,
      orElse: () => readySkills.firstWhere(
        (s) => s.cooldownTurns > 0,
        orElse: () => readySkills.first,
      ),
    );
  }

  /// Executes the active enemy unit's turn and registers combat damage
  ActionResult? executeEnemyTurn({bool autoResume = true}) {
    if (!isEnemyTurn) return null;

    final enemy = tickManager.activeUnit;
    if (enemy == null) return null;

    // Check for Stun first
    if (combatService.checkAndHandleStun()) {
      return null;
    }

    // Pick best ready skill (Limit burst > Signature skill > Basic)
    final readySkills = enemy.resolvedSkills.where((s) => s.isReady).toList();
    SkillEntity chosenSkill = readySkills.firstWhere(
      (s) => s.isLimitBurst && enemy.ultimateCharge >= 100.0,
      orElse: () => readySkills.firstWhere(
        (s) => s.cooldownTurns > 0,
        orElse: () => readySkills.first,
      ),
    );

    final bool isFriendlySkill = chosenSkill.targetType == SkillTargetType.singleAlly ||
        chosenSkill.targetType == SkillTargetType.allAllies ||
        chosenSkill.damageCoefficient == 0.0;

    final target = isFriendlySkill ? selectFriendlyTarget() : selectTargetAlly();
    if (target == null) return null;

    final result = combatService.executeSkill(
      targetUnitId: target.id,
      skill: chosenSkill,
      autoResumeTickEngine: autoResume,
    );

    commandService.registerCombatDamage(result.damageDealt);
    return result;
  }
}
