import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/rank_and_rite_2d_battlefield.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';

void main() {
  group('Colossus Behemoth (Gorgoroth) 2D Tactical Battlefield Tests', () {
    testWidgets('Gorgoroth 2x2 boss renders exactly ONE unified miniature instead of 4 duplicates', (tester) async {
      final engine = SpatialCombatEngine();
      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');

      // Verify Gorgoroth occupies exactly 4 nodes (2x2 quad footprint)
      expect(gorgoroth.footprint, equals(UnitFootprint.quadColossus2x2));
      expect(gorgoroth.occupiedNodes.length, equals(4));

      int miniatureBuildCount = 0;
      final Set<String> builtUnitIds = {};
      String? selectedEnemyId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RankAndRite2DBattlefield(
                engine: engine,
                selectedUnitId: null,
                selectedEnemyUnitId: selectedEnemyId,
                draggedUnitId: null,
                selectedCardId: null,
                draggedUltimateUnitId: null,
                selectedUltimateUnitId: null,
                hoveredTileCol: null,
                hoveredTileRow: null,
                isHoveredPlayerSide: null,
                tileWidth: 100,
                tileHeight: 70,
                onSelectPlayerUnit: (_) {},
                onSelectEnemyUnit: (id) => selectedEnemyId = id,
                onMovePlayerUnit: (_, __, ___) {},
                onCastCard: (_, {targetCol, targetRow, targetUnit}) {},
                onCastUltimate: (_, {targetCol, targetRow, targetUnit}) {},
                onTileHover: (_, __, ___) {},
                onClearHover: () {},
                buildUnitMiniature: (unit, {required double tileWidth, required double tileHeight, required double colGap, bool isSelected = false}) {
                  if (unit.id == 'gorgoroth_boss') {
                    miniatureBuildCount++;
                    builtUnitIds.add(unit.id);
                    return Container(
                      key: const Key('gorgoroth_single_miniature'),
                      width: 200,
                      height: 140,
                      child: Text('Gorgoroth Miniature (${unit.name})'),
                    );
                  }
                  return Container(
                    key: Key('miniature_${unit.id}'),
                    child: Text(unit.name),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Key Verification: Exactly ONE Gorgoroth miniature widget is rendered in the widget tree!
      expect(find.byKey(const Key('gorgoroth_single_miniature')), findsOneWidget);
      expect(miniatureBuildCount, equals(1));

      // Key Verification: The ground tiles for Gorgoroth's territory display the Colossus shield plinth indicator
      expect(find.byIcon(Icons.shield_outlined), findsNWidgets(4));

      await tester.tap(find.byKey(const Key('gorgoroth_single_miniature')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedEnemyId, equals('gorgoroth_boss'));

      // Key Verification: Tapping any ground tile in Gorgoroth's territory also selects Gorgoroth
      selectedEnemyId = null;
      await tester.tap(find.byIcon(Icons.shield_outlined).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedEnemyId, equals('gorgoroth_boss'));
    });
  });
}
