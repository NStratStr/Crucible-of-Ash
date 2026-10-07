import 'dart:math';
import 'package:flutter/material.dart';

class AmbientParticle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double horizontalWobble;

  AmbientParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.horizontalWobble,
  });

  static AmbientParticle random(Random rng) {
    return AmbientParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.5 + rng.nextDouble() * 2.5,
      speed: 0.04 + rng.nextDouble() * 0.08,
      opacity: 0.2 + rng.nextDouble() * 0.6,
      horizontalWobble: (rng.nextDouble() - 0.5) * 0.05,
    );
  }
}

class LivingAtmosphereBackground extends StatefulWidget {
  final String imageAsset;
  final Widget child;
  final bool enableBreathing;
  final bool enableFlicker;
  final Color flickerColor;
  final Alignment flickerCenter;
  final bool enableParticles;
  final Color particleColor;
  final int particleCount;
  final double vignetteOpacity;
  final bool? isLiveAnimation;

  const LivingAtmosphereBackground({
    super.key,
    required this.imageAsset,
    required this.child,
    this.enableBreathing = true,
    this.enableFlicker = false,
    this.flickerColor = const Color(0xFFFF5722),
    this.flickerCenter = const Alignment(0.0, 0.1),
    this.enableParticles = true,
    this.particleColor = const Color(0xFFFF7043),
    this.particleCount = 24,
    this.vignetteOpacity = 0.72,
    this.isLiveAnimation,
  });

  @override
  State<LivingAtmosphereBackground> createState() => _LivingAtmosphereBackgroundState();
}

class _LivingAtmosphereBackgroundState extends State<LivingAtmosphereBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<AmbientParticle> _particles;
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    final bool isTestBinding = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final bool shouldLoop = widget.isLiveAnimation ?? !isTestBinding;

    if (shouldLoop && (widget.enableBreathing || widget.enableFlicker || widget.enableParticles)) {
      _animController.repeat();
    }

    _particles = List.generate(
      widget.particleCount,
      (_) => AmbientParticle.random(_rng),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Ambient Base Artwork with Idle Breathing Motion
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final t = _animController.value;
            // Smooth sinusoidal idle breathing (1.00 -> 1.025 scale)
            final double breathScale = widget.enableBreathing
                ? 1.00 + (sin(t * 2 * pi) * 0.015)
                : 1.0;
            final double breathY = widget.enableBreathing
                ? sin(t * 2 * pi) * 2.5
                : 0.0;

            return Transform.translate(
              offset: Offset(0, breathY),
              child: Transform.scale(
                scale: breathScale,
                child: child,
              ),
            );
          },
          child: Image.asset(
            widget.imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF111114)),
          ),
        ),

        // Layer 2: Candle / Altar Flame Flickering Light
        if (widget.enableFlicker)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final flickerPhase = _animController.value * 12 * pi;
              final flickerStrength = 0.18 + (sin(flickerPhase) * 0.06).abs();
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: widget.flickerCenter,
                    radius: 0.85,
                    colors: [
                      widget.flickerColor.withValues(alpha: flickerStrength),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),

        // Layer 3: Contrast Vignette Overlay for UI Readability
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: widget.vignetteOpacity * 0.85),
                Colors.black.withValues(alpha: widget.vignetteOpacity * 0.55),
                Colors.black.withValues(alpha: widget.vignetteOpacity * 0.92),
              ],
            ),
          ),
        ),

        // Layer 4: Procedural Floating Atmospheric Particles (Embers / Miasma / Spores)
        if (widget.enableParticles)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _LivingAtmosphereParticlePainter(
                  particles: _particles,
                  time: _animController.value,
                  particleColor: widget.particleColor,
                ),
              );
            },
          ),

        // Layer 5: Interactive Foreground UI
        widget.child,
      ],
    );
  }
}

class _LivingAtmosphereParticlePainter extends CustomPainter {
  final List<AmbientParticle> particles;
  final double time;
  final Color particleColor;

  _LivingAtmosphereParticlePainter({
    required this.particles,
    required this.time,
    required this.particleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Procedural drift upwards and horizontal wobble
      final double currentY = (p.y - (time * p.speed * 4)) % 1.0;
      final double wobble = sin((time * 2 * pi) + (i * 1.5)) * 12.0;
      final double currentX = (p.x * size.width) + wobble;
      final double drawY = (currentY < 0 ? currentY + 1.0 : currentY) * size.height;

      final paint = Paint()
        ..color = particleColor.withValues(alpha: (p.opacity * (0.6 + 0.4 * sin(time * 4 * pi + i))).clamp(0.05, 0.8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(currentX, drawY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LivingAtmosphereParticlePainter oldDelegate) => true;
}
