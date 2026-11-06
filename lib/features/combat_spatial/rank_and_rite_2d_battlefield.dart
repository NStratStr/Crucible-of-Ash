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
    // Slight rank-to-rank horizontal overlap so formations look tight and compact like Wartune
    final double rankOverlapMargin = -(tileWidth * 0.16).clamp(8.0, 24.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: rankOrder.asMap().entries.map((entry) {
        final int index = entry.key;
        final int row = entry.value;

        // Natural 2.5D Wartune Stage Depth Staggering:
        // Frontline (Row 0): at bottom ground baseline (offset 0)
        // Midline (Row 1): stepped back into terrain (-14px)
        // Backline (Row 2): stepped deepest into horizon (-28px)
        final double rankDepthOffsetY = row == 0 ? 0.0 : (row == 1 ? -14.0 : -28.0);

        // Z-Index ordering so Frontline units paint in front of Midline/Backline units
        // Row 0 = priority 3 (drawn on top), Row 1 = priority 2, Row 2 = priority 1
        final int rankZIndex = (row == 0 ? 3 : (row == 1 ? 2 : 1));

        return Transform.translate(
          offset: Offset(0, rankDepthOffsetY),
          child: Container(
            margin: EdgeInsets.only(
              left: index > 0 ? (isPlayer ? 0 : rankOverlapMargin) : 0,
              right: index > 0 ? (isPlayer ? rankOverlapMargin : 0) : 0,
            ),
            child: SizedBox(
              width: tileWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (col) {
                  return _build2DGridTile(col: col, row: row, isPlayer: isPlayer);
                }),
              ),
            ),
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
    final bool isSecondaryCleave = occupant != null && !isPlayer && (secondaryTargetEnemyIds?.contains(occupant.id) ?? false);

    // Vanguard Cover check (Rank & Rite Spec Sec 3)
    final bool hasVanguardCover = isPlayer && occupant != null && engine.isCoveredByVanguard(occupant, trajectory: AttackTrajectory.directPhysical);

    // Pre-battle projected attacker and flank status
    final projectedAttacker = engine.playerUnits.where(
      (u) => u.isAlive && u.occupiedNodes.isNotEmpty && engine.resolveProjectedTarget(u)?.id == occupant?.id,
    ).firstOrNull;
    final bool isTargetedInPreBattle = engine.isPreBattlePhase && !isPlayer && projectedAttacker != null && occupant != null;
    final bool isFlankedInPreBattle = isTargetedInPreBattle && !engine.isCoveredByVanguard(occupant!, trajectory: AttackTrajectory.flanking);

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
        if (isTelegraphed) {
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
          plinthRimColor = const Color(0xFF00E676);
          plinthGlowColor = const Color(0xFF00E676).withValues(alpha: 0.4);
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
                      width: isTurnActiveUnit ? 2.4 : ((isSelected || isDropCandidate || isHovered) ? 1.8 : 1.0),
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
                          blurRadius: isTurnActiveUnit ? 18 : (isSelected ? 12 : 6),
                          spreadRadius: isTurnActiveUnit ? 3 : (isSelected ? 2 : 0),
                        ),
                    ],
                  ),
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

              // 3. Vanguard Cover Badge (Rank & Rite Spec Sec 3)
              if (hasVanguardCover)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 4),
                      ],
                    ),
                    child: const Text(
                      '🛡️ COVER -25%',
                      style: TextStyle(fontSize: 6.8, color: Color(0xFF80D8FF), fontWeight: FontWeight.w900),
                    ),
                  ),
                ),

              // 3b-pre. Pre-Battle Projected Target & Flank Reticle Badge
              if (isTargetedInPreBattle && !isSelected)
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
              if (!isPlayer && isSelected && occupant != null)
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
              if (!isPlayer && isSecondaryCleave && !isSelected && occupant != null)
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
