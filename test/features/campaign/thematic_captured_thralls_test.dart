import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

void main() {
  group('Thematic Captured Thralls Factory Tests', () {
    test('StarterBrigades generates valid Gen 1 thralls across all 6 Hex Wheel archetypes', () {
      for (final role in Archetype.values) {
        final thrall = StarterBrigades.createCapturedThrall(archetype: role);

        expect(thrall.generation, 1);
        expect(thrall.level, 1);
        expect(thrall.maxLevel, 10);
        expect(thrall.archetype, role);
        expect(thrall.currentHp, greaterThan(500));
        expect(thrall.attack, greaterThan(90));
        expect(thrall.nativeTraitId, isNotEmpty);
        expect(thrall.lineageAncestors, isEmpty);

        // Verify archetype matches identity
        switch (role) {
          case Archetype.juggernaut:
            expect(thrall.speciesId, 'feral_hound');
            expect(thrall.name, contains('Pit-Hound'));
            break;
          case Archetype.assassin:
            expect(thrall.speciesId, 'decayed_ghoul');
            expect(thrall.name, contains('Ghoul'));
            break;
          case Archetype.marksman:
            expect(thrall.speciesId, 'ashen_archer');
            expect(thrall.name, contains('Crossbowman'));
            break;
          case Archetype.skirmisher:
            expect(thrall.speciesId, 'gargoyle_stalker');
            expect(thrall.name, contains('Gargoyle'));
            break;
          case Archetype.support:
            expect(thrall.speciesId, 'blood_alchemist');
            expect(thrall.name, contains('Alchemist'));
            break;
          case Archetype.occultist:
            expect(thrall.speciesId, 'grave_disciple');
            expect(thrall.name, contains('Cultist'));
            break;
        }
      }
    });
  });
}
