import 'dart:math';

enum Archetype {
  juggernaut, // 0: Tanks / Colossi / Golems
  assassin,   // 1: Rogues / Duelists / Stalkers
  marksman,   // 2: Archers / Artillery / Snipers
  skirmisher, // 3: Flyers / Prowling Beasts
  support,    // 4: Healers / Bards / Totemists
  occultist,  // 5: Mages / Warlocks / Blight Casters
}

class CombatMath {
  static final Random _rng = Random();

  /// Calculates directional affinity multiplier using modulo distance on a 6-node wheel.
  /// Distance +1 clockwise = Strong (1.30)
  /// Distance +5 (or -1 counter-clockwise) = Weak (0.75)
  /// Any other distance = Neutral (1.00)
  static double getAffinityMultiplier(Archetype attacker, Archetype defender) {
    final int delta = (defender.index - attacker.index) % 6;
    if (delta == 1) return 1.30;
    if (delta == 5) return 0.75;
    return 1.00;
  }

  /// Returns the archetype that this role is strong against (+1 clockwise)
  static Archetype getPreyArchetype(Archetype role) {
    return Archetype.values[(role.index + 1) % 6];
  }

  /// Returns the archetype that this role is weak against (-1 counter-clockwise)
  static Archetype getPredatorArchetype(Archetype role) {
    return Archetype.values[(role.index + 5) % 6];
  }

  /// Evaluates whether an attack glances due to affinity disadvantage.
  static bool isGlancingBlow(Archetype attacker, Archetype defender, [Random? rng]) {
    if (getAffinityMultiplier(attacker, defender) == 0.75) {
      final Random activeRng = rng ?? _rng;
      return activeRng.nextDouble() < 0.25; // 25% chance to glance
    }
    return false;
  }

  /// Asymptotic defense mitigation curve.
  /// Mitigation Multiplier = 1000 / (1000 + 3.5 * Defense)
  static double calculateMitigation(int defense) {
    final double safeDef = max(0, defense).toDouble();
    return 1000.0 / (1000.0 + (3.5 * safeDef));
  }

  /// Complete damage resolution pipeline.
  static int calculateDamage({
    required int attack,
    required int defense,
    required double skillCoefficient,
    required Archetype attackerRole,
    required Archetype defenderRole,
    required double critRate,
    required double critDamage,
    Random? rng,
  }) {
    final Random activeRng = rng ?? _rng;
    final double mitigation = calculateMitigation(defense);
    final double baseDamage = attack * skillCoefficient * mitigation;

    final double affinityMod = getAffinityMultiplier(attackerRole, defenderRole);
    final bool glancing = isGlancingBlow(attackerRole, defenderRole, activeRng);

    double critMod = 1.0;
    if (!glancing && activeRng.nextDouble() < critRate) {
      critMod = critDamage;
    }

    // Variance: 0.95 to 1.05
    final double variance = 0.95 + (activeRng.nextDouble() * 0.10);

    double totalDamage = baseDamage * affinityMod * critMod * variance;
    if (glancing) {
      totalDamage *= 0.70; // 30% reduction on glancing blow
    }

    return max(1, totalDamage.round());
  }
}
