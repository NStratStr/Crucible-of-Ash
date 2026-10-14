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
    _engine.isActionPauseEnabled = true;
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

    // Reset visual lunge & floating pops after 1100ms
    final t1 = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _attackingUnitId = null;
          _damagedUnitId = null;
          _unitFloatingPops.remove(event.targetId);
        });
      }
    });
    _animTimers.add(t1);

    // Dismiss banner & resume combat ticks after 1600ms
    final t2 = Timer(const Duration(milliseconds: 1600), () {
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
    // Paced loop: ~50ms per tick (~20 ticks/sec default), slowed by simulationSpeed when active
    const baseIntervalMs = 50;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Atmospheric Volcanic Chasm Arena Backdrop
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/volcanic_chasm_battlefield.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF0D0D14),
                      ),
                    ),
                  ),

                  // Subtle Atmospheric Vignette Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF06070B).withValues(alpha: 0.35),
                            const Color(0xFF030406).withValues(alpha: 0.70),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Interactive 2.5D Battlefield Arena Plane (Unified Isometric Board)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth >= 700;
                      // Increased grid size so tiles and units fill the scene properly
                      final double tileWidth = isDesktop ? 128.0 : 84.0;
                      final double tileHeight = isDesktop ? 64.0 : 42.0;

                      return Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 24.0 : 8.0,
                                vertical: isDesktop ? 12.0 : 6.0,
                              ),
                              child: _buildUnifiedIsometricBattlefield(
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
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



  /// Builds the unified 2.5D Isometric Battlefield Board (Image 2 style)
  /// An authentic continuous angled terrain plane where Enemy Rows and Player Rows
  /// form a single unbroken isometric grid meeting seamlessly along the neutral clash line.
  Widget _buildUnifiedIsometricBattlefield({
    required double tileWidth,
    required double tileHeight,
  }) {
    // Continuous coordinate system:
    // Global Row Index gRow (0..6):
    // gRow 0 = Enemy Backline (Enemy Row 2)
    // gRow 1 = Enemy Midline (Enemy Row 1)
    // gRow 2 = Enemy Frontline (Enemy Row 0)
    // gRow 3 = Neutral Clash Line / Buffer
    // gRow 4 = Player Frontline (Player Row 0)
    // gRow 5 = Player Midline (Player Row 1)
    // gRow 6 = Player Backline (Player Row 2)
    const int numCols = 5;
    const int numGRows = 7;

    // Board bounding dimensions in isometric space:
    // Isometric formula:
    // px = (col - gRow) * (tileWidth / 2)
    // py = (col + gRow) * (tileHeight / 2)
    // Range of (col - gRow): min = 0 - 6 = -6, max = 4 - 0 = +4 -> spread 10 half-widths.
    // Center offset ensures all coordinates are >= 0 inside the canvas.
    final double originX = (numGRows - 1) * (tileWidth * 0.5);
    final double originY = 0.0;
    final double boardTotalWidth = originX + (numCols - 1) * (tileWidth * 0.5) + tileWidth;
    final double boardTotalHeight = (numCols - 1 + numGRows - 1) * (tileHeight * 0.5) + tileHeight + 20.0;

    // Collect all cells to render sorted by isometric depth (gRow + col)
    // This guarantees back-to-front painter order so foreground units/tiles draw over background.
    final List<_IsometricCellData> allCells = [];

    for (int gRow = 0; gRow < numGRows; gRow++) {
      for (int col = 0; col < numCols; col++) {
        final bool isClashLine = (gRow == 3);
        final bool isPlayerSquad = (gRow > 3);
        final int localRow = isPlayerSquad ? (gRow - 4) : (2 - gRow);

        allCells.add(_IsometricCellData(
          gRow: gRow,
          col: col,
          localRow: localRow,
          isClashLine: isClashLine,
          isPlayerSquad: isPlayerSquad,
          depth: gRow + col,
          screenX: originX + (col - gRow) * (tileWidth * 0.5),
          screenY: originY + (col + gRow) * (tileHeight * 0.5),
        ));
      }
    }

    allCells.sort((a, b) => a.depth.compareTo(b.depth));

    return SizedBox(
      width: boardTotalWidth,
      height: boardTotalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: allCells.map((cell) {
          if (cell.isClashLine) {
            return Positioned(
              left: cell.screenX,
              top: cell.screenY,
              width: tileWidth,
              height: tileHeight,
              child: _buildClashLineTile(cell.col, tileWidth: tileWidth, tileHeight: tileHeight),
            );
          }

          return Positioned(
            left: cell.screenX,
            top: cell.screenY,
            width: tileWidth,
            height: tileHeight,
            child: _buildIsometricGridCell(
              cell.col,
              cell.localRow,
              isPlayerSquad: cell.isPlayerSquad,
              tileWidth: tileWidth,
              tileHeight: tileHeight,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClashLineTile(int col, {required double tileWidth, required double tileHeight}) {
    return CustomPaint(
      painter: IsometricDiamondTilePainter(
        fillColor: const Color(0xFFFFD54F).withValues(alpha: 0.05),
        borderColor: const Color(0xFFFFD54F).withValues(alpha: 0.35),
        borderWidth: 1.0,
        hasGlow: false,
      ),
      child: Center(
        child: Icon(
          Icons.swap_vert_rounded,
          color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
          size: 16,
        ),
      ),
    );
  }

  Widget _buildIsometricGridCell(
    int col,
    int row, {
    required bool isPlayerSquad,
    required double tileWidth,
    required double tileHeight,
  }) {
    const double colGap = 0.0;
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

        final Color fillColor = isTelegraphed
            ? const Color(0xFFFF1744).withValues(alpha: 0.35)
            : (isDropCandidate
                ? const Color(0xFF00E5FF).withValues(alpha: 0.28)
                : (isReachable
                    ? const Color(0xFF00E676).withValues(alpha: 0.25)
                    : (isBossSecondaryNode
                        ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                        : (isPlayerSquad
                            ? const Color(0xFF304FFE).withValues(alpha: 0.12)
                            : const Color(0xFFFF1744).withValues(alpha: 0.10)))));

        final Color borderColor = isTelegraphed
            ? const Color(0xFFFF1744).withValues(alpha: 0.90)
            : (isDropCandidate
                ? const Color(0xFF00E5FF).withValues(alpha: 0.85)
                : (isReachable
                    ? const Color(0xFF00E676).withValues(alpha: 0.85)
                    : (isSelected
                        ? const Color(0xFFFFD54F)
                        : (isBossSecondaryNode
                            ? const Color(0xFFFF8A80).withValues(alpha: 0.35)
                            : (isPlayerSquad
                                ? const Color(0xFF82B1FF).withValues(alpha: 0.38)
                                : const Color(0xFFFF8A80).withValues(alpha: 0.32))))));

        final bool hasGlow = isTelegraphed || isSelected || isDropCandidate || isReachable;
        final Color glowColor = isTelegraphed
            ? const Color(0xFFFF1744)
            : (isReachable
                ? const Color(0xFF00E676)
                : (isDropCandidate ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F)));

        // Behemoth boss (1x2 horizontal footprint)
        final bool isBossAnchor = occupant != null && isAnchorCell && occupant.footprint == UnitFootprint.horizontal1x2;
        final double cellSpanWidth = isBossAnchor ? (2 * tileWidth + colGap) : tileWidth;

        return Container(
          width: cellSpanWidth,
          height: tileHeight,
          margin: EdgeInsets.symmetric(horizontal: colGap / 2),
          child: CustomPaint(
            painter: isBossAnchor
                ? IsometricDoubleDiamondPainter(
                    fillColor: fillColor,
                    borderColor: borderColor,
                    borderWidth: hasGlow ? 2.2 : 1.5,
                    hasGlow: hasGlow,
                    glowColor: glowColor,
                  )
                : IsometricDiamondTilePainter(
                    fillColor: fillColor,
                    borderColor: borderColor,
                    borderWidth: hasGlow ? 2.0 : 1.2,
                    hasGlow: hasGlow,
                    glowColor: glowColor,
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
                        '${col + 1},$row',
                        style: TextStyle(
                          fontSize: 8.0,
                          color: isTelegraphed
                              ? const Color(0xFFFF8A80)
                              : (isReachable ? const Color(0xFF00E676) : Colors.white12),
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
                              child: _buildUnitMiniatureWidget(
                                occupant,
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                                colGap: colGap,
                                isDragging: true,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildUnitMiniatureWidget(
                                occupant,
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                                colGap: colGap,
                              ),
                            ),
                            child: _buildUnitMiniatureWidget(
                              occupant,
                              tileWidth: tileWidth,
                              tileHeight: tileHeight,
                              colGap: colGap,
                              isSelected: isSelected,
                            ),
                          )
                        : _buildUnitMiniatureWidget(
                            occupant,
                            tileWidth: tileWidth,
                            tileHeight: tileHeight,
                            colGap: colGap,
                          ),
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

  Widget _buildUnitMiniatureWidget(
    CombatUnitState unit, {
    required double tileWidth,
    required double tileHeight,
    required double colGap,
    bool isDragging = false,
    bool isSelected = false,
  }) {
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

    final double bossSpanWidth = 2 * tileWidth + colGap;
    final double baseWidth = isBoss ? bossSpanWidth - 16 : tileWidth - 12;
    final double baseHeight = isBoss ? 20 : 14;
    // Units scale dynamically with tile size for commanding visual presence
    final double modelWidth = isBoss ? bossSpanWidth * 0.95 : tileWidth * 0.95;
    final double modelHeight = isBoss
        ? (tileHeight * 2.6).clamp(110.0, 180.0)
        : (tileHeight * 2.2).clamp(80.0, 140.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(hitShakeX, lungeY, 0),
      child: SizedBox(
        width: isBoss ? bossSpanWidth : tileWidth,
        height: tileHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Tabletop 2.5D Contact Drop Shadow & Soft Ground Glow
            Positioned(
              bottom: 4,
              child: Container(
                width: baseWidth,
                height: baseHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(baseWidth / 2, baseHeight / 2)),
                  gradient: RadialGradient(
                    colors: [
                      factionColor.withValues(alpha: isSelected || isAttacking ? 0.75 : 0.35),
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: factionColor.withValues(alpha: isSelected || isAttacking ? 0.6 : 0.2),
                      blurRadius: isSelected || isAttacking ? 8 : 4,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Character Model Miniature Cutout (Stands proudly upright on diamond plinth)
            Positioned(
              bottom: 6,
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
                      size: isBoss ? 48 : 36,
                    ),
                  ),
                ),
              ),
            ),

            // 3. Status Badges & Selected Unit Indicator
            Positioned(
              top: isBoss ? -22 : -16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unit.isSlagCarapaceActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221115),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.6),
                      ),
                      child: const Text(
                        'CARAPACE',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  if (unit.bleedStacks > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '🩸${unit.bleedStacks}',
                        style: const TextStyle(fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  // Only show name when unit is selected to keep screen uncluttered
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                      ),
                      child: Text(
                        unit.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD54F),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),

            // 4. Floating Damage / Effect Pop Text
            if (floatingPop != null)
              Positioned(
                top: isBoss ? -34 : -26,
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

            // 5. Sleek Compact Tactical Health & AP Meters
            Positioned(
              bottom: 2,
              child: SizedBox(
                width: isBoss ? 56.0 : 36.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sleek 2.5px HP & Armor Bar
                    Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1.5),
                        border: Border.all(color: Colors.white12, width: 0.3),
                      ),
                      child: Stack(
                        children: [
                          // Base HP
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: unit.isPlayer ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(1),
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
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(1),
                                  border: Border.all(color: const Color(0xFF00E5FF), width: 0.4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    // AP Turn Meter (1.5px)
                    Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: apRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(0.5),
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

/// 2.5D Isometric Diamond Tile Plinth Painter
/// Inspired by the tactical tabletop grid presentation in The Banner Saga & Dragonheir: Silent Gods.
class IsometricDiamondTilePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hasGlow;
  final Color glowColor;

  const IsometricDiamondTilePainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1.2,
    this.hasGlow = false,
    this.glowColor = const Color(0xFFFF1744),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Main 2:1 Isometric Diamond Face
    final diamondPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.5)
      ..close();

    // Glow effect (telegraphed zones, selected, or reachable moves)
    if (hasGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawPath(diamondPath, glowPaint);
    }

    // Translucent face fill preserving underlying scene
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, fillPaint);

    // Inner bevel highlight on upper edges
    final innerBevelPath = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5);
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(innerBevelPath, bevelPaint);

    // Diamond Perimeter Border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(diamondPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant IsometricDiamondTilePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasGlow != hasGlow ||
        oldDelegate.glowColor != glowColor;
  }
}

/// 2.5D Multi-Node Behemoth Double-Diamond Ground Plinth Painter
/// Draws a continuous combined perimeter footprint across Col 1 & Col 2 (1x2 unit)
class IsometricDoubleDiamondPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hasGlow;
  final Color glowColor;

  const IsometricDoubleDiamondPainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1.5,
    this.hasGlow = false,
    this.glowColor = const Color(0xFFFF1744),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Contact drop shadow below double-diamond footprint
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    final shadowPath = Path()
      ..moveTo(w * 0.25, h * 0.08)
      ..lineTo(w * 0.75, h * 0.08)
      ..lineTo(w * 0.98, h * 0.54)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(w * 0.02, h * 0.54)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    if (hasGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(shadowPath, glowPaint);
    }

    // Combined 1x2 hexagonal / double-diamond perimeter footprint
    final footPath = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.85),
          fillColor.withValues(alpha: 0.40),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(footPath, fillPaint);

    // Bevel top highlights
    final bevelPath = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5);
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bevelPath, bevelPaint);

    // Center internal junction dashed hint between the 2 tiles
    final junctionPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), junctionPaint);

    // Footprint perimeter outline
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(footPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant IsometricDoubleDiamondPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasGlow != hasGlow ||
        oldDelegate.glowColor != glowColor;
  }
}

class _IsometricCellData {
  final int gRow;
  final int col;
  final int localRow;
  final bool isClashLine;
  final bool isPlayerSquad;
  final int depth;
  final double screenX;
  final double screenY;

  const _IsometricCellData({
    required this.gRow,
    required this.col,
    required this.localRow,
    required this.isClashLine,
    required this.isPlayerSquad,
    required this.depth,
    required this.screenX,
    required this.screenY,
  });
}

