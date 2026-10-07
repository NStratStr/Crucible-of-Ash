import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/widgets/hexagonal_affinity_wheel_widget.dart';

void main() {
  group('HexagonalAffinityWheelWidget Tests', () {
    testWidgets('renders all 6 archetype abbreviations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HexagonalAffinityWheelWidget(
                activeArchetype: Archetype.juggernaut,
              ),
            ),
          ),
        ),
      );

      expect(find.text('JUG'), findsOneWidget);
      expect(find.text('ASN'), findsOneWidget);
      expect(find.text('MRK'), findsOneWidget);
      expect(find.text('SKM'), findsOneWidget);
      expect(find.text('SUP'), findsOneWidget);
      expect(find.text('OCC'), findsOneWidget);
    });

    testWidgets('triggers onSelectArchetype callback when tapping a node', (tester) async {
      Archetype? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HexagonalAffinityWheelWidget(
                activeArchetype: Archetype.juggernaut,
                onSelectArchetype: (archetype) {
                  tapped = archetype;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ASN'));
      await tester.pump();

      expect(tapped, equals(Archetype.assassin));

      await tester.tap(find.text('OCC'));
      await tester.pump();

      expect(tapped, equals(Archetype.occultist));
    });

    testWidgets('renders correctly when activeArchetype is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HexagonalAffinityWheelWidget(
                activeArchetype: null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('JUG'), findsOneWidget);
      expect(find.text('SUP'), findsOneWidget);
    });
  });
}
