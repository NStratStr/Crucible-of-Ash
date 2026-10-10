import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';

/// GDD v2.6 Section 4: Procedural Compositing Rules
/// - Modular Plinth Material Base Rim (Obsidian, Bone, Iron, Gold, Slate)
/// - Left arc: Bleed notches (up to 10 stacks, crimson #FF1744)
/// - Right arc: Blight/Poison pips (emerald #00E676)
/// - Aegis Barrier Ring: Concentric gold radial ring (#FFD54F) tracking shield integrity
class PlinthRimStatusPainter extends CustomPainter {
  final int bleedStacks;
  final int blightStacks;
  final double shieldIntegrity; // 0.0 to 1.0 (shield points / maxHp)
  final bool isAlive;
  final PlinthMaterial plinthMaterial;
  final bool isBurning;
  final bool isFrozen;

  const PlinthRimStatusPainter({
    required this.bleedStacks,
    required this.blightStacks,
    required this.shieldIntegrity,
    required this.isAlive,
    this.plinthMaterial = PlinthMaterial.slate,
    this.isBurning = false,
    this.isFrozen = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ovalRect = Offset.zero & size;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double rx = size.width / 2;
    final double ry = size.height / 2;

    // 0. Base Plinth Rim Material Tint & Texture Line
    if (isAlive) {
      Color materialRimColor;
      switch (plinthMaterial) {
        case PlinthMaterial.obsidian:
          materialRimColor = const Color(0xFFBA68C8); // Volcanic glass purple
          break;
        case PlinthMaterial.bone:
          materialRimColor = const Color(0xFFD7CCC8); // Calcified crypt bone
          break;
        case PlinthMaterial.iron:
          materialRimColor = const Color(0xFF90A4AE); // Cold iron steel
          break;
        case PlinthMaterial.gold:
          materialRimColor = const Color(0xFFFFD54F); // Ornate gold
          break;
        case PlinthMaterial.slate:
        default:
          materialRimColor = const Color(0xFF546E7A); // Ashen slate
          break;
      }

      final Paint rimPaint = Paint()
        ..color = materialRimColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawOval(ovalRect, rimPaint);
    }

    if (!isAlive && bleedStacks == 0 && blightStacks == 0 && shieldIntegrity <= 0) {
      return;
    }

    // 1. Aegis Barrier: Concentric Gold Radial Ring
    if (shieldIntegrity > 0 && isAlive) {
      final double clampedShield = shieldIntegrity.clamp(0.0, 1.0);
      final Rect outerRect = Rect.fromCenter(
        center: center,
        width: size.width + 8.0,
        height: size.height + 6.0,
      );

      // Subtle outer gold aura
      final Paint auraPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.28 * clampedShield)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawOval(outerRect, auraPaint);

      // Crisp gold shield barrier ring
      final Paint shieldPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawOval(outerRect, shieldPaint);

      // Arc portion indicating shield ratio if damaged, or full ring
      final Paint shieldSweepPaint = Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2;

      // Draw sweep from top clockwise
      final double sweepAngle = 2 * math.pi * clampedShield;
      canvas.drawArc(outerRect, -math.pi / 2, sweepAngle, false, shieldSweepPaint);
    }

    // 2. Left Arc: Bleed Notches (Crimson #FF1744)
    if (bleedStacks > 0) {
      final int count = bleedStacks.clamp(1, 10);
      final Paint bleedPaint = Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.fill;

      final Paint bleedGlowPaint = Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      // Left arc spans between ~110 degrees to ~250 degrees (left side of ellipse)
      // math.pi/2 is bottom, math.pi is left, 3*math.pi/2 is top
      const double startAngle = math.pi * 0.70;
      const double endAngle = math.pi * 1.30;
      final double angleStep = count > 1 ? (endAngle - startAngle) / (count - 1) : 0.0;

      for (int i = 0; i < count; i++) {
        final double theta = count > 1 ? startAngle + i * angleStep : math.pi;
        final double pipX = center.dx + rx * math.cos(theta);
        final double pipY = center.dy + ry * math.sin(theta);
        final Offset pipCenter = Offset(pipX, pipY);

        canvas.drawCircle(pipCenter, 3.2, bleedGlowPaint);
        canvas.drawCircle(pipCenter, 1.8, bleedPaint);
      }
    }

    // 3. Right Arc: Blight/Poison Pips (Emerald #00E676)
    if (blightStacks > 0) {
      final int count = blightStacks.clamp(1, 10);
      final Paint blightPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..style = PaintingStyle.fill;

      final Paint blightGlowPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      // Right arc spans between -0.30*pi to +0.30*pi (around 0 radians / right side of ellipse)
      const double startAngle = -math.pi * 0.30;
      const double endAngle = math.pi * 0.30;
      final double angleStep = count > 1 ? (endAngle - startAngle) / (count - 1) : 0.0;

      for (int i = 0; i < count; i++) {
        final double theta = count > 1 ? startAngle + i * angleStep : 0.0;
        final double pipX = center.dx + rx * math.cos(theta);
        final double pipY = center.dy + ry * math.sin(theta);
        final Offset pipCenter = Offset(pipX, pipY);

        canvas.drawCircle(pipCenter, 3.2, blightGlowPaint);
        canvas.drawCircle(pipCenter, 1.8, blightPaint);
      }
    }

    // 4. Burn Status: Fiery Orange Arc Flame Aura (#FF6D00)
    if (isBurning && isAlive) {
      final Paint burnPaint = Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final Paint burnGlow = Paint()
        ..color = const Color(0xFFFFAB40).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      // Spans upper arc (-math.pi*0.80 to -math.pi*0.20)
      canvas.drawArc(ovalRect, -math.pi * 0.80, math.pi * 0.60, false, burnGlow);
      canvas.drawArc(ovalRect, -math.pi * 0.80, math.pi * 0.60, false, burnPaint);
    }

    // 5. Freeze Status: Crystalline Frost Cyan Glaze Rim (#00E5FF)
    if (isFrozen && isAlive) {
      final Paint frostGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;

      canvas.drawOval(ovalRect, frostGlow);
    }
  }

  @override
  bool shouldRepaint(covariant PlinthRimStatusPainter oldDelegate) {
    return oldDelegate.bleedStacks != bleedStacks ||
        oldDelegate.blightStacks != blightStacks ||
        oldDelegate.shieldIntegrity != shieldIntegrity ||
        oldDelegate.isAlive != isAlive ||
        oldDelegate.plinthMaterial != plinthMaterial ||
        oldDelegate.isBurning != isBurning ||
        oldDelegate.isFrozen != isFrozen;
  }
}
