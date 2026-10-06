import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';
import 'combat_resolution_service.dart';
import 'initiative_tick_manager.dart';
import '../generals/general_command_service.dart';

class BattleScreen extends StatefulWidget {
  final InitiativeTickManager tickManager;
  final CombatResolutionService combatService;
  final GeneralCommandService commandService;

  const BattleScreen({
    super.key,
    required this.tickManager,
    required this.combatService,
    required this.commandService,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  String? _selectedEnemyId;
  String _combatLog = 'Prepare for engagement. The Crucible awaits.';

  @override
  void initState() {
    super.initState();
    widget.tickManager.addListener(_onEngineUpdate);
    widget.commandService.addListener(_onEngineUpdate);

    // Auto-select the first alive enemy if available
    final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive);
    if (aliveEnemies.isNotEmpty) {
      _selectedEnemyId = aliveEnemies.first.id;
    }

    // Start tick engine
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.tickManager.start();
    });
  }

  @override
  void dispose() {
    widget.tickManager.removeListener(_onEngineUpdate);
    widget.commandService.removeListener(_onEngineUpdate);
    super.dispose();
  }

  void _onEngineUpdate() {
    if (!mounted) return;
    setState(() {
      // Validate targeted enemy
      final aliveEnemies = widget.tickManager.enemies.where((u) => u.isAlive).toList();
      if (aliveEnemies.isEmpty) {
        _selectedEnemyId = null;
      } else if (_selectedEnemyId == null || !aliveEnemies.any((u) => u.id == _selectedEnemyId)) {
        _selectedEnemyId = aliveEnemies.first.id;
      }
    });
  }

  void _executePlayerAttack() {
    if (_selectedEnemyId == null) return;
    try {
      final ActionResult result = widget.combatService.executeBasicAttack(
        targetUnitId: _selectedEnemyId!,
        autoResumeTickEngine: true,
      );

      // Register damage to fuel General Focus
      widget.commandService.registerCombatDamage(result.damageDealt);

      setState(() {
        final glanceText = result.isGlancing ? ' [GLANCING]' : '';
        final critText = result.isCritical ? ' [CRIT!]' : '';
        _combatLog =
            '${result.attacker.name} struck ${result.target.name} for ${result.damageDealt} DMG$critText$glanceText.';
        if (result.targetDefeated) {
          _combatLog += ' ${result.target.name} was eradicated!';
        }
      });
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
    final isPlayerTurn = activeUnit != null &&
        widget.tickManager.phase == CombatPhase.awaitingAction &&
        widget.tickManager.allies.any((u) => u.id == activeUnit.id);

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopStatusHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Hostile Horde (Top)
                    _buildSquadSection(
                      title: 'HOSTILE HORDE',
                      units: widget.tickManager.enemies,
                      isEnemy: true,
                      activeUnitId: activeUnit?.id,
                      selectedTargetId: _selectedEnemyId,
                      onSelectTarget: (id) => setState(() => _selectedEnemyId = id),
                    ),
                    const Divider(color: Color(0xFF2B2B36), thickness: 1.5, height: 20),
                    // Allied Brigade (Bottom)
                    _buildSquadSection(
                      title: 'YOUR LINEAGE',
                      units: widget.tickManager.allies,
                      isEnemy: false,
                      activeUnitId: activeUnit?.id,
                    ),
                  ],
                ),
              ),
            ),
            _buildCombatLogBanner(),
            _buildBottomControlBar(isPlayerTurn),
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: const BoxDecoration(
        color: Color(0xFF181820),
        border: Border(bottom: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_moon_outlined, color: Color(0xFFB3261E), size: 22),
              const SizedBox(width: 8),
              Text(
                widget.commandService.generalName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'TICK ${widget.tickManager.tickCount}',
                style: const TextStyle(
                  color: Color(0xFF8E8EA0),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 14),
              _buildPhaseIndicator(),
            ],
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
      color = const Color(0xFFD32F2F);
      label = 'COMMAND';
    } else if (phase == CombatPhase.battleEnded) {
      color = const Color(0xFFE5A93C);
      label = 'CONCLUDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF717182),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                // Arcanum (Backline - 2 Units)
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
                // Vanguard (Frontline - 3 Units)
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
      borderColor = const Color(0xFFE5A93C); // Active turn gold glow
    } else if (isSelectedTarget) {
      borderColor = const Color(0xFFD32F2F); // Red targeted crosshair
    }

    return Expanded(
      child: GestureDetector(
        onTap: (isEnemy && alive) ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(6),
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
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Opacity(
            opacity: alive ? 1.0 : 0.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag: Affinity & Gen
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _archetypeShortCode(unit.archetype),
                      style: TextStyle(
                        color: _archetypeColor(unit.archetype),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'G${unit.generation}',
                      style: const TextStyle(
                        color: Color(0xFF8E8EA0),
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                // Card Center Icon
                Icon(
                  _archetypeIcon(unit.archetype),
                  size: 24,
                  color: alive ? Colors.white70 : Colors.white24,
                ),
                // Unit Name
                Text(
                  unit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // HP and Turn-Meter Bars
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
  // LOG BANNER & GENERAL COMMAND HUD
  // ===========================================================================

  Widget _buildCombatLogBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF14141B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _combatLog,
        style: const TextStyle(
          color: Color(0xFFC5C5D2),
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildBottomControlBar(bool isPlayerTurn) {
    final focus = widget.commandService.currentFocus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF181820),
        border: Border(top: BorderSide(color: Color(0xFF2B2B36), width: 1.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'FOCUS:',
                    style: TextStyle(
                      color: Color(0xFF8E8EA0),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (int i = 0; i < widget.commandService.maxFocus; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < focus ? const Color(0xFFB3261E) : Colors.transparent,
                        border: Border.all(
                          color: const Color(0xFFB3261E),
                          width: 1.5,
                        ),
                        boxShadow: i < focus
                            ? [
                                const BoxShadow(
                                  color: Color(0xFFB3261E),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: (isPlayerTurn && _selectedEnemyId != null) ? _executePlayerAttack : null,
                icon: const Icon(Icons.flash_on, size: 16),
                label: const Text('STRIKE TARGET', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2A2A38),
                  disabledForegroundColor: Colors.white30,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
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
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(
            '$cost FOCUS',
            style: TextStyle(
              fontSize: 9,
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
