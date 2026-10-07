import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/campaign/endgame_gauntlet_dialog.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Lineage Crypt Squad Restriction Tests', () {
    testWidgets('Lineage Crypt Den of Fangs displays restriction status', (WidgetTester tester) async {
      final validSquad = StarterBrigades.createPlayerSquad(); // Contains War-Hound and Gargoyle Skirmisher (2+ beasts/skirmishers)

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => EndgameGauntletDialog.show(ctx, activeSquad: validSquad),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('LINEAGE CRYPT: DEN OF FANGS'), findsOneWidget);
      expect(find.textContaining('RESTRICTION MET'), findsOneWidget);
    });

    testWidgets('Lineage Crypt Den of Fangs blocks entry when lacking beasts/skirmishers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Squad with only Juggernaut knights (no beasts or skirmishers)
      final restrictedSquad = [
        const UnitEntity(
          id: 'knight_1',
          speciesId: 'iron_knight',
          name: 'Iron Footman',
          generation: 1,
          archetype: Archetype.juggernaut,
          slot: FormationSlot.front1,
          level: 10,
          maxLevel: 10,
          currentHp: 800,
          maxHp: 800,
          attack: 100,
          defense: 120,
          speed: 80,
          nativeTraitId: 'iron_bastion',
          lineageAncestors: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => EndgameGauntletDialog.show(ctx, activeSquad: restrictedSquad),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      // Verify restriction warning badge appears
      expect(find.textContaining('RESTRICTION: 2+ Beasts/Skirmishers Required'), findsOneWidget);
      expect(find.text('LINEAGE SEALED'), findsOneWidget);

      // Tap LINEAGE SEALED button
      await tester.tap(find.text('LINEAGE SEALED'));
      await tester.pumpAndSettle();

      // Dialog pops up explaining the barrier
      expect(find.text('LINEAGE BARRIER SEALED'), findsOneWidget);
      expect(find.textContaining('The Den of Fangs strictly permits only feral beasts'), findsOneWidget);
    });
  });
}
