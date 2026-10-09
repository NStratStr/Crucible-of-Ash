import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/combat_math.dart';
import '../../shared/models/expedition_boon.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
import '../../shared/widgets/living_atmosphere_background.dart';
import '../../shared/widgets/hexagonal_affinity_wheel_widget.dart';
import 'combat_resolution_service.dart';
import 'enemy_ai_service.dart';
import 'initiative_tick_manager.dart';
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

class BattleScreen extends StatefulWidget {
  final InitiativeTickManager tickManager;
  final CombatResolutionService combatService;
  final GeneralCommandService commandService;
  final RelicService? relicService;
  final int bloodlineSigils;
  final ValueChanged<int>? onSigilsChanged;
  final VoidCallback? onResetEncounter;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;

  const BattleScreen({
    super.key,
    required this.tickManager,
    required this.combatService,
    required this.commandService,
    this.relicService,
    this.bloodlineSigils = 0,
    this.onSigilsChanged,
    this.onResetEncounter,
    this.onVictory,
    this.onDefeat,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  String? _selectedEnemyId;
  String _combatLog = 'Prepare for engagement. The Crucible awaits.';
  late EnemyAiService _aiService;
  bool _isProcessingAiTurn = false;
  bool _autoBattle = false;
  Timer? _autoBattleTimer;
  bool _hasDispatchedEndOutcome = false;

  final List<FloatingCombatText> _floatingPops = [];
  final List<Timer> _popTimers = [];

  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _screenFlashType;
  Color? _screenFlashColorOverride;
  GeneralOrderBannerData? _activeOrderBanner;
  LimitBurstBannerData? _activeLimitBurstBanner;
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

  void _triggerAttackAnimation(String attackerId, String targetId, {String? vfx}) {
    if (!mounted) return;
    _triggerScreenShake(isHeavy: false);
    setState(() {
      _attackingUnitId = attackerId;
      _damagedUnitId = targetId;
      _screenFlashType = vfx ?? 'slash';
      _screenFlashColorOverride = null;
    });

    final timer = Timer(const Duration(milliseconds: 320), () {
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
    _aiService = EnemyAiService(
      tickManager: widget.tickManager,
      combatService: widget.combatService,
      commandService: widget.commandService,
    );

    widget.tickManager.addListener(_onEngineUpdate);
    widget.commandService.addListener(_onEngineUpdate);

    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive);
    if (aliveEnemies.isNotEmpty) {
      _selectedEnemyId = aliveEnemies.first.id;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.tickManager.phase == CombatPhase.idle) {
        widget.tickManager.start();
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
        _selectedEnemyId = aliveEnemies.first.id;
      }

      _isProcessingAiTurn = false;
      _hasDispatchedEndOutcome = false;
      _combatLog = 'Encounter engaged! The Crucible awakens.';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.tickManager.phase == CombatPhase.idle) {
          widget.tickManager.start();
        }
      });
    }
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _autoBattleTimer?.cancel();
    for (final t in _popTimers) {
      t.cancel();
    }
    _popTimers.clear();
    widget.tickManager.removeListener(_onEngineUpdate);
    widget.commandService.removeListener(_onEngineUpdate);
    super.dispose();
  }

  String? _lastProcessedTurnStartUnitId;

  void _onEngineUpdate() {
    if (!mounted) return;

    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
    if (aliveEnemies.isEmpty) {
      _selectedEnemyId = null;
    } else if (_selectedEnemyId == null || !aliveEnemies.any((u) => u.id == _selectedEnemyId)) {
      _selectedEnemyId = aliveEnemies.first.id;
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

    if (_aiService.isEnemyTurn && !_isProcessingAiTurn) {
      _handleAiTurn();
    } else if (_autoBattle && _isPlayerTurnNow && !_isProcessingAiTurn) {
      _handleAutoPlayerTurn();
    }

    if (widget.tickManager.phase == CombatPhase.battleEnded && !_hasDispatchedEndOutcome) {
      if (widget.tickManager.enemies.every((u) => !u.isAlive)) {
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

  Future<void> _handleAiTurn() async {
    if (_isProcessingAiTurn || !_aiService.isEnemyTurn) return;
    _isProcessingAiTurn = true;

    try {
      final int aiDelay = (650 / widget.tickManager.speedMultiplier).round();
      await Future.delayed(Duration(milliseconds: aiDelay));
      if (!mounted) return;

      final activeBefore = widget.tickManager.activeUnit;
      if (activeBefore == null || !_aiService.isEnemyTurn) return;

      final result = _aiService.executeEnemyTurn();

      if (result != null) {
        widget.commandService.registerCombatDamage(result.damageDealt);

        _triggerAttackAnimation(
          result.attacker.id,
          result.target.id,
          vfx: result.isCritical ? 'crit' : 'slash',
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
          _combatLog =
              '${result.attacker.name} attacked ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText.';
          if (result.targetDefeated) {
            _combatLog += ' ${result.target.name} fell in combat!';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _combatLog = 'Enemy action paused: $e');
      }
    } finally {
      if (mounted) {
        _isProcessingAiTurn = false;
        if (_aiService.isEnemyTurn) {
          _handleAiTurn();
        } else if (_autoBattle && _isPlayerTurnNow) {
          _handleAutoPlayerTurn();
        }
      }
    }
  }

  void _handleAutoPlayerTurn() {
    if (!_isPlayerTurnNow || _isProcessingAiTurn) return;

    final active = widget.tickManager.activeUnit;
    if (active == null) return;

    final skills = active.resolvedSkills;
    final readySkill = skills.reversed.firstWhere((s) => s.isReady, orElse: () => skills.first);

    if (_selectedEnemyId == null) {
      final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
      if (aliveEnemies.isNotEmpty) {
        _selectedEnemyId = aliveEnemies.first.id;
      }
    }

    if (_selectedEnemyId != null) {
      _executePlayerSkill(readySkill);
    }
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
        vfx: result.isCritical ? 'crit' : (skill.isLimitBurst ? 'crit' : 'slash'),
      );

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
        _combatLog =
            '${result.attacker.name} invoked ${skill.name} on ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText.';
        if (result.targetDefeated) {
          _combatLog += ' ${result.target.name} was eradicated!';
        }
      });

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

  void _dispatchOrder(GeneralOrderDefinition order) {
    _executeOrder(() {
      final oldAllies = List<UnitEntity>.from(widget.tickManager.allies);
      final oldEnemies = List<UnitEntity>.from(widget.tickManager.enemies);
      final profile = widget.commandService.currentProfile;

      OrderResult res;
      switch (widget.commandService.activeGeneralType) {
        case GeneralType.vladislav:
          if (order.id == 'siphon_vitality') {
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

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      body: LivingAtmosphereBackground(
        imageAsset: 'assets/images/gothic_arch_battlefield.jpg',
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
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        child: Column(
                          children: [
                            // Hostile Formation (Arcanum backline top -> Vanguard frontline bottom)
                            _buildSquadFormation(
                              units: widget.tickManager.enemies,
                              isEnemy: true,
                              activeUnitId: activeUnit?.id,
                              selectedTargetId: _selectedEnemyId,
                              onSelectTarget: (id) => setState(() => _selectedEnemyId = id),
                            ),

                            // Center Clash Line: The Ashen Front
                            _buildClashLine(),

                            // Allied Formation (Vanguard frontline top -> Arcanum backline bottom)
                            _buildSquadFormation(
                              units: widget.tickManager.allies,
                              isEnemy: false,
                              activeUnitId: activeUnit?.id,
                            ),
                          ],
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

                const SizedBox(width: 8),

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
        child: Row(
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
            if (widget.onResetEncounter != null)
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'YOUR TURN: ${activeUnit.name.toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
        child: Row(
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
                Flexible(
                  child: Text(
                    'ENEMY TURN: ${activeUnit.name}',
                    style: const TextStyle(
                      color: Color(0xFFE57373),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
      child: const Row(
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

    final vanguard = units.where((u) => u.isVanguard).toList();
    final arcanum = units.where((u) => u.isArcanum).toList();

    final bool hasArcanum = arcanum.isNotEmpty;
    final bool hasVanguard = vanguard.isNotEmpty;

    if (!hasArcanum && !hasVanguard) {
      return const Expanded(child: SizedBox.shrink());
    }

    final List<Widget> tierWidgets = [];

    if (isEnemy) {
      // Enemy: Arcanum (Backline) at top, Vanguard (Frontline) closer to center
      if (hasArcanum) {
        tierWidgets.add(
          _buildTierRow(
            units: arcanum,
            isEnemy: true,
            isFrontline: false,
            activeUnitId: activeUnitId,
            selectedTargetId: selectedTargetId,
            onSelectTarget: onSelectTarget,
          ),
        );
      }
      if (hasArcanum && hasVanguard) {
        tierWidgets.add(const SizedBox(height: 3));
      }
      if (hasVanguard) {
        tierWidgets.add(
          _buildTierRow(
            units: vanguard,
            isEnemy: true,
            isFrontline: true,
            activeUnitId: activeUnitId,
            selectedTargetId: selectedTargetId,
            onSelectTarget: onSelectTarget,
          ),
        );
      }
    } else {
      // Allies: Vanguard (Frontline) closer to center, Arcanum (Backline) at bottom
      if (hasVanguard) {
        tierWidgets.add(
          _buildTierRow(
            units: vanguard,
            isEnemy: false,
            isFrontline: true,
            activeUnitId: activeUnitId,
            selectedTargetId: selectedTargetId,
            onSelectTarget: onSelectTarget,
          ),
        );
      }
      if (hasArcanum && hasVanguard) {
        tierWidgets.add(const SizedBox(height: 3));
      }
      if (hasArcanum) {
        tierWidgets.add(
          _buildTierRow(
            units: arcanum,
            isEnemy: false,
            isFrontline: false,
            activeUnitId: activeUnitId,
            selectedTargetId: selectedTargetId,
            onSelectTarget: onSelectTarget,
          ),
        );
      }
    }

    return Expanded(
      flex: 14,
      child: Column(
        children: tierWidgets,
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

    return Expanded(
      flex: 12,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                        constraints: const BoxConstraints(maxWidth: 360),
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
  }) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
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

  Widget _buildTierRow({
    required List<UnitEntity> units,
    required bool isEnemy,
    required bool isFrontline,
    required String? activeUnitId,
    String? selectedTargetId,
    ValueChanged<String>? onSelectTarget,
  }) {
    // Tighter together width-wise: cluster units in a disciplined squad formation
    final double maxClusterWidth = (units.length * 200.0).clamp(240.0, 680.0);

    return Expanded(
      flex: isFrontline ? 10 : 9,
      child: Padding(
        padding: EdgeInsets.only(
          top: isEnemy ? 0 : 3.0,
          bottom: isEnemy ? 3.0 : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxClusterWidth),
            child: Transform.scale(
              scale: isFrontline ? 1.0 : 0.96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: units.map((unit) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 210),
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
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClashLine() {
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF14141B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 11, color: Color(0xFFD4AF37)),
                SizedBox(width: 6),
                Text(
                  'THE ASHEN FRONT',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 8.5,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.shield_outlined, size: 11, color: Color(0xFFD4AF37)),
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

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id;
    final double lungeY = isAttacking ? (isEnemy ? 18.0 : -18.0) : 0.0;
    final double shakeX = isDamaged ? (isEnemy ? -5.5 : 5.5) : 0.0;
    final bool isCriticalHp = hpRatio < 0.25 && alive;

    Color borderColor = const Color(0xFF2B2B36);
    double borderWidth = 1.0;
    List<BoxShadow>? shadows;

    if (isDamaged) {
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

    return GestureDetector(
      onTap: () {
        if (isEnemy && alive) {
          if (isSelectedTarget) {
            // Already selected as target! Tapping again opens the character sheet / inspector!
            PedigreeInspectorDialog.show(
              context,
              unit,
              isEnemy: isEnemy,
              relicService: widget.relicService,
            );
          } else {
            // First tap selects target to hit
            onTap?.call();
          }
        } else {
          PedigreeInspectorDialog.show(
            context,
            unit,
            isEnemy: isEnemy,
            relicService: widget.relicService,
          );
        }
      },
      onDoubleTap: () {
        PedigreeInspectorDialog.show(
          context,
          unit,
          isEnemy: isEnemy,
          relicService: widget.relicService,
        );
      },
      onLongPress: () {
        PedigreeInspectorDialog.show(
          context,
          unit,
          isEnemy: isEnemy,
          relicService: widget.relicService,
        );
      },
      child: Transform.translate(
        offset: Offset(shakeX, lungeY),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                top: isBossUnit ? -14 : (unit.isFigurineCutout ? -4 : 0),
                bottom: isBossUnit ? 40 : 34,
                left: 2,
                right: 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // LAYER 1A: 3D Faction Ground Plinth & Circular Floor Spotlight
                    if (unit.isFigurineCutout) ...[
                      // Dynamic circular ground spotlight glow for active / targeted / boss figurines
                      if (isActive || isSelectedTarget || isBossUnit)
                        Positioned(
                          bottom: -3,
                          left: isBossUnit ? 2 : 8,
                          right: isBossUnit ? 2 : 8,
                          height: isBossUnit ? 24 : 18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.elliptical(
                                isBossUnit ? 240 : 130,
                                isBossUnit ? 32 : 22,
                              )),
                              gradient: RadialGradient(
                                colors: [
                                  (isActive
                                          ? const Color(0xFFFFD54F)
                                          : (isSelectedTarget ? const Color(0xFFFF1744) : const Color(0xFFFF5252)))
                                      .withValues(alpha: isBossUnit ? 0.45 : 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                      Positioned(
                        bottom: 0,
                        left: isBossUnit ? 8 : 14,
                        right: isBossUnit ? 8 : 14,
                        height: isBossUnit ? 18 : 14,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.elliptical(
                              isBossUnit ? 220 : 120,
                              isBossUnit ? 28 : 20,
                            )),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isActive
                                    ? const Color(0xFFFFD54F)
                                    : (isSelectedTarget
                                        ? const Color(0xFFFF1744)
                                        : _factionGlowColor(unit)))
                                    .withValues(alpha: alive ? (isBossUnit ? 0.9 : 0.7) : 0.15),
                                const Color(0xFF1E1E28),
                                const Color(0xFF0C0C12),
                              ],
                            ),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFFFFD54F)
                                  : (isSelectedTarget
                                      ? const Color(0xFFFF1744)
                                      : (isDamaged
                                          ? const Color(0xFFFF1744)
                                          : _factionGlowColor(unit).withValues(alpha: alive ? (isBossUnit ? 0.95 : 0.8) : 0.25))),
                              width: (isActive || isSelectedTarget || isBossUnit) ? 2.2 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isActive
                                        ? const Color(0xFFFFD54F)
                                        : (isSelectedTarget || isDamaged
                                            ? const Color(0xFFFF1744)
                                            : _factionGlowColor(unit)))
                                    .withValues(alpha: alive ? (isBossUnit ? 0.8 : 0.6) : 0.15),
                                blurRadius: (isActive || isSelectedTarget || isBossUnit) ? 18 : 7,
                                spreadRadius: (isActive || isSelectedTarget || isBossUnit) ? 2.5 : 1,
                              ),
                              const BoxShadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // LAYER 1B: Character Miniature Artwork (Painted ON TOP of plinth with prominent scale)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isBossUnit ? 6.0 : 4.0),
                        child: Center(
                          child: Transform.scale(
                            scale: isBossUnit ? 1.75 : (unit.isFigurineCutout ? 1.25 : 1.0),
                            child: ColorFiltered(
                              colorFilter: alive
                                  ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                  : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
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

                    // Critical HP Warning Vignette
                    if (isCriticalHp)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFB3261E).withValues(alpha: 0.25),
                        ),
                      ),

                    // Death Darkening
                    if (!alive)
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

              // LAYER 2.5: Damage Flash & Slash Sparks
              if (isDamaged) ...[
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Colors.white, Color(0xFFFFD54F), Colors.transparent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.95),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // LAYER 2.8: Bottom Readability Gradient
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

              // LAYER 3: Interactive UI Information anchored to Pedestal & Ground
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Opacity(
                          opacity: alive ? 1.0 : 0.25,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0, top: 1.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Status Effect Badges (if active, above the pedestal)
                                if (unit.activeEffects.isNotEmpty && alive)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Wrap(
                                      spacing: 2,
                                      runSpacing: 1,
                                      alignment: WrapAlignment.center,
                                      children: unit.activeEffects.take(4).map((eff) {
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
                                              fontSize: 7.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                // PEDESTAL HUD ROW: Shield (Left) - Level (Center) - Rarity/Target/Boss (Right)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: max(constraints.maxWidth, 380.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Bottom-Left of Pedestal: Archetype Shield Badge (or ☠ BOSS badge for bosses)
                                        if (isBossUnit)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB71C1C).withValues(alpha: 0.95),
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(color: const Color(0xFFFF5252), width: 1.4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFFF1744).withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.dangerous, size: 9, color: Color(0xFFFFD54F)),
                                                SizedBox(width: 3),
                                                Text(
                                                  '☠ BOSS',
                                                  style: TextStyle(
                                                    color: Color(0xFFFFD54F),
                                                    fontSize: 8.0,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
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

                                        // Middle of Pedestal: Tactical Formation Role + Level Badge
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
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
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                isBossUnit ? '👑 TITANIC' : (unit.isVanguard ? '⚔ FRONT' : '🔮 REAR'),
                                                style: TextStyle(
                                                  color: isBossUnit
                                                      ? const Color(0xFFFF8A80)
                                                      : (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)),
                                                  fontSize: 7.0,
                                                  fontWeight: FontWeight.w900,
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
                                          const SizedBox(width: 3),
                                          GestureDetector(
                                            onTap: () {
                                              PedigreeInspectorDialog.show(
                                                context,
                                                unit,
                                                isEnemy: isEnemy,
                                                relicService: widget.relicService,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E28),
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
                                                    size: 7.0,
                                                    color: isBossUnit ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F),
                                                  ),
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
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Under Pedestal: Unit Name
                                Center(
                                  child: Text(
                                    unit.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isBossUnit ? const Color(0xFFFFD54F) : Colors.white,
                                      fontSize: isBossUnit ? 10.5 : 9.5,
                                      fontWeight: FontWeight.bold,
                                      shadows: const [
                                        Shadow(color: Colors.black, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Under Pedestal: HP & Action Stats
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${unit.currentHp}/${unit.maxHp} HP',
                                        style: TextStyle(
                                          color: hpRatio > 0.35 ? Colors.white : const Color(0xFFEF5350),
                                          fontSize: isBossUnit ? 8.5 : 7.5,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                                        ),
                                      ),
                                      Text(
                                        '${unit.turnMeter.toInt()}% TM',
                                        style: TextStyle(
                                          color: const Color(0xFF00E5FF),
                                          fontSize: isBossUnit ? 8.5 : 7.5,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 2),

                                // Under Pedestal: Health Bar (Green / Red)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1.5),
                                  child: LinearProgressIndicator(
                                    value: hpRatio,
                                    minHeight: isBossUnit ? 5.5 : 4.0,
                                    backgroundColor: const Color(0xFF2A2A38),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      hpRatio > 0.4 ? const Color(0xFF4CAF50) : const Color(0xFFC62828),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 1.5),

                                // Under Pedestal: Action Bar (Cyan)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1.5),
                                  child: LinearProgressIndicator(
                                    value: tmRatio,
                                    minHeight: isBossUnit ? 3.5 : 2.5,
                                    backgroundColor: const Color(0xFF2A2A38),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

                // Fallen Overlay
                if (!alive)
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

  Widget _buildBottomControlBar(
      bool isPlayerTurn, UnitEntity? selectedEnemy, UnitEntity? activeUnit) {
    final focus = widget.commandService.currentFocus;
    final profile = widget.commandService.currentProfile;
    final skills = activeUnit?.resolvedSkills ?? [];
    final double? targetedAffinity = (selectedEnemy != null && activeUnit != null)
        ? CombatMath.getAffinityMultiplier(activeUnit.archetype, selectedEnemy.archetype)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF181820),
        border: Border(top: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Column(
        children: [
          // Row 1: Active Hero Skills (A1, A2, Ult)
          if (isPlayerTurn && skills.isNotEmpty)
            Row(
              children: skills.map((skill) {
                final bool isUlt = skill.isLimitBurst;
                final bool ultReady = (activeUnit?.ultimateCharge ?? 0.0) >= 100.0;
                final bool isReady = isUlt ? ultReady : skill.isReady;
                final bool canCast = isPlayerTurn && isReady && _selectedEnemyId != null;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: isUlt && ultReady
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          )
                        : null,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUlt
                            ? (ultReady ? const Color(0xFFE5A93C) : const Color(0xFF2E2416))
                            : (skill.cooldownTurns > 0
                                ? const Color(0xFFB3261E)
                                : const Color(0xFF388E3C)),
                        foregroundColor: isUlt && ultReady ? Colors.black : Colors.white,
                        side: isUlt && ultReady
                            ? const BorderSide(color: Color(0xFFFFD54F), width: 1.5)
                            : null,
                        disabledBackgroundColor: const Color(0xFF2A2A38),
                        disabledForegroundColor: Colors.white30,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: canCast ? () => _executePlayerSkill(skill) : null,
                      child: Column(
                        children: [
                          Text(
                            isUlt && ultReady ? 'LIMIT BURST' : skill.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isUlt && ultReady ? Colors.black : Colors.white,
                            ),
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
                              fontSize: 8,
                              color: isUlt && ultReady ? Colors.black87 : Colors.white70,
                              fontWeight: isUlt && ultReady ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('WAITING FOR INITIATIVE...',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text(
                  selectedEnemy != null ? 'TARGET: ${selectedEnemy.name}' : 'NO TARGET',
                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10),
                ),
              ],
            ),
          const SizedBox(height: 8),
          // Row 2: General Orders & Focus
          Row(
            children: [
              GestureDetector(
                onTap: _showGeneralSelectionDialog,
                child: Row(
                  children: [
                    for (int i = 0; i < widget.commandService.maxFocus; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < focus ? profile.themeColor : Colors.transparent,
                          border: Border.all(color: profile.themeColor, width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: profile.orders.map((order) {
                    final bool isUnlocked = widget.commandService.isOrderUnlocked(order);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildOrderButton(
                          title: order.name,
                          cost: order.focusCost,
                          availableFocus: focus,
                          borderColor: profile.themeColor,
                          isUnlocked: isUnlocked,
                          requiredRank: order.requiredPhylacteryRank,
                          onPressed: () => _dispatchOrder(order),
                          onLockedTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${order.name} is sealed! Anoint ${profile.name} to Phylactery Rank ${order.requiredPhylacteryRank} in the Commander Sanctuary.'),
                                backgroundColor: const Color(0xFFB3261E),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButton({
    required String title,
    required int cost,
    required int availableFocus,
    required Color borderColor,
    required bool isUnlocked,
    required int requiredRank,
    required VoidCallback onPressed,
    required VoidCallback onLockedTap,
  }) {
    if (!isUnlocked) {
      return OutlinedButton(
        onPressed: onLockedTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white38,
          side: const BorderSide(color: Color(0xFF383844), width: 1.0),
          padding: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 8, color: Colors.white38),
                const SizedBox(width: 2),
                Text(title, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white38)),
              ],
            ),
            Text(
              'RANK $requiredRank',
              style: const TextStyle(fontSize: 7.5, color: Color(0xFFE5A93C), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final bool canCast = availableFocus >= cost;

    return OutlinedButton(
      onPressed: canCast ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        side: BorderSide(
          color: canCast ? borderColor : const Color(0xFF2B2B36),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          Text(
            '$cost FOCUS',
            style: TextStyle(
              fontSize: 8,
              color: canCast ? const Color(0xFFE5A93C) : Colors.white24,
            ),
          ),
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
    }
  }

  Color _factionGlowColor(UnitEntity unit) {
    if (unit.isBoss) return const Color(0xFFFF1744);
    switch (unit.factionName) {
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
