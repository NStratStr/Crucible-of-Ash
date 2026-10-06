import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';

void main() {
  group('CombatMath Tests', () {
    test('Hexagonal affinity wheel returns exact multipliers', () {
      // Juggernaut (0) vs Assassin (1) => delta 1 => 1.30 (Strong)
      expect(CombatMath.getAffinityMultiplier(Archetype.juggernaut, Archetype.assassin), equals(1.30));

      // Juggernaut (0) vs Occultist (5) => delta 5 => 0.75 (Weak)
      expect(CombatMath.getAffinityMultiplier(Archetype.juggernaut, Archetype.occultist), equals(0.75));

      // Juggernaut (0) vs Marksman (2) => delta 2 => 1.00 (Neutral)
      expect(CombatMath.getAffinityMultiplier(Archetype.juggernaut, Archetype.marksman), equals(1.00));

      // Juggernaut (0) vs Skirmisher (3) => delta 3 => 1.00 (Neutral opposite)
      expect(CombatMath.getAffinityMultiplier(Archetype.juggernaut, Archetype.skirmisher), equals(1.00));

      // Juggernaut (0) vs Support (4) => delta 4 => 1.00 (Neutral)
      expect(CombatMath.getAffinityMultiplier(Archetype.juggernaut, Archetype.support), equals(1.00));

      // Occultist (5) vs Juggernaut (0) => delta (0 - 5) % 6 = 1 => 1.30 (Strong)
      expect(CombatMath.getAffinityMultiplier(Archetype.occultist, Archetype.juggernaut), equals(1.30));

      // Assassin (1) vs Juggernaut (0) => delta (0 - 1) % 6 = 5 => 0.75 (Weak)
      expect(CombatMath.getAffinityMultiplier(Archetype.assassin, Archetype.juggernaut), equals(0.75));
    });

    test('Defense mitigation curve scales smoothly without zeroing damage', () {
      // 0 Defense -> 1.0 multiplier
      expect(CombatMath.calculateMitigation(0), equals(1.0));

      // 100 Defense -> 1000 / (1000 + 350) = 1000 / 1350 = ~0.7407
      expect(CombatMath.calculateMitigation(100), closeTo(0.7407, 0.001));

      // High defense (1000) -> 1000 / (1000 + 3500) = ~0.2222
      expect(CombatMath.calculateMitigation(1000), closeTo(0.2222, 0.001));
    });

    test('Damage pipeline applies affinity, defense, and crit correctly', () {
      final damage = CombatMath.calculateDamage(
        attack: 200,
        defense: 100,
        skillCoefficient: 1.0,
        attackerRole: Archetype.juggernaut,
        defenderRole: Archetype.assassin, // 1.30x
        critRate: 0.0, // No crit
        critDamage: 1.50,
        rng: Random(42),
      );

      // base: 200 * 0.7407 = ~148.15
      // affinity: 148.15 * 1.30 = ~192.59
      // variance around 190 - 205
      expect(damage, inInclusiveRange(180, 215));
    });

    test('getPreyArchetype and getPredatorArchetype follow hexagonal ring', () {
      expect(CombatMath.getPreyArchetype(Archetype.juggernaut), equals(Archetype.assassin));
      expect(CombatMath.getPredatorArchetype(Archetype.juggernaut), equals(Archetype.occultist));

      expect(CombatMath.getPreyArchetype(Archetype.assassin), equals(Archetype.marksman));
      expect(CombatMath.getPredatorArchetype(Archetype.assassin), equals(Archetype.juggernaut));

      expect(CombatMath.getPreyArchetype(Archetype.occultist), equals(Archetype.juggernaut));
      expect(CombatMath.getPredatorArchetype(Archetype.occultist), equals(Archetype.support));
    });
  });
}
