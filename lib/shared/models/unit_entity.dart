import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import 'skill_entity.dart';

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

  // Turn Meter & Ultimate (0.0 to 100.0)
  final double turnMeter;
  final double ultimateCharge;

  // Status Effects & Skills
  final List<StatusEffect> activeEffects;
  final List<SkillEntity> skills;

  // Pedigree & Traits
  final String nativeTraitId;
  final String? graftedTraitId;
  final List<String> lineageAncestors;
  final String? customAvatarAsset;
  final int currentXp;

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
    this.ultimateCharge = 0.0,
    this.activeEffects = const [],
    this.skills = const [],
    required this.nativeTraitId,
    this.graftedTraitId,
    required this.lineageAncestors,
    this.customAvatarAsset,
    this.currentXp = 0,
  });

  bool get isMaxLevel => level >= maxLevel;
  int get xpToNextLevel => level * 100;
  int get xpNeededForNextLevel => isMaxLevel ? 0 : (xpToNextLevel - currentXp);

  int get xpNeededForMaxLevel {
    if (isMaxLevel) return 0;
    int needed = xpNeededForNextLevel;
    for (int lvl = level + 1; lvl < maxLevel; lvl++) {
      needed += lvl * 100;
    }
    return needed;
  }

  /// Levels up the unit by [levels] count (defaults to 1), compounding stats.
  UnitEntity levelUp({int levels = 1}) {
    if (isMaxLevel) return this;
    UnitEntity current = this;
    for (int i = 0; i < levels; i++) {
      if (current.isMaxLevel) break;
      current = current.addXp(current.xpNeededForNextLevel);
    }
    return current;
  }

  double get xpProgressRatio => isMaxLevel ? 1.0 : (currentXp / xpToNextLevel).clamp(0.0, 1.0);

  /// Grants XP to the unit, computing any level-up threshold crossings and compounding stat gains.
  UnitEntity addXp(int xpGained) {
    if (isMaxLevel) return this;

    int newXp = currentXp + xpGained;
    int newLevel = level;
    int newMaxHp = maxHp;
    int newHp = currentHp;
    int newAtk = attack;
    int newDef = defense;
    int newSpd = speed;

    while (newLevel < maxLevel && newXp >= (newLevel * 100)) {
      newXp -= (newLevel * 100);
      newLevel += 1;
      final hpGain = (newMaxHp * 0.10).round().clamp(15, 200);
      newMaxHp += hpGain;
      newHp += hpGain;
      newAtk += (newAtk * 0.08).round().clamp(5, 50);
      newDef += (newDef * 0.06).round().clamp(4, 40);
      newSpd += 2;
    }

    if (newLevel >= maxLevel) {
      newXp = 0;
    }

    return copyWith(
      level: newLevel,
      currentXp: newXp,
      maxHp: newMaxHp,
      currentHp: newHp,
      attack: newAtk,
      defense: newDef,
      speed: newSpd,
    );
  }

  String get effectiveAvatarAsset {
    if (customAvatarAsset != null) return customAvatarAsset!;
    if (speciesId.contains('butcher') ||
        speciesId.contains('flayed') ||
        speciesId.contains('executioner') ||
        speciesId.contains('titan') ||
        name.contains('Flayed') ||
        name.contains('Butcher') ||
        name.contains('Executioner') ||
        name.contains('Titan')) {
      return 'assets/images/flayed_butcher.png';
    }
    if (speciesId.contains('cerberus') || (generation >= 2 && speciesId.contains('hound'))) {
      return 'assets/images/cerberus_progenitor.jpg';
    }
    if (speciesId.contains('hound') || speciesId.contains('wolf') || speciesId.contains('beast')) {
      return 'assets/images/feral_warhound.png';
    }
    if (archetype == Archetype.occultist ||
        speciesId.contains('ghoul') ||
        speciesId.contains('apothecary') ||
        speciesId.contains('plague') ||
        speciesId.contains('warlock') ||
        speciesId.contains('witch')) {
      return 'assets/images/plague_occultist.jpg';
    }
    if (archetype == Archetype.assassin ||
        speciesId.contains('stalker') ||
        speciesId.contains('slayer') ||
        speciesId.contains('reaper')) {
      return 'assets/images/flayed_butcher.png';
    }
    if (archetype == Archetype.juggernaut ||
        speciesId.contains('knight') ||
        speciesId.contains('golem') ||
        speciesId.contains('footman') ||
        speciesId.contains('guardian')) {
      return 'assets/images/ironclad_dreadnought.png';
    }
    if (archetype == Archetype.marksman || archetype == Archetype.skirmisher) {
      return 'assets/images/feral_warhound.png';
    }
    return 'assets/images/ironclad_dreadnought.png';
  }

  String get factionName {
    if (isBoss) return 'Primordial Titans';
    if (speciesId.contains('hound') || speciesId.contains('wolf') || speciesId.contains('beast') || speciesId.contains('cerberus')) {
      return 'Feral Beasts';
    }
    if (speciesId.contains('ghoul') || speciesId.contains('plague') || speciesId.contains('deathless') || archetype == Archetype.occultist) {
      return 'Deathless Undead';
    }
    return 'Iron Vanguard';
  }

  bool get isFigurineCutout => effectiveAvatarAsset.endsWith('.png');

  bool get isVanguard => slot.index < 3;
  bool get isArcanum => slot.index >= 3;
  bool get isAlive => currentHp > 0;
  bool get isStunned => activeEffects.any((e) => e.type == StatusEffectType.stun);
  bool get isBleeding => activeEffects.any((e) => e.type == StatusEffectType.bleed);
  bool get isBlighted => activeEffects.any((e) => e.type == StatusEffectType.blight);
  bool get isPureblood => generation >= 4;
  String get generationTitle => isPureblood ? 'Pureblood (Gen 4)' : 'Gen $generation';
  bool get isBoss =>
      id.startsWith('boss_') &&
          !id.contains('guard') &&
          !id.contains('priest') &&
          !id.contains('chanter') ||
      id == 'world_titan' ||
      speciesId.contains('chapter_titan') ||
      speciesId.contains('titan_sovereign') ||
      speciesId.contains('sunken_lich') ||
      speciesId.contains('ashen_titan') ||
      speciesId.contains('boss') ||
      name.contains('Titan') ||
      name.contains('Lich King') ||
      name.contains('Gorgoroth') ||
      name.contains('Primordial');

  List<SkillEntity> get resolvedSkills {
    if (skills.isNotEmpty) return skills;
    return _generateDefaultSkills(archetype);
  }

  static List<SkillEntity> _generateDefaultSkills(Archetype archetype) {
    switch (archetype) {
      case Archetype.juggernaut:
        return const [
          SkillEntity(
            id: 'jug_a1',
            name: 'Iron Strike',
            description: 'Heavy physical strike.',
            damageCoefficient: 1.0,
          ),
          SkillEntity(
            id: 'jug_a2',
            name: 'Shield Bash',
            description: 'Hits target and applies 1 turn Stun.',
            damageCoefficient: 1.25,
            cooldownTurns: 3,
            appliedStatus: StatusEffect(type: StatusEffectType.stun, durationTurns: 1),
          ),
          SkillEntity(
            id: 'jug_ult',
            name: 'Colossal Fortification',
            description: 'Empowers defense by +30% for 2 rounds.',
            damageCoefficient: 1.5,
            isLimitBurst: true,
            appliedStatus: StatusEffect(type: StatusEffectType.defenseUp, durationTurns: 2),
          ),
        ];
      case Archetype.assassin:
        return const [
          SkillEntity(
            id: 'asn_a1',
            name: 'Viper Slash',
            description: 'Rapid physical incision.',
            damageCoefficient: 1.0,
          ),
          SkillEntity(
            id: 'asn_a2',
            name: 'Exsanguinate',
            description: 'Deep puncture inflicting Bleed for 2 turns.',
            damageCoefficient: 1.4,
            cooldownTurns: 2,
            appliedStatus: StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 40),
          ),
          SkillEntity(
            id: 'asn_ult',
            name: 'Heartseeker Strike',
            description: 'Devastating critical burst.',
            damageCoefficient: 2.4,
            isLimitBurst: true,
          ),
        ];
      case Archetype.marksman:
        return const [
          SkillEntity(
            id: 'mrk_a1',
            name: 'Aimed Volley',
            description: 'Piercing physical arrow.',
            damageCoefficient: 1.0,
          ),
          SkillEntity(
            id: 'mrk_a2',
            name: 'Armor Shatter Shot',
            description: 'Arrow that ignores 50% target defense.',
            damageCoefficient: 1.35,
            cooldownTurns: 2,
            ignoresArmor: true,
          ),
          SkillEntity(
            id: 'mrk_ult',
            name: 'Rain of Obsidian',
            description: 'Barrage striking all enemy vessels.',
            damageCoefficient: 1.6,
            targetType: SkillTargetType.allEnemies,
            isLimitBurst: true,
          ),
        ];
      case Archetype.skirmisher:
        return const [
          SkillEntity(
            id: 'skm_a1',
            name: 'Talon Rake',
            description: 'Evasive claw strike.',
            damageCoefficient: 1.0,
          ),
          SkillEntity(
            id: 'skm_a2',
            name: 'Dive Bomb',
            description: 'High-speed swoop dealing bonus damage.',
            damageCoefficient: 1.5,
            cooldownTurns: 2,
          ),
          SkillEntity(
            id: 'skm_ult',
            name: 'Whirlwind Tempest',
            description: 'Swoops across all foes with blinding speed.',
            damageCoefficient: 1.7,
            targetType: SkillTargetType.allEnemies,
            isLimitBurst: true,
          ),
        ];
      case Archetype.support:
        return const [
          SkillEntity(
            id: 'sup_a1',
            name: 'Spirit Wand',
            description: 'Mystic pulse.',
            damageCoefficient: 0.9,
          ),
          SkillEntity(
            id: 'sup_a2',
            name: 'Soothing Mist',
            description: 'Restores 25% HP to target ally.',
            damageCoefficient: 0.0,
            cooldownTurns: 3,
            targetType: SkillTargetType.singleAlly,
          ),
          SkillEntity(
            id: 'sup_ult',
            name: 'Ancestral Ward',
            description: 'Bestows +30% Armor on all allies for 2 turns.',
            damageCoefficient: 0.0,
            targetType: SkillTargetType.allAllies,
            isLimitBurst: true,
            appliedStatus: StatusEffect(type: StatusEffectType.defenseUp, durationTurns: 2),
          ),
        ];
      case Archetype.occultist:
        return const [
          SkillEntity(
            id: 'occ_a1',
            name: 'Blight Bolt',
            description: 'Corrosive necrotic projectile.',
            damageCoefficient: 1.0,
          ),
          SkillEntity(
            id: 'occ_a2',
            name: 'Miasma Cloud',
            description: 'Infects target with 2 turns of Blight DoT.',
            damageCoefficient: 1.2,
            cooldownTurns: 2,
            appliedStatus: StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 50),
          ),
          SkillEntity(
            id: 'occ_ult',
            name: 'Abyssal Nova',
            description: 'Massive necrotic wave over all enemies.',
            damageCoefficient: 1.8,
            targetType: SkillTargetType.allEnemies,
            isLimitBurst: true,
          ),
        ];
    }
  }

  UnitEntity copyWith({
    int? currentHp,
    int? level,
    int? maxHp,
    int? attack,
    int? defense,
    int? speed,
    double? turnMeter,
    double? ultimateCharge,
    List<StatusEffect>? activeEffects,
    List<SkillEntity>? skills,
    String? nativeTraitId,
    String? graftedTraitId,
    FormationSlot? slot,
    String? customAvatarAsset,
    int? currentXp,
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
      ultimateCharge: ultimateCharge ?? this.ultimateCharge,
      activeEffects: activeEffects ?? this.activeEffects,
      skills: skills ?? this.skills,
      nativeTraitId: nativeTraitId ?? this.nativeTraitId,
      graftedTraitId: graftedTraitId ?? this.graftedTraitId,
      lineageAncestors: lineageAncestors,
      customAvatarAsset: customAvatarAsset ?? this.customAvatarAsset,
      currentXp: currentXp ?? this.currentXp,
    );
  }

  /// Checks if unit or any of its progenitors belongs to the specified bloodline lineage tag.
  bool hasLineage(String tag) {
    final lower = tag.toLowerCase();
    if (speciesId.toLowerCase().contains(lower)) return true;
    for (final ancestor in lineageAncestors) {
      if (ancestor.toLowerCase().contains(lower)) return true;
    }
    return false;
  }

  /// Whether unit carries verified Beastline ancestry (Feral Hounds, Bats, Wolves, Skirmishers).
  bool get hasBeastLineage {
    return archetype == Archetype.skirmisher ||
        speciesId.contains('hound') ||
        speciesId.contains('cerberus') ||
        speciesId.contains('beast') ||
        speciesId.contains('bat') ||
        speciesId.contains('wolf') ||
        speciesId.contains('fang') ||
        lineageAncestors.any((a) {
          final l = a.toLowerCase();
          return l.contains('hound') ||
              l.contains('cerberus') ||
              l.contains('beast') ||
              l.contains('wolf') ||
              l.contains('fang') ||
              l.contains('bloodline_beast');
        });
  }

  /// Whether unit carries verified Deathless / Undead ancestry (Grave Disciples, Ghouls, Liches, Skeletons, Occultists).
  bool get hasUndeadLineage {
    return archetype == Archetype.occultist ||
        speciesId.contains('grave') ||
        speciesId.contains('disciple') ||
        speciesId.contains('undead') ||
        speciesId.contains('lich') ||
        speciesId.contains('ghoul') ||
        speciesId.contains('skeleton') ||
        speciesId.contains('vampire') ||
        speciesId.contains('deathless') ||
        lineageAncestors.any((a) {
          final l = a.toLowerCase();
          return l.contains('grave') ||
              l.contains('disciple') ||
              l.contains('undead') ||
              l.contains('lich') ||
              l.contains('ghoul') ||
              l.contains('skeleton') ||
              l.contains('vampire') ||
              l.contains('deathless') ||
              l.contains('bloodline_undead');
        });
  }

  /// List of verified human-readable lineage tags for UI display.
  List<String> get verifiedLineageTags {
    final tags = <String>[];
    if (hasBeastLineage) tags.add('Beastline');
    if (hasUndeadLineage) tags.add('Deathless');
    if (speciesId.contains('footman') || lineageAncestors.any((a) => a.contains('footman'))) {
      tags.add('Ironclad');
    }
    if (speciesId.contains('archer') || lineageAncestors.any((a) => a.contains('archer'))) {
      tags.add('Ashen Legion');
    }
    return tags;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'speciesId': speciesId,
      'name': name,
      'generation': generation,
      'archetype': archetype.name,
      'slot': slot.name,
      'level': level,
      'maxLevel': maxLevel,
      'currentHp': currentHp,
      'maxHp': maxHp,
      'attack': attack,
      'defense': defense,
      'speed': speed,
      'critRate': critRate,
      'critDamage': critDamage,
      'nativeTraitId': nativeTraitId,
      'graftedTraitId': graftedTraitId,
      'lineageAncestors': lineageAncestors,
      'customAvatarAsset': customAvatarAsset,
      'currentXp': currentXp,
    };
  }

  factory UnitEntity.fromJson(Map<String, dynamic> json) {
    return UnitEntity(
      id: json['id'] as String,
      speciesId: json['speciesId'] as String,
      name: json['name'] as String,
      generation: (json['generation'] as num).toInt(),
      archetype: Archetype.values.firstWhere(
        (a) => a.name == json['archetype'],
        orElse: () => Archetype.juggernaut,
      ),
      slot: FormationSlot.values.firstWhere(
        (s) => s.name == json['slot'],
        orElse: () => FormationSlot.front1,
      ),
      level: (json['level'] as num).toInt(),
      maxLevel: (json['maxLevel'] as num).toInt(),
      currentHp: (json['currentHp'] as num).toInt(),
      maxHp: (json['maxHp'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      speed: (json['speed'] as num).toInt(),
      critRate: (json['critRate'] as num?)?.toDouble() ?? 0.15,
      critDamage: (json['critDamage'] as num?)?.toDouble() ?? 1.50,
      nativeTraitId: json['nativeTraitId'] as String? ?? 'none',
      graftedTraitId: json['graftedTraitId'] as String?,
      lineageAncestors: (json['lineageAncestors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      customAvatarAsset: json['customAvatarAsset'] as String?,
      currentXp: (json['currentXp'] as num?)?.toInt() ?? 0,
    );
  }
}
