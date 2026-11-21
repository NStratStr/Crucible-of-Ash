import 'dart:math';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';

class DistillReward {
  final int gold;
  final int cursedOre;
  final int bloodlineSigils;

  const DistillReward({
    required this.gold,
    required this.cursedOre,
    required this.bloodlineSigils,
  });
}

class CrucibleService {
  /// Calculates the resource yield when distilling (breaking down) an unwanted reserve unit.
  static DistillReward previewDistill(UnitEntity unit) {
    final int levelBonusGold = max(0, unit.level - 1) * 15;
    switch (unit.generation) {
      case 1:
        return DistillReward(gold: 60 + levelBonusGold, cursedOre: 15, bloodlineSigils: 0);
      case 2:
        return DistillReward(gold: 140 + levelBonusGold, cursedOre: 35, bloodlineSigils: 0);
      case 3:
        return DistillReward(gold: 260 + levelBonusGold, cursedOre: 65, bloodlineSigils: 1);
      default:
        return DistillReward(gold: 400 + levelBonusGold, cursedOre: 100, bloodlineSigils: 2);
    }
  }

  /// Ascends [primary] in-place by consuming [sacrifice], keeping [primary]'s ID, level, and equipped relics
  /// while promoting its Generation, raising its Level Cap, boosting stats, and grafting a trait.
  static UnitEntity ascendInPlace({
    required UnitEntity primary,
    required UnitEntity sacrifice,
    required String selectedGraftTraitId,
    int crucibleTier = 1,
  }) {
    final int nextGeneration = (max(primary.generation, sacrifice.generation) + 1).clamp(1, 6);
    final double sacrificeShare = (crucibleTier >= 4 || sacrifice.level >= sacrifice.maxLevel) ? 0.12 : 0.08;
    final double tierMult = crucibleTier >= 4 ? 1.05 : 1.0;
    final double purebloodMult = nextGeneration >= 4 ? (1.12 + ((nextGeneration - 4) * 0.08)) : 1.0;

    int boostStat(int primaryStat, int sacrificeStat) {
      final promoted = (primaryStat * 1.12) + (sacrificeStat * sacrificeShare);
      return (promoted * tierMult * purebloodMult).round();
    }

    final int newMaxHp = boostStat(primary.maxHp, sacrifice.maxHp);
    final int newAtk = boostStat(primary.attack, sacrifice.attack);
    final int newDef = boostStat(primary.defense, sacrifice.defense);
    final int newSpd = boostStat(primary.speed, sacrifice.speed);
    final int newMaxLevel = max(primary.maxLevel, nextGeneration * 10);

    final List<String> updatedPedigree = {
      ...primary.lineageAncestors,
      ...sacrifice.lineageAncestors,
      sacrifice.speciesId,
      sacrifice.id,
    }.toList();

    return UnitEntity(
      id: primary.id,
      speciesId: primary.speciesId,
      name: primary.name,
      generation: nextGeneration,
      archetype: primary.archetype,
      slot: primary.slot,
      level: primary.level,
      maxLevel: newMaxLevel,
      currentHp: newMaxHp,
      maxHp: newMaxHp,
      attack: newAtk,
      defense: newDef,
      speed: newSpd,
      nativeTraitId: primary.nativeTraitId,
      graftedTraitId: selectedGraftTraitId.isNotEmpty ? selectedGraftTraitId : primary.graftedTraitId,
      lineageAncestors: updatedPedigree,
      rarity: primary.rarity,
    );
  }
  /// Resolves the creation of a descendant from two maxed or unmaxed progenitors.
  static UnitEntity fuseUnits({
    required UnitEntity parentA,
    required UnitEntity parentB,
    required String childSpeciesId,
    required String childName,
    required Archetype childArchetype,
    required FormationSlot assignedSlot,
    required int speciesBaseHp,
    required int speciesBaseAtk,
    required int speciesBaseDef,
    required int speciesBaseSpd,
    required String childNativeTraitId,
    required String selectedGraftTraitId,
    int crucibleTier = 1,
  }) {
    assert(
      parentA.speciesId == parentB.speciesId,
      "Progenitors must share the same species lineage.",
    );

    final int nextGeneration = (max(parentA.generation, parentB.generation) + 1).clamp(1, 6);

    // 10% transfer at max level; 5% transfer if premature (Tier 4 grants full 10% efficiency + 5% resonance)
    final double ratioA = (crucibleTier >= 4 || parentA.level >= parentA.maxLevel) ? 0.10 : 0.05;
    final double ratioB = (crucibleTier >= 4 || parentB.level >= parentB.maxLevel) ? 0.10 : 0.05;
    final double efficiencyMult = crucibleTier >= 4 ? 1.05 : 1.0;

    final int bonusHp = (((parentA.maxHp * ratioA) + (parentB.maxHp * ratioB)) * efficiencyMult).round();
    final int bonusAtk = (((parentA.attack * ratioA) + (parentB.attack * ratioB)) * efficiencyMult).round();
    final int bonusDef = (((parentA.defense * ratioA) + (parentB.defense * ratioB)) * efficiencyMult).round();
    final int bonusSpd = (((parentA.speed * ratioA) + (parentB.speed * ratioB)) * efficiencyMult).round();

    int finalMaxHp = speciesBaseHp + bonusHp;
    int finalAtk = speciesBaseAtk + bonusAtk;
    int finalDef = speciesBaseDef + bonusDef;
    int finalSpd = speciesBaseSpd + bonusSpd;

    // Pureblood & Apex Resonance (Gen 4+ pinnacle lineage bonuses)
    if (nextGeneration >= 4) {
      final double purebloodMult = 1.15 + ((nextGeneration - 4) * 0.10); // +15% at G4, +25% at G5, +35% at G6
      finalMaxHp = (finalMaxHp * purebloodMult).round();
      finalAtk = (finalAtk * purebloodMult).round();
      finalDef = (finalDef * purebloodMult).round();
      finalSpd = (finalSpd * purebloodMult).round();
    }

    final List<String> combinedPedigree = {
      ...parentA.lineageAncestors,
      parentA.speciesId,
      parentA.id,
      ...parentB.lineageAncestors,
      parentB.speciesId,
      parentB.id,
    }.toList();

    // Max Level formula (10 levels per generation):
    // G1=10, G2=20, G3=30, G4=40, G5=50, G6=60
    final int maxLvl = nextGeneration * 10;

    return UnitEntity(
      id: "unit_${DateTime.now().millisecondsSinceEpoch}",
      speciesId: childSpeciesId,
      name: childName,
      generation: nextGeneration,
      archetype: childArchetype,
      slot: assignedSlot,
      level: 1,
      maxLevel: maxLvl,
      currentHp: finalMaxHp,
      maxHp: finalMaxHp,
      attack: finalAtk,
      defense: finalDef,
      speed: finalSpd,
      nativeTraitId: childNativeTraitId,
      graftedTraitId: selectedGraftTraitId,
      lineageAncestors: combinedPedigree,
    );
  }

  /// GDD v2.6 Section 14.1: Maximum allowed generation for MVP specification.
  /// Generations 4 through 6 are cleanly deferred to Post-MVP expansion.
  static const int maxMvpGeneration = 6;

  /// GDD v2.6 Section 12 & 14.1: Exponential Fusion Tax in Ash.
  /// Formula: Cost_Ash = 1000 * (1.85)^Generation
  static int calculateFusionCostAsh(int targetGeneration) {
    if (targetGeneration <= 0) return 1000;
    return (1000 * pow(1.85, targetGeneration)).round();
  }

  /// Generates a normally distributed random multiplier with Box-Muller transform:
  /// Mean = 1.0, StdDev = 0.05 (mutation variance factor).
  static double sampleGaussian({
    Random? random,
    double mean = 1.0,
    double stdDev = 0.05,
  }) {
    final r = random ?? Random();
    double u1 = r.nextDouble();
    while (u1 <= 1e-15) {
      u1 = r.nextDouble();
    }
    final double u2 = r.nextDouble();
    final double z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    return mean + (z0 * stdDev);
  }

  /// GDD v2.6 Section 7 & 14.1: Gaussian stat blending duplicate fusion up to G3.
  /// Formula:
  /// BaseStat_Child = ((BaseStat_P1 + BaseStat_P2) / 2) * (1 + Generation * 0.03) * N(1, 0.05)
  static UnitEntity fuseMvpDuplicates({
    required UnitEntity parentA,
    required UnitEntity parentB,
    Random? random,
    double? fixedVariance,
    String? customChildName,
  }) {
    if (parentA.speciesId != parentB.speciesId) {
      throw ArgumentError(
        'Progenitors must belong to the exact same species duplicate pool (Parent A: ${parentA.speciesId}, Parent B: ${parentB.speciesId}).',
      );
    }

    final int targetGen = max(parentA.generation, parentB.generation) + 1;
    if (targetGen > maxMvpGeneration) {
      throw StateError(
        'Generation $targetGen exceeds MVP boundary (maximum Gen $maxMvpGeneration). Higher generations are sealed.',
      );
    }

    // Variance multiplier sampled from Gaussian N(1.0, 0.05)
    final double variance = fixedVariance ?? sampleGaussian(random: random);

    // Stat ceiling modifier: (1 + Generation * 0.03)
    final double genMultiplier = 1.0 + (targetGen * 0.03);

    int blendStat(int p1, int p2) {
      final double avg = (p1 + p2) / 2.0;
      final int val = (avg * genMultiplier * variance).round();
      return max(1, val);
    }

    final int childMaxHp = blendStat(parentA.maxHp, parentB.maxHp);
    final int childAtk = blendStat(parentA.attack, parentB.attack);
    final int childDef = blendStat(parentA.defense, parentB.defense);
    final int childSpd = blendStat(parentA.speed, parentB.speed);
    final int childResist = blendStat(parentA.resist, parentB.resist);

    final Set<String> mergedAncestors = {
      ...parentA.lineageAncestors,
      parentA.speciesId,
      parentA.id,
      ...parentB.lineageAncestors,
      parentB.speciesId,
      parentB.id,
    };

    final String childName = customChildName ??
        (targetGen == 2
            ? 'Veteran ${parentA.name}'
            : (targetGen == 3
                ? 'Paragon ${parentA.name}'
                : (targetGen == 4
                    ? 'Pureblood ${parentA.name}'
                    : (targetGen == 5
                        ? 'Ascendant ${parentA.name}'
                        : 'Apex ${parentA.name}'))));

    final int maxLvl = 30 + (targetGen * 5); // Gen 2 = 40, Gen 3 = 45

    return UnitEntity(
      id: "unit_${parentA.speciesId}_g${targetGen}_${DateTime.now().millisecondsSinceEpoch}",
      speciesId: parentA.speciesId,
      name: childName,
      generation: targetGen,
      archetype: parentA.archetype,
      slot: parentA.slot,
      level: 1,
      maxLevel: maxLvl,
      currentHp: childMaxHp,
      maxHp: childMaxHp,
      attack: childAtk,
      defense: childDef,
      speed: childSpd,
      resist: childResist,
      flatAbsorb: 0,
      reviveCount: 0,
      critRate: parentA.critRate,
      critDamage: parentA.critDamage,
      rarity: parentA.rarity.index >= parentB.rarity.index ? parentA.rarity : parentB.rarity,
      nativeTraitId: parentA.nativeTraitId,
      graftedTraitId: parentB.nativeTraitId != parentA.nativeTraitId
          ? parentB.nativeTraitId
          : parentA.graftedTraitId,
      lineageAncestors: mergedAncestors.toList(),
      customAvatarAsset: parentA.customAvatarAsset,
    );
  }

  /// GDD v2.6 Section 7: Auto-Synthesis
  /// Single-tap batch action rolling duplicate G1s and G2s into G3 veterans.
  /// Respects trait locks [lockedUnitIds] to prevent consuming preserved bloodlines.
  static AutoSynthesisResult autoSynthesizeDuplicates(
    List<UnitEntity> inventory, {
    Set<String> lockedUnitIds = const {},
    int maxTargetGen = maxMvpGeneration,
    Random? random,
    double? fixedVariance,
  }) {
    final List<UnitEntity> workingInventory = List.of(inventory);
    final List<UnitEntity> synthesized = [];
    final List<String> consumedIds = [];
    int totalAshCost = 0;

    bool foundPair = true;
    while (foundPair) {
      foundPair = false;

      // Group available units by speciesId and generation
      for (int gen = 1; gen < maxTargetGen; gen++) {
        final speciesMap = <String, List<UnitEntity>>{};
        for (final unit in workingInventory) {
          if (unit.generation == gen && !lockedUnitIds.contains(unit.id)) {
            speciesMap.putIfAbsent(unit.speciesId, () => []).add(unit);
          }
        }

        // Look for the first compatible duplicate pair
        for (final entry in speciesMap.entries) {
          if (entry.value.length >= 2) {
            final p1 = entry.value[0];
            final p2 = entry.value[1];

            final child = fuseMvpDuplicates(
              parentA: p1,
              parentB: p2,
              random: random,
              fixedVariance: fixedVariance,
            );

            totalAshCost += calculateFusionCostAsh(child.generation);
            consumedIds.add(p1.id);
            consumedIds.add(p2.id);
            synthesized.add(child);

            workingInventory.removeWhere((u) => u.id == p1.id || u.id == p2.id);
            workingInventory.add(child);

            foundPair = true;
            break;
          }
        }

        if (foundPair) break;
      }
    }

    return AutoSynthesisResult(
      synthesizedUnits: synthesized,
      consumedUnitIds: consumedIds,
      remainingInventory: workingInventory,
      totalAshCost: totalAshCost,
    );
  }
}

/// Result of auto-synthesis batch fusion.
class AutoSynthesisResult {
  final List<UnitEntity> synthesizedUnits;
  final List<String> consumedUnitIds;
  final List<UnitEntity> remainingInventory;
  final int totalAshCost;

  const AutoSynthesisResult({
    required this.synthesizedUnits,
    required this.consumedUnitIds,
    required this.remainingInventory,
    required this.totalAshCost,
  });
}

