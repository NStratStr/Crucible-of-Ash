import 'package:flutter/foundation.dart';

enum SkillTargetType {
  singleEnemy,
  allEnemies,
  singleAlly,
  allAllies,
  self,
}

enum StatusEffectType {
  bleed,       // Physical DoT (synergizes with Vladislav aura)
  blight,      // Occult Poison DoT
  stun,        // Skips next turn
  defenseUp,   // +30% Armor
  speedUp,     // +20% Speed
}

@immutable
class StatusEffect {
  final StatusEffectType type;
  final int durationTurns;
  final int value; // Damage per turn or stat modifier

  const StatusEffect({
    required this.type,
    required this.durationTurns,
    this.value = 0,
  });

  String get displayName {
    switch (type) {
      case StatusEffectType.bleed:
        return 'Bleed';
      case StatusEffectType.blight:
        return 'Blight';
      case StatusEffectType.stun:
        return 'Stun';
      case StatusEffectType.defenseUp:
        return 'Armor Up';
      case StatusEffectType.speedUp:
        return 'Haste';
    }
  }
}

@immutable
class SkillEntity {
  final String id;
  final String name;
  final String description;
  final double damageCoefficient;
  final int cooldownTurns;
  final int currentCooldown;
  final SkillTargetType targetType;
  final bool isLimitBurst;
  final StatusEffect? appliedStatus;
  final double lifestealRatio;
  final bool ignoresArmor;

  const SkillEntity({
    required this.id,
    required this.name,
    required this.description,
    this.damageCoefficient = 1.0,
    this.cooldownTurns = 0,
    this.currentCooldown = 0,
    this.targetType = SkillTargetType.singleEnemy,
    this.isLimitBurst = false,
    this.appliedStatus,
    this.lifestealRatio = 0.0,
    this.ignoresArmor = false,
  });

  bool get isReady => currentCooldown <= 0;

  SkillEntity copyWith({
    int? currentCooldown,
  }) {
    return SkillEntity(
      id: id,
      name: name,
      description: description,
      damageCoefficient: damageCoefficient,
      cooldownTurns: cooldownTurns,
      currentCooldown: currentCooldown ?? this.currentCooldown,
      targetType: targetType,
      isLimitBurst: isLimitBurst,
      appliedStatus: appliedStatus,
      lifestealRatio: lifestealRatio,
      ignoresArmor: ignoresArmor,
    );
  }
}
