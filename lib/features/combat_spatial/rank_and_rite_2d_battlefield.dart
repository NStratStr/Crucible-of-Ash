import 'package:flutter/material.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

/// Rank & Rite 2D Tactical Battlefield Board
/// Provides a direct, high-readability 2D landscape presentation:
/// - Player Squad on the Left (Backline Col 0-4, Midline Col 0-4, Frontline Col 0-4)
/// - Neutral Clash Buffer in the Center
/// - Enemy Host on the Right (Frontline Col 0-4, Midline Col 0-4, Backline Col 0-4)
///
/// Features:
/// - Crystal clear Line-of-Sight and Vanguard Cover visualization
/// - Crisp, unskewed 2D character standing tokens
/// - Direct horizontal trajectory & knockback splat visual alignment
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
    // 5 Columns (lanes, 0 to 4 from top to bottom)
    // Ranks:
    // Player Side (Left):
    //   Rank 2 (Backline), Rank 1 (Midline), Rank 0 (Frontline)
    // Center:
    //   Clash / No-Man's Land Divider
    // Enemy Side (Right):
    //   Rank 0 (Frontline), Rank 1 (Midline), Rank 2 (Backline)

    const int laneCount = 5; // Columns 0..4
    final double colWidth = tileWidth;
    final double rowHeight = tileHeight;
    final double clashDividerWidth = 24.0;
    final double sideWidth = colWidth * 3 + 12; // 3 ranks per side
    final double totalBoardWidth = sideWidth * 2 + clashDividerWidth + 32;
    final double totalBoardHeight = rowHeight * laneCount + 40;

    return Container(
      width: totalBoardWidth,
      height: totalBoardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F14).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E3244), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Rank Indicator Labels
          _buildRankHeaderLabels(sideWidth, clashDividerWidth),
          const SizedBox(height: 8),

          // Main 2D Grid: Lanes (Columns 0 to 4)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left: Player Territory (Back -> Mid -> Front)
                _buildSquadTerritory(isPlayer: true, rankOrder: const [2, 1, 0]),

                // Center: Clash Buffer Lane
                _buildClashBuffer(clashDividerWidth),

                // Right: Enemy Territory (Front -> Mid -> Back)
                _buildSquadTerritory(isPlayer: false, rankOrder: const [0, 1, 2]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankHeaderLabels(double sideWidth, double clashWidth) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Player ranks
          SizedBox(
            width: sideWidth,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('BACKLINE (R2)', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text('MIDLINE (R1)', style: TextStyle(color: Color(0xFF81D4FA), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text('FRONTLINE (R0)', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          SizedBox(
            width: clashWidth,
            child: const Center(
              child: Icon(Icons.compare_arrows, color: Color(0xFFFFD54F), size: 14),
            ),
          ),
          // Enemy ranks
          SizedBox(
            width: sideWidth,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('FRONTLINE (R0)', style: TextStyle(color: Color(0xFFFF8A80), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text('MIDLINE (R1)', style: TextStyle(color: Color(0xFFFFAB91), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text('BACKLINE (R2)', style: TextStyle(color: Color(0xFFE57373), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClashBuffer(double width) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1926).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (i) => Icon(
            Icons.flash_on,
            color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
            size: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSquadTerritory({required bool isPlayer, required List<int> rankOrder}) {
    return Row(
      children: rankOrder.map((row) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

    // Vanguard Cover check (Rank & Rite Spec Sec 3: Direct physical attacks)
    final bool hasVanguardCover = isPlayer && occupant != null && engine.isCoveredByVanguard(occupant, trajectory: AttackTrajectory.directPhysical);

    // Movement validity for selected ally
    final selectedAlly = selectedUnitId != null ? engine.playerUnits.where((u) => u.id == selectedUnitId && u.isAlive).firstOrNull : null;
    final bool isMoveReachable = isPlayer && selectedAlly != null && occupant == null && selectedAlly.canMoveTo(col, row, ignoreApCost: engine.isPreBattlePhase);

    // Drop target for dragged cards or units
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

        Color tileBg = isPlayer
            ? const Color(0xFF13192B).withValues(alpha: 0.7)
            : const Color(0xFF281418).withValues(alpha: 0.7);

        Color tileBorder = isPlayer
            ? const Color(0xFF2A4365).withValues(alpha: 0.7)
            : const Color(0xFF6B2129).withValues(alpha: 0.7);

        if (isDropCandidate || isHovered) {
          tileBg = const Color(0xFF00E5FF).withValues(alpha: 0.25);
          tileBorder = const Color(0xFF00E5FF);
        } else if (isMoveReachable) {
          tileBg = const Color(0xFF00E676).withValues(alpha: 0.22);
          tileBorder = const Color(0xFF00E676);
        } else if (isSelected) {
          tileBorder = const Color(0xFFFFD54F);
        }

        return Container(
          width: tileWidth,
          height: tileHeight,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tileBorder,
              width: (isSelected || isDropCandidate || isHovered) ? 2.0 : 1.0,
            ),
            boxShadow: (isSelected || isDropCandidate)
                ? [
                    BoxShadow(
                      color: (isDropCandidate ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F)).withValues(alpha: 0.4),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Coordinate tag in corner
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  'C$col:R$row',
                  style: TextStyle(
                    fontSize: 7.5,
                    color: Colors.white.withValues(alpha: 0.3),
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // Vanguard Cover Badge (Rank & Rite Spec Sec 3)
              if (hasVanguardCover)
                Positioned(
                  top: 2,
                  right: 3,
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

              // Petrified Stone Plinth Indicator (Rank & Rite Spec Sec 5)
              if (occupant != null && occupant.isPetrifiedPlinth)
                Positioned(
                  bottom: 2,
                  left: 3,
                  right: 3,
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

              // Tile Center: Occupant Unit or Move Button
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
                        color: const Color(0xFF00E676).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00E676), width: 1.0),
                      ),
                      child: const Text(
                        'SHIFT',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFF00E676), fontWeight: FontWeight.w900),
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
