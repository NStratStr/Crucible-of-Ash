import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

/// Experimental Spatial Combat Simulation Screen (GDD v3.2 Extension)
/// Features:
/// - 3-Row x 5-Column Isometric/Tactical battlefield plane
/// - Multi-Node Footprints (1x1 standard, 1x2 horizontal behemoths like Gorgoroth)
/// - Geometric Skill Vectors & Live Telegraph Shading (T-Cleaves, Crosses, Row Scythes)
/// - Tactical Plinth Triage: Drag-and-drop repositioning during 30% bullet-time
/// - Live Burn Pit Card Cycling & Sunder Mechanics
class SpatialBattleScreen extends StatefulWidget {
  final VoidCallback? onBackToStandardCombat;

  const SpatialBattleScreen({
    super.key,
    this.onBackToStandardCombat,
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> {
  late final SpatialCombatEngine _engine;
  Timer? _loopTimer;
  String? _selectedUnitId;
  SpatialCombatCard? _draggedCard;

  // Visual Combat Feedback State
  String? _lastHandledEventId;
  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _activeSkillName;
  String? _activeSkillCasterName;
  bool _isPlayerSkillBanner = false;
  final Map<String, String> _unitFloatingPops = {};
  final List<Timer> _animTimers = [];

  @override
  void initState() {
    super.initState();
    _engine = SpatialCombatEngine();
    _engine.addListener(_onEngineUpdate);
    _startLoop();
  }

  void _onEngineUpdate() {
    if (!mounted) return;

    // Check if a new combat action event was dispatched
    final event = _engine.activeActionEvent;
    if (event != null && event.id != _lastHandledEventId) {
      _lastHandledEventId = event.id;
      _triggerVisualCombatSequence(event);
    }

    setState(() {});
  }

  void _triggerVisualCombatSequence(SpatialActionEvent event) {
    setState(() {
      _attackingUnitId = event.attackerId;
      _damagedUnitId = event.targetId;
      _activeSkillName = event.skillName;
      _activeSkillCasterName = event.attackerName;
      _isPlayerSkillBanner = event.isPlayerAttacker;
      if (event.isHeal) {
        if (event.skillName == 'Phalanx Intercept') {
          _unitFloatingPops[event.targetId] = '+35 🛡️ ARMOR';
        } else if (event.skillName == 'Stoke the Embers') {
          _unitFloatingPops[event.targetId] = '+2 ⚡ FOCUS';
        } else {
          _unitFloatingPops[event.targetId] = '+HEAL';
        }
      } else {
        _unitFloatingPops[event.targetId] = '-${event.damage} DMG';
        if (event.isCrit) {
          _unitFloatingPops[event.targetId] = '💥 -${event.damage} CRIT!';
        }
        if (event.bleedStacks > 0) {
          _unitFloatingPops[event.targetId] = '-${event.damage} DMG (🩸+${event.bleedStacks})';
        }
      }
    });

    // Reset visual lunge & floating pops after 700ms
    final t1 = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _attackingUnitId = null;
          _damagedUnitId = null;
          _unitFloatingPops.remove(event.targetId);
        });
      }
    });
    _animTimers.add(t1);

    // Dismiss banner after 1300ms
    final t2 = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _activeSkillName = null;
        });
        _engine.clearActiveAction();
      }
    });
    _animTimers.add(t2);
  }

  void _startLoop() {
    _loopTimer?.cancel();
    // 30 Hz loop: ~33.3ms per tick adjusted by speed multiplier
    const baseIntervalMs = 33;
    _loopTimer = Timer.periodic(const Duration(milliseconds: baseIntervalMs), (timer) {
      if (!mounted) return;
      if (_engine.isRunning) {
        _engine.stepTick();
      }
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    for (final t in _animTimers) {
      t.cancel();
    }
    _animTimers.clear();
    _engine.removeListener(_onEngineUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gorgoroth = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss').firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141E),
        elevation: 0,
        leading: widget.onBackToStandardCombat != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD54F)),
                onPressed: widget.onBackToStandardCombat,
                tooltip: 'Return to Standard Arena',
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFB3261E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFB3261E)),
              ),
              child: const Text(
                'EXPERIMENTAL v3.2',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8A80),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'SPATIAL NODE ARENA: THE SUNDER',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Play / Pause Simulation
          IconButton(
            icon: Icon(
              _engine.isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _engine.isRunning ? const Color(0xFFFFD54F) : const Color(0xFF81C784),
              size: 26,
            ),
            tooltip: _engine.isRunning ? 'Pause 30Hz Simulation' : 'Run 30Hz Simulation',
            onPressed: () {
              setState(() {
                _engine.isRunning = !_engine.isRunning;
              });
            },
          ),
          // Step 1 Tick Button for Testing
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white70),
            tooltip: 'Advance 1 Tick',
            onPressed: () {
              _engine.stepTick();
            },
          ),
          // Fast-Forward to Tick 135 (Telegraph moment)
          TextButton(
            onPressed: () {
              while (_engine.currentTick < 135) {
                _engine.stepTick();
              }
            },
            child: const Text('TICK 135', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11)),
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            tooltip: 'Reset Encounter',
            onPressed: () {
              _engine.setupSunderAtAshenGate();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD: Status Banner, Focus Bar & Boss Telemetry
            _buildTopStatusRibbon(gorgoroth),

            // Live Skill Invocation Banner
            if (_activeSkillName != null)
              _buildSkillCutInBanner(),

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Enemy Battlefield Grid (Rows 2 -> 1 -> 0)
                        _buildSquadGrid(isPlayerSquad: false),

                        // Central Clash Line Divider
                        _buildClashLineDivider(),

                        // Player Battlefield Grid (Rows 0 -> 1 -> 2)
                        _buildSquadGrid(isPlayerSquad: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tactical Card Hand & Burn Pit
            _buildTacticalHandDock(),

            // Live 30 Hz Combat Event Log
            _buildCombatLogConsole(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusRibbon(CombatUnitState? boss) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(bottom: BorderSide(color: Color(0xFF282838), width: 1.5)),
      ),
      child: Row(
        children: [
          // Commander Focus Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 16),
                const SizedBox(width: 4),
                Text(
                  'FOCUS: ${_engine.focus}/${_engine.maxFocus}',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Simulation Speed & Bullet-Time Indicator
          GestureDetector(
            onTap: () {
              _engine.setBulletTime(!_engine.isBulletTime);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _engine.isBulletTime ? const Color(0xFFFF9100).withValues(alpha: 0.3) : const Color(0xFF282836),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _engine.isBulletTime ? Icons.slow_motion_video : Icons.speed,
                    color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _engine.isBulletTime ? '30% BULLET-TIME' : '1.0X REALTIME',
                    style: TextStyle(
                      color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Boss Telegraph Warning
          if (boss != null && boss.pendingIntent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFF1744)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'EXECUTES IN ${boss.pendingIntent!.triggerTick - _engine.currentTick} TICKS',
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClashLineDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '═══════════ NEUTRAL CLASH PLANE ═══════════',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a 3-Row (0=Front, 1=Mid, 2=Back) x 5-Column Grid
  Widget _buildSquadGrid({required bool isPlayerSquad}) {
    // For Enemy: Render Row 2 (Back) -> Row 1 (Mid) -> Row 0 (Front closest to clash line)
    // For Player: Render Row 0 (Front closest to clash line) -> Row 1 (Mid) -> Row 2 (Back)
    final rowsOrder = isPlayerSquad ? [0, 1, 2] : [2, 1, 0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rowsOrder.map((rowIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (colIdx) {
              return _buildGridCell(colIdx, rowIdx, isPlayerSquad: isPlayerSquad);
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridCell(int col, int row, {required bool isPlayerSquad}) {
    final squad = isPlayerSquad ? _engine.playerUnits : _engine.enemyUnits;
    final occupant = squad.where((u) => u.isAlive && u.occupies(col, row)).firstOrNull;

    // Check if this node is inside an enemy telegraph intent
    final boss = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull;
    final isTelegraphed = isPlayerSquad &&
        boss != null &&
        boss.pendingIntent != null &&
        boss.pendingIntent!.targetNodes.any((n) => n.column == col && n.row == row);

    // Multi-node behemoth anchor check: Gorgoroth occupies 2 tiles; render model only on anchor node (col 1, row 0)
    final bool isAnchorCell = occupant == null ||
        (occupant.occupiedNodes.first.column == col && occupant.occupiedNodes.first.row == row);
    final bool isBossSecondaryNode = occupant != null && !isAnchorCell;

    // Movement stat range validation for selected unit
    final selectedUnit = _selectedUnitId != null
        ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull
        : null;
    final bool isReachable = isPlayerSquad &&
        selectedUnit != null &&
        occupant == null &&
        selectedUnit.canMoveTo(col, row);

    final bool isSelected = _selectedUnitId != null && occupant?.id == _selectedUnitId;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.startsWith('card:')) {
          final cardId = data.replaceFirst('card:', '');
          final card = _engine.hand.where((c) => c.id == cardId).firstOrNull;
          if (card == null) return false;
          // Buff cards target living allies
          if (card.id == 'phalanx_intercept') {
            return isPlayerSquad && occupant != null;
          }
          // Stoke the embers can be dropped anywhere
          if (card.id == 'stoke_the_embers') return true;
          // Offensive spells target living enemies
          return !isPlayerSquad && occupant != null;
        } else {
          // Unit movement triage: only allow if in player squad, unoccupied, and within unit moveRange
          final unitId = data.replaceFirst('unit:', '');
          final unit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
          if (unit == null) return false;
          return isPlayerSquad && occupant == null && unit.canMoveTo(col, row);
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.startsWith('card:')) {
          final cardId = data.replaceFirst('card:', '');
          _engine.castCard(cardId, targetUnit: occupant, targetCol: col, targetRow: row);
          setState(() => _draggedCard = null);
        } else {
          final unitId = data.replaceFirst('unit:', '');
          _engine.movePlayerUnit(unitId, col, row);
          setState(() => _selectedUnitId = null);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool isDropCandidate = candidateData.isNotEmpty;

        return Container(
          width: 58,
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isTelegraphed
                  ? [
                      const Color(0xFF4A1016),
                      const Color(0xFF2B0A0E),
                    ]
                  : (isDropCandidate
                      ? [
                          const Color(0xFF004D40),
                          const Color(0xFF00251A),
                        ]
                      : (isReachable
                          ? [
                              const Color(0xFF00382E),
                              const Color(0xFF001F19),
                            ]
                          : (isBossSecondaryNode
                              ? [
                                  const Color(0xFF26191C),
                                  const Color(0xFF1B0E11),
                                ]
                              : (isPlayerSquad
                                  ? [
                                      const Color(0xFF1A1F2C),
                                      const Color(0xFF10131B),
                                    ]
                                  : [
                                      const Color(0xFF26191C),
                                      const Color(0xFF150D0F),
                                    ])))),
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isTelegraphed
                  ? const Color(0xFFFF1744)
                  : (isDropCandidate
                      ? const Color(0xFF00E5FF)
                      : (isReachable
                          ? const Color(0xFF00E676)
                          : (isSelected
                              ? const Color(0xFFFFD54F)
                              : (isBossSecondaryNode
                                  ? const Color(0xFF795548).withValues(alpha: 0.6)
                                  : (isPlayerSquad ? const Color(0xFF38455E) : const Color(0xFF58363F)))))),
              width: isTelegraphed || isSelected || isDropCandidate || isReachable ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isTelegraphed
                    ? const Color(0xFFFF1744).withValues(alpha: 0.45)
                    : (isReachable
                        ? const Color(0xFF00E676).withValues(alpha: 0.35)
                        : (isDropCandidate
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                            : Colors.black54)),
                blurRadius: isTelegraphed || isDropCandidate || isReachable ? 8 : 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Coordinate Watermark & Tap Handler for Empty Cells
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (isPlayerSquad && occupant == null && selectedUnit != null) {
                      if (selectedUnit.canMoveTo(col, row)) {
                        _engine.movePlayerUnit(selectedUnit.id, col, row);
                        setState(() => _selectedUnitId = null);
                      } else {
                        setState(() {
                          _engine.lastBannerMessage =
                              '⚠️ ${selectedUnit.name} can only move ${selectedUnit.moveRange} tile(s)!';
                        });
                      }
                    }
                  },
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, left: 3),
                      child: Text(
                        'C${col + 1} R$row',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: isTelegraphed
                              ? const Color(0xFFFF8A80)
                              : (isReachable ? const Color(0xFF00E676) : Colors.white24),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Reachable Movement Indicator
              if (isReachable)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_run, color: Color(0xFF00E676), size: 14),
                      Text(
                        'MOVE',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00E676).withValues(alpha: 0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // Secondary Behemoth Footprint Marker (Col 3 Frontline extension of Gorgoroth)
              if (isBossSecondaryNode)
                Center(
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    size: 16,
                  ),
                ),

              // Occupant Miniature (Rendered only on Anchor node)
              if (occupant != null && isAnchorCell)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isPlayerSquad) {
                        setState(() {
                          _selectedUnitId = (_selectedUnitId == occupant.id) ? null : occupant.id;
                        });
                      } else {
                        // Cast active dragged card or target enemy
                        if (_draggedCard != null) {
                          _engine.castCard(_draggedCard!.id, targetUnit: occupant);
                          setState(() => _draggedCard = null);
                        }
                      }
                    },
                    child: isPlayerSquad
                        ? LongPressDraggable<String>(
                            data: 'unit:${occupant.id}',
                            maxSimultaneousDrags: 1,
                            onDragStarted: () {
                              setState(() => _selectedUnitId = occupant.id);
                              _engine.setBulletTime(true);
                            },
                            onDragEnd: (_) {
                              _engine.setBulletTime(false);
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: _buildUnitMiniatureWidget(occupant, isDragging: true),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildUnitMiniatureWidget(occupant),
                            ),
                            child: _buildUnitMiniatureWidget(occupant, isSelected: isSelected),
                          )
                        : _buildUnitMiniatureWidget(occupant),
                  ),
                ),

              // Threat Marker for Cleave telegraph
              if (isTelegraphed)
                const Positioned(
                  bottom: 2,
                  right: 3,
                  child: Icon(Icons.close, color: Color(0xFFFF5252), size: 14),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillCutInBanner() {
    final Color themeColor = _isPlayerSkillBanner ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlayerSkillBanner ? Icons.auto_awesome : Icons.warning_rounded,
            color: themeColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _activeSkillCasterName?.toUpperCase() ?? 'CONSTRUCT',
            style: TextStyle(
              color: themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          const Text('•', style: TextStyle(color: Colors.white38)),
          const SizedBox(width: 6),
          Text(
            _activeSkillName?.toUpperCase() ?? 'ATTACK',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitMiniatureWidget(CombatUnitState unit, {bool isDragging = false, bool isSelected = false}) {
    final bool isBoss = unit.footprint == UnitFootprint.horizontal1x2;
    final double hpRatio = unit.maxHp > 0 ? (unit.hp / unit.maxHp).clamp(0.0, 1.0) : 0.0;
    final double apRatio = (unit.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
    final Color factionColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id;
    final String? floatingPop = _unitFloatingPops[unit.id];

    // Lunge forward across clash line during attack
    final double lungeY = isAttacking ? (unit.isPlayer ? -14.0 : 14.0) : 0.0;
    final double hitShakeX = isDamaged ? 4.0 : 0.0;

    final double baseWidth = isBoss ? 114 : 48;
    final double baseHeight = isBoss ? 15 : 12;
    final double modelWidth = isBoss ? 116 : 64;
    final double modelHeight = isBoss ? 120 : 80;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(hitShakeX, lungeY, 0),
      child: SizedBox(
        width: isBoss ? 118 : 58,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Tabletop 3D Plinth Base (Elliptical Ground Pedestal)
            Positioned(
              bottom: 8,
              child: Container(
                width: baseWidth,
                height: baseHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(baseWidth / 2, baseHeight / 2)),
                  gradient: RadialGradient(
                    colors: [
                      factionColor.withValues(alpha: isSelected || isAttacking ? 0.85 : 0.40),
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: isSelected || isAttacking ? factionColor : factionColor.withValues(alpha: 0.6),
                    width: isSelected || isAttacking ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: factionColor.withValues(alpha: isSelected || isAttacking ? 0.7 : 0.25),
                      blurRadius: isSelected || isAttacking ? 10 : 4,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Character Model Miniature Cutout (Rises proudly above plinth!)
            Positioned(
              bottom: 12,
              child: SizedBox(
                width: modelWidth,
                height: modelHeight,
                child: ColorFiltered(
                  colorFilter: isDamaged
                      ? const ColorFilter.mode(Color(0xFFFF1744), BlendMode.srcATop)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.asset(
                    unit.assetPath,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      unit.isPlayer ? Icons.shield : Icons.dangerous,
                      color: factionColor,
                      size: isBoss ? 40 : 28,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Name, Badges & Slag Carapace Overlays
            Positioned(
              top: isBoss ? -96 : -58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unit.isSlagCarapaceActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221115),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                      ),
                      child: const Text(
                        'CARAPACE -50%',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (unit.bleedStacks > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '🩸 ${unit.bleedStacks}x BLEED',
                        style: const TextStyle(fontSize: 6.0, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (unit.isDisplacementImmune)
                        const Icon(Icons.anchor, size: 9, color: Color(0xFFFFD54F)),
                      const SizedBox(width: 1),
                      Text(
                        unit.name,
                        style: TextStyle(
                          fontSize: isBoss ? 8.5 : 7.5,
                          fontWeight: FontWeight.bold,
                          color: isAttacking ? const Color(0xFFFFD54F) : Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Floating Damage / Effect Pop Text
            if (floatingPop != null)
              Positioned(
                top: isBoss ? -120 : -78,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: floatingPop.contains('ARMOR')
                          ? const Color(0xFF00E5FF)
                          : (floatingPop.contains('FOCUS') ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    floatingPop,
                    style: TextStyle(
                      color: floatingPop.contains('ARMOR')
                          ? const Color(0xFF00E5FF)
                          : (floatingPop.contains('FOCUS') ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // 5. Bottom Tactical HUD: HP (with white shield overlay) & AP Turn Meters
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: isBoss ? 105 : 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HP & Armor Bar
                    Container(
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: Colors.white24, width: 0.4),
                      ),
                      child: Stack(
                        children: [
                          // Base HP
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: unit.isPlayer ? const Color(0xFF81C784) : const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                          // Proportional White/Cyan Shield Overlay
                          if (unit.armor > 0)
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (unit.armor / max(1, unit.maxHp)).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(1.5),
                                  border: Border.all(color: const Color(0xFF00E5FF), width: 0.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    // AP Turn Meter
                    Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: apRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalHandDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF14141E),
        border: Border(top: BorderSide(color: Color(0xFF282838), width: 1.5)),
      ),
      child: Row(
        children: [
          // Dynamic Burn Pit: Drag or Tap card here to exhaust for +1 Focus
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data.startsWith('card:'),
            onAcceptWithDetails: (details) {
              final cardId = details.data.replaceFirst('card:', '');
              _engine.burnCard(cardId);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return GestureDetector(
                onTap: () {
                  if (_engine.hand.isNotEmpty) {
                    _engine.burnCard(_engine.hand.first.id);
                  }
                },
                child: Container(
                  width: 72,
                  height: 78,
                  decoration: BoxDecoration(
                    color: isHovered ? const Color(0xFFFF5252).withValues(alpha: 0.35) : const Color(0xFF221115),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHovered ? const Color(0xFFFF5252) : const Color(0xFFB3261E),
                      width: isHovered ? 2.0 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: isHovered ? const Color(0xFFFF5252) : const Color(0xFFB3261E),
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BURN PIT',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8A80),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Text(
                        '+1 FOCUS',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFFFFD54F)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Cards in Hand
          Expanded(
            child: SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _engine.hand.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final card = _engine.hand[idx];
                  final canAfford = _engine.focus >= card.focusCost;

                  return Draggable<String>(
                    data: 'card:${card.id}',
                    onDragStarted: () {
                      setState(() => _draggedCard = card);
                      _engine.setBulletTime(true);
                    },
                    onDragEnd: (_) {
                      setState(() => _draggedCard = null);
                      _engine.setBulletTime(false);
                    },
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildCardTile(card, canAfford, isFeedback: true),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // One-tap cast on appropriate target
                        if (!canAfford) {
                          setState(() {
                            _engine.lastBannerMessage =
                                '⚠️ NEED ${card.focusCost} FOCUS (HAVE ${_engine.focus})';
                          });
                          return;
                        }
                        CombatUnitState? target;
                        if (card.id == 'phalanx_intercept') {
                          target = _selectedUnitId != null
                              ? _engine.playerUnits
                                  .where((u) => u.id == _selectedUnitId && u.isAlive)
                                  .firstOrNull
                              : null;
                        }
                        _engine.castCard(card.id, targetUnit: target);
                      },
                      child: _buildCardTile(card, canAfford),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(SpatialCombatCard card, bool canAfford, {bool isFeedback = false}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: canAfford ? const Color(0xFF1E2235) : const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: canAfford ? const Color(0xFF00E5FF) : Colors.white24,
          width: 1.2,
        ),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.name,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: canAfford ? Colors.white : Colors.white38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${card.focusCost}F',
                  style: const TextStyle(fontSize: 8, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              card.description,
              style: const TextStyle(fontSize: 7.5, color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatLogConsole() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF0A0A10),
      child: ListView.builder(
        itemCount: _engine.combatLogs.length,
        itemBuilder: (context, idx) {
          final log = _engine.combatLogs[idx];
          final isCrit = log.contains('CRITICAL') || log.contains('SHATTERS');
          final isTelegraph = log.contains('TELEGRAPH') || log.contains('⚠️');

          return Text(
            log,
            style: TextStyle(
              fontSize: 8.5,
              color: isCrit
                  ? const Color(0xFFFFD54F)
                  : (isTelegraph ? const Color(0xFFFF5252) : Colors.white60),
              fontFamily: 'monospace',
            ),
          );
        },
      ),
    );
  }
}
