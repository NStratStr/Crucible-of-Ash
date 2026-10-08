import 'dart:math';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';

class CrucibleService {
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
  }) {
    assert(
      parentA.speciesId == parentB.speciesId,
      "Progenitors must share the same species lineage.",
    );

    final int nextGeneration = (max(parentA.generation, parentB.generation) + 1).clamp(1, 4);

    // 10% transfer at max level; 5% transfer if premature
    final double ratioA = (parentA.level >= parentA.maxLevel) ? 0.10 : 0.05;
    final double ratioB = (parentB.level >= parentB.maxLevel) ? 0.10 : 0.05;

    final int bonusHp = ((parentA.maxHp * ratioA) + (parentB.maxHp * ratioB)).round();
    final int bonusAtk = ((parentA.attack * ratioA) + (parentB.attack * ratioB)).round();
    final int bonusDef = ((parentA.defense * ratioA) + (parentB.defense * ratioB)).round();
    final int bonusSpd = ((parentA.speed * ratioA) + (parentB.speed * ratioB)).round();

    int finalMaxHp = speciesBaseHp + bonusHp;
    int finalAtk = speciesBaseAtk + bonusAtk;
    int finalDef = speciesBaseDef + bonusDef;
    int finalSpd = speciesBaseSpd + bonusSpd;

    // Pureblood Resonance (Gen 4 pinnacle lineage bonus)
    if (nextGeneration >= 4) {
      finalMaxHp = (finalMaxHp * 1.15).round();
      finalAtk = (finalAtk * 1.15).round();
      finalDef = (finalDef * 1.15).round();
      finalSpd = (finalSpd * 1.15).round();
    }

    final List<String> combinedPedigree = {
      ...parentA.lineageAncestors,
      parentA.speciesId,
      parentA.id,
      ...parentB.lineageAncestors,
      parentB.speciesId,
      parentB.id,
    }.toList();

    final int maxLvl = nextGeneration >= 4 ? 50 : 30 + (nextGeneration * 5);

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
}
