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

  /// Physical Damage Reduction (Diminishing Returns) from GDD v2.6 Sec 3.1:
  /// PRR = Armor / (Armor + 100 + (10 * AttackerLevel))
  static double calculatePrr(int armor, {int attackerLevel = 1}) {
    final double safeArmor = max(0, armor).toDouble();
    final double denom = safeArmor + 100.0 + (10.0 * max(1, attackerLevel));
    return safeArmor / denom;
  }

  /// Elemental Resistance Reduction from GDD v2.6 Sec 3.1:
  /// ERR = Resist / (Resist + 120)
  static double calculateErr(int resist) {
    final double safeResist = max(0, resist).toDouble();
    return safeResist / (safeResist + 120.0);
  }

  /// Effective Health Calculation (EHP) from GDD v2.6 Sec 3.1:
  /// EHP = HP * (1 + Armor / 100) * (1 + Resist / 100)
  static double calculateEhp(int hp, {int armor = 0, int resist = 0}) {
    final double safeHp = max(0, hp).toDouble();
    final double safeArmor = max(0, armor).toDouble();
    final double safeResist = max(0, resist).toDouble();
    return safeHp * (1.0 + safeArmor / 100.0) * (1.0 + safeResist / 100.0);
  }

  /// Defense mitigation curve.
  /// Mitigation Multiplier = 1000 / (1000 + 3.5 * Defense)
  static double calculateMitigation(int defense) {
    final double safeDef = max(0, defense).toDouble();
    return 1000.0 / (1000.0 + (3.5 * safeDef));
  }

  /// Complete damage resolution pipeline from GDD v2.6 Sec 3.1:
  /// Damage = (BaseATK * SkillCoeff) * (1 - PRR) * (1 + CRIT_MULT) - FlatAbsorb
  static int calculateDamage({
    required int attack,
    required int defense,
    required double skillCoefficient,
    required Archetype attackerRole,
    required Archetype defenderRole,
    required double critRate,
    required double critDamage,
    int attackerLevel = 1,
    int flatAbsorb = 0,
    bool useHyperbolicPrr = false,
    Random? rng,
  }) {
    final Random activeRng = rng ?? _rng;
    final double mitigation = useHyperbolicPrr
        ? (1.0 - calculatePrr(defense, attackerLevel: attackerLevel))
        : calculateMitigation(defense);
    final double baseDamage = attack * skillCoefficient * mitigation;

    final double affinityMod = getAffinityMultiplier(attackerRole, defenderRole);
    final bool glancing = isGlancingBlow(attackerRole, defenderRole, activeRng);

    double critMod = 1.0;
    if (!glancing && activeRng.nextDouble() < critRate) {
      critMod = critDamage;
    }

    // Variance: 0.95 to 1.05
    final double variance = 0.95 + (activeRng.nextDouble() * 0.10);

    double totalDamage = (baseDamage * affinityMod * critMod * variance) - flatAbsorb;
    if (glancing) {
      totalDamage *= 0.70; // 30% reduction on glancing blow
    }

    return max(1, totalDamage.round());
  }
}
