import 'package:flutter/foundation.dart';

enum SkillTargetType {
  singleEnemy,
  allEnemies,
  singleAlly,
  allAllies,
  self,
}

enum StatusEffectType {
  bleed,        // Physical DoT (GDD v2.6 Sec 4)
  blight,       // Occult Poison DoT
  burn,         // Fire DoT (suppresses 100% healing)
  freeze,       // Hard CC (Physical hit shatters for bonus damage)
  stun,         // Hard CC (Pauses AP accumulation)
  vulnerable,   // Debuff (+25% incoming damage)
  defenseUp,    // +30% Armor buff
  speedUp,      // +35% BaseSPD Haste buff
  shield,       // Absorbs incoming damage
  invulnerable, // Invulnerability grace window (e.g. 6 ticks upon revive)
  decaying,     // Rebound thrall: collapses back to death when duration expires
  taunt,        // Hard Constraint: Forces enemy targeting override (GDD v2.6 Sec 3.3)
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

  bool get isDebuff =>
      type == StatusEffectType.bleed ||
      type == StatusEffectType.blight ||
      type == StatusEffectType.burn ||
      type == StatusEffectType.freeze ||
      type == StatusEffectType.stun ||
      type == StatusEffectType.vulnerable ||
      type == StatusEffectType.decaying;

  bool get isBuff => !isDebuff;

  String get displayName {
    switch (type) {
      case StatusEffectType.bleed:
        return 'Bleed';
      case StatusEffectType.blight:
        return 'Blight';
      case StatusEffectType.burn:
        return 'Burn';
      case StatusEffectType.freeze:
        return 'Freeze';
      case StatusEffectType.stun:
        return 'Stun';
      case StatusEffectType.vulnerable:
        return 'Vulnerable';
      case StatusEffectType.defenseUp:
        return 'Armor Up';
      case StatusEffectType.speedUp:
        return 'Haste';
      case StatusEffectType.shield:
        return 'Shield';
      case StatusEffectType.invulnerable:
        return 'Grace';
      case StatusEffectType.decaying:
        return 'Decaying';
      case StatusEffectType.taunt:
        return 'Taunt';
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
