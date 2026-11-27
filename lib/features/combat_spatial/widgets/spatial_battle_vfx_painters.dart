part of '../spatial_battle_screen.dart';

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

/// Dynamic kinetic VFX effect rendered over the battlefield
class _CombatVfx {
  final String id;
  final Offset startOffset;
  final Offset targetOffset;
  final String? sourceUnitId;
  final String? targetUnitId;
  final Color primaryColor;
  final Color secondaryColor;
  final String type; // 'slash', 'beam', 'shockwave', 'shatter'
  final int durationMs;
  final int createdMs;

  const _CombatVfx({
    required this.id,
    required this.startOffset,
    required this.targetOffset,
    this.sourceUnitId,
    this.targetUnitId,
    required this.primaryColor,
    required this.secondaryColor,
    required this.type,
    required this.durationMs,
    required this.createdMs,
  });

  _CombatVfx copyWithOffsets(Offset newStart, Offset newTarget) {
    return _CombatVfx(
      id: id,
      startOffset: newStart,
      targetOffset: newTarget,
      sourceUnitId: sourceUnitId,
      targetUnitId: targetUnitId,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      type: type,
      durationMs: durationMs,
      createdMs: createdMs,
    );
  }
}

/// Custom painter for directional strike beams, slashes, and impact shockwaves
class _CombatVfxOverlayPainter extends CustomPainter {
  final List<_CombatVfx> effects;
  final int currentTimestampMs;

  const _CombatVfxOverlayPainter({
    required this.effects,
    required this.currentTimestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final vfx in effects) {
      final elapsed = currentTimestampMs - vfx.createdMs;
      if (elapsed < 0 || elapsed > vfx.durationMs) continue;
      final progress = (elapsed / vfx.durationMs).clamp(0.0, 1.0);

      switch (vfx.type) {
        case 'slash':
          _drawSlash(canvas, vfx, progress);
          break;
        case 'beam':
          _drawBeam(canvas, vfx, progress);
          break;
        case 'arrow':
          _drawProjectile(canvas, vfx, progress, isArrow: true);
          break;
        case 'firebolt':
          _drawProjectile(canvas, vfx, progress, isArrow: false);
          break;
        case 'shockwave':
        case 'shatter':
          _drawShockwave(canvas, vfx, progress);
          break;
        case 'heavy_slam':
          _drawHeavySlam(canvas, vfx, progress);
          break;
        case 'heal_pulse':
          _drawHealPulse(canvas, vfx, progress);
          break;
        case 'bloodnova':
          _drawBloodnova(canvas, vfx, progress);
          break;
        case 'bloodsiphon':
          _drawBloodsiphon(canvas, vfx, progress);
          break;
        case 'rune_invocation':
          _drawRuneInvocation(canvas, vfx, progress);
          break;
        case 'death_bleed':
        case 'death_solar':
        case 'death_kinetic':
        case 'death_boss':
          _drawDeathBurst(canvas, vfx, progress);
          break;
      }
    }
  }

  void _drawBloodnova(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final maxRadius = 85.0;
    final currentRadius = maxRadius * progress;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Expanding blood mist wave
    final mistPaint = Paint()
      ..color = const Color(0xFFFF1744).withAlpha((alpha * 0.45).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, currentRadius * 0.7, mistPaint);

    // Jagged crimson detonation ring
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4.5 * (1.0 - progress)).clamp(1.0, 5.0);
    canvas.drawCircle(center, currentRadius, ringPaint);

    // Detonating blood spikes radiating outwards
    final spikePaint = Paint()
      ..color = const Color(0xFFFF5252).withAlpha(alpha)
      ..strokeWidth = (3.0 * (1.0 - progress)).clamp(1.0, 3.5)
      ..strokeCap = StrokeCap.round;
    const int numSpikes = 8;
    for (int i = 0; i < numSpikes; i++) {
      final angle = (i * 3.14159 * 2) / numSpikes + (progress * 0.4);
      final rInner = currentRadius * 0.5;
      final rOuter = currentRadius * (1.1 + (i % 2 == 0 ? 0.2 : 0.05));
      final p1 = Offset(center.dx + cos(angle) * rInner, center.dy + sin(angle) * rInner);
      final p2 = Offset(center.dx + cos(angle) * rOuter, center.dy + sin(angle) * rOuter);
      canvas.drawLine(p1, p2, spikePaint);
    }
  }

  void _drawBloodsiphon(Canvas canvas, _CombatVfx vfx, double progress) {
    final start = vfx.startOffset; // Caster or ally receiving heal
    final target = vfx.targetOffset; // Bleeding enemy being siphoned
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Spiral / curved crimson tendril siphoning from target to caster
    final path = Path();
    path.moveTo(target.dx, target.dy);
    final midX = (target.dx + start.dx) * 0.5 + sin(progress * 3.14159 * 2) * 35.0;
    final midY = (target.dy + start.dy) * 0.5 - 25.0;
    path.quadraticBezierTo(midX, midY, start.dx, start.dy);

    final tendrilPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.5 * (1.0 - progress)).clamp(1.2, 4.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, tendrilPaint);

    // Inner bright leech core
    final corePaint = Paint()
      ..color = Colors.white.withAlpha((alpha * 0.75).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * (1.0 - progress)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);

    // Impact blood droplet burst on target
    final burstRadius = 16.0 * progress;
    final burstPaint = Paint()
      ..color = const Color(0xFFD50000).withAlpha((alpha * 0.8).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(target, burstRadius, burstPaint);
  }

  void _drawSlash(Canvas canvas, _CombatVfx vfx, double progress) {
    final target = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final slashLen = 62.0 + progress * 28.0;

    // 1. Wide curved crescent slash arc with outer glow + white-hot core
    final arcPath = Path();
    final p1 = Offset(target.dx - slashLen * 0.55, target.dy - slashLen * 0.42);
    final p2 = Offset(target.dx + slashLen * 0.55, target.dy + slashLen * 0.42);
    final ctrl = Offset(target.dx + slashLen * 0.25, target.dy - slashLen * 0.35);
    arcPath.moveTo(p1.dx, p1.dy);
    arcPath.quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);

    final glowPaint = Paint()
      ..color = vfx.primaryColor.withAlpha((alpha * 0.65).round())
      ..strokeWidth = (11.0 * (1.0 - progress)).clamp(2.0, 11.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arcPath, glowPaint);

    final corePaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..strokeWidth = (3.5 * (1.0 - progress)).clamp(0.8, 3.5)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arcPath, corePaint);

    // 2. Cross-slash spark & radiating impact sparks
    final crossPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.85).round())
      ..strokeWidth = (3.0 * (1.0 - progress)).clamp(0.8, 3.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(target.dx + slashLen * 0.38, target.dy - slashLen * 0.38),
      Offset(target.dx - slashLen * 0.38, target.dy + slashLen * 0.38),
      crossPaint,
    );

    final sparkPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha(alpha)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 3.14159 * 2) / 6 + 0.35;
      final r1 = 12.0 + progress * 24.0;
      final r2 = r1 + (14.0 * (1.0 - progress));
      canvas.drawLine(
        Offset(target.dx + cos(angle) * r1, target.dy + sin(angle) * r1),
        Offset(target.dx + cos(angle) * r2, target.dy + sin(angle) * r2),
        sparkPaint,
      );
    }

    // 3. Initial crisp impact flash
    if (progress < 0.35) {
      final t = progress / 0.35;
      final flashPaint = Paint()
        ..color = Colors.white.withAlpha(((1.0 - t) * 230).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, 18.0 * t, flashPaint);
    }
  }

  void _drawHeavySlam(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final radius = 16.0 + progress * 68.0;

    // Ground impact ellipse shockwave
    final rect = Rect.fromCenter(center: Offset(center.dx, center.dy + 12), width: radius * 2.1, height: radius * 0.9);
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (5.5 * (1.0 - progress)).clamp(1.2, 5.5);
    canvas.drawOval(rect, ringPaint);

    // Radiating stone/kinetic shatter shards
    final shardPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha(alpha)
      ..strokeWidth = (3.2 * (1.0 - progress)).clamp(1.0, 3.2)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 3.14159 * 2) / 8;
      final rIn = radius * 0.35;
      final rOut = radius * 0.95;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * rIn, center.dy + sin(angle) * rIn * 0.55 + 8),
        Offset(center.dx + cos(angle) * rOut, center.dy + sin(angle) * rOut * 0.55 + 8),
        shardPaint,
      );
    }

    if (progress < 0.3) {
      final flashPaint = Paint()
        ..color = Colors.white.withAlpha(((1.0 - progress / 0.3) * 220).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 22.0 * (progress / 0.3), flashPaint);
    }
  }

  void _drawHealPulse(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final rise = progress * 38.0;

    // Rising restorative emerald/gold ring
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 * (1.0 - progress)).clamp(1.0, 3.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 10 - rise), width: 46.0 + progress * 16.0, height: 18.0),
      ringPaint,
    );

    // Rising light motes
    final motePaint = Paint()
      ..color = vfx.secondaryColor.withAlpha(alpha)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final dx = (i - 2) * 11.0;
      final dy = 12.0 - rise * (0.7 + (i % 2) * 0.45);
      canvas.drawCircle(Offset(center.dx + dx, center.dy + dy), 2.5 * (1.0 - progress * 0.5), motePaint);
    }
  }

  void _drawProjectile(Canvas canvas, _CombatVfx vfx, double progress, {required bool isArrow}) {
    final start = vfx.startOffset;
    final target = vfx.targetOffset;

    // Ballistic / direct projectile flight interpolation
    final double flightT = (progress / 0.82).clamp(0.0, 1.0);
    // Slight parabolic arc
    final double arcHeight = isArrow ? -28.0 : -18.0;
    final double currentX = start.dx + (target.dx - start.dx) * flightT;
    final double currentY = start.dy + (target.dy - start.dy) * flightT + sin(flightT * 3.14159) * arcHeight;
    final currentPos = Offset(currentX, currentY);

    // Calculate heading angle
    final double dx = target.dx - start.dx;
    final double dy = target.dy - start.dy + (cos(flightT * 3.14159) * arcHeight);
    final double angle = atan2(dy, dx);

    final int alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    if (flightT < 1.0) {
      if (isArrow) {
        // High-velocity arrow / bolt with tracer tail
        final double tailLength = 22.0;
        final tailPos = Offset(currentX - cos(angle) * tailLength, currentY - sin(angle) * tailLength);

        // Motion trail
        final trailPaint = Paint()
          ..color = vfx.primaryColor.withAlpha((alpha * 0.45).round())
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tailPos, currentPos, trailPaint);

        // Arrow shaft & glowing tip
        final arrowPaint = Paint()
          ..color = Colors.white.withAlpha(alpha)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tailPos, currentPos, arrowPaint);

        // Arrow head spark
        final headPaint = Paint()
          ..color = vfx.primaryColor.withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(currentPos, 3.2, headPaint);
      } else {
        // Glowing magic firebolt / orb with smoke embers
        final orbRadius = 6.5;
        // Outer fiery halo
        final haloPaint = Paint()
          ..color = vfx.primaryColor.withAlpha((alpha * 0.55).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(currentPos, orbRadius * 1.6, haloPaint);

        // Core bolt
        final corePaint = Paint()
          ..color = vfx.secondaryColor.withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(currentPos, orbRadius, corePaint);

        // Center white-hot spark
        canvas.drawCircle(currentPos, orbRadius * 0.45, Paint()..color = Colors.white.withAlpha(alpha));

        // Trailing particles
        final trailOffset = Offset(currentX - cos(angle) * 14.0, currentY - sin(angle) * 14.0);
        canvas.drawCircle(trailOffset, orbRadius * 0.5, Paint()..color = vfx.primaryColor.withAlpha((alpha * 0.4).round()));
      }
    } else {
      // Impact burst at target location when projectile lands!
      final burstP = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      final burstRadius = (isArrow ? 18.0 : 28.0) * burstP;
      final burstAlpha = ((1.0 - burstP) * 240).round().clamp(0, 255);

      final burstPaint = Paint()
        ..color = vfx.primaryColor.withAlpha(burstAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.0 * (1.0 - burstP)).clamp(1.0, 3.5);
      canvas.drawCircle(target, burstRadius, burstPaint);

      // Core flash
      if (burstP < 0.5) {
        final coreFlashPaint = Paint()
          ..color = Colors.white.withAlpha(((1.0 - burstP / 0.5) * 220).round())
          ..style = PaintingStyle.fill;
        canvas.drawCircle(target, burstRadius * 0.6, coreFlashPaint);
      }
    }
  }

  void _drawBeam(Canvas canvas, _CombatVfx vfx, double progress) {
    final start = vfx.startOffset;
    final target = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Primary energy tracer beam
    final beamPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..strokeWidth = (5.0 * (1.0 - progress * 0.7)).clamp(1.5, 6.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, target, beamPaint);

    // Bright core line
    final corePaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..strokeWidth = 2.0 * (1.0 - progress)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, target, corePaint);

    // Target burst
    final burstRadius = 18.0 * progress;
    final burstPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.7).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(target, burstRadius, burstPaint);
  }

  void _drawShockwave(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final maxRadius = vfx.type == 'shatter' ? 65.0 : 45.0;
    final currentRadius = maxRadius * progress;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Outer shock ring
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.5 * (1.0 - progress)).clamp(0.8, 4.0);
    canvas.drawCircle(center, currentRadius, ringPaint);

    // Inner bright harmonic wave
    if (progress > 0.2) {
      final innerProgress = (progress - 0.2) / 0.8;
      final innerAlpha = ((1.0 - innerProgress) * 200).round().clamp(0, 255);
      final innerPaint = Paint()
        ..color = vfx.secondaryColor.withAlpha(innerAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius * 0.65, innerPaint);
    }

    // Shatter shards for critical armor crack
    if (vfx.type == 'shatter') {
      final shardPaint = Paint()
        ..color = const Color(0xFFFFD54F).withAlpha(alpha)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final angle = (i * 3.14159 * 2) / 6;
        final d1 = currentRadius * 0.7;
        final d2 = currentRadius * 1.15;
        final p1 = Offset(center.dx + cos(angle) * d1, center.dy + sin(angle) * d1);
        final p2 = Offset(center.dx + cos(angle) * d2, center.dy + sin(angle) * d2);
        canvas.drawLine(p1, p2, shardPaint);
      }
    }
  }

  void _drawRuneInvocation(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.startOffset; // Centered at caster plinth
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final currentRadius = 28.0 + (progress * 18.0);

    // 1. Concentric rotating invocation runic circle
    final outerRing = Paint()
      ..color = vfx.primaryColor.withAlpha((alpha * 0.85).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * (1.0 - progress * 0.5);
    canvas.drawCircle(center, currentRadius, outerRing);

    final innerRing = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.65).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, currentRadius * 0.65, innerRing);

    // 2. Rotating runic rays
    final rayPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.75).round())
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const int rayCount = 6;
    final double spinAngle = progress * 3.14159;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 3.14159 * 2) / rayCount + spinAngle;
      final p1 = Offset(center.dx + cos(angle) * (currentRadius * 0.65), center.dy + sin(angle) * (currentRadius * 0.65));
      final p2 = Offset(center.dx + cos(angle) * (currentRadius * 1.15), center.dy + sin(angle) * (currentRadius * 1.15));
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 3. Central incantation flare burst
    if (progress < 0.45) {
      final burstT = progress / 0.45;
      final flarePaint = Paint()
        ..color = Colors.white.withAlpha(((1.0 - burstT) * 220).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12.0 * burstT, flarePaint);
    }
  }

  void _drawDeathBurst(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final count = vfx.type == 'death_boss' ? 24 : 14;
    final maxDist = vfx.type == 'death_boss' ? 85.0 : 55.0;

    // Expanding shock perimeter
    final shockPaint = Paint()
      ..color = vfx.primaryColor.withAlpha((alpha * 0.7).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 3.5;
    canvas.drawCircle(center, maxDist * progress, shockPaint);

    // Radiating ember/splatter particles
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * 3.14159 / count)) + (progress * 0.8);
      final dist = (maxDist * 0.3) + (maxDist * 0.7 * progress);
      final px = center.dx + (cos(angle) * dist);
      final py = center.dy + (sin(angle) * dist * 0.55); // Isometric squash
      final pRadius = (vfx.type == 'death_boss' ? 5.5 : 3.5) * (1.0 - progress);

      final pPaint = Paint()
        ..color = (i % 2 == 0 ? vfx.primaryColor : vfx.secondaryColor).withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), max(0.8, pRadius), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CombatVfxOverlayPainter oldDelegate) {
    return true;
  }
}

class _TrajectoryData {
  final Offset sourceOffset;
  final Offset targetOffset;
  final String skillName;
  final String targetName;
  final Color color;
  final bool isSecondary;
  final bool showLabel;
  final bool isArcPath;
  final String? labelPrefix;
  final bool isCoverCord;

  const _TrajectoryData({
    required this.sourceOffset,
    required this.targetOffset,
    required this.skillName,
    required this.targetName,
    required this.color,
    this.isSecondary = false,
    this.showLabel = true,
    this.isArcPath = false,
    this.labelPrefix,
    this.isCoverCord = false,
  });
}

class _AttackTrajectoryOverlayPainter extends CustomPainter {
  final List<_TrajectoryData> trajectories;
  final double dashPhase;

  const _AttackTrajectoryOverlayPainter({
    required this.trajectories,
    this.dashPhase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final traj in trajectories) {
      _paintSingleTrajectory(canvas, traj);
    }
  }

  void _paintSingleTrajectory(Canvas canvas, _TrajectoryData traj) {
    final sourceOffset = traj.sourceOffset;
    final targetOffset = traj.targetOffset;
    final trajectoryColor = traj.color;
    final isSecondary = traj.isSecondary;

    final dx = targetOffset.dx - sourceOffset.dx;
    final dy = targetOffset.dy - sourceOffset.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;

    // Slight upward isometric curve
    final controlPoint = Offset(
      (sourceOffset.dx + targetOffset.dx) * 0.5,
      (sourceOffset.dy + targetOffset.dy) * 0.5 - min(30.0, distance * 0.12),
    );

    if (traj.isCoverCord) {
      // Defensive Vanguard Cover Cord: Glowing cyan tether connecting Frontline Vanguard to Covered Ally
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      final corePaint = Paint()
        ..color = const Color(0xFF80D8FF).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final brightCorePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;

      const int numSegments = 20;
      for (int i = 0; i < numSegments; i += 2) {
        final rawT1 = (i / numSegments + dashPhase) % 1.0;
        final rawT2 = rawT1 + (1.0 / numSegments);
        final t1 = rawT1.clamp(0.0, 1.0);
        final t2 = rawT2.clamp(0.0, 1.0);
        if (t2 <= t1) continue;

        final p1 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t1);
        final p2 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t2);

        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, corePaint);
        canvas.drawLine(p1, p2, brightCorePaint);
      }

      final anchorPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(sourceOffset, 6.0, anchorPaint);
      canvas.drawCircle(targetOffset, 6.0, anchorPaint);

      final midPoint = _evaluateBezier(sourceOffset, controlPoint, targetOffset, 0.5);
      final textSpan = const TextSpan(
        text: '🛡️ COVER (-25%)',
        style: TextStyle(
          color: Color(0xFF80D8FF),
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: midPoint,
          width: textPainter.width + 10.0,
          height: 15.0,
        ),
        const Radius.circular(3.0),
      );

      canvas.drawRRect(pillRect, Paint()..color = const Color(0xEE0B1A24));
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );

      textPainter.paint(
        canvas,
        Offset(midPoint.dx - textPainter.width * 0.5, midPoint.dy - textPainter.height * 0.5),
      );
      return;
    }

    final double alphaScale = isSecondary ? 0.65 : 1.0;

    // 1. Source node ring
    if (!isSecondary) {
      final sourcePaint = Paint()
        ..color = trajectoryColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(sourceOffset, 10.0, sourcePaint);
      canvas.drawCircle(sourceOffset, 3.5, Paint()..color = trajectoryColor.withValues(alpha: 0.9));
    }

    // 2. Translucent dashed trajectory path with animated dashPhase
    final glowPaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.25 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 4.0 : 6.0
      ..strokeCap = StrokeCap.round;

    final corePaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.85 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 1.5 : 2.2
      ..strokeCap = StrokeCap.round;

    final brightCorePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 0.7 : 1.0
      ..strokeCap = StrokeCap.round;

    // Sample quadratic bezier path points for animated dashes
    const int numSegments = 24;
    for (int i = 0; i < numSegments; i += 2) {
      final rawT1 = (i / numSegments + dashPhase) % 1.0;
      final rawT2 = rawT1 + (1.0 / numSegments);
      final t1 = rawT1.clamp(0.0, 1.0);
      final t2 = rawT2.clamp(0.0, 1.0);
      if (t2 <= t1) continue;

      final p1 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t1);
      final p2 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t2);

      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, corePaint);
      canvas.drawLine(p1, p2, brightCorePaint);
    }

    // 3. Arrowhead at target
    const double tPrev = 0.90;
    final pPrev = _evaluateBezier(sourceOffset, controlPoint, targetOffset, tPrev);
    final angle = atan2(targetOffset.dy - pPrev.dy, targetOffset.dx - pPrev.dx);
    final arrowLen = isSecondary ? 9.0 : 12.0;
    const arrowAngle = pi / 5; // 36 deg

    final arrowLeft = Offset(
      targetOffset.dx - arrowLen * cos(angle - arrowAngle),
      targetOffset.dy - arrowLen * sin(angle - arrowAngle),
    );
    final arrowRight = Offset(
      targetOffset.dx - arrowLen * cos(angle + arrowAngle),
      targetOffset.dy - arrowLen * sin(angle + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(targetOffset.dx, targetOffset.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy);

    canvas.drawPath(arrowPath, glowPaint);
    canvas.drawPath(arrowPath, corePaint);

    // 4. Target reticle diamond and crosshairs
    final double r = isSecondary ? 12.0 : 16.0;
    final reticlePath = Path()
      ..moveTo(targetOffset.dx, targetOffset.dy - r)
      ..lineTo(targetOffset.dx + r * 1.5, targetOffset.dy)
      ..lineTo(targetOffset.dx, targetOffset.dy + r)
      ..lineTo(targetOffset.dx - r * 1.5, targetOffset.dy)
      ..close();

    final reticleGlow = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.28 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 3.5 : 5.0;
    final reticleCore = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.95 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 1.3 : 1.8;

    canvas.drawPath(reticlePath, reticleGlow);
    canvas.drawPath(reticlePath, reticleCore);

    // Crosshairs
    final chPaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.9 * alphaScale)
      ..strokeWidth = isSecondary ? 1.1 : 1.5;
    canvas.drawLine(Offset(targetOffset.dx - r * 1.8, targetOffset.dy), Offset(targetOffset.dx - r * 1.2, targetOffset.dy), chPaint);
    canvas.drawLine(Offset(targetOffset.dx + r * 1.2, targetOffset.dy), Offset(targetOffset.dx + r * 1.8, targetOffset.dy), chPaint);
    canvas.drawLine(Offset(targetOffset.dx, targetOffset.dy - r * 1.4), Offset(targetOffset.dx, targetOffset.dy - r * 0.9), chPaint);
    canvas.drawLine(Offset(targetOffset.dx, targetOffset.dy + r * 0.9), Offset(targetOffset.dx, targetOffset.dy + r * 1.4), chPaint);

    // 5. Tactical Trajectory Label Pill (drawn above the target if enabled)
    if (traj.showLabel) {
      final labelCenter = Offset(
        targetOffset.dx,
        targetOffset.dy - r - 14.0,
      );

      final String prefix = traj.labelPrefix ?? '⚔️';
      final String labelText = traj.isArcPath
          ? '$prefix ${traj.skillName} • ${traj.targetName}'
          : '$prefix ${traj.skillName} • TARGET: ${traj.targetName}';

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: trajectoryColor,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: labelCenter,
          width: textPainter.width + 14.0,
          height: 18.0,
        ),
        const Radius.circular(4.0),
      );

      // Pill background & border
      canvas.drawRRect(pillRect, Paint()..color = const Color(0xEE0B0F19));
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = trajectoryColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      textPainter.paint(
        canvas,
        Offset(labelCenter.dx - textPainter.width * 0.5, labelCenter.dy - textPainter.height * 0.5),
      );
    }
  }

  static Offset _evaluateBezier(Offset p0, Offset p1, Offset p2, double t) {
    final double u = 1.0 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double ut2 = 2.0 * u * t;

    return Offset(
      uu * p0.dx + ut2 * p1.dx + tt * p2.dx,
      uu * p0.dy + ut2 * p1.dy + tt * p2.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _AttackTrajectoryOverlayPainter oldDelegate) {
    return oldDelegate.dashPhase != dashPhase ||
        oldDelegate.trajectories.length != trajectories.length ||
        true;
  }
}

/// Floating combat text with typography, color coding, and float animation
class _FloatingCombatText {
  final String id;
  final String unitId;
  final String text;
  final Color color;
  final Color borderColor;
  final double fontSize;
  final bool isCrit;
  final int createdMs;
  final int durationMs;
  final double horizontalDrift;

  const _FloatingCombatText({
    required this.id,
    required this.unitId,
    required this.text,
    required this.color,
    required this.borderColor,
    this.fontSize = 11.0,
    this.isCrit = false,
    required this.createdMs,
    this.durationMs = 1750,
    this.horizontalDrift = 0.0,
  });

  double get progress {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - createdMs;
    return (elapsed / durationMs).clamp(0.0, 1.0);
  }

  bool get isExpired => progress >= 1.0;
}

/// Dynamic ground ripple shockwave originating from high-impact strikes
class _GroundShockwaveRipple {
  final String id;
  final Offset origin;
  final String? targetUnitId;
  final Color color;
  final double maxRadius;
  final int createdMs;
  final int durationMs;

  const _GroundShockwaveRipple({
    required this.id,
    required this.origin,
    this.targetUnitId,
    required this.color,
    this.maxRadius = 120.0,
    required this.createdMs,
    this.durationMs = 600,
  });

  _GroundShockwaveRipple copyWithOrigin(Offset newOrigin) {
    return _GroundShockwaveRipple(
      id: id,
      origin: newOrigin,
      targetUnitId: targetUnitId,
      color: color,
      maxRadius: maxRadius,
      createdMs: createdMs,
      durationMs: durationMs,
    );
  }

  double get progress {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - createdMs;
    return (elapsed / durationMs).clamp(0.0, 1.0);
  }

  bool get isExpired => progress >= 1.0;
}

/// Painter for 2.5D concentric ground shockwave ripples on the isometric grid
class _GroundShockwaveRipplePainter extends CustomPainter {
  final List<_GroundShockwaveRipple> ripples;
  final int currentTimestampMs;

  const _GroundShockwaveRipplePainter({
    required this.ripples,
    required this.currentTimestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final elapsed = currentTimestampMs - ripple.createdMs;
      if (elapsed < 0 || elapsed > ripple.durationMs) continue;

      final double p = (elapsed / ripple.durationMs).clamp(0.0, 1.0);
      final double radiusX = ripple.maxRadius * p;
      final double radiusY = radiusX * 0.50; // 2:1 isometric ground perspective flattening
      final int alpha = ((1.0 - p) * 230).round().clamp(0, 255);

      // Primary expanding ground shock ellipse
      final ellipseRect = Rect.fromCenter(
        center: ripple.origin,
        width: radiusX * 2,
        height: radiusY * 2,
      );

      final shockPaint = Paint()
        ..color = ripple.color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.5 * (1.0 - p)).clamp(1.0, 4.0);
      canvas.drawOval(ellipseRect, shockPaint);

      // Inner high-energy accent ring
      if (p > 0.15) {
        final double innerP = (p - 0.15) / 0.85;
        final double innerRadiusX = ripple.maxRadius * innerP * 0.70;
        final double innerRadiusY = innerRadiusX * 0.50;
        final int innerAlpha = ((1.0 - innerP) * 180).round().clamp(0, 255);

        final innerRect = Rect.fromCenter(
          center: ripple.origin,
          width: innerRadiusX * 2,
          height: innerRadiusY * 2,
        );
        final innerPaint = Paint()
          ..color = Colors.white.withAlpha(innerAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawOval(innerRect, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GroundShockwaveRipplePainter oldDelegate) {
    return true;
  }

}

/// Custom painter rendering drifting, smoldering ash embers over downed units
class _AshEmbersDissolvePainter extends CustomPainter {
  final int timestampMs;

  const _AshEmbersDissolvePainter({
    required this.timestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Fixed pseudo-random ember particle seeds
    const int particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      // Individual cyclic phase offset (cycle = 1800ms)
      final double seed = (i * 137.5) % 1.0;
      final double cyclePhase = ((timestampMs + (i * 220)) % 1800) / 1800.0;

      // Particle rises upward from base to top
      final double x = (w * 0.15) + (w * 0.70 * ((seed + cyclePhase * 0.2) % 1.0)) + (sin(cyclePhase * 3.14159 * 2 + i) * 6.0);
      final double y = h * (1.0 - cyclePhase * 0.95);

      // Fade in at bottom, fade out near top
      final double opacity = cyclePhase < 0.2
          ? (cyclePhase / 0.2)
          : (cyclePhase > 0.7 ? (1.0 - (cyclePhase - 0.7) / 0.3) : 1.0);
      final int alpha = (opacity * 210).round().clamp(0, 255);

      final double radius = 1.0 + (i % 3) * 0.7;

      // Smoldering embers gradient (radiant ash gold & crimson)
      final Color emberColor = (i % 2 == 0) ? const Color(0xFFFF9100) : const Color(0xFFFF5252);
      final paint = Paint()
        ..color = emberColor.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, paint);

      // Core ember spark glow
      if (radius > 1.5) {
        final corePaint = Paint()
          ..color = const Color(0xFFFFE082).withAlpha((alpha * 0.85).round())
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), radius * 0.5, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AshEmbersDissolvePainter oldDelegate) {
    return true;
  }
}

/// Global arena ambient ash flakes and glowing ember particle painter
class _AtmosphericBattlefieldEmbersPainter extends CustomPainter {
  final int timestampMs;
  final bool isEnraged;

  const _AtmosphericBattlefieldEmbersPainter({
    required this.timestampMs,
    this.isEnraged = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final int count = isEnraged ? 44 : 28;
    for (int i = 0; i < count; i++) {
      final double seedX = ((i * 137.508) % 1.0);
      final double seedSpeed = 0.65 + (i % 5) * 0.20;
      final int cycleDuration = (5500 / seedSpeed).round();

      final double phase = ((timestampMs + (i * 260)) % cycleDuration) / cycleDuration.toDouble();

      final double x = (w * seedX) + (sin(phase * 3.14159 * 2 + i) * 32.0) + (phase * w * 0.12);
      final double y = h * (1.05 - phase * 1.1);

      final double opacity = phase < 0.15
          ? (phase / 0.15)
          : (phase > 0.82 ? (1.0 - (phase - 0.82) / 0.18) : 1.0);

      final double radius = 0.9 + (i % 4) * 0.65;

      Color color;
      if (isEnraged) {
        color = (i % 3 == 0)
            ? const Color(0xFFFF1744)
            : ((i % 3 == 1) ? const Color(0xFFFF5252) : const Color(0xFFFF9100));
      } else {
        color = (i % 3 == 0)
            ? const Color(0xFFFF9100)
            : ((i % 3 == 1) ? const Color(0xFFFFD54F) : const Color(0xFFFF5722));
      }

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * (isEnraged ? 0.75 : 0.50))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x % (w + 40) - 20, y), radius, paint);

      if (radius > 1.8) {
        final glowPaint = Paint()
          ..color = const Color(0xFFFFF9C4).withValues(alpha: opacity * 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x % (w + 40) - 20, y), radius * 0.45, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericBattlefieldEmbersPainter oldDelegate) {
    return true;
  }
}


class UnitStatusBadgeData {
  final String id;
  final String name;
  final String icon;
  final String summary;
  final String detail;
  final Color color;
  final Color bg;
  final bool isBuff;

  const UnitStatusBadgeData({
    required this.id,
    required this.name,
    required this.icon,
    required this.summary,
    required this.detail,
    required this.color,
    required this.bg,
    required this.isBuff,
  });
}

class SculptorDisciplineVisuals {
  final String title;
  final Color primaryColor;
  final String s1Title;
  final String s1Sub;
  final IconData s1Icon;
  final Color s1Color;
  final Color s1Border;
  final String s1Action;
  final String s1Tooltip;

  final String s2Title;
  final String s2Sub;
  final IconData s2Icon;
  final Color s2Color;
  final Color s2Border;
  final String s2Action;
  final String s2Tooltip;

  final String s3Title;
  final String s3Sub;
  final IconData s3Icon;
  final Color s3Color;
  final Color s3Border;
  final String s3Action;
  final String s3Tooltip;

  final String s4Title;
  final String s4Sub;
  final IconData s4Icon;
  final Color s4Color;
  final Color s4Border;
  final String s4Action;
  final String s4Tooltip;

  const SculptorDisciplineVisuals({
    required this.title,
    required this.primaryColor,
    required this.s1Title,
    required this.s1Sub,
    required this.s1Icon,
    required this.s1Color,
    required this.s1Border,
    required this.s1Action,
    required this.s1Tooltip,
    required this.s2Title,
    required this.s2Sub,
    required this.s2Icon,
    required this.s2Color,
    required this.s2Border,
    required this.s2Action,
    required this.s2Tooltip,
    required this.s3Title,
    required this.s3Sub,
    required this.s3Icon,
    required this.s3Color,
    required this.s3Border,
    required this.s3Action,
    required this.s3Tooltip,
    required this.s4Title,
    required this.s4Sub,
    required this.s4Icon,
    required this.s4Color,
    required this.s4Border,
    required this.s4Action,
    required this.s4Tooltip,
  });

  factory SculptorDisciplineVisuals.forGeneral(GeneralType general) {
    switch (general) {
      case GeneralType.valeria:
        return const SculptorDisciplineVisuals(
          title: 'THE ASH SCULPTOR',
          primaryColor: Color(0xFFFFD54F),
          s1Title: 'IRON SLAM',
          s1Sub: '+18 Cinders',
          s1Icon: Icons.shield,
          s1Color: Color(0xFF5D4037),
          s1Border: Color(0xFFFFD54F),
          s1Action: 'cold_iron_slam',
          s1Tooltip: 'Cold Iron Slam: Main Cinder Generator (0 Cinders, 6.0s CD). Generates +18 Cinders, shreds 20 Armor, staggers -1,500 AP.',
          s2Title: 'JUDGMENT',
          s2Sub: '30 Cinders',
          s2Icon: Icons.wb_sunny,
          s2Color: Color(0xFFF57F17),
          s2Border: Color(0xFFFFD54F),
          s2Action: 'sundering_judgment',
          s2Tooltip: 'Sundering Judgment: Consumes 30 Cinders. 180% Holy DMG, shreds 30% Armor & inflicts 3s Vulnerable.',
          s3Title: 'BULWARK',
          s3Sub: '25 Cinders',
          s3Icon: Icons.security,
          s3Color: Color(0xFF37474F),
          s3Border: Color(0xFF81D4FA),
          s3Action: 'iron_bulwark',
          s3Tooltip: 'Iron Bulwark: Consumes 25 Cinders. +35 Armor & cleanses all debuffs across squad.',
          s4Title: 'WRATH APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.flash_on,
          s4Color: Color(0xFFFFB300),
          s4Border: Color(0xFFFFF176),
          s4Action: 'wrath_of_the_dawnbound',
          s4Tooltip: 'Wrath of the Dawnbound: APEX! 280% (380% Perfect Forge Crit) Radiant Nova across all foes!',
        );
      case GeneralType.vladislav:
        return const SculptorDisciplineVisuals(
          title: 'THE ASH SCULPTOR',
          primaryColor: Color(0xFFFF1744),
          s1Title: 'SIPHON REND',
          s1Sub: '+18 Cinders',
          s1Icon: Icons.bloodtype,
          s1Color: Color(0xFF880E4F),
          s1Border: Color(0xFFFF5252),
          s1Action: 'siphon_rend',
          s1Tooltip: 'Siphon Rend: Main Cinder Generator (0 Cinders, 6.0s CD). Generates +18 Cinders, 135% ATK, leeches 40% DMG dealt as HP.',
          s2Title: 'CRIMSON BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.whatshot,
          s2Color: Color(0xFFC2185B),
          s2Border: Color(0xFFFF4081),
          s2Action: 'crimson_brand',
          s2Tooltip: 'Crimson Brand: Consumes 30 Cinders. 165% ATK + 3 Bleeds, detonates active bleeds for 2x DMG.',
          s3Title: 'VEIN TETHER',
          s3Sub: '25 Cinders',
          s3Icon: Icons.all_inclusive,
          s3Color: Color(0xFF4A148C),
          s3Border: Color(0xFFEA80FC),
          s3Action: 'vein_tether',
          s3Tooltip: 'Vein Tether: Consumes 25 Cinders. +2,500 AP haste & +25 Aegis to all allies.',
          s4Title: 'EXSANGUINATION',
          s4Sub: '80 Cinders',
          s4Icon: Icons.storm,
          s4Color: Color(0xFFB71C1C),
          s4Border: Color(0xFFFF1744),
          s4Action: 'exsanguination_apex',
          s4Tooltip: 'Exsanguination Apex: APEX! 260% (360% Forge Crit) Blood Tempest, executes targets below 25% HP!',
        );
      case GeneralType.morrigan:
        return const SculptorDisciplineVisuals(
          title: 'THE ASH SCULPTOR',
          primaryColor: Color(0xFF00E676),
          s1Title: 'CORROSIVE TOUCH',
          s1Sub: '+18 Cinders',
          s1Icon: Icons.coronavirus,
          s1Color: Color(0xFF1B5E20),
          s1Border: Color(0xFF69F0AE),
          s1Action: 'corrosive_touch',
          s1Tooltip: 'Corrosive Touch: Main Cinder Generator (0 Cinders, 6.0s CD). Generates +18 Cinders, 130% ATK, 2 Poison, -1,000 AP stagger.',
          s2Title: 'MIASMIC BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.bubble_chart,
          s2Color: Color(0xFF2E7D32),
          s2Border: Color(0xFF00E676),
          s2Action: 'miasmic_brand',
          s2Tooltip: 'Miasmic Brand: Consumes 30 Cinders. 160% ATK, plagues target column with 3 Poison & Vulnerable.',
          s3Title: 'BONE WARD',
          s3Sub: '25 Cinders',
          s3Icon: Icons.healing,
          s3Color: Color(0xFF004D40),
          s3Border: Color(0xFF64FFDA),
          s3Action: 'bone_ward',
          s3Tooltip: 'Bone Ward: Consumes 25 Cinders. 30% max HP ossuary shields to all living allies.',
          s4Title: 'SPORE APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.eco,
          s4Color: Color(0xFF00C853),
          s4Border: Color(0xFFB9F6CA),
          s4Action: 'cataclysmic_spore',
          s4Tooltip: 'Cataclysmic Spore: APEX! 240% (340% Forge Crit) Nature eruption, deals bonus damage to poisoned foes!',
        );
      case GeneralType.malakor:
        return const SculptorDisciplineVisuals(
          title: 'THE ASH SCULPTOR',
          primaryColor: Color(0xFFFF6D00),
          s1Title: 'CLEAVE',
          s1Sub: '+18 Cinders',
          s1Icon: Icons.sports_mma,
          s1Color: Color(0xFFB3261E),
          s1Border: Color(0xFFFF8A80),
          s1Action: 'forge_cleave',
          s1Tooltip: 'Forge Cleave: Main Cinder Generator (0 Cinders, 6.0s CD). Generates +18 Cinders, 140% ATK heavy strike (+1 Bleed).',
          s2Title: 'BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.local_fire_department,
          s2Color: Color(0xFFC2185B),
          s2Border: Color(0xFFFF4081),
          s2Action: 'sundering_brand',
          s2Tooltip: 'Sundering Brand: Consumes 30 Cinders. 175% ATK, shatters 50% Armor & triggers Crypt Stalker ambush!',
          s3Title: 'BASTION',
          s3Sub: '25 Cinders',
          s3Icon: Icons.shield,
          s3Color: Color(0xFF00695C),
          s3Border: Color(0xFF00BFA5),
          s3Action: 'obsidian_bastion',
          s3Tooltip: 'Obsidian Bastion: Consumes 25 Cinders. Shields Sculptor and retinue with Aegis barriers.',
          s4Title: 'PYRE APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.bolt,
          s4Color: Color(0xFFFF6D00),
          s4Border: Color(0xFFFFD54F),
          s4Action: 'cataclysmic_pyre',
          s4Tooltip: 'Cataclysmic Pyre: APEX! 250% (350% Perfect Forge Crit) Fire Nova across all enemy ranks!',
        );
    }
  }
}

class _StaggeredMeteorBarrage extends StatefulWidget {
  final List<Alignment> targetAlignments;
  final List<Offset>? targetOffsets;
  final String assetPath;

  const _StaggeredMeteorBarrage({
    super.key,
    this.targetAlignments = const [],
    this.targetOffsets,
    this.assetPath = 'assets/images/Spells/meteor storm.png',
  });

  @override
  State<_StaggeredMeteorBarrage> createState() => _StaggeredMeteorBarrageState();
}

class _StaggeredMeteorBarrageState extends State<_StaggeredMeteorBarrage> {
  late final List<bool> _active;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    final count = widget.targetOffsets?.length ?? widget.targetAlignments.length;
    _active = List<bool>.generate(count, (i) => i == 0);
    for (int i = 1; i < count; i++) {
      _timers.add(Timer(Duration(milliseconds: i * 140), () {
        if (mounted) {
          setState(() => _active[i] = true);
        }
      }));
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offsets = widget.targetOffsets;
    if (offsets != null && offsets.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < offsets.length; i++)
            if (i < _active.length && _active[i])
              Positioned(
                left: offsets[i].dx - 92.5,
                top: offsets[i].dy - 82.0,
                width: 185,
                height: 150,
                child: SpriteSheetAnimation(
                  key: ValueKey('meteor_burst_2d_${widget.assetPath}_$i'),
                  assetPath: widget.assetPath,
                  columns: 3,
                  rows: 4,
                  totalFrames: 12,
                  duration: const Duration(milliseconds: 900),
                  loop: false,
                  fit: BoxFit.contain,
                ),
              ),
        ],
      );
    }
    return Stack(
      children: [
        for (int i = 0; i < widget.targetAlignments.length; i++)
          if (i < _active.length && _active[i])
            Align(
              alignment: widget.targetAlignments[i],
              child: SizedBox(
                width: 185,
                height: 150,
                child: SpriteSheetAnimation(
                  key: ValueKey('meteor_burst_${widget.assetPath}_$i'),
                  assetPath: widget.assetPath,
                  columns: 3,
                  rows: 4,
                  totalFrames: 12,
                  duration: const Duration(milliseconds: 900),
                  loop: false,
                  fit: BoxFit.contain,
                ),
              ),
            ),
      ],
    );
  }
}
