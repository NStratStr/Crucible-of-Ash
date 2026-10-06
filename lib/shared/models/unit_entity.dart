import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';

enum FormationSlot { front1, front2, front3, back1, back2 }

@immutable
class UnitEntity {
  final String id;
  final String speciesId;
  final String name;
  final int generation; // 1, 2, 3, or 4 (Pureblood)
  final Archetype archetype;
  final FormationSlot slot;

  // Progression & Health
  final int level;
  final int maxLevel;
  final int currentHp;

  // Attributes
  final int maxHp;
  final int attack;
  final int defense;
  final int speed;
  final double critRate;
  final double critDamage;

  // Turn Meter (0.0 to 100.0+)
  final double turnMeter;

  // Pedigree & Traits
  final String nativeTraitId;
  final String? graftedTraitId;
  final List<String> lineageAncestors;

  const UnitEntity({
    required this.id,
    required this.speciesId,
    required this.name,
    required this.generation,
    required this.archetype,
    required this.slot,
    required this.level,
    required this.maxLevel,
    required this.currentHp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.speed,
    this.critRate = 0.15,
    this.critDamage = 1.50,
    this.turnMeter = 0.0,
    required this.nativeTraitId,
    this.graftedTraitId,
    required this.lineageAncestors,
  });

  bool get isVanguard => slot.index < 3;
  bool get isArcanum => slot.index >= 3;
  bool get isAlive => currentHp > 0;

  UnitEntity copyWith({
    int? currentHp,
    int? level,
    int? maxHp,
    int? attack,
    int? defense,
    int? speed,
    double? turnMeter,
    String? graftedTraitId,
    FormationSlot? slot,
  }) {
    return UnitEntity(
      id: id,
      speciesId: speciesId,
      name: name,
      generation: generation,
      archetype: archetype,
      slot: slot ?? this.slot,
      level: level ?? this.level,
      maxLevel: maxLevel,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      speed: speed ?? this.speed,
      critRate: critRate,
      critDamage: critDamage,
      turnMeter: turnMeter ?? this.turnMeter,
      nativeTraitId: nativeTraitId,
      graftedTraitId: graftedTraitId ?? this.graftedTraitId,
      lineageAncestors: lineageAncestors,
    );
  }
}
