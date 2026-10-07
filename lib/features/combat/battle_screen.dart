import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
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

class BattleScreen extends StatefulWidget {
  final InitiativeTickManager tickManager;
  final CombatResolutionService combatService;
  final GeneralCommandService commandService;
  final RelicService? relicService;
  final int bloodlineSigils;
  final ValueChanged<int>? onSigilsChanged;
  final VoidCallback? onResetEncounter;
  final VoidCallback? onVictory;

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

  final List<FloatingCombatText> _floatingPops = [];
  final List<Timer> _popTimers = [];

  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _screenFlashType;

  void _triggerAttackAnimation(String attackerId, String targetId, {String? vfx}) {
    if (!mounted) return;
    setState(() {
      _attackingUnitId = attackerId;
      _damagedUnitId = targetId;
      _screenFlashType = vfx ?? 'slash';
    });

    final timer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) {
        setState(() {
          _attackingUnitId = null;
          _damagedUnitId = null;
          _screenFlashType = null;
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
      await Future.delayed(const Duration(milliseconds: 550));
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

      setState(() {
        final glanceText = result.isGlancing ? ' [GLANCING BLOW -30% DMG]' : '';
        final critText = result.isCritical ? ' [CRIT!]' : '';
        _combatLog =
            '${result.attacker.name} invoked ${skill.name} on ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText.';
        if (result.targetDefeated) {
          _combatLog += ' ${result.target.name} was eradicated!';
        }
      });

      if (widget.tickManager.enemies.every((u) => !u.isAlive)) {
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
      setState(() => _combatLog = res.summary);
      if (widget.tickManager.enemies.every((u) => !u.isAlive)) {
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

  @override
  Widget build(BuildContext context) {
    final activeUnit = widget.tickManager.activeUnit;
    final isPlayerTurn = _isPlayerTurnNow;
    final selectedEnemy = widget.tickManager.enemies
        .where((u) => u.id == _selectedEnemyId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopStatusHeader(),
                _buildTurnGuidanceBanner(activeUnit, isPlayerTurn),
                _buildBattleModifierBanner(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Column(
                      children: [
                        // Hostile Squad
                        _buildSquadSection(
                          title: 'HOSTILE HORDE (TAP TO TARGET • LONG-PRESS TO INSPECT)',
                          units: widget.tickManager.enemies,
                          isEnemy: true,
                          activeUnitId: activeUnit?.id,
                          selectedTargetId: _selectedEnemyId,
                          onSelectTarget: (id) => setState(() => _selectedEnemyId = id),
                        ),
                        const Divider(color: Color(0xFF2B2B36), thickness: 1.5, height: 12),
                        // Allied Squad
                        _buildSquadSection(
                          title: 'YOUR LINEAGE BRIGADE (TAP TO INSPECT PEDIGREE)',
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
            // Floating Combat Text Overlay
            Positioned(
              top: 130,
              right: 30,
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
            // Full-screen Attack / Crit Strike VFX Overlay
            if (_screenFlashType != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _screenFlashType == 'crit'
                          ? const Color(0xFFFFD54F).withValues(alpha: 0.20)
                          : const Color(0xFFB3261E).withValues(alpha: 0.16),
                      border: Border.all(
                        color: _screenFlashType == 'crit'
                            ? const Color(0xFFFFD54F)
                            : const Color(0xFFB3261E),
                        width: 2.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _screenFlashType == 'crit' ? Icons.flash_on : Icons.colorize,
                        size: 64,
                        color: _screenFlashType == 'crit'
                            ? const Color(0xFFFFD54F).withValues(alpha: 0.8)
                            : const Color(0xFFEF5350).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP STATUS HEADER & TICK PROGRESS
  // ===========================================================================

  Widget _buildTopStatusHeader() {
    final profile = widget.commandService.currentProfile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Color(0xFF181820),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _showGeneralSelectionDialog,
            child: Row(
              children: [
                Icon(profile.icon, color: profile.themeColor, size: 20),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                      ],
                    ),
                    Text(
                      profile.title,
                      style: TextStyle(color: profile.themeColor, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _autoBattle ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _autoBattle ? Icons.play_arrow : Icons.pause,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _autoBattle ? 'AUTO ON' : 'MANUAL',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TICK ${widget.tickManager.tickCount}',
                style: const TextStyle(
                  color: Color(0xFF8E8EA0),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              _buildPhaseIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTurnGuidanceBanner(UnitEntity? activeUnit, bool isPlayerTurn) {
    if (widget.tickManager.phase == CombatPhase.battleEnded) {
      final alliesWon = widget.tickManager.enemies.every((u) => !u.isAlive);
      return Container(
        width: double.infinity,
        color: alliesWon ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              alliesWon
                  ? 'VICTORY! All hostile vessels eradicated.'
                  : 'DEFEAT! Your lineage has fallen.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (widget.onResetEncounter != null)
              GestureDetector(
                onTap: widget.onResetEncounter,
                child: const Text('REPLAY',
                    style: TextStyle(
                        color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
          ],
        ),
      );
    }

    if (isPlayerTurn && activeUnit != null) {
      return Container(
        width: double.infinity,
        color: const Color(0xFFB3261E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.yellowAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'YOUR TURN: ${activeUnit.name} is ready! Choose a skill below to strike.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    if (_aiService.isEnemyTurn && activeUnit != null) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF424242),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                ),
                const SizedBox(width: 8),
                Text(
                  'ENEMY TURN: ${activeUnit.name} is attacking...',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                _isProcessingAiTurn = false;
                _handleAiTurn();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB3261E),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'RESOLVE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBattleModifierBanner() {
    final modifier = widget.combatService.battleModifier;
    if (modifier == BattleModifier.none) return const SizedBox.shrink();

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String description;

    switch (modifier) {
      case BattleModifier.titanicFury:
        bgColor = const Color(0xFF261010);
        borderColor = const Color(0xFFD32F2F);
        textColor = const Color(0xFFEF5350);
        icon = Icons.warning_amber_rounded;
        title = 'TITANIC FURY';
        description = 'Boss attacks strike all frontline Vanguard units simultaneously.';
        break;
      case BattleModifier.bloodMoon:
        bgColor = const Color(0xFF261808);
        borderColor = const Color(0xFFFB8C00);
        textColor = const Color(0xFFFFB74D);
        icon = Icons.brightness_2;
        title = 'BLOOD MOON';
        description = 'All critical strike damage is amplified by +50%.';
        break;
      case BattleModifier.corrosiveMiasma:
        bgColor = const Color(0xFF1F1026);
        borderColor = const Color(0xFF8E24AA);
        textColor = const Color(0xFFBA68C8);
        icon = Icons.coronavirus_outlined;
        title = 'CORROSIVE MIASMA';
        description = 'Non-Occultist units suffer 30 poison damage at start of turn.';
        break;
      case BattleModifier.none:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 9.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    final phase = widget.tickManager.phase;
    Color color = Colors.grey;
    String label = 'PAUSED';

    if (phase == CombatPhase.ticking) {
      color = const Color(0xFF388E3C);
      label = 'TICKING';
    } else if (phase == CombatPhase.awaitingAction) {
      color = _isPlayerTurnNow ? const Color(0xFFD32F2F) : const Color(0xFFE5A93C);
      label = _isPlayerTurnNow ? 'YOUR TURN' : 'ENEMY TURN';
    } else if (phase == CombatPhase.battleEnded) {
      color = const Color(0xFFE5A93C);
      label = 'CONCLUDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ===========================================================================
  // SQUAD ROWS: VANGUARD & ARCANUM FORMATION
  // ===========================================================================

  Widget _buildSquadSection({
    required String title,
    required List<UnitEntity> units,
    required bool isEnemy,
    required String? activeUnitId,
    String? selectedTargetId,
    ValueChanged<String>? onSelectTarget,
  }) {
    final vanguard = units.where((u) => u.isVanguard).toList();
    final arcanum = units.where((u) => u.isArcanum).toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isEnemy ? const Color(0xFFE57373) : const Color(0xFF81C784),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                isEnemy ? 'Backline ← | → Frontline' : 'Frontline ← | → Backline',
                style: const TextStyle(color: Color(0xFF616161), fontSize: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: arcanum.map((unit) {
                      return _buildUnitCard(
                        unit: unit,
                        isEnemy: isEnemy,
                        isActive: unit.id == activeUnitId,
                        isSelectedTarget: unit.id == selectedTargetId,
                        onTap: () => onSelectTarget?.call(unit.id),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: const Color(0xFF2B2B36),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: vanguard.map((unit) {
                      return _buildUnitCard(
                        unit: unit,
                        isEnemy: isEnemy,
                        isActive: unit.id == activeUnitId,
                        isSelectedTarget: unit.id == selectedTargetId,
                        onTap: () => onSelectTarget?.call(unit.id),
                      );
                    }).toList(),
                  ),
                ),
              ],
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
  }) {
    final bool alive = unit.isAlive;
    final double hpRatio = (unit.currentHp / unit.maxHp).clamp(0.0, 1.0);
    final double tmRatio = (unit.turnMeter / 100.0).clamp(0.0, 1.0);
    final bool ultReady = unit.ultimateCharge >= 100.0 && alive;

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id;
    final double lungeY = isAttacking ? (isEnemy ? 14.0 : -14.0) : 0.0;
    final double shakeX = isDamaged ? 3.5 : 0.0;
    final bool isCriticalHp = hpRatio < 0.25 && alive;

    Color borderColor = const Color(0xFF2B2B36);
    if (isDamaged) {
      borderColor = const Color(0xFFFF1744);
    } else if (isAttacking) {
      borderColor = const Color(0xFFFFD54F);
    } else if (isCriticalHp) {
      borderColor = const Color(0xFFD50000);
    } else if (isActive) {
      borderColor = const Color(0xFFE5A93C);
    } else if (isSelectedTarget) {
      borderColor = const Color(0xFFD32F2F);
    } else if (ultReady) {
      borderColor = const Color(0xFFFFD54F);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isEnemy && alive) {
            onTap?.call();
          } else {
            PedigreeInspectorDialog.show(
              context,
              unit,
              isEnemy: isEnemy,
              relicService: widget.relicService,
            );
          }
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
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: alive ? const Color(0xFF14141A) : const Color(0xFF0E0E12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: borderColor,
                width: (isActive || isSelectedTarget || ultReady || isDamaged || isAttacking) ? 2.0 : 1.0,
              ),
              boxShadow: isDamaged
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : (isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 1.5,
                          )
                        ]
                      : (isCriticalHp
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD50000).withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : (isSelectedTarget
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD32F2F).withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null))),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  // LAYER 1 (Bottom): The Character Portrait Artwork
                  Positioned.fill(
                    child: Image.asset(
                      unit.effectiveAvatarAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B22)),
                    ),
                  ),

                  // LAYER 1.5: Ambient Vignette & Status Tint
                  Positioned.fill(
                    child: Container(
                      color: alive
                          ? (isCriticalHp
                              ? const Color(0xFFB3261E).withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: 0.20))
                          : Colors.black.withValues(alpha: 0.82),
                    ),
                  ),

                  // LAYER 2 (Middle): The Carved Iron Gothic Frame Overlay
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/card_frame.png',
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                  // LAYER 2.5: Red Hit Flash when Damaged
                  if (isDamaged)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFFB3261E).withValues(alpha: 0.55),
                      ),
                    ),

                  // LAYER 2.8: Bottom Readability Gradient
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
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

                  // LAYER 3 (Top): Dynamic Flutter UI
                  Opacity(
                    opacity: alive ? 1.0 : 0.25,
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Header: Archetype Badge (Left) & State Badge (Right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: _archetypeColor(unit.archetype), width: 0.8),
                                ),
                                child: Text(
                                  _archetypeShortCode(unit.archetype),
                                  style: TextStyle(
                                    color: _archetypeColor(unit.archetype),
                                    fontSize: 7.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelectedTarget)
                                Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.gps_fixed, size: 9, color: Color(0xFFEF5350)),
                                )
                              else if (ultReady)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                                  ),
                                  child: const Text(
                                    'ULT',
                                    style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: const Color(0xFFE5A93C), width: 0.8),
                                  ),
                                  child: Text(
                                    'G${unit.generation}',
                                    style: const TextStyle(
                                      color: Color(0xFFE5A93C),
                                      fontSize: 6.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Center: Status Effect Chips (if active)
                          if (unit.activeEffects.isNotEmpty && alive)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: unit.activeEffects.take(3).map((eff) {
                                final Color color = _statusColor(eff.type);
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(color: color, width: 0.6),
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
                            )
                          else
                            const SizedBox.shrink(),

                          // Bottom: Unit Name, HP/TM Numbers & Progress Bars
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                unit.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${unit.currentHp}/${unit.maxHp}',
                                      style: TextStyle(
                                        color: hpRatio > 0.35
                                            ? Colors.white70
                                            : const Color(0xFFEF5350),
                                        fontSize: 6.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                                      ),
                                    ),
                                    Text(
                                      '${unit.turnMeter.toInt()}%',
                                      style: const TextStyle(
                                        color: Color(0xFF64B5F6),
                                        fontSize: 6.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              LinearProgressIndicator(
                                value: hpRatio,
                                minHeight: 3.5,
                                backgroundColor: const Color(0xFF2A2A38),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  hpRatio > 0.4
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              LinearProgressIndicator(
                                value: tmRatio,
                                minHeight: 2.5,
                                backgroundColor: const Color(0xFF2A2A38),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fallen / Defeated overlay
                  if (!alive)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dangerous, size: 14, color: Color(0xFFEF5350)),
                              SizedBox(height: 1),
                              Text(
                                'FALLEN',
                                style: TextStyle(
                                  color: Color(0xFFEF5350),
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
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
                                    : '${skill.damageCoefficient}x DMG'),
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
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildOrderButton(
                          title: order.name,
                          cost: order.focusCost,
                          availableFocus: focus,
                          borderColor: profile.themeColor,
                          onPressed: () => _dispatchOrder(order),
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
    required VoidCallback onPressed,
  }) {
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
    }
  }
}
