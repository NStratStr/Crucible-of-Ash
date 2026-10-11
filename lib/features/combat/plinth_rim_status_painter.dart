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
  final String? factionName;
  final bool isBurning;
  final bool isFrozen;
  final double hpRatio;
  final double tmRatio;
  final bool showHpBar;
  final bool showTmBar;
  final bool isDamaged;
  final bool isAttacking;

  const PlinthRimStatusPainter({
    required this.bleedStacks,
    required this.blightStacks,
    required this.shieldIntegrity,
    required this.isAlive,
    this.plinthMaterial = PlinthMaterial.slate,
    this.factionName,
    this.isBurning = false,
    this.isFrozen = false,
    this.hpRatio = 1.0,
    this.tmRatio = 0.0,
    this.showHpBar = true,
    this.showTmBar = true,
    this.isDamaged = false,
    this.isAttacking = false,
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

      // GDD v2.7 Sec 2.2: Faction Grounding Inscriptions
      // - Ash Legion: Welded cold-iron rims on weathered fortress flagstone (notched bolt pips)
      // - Crypt Stalkers: Weeping arterial stone basins with creeping black moss (crimson weeping fissures)
      // - Corrupted Beasts: Trampled black earth with broken bone chips and toxic roots (bone-white flecks)
      // - Occult Void Cult: Obsidian discs etched with hovering, rift-glass violet runes (arc runes)
      if (factionName != null) {
        if (factionName == 'Ash Legion') {
          final Paint boltPaint = Paint()
            ..color = const Color(0xFFCFD8DC).withValues(alpha: 0.8)
            ..style = PaintingStyle.fill;
          for (final angle in [-math.pi * 0.75, -math.pi * 0.25, math.pi * 0.25, math.pi * 0.75]) {
            final double bx = center.dx + rx * math.cos(angle);
            final double by = center.dy + ry * math.sin(angle);
            canvas.drawCircle(Offset(bx, by), 1.5, boltPaint);
          }
        } else if (factionName == 'Crypt Stalkers') {
          final Paint mossPaint = Paint()
            ..color = const Color(0xFF1B5E20).withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawArc(ovalRect, math.pi * 0.35, math.pi * 0.30, false, mossPaint);
          final Paint arterialPaint = Paint()
            ..color = const Color(0xFFB71C1C).withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawArc(ovalRect, -math.pi * 0.65, math.pi * 0.30, false, arterialPaint);
        } else if (factionName == 'Corrupted Beasts') {
          final Paint rootPaint = Paint()
            ..color = const Color(0xFF3E2723).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawArc(ovalRect, math.pi * 0.15, math.pi * 0.70, false, rootPaint);
          final Paint boneChipPaint = Paint()
            ..color = const Color(0xFFEFEBE9).withValues(alpha: 0.7)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(center.dx - rx * 0.6, center.dy + ry * 0.7), 1.4, boneChipPaint);
          canvas.drawCircle(Offset(center.dx + rx * 0.6, center.dy + ry * 0.7), 1.4, boneChipPaint);
        } else if (factionName == 'Occult Void Cult') {
          final Paint riftRunePaint = Paint()
            ..color = const Color(0xFFE040FB).withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6;
          canvas.drawArc(ovalRect, -math.pi * 0.90, math.pi * 0.40, false, riftRunePaint);
          canvas.drawArc(ovalRect, math.pi * 0.10, math.pi * 0.40, false, riftRunePaint);
        }
      }
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

    // 6. GDD v2.8 Tabletop Miniature Inlaid Curved Health Bar Arc (Lower Front Rim)
    if (isAlive && showHpBar) {
      final double clampedHp = hpRatio.clamp(0.0, 1.0);
      final Rect hpRect = Rect.fromCenter(
        center: center,
        width: size.width + 6.0,
        height: size.height + 5.0,
      );

      // Total sweep angle along the front edge of the plinth ellipse (bottom curve)
      const double startAngle = math.pi * 0.92;
      const double totalSweep = math.pi * 0.84;

      // Dark iron beveled background track
      final Paint hpBevelPaint = Paint()
        ..color = const Color(0xFF454558).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.4;
      canvas.drawArc(hpRect, math.pi * 0.08, totalSweep, false, hpBevelPaint);

      final Paint hpTrackPaint = Paint()
        ..color = const Color(0xFF101016)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.2;
      canvas.drawArc(hpRect, math.pi * 0.08, totalSweep, false, hpTrackPaint);

      if (clampedHp > 0) {
        Color hpColor;
        Color hpGlowColor;
        if (clampedHp > 0.45) {
          hpColor = const Color(0xFF00E676); // High-contrast Emerald Green
          hpGlowColor = const Color(0xFF69F0AE);
        } else if (clampedHp > 0.20) {
          hpColor = const Color(0xFFFFB300); // Amber warning
          hpGlowColor = const Color(0xFFFFD54F);
        } else {
          hpColor = const Color(0xFFFF1744); // Critical Crimson
          hpGlowColor = const Color(0xFFFF5252);
        }

        if (isDamaged) {
          hpColor = const Color(0xFFFF1744);
          hpGlowColor = Colors.white;
        }

        final double filledSweep = totalSweep * clampedHp;

        // Vivid liquid health glow
        final Paint hpGlowPaint = Paint()
          ..color = hpGlowColor.withValues(alpha: isDamaged ? 0.90 : 0.55)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6.8;
        canvas.drawArc(hpRect, startAngle, -filledSweep, false, hpGlowPaint);

        // Core liquid health arc
        final Paint hpFillPaint = Paint()
          ..color = hpColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4.2;
        canvas.drawArc(hpRect, startAngle, -filledSweep, false, hpFillPaint);
      }
    }

    // 7. GDD v2.8 Tabletop Miniature Inlaid Curved AP / Turn Meter Arc (Concentric Inner Rim)
    if (isAlive && showTmBar) {
      final double clampedTm = tmRatio.clamp(0.0, 1.0);
      final Rect apRect = Rect.fromCenter(
        center: center,
        width: size.width - 4.0,
        height: size.height - 3.0,
      );

      const double apStartAngle = math.pi * 0.90;
      const double apTotalSweep = math.pi * 0.80;

      // Dark background track groove
      final Paint apTrackPaint = Paint()
        ..color = const Color(0xFF08121A)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.6;
      canvas.drawArc(apRect, math.pi * 0.10, apTotalSweep, false, apTrackPaint);

      if (clampedTm > 0) {
        final bool isReady = clampedTm >= 0.999;
        final Color apColor = isReady ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF);
        final double filledApSweep = apTotalSweep * clampedTm;

        // Outer glow
        final Paint apGlowPaint = Paint()
          ..color = apColor.withValues(alpha: isReady ? 0.85 : 0.45)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4.8;
        canvas.drawArc(apRect, apStartAngle, -filledApSweep, false, apGlowPaint);

        // Core cyan / gold AP arc
        final Paint apFillPaint = Paint()
          ..color = apColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.6;
        canvas.drawArc(apRect, apStartAngle, -filledApSweep, false, apFillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PlinthRimStatusPainter oldDelegate) {
    return oldDelegate.bleedStacks != bleedStacks ||
        oldDelegate.blightStacks != blightStacks ||
        oldDelegate.shieldIntegrity != shieldIntegrity ||
        oldDelegate.isAlive != isAlive ||
        oldDelegate.plinthMaterial != plinthMaterial ||
        oldDelegate.factionName != factionName ||
        oldDelegate.isBurning != isBurning ||
        oldDelegate.isFrozen != isFrozen ||
        oldDelegate.hpRatio != hpRatio ||
        oldDelegate.tmRatio != tmRatio ||
        oldDelegate.showHpBar != showHpBar ||
        oldDelegate.showTmBar != showTmBar ||
        oldDelegate.isDamaged != isDamaged ||
        oldDelegate.isAttacking != isAttacking;
  }
}
