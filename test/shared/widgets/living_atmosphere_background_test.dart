import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/shared/widgets/living_atmosphere_background.dart';

void main() {
  group('LivingAtmosphereBackground Widget Tests', () {
    testWidgets('Renders background image and child widget without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivingAtmosphereBackground(
              imageAsset: 'assets/images/crucible_ritual_chamber.jpg',
              enableBreathing: true,
              enableFlicker: true,
              enableParticles: true,
              child: Center(
                child: Text('ALTAR CONTENT'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ALTAR CONTENT'), findsOneWidget);
      expect(find.byType(LivingAtmosphereBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders properly with live animation enabled and pumps through ticks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivingAtmosphereBackground(
              imageAsset: 'assets/images/gothic_arch_battlefield.jpg',
              enableBreathing: true,
              enableFlicker: false,
              enableParticles: true,
              isLiveAnimation: true,
              child: Center(
                child: Text('BATTLEFIELD CONTENT'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('BATTLEFIELD CONTENT'), findsOneWidget);

      // Advance through animation frames without pumpAndSettle timeout
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('BATTLEFIELD CONTENT'), findsOneWidget);
    });
  });
}
