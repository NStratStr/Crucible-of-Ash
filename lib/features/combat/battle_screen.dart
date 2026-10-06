import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import 'combat_resolution_service.dart';
import 'enemy_ai_service.dart';
import 'initiative_tick_manager.dart';
import '../generals/general_command_service.dart';

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
  final VoidCallback? onResetEncounter;
  final VoidCallback? onVictory;

  const BattleScreen({
    super.key,
    required this.tickManager,
    required this.combatService,
    required this.commandService,
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
    widget.tickManager.removeListener(_onEngineUpdate);
    widget.commandService.removeListener(_onEngineUpdate);
    super.dispose();
  }

  void _onEngineUpdate() {
    if (!mounted) return;

    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
    if (aliveEnemies.isEmpty) {
      _selectedEnemyId = null;
    } else if (_selectedEnemyId == null || !aliveEnemies.any((u) => u.id == _selectedEnemyId)) {
      _selectedEnemyId = aliveEnemies.first.id;
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
      final text = isCrit ? 'CRIT! -$damage' : (isGlancing ? 'GLANCE -$damage' : '-$damage');
      final color = isCrit ? const Color(0xFFFFD54F) : (isGlancing ? Colors.white60 : const Color(0xFFEF5350));

      final pop = FloatingCombatText(text: text, color: color, isCrit: isCrit);
      setState(() => _floatingPops.add(pop));

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _floatingPops.remove(pop));
      });
    }

    if (heal > 0) {
      final pop = FloatingCombatText(text: '+$heal HP', color: const Color(0xFF81C784));
      setState(() => _floatingPops.add(pop));

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _floatingPops.remove(pop));
      });
    }
  }

  Future<void> _handleAiTurn() async {
    if (_isProcessingAiTurn) return;
    _isProcessingAiTurn = true;

    try {
      final enemy = widget.tickManager.activeUnit;
      if (enemy == null || !_aiService.isEnemyTurn) {
        return;
      }

      setState(() {
        _combatLog = 'HOSTILE ACTION: ${enemy.name} is preparing an assault...';
      });

      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;

      final result = _aiService.executeEnemyTurn(autoResume: true);
      if (result != null && mounted) {
        _triggerDamagePop(
          damage: result.damageDealt,
          isCrit: result.isCritical,
          isGlancing: result.isGlancing,
          heal: result.lifestealRecovered,
        );

        setState(() {
          final glanceText = result.isGlancing ? ' [GLANCING]' : '';
          final critText = result.isCritical ? ' [CRIT!]' : '';
          _combatLog =
              '${result.attacker.name} used ${result.skillName} on ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText!';
          if (result.targetDefeated) {
            _combatLog += ' ${result.target.name} has fallen!';
          }
        });
      }
    } catch (e) {
      debugPrint('Error during AI turn: $e');
    } finally {
      _isProcessingAiTurn = false;
      if (mounted) {
        if (_aiService.isEnemyTurn) {
          // Immediately chain consecutive enemy turns in queue
          Future.microtask(() => _handleAiTurn());
        } else if (_autoBattle && _isPlayerTurnNow) {
          _handleAutoPlayerTurn();
        }
      }
    }
  }

  void _handleAutoPlayerTurn() {
    _autoBattleTimer?.cancel();
    _autoBattleTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _isPlayerTurnNow) {
        final active = widget.tickManager.activeUnit;
        if (active != null) {
          final readySkills = active.resolvedSkills.where((s) => s.isReady).toList();
          final chosen = readySkills.firstWhere((s) => s.cooldownTurns > 0, orElse: () => readySkills.first);
          _executePlayerSkill(chosen);
        }
      }
    });
  }

  void _executePlayerSkill(SkillEntity skill) {
    if (_selectedEnemyId == null) return;
    try {
      final ActionResult result = widget.combatService.executeSkill(
        targetUnitId: _selectedEnemyId!,
        skill: skill,
        autoResumeTickEngine: true,
      );

      widget.commandService.registerCombatDamage(result.damageDealt);

      _triggerDamagePop(
        damage: result.damageDealt,
        isCrit: result.isCritical,
        isGlancing: result.isGlancing,
        heal: result.healAmount > 0 ? result.healAmount : result.lifestealRecovered,
      );

      setState(() {
        final glanceText = result.isGlancing ? ' [GLANCING]' : '';
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    child: Column(
                      children: [
                        // Hostile Squad
                        _buildSquadSection(
                          title: 'HOSTILE HORDE (TAP TO TARGET)',
                          units: widget.tickManager.enemies,
                          isEnemy: true,
                          activeUnitId: activeUnit?.id,
                          selectedTargetId: _selectedEnemyId,
                          onSelectTarget: (id) => setState(() => _selectedEnemyId = id),
                        ),
                        const Divider(color: Color(0xFF2B2B36), thickness: 1.5, height: 14),
                        // Allied Squad
                        _buildSquadSection(
                          title: 'YOUR LINEAGE BRIGADE',
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
              top: 140,
              right: 40,
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
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: pop.color, width: pop.isCrit ? 2 : 1),
                        ),
                        child: Text(
                          pop.text,
                          style: TextStyle(
                            color: pop.color,
                            fontWeight: FontWeight.bold,
                            fontSize: pop.isCrit ? 16 : 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Color(0xFF181820),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_moon_outlined, color: Color(0xFFB3261E), size: 20),
              const SizedBox(width: 6),
              Text(
                widget.commandService.generalName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
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
              alliesWon ? 'VICTORY! All hostile vessels eradicated.' : 'DEFEAT! Your lineage has fallen.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (widget.onResetEncounter != null)
              GestureDetector(
                onTap: widget.onResetEncounter,
                child: const Text('REPLAY', style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 11)),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                isEnemy ? 'Backline ← | → Frontline' : 'Frontline ← | → Backline',
                style: const TextStyle(color: Color(0xFF616161), fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                  height: 50,
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

    Color borderColor = const Color(0xFF2B2B36);
    if (isActive) {
      borderColor = const Color(0xFFE5A93C);
    } else if (isSelectedTarget) {
      borderColor = const Color(0xFFD32F2F);
    }

    return Expanded(
      child: GestureDetector(
        onTap: (isEnemy && alive) ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: alive ? const Color(0xFF1E1E26) : const Color(0xFF131318),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: (isActive || isSelectedTarget) ? 2.2 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.35),
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
                    : null),
          ),
          child: Opacity(
            opacity: alive ? 1.0 : 0.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _archetypeShortCode(unit.archetype),
                      style: TextStyle(
                        color: _archetypeColor(unit.archetype),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isSelectedTarget)
                      const Icon(Icons.gps_fixed, size: 10, color: Color(0xFFD32F2F))
                    else
                      Text(
                        'G${unit.generation}',
                        style: const TextStyle(
                          color: Color(0xFF8E8EA0),
                          fontSize: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
                Icon(
                  _archetypeIcon(unit.archetype),
                  size: 20,
                  color: alive ? Colors.white70 : Colors.white24,
                ),
                Text(
                  unit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: hpRatio,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF2A2A38),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hpRatio > 0.4 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    LinearProgressIndicator(
                      value: tmRatio,
                      minHeight: 3,
                      backgroundColor: const Color(0xFF2A2A38),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                    ),
                  ],
                ),
              ],
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

  Widget _buildBottomControlBar(bool isPlayerTurn, UnitEntity? selectedEnemy, UnitEntity? activeUnit) {
    final focus = widget.commandService.currentFocus;
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
                final bool isReady = skill.isReady;
                final bool canCast = isPlayerTurn && isReady && _selectedEnemyId != null;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: skill.isLimitBurst
                            ? const Color(0xFFE5A93C)
                            : (skill.cooldownTurns > 0 ? const Color(0xFFB3261E) : const Color(0xFF388E3C)),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2A2A38),
                        disabledForegroundColor: Colors.white30,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: canCast ? () => _executePlayerSkill(skill) : null,
                      child: Column(
                        children: [
                          Text(
                            skill.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                          Text(
                            skill.currentCooldown > 0 ? '${skill.currentCooldown} CD' : (skill.isLimitBurst ? 'ULTIMATE' : '${skill.damageCoefficient}x DMG'),
                            style: const TextStyle(fontSize: 8, color: Colors.white70),
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
                const Text('WAITING FOR INITIATIVE...', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text(selectedEnemy != null ? 'TARGET: ${selectedEnemy.name}' : 'NO TARGET', style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10)),
              ],
            ),
          const SizedBox(height: 8),
          // Row 2: General Orders & Focus
          Row(
            children: [
              Row(
                children: [
                  for (int i = 0; i < widget.commandService.maxFocus; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < focus ? const Color(0xFFB3261E) : Colors.transparent,
                        border: Border.all(color: const Color(0xFFB3261E), width: 1.5),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildOrderButton(
                        title: 'SIPHON',
                        cost: 1,
                        availableFocus: focus,
                        onPressed: () => _executeOrder(() {
                          if (_selectedEnemyId == null) return;
                          final res = widget.commandService.executeSiphonVitality(_selectedEnemyId!);
                          setState(() => _combatLog = res.summary);
                        }),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildOrderButton(
                        title: 'WARD',
                        cost: 2,
                        availableFocus: focus,
                        onPressed: () => _executeOrder(() {
                          final res = widget.commandService.executeSanguineWard();
                          setState(() => _combatLog = res.summary);
                        }),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildOrderButton(
                        title: 'EXECUTE',
                        cost: 3,
                        availableFocus: focus,
                        onPressed: () => _executeOrder(() {
                          if (_selectedEnemyId == null) return;
                          final res = widget.commandService.executeFeastOfRuin(_selectedEnemyId!);
                          setState(() => _combatLog = res.summary);
                        }),
                      ),
                    ),
                  ],
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
    required VoidCallback onPressed,
  }) {
    final bool canCast = availableFocus >= cost;

    return OutlinedButton(
      onPressed: canCast ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        side: BorderSide(
          color: canCast ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
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
}
