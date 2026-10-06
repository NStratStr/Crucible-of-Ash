import 'dart:math';
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

  /// Selects a target ally prioritizing frontline Vanguard, then Arcanum
  UnitEntity? selectTargetAlly() {
    final aliveVanguard = tickManager.allies.where((u) => u.isVanguard && u.isAlive).toList();
    if (aliveVanguard.isNotEmpty) {
      return aliveVanguard[_rng.nextInt(aliveVanguard.length)];
    }
    final aliveAllies = tickManager.allies.where((u) => u.isAlive).toList();
    if (aliveAllies.isNotEmpty) {
      return aliveAllies[_rng.nextInt(aliveAllies.length)];
    }
    return null;
  }

  /// Executes the active enemy unit's turn and registers combat damage
  ActionResult? executeEnemyTurn({bool autoResume = true}) {
    if (!isEnemyTurn) return null;

    final target = selectTargetAlly();
    if (target == null) return null;

    final result = combatService.executeBasicAttack(
      targetUnitId: target.id,
      autoResumeTickEngine: autoResume,
    );

    commandService.registerCombatDamage(result.damageDealt);
    return result;
  }
}
