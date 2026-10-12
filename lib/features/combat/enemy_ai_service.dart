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

  /// GDD v2.9 Section 3.1 - 3.3: Dynamic Targeting with Deterministic Column Geometry & Rule-Breaking
  ///
  /// STEP 1 (Hard Constraints & Rule-Breakers):
  ///   - 1A. Taunt/Provoke override: Must target taunting unit if alive.
  ///   - 1B. Rule-Breaking Skill Target Types:
  ///         * lowestHpEnemy: Targets opponent with lowest current HP (Assassinate / Execution).
  ///         * frontlineEnemies: Targets primary Frontline opponent (cleaves all Frontline).
  ///         * backlineEnemies: Targets primary Backline opponent (strikes all Backline).
  ///         * allEnemies: Targets primary lowest HP opponent (AoE strikes all opponents).
  ///   - 1C. Aerial / Skirmisher Trait: dive_bomb bypasses Frontline to strike Backline directly.
  ///
  /// STEP 2 (Deterministic 5-Column & Row Grid Geometry - Basic Attacks & Standard Single-Target):
  ///   - 2A. Direct Column Target: Attacks fire directly across into the opposing unit occupying
  ///         the same column index (Col N -> Col N).
  ///   - 2B. Line Precedence: If the target column has a unit in the Frontline, the Frontline unit
  ///         absorbs the attack. If Frontline is empty, the attack penetrates directly into Backline.
  ///   - 2C. Adjacency Fallback: If the direct column is completely empty, targeting cascades
  ///         to nearest adjacent columns (|Col_target - Col_actor| = 1, then 2, etc.)
  ///         maintaining Line Precedence (Frontline absorbs before Backline).
  ///
  /// STEP 3 (Tie-Breakers & Graceful Fallback):
  ///   - Lowest current HP, lowest EHP, role priority.
  UnitEntity? selectTargetAlly({UnitEntity? actingUnit, SkillEntity? skill}) {
    final livingAllies = tickManager.allies.where((u) => u.isAlive).toList();
    if (livingAllies.isEmpty) return null;

    // STEP 1: Hard Constraints & Rule-Breaking Overrides
    // 1A. Taunt / Provoke state override
    final tauntingAllies = livingAllies.where((u) => u.isTaunting).toList();
    if (tauntingAllies.isNotEmpty) {
      tauntingAllies.sort((a, b) => a.ehp.compareTo(b.ehp));
      return tauntingAllies.first;
    }

    // 1B. Special Skill Target Rule-Breakers (AoE, Execution, Cleave)
    if (skill != null) {
      if (skill.targetType == SkillTargetType.lowestHpEnemy) {
        final sortedByHp = List<UnitEntity>.from(livingAllies)
          ..sort((a, b) {
            final hpComp = a.currentHp.compareTo(b.currentHp);
            if (hpComp != 0) return hpComp;
            return a.ehp.compareTo(b.ehp);
          });
        return sortedByHp.first;
      }
      if (skill.targetType == SkillTargetType.frontlineEnemies) {
        final vanguards = livingAllies.where((u) => u.isFrontline).toList();
        if (vanguards.isNotEmpty) {
          vanguards.sort((a, b) => a.currentHp.compareTo(b.currentHp));
          return vanguards.first;
        }
      }
      if (skill.targetType == SkillTargetType.backlineEnemies) {
        final arcanums = livingAllies.where((u) => u.isBackline).toList();
        if (arcanums.isNotEmpty) {
          arcanums.sort((a, b) => a.currentHp.compareTo(b.currentHp));
          return arcanums.first;
        }
      }
      if (skill.targetType == SkillTargetType.allEnemies) {
        final sortedByHp = List<UnitEntity>.from(livingAllies)
          ..sort((a, b) => a.currentHp.compareTo(b.currentHp));
        return sortedByHp.first;
      }
    }

    // 1C. Aerial / Skirmisher Trait: dive_bomb bypasses Frontline to strike Backline directly
    final bool bypassesFrontline = actingUnit != null &&
        (actingUnit.nativeTraitId == 'dive_bomb' ||
            actingUnit.graftedTraitId == 'dive_bomb' ||
            actingUnit.archetype == Archetype.skirmisher);

    if (bypassesFrontline) {
      final arcanumAllies = livingAllies.where((u) => u.isArcanum).toList();
      if (arcanumAllies.isNotEmpty) {
        if (actingUnit != null) {
          return _resolveDeterministicColumnTarget(
            livingOpponents: arcanumAllies,
            actorCol: actingUnit.columnIndex,
          );
        }
        arcanumAllies.sort((a, b) => a.ehp.compareTo(b.ehp));
        return arcanumAllies.first;
      }
    }

    // STEP 2: Deterministic Column & Row Geometry (Basic Attacks and Single-Target Strikes)
    if (actingUnit != null) {
      return _resolveDeterministicColumnTarget(
        livingOpponents: livingAllies,
        actorCol: actingUnit.columnIndex,
      );
    }

    // Fallback if no acting unit specified: Lowest EHP living ally
    final sortedFallback = List<UnitEntity>.from(livingAllies)..sort((a, b) => a.ehp.compareTo(b.ehp));
    return sortedFallback.first;
  }

  /// GDD v2.9 Section 3.1 - 3.3: Deterministic Column & Row Geometry for Targeting Enemies
  UnitEntity? selectTargetEnemy({UnitEntity? actingUnit, SkillEntity? skill}) {
    final livingEnemies = tickManager.enemies.where((u) => u.isAlive).toList();
    if (livingEnemies.isEmpty) return null;

    // STEP 1: Hard Constraints & Rule-Breaking Overrides
    // 1A. Taunt / Provoke state override
    final tauntingEnemies = livingEnemies.where((u) => u.isTaunting).toList();
    if (tauntingEnemies.isNotEmpty) {
      tauntingEnemies.sort((a, b) => a.ehp.compareTo(b.ehp));
      return tauntingEnemies.first;
    }

    // 1B. Special Skill Target Rule-Breakers (AoE, Execution, Cleave)
    if (skill != null) {
      if (skill.targetType == SkillTargetType.lowestHpEnemy) {
        final sortedByHp = List<UnitEntity>.from(livingEnemies)
          ..sort((a, b) {
            final hpComp = a.currentHp.compareTo(b.currentHp);
            if (hpComp != 0) return hpComp;
            return a.ehp.compareTo(b.ehp);
          });
        return sortedByHp.first;
      }
      if (skill.targetType == SkillTargetType.frontlineEnemies) {
        final vanguards = livingEnemies.where((u) => u.isFrontline).toList();
        if (vanguards.isNotEmpty) {
          vanguards.sort((a, b) => a.currentHp.compareTo(b.currentHp));
          return vanguards.first;
        }
      }
      if (skill.targetType == SkillTargetType.backlineEnemies) {
        final arcanums = livingEnemies.where((u) => u.isBackline).toList();
        if (arcanums.isNotEmpty) {
          arcanums.sort((a, b) => a.currentHp.compareTo(b.currentHp));
          return arcanums.first;
        }
      }
      if (skill.targetType == SkillTargetType.allEnemies) {
        final sortedByHp = List<UnitEntity>.from(livingEnemies)
          ..sort((a, b) => a.currentHp.compareTo(b.currentHp));
        return sortedByHp.first;
      }
    }

    // 1C. Aerial / Skirmisher Trait: dive_bomb bypasses Frontline
    final bool bypassesFrontline = actingUnit != null &&
        (actingUnit.nativeTraitId == 'dive_bomb' ||
            actingUnit.graftedTraitId == 'dive_bomb' ||
            actingUnit.archetype == Archetype.skirmisher);

    if (bypassesFrontline) {
      final arcanumEnemies = livingEnemies.where((u) => u.isArcanum).toList();
      if (arcanumEnemies.isNotEmpty) {
        if (actingUnit != null) {
          return _resolveDeterministicColumnTarget(
            livingOpponents: arcanumEnemies,
            actorCol: actingUnit.columnIndex,
          );
        }
        arcanumEnemies.sort((a, b) => a.ehp.compareTo(b.ehp));
        return arcanumEnemies.first;
      }
    }

    // STEP 2: Deterministic Column & Row Geometry
    if (actingUnit != null) {
      return _resolveDeterministicColumnTarget(
        livingOpponents: livingEnemies,
        actorCol: actingUnit.columnIndex,
      );
    }

    final sortedFallback = List<UnitEntity>.from(livingEnemies)..sort((a, b) => a.ehp.compareTo(b.ehp));
    return sortedFallback.first;
  }

  /// Resolves target among [livingOpponents] using GDD v2.9 Section 3.2 deterministic geometry:
  /// 1. Direct Column Target: Opposing unit with same columnIndex.
  ///    Line Precedence: Frontline absorbs before Backline in that column.
  /// 2. Adjacency Fallback: If direct column is empty, cascades to nearest adjacent columns
  ///    (|Col_target - Col_actor| = 1, then 2, etc.) prioritizing Frontline over Backline.
  /// 3. Tie-Breaker: Lowest current HP, lowest EHP, role priority.
  UnitEntity _resolveDeterministicColumnTarget({
    required List<UnitEntity> livingOpponents,
    required int actorCol,
  }) {
    // 1. Direct Column Check
    final directColOpponents = livingOpponents.where((u) => u.columnIndex == actorCol).toList();
    if (directColOpponents.isNotEmpty) {
      // Line Precedence: Frontline absorbs before Backline
      final vanguards = directColOpponents.where((u) => u.isFrontline).toList();
      if (vanguards.isNotEmpty) {
        vanguards.sort((a, b) {
          final hpComp = a.currentHp.compareTo(b.currentHp);
          if (hpComp != 0) return hpComp;
          return a.ehp.compareTo(b.ehp);
        });
        return vanguards.first;
      }
      final arcanums = directColOpponents.where((u) => u.isBackline).toList();
      if (arcanums.isNotEmpty) {
        arcanums.sort((a, b) => a.currentHp.compareTo(b.currentHp));
        return arcanums.first;
      }
      return directColOpponents.first;
    }

    // 2. Adjacency Fallback: Check nearest columns (|dist| = 1..4)
    for (int dist = 1; dist <= 4; dist++) {
      final candidateCols = [actorCol - dist, actorCol + dist].where((c) => c >= 0 && c <= 4).toSet();
      final adjacentOpponents = livingOpponents.where((u) => candidateCols.contains(u.columnIndex)).toList();

      if (adjacentOpponents.isNotEmpty) {
        // Line Precedence: Check if any adjacent opponent is Frontline
        final vanguards = adjacentOpponents.where((u) => u.isFrontline).toList();
        if (vanguards.isNotEmpty) {
          vanguards.sort((a, b) {
            // Distance proximity first
            final distA = (a.columnIndex - actorCol).abs();
            final distB = (b.columnIndex - actorCol).abs();
            if (distA != distB) return distA.compareTo(distB);
            // Tie-breaker: Lowest current HP
            final hpComp = a.currentHp.compareTo(b.currentHp);
            if (hpComp != 0) return hpComp;
            return a.ehp.compareTo(b.ehp);
          });
          return vanguards.first;
        }

        final arcanums = adjacentOpponents.where((u) => u.isBackline).toList();
        if (arcanums.isNotEmpty) {
          arcanums.sort((a, b) {
            final distA = (a.columnIndex - actorCol).abs();
            final distB = (b.columnIndex - actorCol).abs();
            if (distA != distB) return distA.compareTo(distB);
            return a.currentHp.compareTo(b.currentHp);
          });
          return arcanums.first;
        }

        return adjacentOpponents.first;
      }
    }

    // 3. Fallback: Lowest EHP living opponent
    final sortedFallback = List<UnitEntity>.from(livingOpponents)..sort((a, b) => a.ehp.compareTo(b.ehp));
    return sortedFallback.first;
  }

  /// Selects a friendly enemy target (for healing / buffs)
  UnitEntity? selectFriendlyTarget({SkillEntity? skill}) {
    if (skill?.targetType == SkillTargetType.lowestHpAlly) {
      final living = tickManager.enemies.where((u) => u.isAlive).toList();
      if (living.isEmpty) return null;
      living.sort((a, b) => (a.currentHp / a.maxHp).compareTo(b.currentHp / b.maxHp));
      return living.first;
    }
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
        chosenSkill.targetType == SkillTargetType.lowestHpAlly ||
        chosenSkill.damageCoefficient == 0.0;

    final target = isFriendlySkill
        ? selectFriendlyTarget(skill: chosenSkill)
        : selectTargetAlly(actingUnit: enemy, skill: chosenSkill);
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
