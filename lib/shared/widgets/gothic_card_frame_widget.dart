import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../models/unit_entity.dart';

class GothicCardFrameWidget extends StatelessWidget {
  final UnitEntity unit;
  final double width;
  final double height;
  final bool showStats;
  final bool isSelected;
  final VoidCallback? onTap;

  const GothicCardFrameWidget({
    super.key,
    required this.unit,
    this.width = 160,
    this.height = 230,
    this.showStats = true,
    this.isSelected = false,
    this.onTap,
  });

  Color _getArchetypeColor(Archetype type) {
    switch (type) {
      case Archetype.juggernaut:
        return const Color(0xFFC62828);
      case Archetype.assassin:
        return const Color(0xFF6A1B9A);
      case Archetype.marksman:
        return const Color(0xFF2E7D32);
      case Archetype.skirmisher:
        return const Color(0xFFE65100);
      case Archetype.support:
        return const Color(0xFF00838F);
      case Archetype.occultist:
        return const Color(0xFF4527A0);
    }
  }

  IconData _getArchetypeIcon(Archetype type) {
    switch (type) {
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

  @override
  Widget build(BuildContext context) {
    final themeColor = _getArchetypeColor(unit.archetype);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF2B2B36),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFFE5A93C).withValues(alpha: 0.4)
                  : Colors.black54,
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              // 1. Character Portrait Artwork
              Positioned.fill(
                child: Image.asset(
                  unit.effectiveAvatarAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1B1B22),
                      child: Icon(
                        _getArchetypeIcon(unit.archetype),
                        color: themeColor.withValues(alpha: 0.5),
                        size: 48,
                      ),
                    );
                  },
                ),
              ),

              // 2. Carved Iron Gothic Frame Overlay (with transparent window)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/card_frame.png',
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              // 3. Subtle bottom shadow for name readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 54,
                child: DecoratedBox(
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

              // 3. Top Badges: Archetype (Left) & Generation (Right)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: themeColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getArchetypeIcon(unit.archetype), color: themeColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        unit.archetype.name.toUpperCase(),
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE5A93C), width: 1),
                  ),
                  child: Text(
                    'GEN ${unit.generation}',
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // 4. Bottom Info Banner: Name, Level, Stats
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lv. ${unit.level}/${unit.maxLevel}',
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          unit.isVanguard ? 'VANGUARD' : 'ARCANUM',
                          style: const TextStyle(
                            color: Color(0xFF8E8EA0),
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (showStats) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E26).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'HP ${unit.maxHp}',
                              style: const TextStyle(color: Colors.white70, fontSize: 8),
                            ),
                            Text(
                              'ATK ${unit.attack}',
                              style: const TextStyle(color: Color(0xFFEF5350), fontSize: 8),
                            ),
                            Text(
                              'DEF ${unit.defense}',
                              style: const TextStyle(color: Color(0xFF81C784), fontSize: 8),
                            ),
                            Text(
                              'SPD ${unit.speed}',
                              style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
