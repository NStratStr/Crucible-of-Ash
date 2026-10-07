import 'package:flutter/material.dart';

enum RelicSlot {
  weapon,
  armor,
  talisman,
  sigil,
}

enum RelicSetType {
  bloodleech,  // 2-pc: +15% Lifesteal
  ironclad,    // 2-pc: +20% Defense
  tempest,     // 2-pc: +12 Speed
  executioner, // 4-pc: +30% Crit DMG, +10% Crit Rate
}

enum RelicRarity {
  common,
  rare,
  epic,
  legendary,
}

@immutable
class RelicEntity {
  final String id;
  final String name;
  final RelicSlot slot;
  final RelicRarity rarity;
  final RelicSetType setType;
  final int bonusAttack;
  final int bonusDefense;
  final int bonusHp;
  final int bonusSpeed;
  final double bonusCritRate;
  final String description;
  final String? equippedUnitId;

  const RelicEntity({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    required this.setType,
    this.bonusAttack = 0,
    this.bonusDefense = 0,
    this.bonusHp = 0,
    this.bonusSpeed = 0,
    this.bonusCritRate = 0.0,
    required this.description,
    this.equippedUnitId,
  });

  RelicEntity copyWith({
    String? id,
    String? name,
    RelicSlot? slot,
    RelicRarity? rarity,
    RelicSetType? setType,
    int? bonusAttack,
    int? bonusDefense,
    int? bonusHp,
    int? bonusSpeed,
    double? bonusCritRate,
    String? description,
    String? equippedUnitId,
    bool clearEquipped = false,
  }) {
    return RelicEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      slot: slot ?? this.slot,
      rarity: rarity ?? this.rarity,
      setType: setType ?? this.setType,
      bonusAttack: bonusAttack ?? this.bonusAttack,
      bonusDefense: bonusDefense ?? this.bonusDefense,
      bonusHp: bonusHp ?? this.bonusHp,
      bonusSpeed: bonusSpeed ?? this.bonusSpeed,
      bonusCritRate: bonusCritRate ?? this.bonusCritRate,
      description: description ?? this.description,
      equippedUnitId: clearEquipped ? null : (equippedUnitId ?? this.equippedUnitId),
    );
  }

  Color get rarityColor {
    switch (rarity) {
      case RelicRarity.common:
        return const Color(0xFF9E9E9E);
      case RelicRarity.rare:
        return const Color(0xFF42A5F5);
      case RelicRarity.epic:
        return const Color(0xFFAB47BC);
      case RelicRarity.legendary:
        return const Color(0xFFFFB300);
    }
  }

  IconData get slotIcon {
    switch (slot) {
      case RelicSlot.weapon:
        return Icons.colorize;
      case RelicSlot.armor:
        return Icons.shield;
      case RelicSlot.talisman:
        return Icons.auto_awesome;
      case RelicSlot.sigil:
        return Icons.token;
    }
  }

  static String setBonusDescription(RelicSetType type) {
    switch (type) {
      case RelicSetType.bloodleech:
        return '2-Piece: +15% Lifesteal on all strikes';
      case RelicSetType.ironclad:
        return '2-Piece: +20% Squad Armor defense';
      case RelicSetType.tempest:
        return '2-Piece: +12 Initiative Speed';
      case RelicSetType.executioner:
        return '4-Piece: +30% Crit Damage & +10% Crit Rate';
    }
  }

  static String setName(RelicSetType type) {
    switch (type) {
      case RelicSetType.bloodleech:
        return 'Bloodleech Set';
      case RelicSetType.ironclad:
        return 'Ironclad Bastion';
      case RelicSetType.tempest:
        return 'Tempest Weaver';
      case RelicSetType.executioner:
        return 'Executioner Set';
    }
  }
}
