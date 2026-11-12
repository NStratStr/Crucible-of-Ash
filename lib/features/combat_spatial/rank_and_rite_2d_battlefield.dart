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
  final Set<String>? secondaryTargetEnemyIds;
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
  final Function(CombatUnitState unit)? onLongPressUnit;
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
    this.secondaryTargetEnemyIds,
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
    this.onLongPressUnit,
    required this.buildUnitMiniature,
  });

  @override
  Widget build(BuildContext context) {
    final double colWidth = tileWidth;
    final double rowHeight = tileHeight;
    final double clashDividerWidth = (tileWidth * 0.22).clamp(20.0, 36.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left: Player Squad (Backline Row 2 -> Midline Row 1 -> Frontline Row 0)
          _buildSquadTerritory(isPlayer: true, rankOrder: const [2, 1, 0]),

          // Center: Intimate clash spacing (armies face off in close tactical confrontation)
          SizedBox(width: (tileWidth * 0.38).clamp(32.0, 68.0)),

          // Right: Enemy Squad (Frontline Row 0 -> Midline Row 1 -> Backline Row 2)
          _buildSquadTerritory(isPlayer: false, rankOrder: const [0, 1, 2]),
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
          3,
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
    // Slight rank-to-rank horizontal overlap so formations look tight and compact and cohesive
    final double overlapStep = (tileWidth * 0.16).clamp(8.0, 24.0);
    final units = isPlayer ? engine.playerUnits : engine.enemyUnits;
    final multiUnits = units.where((u) => u.isAlive && (u.occupiedNodes.length > 1 || u.footprint != UnitFootprint.single1x1)).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: rankOrder.asMap().entries.map((entry) {
            final int index = entry.key;
            final int row = entry.value;

            // Clean 2D Lane Alignment (Straight horizontal lanes, no fake diagonal offsets)
            const double rankDepthOffsetY = 0.0;
            const double rankDepthOffsetX = 0.0;

            return Transform.translate(
              offset: Offset(rankDepthOffsetX, rankDepthOffsetY),
              child: SizedBox(
                width: tileWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (col) {
                    return _build2DGridTile(col: col, row: row, isPlayer: isPlayer);
                  }),
                ),
              ),
            );
          }).toList(),
        ),

        // Multi-Node Behemoth / Colossus Boss Layer (Gorgoroth, World Titans)
        // Renders ONE single commanding Boss Miniature positioned centrally over its multi-node footprint
        // with a unified grand Colossus territorial base and single overhead badge!
        ...multiUnits.map((multiUnit) {
          double minX = double.infinity;
          double maxX = -double.infinity;
          double minY = double.infinity;
          double maxY = -double.infinity;

          for (final node in multiUnit.occupiedNodes) {
            final int rankIdx = rankOrder.indexOf(node.row);
            if (rankIdx == -1) continue;
            final double colLeft = rankIdx * tileWidth - (overlapStep * rankIdx);
            final double colRight = colLeft + tileWidth;
            final double rankDepthOffsetY = node.row == 0 ? 0.0 : (node.row == 1 ? -14.0 : -28.0);
            final double tileTop = node.column * tileHeight + rankDepthOffsetY;
            final double tileBottom = tileTop + tileHeight;

            if (colLeft < minX) minX = colLeft;
            if (colRight > maxX) maxX = colRight;
            if (tileTop < minY) minY = tileTop;
            if (tileBottom > maxY) maxY = tileBottom;
          }

          if (minX == double.infinity) return const SizedBox.shrink();

          final double centerX = (minX + maxX) / 2;
          final double centerY = (minY + maxY) / 2;
          final bool isQuadColossus = multiUnit.footprint == UnitFootprint.quadColossus2x2;
          final double bossSpanWidth = tileWidth * (isQuadColossus ? 2.35 : 1.8);
          final double bossSpanHeight = tileHeight * 3.1;

          // Natural Ground Baseline for the multi-node footprint:
          // In 2.5D perspective, the base of the 2x2 boss rests solidly across Col 1 and Col 2.
          final double groundBaselineY = centerY + (tileHeight * 0.42);
          final double bossTop = groundBaselineY - bossSpanHeight + 10;
          final double bossLeft = centerX - (bossSpanWidth / 2);

          final bool isSelected = isPlayer ? (selectedUnitId == multiUnit.id) : (selectedEnemyUnitId == multiUnit.id);
          final bool isSecondaryCleave = !isPlayer && (secondaryTargetEnemyIds?.contains(multiUnit.id) ?? false);
          final anchorNode = multiUnit.occupiedNodes.isNotEmpty ? multiUnit.occupiedNodes.first : const GridNode(column: 1, row: 0);

          return Positioned(
            left: bossLeft,
            top: bossTop,
            width: bossSpanWidth,
            height: bossSpanHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // 1. Unified Molten Magma Underglow (Natural ambient terrain heat, seamless blend with dark battlefield)
                Positioned(
                  bottom: 4,
                  child: IgnorePointer(
                    child: Container(
                      width: bossSpanWidth * 0.88,
                      height: tileHeight * 0.44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.elliptical(bossSpanWidth * 0.44, tileHeight * 0.22)),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.85,
                          colors: isSelected
                              ? [
                                  const Color(0x77FF1744),
                                  const Color(0x33FF5252),
                                  Colors.transparent,
                                ]
                              : (isSecondaryCleave
                                  ? [
                                      const Color(0x66FF9100),
                                      const Color(0x28FFB74D),
                                      Colors.transparent,
                                  ]
                                  : [
                                      const Color(0x55E65100),
                                      const Color(0x22BF360C),
                                      Colors.transparent,
                                  ]),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.70),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          if (isSelected)
                            const BoxShadow(
                              color: Color(0x88FF1744),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          else if (isSecondaryCleave)
                            const BoxShadow(
                              color: Color(0x77FF9100),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. DragTarget & Single Boss Miniature (Grounded firmly at bottomCenter)
                Positioned(
                  bottom: 0,
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      onTileHover(anchorNode.column, anchorNode.row, isPlayer);
                      return true;
                    },
                    onLeave: (_) => onClearHover(),
                    onAcceptWithDetails: (details) {
                      final data = details.data;
                      if (data.startsWith('card:')) {
                        final cardId = data.replaceFirst('card:', '');
                        onCastCard(cardId, targetUnit: multiUnit, targetCol: anchorNode.column, targetRow: anchorNode.row);
                      } else if (data.startsWith('ultimate:')) {
                        final ultId = data.replaceFirst('ultimate:', '');
                        onCastUltimate(ultId, targetUnit: multiUnit, targetCol: anchorNode.column, targetRow: anchorNode.row);
                      }
                      onClearHover();
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (isPlayer) {
                            onSelectPlayerUnit(multiUnit.id);
                          } else {
                            onSelectEnemyUnit(multiUnit.id);
                          }
                        },
                        onDoubleTap: () => onLongPressUnit?.call(multiUnit),
                        onLongPress: () => onLongPressUnit?.call(multiUnit),
                        child: buildUnitMiniature(
                          multiUnit,
                          tileWidth: tileWidth,
                          tileHeight: tileHeight,
                          colGap: 0,
                          isSelected: isSelected || candidateData.isNotEmpty,
                        ),
                      );
                    },
                  ),
                ),

                // 3. Single Overhead Target / Cleave Badge (Positioned once at the top of the giant boss)
                if (isSelected || isSecondaryCleave)
                  Positioned(
                    top: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFB71C1C) : const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFF5252) : const Color(0xFFFFB74D),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected ? const Color(0x99FF1744) : const Color(0x88FF9100),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.gps_fixed : Icons.flash_on,
                            size: 9,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isSelected ? 'TARGET LOCK' : '⚔️ CLEAVE SPLASH',
                            style: const TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _build2DGridTile({
    required int col,
    required int row,
    required bool isPlayer,
  }) {
    final units = isPlayer ? engine.playerUnits : engine.enemyUnits;
    final occupant = units.where((u) => (u.isAlive || u.isSolidObstacle) && u.occupies(col, row)).firstOrNull;
    final bool isPartOfMultiNodeBoss = units.any((u) => (u.isAlive || u.isSolidObstacle) && (u.occupiedNodes.length > 1 || u.footprint != UnitFootprint.single1x1) && u.occupies(col, row));
    final bool isMultiNodeBoss = isPartOfMultiNodeBoss;
    final bool isSelected = occupant != null && (isPlayer ? (selectedUnitId == occupant.id) : (selectedEnemyUnitId == occupant.id));
    final bool isHovered = hoveredTileCol == col && hoveredTileRow == row && isHoveredPlayerSide == isPlayer;
    final bool isSecondaryCleave = occupant != null && !isPlayer && (secondaryTargetEnemyIds?.contains(occupant.id) ?? false);

    // Vanguard Cover check (Rank & Rite Spec Sec 3)
    final bool hasVanguardCover = isPlayer && occupant != null && engine.isCoveredByVanguard(occupant, trajectory: AttackTrajectory.directPhysical);

    // Pre-battle projected attacker and flank status
    final projectedAttacker = engine.playerUnits.where(
      (u) => u.isAlive && u.occupiedNodes.isNotEmpty && engine.resolveProjectedTarget(u)?.id == occupant?.id,
    ).firstOrNull;
    final bool isTargetedInPreBattle = engine.isPreBattlePhase && !isPlayer && projectedAttacker != null && occupant != null;
    final bool isFlankedInPreBattle = isTargetedInPreBattle && !engine.isCoveredByVanguard(occupant, trajectory: AttackTrajectory.flanking);

    // Movement validity for selected ally
    final selectedAlly = selectedUnitId != null ? engine.playerUnits.where((u) => u.id == selectedUnitId && u.isAlive).firstOrNull : null;
    final bool isMoveReachable = isPlayer && selectedAlly != null && occupant == null && selectedAlly.canMoveTo(col, row, ignoreApCost: engine.isPreBattlePhase);

    // Telegraphed Enemy Threat Danger Zone (Suggestion 2)
    final bool isTelegraphed = isPlayer && engine.activeTelegraphedNodes.any((n) => n.column == col && n.row == row);
    SpatialTelegraphIntent? activeIntentOnCell;
    if (isTelegraphed) {
      for (final enemy in engine.enemyUnits) {
        if (enemy.isAlive && enemy.pendingIntent != null && enemy.pendingIntent!.targetNodes.any((n) => n.column == col && n.row == row)) {
          activeIntentOnCell = enemy.pendingIntent;
          break;
        }
      }
    }

    // Natural Field-of-Vision Depth Scaling:
    // Row 0 (Frontline, closest to clash): Plinths are larger and wider (1.0 scale)
    // Row 1 (Midline): Scale 0.94
    // Row 2 (Backline, deeper in terrain): Scale 0.88
    // 3x3 Staggered Depth Perspective Scaling
    // Row 0 (Frontline, closest to clash): 1.06 scale (heroic frontline presence)
    // Row 1 (Midline): 0.95 scale
    // Row 2 (Backline, deeper in the field): 0.84 scale (recedes into the distance)
    final double depthScale = row == 0 ? 1.06 : (row == 1 ? 0.95 : 0.84);
    final double plinthW = (tileWidth * 0.88 * depthScale).clamp(44.0, 160.0);
    final double plinthH = (tileHeight * 0.28 * depthScale).clamp(14.0, 38.0);

    return DragTarget<String>(
      key: Key('2d_tile_${isPlayer ? "player" : "enemy"}_c${col}_r$row'),
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

        final bool isNecroticMire = isPlayer && engine.necroticMireNodes.any((n) => n.column == col && n.row == row);
        final bool isTurnActiveUnit = occupant != null && engine.activeActingUnit?.id == occupant.id;
        if (isMultiNodeBoss) {
          // Multi-node colossus boss territory: Individual ground tiles stay unlit
          // The single unified boss entity renders the grand Colossus territorial base!
          plinthRimColor = Colors.transparent;
          plinthGlowColor = Colors.transparent;
        } else if (isTelegraphed) {
          plinthRimColor = const Color(0xFFFF1744);
          plinthGlowColor = const Color(0xFFFF1744).withValues(alpha: 0.75);
        } else if (isNecroticMire) {
          plinthRimColor = const Color(0xFF00E676);
          plinthGlowColor = const Color(0xFF00E676).withValues(alpha: 0.75);
        } else if (isTurnActiveUnit) {
          plinthRimColor = const Color(0xFFFFD54F);
          plinthGlowColor = const Color(0xFFFFD54F).withValues(alpha: 0.85);
        } else if (!isPlayer && isSelected) {
          // Explicit targeted enemy lock: fierce crimson/gold reticle rim!
          plinthRimColor = const Color(0xFFFF1744);
          plinthGlowColor = const Color(0xFFFF5252).withValues(alpha: 0.85);
        } else if (isSecondaryCleave) {
          // Secondary cleave/splash target: warm amber rim & pulse!
          plinthRimColor = const Color(0xFFFF9100);
          plinthGlowColor = const Color(0xFFFF9100).withValues(alpha: 0.75);
        } else if (isSelected || isDropCandidate || isHovered) {
          plinthRimColor = const Color(0xFF00E5FF);
          plinthGlowColor = const Color(0xFF00E5FF).withValues(alpha: 0.6);
        } else if (isMoveReachable) {
          plinthRimColor = const Color(0xFF00E676).withValues(alpha: 0.35);
          plinthGlowColor = Colors.transparent;
        } else if (occupant != null) {
          if (hasVanguardCover) {
            plinthRimColor = const Color(0xFF00E5FF);
            plinthGlowColor = const Color(0xFF00E5FF).withValues(alpha: 0.45);
          } else {
            plinthRimColor = isPlayer
                ? const Color(0xFF64B5F6).withValues(alpha: 0.70)
                : const Color(0xFFE57373).withValues(alpha: 0.65);
            plinthGlowColor = (isPlayer ? const Color(0xFF2196F3) : const Color(0xFFF44336)).withValues(alpha: 0.25);
          }
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
              // 1. Natural Ground Plinth (Carved Runic Miniature Base)
              if (!isMultiNodeBoss && (occupant != null || isDropCandidate || isHovered || engine.isPreBattlePhase))
                Positioned(
                  bottom: 8,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: plinthW,
                        height: plinthH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.elliptical(plinthW / 2, plinthH / 2)),
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.15),
                            radius: 0.85,
                            colors: isPlayer
                                ? [
                                    (occupant?.isAshSculptor == true || occupant?.id == 'ash_sculptor')
                                        ? const Color(0xFF382810).withValues(alpha: 0.95)
                                        : const Color(0xFF1A2B42).withValues(alpha: occupant != null ? 0.95 : 0.40),
                                    const Color(0xFF0B1420).withValues(alpha: 0.80),
                                    Colors.transparent,
                                  ]
                                : [
                                    const Color(0xFF38151A).withValues(alpha: occupant != null ? 0.95 : 0.40),
                                    const Color(0xFF1B0709).withValues(alpha: 0.80),
                                    Colors.transparent,
                                  ],
                          ),
                          border: Border.all(
                            color: (occupant?.isAshSculptor == true || occupant?.id == 'ash_sculptor') && !isSelected && !isTurnActiveUnit
                                ? const Color(0xFFFFD54F).withValues(alpha: 0.85)
                                : plinthRimColor,
                            width: isTurnActiveUnit ? 2.4 : ((isSelected || isDropCandidate || isHovered) ? 1.8 : 1.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.70),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                            if (plinthGlowColor != Colors.transparent || (occupant?.isAshSculptor == true && !isSelected))
                              BoxShadow(
                                color: (occupant?.isAshSculptor == true && plinthGlowColor == Colors.transparent)
                                    ? const Color(0xFFFFD54F).withValues(alpha: 0.3)
                                    : plinthGlowColor,
                                blurRadius: isTurnActiveUnit ? 18 : (isSelected ? 12 : 6),
                                spreadRadius: isTurnActiveUnit ? 3 : (isSelected ? 2 : 0),
                              ),
                          ],
                        ),
                      ),
                      // Inner concentric carved rune lip
                      Container(
                        width: plinthW * 0.76,
                        height: plinthH * 0.65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.elliptical(plinthW * 0.38, plinthH * 0.325)),
                          border: Border.all(
                            color: plinthRimColor.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1b. Glowing Arcane Spell Magic Circle Projection (when targeted by Card or Ultimate)
              if ((selectedCardId != null && !isPlayer) || isHovered)
                Positioned(
                  bottom: 2,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (isHovered || isDropCandidate) ? 0.85 : (selectedCardId != null ? 0.40 : 0.0),
                      child: Image.asset(
                        (selectedCardId == 'phalanx_intercept' || selectedCardId == 'stoke_the_embers')
                            ? 'assets/images/Spells/Support_spell_magic_circle.png'
                            : (selectedCardId == 'revive_vitae'
                                ? 'assets/images/Spells/Heal_spell_magic_circle.png'
                                : 'assets/images/Spells/Attack_spell_magic_circle.png'),
                        width: plinthW * 1.15,
                        height: plinthH * 2.2,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // Coordinate marker: ONLY shown when dragging a unit or hovering
              if (isHovered || isDropCandidate)
                Positioned(
                  bottom: 11,
                  child: Opacity(
                    opacity: 0.6,
                    child: Text(
                      'C$col:R$row',
                      style: const TextStyle(
                        fontSize: 7.5,
                        color: Color(0xFF80D8FF),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 2b. Telegraphed Enemy Threat Danger Zone Countdown & Hazard Overlay
              if (isTelegraphed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x33FF1744),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x88FF1744), width: 1.2),
                      ),
                    ),
                  ),
                ),
              if (isTelegraphed && activeIntentOnCell != null)
                Positioned(
                  top: 2,
                  left: 2,
                  right: 2,
                  child: Builder(
                    builder: (context) {
                      final intent = activeIntentOnCell!;
                      final remTicks = (intent.triggerTick - engine.currentTick).clamp(0, 9999);
                      final remSec = (remTicks / 30.0).toStringAsFixed(1);
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xEE4A0E17),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFFFF1744), width: 0.9),
                            boxShadow: const [
                              BoxShadow(color: Color(0x66FF1744), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            '⚠️ ${remSec}s',
                            style: const TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF8A80),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Necrotic Mire Badge in 2D
              if (isNecroticMire)
                Positioned(
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1B5E20),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF69F0AE), width: 0.8),
                      boxShadow: const [BoxShadow(color: Color(0x6600E676), blurRadius: 4)],
                    ),
                    child: const Text(
                      '☣️ MIASMA (-15)',
                      style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Color(0xFFB9F6CA)),
                    ),
                  ),
                ),

              // Vanguard cover is cleanly indicated by subtle blue plinth glow, no overhead badge clutter

              // 3b-pre. Pre-Battle Projected Target & Flank Reticle Badge
              if (!isMultiNodeBoss && isTargetedInPreBattle && !isSelected)
                Positioned(
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isFlankedInPreBattle ? const Color(0xEE4A148C) : const Color(0xEE0D47A1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isFlankedInPreBattle ? const Color(0xFFB388FF) : const Color(0xFF00E5FF),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isFlankedInPreBattle ? const Color(0xFFB388FF) : const Color(0xFF00E5FF)).withValues(alpha: 0.5),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFlankedInPreBattle ? Icons.flash_on : Icons.gps_fixed,
                          size: 8,
                          color: isFlankedInPreBattle ? const Color(0xFFE1BEE7) : const Color(0xFF80D8FF),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isFlankedInPreBattle ? '⚡ FLANK (+20% CRIT)' : '🎯 TARGET',
                          style: TextStyle(
                            fontSize: 6.5,
                            fontWeight: FontWeight.w900,
                            color: isFlankedInPreBattle ? const Color(0xFFE1BEE7) : const Color(0xFF80D8FF),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3b. Primary Target Lock Reticle Badge
              if (!isMultiNodeBoss && !isPlayer && isSelected)
                Positioned(
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFFF5252), width: 1.0),
                      boxShadow: const [
                        BoxShadow(color: Color(0x99FF1744), blurRadius: 6),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed, size: 8, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'TARGET LOCK',
                          style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3c. Secondary Cleave / Splash Target Badge
              if (!isMultiNodeBoss && !isPlayer && isSecondaryCleave && !isSelected)
                Positioned(
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFFFB74D), width: 0.9),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66FF9100), blurRadius: 5),
                      ],
                    ),
                    child: const Text(
                      '⚔️ CLEAVE SPLASH',
                      style: TextStyle(fontSize: 6.0, fontWeight: FontWeight.w900, color: Color(0xFFFFE082), letterSpacing: 0.4),
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

              // 4b. Ghost Placement Preview when dragging a unit
              if (occupant == null && isPlayer && draggedUnitId != null && (isHovered || isDropCandidate))
                Builder(
                  builder: (context) {
                    final draggedUnit = engine.playerUnits.where((u) => u.id == draggedUnitId).firstOrNull;
                    if (draggedUnit == null) return const SizedBox.shrink();
                    return Center(
                      child: Opacity(
                        opacity: 0.55,
                        child: buildUnitMiniature(
                          draggedUnit,
                          tileWidth: tileWidth,
                          tileHeight: tileHeight,
                          colGap: 0,
                          isSelected: false,
                        ),
                      ),
                    );
                  },
                ),

              // 5. Standing Unit Miniature (Grounded on the perspective plinth)
              // Standard 1x1 units render on their plinth. Multi-node behemoths (e.g. 2x2 Gorgoroth)
              // render ONE unified giant miniature centered across their multi-node footprint in _buildSquadTerritory!
              if (occupant != null && !isMultiNodeBoss)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isPlayer) {
                        if (engine.isPreBattlePhase && selectedAlly != null && selectedAlly.id != occupant.id) {
                          // In pre-battle deployment, tapping another friendly ally swaps grid positions!
                          onMovePlayerUnit(selectedAlly.id, col, row);
                        } else {
                          onSelectPlayerUnit(occupant.id);
                        }
                      } else {
                        onSelectEnemyUnit(occupant.id);
                      }
                    },
                    onDoubleTap: () {
                      onLongPressUnit?.call(occupant);
                    },
                    onLongPress: () {
                      onLongPressUnit?.call(occupant);
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
              else if (isMultiNodeBoss)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final boss = units.firstWhere((u) => u.occupies(col, row));
                      if (isPlayer) {
                        onSelectPlayerUnit(boss.id);
                      } else {
                        onSelectEnemyUnit(boss.id);
                      }
                    },
                    onDoubleTap: () {
                      final boss = units.firstWhere((u) => u.occupies(col, row));
                      onLongPressUnit?.call(boss);
                    },
                    onLongPress: () {
                      final boss = units.firstWhere((u) => u.occupies(col, row));
                      onLongPressUnit?.call(boss);
                    },
                  ),
                )
              else if (isMoveReachable) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onMovePlayerUnit(selectedAlly.id, col, row);
                    },
                    child: Center(
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
                  ),
                ),
              ] else
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
