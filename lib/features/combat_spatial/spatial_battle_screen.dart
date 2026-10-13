import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _engine = SpatialCombatEngine();
    _engine.addListener(_onEngineUpdate);
    _startLoop();
  }

  void _onEngineUpdate() {
    if (mounted) setState(() {});
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

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    // Enemy Battlefield Grid (Rows 2 -> 1 -> 0)
                    Expanded(
                      child: _buildSquadGrid(isPlayerSquad: false),
                    ),

                    // Central Clash Line Divider
                    _buildClashLineDivider(),

                    // Player Battlefield Grid (Rows 0 -> 1 -> 2)
                    Expanded(
                      child: _buildSquadGrid(isPlayerSquad: true),
                    ),
                  ],
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
      children: rowsOrder.map((rowIdx) {
        return Expanded(
          child: Row(
            children: List.generate(5, (colIdx) {
              return Expanded(
                child: _buildGridCell(colIdx, rowIdx, isPlayerSquad: isPlayerSquad),
              );
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

    final bool isSelected = _selectedUnitId != null && occupant?.id == _selectedUnitId;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Only accept if cell is in player territory and target is currently empty
        return isPlayerSquad && occupant == null;
      },
      onAcceptWithDetails: (details) {
        final draggedUnitId = details.data;
        _engine.movePlayerUnit(draggedUnitId, col, row);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isDropCandidate = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () {
            if (isPlayerSquad) {
              if (occupant != null) {
                setState(() => _selectedUnitId = occupant.id);
              } else if (_selectedUnitId != null) {
                // Click to move selected unit to this empty cell
                _engine.movePlayerUnit(_selectedUnitId!, col, row);
                setState(() => _selectedUnitId = null);
              }
            } else if (occupant != null) {
              // Target enemy with dragged card
              if (_draggedCard != null) {
                _engine.castCard(_draggedCard!.id, targetUnit: occupant);
                setState(() => _draggedCard = null);
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(2.5),
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
                            const Color(0xFF00363A),
                            const Color(0xFF001F24),
                          ]
                        : (isPlayerSquad
                            ? [
                                const Color(0xFF1A1F2C),
                                const Color(0xFF10131B),
                              ]
                            : [
                                const Color(0xFF26191C),
                                const Color(0xFF150D0F),
                              ])),
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isTelegraphed
                    ? const Color(0xFFFF1744)
                    : (isSelected
                        ? const Color(0xFFFFD54F)
                        : (isDropCandidate
                            ? const Color(0xFF00E5FF)
                            : (isPlayerSquad ? const Color(0xFF38455E) : const Color(0xFF58363F)))),
                width: isTelegraphed || isSelected || isDropCandidate ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isTelegraphed
                      ? const Color(0xFFFF1744).withValues(alpha: 0.45)
                      : (isDropCandidate
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                          : Colors.black54),
                  blurRadius: isTelegraphed || isDropCandidate ? 8 : 3,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Coordinate Watermark
                Positioned(
                  top: 2,
                  left: 3,
                  child: Text(
                    'C${col + 1} R$row',
                    style: TextStyle(
                      fontSize: 8,
                      color: isTelegraphed ? const Color(0xFFFF8A80) : Colors.white24,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                // Occupant Miniature
                if (occupant != null)
                  Center(
                    child: isPlayerSquad
                        ? Draggable<String>(
                            data: occupant.id,
                            onDragStarted: () {
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

  Widget _buildUnitMiniatureWidget(CombatUnitState unit, {bool isDragging = false, bool isSelected = false}) {
    final bool isBoss = unit.footprint == UnitFootprint.horizontal1x2;
    final double hpRatio = unit.maxHp > 0 ? (unit.hp / unit.maxHp).clamp(0.0, 1.0) : 0.0;
    final double apRatio = (unit.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
    final Color factionColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    return SizedBox(
      width: isDragging ? 80 : double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Tabletop 3D Plinth Base (Elliptical Ground Pedestal)
          Positioned(
            bottom: 12,
            left: 4,
            right: 4,
            child: Center(
              child: Container(
                width: isBoss ? 110 : 54,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(50, 12)),
                  gradient: RadialGradient(
                    colors: [
                      factionColor.withValues(alpha: isSelected ? 0.6 : 0.35),
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: isSelected ? factionColor : factionColor.withValues(alpha: 0.5),
                    width: isSelected ? 1.5 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: factionColor.withValues(alpha: isSelected ? 0.5 : 0.2),
                      blurRadius: isSelected ? 8 : 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Character Model Miniature Cutout
          Positioned(
            bottom: 14,
            top: 2,
            left: 2,
            right: 2,
            child: Center(
              child: Image.asset(
                unit.assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => Icon(
                  unit.isPlayer ? Icons.shield : Icons.dangerous,
                  color: factionColor,
                  size: isBoss ? 36 : 24,
                ),
              ),
            ),
          ),

          // 3. Name, Badges & Slag Carapace Overlays
          Positioned(
            top: 1,
            left: 2,
            right: 2,
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
                    Flexible(
                      child: Text(
                        unit.name,
                        style: TextStyle(
                          fontSize: isBoss ? 8.5 : 7.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Bottom Tactical HUD: HP & AP Turn Meters
          Positioned(
            bottom: 0,
            left: 3,
            right: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HP Bar
                Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.white24, width: 0.4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: hpRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: unit.isPlayer ? const Color(0xFF81C784) : const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
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
        ],
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
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              _engine.burnCard(details.data);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return Container(
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
                    data: card.id,
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
                        // One-tap cast on primary target
                        _engine.castCard(card.id);
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
