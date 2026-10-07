import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/crucible/crucible_screen.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Crucible Economy, Resource Gating, & Progenitor Sacrifice Tests', () {
    const parentG1Alpha = UnitEntity(
      id: 'hound_g1_a',
      speciesId: 'feral_hound',
      name: 'Hound Alpha',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 30,
      maxLevel: 30,
      currentHp: 1000,
      maxHp: 1000,
      attack: 200,
      defense: 100,
      speed: 100,
      nativeTraitId: 'rend',
      lineageAncestors: [],
    );

    const parentG1Beta = UnitEntity(
      id: 'hound_g1_b',
      speciesId: 'feral_hound',
      name: 'Hound Beta',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front2,
      level: 30,
      maxLevel: 30,
      currentHp: 1100,
      maxHp: 1100,
      attack: 190,
      defense: 110,
      speed: 105,
      nativeTraitId: 'pack_hunter',
      lineageAncestors: [],
    );

    const parentG3Alpha = UnitEntity(
      id: 'hound_g3_a',
      speciesId: 'feral_hound',
      name: 'Cerberus Progenitor Alpha',
      generation: 3,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 45,
      maxLevel: 45,
      currentHp: 1400,
      maxHp: 1400,
      attack: 250,
      defense: 160,
      speed: 120,
      nativeTraitId: 'rend',
      lineageAncestors: ['g1_a', 'g2_a'],
    );

    const parentG3Beta = UnitEntity(
      id: 'hound_g3_b',
      speciesId: 'feral_hound',
      name: 'Cerberus Progenitor Beta',
      generation: 3,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front2,
      level: 45,
      maxLevel: 45,
      currentHp: 1350,
      maxHp: 1350,
      attack: 240,
      defense: 170,
      speed: 115,
      nativeTraitId: 'iron_bastion',
      lineageAncestors: ['g1_b', 'g2_b'],
    );

    testWidgets('Crucible Altar renders currency status bar with Ichor and Bloodline Sigils', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [parentG1Alpha, parentG1Beta],
              totalIchor: 450,
              bloodlineSigils: 3,
              onFusionComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('ICHOR: '), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
      expect(find.text('BLOODLINE SIGILS: '), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Gen 2 fusion requires 150 Ichor; disables button when Ichor < 150', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [parentG1Alpha, parentG1Beta],
              totalIchor: 100, // Insufficient!
              bloodlineSigils: 0,
              onFusionComplete: (_) {},
            ),
          ),
        ),
      );

      // Both units auto-slotted
      expect(find.text('TRANSMUTATION RITUAL COST (GEN 2)'), findsOneWidget);
      expect(find.text('150 Ichor'), findsOneWidget);
      expect(find.text('INSUFFICIENT RESOURCES'), findsOneWidget);
      expect(find.textContaining('INSUFFICIENT ICHOR'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Gen 4 Pureblood requires 500 Ichor and 1 Bloodline Sigil; disables when Sigils < 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [parentG3Alpha, parentG3Beta],
              totalIchor: 1000,
              bloodlineSigils: 0, // Insufficient Sigils for Gen 4
              onFusionComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('PUREBLOOD CONSECRATION COST'), findsOneWidget);
      expect(find.text('500 Ichor'), findsOneWidget);
      expect(find.text('1 Bloodline Sigil'), findsOneWidget);
      expect(find.text('INSUFFICIENT RESOURCES'), findsOneWidget);
      expect(find.textContaining('INSUFFICIENT BLOODLINE SIGILS'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Gen 4 Pureblood fusion with sufficient resources enables consecration button and deducts currencies', (tester) async {
      int updatedIchor = -1;
      int updatedSigils = -1;
      UnitEntity? producedChild;
      List<String>? sacrificedParents;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [parentG3Alpha, parentG3Beta],
              totalIchor: 800,
              bloodlineSigils: 2,
              onIchorChanged: (val) => updatedIchor = val,
              onSigilsChanged: (val) => updatedSigils = val,
              onFusionExecuted: (child, parents) {
                producedChild = child;
                sacrificedParents = parents;
              },
              onFusionComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('👑 CONSECRATE PUREBLOOD SOVEREIGN'), findsOneWidget);
      await tester.ensureVisible(find.text('👑 CONSECRATE PUREBLOOD SOVEREIGN'));
      await tester.tap(find.text('👑 CONSECRATE PUREBLOOD SOVEREIGN'));
      await tester.pumpAndSettle();

      expect(updatedIchor, 800 - 500); // 300 Ichor remaining
      expect(updatedSigils, 2 - 1);    // 1 Sigil remaining
      expect(producedChild, isNotNull);
      expect(producedChild!.generation, 4);
      expect(producedChild!.isPureblood, isTrue);
      expect(sacrificedParents, containsAll(['hound_g3_a', 'hound_g3_b']));
    });

    testWidgets('Roster filter chips filter available vessels by species and generation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [
                parentG1Alpha,
                parentG1Beta,
                parentG3Alpha,
              ],
              totalIchor: 1000,
              bloodlineSigils: 5,
              onFusionComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('GEN I'), findsOneWidget);
      expect(find.text('GEN III'), findsOneWidget);

      // Tap GEN III filter
      await tester.ensureVisible(find.text('GEN III'));
      await tester.tap(find.text('GEN III'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3 VESSELS'), findsOneWidget);
      expect(find.text('Cerberus Progenitor Alpha'), findsOneWidget);
    });
  });
}
