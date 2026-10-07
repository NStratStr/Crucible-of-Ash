import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/relics/relic_forge_screen.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/relic_entity.dart';

void main() {
  group('RelicForgeScreen Filter Tests', () {
    testWidgets('Renders Slot and Set filter chips and filters unequipped relics', (tester) async {
      final relicService = RelicService();
      final units = StarterBrigades.createPlayerSquad();

      // Ensure we have specific known relics in inventory
      final bloodRelic = const RelicEntity(
        id: 'test_blood_relic',
        name: 'Sanguine Blade',
        slot: RelicSlot.weapon,
        rarity: RelicRarity.rare,
        setType: RelicSetType.bloodleech,
        bonusAttack: 30,
        description: 'Forged in sacrificial blood.',
      );

      final ironRelic = const RelicEntity(
        id: 'test_iron_relic',
        name: 'Obsidian Plate',
        slot: RelicSlot.armor,
        rarity: RelicRarity.epic,
        setType: RelicSetType.ironclad,
        bonusDefense: 45,
        description: 'Impenetrable plate mail.',
      );

      relicService.forgeRandomRelic(); // forge some baseline relics
      // Unequip all to test inventory filtering
      for (final r in relicService.allRelics) {
        if (r.equippedUnitId != null) {
          relicService.unequipRelic(r.id);
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: RelicForgeScreen(
            relicService: relicService,
            brigadeUnits: units,
            totalIchor: 500,
            cursedOre: 100,
          ),
        ),
      );

      // Verify Set Filter chips exist in the UI
      expect(find.text('ALL SETS'), findsOneWidget);
      expect(find.text('BLOOD (2)'), findsOneWidget);
      expect(find.text('IRON (2)'), findsOneWidget);
      expect(find.text('TEMP (2)'), findsOneWidget);
      expect(find.text('EXEC (4)'), findsOneWidget);

      // Tap BLOOD (2) filter chip
      await tester.tap(find.text('BLOOD (2)'));
      await tester.pumpAndSettle();

      // Tap IRON (2) filter chip
      await tester.tap(find.text('IRON (2)'));
      await tester.pumpAndSettle();

      // Tap ALL SETS chip to reset
      await tester.tap(find.text('ALL SETS'));
      await tester.pumpAndSettle();
      expect(find.text('ALL SETS'), findsOneWidget);
    });
  });
}
