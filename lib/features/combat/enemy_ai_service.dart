import 'dart:math';
import '../../core/combat_math.dart';
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

  /// GDD v2.8 Section 3.3: Dynamic Targeting Hierarchy for Targeting Allies
  /// Step 1 (Hard Constraints):
  ///   - Taunt/Provoke override: Must target taunting unit if alive.
  ///   - Line-of-Sight & Vanguard Protection: Melee/standard units must clear living Vanguard before Arcanum.
  ///     (Aerial/skirmisher units with dive_bomb bypass line-of-sight to strike Arcanum directly).
  /// Step 2 (Primary Priority Flag):
  ///   - Evaluates lowest EHP, then Role Class Priority (Support > Occultist > Marksman > Aberration > Tank).
  /// Step 3 (Tie-Breaker Metric):
  ///   - Highest Threat Score, Lowest current HP, Slot index proximity.
  /// Step 4 (Fallback):
  ///   - Nearest valid living ally.
  UnitEntity? selectTargetAlly({UnitEntity? actingUnit}) {
    final livingAllies = tickManager.allies.where((u) => u.isAlive).toList();
    if (livingAllies.isEmpty) return null;

    // STEP 1: Hard Constraints
    // 1A. Taunt / Provoke state override
    final tauntingAllies = livingAllies.where((u) => u.isTaunting).toList();
    if (tauntingAllies.isNotEmpty) {
      tauntingAllies.sort((a, b) => a.ehp.compareTo(b.ehp));
      return tauntingAllies.first;
    }

    // 1B. Line-of-Sight / Vanguard Raycast check:
    // Units with dive_bomb (Skirmishers/Flyers) or true-strike ignore frontline LoS constraints
    final bool bypassesFrontline = actingUnit != null &&
        (actingUnit.nativeTraitId == 'dive_bomb' ||
            actingUnit.graftedTraitId == 'dive_bomb' ||
            actingUnit.archetype == Archetype.skirmisher);

    List<UnitEntity> candidatePool;
    if (bypassesFrontline) {
      // Skirmishers prioritize rear Arcanum casters/healers directly
      final arcanumAllies = livingAllies.where((u) => u.isArcanum).toList();
      candidatePool = arcanumAllies.isNotEmpty ? arcanumAllies : livingAllies;
    } else {
      final aliveVanguard = livingAllies.where((u) => u.isVanguard).toList();
      candidatePool = aliveVanguard.isNotEmpty ? aliveVanguard : livingAllies;
    }

    if (candidatePool.isEmpty) return livingAllies.first;

    // STEP 2 & 3: Primary Priority Flag & Tie-Breakers
    candidatePool.sort((a, b) {
      // Primary: Lowest EHP (GDD Sec 3.1 & 3.3)
      final ehpCompare = a.ehp.compareTo(b.ehp);
      if (ehpCompare != 0) return ehpCompare;

      // Secondary: Role Class Priority (Support > Occultist > Marksman > Aberration > Tank)
      final roleCompare = a.rolePriorityOrder.compareTo(b.rolePriorityOrder);
      if (roleCompare != 0) return roleCompare;

      // Tertiary Tie-breaker: Highest Threat Score (dealers of high DPS prioritized)
      final threatCompare = b.threatScore.compareTo(a.threatScore);
      if (threatCompare != 0) return threatCompare;

      // Quaternary: Lowest current HP
      final hpCompare = a.currentHp.compareTo(b.currentHp);
      if (hpCompare != 0) return hpCompare;

      // Final Tie-breaker: Slot index proximity
      return a.slot.index.compareTo(b.slot.index);
    });

    return candidatePool.first;
  }

  /// GDD v2.8 Section 3.3: Dynamic Targeting Hierarchy for Targeting Enemies
  /// Step 1 (Hard Constraints):
  ///   - Taunt/Provoke override: Must target taunting unit if alive.
  ///   - Line-of-Sight & Vanguard Protection: Standard attacks target living Vanguard before Arcanum.
  ///     (Units with dive_bomb or Skirmisher archetype bypass frontline).
  /// Step 2 (Primary Priority Flag):
  ///   - Evaluates lowest EHP, then role class priority (Support > Occultist > Skirmisher > Aberration > Juggernaut/Colossus).
  /// Step 3 (Tie-Breaker Metric):
  ///   - Highest threat score, lowest current HP, slot index proximity.
  /// Step 4 (Fallback):
  ///   - Nearest valid living enemy.
  UnitEntity? selectTargetEnemy({UnitEntity? actingUnit}) {
    final livingEnemies = tickManager.enemies.where((u) => u.isAlive).toList();
    if (livingEnemies.isEmpty) return null;

    // STEP 1: Hard Constraints
    // 1A. Taunt / Provoke state override
    final tauntingEnemies = livingEnemies.where((u) => u.isTaunting).toList();
    if (tauntingEnemies.isNotEmpty) {
      tauntingEnemies.sort((a, b) => a.ehp.compareTo(b.ehp));
      return tauntingEnemies.first;
    }

    // 1B. Line-of-Sight / Vanguard Raycast check
    final bool bypassesFrontline = actingUnit != null &&
        (actingUnit.nativeTraitId == 'dive_bomb' ||
            actingUnit.graftedTraitId == 'dive_bomb' ||
            actingUnit.archetype == Archetype.skirmisher);

    List<UnitEntity> candidatePool;
    if (bypassesFrontline) {
      final arcanumEnemies = livingEnemies.where((u) => u.isArcanum).toList();
      candidatePool = arcanumEnemies.isNotEmpty ? arcanumEnemies : livingEnemies;
    } else {
      final aliveVanguard = livingEnemies.where((u) => u.isVanguard).toList();
      candidatePool = aliveVanguard.isNotEmpty ? aliveVanguard : livingEnemies;
    }

    if (candidatePool.isEmpty) return livingEnemies.first;

    // STEP 2 & 3: Primary Priority Flag & Tie-Breakers
    candidatePool.sort((a, b) {
      // Primary: Lowest EHP (GDD Sec 3.1 & 3.3)
      final ehpCompare = a.ehp.compareTo(b.ehp);
      if (ehpCompare != 0) return ehpCompare;

      // Secondary: Role Class Priority (Support > Occultist > Skirmisher > Aberration > Tank)
      final roleCompare = a.rolePriorityOrder.compareTo(b.rolePriorityOrder);
      if (roleCompare != 0) return roleCompare;

      // Tertiary: Highest Threat Score
      final threatCompare = b.threatScore.compareTo(a.threatScore);
      if (threatCompare != 0) return threatCompare;

      // Quaternary: Lowest current HP
      final hpCompare = a.currentHp.compareTo(b.currentHp);
      if (hpCompare != 0) return hpCompare;

      // Final Tie-breaker: Slot index proximity
      return a.slot.index.compareTo(b.slot.index);
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

    final target = isFriendlySkill ? selectFriendlyTarget() : selectTargetAlly(actingUnit: enemy);
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
