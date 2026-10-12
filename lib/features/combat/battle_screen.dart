import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/combat_math.dart';
import '../../shared/models/expedition_boon.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/data/starter_brigades.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
import '../../shared/widgets/living_atmosphere_background.dart';
import '../../shared/widgets/hexagonal_affinity_wheel_widget.dart';
import 'combat_resolution_service.dart';
import 'enemy_ai_service.dart';
import 'initiative_tick_manager.dart';
import 'plinth_rim_status_painter.dart';
import 'wargaming_spell_card.dart';
import '../generals/general_command_service.dart';
import '../generals/general_selection_dialog.dart';
import '../relics/relic_service.dart';

class FloatingCombatText {
  final String text;
  final Color color;
  final bool isCrit;
  final Key key = UniqueKey();

  FloatingCombatText({
    required this.text,
    required this.color,
    this.isCrit = false,
  });
}

class GeneralOrderBannerData {
  final String generalName;
  final String orderName;
  final int focusCost;
  final Color themeColor;
  final IconData icon;
  final String summary;

  const GeneralOrderBannerData({
    required this.generalName,
    required this.orderName,
    required this.focusCost,
    required this.themeColor,
    required this.icon,
    required this.summary,
  });
}

class LimitBurstBannerData {
  final UnitEntity caster;
  final SkillEntity skill;
  final String targetName;

  const LimitBurstBannerData({
    required this.caster,
    required this.skill,
    required this.targetName,
  });
}

/// Greyscale color filter matrix that preserves 100% of alpha transparency,
/// avoiding the solid-grey bleed bug caused by [BlendMode.saturation] on transparent PNG canvases.
const ColorFilter kAlphaSafeGreyscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, // Red
  0.2126, 0.7152, 0.0722, 0, 0, // Green
  0.2126, 0.7152, 0.0722, 0, 0, // Blue
  0,      0,      0,      1, 0, // Alpha (Preserves 100% of original transparency)
]);

class BattleScreen extends StatefulWidget {
  final InitiativeTickManager tickManager;
  final CombatResolutionService combatService;
  final GeneralCommandService commandService;
  final RelicService? relicService;
  final int bloodlineSigils;
  final ValueChanged<int>? onSigilsChanged;
  final VoidCallback? onResetEncounter;
  final VoidCallback? onDeployMvpSkirmish;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;
  final List<List<UnitEntity>>? enemyWaves;
  final bool initialAutoBattle;
  final bool startInPreBattleSetup;

  const BattleScreen({
    super.key,
    required this.tickManager,
    required this.combatService,
    required this.commandService,
    this.relicService,
    this.bloodlineSigils = 0,
    this.onSigilsChanged,
    this.onResetEncounter,
    this.onDeployMvpSkirmish,
    this.onVictory,
    this.onDefeat,
    this.enemyWaves,
    this.initialAutoBattle = false,
    this.startInPreBattleSetup = false,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  int _currentWaveIndex = 0;
  String? _selectedEnemyId;
  String _combatLog = 'Prepare for engagement. The Crucible awaits.';
  late EnemyAiService _aiService;
  bool _isProcessingAiTurn = false;
  bool _autoBattle = false;
  Timer? _autoBattleTimer;
  Timer? _aiTurnTimer;
  bool _hasDispatchedEndOutcome = false;
  List<List<UnitEntity>>? _localEnemyWaves;
  bool _isPreBattleSetup = false;
  String? _selectedSwapUnitId;

  void _commenceBattle() {
    setState(() {
      _isPreBattleSetup = false;
      _selectedSwapUnitId = null;
      _combatLog = 'Engagement commenced! Honor through blood and steel.';
    });
    _addPop('ENGAGEMENT COMMENCED!', const Color(0xFFFFD54F), isCrit: true);
    if (widget.tickManager.phase == CombatPhase.idle) {
      widget.tickManager.start();
    }
    if (_autoBattle && _isPlayerTurnNow && !_isProcessingAiTurn) {
      _handleAutoPlayerTurn();
    } else if (_aiService.isEnemyTurn && !_isProcessingAiTurn) {
      _handleAiTurn();
    }
  }

  void _swapAlliedUnits(int indexA, int indexB) {
    if (indexA < 0 ||
        indexA >= widget.tickManager.allies.length ||
        indexB < 0 ||
        indexB >= widget.tickManager.allies.length ||
        indexA == indexB) {
      return;
    }
    final List<UnitEntity> allies = List<UnitEntity>.from(widget.tickManager.allies);
    final unitA = allies[indexA];
    final unitB = allies[indexB];

    final FormationSlot slotA = indexA < FormationSlot.values.length
        ? FormationSlot.values[indexA]
        : FormationSlot.front1;
    final FormationSlot slotB = indexB < FormationSlot.values.length
        ? FormationSlot.values[indexB]
        : FormationSlot.front1;

    allies[indexA] = unitB.copyWith(
      slot: slotA,
      columnIndexOverride: indexA,
      isFrontlineOverride: unitB.isFrontline,
    );
    allies[indexB] = unitA.copyWith(
      slot: slotB,
      columnIndexOverride: indexB,
      isFrontlineOverride: unitA.isFrontline,
    );

    widget.tickManager.updateSquads(allies: allies);
    setState(() {
      _selectedSwapUnitId = null;
      _combatLog = 'Repositioned: ${unitA.name} to Col ${indexB + 1}, ${unitB.name} to Col ${indexA + 1}.';
    });
    _addPop('SWAPPED COLUMNS!', const Color(0xFFFFD54F));
  }

  void _shiftAlliedUnit(int currentIndex, int direction) {
    final targetIndex = currentIndex + direction;
    if (targetIndex >= 0 && targetIndex < widget.tickManager.allies.length) {
      _swapAlliedUnits(currentIndex, targetIndex);
    }
  }

  void _showPreBattleCardInfo(GeneralOrderDefinition order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: Color(0xFFE5A93C), width: 1.5),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5A93C)),
                      ),
                      child: Text(
                        '${order.focusCost} FOCUS',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚡ Ready in Opening Hand. Playable during combat once Focus is accumulated.',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleAlliedLane(String unitId) {
    final updatedAllies = widget.tickManager.allies.map((u) {
      if (u.id == unitId) {
        final nextFrontline = !u.isFrontline;
        return u.copyWith(isFrontlineOverride: nextFrontline);
      }
      return u;
    }).toList();
    widget.tickManager.updateSquads(allies: updatedAllies);
    setState(() {});
  }

  void _applyFormationPreset({required bool? allFrontline}) {
    final updatedAllies = widget.tickManager.allies.map((u) {
      if (allFrontline == null) {
        // Balanced default: default based on slot (front slots = front, back slots = back)
        return u.copyWith(isFrontlineOverride: u.slot.index < 3);
      } else {
        return u.copyWith(isFrontlineOverride: allFrontline);
      }
    }).toList();
    widget.tickManager.updateSquads(allies: updatedAllies);
    setState(() {});
  }

  void _deployMvpSkirmish() {
    if (widget.onDeployMvpSkirmish != null) {
      widget.onDeployMvpSkirmish!();
      return;
    }
    final waves = StarterBrigades.createMvpThreeWaveSkirmish();
    final allies = StarterBrigades.createAshLegionPlayerSquad();
    _localEnemyWaves = waves;
    _currentWaveIndex = 0;
    _hasDispatchedEndOutcome = false;
    _isProcessingAiTurn = false;
    _isPreBattleSetup = false;
    _selectedEnemyId = waves.first.first.id;
    widget.tickManager.updateSquads(allies: allies, enemies: waves.first);
    widget.commandService.initializeGrimoire();
    _autoBattle = true;
    _addPop('MVP 3-WAVE SKIRMISH ENGAGED!', const Color(0xFFFFD54F), isCrit: true);
    setState(() {
      _combatLog = '[MVP ENGAGED] Ash Legion vs Crypt Stalkers. 3 Waves to Gorgoroth!';
    });
    widget.tickManager.start();
    if (_isPlayerTurnNow && !_isProcessingAiTurn) {
      _handleAutoPlayerTurn();
    } else if (_aiService.isEnemyTurn && !_isProcessingAiTurn) {
      _handleAiTurn();
    }
  }

  final List<FloatingCombatText> _floatingPops = [];
  final List<Timer> _popTimers = [];

  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _screenFlashType;
  Color? _screenFlashColorOverride;
  GeneralOrderBannerData? _activeOrderBanner;
  LimitBurstBannerData? _activeLimitBurstBanner;
  int? _hoveredCardIndex;
  Offset _screenShake = Offset.zero;
  Timer? _shakeTimer;

  void _triggerScreenShake({bool isHeavy = false}) {
    _shakeTimer?.cancel();
    final double intensity = isHeavy ? 9.0 : 3.5;
    setState(() {
      _screenShake = Offset(
        (intensity * (Random().nextBool() ? 1.0 : -1.0)),
        (intensity * 0.6 * (Random().nextBool() ? 1.0 : -1.0)),
      );
    });
    _shakeTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() {
          _screenShake = Offset.zero;
        });
      }
    });
  }

  void _addPop(String text, Color color, {bool isCrit = false}) {
    if (!mounted) return;
    final pop = FloatingCombatText(text: text, color: color, isCrit: isCrit);
    setState(() => _floatingPops.add(pop));
    final timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _floatingPops.remove(pop));
    });
    _popTimers.add(timer);
  }

  String _resolveCombatVfx(UnitEntity attacker, {SkillEntity? skill, bool isCrit = false}) {
    if (isCrit || (skill != null && skill.isLimitBurst)) return 'crit';
    if (attacker.isBoss) return 'boss';
    if (attacker.archetype == Archetype.marksman) return 'pierce';
    if (attacker.archetype == Archetype.occultist) return 'magic';
    if (attacker.archetype == Archetype.juggernaut) return 'crush';
    return 'slash';
  }

  void _triggerAttackAnimation(String attackerId, String targetId, {String? vfx}) {
    if (!mounted) return;
    final bool isHeavy = vfx == 'crit' || vfx == 'boss' || vfx == 'crush';
    _triggerScreenShake(isHeavy: isHeavy);
    setState(() {
      _attackingUnitId = attackerId;
      _damagedUnitId = targetId;
      _screenFlashType = vfx ?? 'slash';
      _screenFlashColorOverride = null;
    });

    final double speedMult = widget.tickManager.speedMultiplier;
    final int animDurationMs = (850 / speedMult).round().clamp(480, 1300);

    final timer = Timer(Duration(milliseconds: animDurationMs), () {
      if (mounted) {
        setState(() {
          _attackingUnitId = null;
          _damagedUnitId = null;
          _screenFlashType = null;
          _screenFlashColorOverride = null;
        });
      }
    });
    _popTimers.add(timer);
  }

  @override
  void initState() {
    super.initState();
    _isPreBattleSetup = widget.startInPreBattleSetup;
    if (_isPreBattleSetup && widget.tickManager.phase == CombatPhase.ticking) {
      widget.tickManager.pause();
    }
    _autoBattle = widget.initialAutoBattle;
    _aiService = EnemyAiService(
      tickManager: widget.tickManager,
      combatService: widget.combatService,
      commandService: widget.commandService,
    );

    widget.tickManager.addListener(_onEngineUpdate);
    widget.commandService.addListener(_onEngineUpdate);

    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive);
    if (aliveEnemies.isNotEmpty) {
      _selectedEnemyId = _aiService.selectTargetEnemy()?.id ?? aliveEnemies.first.id;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isPreBattleSetup) {
        if (widget.tickManager.phase == CombatPhase.idle) {
          widget.tickManager.start();
        }
        if (_autoBattle && _isPlayerTurnNow && !_isProcessingAiTurn) {
          _handleAutoPlayerTurn();
        } else if (_aiService.isEnemyTurn && !_isProcessingAiTurn) {
          _handleAiTurn();
        }
      }
    });
  }

  @override
  void didUpdateWidget(BattleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickManager != widget.tickManager) {
      oldWidget.tickManager.removeListener(_onEngineUpdate);
      oldWidget.commandService.removeListener(_onEngineUpdate);

      _aiService = EnemyAiService(
        tickManager: widget.tickManager,
        combatService: widget.combatService,
        commandService: widget.commandService,
      );

      widget.tickManager.addListener(_onEngineUpdate);
      widget.commandService.addListener(_onEngineUpdate);

      final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive);
      if (aliveEnemies.isNotEmpty) {
        _selectedEnemyId = _aiService.selectTargetEnemy()?.id ?? aliveEnemies.first.id;
      }

      _isProcessingAiTurn = false;
      _hasDispatchedEndOutcome = false;
      _isPreBattleSetup = widget.startInPreBattleSetup;
      if (_isPreBattleSetup && widget.tickManager.phase == CombatPhase.ticking) {
        widget.tickManager.pause();
      }
      _combatLog = 'Encounter engaged! The Crucible awakens.';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isPreBattleSetup && widget.tickManager.phase == CombatPhase.idle) {
          widget.tickManager.start();
        }
      });
    }
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _autoBattleTimer?.cancel();
    _aiTurnTimer?.cancel();
    for (final t in _popTimers) {
      t.cancel();
    }
    _popTimers.clear();
    widget.tickManager.removeListener(_onEngineUpdate);
    widget.commandService.removeListener(_onEngineUpdate);
    super.dispose();
  }


  void _openInspectorModal(UnitEntity unit, bool isEnemy) {
    final wasTicking = widget.tickManager.phase == CombatPhase.ticking;
    if (wasTicking) {
      widget.tickManager.pause();
    }
    PedigreeInspectorDialog.show(
      context,
      unit,
      isEnemy: isEnemy,
      relicService: widget.relicService,
    ).then((_) {
      if (mounted && wasTicking && widget.tickManager.phase != CombatPhase.battleEnded) {
        widget.tickManager.start();
      }
    });
  }

  String? _lastProcessedTurnStartUnitId;

  void _onEngineUpdate() {
    if (!mounted) return;

    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
    if (aliveEnemies.isEmpty) {
      _selectedEnemyId = null;
    } else {
      final tauntingEnemy = aliveEnemies.where((u) => u.isTaunting).firstOrNull;
      if (tauntingEnemy != null) {
        _selectedEnemyId = tauntingEnemy.id;
      } else if (_selectedEnemyId == null || !aliveEnemies.any((u) => u.id == _selectedEnemyId)) {
        final optimal = _aiService.selectTargetEnemy(actingUnit: widget.tickManager.activeUnit);
        _selectedEnemyId = optimal?.id ?? aliveEnemies.first.id;
      }
    }

    final active = widget.tickManager.activeUnit;
    if (active != null && widget.tickManager.phase == CombatPhase.awaitingAction) {
      if (_lastProcessedTurnStartUnitId != active.id) {
        _lastProcessedTurnStartUnitId = active.id;
        final startRes = widget.combatService.processTurnStart(unitId: active.id);
        if (startRes.dotDamage > 0) {
          _triggerDamagePop(damage: startRes.dotDamage, isCrit: false, isGlancing: false);
        }
        if (startRes.healAmount > 0) {
          _triggerDamagePop(damage: 0, isCrit: false, isGlancing: false, heal: startRes.healAmount);
        }
        if (startRes.isDefeated) {
          _combatLog = startRes.message ?? '${active.name} succumbed to internal rot!';
        } else if (startRes.isStunned) {
          _combatLog = startRes.message ?? '${active.name} is Stunned! Turn skipped.';
        } else if (startRes.triggeredTraits.isNotEmpty) {
          _combatLog = '${active.name} triggered ${startRes.triggeredTraits.join(', ')}!';
        }
      }
    } else if (active == null) {
      _lastProcessedTurnStartUnitId = null;
    }

    // GDD v2.6 Sec 13.2: Check for Boss Phase Shifts (66% and 33% HP)
    final phaseShiftMsg = widget.tickManager.lastPhaseShiftMessage;
    if (phaseShiftMsg != null) {
      widget.tickManager.clearLastPhaseShiftMessage();
      _combatLog = phaseShiftMsg;
      _addPop('⚡ PHASE SHIFT! ⚡', const Color(0xFFFFD54F), isCrit: true);
      _triggerScreenShake();
    }

    if (_aiService.isEnemyTurn && !_isProcessingAiTurn) {
      _handleAiTurn();
    } else if (_autoBattle && _isPlayerTurnNow && !_isProcessingAiTurn) {
      _handleAutoPlayerTurn();
    }

    if (widget.tickManager.phase == CombatPhase.battleEnded && !_hasDispatchedEndOutcome) {
      if (widget.tickManager.enemies.every((u) => !u.isAlive)) {
        final waves = widget.enemyWaves ?? _localEnemyWaves;
        if (waves != null && _currentWaveIndex < waves.length - 1) {
          _currentWaveIndex++;
          final nextWave = waves[_currentWaveIndex];
          widget.tickManager.advanceWave(nextWave);
          final optimalNewTarget = _aiService.selectTargetEnemy();
          _selectedEnemyId = optimalNewTarget?.id ?? nextWave.firstWhere((e) => e.isAlive).id;
          _addPop('WAVE ${_currentWaveIndex + 1} ENGAGED!', const Color(0xFFFFD54F), isCrit: true);
          _combatLog = '[REINFORCEMENTS] Wave ${_currentWaveIndex + 1} of ${waves.length} enters the arena!';
          setState(() {});
          return;
        }
        _hasDispatchedEndOutcome = true;
        widget.onVictory?.call();
      } else if (widget.tickManager.allies.every((u) => !u.isAlive)) {
        _hasDispatchedEndOutcome = true;
        widget.onDefeat?.call();
      }
    }

    setState(() {});
  }

  bool get _isPlayerTurnNow {
    final active = widget.tickManager.activeUnit;
    return active != null &&
        widget.tickManager.phase == CombatPhase.awaitingAction &&
        widget.tickManager.allies.any((u) => u.id == active.id && u.isAlive);
  }

  void _triggerDamagePop({
    required int damage,
    required bool isCrit,
    required bool isGlancing,
    int heal = 0,
  }) {
    if (damage > 0) {
      _triggerScreenShake(isHeavy: isCrit || damage > 300);
      if (isCrit) {
        HapticFeedback.heavyImpact();
      } else if (isGlancing) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }

      final text = isCrit ? 'CRIT! -$damage' : (isGlancing ? 'GLANCE -$damage' : '-$damage');
      final color = isCrit
          ? const Color(0xFFFFD54F)
          : (isGlancing ? Colors.white60 : const Color(0xFFEF5350));

      final pop = FloatingCombatText(text: text, color: color, isCrit: isCrit);
      setState(() => _floatingPops.add(pop));

      final timer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _floatingPops.remove(pop));
      });
      _popTimers.add(timer);
    }

    if (heal > 0) {
      final healPop = FloatingCombatText(
        text: '+$heal HP',
        color: const Color(0xFF81C784),
      );
      setState(() => _floatingPops.add(healPop));

      final healTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _floatingPops.remove(healPop));
      });
      _popTimers.add(healTimer);
    }
  }

  void _handleAiTurn() {
    if (_isProcessingAiTurn || !_aiService.isEnemyTurn) return;
    _isProcessingAiTurn = true;
    _aiTurnTimer?.cancel();

    final double bulletMult = (widget.tickManager.isBulletTime || widget.commandService.isBulletTimeActive) ? 0.30 : 1.0;
    final int aiDelay = ((400 / widget.tickManager.speedMultiplier) / bulletMult).round();

    _aiTurnTimer = Timer(Duration(milliseconds: aiDelay), () {
      if (!mounted) return;
      try {
        final activeBefore = widget.tickManager.activeUnit;
        if (activeBefore == null || !_aiService.isEnemyTurn) {
          _isProcessingAiTurn = false;
          return;
        }

        final result = _aiService.executeEnemyTurn();

        if (result != null) {
          widget.commandService.registerCombatDamage(result.damageDealt);

          _triggerAttackAnimation(
            result.attacker.id,
            result.target.id,
            vfx: _resolveCombatVfx(result.attacker, isCrit: result.isCritical),
          );

          _triggerDamagePop(
            damage: result.damageDealt,
            isCrit: result.isCritical,
            isGlancing: result.isGlancing,
            heal: result.healAmount > 0 ? result.healAmount : result.lifestealRecovered,
          );

          setState(() {
            final glanceText = result.isGlancing ? ' [GLANCING BLOW -30% DMG]' : '';
            final critText = result.isCritical ? ' [CRIT!]' : '';
            final guardedText = result.isGuarded ? ' [GUARDED -20%]' : '';
            _combatLog =
                '${result.attacker.name} attacked ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText$guardedText.';
            if (result.targetDefeated) {
              _combatLog += ' ${result.target.name} fell in combat!';
            }
          });
          if (result.isGuarded) {
            _addPop('GUARDED (-20%)', const Color(0xFF90CAF9));
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _combatLog = 'Enemy action paused: $e');
        }
      }

      // Tactical Breathing Window: Keep _isProcessingAiTurn active until the attack animation finishes + a 400ms recovery gap
      final int turnPacingMs = ((1250 / widget.tickManager.speedMultiplier) / bulletMult).round().clamp(600, 4200);
      Timer(Duration(milliseconds: turnPacingMs), () {
        if (mounted) {
          _isProcessingAiTurn = false;
          if (_aiService.isEnemyTurn) {
            _handleAiTurn();
          } else if (_autoBattle && _isPlayerTurnNow) {
            _handleAutoPlayerTurn();
          }
        }
      });
    });
  }

  void _handleAutoPlayerTurn() {
    if (!_isPlayerTurnNow || _isProcessingAiTurn) return;

    final active = widget.tickManager.activeUnit;
    if (active == null) return;

    _isProcessingAiTurn = true;
    _autoBattleTimer?.cancel();

    final double bulletMult = (widget.tickManager.isBulletTime || widget.commandService.isBulletTimeActive) ? 0.30 : 1.0;
    final int autoDelay = ((350 / widget.tickManager.speedMultiplier) / bulletMult).round();

    _autoBattleTimer = Timer(Duration(milliseconds: autoDelay), () {
      if (!mounted || !_isPlayerTurnNow) {
        _isProcessingAiTurn = false;
        return;
      }

      try {
        final currentActive = widget.tickManager.activeUnit;
        if (currentActive == null || currentActive.id != active.id) {
          _isProcessingAiTurn = false;
          return;
        }

        final skills = currentActive.resolvedSkills;
        final readySkill = skills.reversed.firstWhere((s) => s.isReady, orElse: () => skills.first);

        final optimal = _aiService.selectTargetEnemy(actingUnit: currentActive);
        if (optimal != null) {
          _selectedEnemyId = optimal.id;
        } else if (_selectedEnemyId == null || !widget.tickManager.enemies.any((e) => e.id == _selectedEnemyId && e.isAlive)) {
          final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
          if (aliveEnemies.isNotEmpty) {
            _selectedEnemyId = aliveEnemies.first.id;
          }
        }

        if (_selectedEnemyId != null) {
          _executePlayerSkill(readySkill);
        }
      } catch (_) {}

      // Tactical Recovery Window after auto-attack
      final int turnPacingMs = ((1200 / widget.tickManager.speedMultiplier) / bulletMult).round().clamp(600, 4000);
      Timer(Duration(milliseconds: turnPacingMs), () {
        if (mounted) {
          _isProcessingAiTurn = false;
          if (_aiService.isEnemyTurn) {
            _handleAiTurn();
          } else if (_autoBattle && _isPlayerTurnNow) {
            _handleAutoPlayerTurn();
          }
        }
      });
    });
  }

  void _executePlayerSkill(SkillEntity skill) {
    if (!_isPlayerTurnNow) return;

    final targetId = skill.targetType == SkillTargetType.singleAlly
        ? widget.tickManager.allies.firstWhere((u) => u.isAlive).id
        : _selectedEnemyId;

    if (targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an enemy vessel first.'),
          backgroundColor: Color(0xFFB3261E),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    try {
      final result = widget.combatService.executeSkill(skill: skill, targetUnitId: targetId);

      widget.commandService.registerCombatDamage(result.damageDealt);

      _triggerAttackAnimation(
        result.attacker.id,
        result.target.id,
        vfx: _resolveCombatVfx(result.attacker, skill: skill, isCrit: result.isCritical),
      );

      _isProcessingAiTurn = true;
      final int playerAnimDuration = (1100 / widget.tickManager.speedMultiplier).round().clamp(600, 2500);
      Timer(Duration(milliseconds: playerAnimDuration), () {
        if (mounted) {
          _isProcessingAiTurn = false;
          if (_aiService.isEnemyTurn) {
            _handleAiTurn();
          }
        }
      });

      _triggerDamagePop(
        damage: result.damageDealt,
        isCrit: result.isCritical,
        isGlancing: result.isGlancing,
        heal: result.healAmount > 0 ? result.healAmount : result.lifestealRecovered,
      );

      if (skill.isLimitBurst) {
        setState(() {
          _activeLimitBurstBanner = LimitBurstBannerData(
            caster: result.attacker,
            skill: skill,
            targetName: result.target.name,
          );
        });

        final bannerTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _activeLimitBurstBanner = null;
            });
          }
        });
        _popTimers.add(bannerTimer);
      }

      setState(() {
        final glanceText = result.isGlancing ? ' [GLANCING BLOW -30% DMG]' : '';
        final critText = result.isCritical ? ' [CRIT!]' : '';
        final guardedText = result.isGuarded ? ' [GUARDED -20%]' : '';
        _combatLog =
            '${result.attacker.name} invoked ${skill.name} on ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText$guardedText.';
        if (result.targetDefeated) {
          _combatLog += ' ${result.target.name} was eradicated!';
        }
      });

      if (result.isGuarded) {
        _addPop('GUARDED (-20%)', const Color(0xFF90CAF9));
      }

      if (widget.tickManager.enemies.every((u) => !u.isAlive) && !_hasDispatchedEndOutcome) {
        _hasDispatchedEndOutcome = true;
        widget.onVictory?.call();
      }
    } catch (e) {
      setState(() {
        _combatLog = 'Action failed: $e';
      });
    }
  }

  void _executeOrder(void Function() orderAction) {
    try {
      orderAction();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _dispatchOrder(GeneralOrderDefinition order, {String? targetUnitId}) {
    _executeOrder(() {
      final oldAllies = List<UnitEntity>.from(widget.tickManager.allies);
      final oldEnemies = List<UnitEntity>.from(widget.tickManager.enemies);
      final profile = widget.commandService.currentProfile;

      OrderResult res;
      switch (widget.commandService.activeGeneralType) {
        case GeneralType.vladislav:
          if (order.id == 'rend_flesh') {
            final enemyId = targetUnitId ?? _selectedEnemyId ?? widget.tickManager.enemies.firstWhere((e) => e.isAlive).id;
            res = widget.commandService.executeRendFlesh(enemyId);
          } else if (order.id == 'iron_bulwark') {
            final allyId = targetUnitId ?? widget.tickManager.allies.firstWhere((a) => a.isAlive, orElse: () => throw StateError('No living ally to fortify.')).id;
            res = widget.commandService.executeIronBulwark(allyId);
          } else if (order.id == 'exsanguinating_strike') {
            final enemyId = targetUnitId ?? _selectedEnemyId ?? widget.tickManager.enemies.firstWhere((e) => e.isAlive).id;
            res = widget.commandService.executeExsanguinatingStrike(enemyId);
          } else if (order.id == 'sanguine_revival') {
            final fallenAllyId = targetUnitId ?? widget.tickManager.allies.firstWhere(
              (a) => !a.isAlive,
              orElse: () => throw StateError('No fallen ally to revive.'),
            ).id;
            res = widget.commandService.executeSanguineRevival(fallenAllyId);
          } else if (order.id == 'disrupting_cleave') {
            final enemyId = targetUnitId ?? _selectedEnemyId ?? widget.tickManager.enemies.firstWhere((e) => e.isAlive).id;
            res = widget.commandService.executeDisruptingCleave(enemyId);
          } else if (order.id == 'blood_boil') {
            final allyId = targetUnitId ?? widget.tickManager.allies.firstWhere((a) => a.isAlive, orElse: () => throw StateError('No living ally to buff.')).id;
            res = widget.commandService.executeBloodBoil(allyId);
          } else if (order.id == 'siphon_vitality') {
            if (_selectedEnemyId == null) {
              throw StateError('Select an enemy to siphon.');
            }
            res = widget.commandService.executeSiphonVitality(_selectedEnemyId!);
          } else if (order.id == 'sanguine_ward') {
            res = widget.commandService.executeSanguineWard();
          } else {
            if (_selectedEnemyId == null) {
              throw StateError('Select an enemy to execute.');
            }
            res = widget.commandService.executeFeastOfRuin(_selectedEnemyId!);
          }
          break;
        case GeneralType.valeria:
          if (order.id == 'stand_resolute') {
            final firstAliveAlly = widget.tickManager.allies.firstWhere(
              (a) => a.isAlive,
              orElse: () => throw StateError('No living ally to fortify.'),
            );
            res = widget.commandService.executeStandResolute(firstAliveAlly.id);
          } else if (order.id == 'retributive_stride') {
            res = widget.commandService.executeRetributiveStride();
          } else {
            if (_selectedEnemyId == null) {
              throw StateError('Select an enemy to smite.');
            }
            res = widget.commandService.executeSmiteTheWicked(_selectedEnemyId!);
          }
          break;
        case GeneralType.malakor:
          if (order.id == 'corpse_burst') {
            res = widget.commandService.executeCorpseBurst();
          } else if (order.id == 'virulent_cascade') {
            res = widget.commandService.executeVirulentCascade();
          } else {
            res = widget.commandService.executeRebindFlesh();
          }
          break;
        case GeneralType.morrigan:
          if (order.id == 'quicken') {
            final livingAllies = widget.tickManager.allies.where((a) => a.isAlive).toList();
            if (livingAllies.isEmpty) throw StateError('No living allies.');
            final target = livingAllies.firstWhere(
              (a) => a.turnMeter < 90,
              orElse: () => livingAllies.first,
            );
            res = widget.commandService.executeQuicken(target.id);
          } else if (order.id == 'unravel_hex') {
            res = widget.commandService.executeUnravelHex();
          } else {
            res = widget.commandService.executeEchoingHourglass();
          }
          break;
      }

      setState(() {
        _combatLog = '[${profile.name.toUpperCase()}] ${order.name}: ${res.summary}';
        _activeOrderBanner = GeneralOrderBannerData(
          generalName: profile.name,
          orderName: order.name,
          focusCost: order.focusCost,
          themeColor: profile.themeColor,
          icon: order.icon,
          summary: res.summary,
        );
        _screenFlashType = 'order';
        _screenFlashColorOverride = profile.themeColor;
      });

      // Spawn floating pops based on delta between pre- and post-order stats
      for (final newE in widget.tickManager.enemies) {
        final oldE = oldEnemies.where((e) => e.id == newE.id).firstOrNull;
        if (oldE != null) {
          if (oldE.isAlive && !newE.isAlive) {
            _addPop('EXECUTED', const Color(0xFFFF5252), isCrit: true);
          } else if (oldE.currentHp > newE.currentHp) {
            final diff = oldE.currentHp - newE.currentHp;
            _addPop('-$diff', const Color(0xFFEF5350));
          }
          if (oldE.turnMeter > newE.turnMeter && (oldE.turnMeter - newE.turnMeter) >= 20) {
            final tmDiff = (oldE.turnMeter - newE.turnMeter).round();
            _addPop('-$tmDiff% TM STAGGER', const Color(0xFFFF9100), isCrit: true);
            _triggerScreenShake(isHeavy: true);
          }
          final oldBleeds = oldE.activeEffects.where((e) => e.type == StatusEffectType.bleed).length;
          final newBleeds = newE.activeEffects.where((e) => e.type == StatusEffectType.bleed).length;
          if (newBleeds > oldBleeds) {
            _addPop('+BLEED (${newBleeds}x)', const Color(0xFFD32F2F));
          }
        }
      }

      for (final newA in widget.tickManager.allies) {
        final oldA = oldAllies.where((a) => a.id == newA.id).firstOrNull;
        if (oldA != null) {
          if (!oldA.isAlive && newA.isAlive) {
            _addPop('RESURRECTED', const Color(0xFF81C784), isCrit: true);
          } else if (newA.currentHp > oldA.currentHp) {
            final diff = newA.currentHp - oldA.currentHp;
            _addPop('+$diff HP', const Color(0xFF81C784));
          }
          if (newA.turnMeter > oldA.turnMeter && (newA.turnMeter - oldA.turnMeter) >= 25) {
            _addPop('+TM SURGE', const Color(0xFF00E5FF));
          }
          if (newA.defense > oldA.defense) {
            _addPop('+ARMOR', const Color(0xFF42A5F5));
          }
        }
      }

      final flashTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _screenFlashType = null;
            _screenFlashColorOverride = null;
          });
        }
      });
      _popTimers.add(flashTimer);

      final bannerTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _activeOrderBanner = null;
          });
        }
      });
      _popTimers.add(bannerTimer);

      if (widget.tickManager.enemies.every((u) => !u.isAlive) && !_hasDispatchedEndOutcome) {
        _hasDispatchedEndOutcome = true;
        widget.onVictory?.call();
      }
    });
  }

  Future<void> _showGeneralSelectionDialog() async {
    final chosen = await GeneralSelectionDialog.show(
      context,
      currentGeneralType: widget.commandService.activeGeneralType,
      commandService: widget.commandService,
      bloodlineSigils: widget.bloodlineSigils,
      onSigilsChanged: widget.onSigilsChanged,
    );
    if (!mounted || chosen == null) return;

    widget.commandService.setActiveGeneral(chosen);
    final profile = widget.commandService.currentProfile;
    setState(() {
      _combatLog = 'Commander sworn: ${profile.name} (${profile.title}) took command!';
    });
  }

  void _showHexWheelDialog([Archetype? activeArchetype]) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16161F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.hexagon_outlined, color: Color(0xFFD4AF37), size: 18),
              SizedBox(width: 8),
              Text(
                'HEXAGONAL AFFINITY WHEEL',
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Clockwise target = Advantage (+30% DMG, -15% Incoming)\n'
                'Counter-clockwise target = Disadvantage (-25% DMG, +25% Glancing Blow)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
              ),
              const SizedBox(height: 16),
              HexagonalAffinityWheelWidget(
                activeArchetype: activeArchetype,
                size: 220,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('DISMISS', style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrandBossBar(UnitEntity boss) {
    final double hpRatio = (boss.currentHp / boss.maxHp).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () {
        PedigreeInspectorDialog.show(
          context,
          boss,
          isEnemy: true,
          relicService: widget.relicService,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E0909), Color(0xFF140505), Color(0xFF2E0909)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFF5252), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF1744).withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dangerous, color: Color(0xFFFF5252), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'PRIMORDIAL BOSS: ${boss.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFF8A80), width: 0.8),
                      ),
                      child: Text(
                        'Lv.${boss.level} TITAN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E28),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment, size: 8, color: Color(0xFFFFD54F)),
                          SizedBox(width: 2),
                          Text(
                            'SHEET',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: hpRatio,
                minHeight: 7.0,
                backgroundColor: const Color(0xFF2A2A38),
                valueColor: AlwaysStoppedAnimation<Color>(
                  hpRatio > 0.4 ? const Color(0xFFC62828) : const Color(0xFFFF1744),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${boss.currentHp} / ${boss.maxHp} HP',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 7.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(hpRatio * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 7.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUnit = widget.tickManager.activeUnit;
    final isPlayerTurn = _isPlayerTurnNow;
    final selectedEnemy = widget.tickManager.enemies
        .where((u) => u.id == _selectedEnemyId)
        .firstOrNull;
    final activeBoss = widget.tickManager.enemies
        .where((u) => u.isAlive && u.isBoss)
        .firstOrNull;
    final bool isBossEncounter =
        widget.tickManager.enemies.any((u) => u.isBoss) || activeBoss != null;

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      body: LivingAtmosphereBackground(
        imageAsset: isBossEncounter
            ? 'assets/images/volcanic_chasm_battlefield.jpg'
            : 'assets/images/gothic_arch_battlefield.jpg',
        enableBreathing: true,
        enableFlicker: false,
        particleColor: const Color(0xFFFF7043),
        particleCount: 24,
        vignetteOpacity: 0.72,
        child: SafeArea(
          child: Stack(
            children: [
              Transform.translate(
                offset: _screenShake,
                child: Column(
                  children: [
                    _buildTopStatusBar(activeUnit, isPlayerTurn),
                    if (activeBoss != null) _buildGrandBossBar(activeBoss),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: MediaQuery.of(context).size.height < 760 ? 1.0 : 4.0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width >= 1000 ? 1440.0 : double.infinity,
                            ),
                            child: Builder(
                              builder: (context) {
                                final double screenWidth = MediaQuery.of(context).size.width;
                                final double screenHeight = MediaQuery.of(context).size.height;
                                final bool isMobile = screenWidth < 600;
                                final bool isCompact = screenHeight < 760;
                                final bool isUltraCompact = screenHeight < 620;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Vertical Initiative Ribbon along the left edge
                                    Padding(
                                      padding: EdgeInsets.only(right: isMobile ? 3.0 : 6.0),
                                      child: Center(
                                        child: SingleChildScrollView(
                                          child: _buildVerticalInitiativeTrack(
                                            isCompact: isCompact,
                                            isMobile: isMobile,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Main Battlefield Formation Field
                                    Expanded(
                                      child: Column(
                                        children: [
                                          // Hostile Formation (Arcanum backline top -> Vanguard frontline bottom)
                                          _buildSquadFormation(
                                            units: widget.tickManager.enemies,
                                            isEnemy: true,
                                            activeUnitId: activeUnit?.id,
                                            selectedTargetId: _selectedEnemyId,
                                            onSelectTarget: (id) {
                                              final tauntingEnemy = widget.tickManager.enemies.where((u) => u.isAlive && u.isTaunting).firstOrNull;
                                              if (tauntingEnemy != null && tauntingEnemy.id != id) {
                                                _addPop('TAUNTED by ${tauntingEnemy.name}!', const Color(0xFFFF5252), isCrit: true);
                                                setState(() => _selectedEnemyId = tauntingEnemy.id);
                                              } else {
                                                setState(() => _selectedEnemyId = id);
                                              }
                                            },
                                          ),

                                          // Center Clash Line: The Ashen Front
                                          _buildClashLine(isCompact: isCompact, isUltraCompact: isUltraCompact),

                                          // Allied Formation (Vanguard frontline top -> Arcanum backline bottom)
                                          _buildSquadFormation(
                                            units: widget.tickManager.allies,
                                            isEnemy: false,
                                            activeUnitId: activeUnit?.id,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildCombatLogBanner(),
                    _buildBottomControlBar(isPlayerTurn, selectedEnemy, activeUnit),
                  ],
                ),
              ),
            // Floating Combat Text Overlay
            Positioned(
              top: 70,
              right: 24,
              child: IgnorePointer(
                child: Column(
                  children: _floatingPops.map((pop) {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: pop.color.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          pop.text,
                          style: TextStyle(
                            color: pop.color,
                            fontWeight: FontWeight.bold,
                            fontSize: pop.isCrit ? 14 : 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Commander Focus Order Cut-In Banner
            if (_activeOrderBanner != null)
              Positioned(
                top: 75,
                left: 16,
                right: 16,
                child: _buildGeneralOrderBanner(_activeOrderBanner!),
              ),
            // Brave Exvius Tactical Limit Burst Banner
            if (_activeLimitBurstBanner != null)
              Positioned(
                top: 75,
                left: 16,
                right: 16,
                child: _buildLimitBurstBanner(_activeLimitBurstBanner!),
              ),
            // Tactical Chrono-Dilation Bullet-Time Overlay
            if (widget.tickManager.isBulletTime || widget.commandService.isBulletTimeActive) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                        width: 3.0,
                      ),
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF00E5FF).withValues(alpha: 0.08),
                        ],
                        radius: 0.9,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00272B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_bottom, size: 13, color: Color(0xFF00E5FF)),
                        SizedBox(width: 6),
                        Text(
                          '⏳ BULLET-TIME ACTIVE • 30% SPEED',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Full-screen Attack / Crit Strike / Order VFX Overlay
            if (_screenFlashType != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: (_screenFlashColorOverride ??
                              (_screenFlashType == 'crit'
                                  ? const Color(0xFFFFD54F)
                                  : const Color(0xFFB3261E)))
                          .withValues(alpha: 0.20),
                      border: Border.all(
                        color: _screenFlashColorOverride ??
                            (_screenFlashType == 'crit'
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFFB3261E)),
                        width: 2.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _screenFlashType == 'order'
                            ? (_activeOrderBanner?.icon ?? Icons.flash_on)
                            : (_screenFlashType == 'crit' ? Icons.flash_on : Icons.colorize),
                        size: 64,
                        color: (_screenFlashColorOverride ??
                                (_screenFlashType == 'crit'
                                    ? const Color(0xFFFFD54F)
                                    : const Color(0xFFEF5350)))
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildGeneralOrderBanner(GeneralOrderBannerData banner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: banner.themeColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: banner.themeColor.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: banner.themeColor.withValues(alpha: 0.2),
              border: Border.all(color: banner.themeColor, width: 1.5),
            ),
            child: Icon(banner.icon, color: banner.themeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'COMMANDER ORDER: ${banner.orderName}',
                      style: TextStyle(
                        color: banner.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5A93C), width: 1),
                      ),
                      child: Text(
                        '${banner.focusCost} FOCUS',
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  banner.summary,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitBurstBanner(LimitBurstBannerData banner) {
    final caster = banner.caster;
    final skill = banner.skill;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD54F), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFB3261E).withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
            ),
            child: const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'LIMIT BURST AWAKENING',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5A93C), width: 1),
                      ),
                      child: Text(
                        'GEN ${caster.generation} • LV. ${caster.level}',
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${caster.name.toUpperCase()} : ${skill.name.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${skill.damageCoefficient}x DMG)',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Cataclysmic strike unleashed upon ${banner.targetName}!',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP STATUS BAR & INITIATIVE GUIDANCE
  // ===========================================================================

  Widget _buildTopStatusBar(UnitEntity? activeUnit, bool isPlayerTurn) {
    final profile = widget.commandService.currentProfile;
    final modifier = widget.combatService.battleModifier;
    final boons = widget.combatService.activeBoons;
    final bool hasModifierOrBoons = modifier != BattleModifier.none || boons.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16161F),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main 1-Line Status Bar: Commander (Left) | Turn & Phase Pill (Center) | Controls (Right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Row(
              children: [
                // Commander Profile Pill
                GestureDetector(
                  onTap: _showGeneralSelectionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: profile.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: profile.themeColor.withValues(alpha: 0.6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(profile.icon, color: profile.themeColor, size: 16),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  profile.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 14),
                              ],
                            ),
                            Text(
                              profile.title,
                              style: TextStyle(color: profile.themeColor, fontSize: 7.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // 1-Tap MVP 3-Wave Skirmish Launcher (GDD v2.8 MVP Spec)
                GestureDetector(
                  onTap: _deployMvpSkirmish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.military_tech, color: Color(0xFFFFD54F), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'MVP SKIRMISH',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 9.0,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Center: Dynamic Turn & Phase Guidance Pill
                Expanded(
                  child: _buildTurnStatusPill(activeUnit, isPlayerTurn),
                ),

                const SizedBox(width: 8),

                // Right: Speed Toggle, Wheel Info, Auto Mode & Tick Indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed Multiplier Toggle
                    GestureDetector(
                      onTap: () {
                        final current = widget.tickManager.speedMultiplier;
                        final next = current == 1.0 ? 2.0 : (current == 2.0 ? 3.0 : 1.0);
                        widget.tickManager.setSpeedMultiplier(next);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.tickManager.speedMultiplier > 1.0
                              ? const Color(0xFFE5A93C).withValues(alpha: 0.25)
                              : const Color(0xFF2B2B36),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: widget.tickManager.speedMultiplier > 1.0
                                ? const Color(0xFFE5A93C)
                                : const Color(0xFF424250),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${widget.tickManager.speedMultiplier.toInt()}X',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: widget.tickManager.speedMultiplier > 1.0
                                ? const Color(0xFFE5A93C)
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Affinity Wheel Modal Trigger
                    GestureDetector(
                      onTap: () => _showHexWheelDialog(activeUnit?.archetype),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2B36),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF424250), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hexagon_outlined, size: 11, color: Color(0xFFD4AF37)),
                            SizedBox(width: 2),
                            Text(
                              'WHEEL',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _autoBattle = !_autoBattle;
                          if (_autoBattle && _isPlayerTurnNow) {
                            _handleAutoPlayerTurn();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: _autoBattle ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _autoBattle ? const Color(0xFFFF5252) : const Color(0xFF424250),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _autoBattle ? Icons.play_arrow : Icons.pause,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _autoBattle ? 'AUTO' : 'MANUAL',
                              style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F2A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF38384A), width: 1),
                      ),
                      child: Text(
                        'TICK ${widget.tickManager.tickCount}',
                        style: const TextStyle(
                          color: Color(0xFF9E9EB0),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 9.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Streamlined Ribbon: Active World Modifier & Lineage Covenants
          if (hasModifierOrBoons)
            _buildCompactModifierAndCovenantsBar(modifier, boons),
        ],
      ),
    );
  }

  Widget _buildTurnStatusPill(UnitEntity? activeUnit, bool isPlayerTurn) {
    if (widget.tickManager.phase == CombatPhase.battleEnded) {
      final alliesWon = widget.tickManager.enemies.every((u) => !u.isAlive);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: alliesWon ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: alliesWon ? const Color(0xFF81C784) : const Color(0xFFFF5252),
            width: 1.2,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    alliesWon ? Icons.military_tech : Icons.dangerous,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    alliesWon ? 'VICTORY!' : 'DEFEAT!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (widget.onResetEncounter != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onResetEncounter,
                  child: const Text(
                    'REPLAY',
                    style: TextStyle(
                      color: Colors.yellowAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isPlayerTurn && activeUnit != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFB3261E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 14),
              const SizedBox(width: 5),
              Text(
                'YOUR TURN: ${activeUnit.name.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiService.isEnemyTurn && activeUnit != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2224),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.7), width: 1.0),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF5350)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ENEMY TURN: ${activeUnit.name}',
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  _isProcessingAiTurn = false;
                  _handleAiTurn();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'RESOLVE',
                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pre-Battle Setup phase
    if (_isPreBattleSetup) {
      return GestureDetector(
        onTap: _commenceBattle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF81C784), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF81C784).withValues(alpha: 0.35),
                blurRadius: 6,
              ),
            ],
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 13, color: Color(0xFFFFD54F)),
                SizedBox(width: 5),
                Text(
                  'PRE-BATTLE: TAP UNITS TO ASSIGN LANE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Idle / Ticking phase
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C24),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333344), width: 1),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 12, color: Color(0xFF8E8EA0)),
            SizedBox(width: 5),
            Text(
              'CYCLING INITIATIVE...',
              style: TextStyle(
                color: Color(0xFF8E8EA0),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactModifierAndCovenantsBar(BattleModifier modifier, Iterable<ExpeditionBoon> boons) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFF101016),
        border: Border(top: BorderSide(color: Color(0xFF22222E), width: 1.0)),
      ),
      child: Row(
        children: [
          if (modifier != BattleModifier.none) ...[
            const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFFFB74D)),
            const SizedBox(width: 4),
            Text(
              'MODIFIER: ${_modifierTitle(modifier)}',
              style: const TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (boons.isNotEmpty) ...[
            const Icon(Icons.auto_awesome, size: 11, color: Color(0xFFFF7043)),
            const SizedBox(width: 4),
            const Text(
              'COVENANTS: ',
              style: TextStyle(
                color: Color(0xFFFF7043),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: boons.map((b) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: b.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: b.color.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(b.icon, color: b.color, size: 9),
                        const SizedBox(width: 2),
                        Text(
                          b.displayName,
                          style: TextStyle(color: b.color, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _modifierTitle(BattleModifier m) {
    switch (m) {
      case BattleModifier.titanicFury: return 'TITANIC FURY';
      case BattleModifier.bloodMoon: return 'BLOOD MOON';
      case BattleModifier.corrosiveMiasma: return 'CORROSIVE MIASMA';
      case BattleModifier.voidCorruption: return 'VOID CORRUPTION';
      case BattleModifier.abyssalEclipse: return 'ABYSSAL ECLIPSE';
      case BattleModifier.none: return '';
    }
  }

  // ===========================================================================
  // 2-TIER SPATIAL DEPTH FORMATION & ASHEN FRONT CLASH LINE
  // ===========================================================================

  Widget _buildSquadFormation({
    required List<UnitEntity> units,
    required bool isEnemy,
    required String? activeUnitId,
    String? selectedTargetId,
    ValueChanged<String>? onSelectTarget,
  }) {
    // If enemy squad contains a Boss, deploy the grand centered Boss Throne Stage
    final bool hasBoss = units.any((u) => u.isBoss);
    if (isEnemy && hasBoss) {
      return _buildBossEncounterFormation(
        units: units,
        activeUnitId: activeUnitId,
        selectedTargetId: selectedTargetId,
        onSelectTarget: onSelectTarget,
      );
    }

    if (units.isEmpty) {
      return const Expanded(child: SizedBox.shrink());
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isDesktop = screenWidth >= 1000;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1000;
    final bool isCompact = screenHeight < 760;
    final bool isUltraCompact = screenHeight < 620;

    // Responsive squad cluster width tailored for commanding mobile presence & desktop wargaming scale
    final double perUnitWidth = isDesktop ? 220.0 : (isTablet ? 170.0 : 96.0);
    final double maxClusterWidth = (units.length * perUnitWidth).clamp(280.0, isDesktop ? 1220.0 : (isTablet ? 740.0 : screenWidth));
    final double cardMaxWidth = isDesktop ? 230.0 : (isTablet ? 180.0 : 105.0);
    final double horizontalPadding = isDesktop ? 4.0 : (isTablet ? 2.5 : 1.0);

    // GDD v2.8 Sec 3.4 & 3.5: Leadership Aura checks for Lord Vladislav
    final commander = widget.tickManager.allies.where((u) => u.isCommander).firstOrNull;
    final bool isVladCommander = widget.commandService.activeGeneralType == GeneralType.vladislav;
    final bool vladVanguardAura = !isEnemy && isVladCommander && (commander != null && commander.isVanguard && commander.isAlive);
    final bool vladArcanumAura = !isEnemy && isVladCommander && (commander != null && commander.isArcanum && commander.isAlive);

    final int vanguardCount = units.where((u) => u.isVanguard).length;
    final int arcanumCount = units.where((u) => u.isArcanum).length;

    final String rankTitle = isEnemy
        ? (isCompact ? '⚔️ HOSTILE SQUAD ($vanguardCount FRONT • $arcanumCount REAR)' : '⚔️ HOSTILE REGIMENT: $vanguardCount FRONTLINE • $arcanumCount BACKLINE')
        : (vladVanguardAura
            ? (isCompact ? '🛡️ ALLIED FRONT • 🩸 VAMPIRIC' : '🛡️ ALLIED REGIMENT: VAMPIRIC CONDUIT (+15% LIFESTEAL) • $vanguardCount FRONT • $arcanumCount REAR')
            : (vladArcanumAura
                ? (isCompact ? '🏹 ALLIED REAR • 🩸 CONDUIT' : '🏹 ALLIED REGIMENT: VAMPIRIC CONDUIT (-1 FOCUS BLEED) • $vanguardCount FRONT • $arcanumCount REAR')
                : (isCompact ? '🛡️ ALLIED SQUAD ($vanguardCount FRONT • $arcanumCount REAR)' : '🛡️ ALLIED REGIMENT: $vanguardCount FRONTLINE • $arcanumCount BACKLINE')));

    final Color rankColor = isEnemy ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F);

    return Expanded(
      flex: 14,
      child: Column(
        children: [
          // Tactical Regiment Header (Shown during Pre-Battle setup or when an active general aura is active)
          if (!isUltraCompact && (_isPreBattleSetup || vladVanguardAura || vladArcanumAura))
            Container(
              margin: EdgeInsets.only(
                top: isEnemy ? 0.0 : (isCompact ? 1.0 : 2.0),
                bottom: isEnemy ? (isCompact ? 1.0 : 2.0) : 0.0,
              ),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: isCompact ? 1.0 : 2.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: rankColor.withValues(alpha: 0.45), width: 0.8),
              ),
              child: Text(
                rankTitle,
                style: TextStyle(
                  color: rankColor,
                  fontSize: isCompact ? 6.5 : 7.2,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Unified Staggered Squad Row: All units rendered in their formation slot columns
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxClusterWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: units.map((unit) {
                    final bool isFrontline = unit.isVanguard;
                    // Stagger Depth: Frontline steps forward towards Ashen Front (-Y for Allies, +Y for Enemy)
                    // Backline steps back away from Ashen Front (+Y for Allies, -Y for Enemy)
                    final double depthY = isFrontline
                        ? (isEnemy ? (isCompact ? 10.0 : 14.0) : (isCompact ? -10.0 : -14.0))
                        : (isEnemy ? (isCompact ? -6.0 : -10.0) : (isCompact ? 6.0 : 10.0));
                    // Consistent scale: Units maintain 100% equal size regardless of lane assignment
                    const double tierScale = 1.0;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 1.0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxWidth),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              transform: Matrix4.translationValues(0.0, depthY, 0.0),
                              child: Transform.scale(
                                scale: tierScale,
                                alignment: Alignment.bottomCenter,
                                child: _buildUnitCard(
                                  unit: unit,
                                  isEnemy: isEnemy,
                                  isActive: unit.id == activeUnitId,
                                  isSelectedTarget: unit.id == selectedTargetId,
                                  onTap: () => onSelectTarget?.call(unit.id),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grand Boss Battlefield Stage: Colossal Boss centered with minions/henchmen flanking
  Widget _buildBossEncounterFormation({
    required List<UnitEntity> units,
    required String? activeUnitId,
    String? selectedTargetId,
    ValueChanged<String>? onSelectTarget,
  }) {
    final boss = units.firstWhere((u) => u.isBoss);
    final minions = units.where((u) => !u.isBoss).toList();

    List<UnitEntity> leftMinions = [];
    List<UnitEntity> rightMinions = [];

    if (minions.length == 1) {
      leftMinions = [minions[0]];
    } else if (minions.length > 1) {
      final int half = (minions.length / 2).ceil();
      leftMinions = minions.take(half).toList();
      rightMinions = minions.skip(half).toList();
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1000;

    final double stageMaxWidth = isDesktop ? 1220.0 : (isTablet ? 900.0 : 720.0);
    final double bossMaxWidth = isDesktop ? 540.0 : (isTablet ? 440.0 : 360.0);
    final double minionMaxWidth = isDesktop ? 280.0 : (isTablet ? 230.0 : 180.0);

    return Expanded(
      flex: 12,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: stageMaxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Minions / Henchmen
                ...leftMinions.map((unit) => _buildMinionSlot(
                      unit: unit,
                      activeUnitId: activeUnitId,
                      selectedTargetId: selectedTargetId,
                      onSelectTarget: onSelectTarget,
                      maxWidth: minionMaxWidth,
                    )),

                // Symmetrical spacer when there are no minions
                if (minions.isEmpty)
                  const Expanded(flex: 2, child: SizedBox.shrink()),

                // Centered Dominant Boss Slot (prominent flex & wide constraints)
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: bossMaxWidth),
                        child: _buildUnitCard(
                          unit: boss,
                          isEnemy: true,
                          isActive: boss.id == activeUnitId,
                          isSelectedTarget: boss.id == selectedTargetId,
                          onTap: () => onSelectTarget?.call(boss.id),
                          isBossCenterpiece: true,
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Minions / Henchmen
                ...rightMinions.map((unit) => _buildMinionSlot(
                      unit: unit,
                      activeUnitId: activeUnitId,
                      selectedTargetId: selectedTargetId,
                      onSelectTarget: onSelectTarget,
                      maxWidth: minionMaxWidth,
                    )),

                // Symmetrical spacer when there is 1 minion (on the right) or no minions
                if (minions.length == 1 || minions.isEmpty)
                  const Expanded(flex: 2, child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinionSlot({
    required UnitEntity unit,
    required String? activeUnitId,
    String? selectedTargetId,
    ValueChanged<String>? onSelectTarget,
    double maxWidth = 180.0,
  }) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _buildUnitCard(
              unit: unit,
              isEnemy: true,
              isActive: unit.id == activeUnitId,
              isSelectedTarget: unit.id == selectedTargetId,
              onTap: () => onSelectTarget?.call(unit.id),
            ),
          ),
        ),
      ),
    );
  }



  /// Calculates upcoming turn queue based on current Turn Meter and Speed ticks
  List<UnitEntity> _getUpcomingTurnQueue() {
    final livingUnits = widget.tickManager.allUnits.where((u) => u.isAlive).toList();
    if (livingUnits.isEmpty) return [];

    final active = widget.tickManager.activeUnit;
    livingUnits.sort((a, b) {
      if (a.id == active?.id) return -1;
      if (b.id == active?.id) return 1;

      // Estimate ticks remaining to reach 100% Turn Meter
      final double tmNeededA = (100.0 - a.turnMeter).clamp(0.0, 100.0);
      final double speedModA = a.hasHaste ? 1.35 : 1.0;
      final double deltaA = ((a.speed * speedModA) / 100.0) * InitiativeTickManager.tickScale;
      final double ticksA = deltaA > 0 ? (tmNeededA / deltaA) : 999.0;

      final double tmNeededB = (100.0 - b.turnMeter).clamp(0.0, 100.0);
      final double speedModB = b.hasHaste ? 1.35 : 1.0;
      final double deltaB = ((b.speed * speedModB) / 100.0) * InitiativeTickManager.tickScale;
      final double ticksB = deltaB > 0 ? (tmNeededB / deltaB) : 999.0;

      final int tickComp = ticksA.compareTo(ticksB);
      if (tickComp != 0) return tickComp;

      return b.speed.compareTo(a.speed);
    });

    return livingUnits.take(6).toList();
  }

  /// Vertical Initiative Ribbon along the left edge showing who acts next from top to bottom
  Widget _buildVerticalInitiativeTrack({bool isCompact = false, bool isMobile = false}) {
    final upcomingQueue = _getUpcomingTurnQueue();
    if (upcomingQueue.isEmpty) return const SizedBox.shrink();

    final active = widget.tickManager.activeUnit;
    final double avatarSize = isMobile ? 26.0 : (isCompact ? 28.0 : 34.0);
    final double activeAvatarSize = isMobile ? 30.0 : (isCompact ? 32.0 : 38.0);
    final int displayCount = isMobile ? 4 : 5;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 3 : 5,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E14).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.75),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header icon and label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_bottom, size: isMobile ? 9 : 11, color: const Color(0xFFFFD54F)),
              const SizedBox(width: 2),
              Text(
                'NEXT',
                style: TextStyle(
                  color: const Color(0xFFFFD54F),
                  fontSize: isMobile ? 7.0 : 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 3 : 4),
          Container(
            width: isMobile ? 24 : 32,
            height: 1,
            color: const Color(0xFF3E3E52),
          ),
          SizedBox(height: isMobile ? 3 : 5),

          // Stack of upcoming combatant tokens
          ...upcomingQueue.take(displayCount).toList().asMap().entries.map((entry) {
            final int index = entry.key;
            final UnitEntity u = entry.value;
            final bool isAlly = widget.tickManager.allies.any((a) => a.id == u.id);
            final bool isNow = index == 0 && active?.id == u.id;
            final Color sideColor = isAlly ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
            final Color borderCol = isNow ? const Color(0xFFFFD54F) : sideColor;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 2.0 : 3.0),
              child: Tooltip(
                message: '${u.name}\n${isAlly ? "ALLIED" : "HOSTILE"}\nSpeed: ${u.speed} • Turn Meter: ${u.turnMeter.toStringAsFixed(0)}%',
                child: GestureDetector(
                  onTap: () {
                    if (!isAlly && u.isAlive) {
                      setState(() => _selectedEnemyId = u.id);
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Unit Avatar Node
                      Container(
                        width: isNow ? activeAvatarSize : avatarSize,
                        height: isNow ? activeAvatarSize : avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderCol,
                            width: isNow ? 1.8 : 1.2,
                          ),
                          boxShadow: isNow
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.75),
                                    blurRadius: 6,
                                    spreadRadius: 1.0,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: sideColor.withValues(alpha: 0.35),
                                    blurRadius: 3,
                                  ),
                                ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                u.effectiveAvatarAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: isAlly ? const Color(0xFF1B3B22) : const Color(0xFF3B1B1B),
                                  child: Icon(
                                    isAlly ? Icons.shield : Icons.dangerous_outlined,
                                    size: 16,
                                    color: borderCol,
                                  ),
                                ),
                              ),
                              // Vignette gradient for clear contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.45),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Rank Badge (1, 2, 3...) or ACT label
                      Positioned(
                        bottom: -3,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isNow ? 4.0 : 3.0, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: isNow ? const Color(0xFFFFD54F) : const Color(0xFF14141B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: borderCol,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            isNow ? 'ACT' : '#${index + 1}',
                            style: TextStyle(
                              color: isNow ? Colors.black : Colors.white70,
                              fontSize: isNow ? 6.5 : 6.0,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),

                      // Target indicator icon if this enemy is currently targeted
                      if (!isAlly && u.id == _selectedEnemyId)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFF5252),
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClashLine({bool isCompact = false, bool isUltraCompact = false}) {
    if (isUltraCompact) {
      return Container(
        height: 10,
        margin: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: const Color(0xFF5D4037))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '• ASHEN FRONT •',
                style: TextStyle(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                  fontSize: 7.0,
                  letterSpacing: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFF5D4037))),
          ],
        ),
      );
    }
    return Container(
      height: isCompact ? 16 : 28,
      margin: EdgeInsets.symmetric(vertical: isCompact ? 2 : 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xFF5D4037), Color(0xFFD4AF37)],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: isCompact ? 2 : 4),
            decoration: BoxDecoration(
              color: const Color(0xFF14141B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  blurRadius: isCompact ? 4 : 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: isCompact ? 9 : 11, color: const Color(0xFFD4AF37)),
                SizedBox(width: isCompact ? 4 : 6),
                Text(
                  'THE ASHEN FRONT',
                  style: TextStyle(
                    color: const Color(0xFFD4AF37),
                    fontSize: isCompact ? 7.5 : 8.5,
                    letterSpacing: isCompact ? 1.0 : 2.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(width: isCompact ? 4 : 6),
                Icon(Icons.shield_outlined, size: isCompact ? 9 : 11, color: const Color(0xFFD4AF37)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFF5D4037), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetStrikeVfx(String vfxType, bool isBossUnit) {
    switch (vfxType) {
      case 'crit':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isBossUnit ? 180 : 130,
                height: isBossUnit ? 180 : 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD54F).withValues(alpha: 0.65),
                      const Color(0xFFFF1744).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: isBossUnit ? 190 : 135,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Color(0xFFFF8A80), Colors.white, Color(0xFFFFD54F), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.95),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: 0.45,
                child: Container(
                  width: isBossUnit ? 175 : 125,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Colors.white, Color(0xFFFF1744), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.9),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.flash_on, size: 36, color: Color(0xFFFFF9C4)),
            ],
          ),
        );
      case 'boss':
      case 'crush':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isBossUnit ? 190 : 130,
                height: isBossUnit ? 60 : 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFFF5252), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.7),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: 0.05,
                child: Container(
                  width: 7,
                  height: isBossUnit ? 180 : 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white, Color(0xFFFF1744), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.9),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.shield, size: 32, color: Color(0xFFFFD54F)),
            ],
          ),
        );
      case 'pierce':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.15,
                child: Container(
                  width: isBossUnit ? 210 : 145,
                  height: 4.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Color(0xFF80D8FF), Colors.white, Color(0xFF00E5FF), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: -0.15,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 18, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(9))),
                    const SizedBox(width: 14),
                    Container(width: 12, height: 26, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00E5FF), width: 1.8), borderRadius: BorderRadius.circular(13))),
                    const SizedBox(width: 14),
                    Container(width: 16, height: 34, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF80D8FF), width: 2.0), borderRadius: BorderRadius.circular(17))),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'magic':
      case 'sunfire':
      case 'sunburst':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/Spells/Sunburst - Tier 1 Spell no text.png',
                width: isBossUnit ? 190 : 130,
                height: isBossUnit ? 190 : 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.auto_fix_high, size: 38, color: Color(0xFFFFD54F)),
              ),
              Container(
                width: isBossUnit ? 140 : 90,
                height: isBossUnit ? 140 : 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'vampiric':
      case 'bleed':
      case 'vitae':
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/Spells/Vitae Erution - Tier 1 no txt.png',
                width: isBossUnit ? 190 : 130,
                height: isBossUnit ? 190 : 130,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.bloodtype, size: 38, color: Color(0xFFFF1744)),
              ),
              Container(
                width: isBossUnit ? 140 : 90,
                height: isBossUnit ? 140 : 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.7),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'slash':
      default:
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.42,
                child: Container(
                  width: isBossUnit ? 160 : 115,
                  height: 4.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Colors.white, Color(0xFFFF1744), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.85),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.rotate(
                angle: 0.42,
                child: Container(
                  width: isBossUnit ? 150 : 105,
                  height: 3.8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, Colors.white, Color(0xFFFFD54F), Colors.transparent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.colorize, size: 22, color: Color(0xFFFFEB3B)),
            ],
          ),
        );
    }
  }

  Widget _buildAssassinBackstabApparition(UnitEntity assassin, bool isTargetEnemy) {
    return Positioned(
      top: isTargetEnemy ? -36 : null,
      bottom: isTargetEnemy ? null : -36,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.scale(
          scale: 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFFE040FB), width: 1.0),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFE040FB), blurRadius: 8),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on, size: 8, color: Color(0xFFE040FB)),
                    SizedBox(width: 2),
                    Text(
                      'SHADOWSTEP BACKSTAB',
                      style: TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7B1FA2).withValues(alpha: 0.8),
                            blurRadius: 14,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      assassin.effectiveAvatarAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 38,
                        color: Color(0xFFE040FB),
                      ),
                    ),
                    Transform.rotate(
                      angle: 0.45,
                      child: Container(
                        width: 50,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Color(0xFFFF1744), Colors.white, Colors.transparent],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFFF1744), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: -0.45,
                      child: Container(
                        width: 50,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Color(0xFFFF1744), Colors.white, Colors.transparent],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFFF1744), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShadowstepSmokePuff() {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B1FA2).withValues(alpha: 0.7),
                    const Color(0xFF4A148C).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.cloud, size: 28, color: Color(0xFFE1BEE7)),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFFE040FB), width: 0.7),
              ),
              child: const Text(
                '🌀 SHADOWSTEP',
                style: TextStyle(color: Color(0xFFE040FB), fontSize: 6.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncantingRuneSigil() {
    return Positioned(
      top: -24,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
              ),
              child: const Text(
                '✨ INCANTING',
                style: TextStyle(color: Color(0xFFFFD54F), fontSize: 6.5, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.auto_fix_high, size: 14, color: Color(0xFFFFD54F)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksmanAimFlare() {
    return Positioned(
      top: 10,
      right: 8,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white,
              const Color(0xFF00E5FF).withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: const Icon(Icons.flash_on, size: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildMarksmanTargetReticle() {
    return Positioned.fill(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.4),
              ),
            ),
            const Icon(Icons.gps_fixed, size: 26, color: Color(0xFF00E5FF)),
            Transform.rotate(
              angle: -0.6,
              child: Container(
                width: 85,
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFF80D8FF), Colors.white, Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getUnitModelScale(UnitEntity unit, bool isBossUnit, bool isDesktop, {bool isCompact = false}) {
    if (isBossUnit) {
      return isDesktop ? 2.50 : (isCompact ? 1.95 : 2.25);
    }
    if (!unit.isFigurineCutout) {
      return 1.15;
    }

    // Command presence: miniatures scale prominently to command battlefield space
    final double baseScale = isDesktop ? 1.95 : (isCompact ? 1.65 : 1.82);

    // Tabletop Miniature Equalization:
    // Standing humanoid poses (Footman, Marksman, Cleric): ~627px height -> scale 1.0
    // Vlad: tall standing upright with raised sword and cape -> scale 0.76 to match infantry eye level
    // Ghoul / crouched quadruped beasts: ~704px height in raw asset -> scale 1.05 to match infantry visual presence
    double poseCompensation = 1.0;
    final asset = unit.effectiveAvatarAsset.toLowerCase();
    final species = unit.speciesId.toLowerCase();
    final name = unit.name.toLowerCase();

    if (asset.contains('vladislav') || species.contains('vladislav') || name.contains('vladislav')) {
      poseCompensation = 0.76;
    } else if (asset.contains('ghoul') || species.contains('ghoul') || name.contains('ghoul') ||
               asset.contains('flayer') || asset.contains('warhound')) {
      poseCompensation = 1.05;
    }

    return baseScale * poseCompensation;
  }

  Widget _buildUnitCard({
    required UnitEntity unit,
    required bool isEnemy,
    required bool isActive,
    required bool isSelectedTarget,
    VoidCallback? onTap,
    bool isBossCenterpiece = false,
  }) {
    final bool alive = unit.isAlive;
    final bool isBossUnit = unit.isBoss || isBossCenterpiece;
    final double hpRatio = (unit.currentHp / unit.maxHp).clamp(0.0, 1.0);
    final double tmRatio = (unit.turnMeter / 100.0).clamp(0.0, 1.0);
    final bool ultReady = unit.ultimateCharge >= 100.0 && alive;

    final activeUnit = widget.tickManager.activeUnit;
    double? affinityMult;
    if (isEnemy && alive && _isPlayerTurnNow && activeUnit != null) {
      affinityMult = CombatMath.getAffinityMultiplier(activeUnit.archetype, unit.archetype);
    }

    final attackerUnit = _attackingUnitId != null
        ? (widget.tickManager.allies.where((u) => u.id == _attackingUnitId).firstOrNull ??
           widget.tickManager.enemies.where((u) => u.id == _attackingUnitId).firstOrNull)
        : null;

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id;
    final bool isAttackerAssassin = attackerUnit?.archetype == Archetype.assassin;
    final bool isAttackerMarksman = attackerUnit?.archetype == Archetype.marksman;
    final bool isAttackerOccultist = attackerUnit?.archetype == Archetype.occultist;

    double lungeY = 0.0;
    double attackTilt = 0.0;
    double attackScale = 1.0;
    double unitOpacity = 1.0;

    if (isAttacking) {
      if (unit.archetype == Archetype.assassin) {
        // Assassin Shadowstep: vanishes from original position into shadow smoke
        unitOpacity = 0.0;
      } else if (unit.archetype == Archetype.marksman) {
        // Marksman: small deliberate step forward into kneeling/sniper stance
        lungeY = isEnemy ? 14.0 : -14.0;
        attackTilt = isEnemy ? 0.03 : -0.03;
        attackScale = 1.04;
      } else if (unit.archetype == Archetype.occultist) {
        // Occultist / Spellcaster: steps forward towards clash line to incant
        lungeY = isEnemy ? 26.0 : -26.0;
        attackScale = 1.06;
      } else {
        // Melee / Juggernaut / Skirmisher / Boss / Commander:
        // Physical tactile charge deep across the neutral ground toward opposing rank!
        lungeY = isEnemy ? 120.0 : -120.0;
        attackTilt = isEnemy ? 0.10 : -0.10;
        attackScale = 1.15;
      }
    }

    final double shakeX = isDamaged ? (isEnemy ? -12.0 : 12.0) : 0.0;
    final double hitRecoilY = isDamaged ? (isEnemy ? -14.0 : 14.0) : 0.0;
    final bool isCriticalHp = hpRatio < 0.25 && alive;

    final int allyIndex = isEnemy ? -1 : widget.tickManager.allies.indexWhere((u) => u.id == unit.id);
    final bool isSelectedForSwap = _isPreBattleSetup && !isEnemy && _selectedSwapUnitId == unit.id;

    Color borderColor = const Color(0xFF2B2B36);
    double borderWidth = 1.0;
    List<BoxShadow>? shadows;

    if (isSelectedForSwap) {
      borderColor = const Color(0xFFFFD54F);
      borderWidth = 2.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
          blurRadius: 14,
          spreadRadius: 2.5,
        ),
      ];
    } else if (isDamaged) {
      borderColor = const Color(0xFFFF1744);
      borderWidth = 2.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFF1744).withValues(alpha: 0.7),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];
    } else if (isAttacking) {
      borderColor = const Color(0xFFFFD54F);
      borderWidth = 2.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ];
    } else if (isActive) {
      borderColor = const Color(0xFFFFD54F);
      borderWidth = 2.5;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (isSelectedTarget) {
      borderColor = const Color(0xFFFF1744);
      borderWidth = isBossUnit ? 3.0 : 2.2;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFF1744).withValues(alpha: 0.65),
          blurRadius: isBossUnit ? 16 : 8,
          spreadRadius: isBossUnit ? 2.5 : 1.5,
        ),
      ];
    } else if (ultReady) {
      borderColor = const Color(0xFFFFD54F);
      borderWidth = 2.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else if (isBossUnit && alive) {
      borderColor = const Color(0xFFFF5252);
      borderWidth = 2.8;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFF1744).withValues(alpha: 0.75),
          blurRadius: 20,
          spreadRadius: 3.5,
        ),
        BoxShadow(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
          blurRadius: 12,
          spreadRadius: 1.5,
        ),
      ];
    } else if (isCriticalHp) {
      borderColor = const Color(0xFFD50000);
      borderWidth = 1.8;
      shadows = [
        BoxShadow(
          color: const Color(0xFFD50000).withValues(alpha: 0.4),
          blurRadius: 6,
          spreadRadius: 1,
        ),
      ];
    }

    // Organic miniature outline glow around the model silhouette (only for figurines when alive)
    final bool hasModelGlow = alive &&
        unit.isFigurineCutout &&
        (isSelectedForSwap || isSelectedTarget || isDamaged || isActive || isBossUnit);
    Color modelGlowColor = Colors.transparent;
    double modelGlowAlpha = 0.0;
    double modelGlowBlur = 6.0;

    if (isSelectedForSwap) {
      modelGlowColor = const Color(0xFFFFD54F);
      modelGlowAlpha = 0.95;
      modelGlowBlur = 8.0;
    } else if (isDamaged) {
      modelGlowColor = const Color(0xFFFF1744);
      modelGlowAlpha = 0.95;
      modelGlowBlur = 8.0;
    } else if (isSelectedTarget) {
      modelGlowColor = const Color(0xFFFF1744);
      modelGlowAlpha = 0.85;
      modelGlowBlur = 6.5;
    } else if (isActive) {
      modelGlowColor = const Color(0xFFFFD54F);
      modelGlowAlpha = 0.80;
      modelGlowBlur = 6.0;
    } else if (isBossUnit) {
      modelGlowColor = const Color(0xFFFF5252);
      modelGlowAlpha = 0.60;
      modelGlowBlur = 7.5;
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isDesktop = screenWidth >= 1000;
    final bool isCompact = screenHeight < 760;
    final bool isUltraCompact = screenHeight < 620;
    final double miniatureScale = _getUnitModelScale(unit, isBossUnit, isDesktop, isCompact: isCompact);

    // Dynamic HUD height tailored to screen size & pre-battle setup mode
    final double hudHeight = isBossUnit
        ? (isUltraCompact ? 24.0 : (isCompact ? 28.0 : 34.0))
        : (_isPreBattleSetup
            ? (isUltraCompact ? 26.0 : (isCompact ? 32.0 : 42.0))
            : (isUltraCompact ? 18.0 : (isCompact ? 22.0 : 26.0)));

    final Widget cardWidget = GestureDetector(
      key: Key('unit_card_${unit.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isPreBattleSetup && !isEnemy && alive) {
          if (_selectedSwapUnitId == null) {
            setState(() {
              _selectedSwapUnitId = unit.id;
              _combatLog = 'Selected ${unit.name} (Col ${allyIndex + 1}). Tap another unit to swap, or use ◀ / ▶.';
            });
          } else if (_selectedSwapUnitId == unit.id) {
            setState(() => _selectedSwapUnitId = null);
          } else {
            final indexA = widget.tickManager.allies.indexWhere((u) => u.id == _selectedSwapUnitId);
            final indexB = allyIndex;
            _swapAlliedUnits(indexA, indexB);
          }
          return;
        }
        if (isEnemy && alive) {
          if (isSelectedTarget) {
            _openInspectorModal(unit, isEnemy);
          } else {
            onTap?.call();
          }
        } else {
          _openInspectorModal(unit, isEnemy);
        }
      },
      onDoubleTap: () {
        _openInspectorModal(unit, isEnemy);
      },
      onLongPress: () {
        _openInspectorModal(unit, isEnemy);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: unitOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: isAttacking ? Curves.easeOutBack : Curves.easeInOutCubic,
          transform: Matrix4.identity()
            ..translate(shakeX, lungeY + hitRecoilY)
            ..rotateZ(attackTilt)
            ..scale(attackScale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: unit.isFigurineCutout ? Colors.transparent : (alive ? const Color(0xFF14141A) : const Color(0xFF0E0E12)),
            borderRadius: BorderRadius.circular(6),
            border: unit.isFigurineCutout
                ? Border.all(color: Colors.transparent, width: 0)
                : Border.all(color: borderColor, width: borderWidth),
            boxShadow: unit.isFigurineCutout ? null : shadows,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // LAYER 0: Dark Gothic Stone Base (for classic cards only)
              if (!unit.isFigurineCutout)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF161622), Color(0xFF09090D)],
                        ),
                      ),
                    ),
                  ),
                ),

              // LAYER 1: Open Character Miniature & 3D Faction Ground Plinth
              Positioned(
                top: isBossUnit ? (isCompact ? -6 : -14) : (unit.isFigurineCutout ? (isCompact ? -2 : -4) : 0),
                bottom: hudHeight + 2.0,
                left: 1,
                right: 1,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // LAYER 1A: 3D Tabletop Ground Contact Shadow (Soft gradient grounded beneath base)
                    if (unit.isFigurineCutout)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: isBossUnit ? (isCompact ? 130.0 : 170.0) : (isCompact ? 76.0 : 96.0),
                            height: isBossUnit ? (isCompact ? 16.0 : 20.0) : (isCompact ? 10.0 : 14.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(Radius.elliptical(50, 10)),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.65),
                                    Colors.black.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // LAYER 1-GLOW: Organic Character Model Silhouette Glow (No rectangular boxes)
                    if (hasModelGlow)
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isBossUnit ? 4.0 : 2.0),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Transform.scale(
                              scale: miniatureScale,
                              alignment: Alignment.bottomCenter,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: modelGlowBlur,
                                  sigmaY: modelGlowBlur,
                                  tileMode: TileMode.decal,
                                ),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    modelGlowColor.withValues(alpha: modelGlowAlpha),
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    unit.effectiveAvatarAsset,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomCenter,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // LAYER 1B: Character Miniature Artwork (Painted ON TOP of plinth with prominent scale)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isBossUnit ? 4.0 : 2.0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.scale(
                            scale: miniatureScale,
                            alignment: Alignment.bottomCenter,
                            child: ColorFiltered(
                              colorFilter: isDamaged && alive
                                  ? const ColorFilter.mode(Color(0xFFFF1744), BlendMode.srcATop)
                                  : (alive
                                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                      : kAlphaSafeGreyscaleFilter),
                              child: Opacity(
                                opacity: alive ? unitOpacity : (unit.isFigurineCutout ? 0.45 : 0.65),
                                child: Image.asset(
                                  unit.effectiveAvatarAsset,
                                  fit: unit.isFigurineCutout ? BoxFit.contain : BoxFit.cover,
                                  alignment: unit.isFigurineCutout ? Alignment.bottomCenter : Alignment.topCenter,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B22)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Inner Silhouette Vignette & Depth Shadow (applied to classic card illustrations)
                    if (!unit.isFigurineCutout)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.65, 1.0],
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.82),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Critical HP Warning Vignette (only for classic cards)
                    if (isCriticalHp && !unit.isFigurineCutout)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFB3261E).withValues(alpha: 0.25),
                        ),
                      ),

                    // Death Darkening (only for classic cards)
                    if (!alive && !unit.isFigurineCutout)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),

              // LAYER 2: Carved Iron Gothic Frame Overlay (for classic card format)
              if (!unit.isFigurineCutout)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        'assets/images/card_frame.png',
                        fit: BoxFit.fill,
                        opacity: const AlwaysStoppedAnimation(0.75),
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // LAYER 2.5: High-Impact Directional Attack Strike VFX & Sparks
              if (isDamaged) ...[
                if (!unit.isFigurineCutout)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildTargetStrikeVfx(_screenFlashType ?? 'slash', isBossUnit),
                  ),
                ),
                // Assassin Blink Strike: Reappears directly adjacent to damaged target!
                if (isAttackerAssassin && attackerUnit != null)
                  _buildAssassinBackstabApparition(attackerUnit, isEnemy),
                // Marksman Piercing Scope Lock & Tracer Impact
                if (isAttackerMarksman)
                  _buildMarksmanTargetReticle(),
              ],

              // Archetype Specific Attacker Overlays
              if (isAttacking && alive) ...[
                // Assassin vanishing into shadow smoke at home base
                if (unit.archetype == Archetype.assassin)
                  _buildShadowstepSmokePuff(),
                // Occultist overhead arcane rune sigil
                if (unit.archetype == Archetype.occultist)
                  _buildIncantingRuneSigil(),
                // Marksman muzzle flash / lens flare
                if (unit.archetype == Archetype.marksman)
                  _buildMarksmanAimFlare(),
              ],

              // LAYER 2.8: Bottom Readability Gradient (only for classic cards)
              if (!unit.isFigurineCutout)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),

              // LAYER 3: Interactive UI Information anchored cleanly beneath Pedestal
              Positioned(
                left: 1,
                right: 1,
                bottom: 1,
                height: hudHeight,
                child: Opacity(
                  opacity: alive ? 1.0 : 0.25,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // GDD v2.6 Sec 13.5: Enemy Boss/Elite Action Intent Telegraphing
                      if (isEnemy && alive && unit.turnMeter >= 40.0 && !isUltraCompact) ...[
                        Builder(builder: (ctx) {
                          final intentSkill = _aiService.predictNextSkill(unit);
                          if (intentSkill == null) return const SizedBox.shrink();
                          final bool isLimitBurst = intentSkill.isLimitBurst;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 1.5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                              decoration: BoxDecoration(
                                color: isLimitBurst
                                    ? const Color(0xFFD50000).withValues(alpha: 0.90)
                                    : const Color(0xFF263238).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isLimitBurst ? const Color(0xFFFFD54F) : const Color(0xFFFF8A80),
                                  width: isLimitBurst ? 1.2 : 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLimitBurst ? Icons.warning_amber_rounded : Icons.gps_fixed,
                                    size: 7.5,
                                    color: isLimitBurst ? const Color(0xFFFFD54F) : const Color(0xFFFF8A80),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'INTENT: ${intentSkill.name.toUpperCase()}',
                                    style: TextStyle(
                                      color: isLimitBurst ? const Color(0xFFFFD54F) : Colors.white,
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],

                      // Status Effect Badges (if active, above the pedestal)
                      if (unit.activeEffects.isNotEmpty && alive && !isUltraCompact)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 1,
                            alignment: WrapAlignment.center,
                            children: unit.activeEffects.take(3).map((eff) {
                              final Color color = _statusColor(eff.type);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: color, width: 0.7),
                                ),
                                child: Text(
                                  _statusAbbr(eff.type),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Tabletop Miniature Inlaid Health Bar & AP Meter (for non-boss units)
                      if (!isBossUnit && alive)
                        Padding(
                          padding: EdgeInsets.only(bottom: isCompact ? 1.5 : 2.5),
                          child: _buildUnitStatusMeter(
                            unit: unit,
                            hpRatio: hpRatio,
                            tmRatio: tmRatio,
                            isDamaged: isDamaged,
                            isCompact: isCompact,
                          ),
                        ),

                      // PEDESTAL HUD ROW: Shield (Left) - Level (Center) - Rarity/Target/Boss (Right) - Sheet (Far Right)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPreBattleSetup) ...[
                                // Bottom-Left of Pedestal: Archetype Shield Badge (or ☠ BOSS badge for bosses)
                                if (isBossUnit)
                                  Builder(builder: (ctx) {
                                    final String phaseText = hpRatio > 0.66
                                        ? '☠ BOSS'
                                        : (hpRatio > 0.33 ? '⚡ BOSS (P2)' : '🔥 BOSS (P3)');
                                    final Color phaseColor = hpRatio > 0.66
                                        ? const Color(0xFFFFD54F)
                                        : (hpRatio > 0.33 ? const Color(0xFFFF9800) : const Color(0xFFFF1744));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB71C1C).withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: phaseColor, width: 1.4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: phaseColor.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.dangerous, size: 9, color: phaseColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            phaseText,
                                            style: TextStyle(
                                              color: phaseColor,
                                              fontSize: 8.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: _archetypeColor(unit.archetype), width: 1.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_archetypeIcon(unit.archetype), size: 8, color: _archetypeColor(unit.archetype)),
                                        const SizedBox(width: 2),
                                        Text(
                                          _archetypeShortCode(unit.archetype),
                                          style: TextStyle(
                                            color: _archetypeColor(unit.archetype),
                                            fontSize: 8.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(width: 4),

                                // Middle of Pedestal: Tactical Formation Role + Level Badge
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      key: Key('unit_lane_badge_${unit.id}'),
                                      onTap: !isEnemy && alive
                                          ? () => _toggleAlliedLane(unit.id)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.2),
                                        decoration: BoxDecoration(
                                          color: isBossUnit
                                              ? const Color(0xFF7F0000).withValues(alpha: 0.7)
                                              : (unit.isVanguard
                                                  ? const Color(0xFFE5A93C).withValues(alpha: 0.25)
                                                  : const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(
                                            color: isBossUnit
                                                ? const Color(0xFFFF5252)
                                                : (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)),
                                            width: !isEnemy ? 1.4 : 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isBossUnit ? '👑 TITANIC' : (unit.isVanguard ? '⚔ FRONT' : '🔮 REAR'),
                                              style: TextStyle(
                                                color: isBossUnit
                                                    ? const Color(0xFFFF8A80)
                                                    : (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)),
                                                fontSize: 7.0,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            if (!isEnemy) ...[
                                              const SizedBox(width: 2),
                                              const Icon(Icons.swap_vert, size: 8, color: Colors.white70),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                                      decoration: BoxDecoration(
                                        color: isBossUnit
                                            ? const Color(0xFFB71C1C).withValues(alpha: 0.75)
                                            : Colors.black.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: isBossUnit ? const Color(0xFFFF5252) : const Color(0xFFE5A93C),
                                          width: isBossUnit ? 1.2 : 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isBossUnit ? 'Lv.${unit.level} ★' : 'Lv.${unit.level}',
                                        style: TextStyle(
                                          color: isBossUnit ? const Color(0xFFFF8A80) : const Color(0xFFE5A93C),
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(width: 4),

                                // Bottom-Right of Pedestal: Target / Boss / Status / Gen Badge
                                if (isSelectedTarget)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: affinityMult != null && affinityMult > 1.0
                                          ? const Color(0xFF2E7D32)
                                          : (affinityMult != null && affinityMult < 1.0
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFFB3261E)),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: affinityMult != null && affinityMult > 1.0
                                            ? const Color(0xFF81C784)
                                            : (affinityMult != null && affinityMult < 1.0
                                                ? const Color(0xFFFF8A80)
                                                : const Color(0xFFFF5252)),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.gps_fixed, size: 8, color: Colors.white),
                                        const SizedBox(width: 2),
                                        Text(
                                          affinityMult != null && affinityMult > 1.0
                                              ? 'TARGET (▲+30%)'
                                              : (affinityMult != null && affinityMult < 1.0
                                                  ? 'TARGET (▼WEAK)'
                                                  : 'TARGET'),
                                          style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isBossUnit)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB71C1C).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.dangerous, size: 8, color: Color(0xFFFFD54F)),
                                        SizedBox(width: 2),
                                        Text(
                                          '☠ BOSS',
                                          style: TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5A93C),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flash_on, size: 8, color: Colors.black),
                                        SizedBox(width: 2),
                                        Text(
                                          'ACTING',
                                          style: TextStyle(color: Colors.black, fontSize: 7.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (ultReady)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD54F),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'ULT',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: affinityMult != null && affinityMult > 1.0
                                          ? const Color(0xFF1B5E20).withValues(alpha: 0.85)
                                          : (affinityMult != null && affinityMult < 1.0
                                              ? const Color(0xFFB71C1C).withValues(alpha: 0.85)
                                              : Colors.black.withValues(alpha: 0.85)),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: affinityMult != null && affinityMult > 1.0
                                            ? const Color(0xFF81C784)
                                            : (affinityMult != null && affinityMult < 1.0
                                                ? const Color(0xFFFF8A80)
                                                : const Color(0xFFE5A93C)),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      affinityMult != null && affinityMult > 1.0
                                          ? '▲ ADV'
                                          : (affinityMult != null && affinityMult < 1.0
                                              ? '▼ WEAK'
                                              : (unit.isPureblood ? 'PUREBLOOD' : 'G${unit.generation}')),
                                      style: TextStyle(
                                        color: affinityMult != null && affinityMult > 1.0
                                            ? const Color(0xFFA5D6A7)
                                            : (affinityMult != null && affinityMult < 1.0
                                                ? const Color(0xFFFFCDD2)
                                                : const Color(0xFFE5A93C)),
                                        fontSize: 7.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                const SizedBox(width: 4),
                              ] else ...[
                                // During live combat: keep miniature view clear & uncluttered
                                if (isBossUnit) ...[
                                  Builder(builder: (ctx) {
                                    final String phaseText = hpRatio > 0.66
                                        ? '☠ BOSS'
                                        : (hpRatio > 0.33 ? '⚡ BOSS (P2)' : '🔥 BOSS (P3)');
                                    final Color phaseColor = hpRatio > 0.66
                                        ? const Color(0xFFFFD54F)
                                        : (hpRatio > 0.33 ? const Color(0xFFFF9800) : const Color(0xFFFF1744));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB71C1C).withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: phaseColor, width: 1.4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: phaseColor.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.dangerous, size: 9, color: phaseColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            phaseText,
                                            style: TextStyle(
                                              color: phaseColor,
                                              fontSize: 8.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 4),
                                ],
                              ],

                              // Tactical Character Sheet Modal Button
                              GestureDetector(
                                key: Key('unit_sheet_btn_${unit.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _openInspectorModal(unit, isEnemy);
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _isPreBattleSetup ? 5 : 4,
                                    vertical: _isPreBattleSetup ? 2.5 : 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E28).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isBossUnit ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.assignment,
                                        size: _isPreBattleSetup ? 7.5 : 8.5,
                                        color: isBossUnit ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F),
                                      ),
                                      if (_isPreBattleSetup) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          'SHEET',
                                          style: TextStyle(
                                            color: isBossUnit ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F),
                                            fontSize: 7.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Live Battle Subtle Target Pip (Only during active combat when selected)
                      if (!_isPreBattleSetup && isSelectedTarget && isEnemy && alive)
                        Container(
                          margin: const EdgeInsets.only(top: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: affinityMult != null && affinityMult > 1.0
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.90)
                                : (affinityMult != null && affinityMult < 1.0
                                    ? const Color(0xFFC62828).withValues(alpha: 0.90)
                                    : const Color(0xFFB3261E).withValues(alpha: 0.90)),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: affinityMult != null && affinityMult > 1.0
                                  ? const Color(0xFF81C784)
                                  : (affinityMult != null && affinityMult < 1.0
                                      ? const Color(0xFFFF8A80)
                                      : const Color(0xFFFF5252)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.gps_fixed, size: 7.5, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                affinityMult != null && affinityMult > 1.0
                                    ? 'TARGET (▲+30%)'
                                    : (affinityMult != null && affinityMult < 1.0
                                        ? 'TARGET (▼WEAK)'
                                        : 'TARGET'),
                                style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Pre-Battle Column Navigation Pill & Nudge Arrows
            if (_isPreBattleSetup && !isEnemy && alive)
              Positioned(
                top: 2,
                left: 2,
                right: 2,
                child: Container(
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelectedForSwap
                        ? const Color(0xFFE5A93C).withValues(alpha: 0.95)
                        : const Color(0xFF161622).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelectedForSwap ? const Color(0xFFFFD54F) : const Color(0xFF424254),
                      width: isSelectedForSwap ? 1.5 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        key: Key('shift_left_${unit.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: allyIndex > 0 ? () => _shiftAlliedUnit(allyIndex, -1) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.chevron_left,
                            size: 13,
                            color: allyIndex > 0
                                ? (isSelectedForSwap ? Colors.black : const Color(0xFFFFD54F))
                                : Colors.white24,
                          ),
                        ),
                      ),
                      Text(
                        isSelectedForSwap ? 'SWAP' : 'COL ${allyIndex + 1}',
                        style: TextStyle(
                          color: isSelectedForSwap ? Colors.black : const Color(0xFFFFD54F),
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      GestureDetector(
                        key: Key('shift_right_${unit.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: allyIndex < widget.tickManager.allies.length - 1
                            ? () => _shiftAlliedUnit(allyIndex, 1)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.chevron_right,
                            size: 13,
                            color: allyIndex < widget.tickManager.allies.length - 1
                                ? (isSelectedForSwap ? Colors.black : const Color(0xFFFFD54F))
                                : Colors.white24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Fallen Overlay
                if (!alive)
                  if (unit.isFigurineCutout || isBossUnit)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A24).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFEF5350), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dangerous, size: 14, color: Color(0xFFEF5350)),
                              SizedBox(width: 4),
                              Text(
                                'FALLEN',
                                style: TextStyle(
                                  color: Color(0xFFEF5350),
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dangerous, size: 18, color: Color(0xFFEF5350)),
                              SizedBox(height: 2),
                              Text(
                                'FALLEN',
                                style: TextStyle(
                                  color: Color(0xFFEF5350),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );

      return DragTarget<GeneralOrderDefinition>(
        onWillAcceptWithDetails: (details) {
          final order = details.data;
          if (order.id == 'sanguine_revival') {
            return !isEnemy && !alive;
          }
          if (order.id == 'blood_boil' || order.id == 'iron_bulwark' || order.id == 'stand_resolute') {
            return !isEnemy && alive;
          }
          return isEnemy && alive;
        },
        onAcceptWithDetails: (details) {
          final order = details.data;
          // GDD v2.7 Sec 7.3: Target Failsafe: If target dies or becomes invalid while hovering card during bullet-time,
          // the card snaps safely back to hand with 0 Focus consumed.
          final liveUnit = isEnemy
              ? widget.tickManager.enemies.where((e) => e.id == unit.id).firstOrNull
              : widget.tickManager.allies.where((a) => a.id == unit.id).firstOrNull;
          final bool isStillAlive = liveUnit?.isAlive ?? false;
          final bool targetValid = (order.id == 'sanguine_revival') ? !isStillAlive : isStillAlive;

          if (targetValid) {
            _dispatchOrder(order, targetUnitId: unit.id);
          } else {
            _addPop('TARGET LOST', const Color(0xFFB0BEC5));
          }
          widget.commandService.setBulletTime(false);
          widget.tickManager.setBulletTime(false);
        },
        builder: (context, candidateData, rejectedData) {
          final bool isHovered = candidateData.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                cardWidget,
                // Subtle organic tabletop targeting ring around unit base
                if (isHovered)
                  Positioned(
                    bottom: 24,
                    left: 4,
                    right: 4,
                    height: 24,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.elliptical(50, 14)),
                          border: Border.all(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

  // ===========================================================================
  // LOG BANNER & SKILL ACTIONS BAR
  // ===========================================================================

  Widget _buildCombatLogBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF14141B),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Text(
        _combatLog,
        style: const TextStyle(
          color: Color(0xFFC5C5D2),
          fontFamily: 'monospace',
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPreBattleControlBar() {
    final allies = widget.tickManager.allies;
    final frontlineCount = allies.where((u) => u.isFrontline).length;
    final backlineCount = allies.where((u) => u.isBackline).length;
    final focus = widget.commandService.currentFocus;
    final profile = widget.commandService.currentProfile;
    final handCards = widget.commandService.hand.isNotEmpty
        ? widget.commandService.hand
        : profile.orders;
    final isCompact = MediaQuery.of(context).size.height < 760;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        border: Border(top: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Upper Info Rail: Formation Counts & Presets
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lane distribution pills
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5A93C), width: 1.0),
                      ),
                      child: Text(
                        '🛡️ FRONT: $frontlineCount',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF80D8FF).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF80D8FF), width: 1.0),
                      ),
                      child: Text(
                        '🔮 REAR: $backlineCount',
                        style: const TextStyle(
                          color: Color(0xFF80D8FF),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),

                // Tactical Presets (ALL FRONT, BALANCED, ALL REAR)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPresetButton(
                      label: 'ALL FRONT',
                      isActive: frontlineCount == allies.length,
                      onTap: () => _applyFormationPreset(allFrontline: true),
                    ),
                    const SizedBox(width: 4),
                    _buildPresetButton(
                      label: 'BALANCED',
                      isActive: frontlineCount > 0 && backlineCount > 0,
                      onTap: () => _applyFormationPreset(allFrontline: null),
                    ),
                    const SizedBox(width: 4),
                    _buildPresetButton(
                      label: 'ALL REAR',
                      isActive: backlineCount == allies.length,
                      onTap: () => _applyFormationPreset(allFrontline: false),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Opening Hand Label / Focus Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.style, size: 12, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 4),
                    Text(
                      'OPENING HAND (${handCards.length} CARDS)',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Text(
                  'STARTING FOCUS: $focus/${widget.commandService.maxFocus}',
                  style: TextStyle(
                    color: profile.themeColor,
                    fontSize: 8.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Opening Hand Cards Tray
          _buildFannedHandTray(
            handCards: handCards,
            focus: focus,
            profile: profile,
            isCompact: isCompact,
          ),

          const SizedBox(height: 6),

          // Lower Action Rail: Guidance Hint & COMMENCE ENGAGEMENT Button
          Row(
            children: [
              // Tactical formation guidance tooltip
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38384A), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: Color(0xFFFFD54F)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedSwapUnitId != null
                              ? 'Tap another allied unit to swap column positions, or tap ◀ / ▶.'
                              : (frontlineCount == 0
                                  ? '⚠️ ALL BACKLINE: No melee shield! Enemies engage directly.'
                                  : (backlineCount == 0
                                      ? '⚔️ ALL FRONTLINE: Maximum Stagger Resist (+10%) & Aggro absorption.'
                                      : 'Tap ◀ / ▶ to move units left/right. Tap FRONT/REAR to toggle lane depth.')),
                          style: TextStyle(
                            color: _selectedSwapUnitId != null
                                ? const Color(0xFFFFD54F)
                                : (frontlineCount == 0
                                    ? const Color(0xFFFF8A80)
                                    : (backlineCount == 0 ? const Color(0xFFFFD54F) : Colors.white70)),
                            fontSize: 8.0,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Autobattler toggle before launch
              GestureDetector(
                onTap: () {
                  setState(() {
                    _autoBattle = !_autoBattle;
                  });
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _autoBattle ? const Color(0xFF1B5E20) : const Color(0xFF2A2A38),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _autoBattle ? const Color(0xFF81C784) : const Color(0xFF555566),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _autoBattle ? Icons.autorenew : Icons.touch_app,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _autoBattle ? 'AUTO ON' : 'MANUAL',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Grand Golden COMMENCE ENGAGEMENT Button
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 18, color: Color(0xFFFFD54F)),
                  label: const Text(
                    'COMMENCE BATTLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.0,
                      letterSpacing: 1.0,
                    ),
                  ),
                  onPressed: _commenceBattle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFB3261E).withValues(alpha: 0.4) : const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isActive ? const Color(0xFFFFD54F) : const Color(0xFF424254),
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFFD54F) : Colors.white60,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlBar(
      bool isPlayerTurn, UnitEntity? selectedEnemy, UnitEntity? activeUnit) {
    if (_isPreBattleSetup) {
      return _buildPreBattleControlBar();
    }

    final focus = widget.commandService.currentFocus;
    final maxFocus = widget.commandService.maxFocus;
    final profile = widget.commandService.currentProfile;
    final skills = activeUnit?.resolvedSkills ?? [];
    final double? targetedAffinity = (selectedEnemy != null && activeUnit != null)
        ? CombatMath.getAffinityMultiplier(activeUnit.archetype, selectedEnemy.archetype)
        : null;

    final commander = widget.tickManager.allies.where((u) => u.isCommander).firstOrNull;
    final bool isVladCommander = widget.commandService.activeGeneralType == GeneralType.vladislav;
    final String auraText = isVladCommander
        ? (commander != null && commander.isVanguard && commander.isAlive
            ? '🩸 VAMPIRIC CONDUIT: +15% LIFESTEAL (FRONTLINE)'
            : (commander != null && commander.isArcanum && commander.isAlive
                ? '🩸 VAMPIRIC CONDUIT: -1 FOCUS BLEED SLIPS (BACKLINE)'
                : '🩸 VAMPIRIC CONDUIT'))
        : '✦ ${profile.name.toUpperCase()}';

    final handCards = widget.commandService.hand.isNotEmpty
        ? widget.commandService.hand
        : profile.orders;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        border: Border(top: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional: Compact Manual Skill Strip (Only shown when MANUAL mode is active AND waiting on player action)
          if (!_autoBattle && isPlayerTurn && skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACT: ${activeUnit?.name.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: skills.map((skill) {
                        final bool isUlt = skill.isLimitBurst;
                        final bool ultReady = (activeUnit?.ultimateCharge ?? 0.0) >= 100.0;
                        final bool isReady = isUlt ? ultReady : skill.isReady;
                        final bool canCast = isPlayerTurn && isReady && _selectedEnemyId != null;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isUlt
                                      ? (ultReady ? const Color(0xFFE5A93C) : const Color(0xFF2E2416))
                                      : (skill.cooldownTurns > 0 ? const Color(0xFFB3261E) : const Color(0xFF2E7D32)),
                                  foregroundColor: isUlt && ultReady ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onPressed: canCast ? () => _executePlayerSkill(skill) : null,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isUlt ? 'LIMIT BURST' : skill.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      isUlt
                                          ? (ultReady
                                              ? 'READY (100%)'
                                              : '${(activeUnit?.ultimateCharge ?? 0).toInt()}% GAUGE')
                                          : (skill.currentCooldown > 0
                                              ? '${skill.currentCooldown} CD'
                                              : (targetedAffinity != null && targetedAffinity > 1.0
                                                  ? '${skill.damageCoefficient}x DMG (▲ 1.3x)'
                                                  : (targetedAffinity != null && targetedAffinity < 1.0
                                                      ? '${skill.damageCoefficient}x DMG (▼ 0.75x)'
                                                      : '${skill.damageCoefficient}x DMG'))),
                                      style: TextStyle(
                                        fontSize: 7.0,
                                        fontWeight: FontWeight.w600,
                                        color: isUlt && ultReady ? Colors.black87 : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Upper Rail: The Gauntlet Spindle & Leadership Aura Bar
          Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Focus Orbs & Spindle Label
                GestureDetector(
                  onTap: _showGeneralSelectionDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < maxFocus; i++)
                        Container(
                          margin: const EdgeInsets.only(right: 3),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < focus ? profile.themeColor : Colors.transparent,
                            border: Border.all(color: profile.themeColor, width: 1.5),
                            boxShadow: i < focus
                                ? [
                                    BoxShadow(
                                      color: profile.themeColor.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        'FOCUS $focus/$maxFocus',
                        style: TextStyle(
                          color: profile.themeColor,
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '(1pt/30t)',
                        style: TextStyle(color: Colors.white38, fontSize: 7.5),
                      ),
                    ],
                  ),
                ),

                // Leadership Aura Pill (GDD v2.8 Sec 3.5)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: profile.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: profile.themeColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Text(
                      auraText,
                      style: TextStyle(
                        color: profile.themeColor,
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tactical Bullet-Time Slow-Mo Toggle
                    GestureDetector(
                      onTap: () {
                        final bool isCurrentlyBullet = widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime;
                        final bool nextState = !isCurrentlyBullet;
                        widget.commandService.setBulletTime(nextState);
                        widget.tickManager.setBulletTime(nextState);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: (widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime)
                              ? const Color(0xFF004D40)
                              : const Color(0xFF263238),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: (widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime)
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF546E7A),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_bottom,
                              size: 10,
                              color: (widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime)
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              (widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime)
                                  ? 'BULLET-TIME (30%)'
                                  : 'BULLET-TIME',
                              style: TextStyle(
                                color: (widget.commandService.isBulletTimeActive || widget.tickManager.isBulletTime)
                                    ? const Color(0xFF00E5FF)
                                    : Colors.white70,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Autobattler Status Pill (GDD v2.8 Sec 1 & 2.3)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _autoBattle = !_autoBattle;
                          if (_autoBattle && _isPlayerTurnNow) {
                            _handleAutoPlayerTurn();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _autoBattle ? const Color(0xFF1B5E20) : const Color(0xFF424250),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: _autoBattle ? const Color(0xFF81C784) : const Color(0xFF757575),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _autoBattle ? Icons.autorenew : Icons.touch_app,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _autoBattle ? 'AUTOBATTLER ON' : 'MANUAL',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lower Rail: Fanned Hand of Collectible Wargaming Cards + Burn Pit
          _buildFannedHandTray(
            handCards: handCards,
            focus: focus,
            profile: profile,
            isCompact: MediaQuery.of(context).size.height < 760,
          ),
        ],
      ),
    );
  }

  Widget _buildFannedHandTray({
    required List<GeneralOrderDefinition> handCards,
    required int focus,
    required GeneralProfile profile,
    required bool isCompact,
  }) {
    final cardsToDisplay = handCards.take(4).toList();
    final int count = cardsToDisplay.length;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;
    final double cardWidth = isDesktop ? 106.0 : (isCompact ? 82.0 : 96.0);
    final double cardHeight = isDesktop ? 158.0 : (isCompact ? 122.0 : 142.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Fanned Hand of Cards (Physical Tabletop Hand Spread)
            Flexible(
              child: SizedBox(
                height: cardHeight + 22,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(count, (index) {
                        final order = cardsToDisplay[index];
                        final int effCost = widget.commandService.getEffectiveFocusCost(order);
                        final bool isUnlocked = widget.commandService.isOrderUnlocked(order);
                        final bool canAfford = focus >= effCost && isUnlocked;
                        final bool isHovered = _hoveredCardIndex == index;

                        // Physical tabletop fan geometry: arched curve and radial rotation
                        final double centerIdx = (count - 1) / 2.0;
                        final double offsetFromCenter = index - centerIdx;
                        final double fanAngle = isHovered ? 0.0 : (offsetFromCenter * 0.055);
                        final double arcY = isHovered ? -18.0 : (offsetFromCenter.abs() * 4.5);
                        final double overlapX = index > 0 ? (isCompact ? -10.0 : -14.0) : 0.0;

                        return Transform.translate(
                          offset: Offset(overlapX, arcY),
                          child: Transform.rotate(
                            angle: fanAngle,
                            child: AnimatedScale(
                              scale: isHovered ? 1.07 : 1.0,
                              duration: const Duration(milliseconds: 140),
                              child: MouseRegion(
                                onEnter: (_) => setState(() => _hoveredCardIndex = index),
                                onExit: (_) => setState(() => _hoveredCardIndex = null),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: _buildTuningSlipCard(
                                    order: order,
                                    effectiveCost: effCost,
                                    availableFocus: focus,
                                    canAfford: canAfford,
                                    isUnlocked: isUnlocked,
                                    themeColor: profile.themeColor,
                                    width: cardWidth,
                                    height: cardHeight,
                                    onTap: _isPreBattleSetup
                                        ? () => _showPreBattleCardInfo(order)
                                        : () => _dispatchOrder(order),
                                    onLockedTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${order.name} is sealed! Anoint ${profile.name} to Phylactery Rank ${order.requiredPhylacteryRank} in the Commander Sanctuary.',
                                          ),
                                          backgroundColor: const Color(0xFFB3261E),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Under-Rail Burn Pit (48x48 tabletop brazier)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: _buildBurnPit(profile.themeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTuningSlipCard({
    required GeneralOrderDefinition order,
    required int effectiveCost,
    required int availableFocus,
    required bool canAfford,
    required bool isUnlocked,
    required Color themeColor,
    required VoidCallback onTap,
    required VoidCallback onLockedTap,
    double? width,
    double? height,
  }) {
    final double cardW = width ?? 105.0;
    final double cardH = height ?? 150.0;

    final slipWidget = WargamingSpellCard(
      order: order,
      effectiveCost: effectiveCost,
      canAfford: canAfford,
      isUnlocked: isUnlocked,
      themeColor: themeColor,
      onTap: onTap,
      onLockedTap: onLockedTap,
      isCompact: false,
      width: cardW,
      height: cardH,
    );

    if (!isUnlocked || _isPreBattleSetup) {
      return slipWidget;
    }

    return Draggable<GeneralOrderDefinition>(
      data: order,
      dragAnchorStrategy: (draggable, context, position) {
        return const Offset(36, 53);
      },
      onDragStarted: () {
        widget.commandService.setBulletTime(true);
        widget.tickManager.setBulletTime(true);
      },
      onDragEnd: (_) {
        widget.commandService.setBulletTime(false);
        widget.tickManager.setBulletTime(false);
      },
      onDraggableCanceled: (_, __) {
        widget.commandService.setBulletTime(false);
        widget.tickManager.setBulletTime(false);
      },
      feedback: Material(
        color: Colors.transparent,
        child: WargamingSpellCard(
          order: order,
          effectiveCost: effectiveCost,
          canAfford: canAfford,
          isUnlocked: isUnlocked,
          themeColor: themeColor,
          isCompact: false,
          width: 72,
          height: 106,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: slipWidget,
      ),
      child: slipWidget,
    );
  }

  Widget _buildBurnPit(Color themeColor) {
    return DragTarget<GeneralOrderDefinition>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final burned = details.data;
        widget.commandService.burnCard(burned.id);
        _addPop('BURNED', const Color(0xFFFF7043));
        widget.commandService.setBulletTime(false);
        widget.tickManager.setBulletTime(false);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;
        return Tooltip(
          message: 'Burn Card (0 Focus, 6-tick CD)',
          child: GestureDetector(
            onTap: () {
              if (widget.commandService.hand.isNotEmpty) {
                final burned = widget.commandService.hand.first;
                widget.commandService.burnCard(burned.id);
                _addPop('BURNED', const Color(0xFFFF7043));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isHovered ? const Color(0xFF5E1A1A) : const Color(0xFF261416),
                border: Border.all(
                  color: isHovered ? const Color(0xFFFFAB91) : const Color(0xFFFF7043),
                  width: isHovered ? 2.0 : 1.2,
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: isHovered
                    ? [
                        const BoxShadow(
                          color: Color(0xFFFF7043),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: isHovered ? Colors.white : const Color(0xFFFF7043),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'BURN',
                    style: TextStyle(
                      color: Color(0xFFFFAB91),
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnitStatusMeter({
    required UnitEntity unit,
    required double hpRatio,
    required double tmRatio,
    required bool isDamaged,
    bool isCompact = false,
  }) {
    Color hpColor = const Color(0xFF00E676); // High-contrast emerald
    if (hpRatio < 0.20) {
      hpColor = const Color(0xFFFF1744); // Critical red
    } else if (hpRatio < 0.45) {
      hpColor = const Color(0xFFFFB300); // Amber warning
    }
    if (isDamaged) {
      hpColor = const Color(0xFFFF1744);
    }

    final double clampedHp = hpRatio.clamp(0.0, 1.0);
    final double clampedTm = tmRatio.clamp(0.0, 1.0);
    final double shieldIntegrity = unit.maxHp > 0 ? (unit.shieldPoints / unit.maxHp).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: isCompact ? 84 : 96,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 3, vertical: isCompact ? 1 : 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C12).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF38384A), width: 0.8),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HP Bar track with shield overlay
          SizedBox(
            height: isCompact ? 3.0 : 4.5,
            child: Stack(
              children: [
                // Track background
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                // Health fill
                FractionallySizedBox(
                  widthFactor: clampedHp,
                  child: Container(
                    decoration: BoxDecoration(
                      color: hpColor,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: hpColor.withValues(alpha: 0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                // Aegis Shield overlay if present
                if (shieldIntegrity > 0)
                  FractionallySizedBox(
                    widthFactor: shieldIntegrity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(1.5),
                        border: Border.all(color: Colors.white, width: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 1.0 : 1.5),
          // AP / Turn Meter Bar
          SizedBox(
            height: isCompact ? 1.5 : 2.0,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1520),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: clampedTm,
                  child: Container(
                    decoration: BoxDecoration(
                      color: clampedTm >= 0.999 ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(height: 1.0),
            // Numerical HP readout
            Text(
              '${unit.currentHp}/${unit.maxHp}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 6.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _archetypeShortCode(Archetype a) {
    switch (a) {
      case Archetype.juggernaut:
        return 'JUG';
      case Archetype.assassin:
        return 'ASN';
      case Archetype.marksman:
        return 'MRK';
      case Archetype.skirmisher:
        return 'SKM';
      case Archetype.support:
        return 'SUP';
      case Archetype.occultist:
        return 'OCC';
    }
  }

  Color _archetypeColor(Archetype a) {
    switch (a) {
      case Archetype.juggernaut:
        return const Color(0xFF4A90E2);
      case Archetype.assassin:
        return const Color(0xFFE24A4A);
      case Archetype.marksman:
        return const Color(0xFF50E3C2);
      case Archetype.skirmisher:
        return const Color(0xFFF5A623);
      case Archetype.support:
        return const Color(0xFF7ED321);
      case Archetype.occultist:
        return const Color(0xFFBD10E0);
    }
  }

  IconData _archetypeIcon(Archetype a) {
    switch (a) {
      case Archetype.juggernaut:
        return Icons.shield;
      case Archetype.assassin:
        return Icons.colorize;
      case Archetype.marksman:
        return Icons.gps_fixed;
      case Archetype.skirmisher:
        return Icons.air;
      case Archetype.support:
        return Icons.healing;
      case Archetype.occultist:
        return Icons.auto_awesome;
    }
  }

  Color _statusColor(StatusEffectType type) {
    switch (type) {
      case StatusEffectType.bleed:
        return const Color(0xFFE53935);
      case StatusEffectType.blight:
        return const Color(0xFF43A047);
      case StatusEffectType.stun:
        return const Color(0xFFFFB300);
      case StatusEffectType.defenseUp:
        return const Color(0xFF1E88E5);
      case StatusEffectType.speedUp:
        return const Color(0xFF00ACC1);
      case StatusEffectType.decaying:
        return const Color(0xFF8D6E63);
      case StatusEffectType.burn:
        return const Color(0xFFFF7043);
      case StatusEffectType.freeze:
        return const Color(0xFF29B6F6);
      case StatusEffectType.vulnerable:
        return const Color(0xFFAB47BC);
      case StatusEffectType.shield:
        return const Color(0xFFFFD54F);
      case StatusEffectType.invulnerable:
        return const Color(0xFF80CBC4);
      case StatusEffectType.taunt:
        return const Color(0xFFFF5722);
    }
  }

  String _statusAbbr(StatusEffectType type) {
    switch (type) {
      case StatusEffectType.bleed:
        return 'BLD';
      case StatusEffectType.blight:
        return 'BLT';
      case StatusEffectType.stun:
        return 'STN';
      case StatusEffectType.defenseUp:
        return 'ARM';
      case StatusEffectType.speedUp:
        return 'SPD';
      case StatusEffectType.decaying:
        return 'ROT';
      case StatusEffectType.burn:
        return 'BRN';
      case StatusEffectType.freeze:
        return 'FRZ';
      case StatusEffectType.vulnerable:
        return 'VUL';
      case StatusEffectType.shield:
        return 'SHD';
      case StatusEffectType.invulnerable:
        return 'GRC';
      case StatusEffectType.taunt:
        return 'TNT';
    }
  }

  Color _factionGlowColor(UnitEntity unit) {
    if (unit.isBoss) return const Color(0xFFFF1744);
    switch (unit.factionName) {
      case 'Ash Legion':
        return const Color(0xFFFF9800);
      case 'Crypt Stalkers':
        return const Color(0xFF00E5FF);
      case 'Crimson Court':
        return const Color(0xFFD50000);
      case 'Weaver Brood':
        return const Color(0xFFAB47BC);
      case 'Feral Beasts':
        return const Color(0xFF66BB6A);
      case 'Deathless Undead':
        return const Color(0xFF26A69A);
      case 'Iron Vanguard':
      default:
        return const Color(0xFF42A5F5);
    }
  }
}
