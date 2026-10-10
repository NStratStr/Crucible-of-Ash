import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/plinth_rim_status_painter.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('PlinthMaterial Tests', () {
    const UnitEntity unitSlate = UnitEntity(
      id: 'u_slate',
      name: 'Slate Guard',
      level: 1,
      maxLevel: 20,
      archetype: Archetype.juggernaut,
      currentHp: 100,
      maxHp: 100,
      attack: 20,
      defense: 10,
      speed: 100,
      generation: 1,
      slot: FormationSlot.front1,
      speciesId: 'human',
      nativeTraitId: 'none',
      lineageAncestors: [],
      plinthMaterial: PlinthMaterial.slate,
    );

    test('PlinthMaterial enum values have proper titles and border colors', () {
      expect(unitSlate.plinthMaterialTitle, 'Ashen Slate Plinth (Standard)');
      expect(unitSlate.plinthRimBorderColorValue, 0xFF455A64);

      final unitObsidian = unitSlate.copyWith(plinthMaterial: PlinthMaterial.obsidian);
      expect(unitObsidian.plinthMaterialTitle, 'Obsidian Plinth (+10% Crit DMG)');
      expect(unitObsidian.plinthRimBorderColorValue, 0xFF7B1FA2);

      final unitBone = unitSlate.copyWith(plinthMaterial: PlinthMaterial.bone);
      expect(unitBone.plinthMaterialTitle, 'Crypt Bone Plinth (+5% Lifesteal)');
      expect(unitBone.plinthRimBorderColorValue, 0xFFBCAAA4);

      final unitIron = unitSlate.copyWith(plinthMaterial: PlinthMaterial.iron);
      expect(unitIron.plinthMaterialTitle, 'Cold Iron Plinth (+15% Armor)');
      expect(unitIron.plinthRimBorderColorValue, 0xFF78909C);

      final unitGold = unitSlate.copyWith(plinthMaterial: PlinthMaterial.gold);
      expect(unitGold.plinthMaterialTitle, 'Pureblood Gold Plinth (+10% All Stats)');
      expect(unitGold.plinthRimBorderColorValue, 0xFFFFD54F);
    });

    test('UnitEntity serialization preserves plinthMaterial', () {
      final unit = unitSlate.copyWith(plinthMaterial: PlinthMaterial.iron);

      final json = unit.toJson();
      expect(json['plinthMaterial'], 'iron');

      final deserialized = UnitEntity.fromJson(json);
      expect(deserialized.plinthMaterial, PlinthMaterial.iron);
      expect(deserialized.plinthMaterialTitle, 'Cold Iron Plinth (+15% Armor)');
    });

    testWidgets('PlinthRimStatusPainter renders with plinth material without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: Size(64, 22),
                painter: PlinthRimStatusPainter(
                  bleedStacks: 3,
                  blightStacks: 2,
                  shieldIntegrity: 0.5,
                  isAlive: true,
                  plinthMaterial: PlinthMaterial.obsidian,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
