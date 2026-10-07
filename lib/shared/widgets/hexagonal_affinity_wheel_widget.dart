import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';

class HexagonalAffinityWheelWidget extends StatelessWidget {
  final Archetype? activeArchetype;
  final ValueChanged<Archetype>? onSelectArchetype;
  final double size;

  const HexagonalAffinityWheelWidget({
    super.key,
    this.activeArchetype,
    this.onSelectArchetype,
    this.size = 240.0,
  });

  static Color getArchetypeColor(Archetype type) {
    switch (type) {
      case Archetype.juggernaut:
        return const Color(0xFF1E88E5); // Sapphire / Armor
      case Archetype.assassin:
        return const Color(0xFFE53935); // Crimson / Blood
      case Archetype.marksman:
        return const Color(0xFF43A047); // Emerald / Precision
      case Archetype.skirmisher:
        return const Color(0xFFFB8C00); // Amber / Swift
      case Archetype.support:
        return const Color(0xFF00ACC1); // Cyan / Restoration
      case Archetype.occultist:
        return const Color(0xFF8E24AA); // Amethyst / Void
    }
  }

  static IconData getArchetypeIcon(Archetype type) {
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

  static String getArchetypeAbbr(Archetype type) {
    switch (type) {
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

  @override
  Widget build(BuildContext context) {
    final double radius = (size / 2) - 26;
    final centerOffset = Offset(size / 2, size / 2);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Connecting Ring & Vectors
          CustomPaint(
            size: Size(size, size),
            painter: _HexagonWheelPainter(
              activeArchetype: activeArchetype,
              radius: radius,
            ),
          ),

          // Center Aperture / Sigil Core
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4A4A58), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/crucible_aperture.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF14141B),
                  child: const Icon(Icons.sync, color: Color(0xFFE5A93C), size: 22),
                ),
              ),
            ),
          ),

          // 6 Hexagonal Nodes
          ...Archetype.values.map((role) {
            // Angle calculation: 0 (Juggernaut) at top (-pi/2), then clockwise by +pi/3 (60 deg)
            final double angle = (-pi / 2) + (role.index * (2 * pi / 6));
            final double x = centerOffset.dx + (radius * cos(angle));
            final double y = centerOffset.dy + (radius * sin(angle));

            final bool isSelected = activeArchetype == role;
            final bool isPrey = activeArchetype != null &&
                CombatMath.getPreyArchetype(activeArchetype!) == role;
            final bool isPredator = activeArchetype != null &&
                CombatMath.getPredatorArchetype(activeArchetype!) == role;

            final color = getArchetypeColor(role);

            return Positioned(
              left: x - 22,
              top: y - 22,
              child: GestureDetector(
                onTap: () => onSelectArchetype?.call(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.35)
                        : const Color(0xFF121218),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE5A93C)
                          : (isPrey
                              ? const Color(0xFF81C784)
                              : (isPredator ? const Color(0xFFEF5350) : color)),
                      width: isSelected ? 2.5 : (isPrey || isPredator ? 2.0 : 1.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFFE5A93C).withValues(alpha: 0.5)
                            : (isPrey
                                ? const Color(0xFF81C784).withValues(alpha: 0.4)
                                : (isPredator
                                    ? const Color(0xFFEF5350).withValues(alpha: 0.4)
                                    : Colors.black)),
                        blurRadius: isSelected ? 10 : 4,
                        spreadRadius: isSelected ? 1.5 : 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        getArchetypeIcon(role),
                        size: 16,
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        getArchetypeAbbr(role),
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HexagonWheelPainter extends CustomPaintPainter {
  final Archetype? activeArchetype;
  final double radius;

  _HexagonWheelPainter({
    required this.activeArchetype,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintBase = Paint()
      ..color = const Color(0xFF2B2B36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw connecting perimeter edges
    final points = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final double angle = (-pi / 2) + (i * (2 * pi / 6));
      points.add(Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)));
    }

    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, paintBase);

    // If an archetype is highlighted, draw directional vectors:
    // 1. Vector to PREY (clockwise +1) in Vibrant Green
    // 2. Vector from PREDATOR (counter-clockwise -1) in Crimson
    if (activeArchetype != null) {
      final int idx = activeArchetype!.index;
      final int preyIdx = (idx + 1) % 6;
      final int predIdx = (idx + 5) % 6;

      // Prey vector (Strong -> +30%)
      final preyPaint = Paint()
        ..color = const Color(0xFF81C784)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawLine(points[idx], points[preyIdx], preyPaint);

      // Predator vector (Weak <- -25%)
      final predPaint = Paint()
        ..color = const Color(0xFFEF5350)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(points[predIdx], points[idx], predPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonWheelPainter oldDelegate) {
    return oldDelegate.activeArchetype != activeArchetype || oldDelegate.radius != radius;
  }
}

abstract class CustomPaintPainter extends CustomPainter {}
