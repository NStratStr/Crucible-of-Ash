import 'package:flutter/material.dart';

enum RelicSlot {
  weapon,
  armor,
  talisman,
  sigil,
}

enum RelicSetType {
  bloodleech,    // 2-pc: +15% Lifesteal
  ironclad,      // 2-pc: +20% Defense
  tempest,       // 2-pc: +12 Speed
  executioner,   // 4-pc: +30% Crit DMG, +10% Crit Rate
  blightweaver,  // 4-pc: Attacks inflict Blight; +30% DMG vs Blighted foes
  dreadnought,   // 4-pc: +30% Max HP; reflects 20% damage back to attackers
  shadowstalker, // 2-pc: +15% Crit Rate, +10 Speed
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
  final int upgradeLevel; // 0 to 5

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
    this.upgradeLevel = 0,
  });

  String get displayName => upgradeLevel > 0 ? '$name +$upgradeLevel' : name;

  /// World promotion refinement cap (Tied to unlocked Chapter / World tier):
  /// - Chapter 1: Refinement Cap +2
  /// - Chapter 2: Refinement Cap +3
  /// - Chapter 3+: Refinement Cap +5 (Master Refinement)
  static int maxRefinementTierForChapter(int chapter) {
    if (chapter <= 1) return 2;
    if (chapter == 2) return 3;
    return 5;
  }

  bool canUpgradeForChapter(int chapter) => upgradeLevel < maxRefinementTierForChapter(chapter);
  bool get canUpgrade => upgradeLevel < 5;
  int get upgradeCostIchor => (upgradeLevel + 1) * 75;
  int get upgradeCostOre => (upgradeLevel + 1) * 10;

  /// Mission-specific Relic Sets (different equipment sets themed to each mission / region):
  /// - Mission 1 (Ashen Perimeter): Ironclad (+DEF) & Tempest (+SPD)
  /// - Mission 2 (Smoldering Barricade): Bloodleech (+Lifesteal) & Shadowstalker (+CRIT/SPD)
  /// - Mission 3+ (Sanctuary Frontier / Caldera): Executioner, Blightweaver, Dreadnought
  static List<RelicSetType> setsForChapter(int chapter) {
    switch (chapter) {
      case 1:
        return const [RelicSetType.ironclad, RelicSetType.tempest];
      case 2:
        return const [RelicSetType.bloodleech, RelicSetType.shadowstalker, RelicSetType.ironclad];
      case 3:
      default:
        return const [
          RelicSetType.executioner,
          RelicSetType.blightweaver,
          RelicSetType.dreadnought,
          RelicSetType.bloodleech,
          RelicSetType.shadowstalker,
        ];
    }
  }

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
    int? upgradeLevel,
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
      upgradeLevel: upgradeLevel ?? this.upgradeLevel,
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
      case RelicSetType.blightweaver:
        return '4-Piece: Strikes inflict Blight; +30% damage vs Blighted foes';
      case RelicSetType.dreadnought:
        return '4-Piece: +30% Max HP; reflects 20% damage to attackers';
      case RelicSetType.shadowstalker:
        return '2-Piece: +15% Crit Rate & +10 Speed';
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
      case RelicSetType.blightweaver:
        return 'Blightweaver Set';
      case RelicSetType.dreadnought:
        return 'Dreadnought Bastion';
      case RelicSetType.shadowstalker:
        return 'Shadowstalker Set';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slot': slot.name,
      'rarity': rarity.name,
      'setType': setType.name,
      'bonusAttack': bonusAttack,
      'bonusDefense': bonusDefense,
      'bonusHp': bonusHp,
      'bonusSpeed': bonusSpeed,
      'bonusCritRate': bonusCritRate,
      'description': description,
      'equippedUnitId': equippedUnitId,
      'upgradeLevel': upgradeLevel,
    };
  }

  factory RelicEntity.fromJson(Map<String, dynamic> json) {
    return RelicEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      slot: RelicSlot.values.firstWhere(
        (s) => s.name == json['slot'],
        orElse: () => RelicSlot.weapon,
      ),
      rarity: RelicRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => RelicRarity.common,
      ),
      setType: RelicSetType.values.firstWhere(
        (st) => st.name == json['setType'],
        orElse: () => RelicSetType.ironclad,
      ),
      bonusAttack: (json['bonusAttack'] as num?)?.toInt() ?? 0,
      bonusDefense: (json['bonusDefense'] as num?)?.toInt() ?? 0,
      bonusHp: (json['bonusHp'] as num?)?.toInt() ?? 0,
      bonusSpeed: (json['bonusSpeed'] as num?)?.toInt() ?? 0,
      bonusCritRate: (json['bonusCritRate'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      equippedUnitId: json['equippedUnitId'] as String?,
      upgradeLevel: (json['upgradeLevel'] as num?)?.toInt() ?? 0,
    );
  }
}
