import 'package:flutter/material.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

/// Rank & Rite 2D Tactical Battlefield Board
/// Provides an authentic open-ground dark fantasy tactical presentation:
/// - Replaces artificial square box borders with tactile perspective ground plinths
/// - Field-of-vision visual depth: Frontline plinths are prominent, tapering subtly towards Backline
/// - Soft battlefield terrain footprint with clean column alignments
/// - Fully fixed header alignments eliminating right-edge / backline truncation
class RankAndRite2DBattlefield extends StatelessWidget {
  final SpatialCombatEngine engine;
  final String? selectedUnitId;
  final String? selectedEnemyUnitId;
  final String? draggedUnitId;
  final String? selectedCardId;
  final String? draggedUltimateUnitId;
  final String? selectedUltimateUnitId;
  final int? hoveredTileCol;
  final int? hoveredTileRow;
  final bool? isHoveredPlayerSide;
  final double tileWidth;
  final double tileHeight;
  final Function(String unitId) onSelectPlayerUnit;
  final Function(String enemyId) onSelectEnemyUnit;
  final Function(String unitId, int col, int row) onMovePlayerUnit;
  final Function(String cardId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) onCastCard;
  final Function(String ultUnitId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) onCastUltimate;
  final Function(int col, int row, bool isPlayer) onTileHover;
  final VoidCallback onClearHover;
  final Widget Function(CombatUnitState unit, {required double tileWidth, required double tileHeight, required double colGap, bool isSelected}) buildUnitMiniature;

  const RankAndRite2DBattlefield({
    super.key,
    required this.engine,
    required this.selectedUnitId,
    required this.selectedEnemyUnitId,
    required this.draggedUnitId,
    required this.selectedCardId,
    required this.draggedUltimateUnitId,
    required this.selectedUltimateUnitId,
    required this.hoveredTileCol,
    required this.hoveredTileRow,
    required this.isHoveredPlayerSide,
    required this.tileWidth,
    required this.tileHeight,
    required this.onSelectPlayerUnit,
    required this.onSelectEnemyUnit,
    required this.onMovePlayerUnit,
    required this.onCastCard,
    required this.onCastUltimate,
    required this.onTileHover,
    required this.onClearHover,
    required this.buildUnitMiniature,
  });

  @override
  Widget build(BuildContext context) {
    final double colWidth = tileWidth;
    final double rowHeight = tileHeight;
    final double clashDividerWidth = (tileWidth * 0.22).clamp(20.0, 36.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF07090E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232738), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.80),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Perfectly matched Rank Indicator Labels (Backline -> Midline -> Frontline)
          _buildRankHeaderLabels(colWidth, clashDividerWidth),
          const SizedBox(height: 8),

          // Main 2D Grid: Lanes (Columns 0 to 4)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Player Territory (Backline Row 2 -> Midline Row 1 -> Frontline Row 0)
              _buildSquadTerritory(isPlayer: true, rankOrder: const [2, 1, 0]),

              // Center: Subtle Clash Line / No-Man's Land Divider
              _buildClashBuffer(clashDividerWidth, height: rowHeight * 5 + 16),

              // Right: Enemy Territory (Frontline Row 0 -> Midline Row 1 -> Backline Row 2)
              _buildSquadTerritory(isPlayer: false, rankOrder: const [0, 1, 2]),
            ],
          ),
        ],
      ),
    );
  }

  /// Perfectly aligned rank headers matching each column width exactly
  Widget _buildRankHeaderLabels(double colWidth, double clashWidth) {
    Widget buildRankBadge(String label, Color color) {
      return SizedBox(
        width: colWidth,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.40), width: 0.8),
            ),
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.4),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Player Ranks: Row 2 (Back), Row 1 (Mid), Row 0 (Front)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildRankBadge('BACKLINE (R2)', const Color(0xFF64B5F6)),
              buildRankBadge('MIDLINE (R1)', const Color(0xFF81D4FA)),
              buildRankBadge('FRONTLINE (R0)', const Color(0xFFFFD54F)),
            ],
          ),
        ),

        // Neutral Clash Divider
        SizedBox(
          width: clashWidth,
          child: const Center(
            child: Icon(Icons.compare_arrows, color: Color(0xFFFFD54F), size: 14),
          ),
        ),

        // Enemy Ranks: Row 0 (Front), Row 1 (Mid), Row 2 (Back)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildRankBadge('FRONTLINE (R0)', const Color(0xFFFF8A80)),
              buildRankBadge('MIDLINE (R1)', const Color(0xFFFFAB91)),
              buildRankBadge('BACKLINE (R2)', const Color(0xFFE57373)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClashBuffer(double width, {required double height}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF14131D).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: const Color(0xFFFFD54F).withValues(alpha: 0.25), width: 1.0),
          right: BorderSide(color: const Color(0xFFFFD54F).withValues(alpha: 0.25), width: 1.0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (i) => Icon(
            Icons.flash_on,
            color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
            size: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSquadTerritory({required bool isPlayer, required List<int> rankOrder}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rankOrder.map((row) {
        return SizedBox(
          width: tileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (col) {
              return _build2DGridTile(col: col, row: row, isPlayer: isPlayer);
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _build2DGridTile({
    required int col,
    required int row,
    required bool isPlayer,
  }) {
    final units = isPlayer ? engine.playerUnits : engine.enemyUnits;
    final occupant = units.where((u) => (u.isAlive || u.isSolidObstacle) && u.occupies(col, row)).firstOrNull;
    final bool isSelected = occupant != null && (isPlayer ? (selectedUnitId == occupant.id) : (selectedEnemyUnitId == occupant.id));
    final bool isHovered = hoveredTileCol == col && hoveredTileRow == row && isHoveredPlayerSide == isPlayer;

    // Vanguard Cover check (Rank & Rite Spec Sec 3)
    final bool hasVanguardCover = isPlayer && occupant != null && engine.isCoveredByVanguard(occupant, trajectory: AttackTrajectory.directPhysical);

    // Movement validity for selected ally
    final selectedAlly = selectedUnitId != null ? engine.playerUnits.where((u) => u.id == selectedUnitId && u.isAlive).firstOrNull : null;
    final bool isMoveReachable = isPlayer && selectedAlly != null && occupant == null && selectedAlly.canMoveTo(col, row, ignoreApCost: engine.isPreBattlePhase);

    // Natural Field-of-Vision Depth Scaling:
    // Row 0 (Frontline, closest to clash): Plinths are larger and wider (1.0 scale)
    // Row 1 (Midline): Scale 0.94
    // Row 2 (Backline, deeper in terrain): Scale 0.88
    final double depthScale = row == 0 ? 1.0 : (row == 1 ? 0.94 : 0.88);
    final double plinthW = (tileWidth * 0.88 * depthScale).clamp(44.0, 160.0);
    final double plinthH = (tileHeight * 0.30 * depthScale).clamp(14.0, 40.0);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        onTileHover(col, row, isPlayer);
        return true;
      },
      onLeave: (_) => onClearHover(),
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.startsWith('card:')) {
          final cardId = data.replaceFirst('card:', '');
          onCastCard(cardId, targetUnit: occupant, targetCol: col, targetRow: row);
        } else if (data.startsWith('ultimate:')) {
          final ultId = data.replaceFirst('ultimate:', '');
          onCastUltimate(ultId, targetUnit: occupant, targetCol: col, targetRow: row);
        } else if (data.startsWith('unit:')) {
          final unitId = data.replaceFirst('unit:', '');
          if (isPlayer) {
            onMovePlayerUnit(unitId, col, row);
          }
        }
        onClearHover();
      },
      builder: (context, candidateData, rejectedData) {
        final bool isDropCandidate = candidateData.isNotEmpty;

        // Ground Plinth Border & Glow Colors
        Color plinthRimColor;
        Color plinthGlowColor;

        if (isSelected || isDropCandidate || isHovered) {
          plinthRimColor = const Color(0xFF00E5FF);
          plinthGlowColor = const Color(0xFF00E5FF).withValues(alpha: 0.6);
        } else if (isMoveReachable) {
          plinthRimColor = const Color(0xFF00E676);
          plinthGlowColor = const Color(0xFF00E676).withValues(alpha: 0.4);
        } else if (occupant != null) {
          plinthRimColor = isPlayer
              ? const Color(0xFF64B5F6).withValues(alpha: 0.70)
              : const Color(0xFFE57373).withValues(alpha: 0.65);
          plinthGlowColor = (isPlayer ? const Color(0xFF2196F3) : const Color(0xFFF44336)).withValues(alpha: 0.25);
        } else {
          // Empty ground coordinate
          plinthRimColor = isPlayer
              ? const Color(0xFF37474F).withValues(alpha: 0.35)
              : const Color(0xFF4E342E).withValues(alpha: 0.30);
          plinthGlowColor = Colors.transparent;
        }

        return Container(
          width: tileWidth,
          height: tileHeight,
          // Open battlefield: transparent background instead of square bounding box!
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Natural Flat Battlefield Ground Plinth (Tabletop Perspective Base)
              Positioned(
                bottom: 8,
                child: Container(
                  width: plinthW,
                  height: plinthH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(plinthW / 2, plinthH / 2)),
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.15),
                      radius: 0.85,
                      colors: isPlayer
                          ? [
                              const Color(0xFF1A2B42).withValues(alpha: occupant != null ? 0.95 : 0.60),
                              const Color(0xFF0B1420).withValues(alpha: 0.90),
                              Colors.transparent,
                            ]
                          : [
                              const Color(0xFF38151A).withValues(alpha: occupant != null ? 0.95 : 0.60),
                              const Color(0xFF1B0709).withValues(alpha: 0.90),
                              Colors.transparent,
                            ],
                    ),
                    border: Border.all(
                      color: plinthRimColor,
                      width: (isSelected || isDropCandidate || isHovered) ? 1.8 : 1.0,
                    ),
                    boxShadow: [
                      // Ground contact shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      if (plinthGlowColor != Colors.transparent)
                        BoxShadow(
                          color: plinthGlowColor,
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Subtle Coordinate Marker (Faintly etched into stone surface)
              Positioned(
                bottom: 11,
                child: Opacity(
                  opacity: (occupant != null || isHovered || isMoveReachable) ? 0.0 : 0.28,
                  child: Text(
                    'C$col:R$row',
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 3. Vanguard Cover Badge (Rank & Rite Spec Sec 3)
              if (hasVanguardCover)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 0.8),
                    ),
                    child: const Text(
                      '🛡️-25%',
                      style: TextStyle(fontSize: 7, color: Color(0xFF80D8FF), fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

              // 4. Petrified Stone Plinth Indicator (Rank & Rite Spec Sec 5)
              if (occupant != null && occupant.isPetrifiedPlinth)
                Positioned(
                  bottom: 2,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF90A4AE), width: 0.8),
                    ),
                    child: Center(
                      child: Text(
                        '🪨 ${occupant.plinthDurability}/3',
                        style: const TextStyle(fontSize: 7.5, color: Color(0xFFCFD8DC), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

              // 5. Standing Unit Miniature (Grounded on the perspective plinth)
              if (occupant != null)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isPlayer) {
                        onSelectPlayerUnit(occupant.id);
                      } else {
                        onSelectEnemyUnit(occupant.id);
                      }
                    },
                    child: buildUnitMiniature(
                      occupant,
                      tileWidth: tileWidth,
                      tileHeight: tileHeight,
                      colGap: 0,
                      isSelected: isSelected,
                    ),
                  ),
                )
              else if (isMoveReachable)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onMovePlayerUnit(selectedAlly.id, col, row);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00E676), width: 1.0),
                        boxShadow: const [
                          BoxShadow(color: Color(0x6600E676), blurRadius: 6),
                        ],
                      ),
                      child: const Text(
                        'SHIFT',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFFE8F5E9), fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (isPlayer && selectedAlly != null && selectedAlly.canMoveTo(col, row, ignoreApCost: engine.isPreBattlePhase)) {
                        onMovePlayerUnit(selectedAlly.id, col, row);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
