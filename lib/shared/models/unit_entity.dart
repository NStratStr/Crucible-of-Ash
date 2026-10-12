import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import 'skill_entity.dart';

enum FormationSlot { front1, front2, front3, back1, back2 }

/// GDD v2.6 Pillar 1 & Sec 4: Physical Miniature Plinth Crafting
/// Modular bases and plinth materials providing distinct tabletop tactile aesthetics and passive stat affinity.
enum PlinthMaterial {
  slate,      // Weathered Ash Slate (Standard military baseline)
  obsidian,   // Volcanic Glass (+10% Crit Damage, deep dark purple sheen)
  bone,       // Defiled Crypt Bone (+5% Lifesteal, pale sepia calcified rim)
  iron,       // Cold Forged Iron (+15% Armor, industrial brushed metallic sheen)
  gold,       // Consecrated Pureblood Gold (+10% All-stats, ornate gleaming rim)
}

@immutable
class UnitEntity {
  final String id;
  final String speciesId;
  final String name;
  final int generation; // 1, 2, 3, or 4 (Pureblood)
  final Archetype archetype;
  final FormationSlot slot;
  final PlinthMaterial plinthMaterial;
  final bool? isFrontlineOverride; // When set, overrides slot-based frontline/backline assignment
  final int? columnIndexOverride; // When set, explicitly assigns column (0..4)

  // Progression & Health
  final int level;
  final int maxLevel;
  final int currentHp;

  // Attributes & Defense (GDD v2.6 Sec 3.1)
  final int maxHp;
  final int attack;
  final int defense;
  final int speed;
  final int resist;
  final int flatAbsorb;
  final double critRate;
  final double critDamage;

  // Revive & Soul Fracture (GDD v2.6 Sec 3.4)
  final int reviveCount;

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
    this.plinthMaterial = PlinthMaterial.slate,
    this.isFrontlineOverride,
    this.columnIndexOverride,
    required this.level,
    required this.maxLevel,
    required this.currentHp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.speed,
    this.resist = 50,
    this.flatAbsorb = 0,
    this.reviveCount = 0,
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

  /// GDD v2.6: Armor is an alias for physical defense rating.
  int get armor => defense;

  /// GDD v2.6 Sec 3.4: Stacking -20% Max HP penalty for each revive in battle.
  int get effectiveMaxHp => (maxHp * pow(0.80, reviveCount)).round();

  /// GDD v2.6 Sec 3.1: Effective Health (EHP) calculation.
  double get ehp => CombatMath.calculateEhp(currentHp, armor: defense, resist: resist);

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
    // Commander: Lord Vladislav (Generational Evolution: G1, G3, G6)
    if (id.contains('vladislav') || speciesId.contains('vladislav') || name.contains('Vladislav')) {
      if (generation >= 6) {
        return 'assets/images/Crypt Stalkers/lord_vladislav_g6.png';
      }
      if (generation >= 3) {
        return 'assets/images/Crypt Stalkers/lord_vladislav_g3.png';
      }
      return 'assets/images/Crypt Stalkers/lord_vladislav_g1.png';
    }

    // Commander: Lady Valeria (Generational Evolution: G1, G3, G6)
    if (id.contains('valeria') || speciesId.contains('valeria') || name.contains('Valeria')) {
      if (generation >= 6) {
        return 'assets/images/Ash Legion/lady_valeria_g6.png';
      }
      if (generation >= 3) {
        return 'assets/images/Ash Legion/lady_valeria_g3.png';
      }
      return 'assets/images/Ash Legion/lady_valeria_g1.png';
    }

    // Primordial Boss / Titan / Colossus
    if (isBoss ||
        speciesId.contains('butcher') ||
        speciesId.contains('flayed') ||
        speciesId.contains('executioner') ||
        speciesId.contains('titan') ||
        name.contains('Flayed') ||
        name.contains('Butcher') ||
        name.contains('Executioner') ||
        name.contains('Titan')) {
      if (speciesId.contains('golem') || speciesId.contains('colossus') || name.contains('Golem') || name.contains('Colossus')) {
        return 'assets/images/magma_golem.png';
      }
      return 'assets/images/flayed_butcher.png';
    }

    if (speciesId.contains('golem') || speciesId.contains('colossus') || name.contains('Golem') || name.contains('Colossus')) {
      return 'assets/images/magma_golem.png';
    }

    // Evolution flag: Gen 4+ or pureblood triggers sovereign/pureblood evolution
    final bool isFinalEvolution = isPureblood || generation >= 4;

    // Crypt Stalkers: Rotting Husk (Juggernaut)
    if (speciesId.contains('husk') || name.contains('Husk')) {
      return 'assets/images/rotting_husk_g1.png';
    }

    // Crypt Stalkers: Ghoul / Flayer / Strigoi Lord line
    if (speciesId.contains('strigoi') || name.contains('Strigoi')) {
      return 'assets/images/strigoi_lord_g6.png';
    }
    if (speciesId.contains('flayer') || name.contains('Flayer')) {
      return 'assets/images/sanguine_flayer_g3.png';
    }
    if (speciesId.contains('ghoul') || name.contains('Ghoul')) {
      if (isFinalEvolution) return 'assets/images/strigoi_lord_g6.png';
      if (generation >= 3) return 'assets/images/sanguine_flayer_g3.png';
      return 'assets/images/grave_ghoul_g1.png';
    }

    // Ash Legion: Iron Footman / Sun-Forged Veteran / Lord Justicar line
    if (speciesId.contains('justicar') || name.contains('Justicar')) {
      return 'assets/images/lord_justicar_g6.png';
    }
    if (speciesId.contains('veteran') || name.contains('Veteran')) {
      return 'assets/images/sun_forged_veteran_g3.png';
    }
    if (speciesId.contains('footman') || name.contains('Footman')) {
      if (isFinalEvolution) return 'assets/images/lord_justicar_g6.png';
      if (generation >= 3) return 'assets/images/sun_forged_veteran_g3.png';
      return 'assets/images/iron_footman_g1.png';
    }

    // Ash Legion: Solar Inquisitor / Inquisitor line
    if (speciesId.contains('inquisitor') || name.contains('Inquisitor')) {
      return 'assets/images/UI/Solar Inquisitor - ASH - 02 -  ASN - G3 Tansparent.png';
    }

    // Ash Legion: Sun-Scorched Cleric / Field Medicus line
    if (speciesId.contains('cleric') || name.contains('Cleric') || speciesId.contains('medicus') || name.contains('Medicus')) {
      return 'assets/images/sun_scorched_cleric.png';
    }

    // Feral Beast / Cerberus line
    if (speciesId.contains('cerberus') ||
        speciesId.contains('hound') ||
        speciesId.contains('wolf') ||
        speciesId.contains('beast') ||
        name.contains('Cerberus') ||
        name.contains('Hound')) {
      if (isFinalEvolution || speciesId.contains('cerberus') || name.contains('Cerberus')) {
        return 'assets/images/cerberus_pureblood.png';
      }
      return 'assets/images/feral_warhound.png';
    }

    // Occultist / Support / Lich / Cleric / Medicus / Alchemist line
    if (archetype == Archetype.occultist ||
        archetype == Archetype.support ||
        speciesId.contains('occultist') ||
        speciesId.contains('lich') ||
        speciesId.contains('apothecary') ||
        speciesId.contains('plague') ||
        speciesId.contains('warlock') ||
        speciesId.contains('witch') ||
        speciesId.contains('alchemist') ||
        name.contains('Disciple') ||
        name.contains('Weave') ||
        name.contains('Lich') ||
        name.contains('Alchemist')) {
      if (isFinalEvolution || name.contains('Void') || name.contains('Lich') || speciesId.contains('lich')) {
        return 'assets/images/lich_pureblood.png';
      }
      return 'assets/images/occultist_base.png';
    }

    // Marksman / Ballista / Arbalest line
    if (archetype == Archetype.marksman ||
        speciesId.contains('archer') ||
        speciesId.contains('marksman') ||
        speciesId.contains('sniper') ||
        speciesId.contains('ballista') ||
        speciesId.contains('arbalest') ||
        name.contains('Archer') ||
        name.contains('Sniper') ||
        name.contains('Ballista') ||
        name.contains('Arbalest')) {
      if (isFinalEvolution || speciesId.contains('ballista') || name.contains('Ballista')) {
        return 'assets/images/ballista_pureblood.png';
      }
      return 'assets/images/marksman_base.png';
    }

    // Assassin / Skirmisher / Vampire / Duelist line
    if (archetype == Archetype.assassin ||
        archetype == Archetype.skirmisher ||
        speciesId.contains('stalker') ||
        speciesId.contains('slayer') ||
        speciesId.contains('reaper') ||
        speciesId.contains('vampire') ||
        speciesId.contains('duelist') ||
        name.contains('Shadow') ||
        name.contains('Blade') ||
        name.contains('Skirmisher') ||
        name.contains('Vampire') ||
        name.contains('Duelist')) {
      if (isFinalEvolution || name.contains('Eclipse') || name.contains('Vampire') || speciesId.contains('vampire')) {
        return 'assets/images/vampire_pureblood.png';
      }
      return 'assets/images/grave_ghoul_g1.png';
    }

    // Juggernaut / Knight / Paladin / Dreadnought line
    if (archetype == Archetype.juggernaut ||
        speciesId.contains('knight') ||
        speciesId.contains('dreadnought') ||
        speciesId.contains('paladin') ||
        speciesId.contains('guardian') ||
        name.contains('Dreadnought') ||
        name.contains('Paladin')) {
      if (isFinalEvolution || speciesId.contains('dreadnought') || name.contains('Dreadnought')) {
        return 'assets/images/lord_justicar_g6.png';
      }
      if (generation >= 3) {
        return 'assets/images/sun_forged_veteran_g3.png';
      }
      return 'assets/images/iron_footman_g1.png';
    }

    return isFinalEvolution
        ? 'assets/images/lord_justicar_g6.png'
        : 'assets/images/iron_footman_g1.png';
  }

  String get factionName {
    if (isBoss) return 'Primordial Titans';
    if (speciesId.contains('hound') ||
        speciesId.contains('wolf') ||
        speciesId.contains('beast') ||
        speciesId.contains('cerberus') ||
        speciesId.contains('boar')) {
      return 'Corrupted Beasts';
    }
    if (speciesId.contains('ghoul') ||
        speciesId.contains('plague') ||
        speciesId.contains('deathless') ||
        speciesId.contains('crypt') ||
        speciesId.contains('husk') ||
        speciesId.contains('necro') ||
        name.contains('Crypt') ||
        name.contains('Husk') ||
        archetype == Archetype.occultist) {
      return 'Crypt Stalkers';
    }
    if (speciesId.contains('void') ||
        speciesId.contains('cult') ||
        speciesId.contains('rift') ||
        name.contains('Void')) {
      return 'Occult Void Cult';
    }
    return 'Ash Legion';
  }

  bool get isFigurineCutout =>
      effectiveAvatarAsset.endsWith('.png') ||
      effectiveAvatarAsset.toLowerCase().contains('vladislav');

  /// GDD v2.9 Section 3.1 & 3.2: Deterministic 5-Column & Dual-Row Spatial Geometry
  /// Each unit occupies a column index from 0 (Far Left) to 4 (Far Right).
  int get columnIndex => columnIndexOverride ?? slot.index.clamp(0, 4);

  /// GDD v2.8 Sec 3.4: Flexible formation customization allows any unit (including all 5)
  /// to be stationed in Frontline or Backline.
  bool get isFrontline => isFrontlineOverride ?? (slot.index < 3);
  bool get isBackline => !isFrontline;

  bool get isVanguard => isFrontline;
  bool get isArcanum => isBackline;
  bool get isAlive => currentHp > 0;
  bool get isStunned => activeEffects.any((e) => e.type == StatusEffectType.stun);
  bool get isBleeding => activeEffects.any((e) => e.type == StatusEffectType.bleed);
  int get bleedStacks => activeEffects
      .where((e) => e.type == StatusEffectType.bleed)
      .fold<int>(0, (sum, e) => sum + (e.value > 0 ? e.value : 1))
      .clamp(0, 10);
  bool get isBlighted => activeEffects.any((e) => e.type == StatusEffectType.blight);
  int get blightStacks => activeEffects
      .where((e) => e.type == StatusEffectType.blight)
      .fold<int>(0, (sum, e) => sum + (e.value > 0 ? e.value : 1))
      .clamp(0, 10);
  bool get isBurning => activeEffects.any((e) => e.type == StatusEffectType.burn);
  bool get isFrozen => activeEffects.any((e) => e.type == StatusEffectType.freeze);
  bool get isVulnerable => activeEffects.any((e) => e.type == StatusEffectType.vulnerable);
  bool get hasHaste => activeEffects.any((e) => e.type == StatusEffectType.speedUp);
  bool get isTaunting => activeEffects.any((e) => e.type == StatusEffectType.taunt);
  int get shieldPoints => activeEffects
      .where((e) => e.type == StatusEffectType.shield)
      .fold<int>(0, (sum, e) => sum + e.value);
  bool get hasShield => shieldPoints > 0;

  /// Dynamic Threat Score (GDD v2.6 Sec 3.3): Attack * (1 + CritRate) * (Speed / 100)
  double get threatScore => attack * (1.0 + critRate) * (speed / 100.0);

  /// GDD v2.8 Sec 3.3 Role Class Priority Order:
  /// Support/Healer (1) > Occultist (2) > Marksman/Assassin/Skirmisher/DPS (3) > Juggernaut/Tank (4)
  int get rolePriorityOrder {
    switch (archetype) {
      case Archetype.support:
        return 1;
      case Archetype.occultist:
        return 2;
      case Archetype.marksman:
      case Archetype.assassin:
      case Archetype.skirmisher:
        return 3;
      case Archetype.juggernaut:
        return 4;
    }
  }

  bool get isPureblood => generation >= 4;
  String get generationTitle => isPureblood ? 'Pureblood (Gen 4)' : 'Gen $generation';

  /// Plinth material title and tactical passive affinity (GDD v2.6 Pillar 1)
  String get plinthMaterialTitle {
    switch (plinthMaterial) {
      case PlinthMaterial.obsidian:
        return 'Obsidian Plinth (+10% Crit DMG)';
      case PlinthMaterial.bone:
        return 'Crypt Bone Plinth (+5% Lifesteal)';
      case PlinthMaterial.iron:
        return 'Cold Iron Plinth (+15% Armor)';
      case PlinthMaterial.gold:
        return 'Pureblood Gold Plinth (+10% All Stats)';
      case PlinthMaterial.slate:
      default:
        return 'Ashen Slate Plinth (Standard)';
    }
  }

  /// Base plinth rim border color for visual compositing
  int get plinthRimBorderColorValue {
    switch (plinthMaterial) {
      case PlinthMaterial.obsidian:
        return 0xFF7B1FA2; // Deep purple
      case PlinthMaterial.bone:
        return 0xFFBCAAA4; // Sepia bone
      case PlinthMaterial.iron:
        return 0xFF78909C; // Steel metallic
      case PlinthMaterial.gold:
        return 0xFFFFD54F; // Gleaming gold
      case PlinthMaterial.slate:
      default:
        return 0xFF455A64; // Dark ashen slate
    }
  }
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

  /// GDD v2.8 Sec 3.5: Whether this board unit is an Arch-Sculptor / Commander.
  bool get isCommander =>
      id.contains('commander') ||
      id.contains('vladislav') ||
      id.contains('valeria') ||
      id.contains('malakor') ||
      id.contains('morrigan') ||
      speciesId.contains('commander') ||
      name.contains('Vladislav') ||
      name.contains('Valeria') ||
      name.contains('Malakor') ||
      name.contains('Morrigan');

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
            description: 'Devastating execution burst targeting lowest HP enemy.',
            damageCoefficient: 2.4,
            targetType: SkillTargetType.lowestHpEnemy,
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
    String? id,
    String? speciesId,
    String? name,
    int? generation,
    Archetype? archetype,
    int? currentHp,
    int? level,
    int? maxHp,
    int? attack,
    int? defense,
    int? speed,
    int? resist,
    int? flatAbsorb,
    int? reviveCount,
    double? critRate,
    double? critDamage,
    double? turnMeter,
    double? ultimateCharge,
    List<StatusEffect>? activeEffects,
    List<SkillEntity>? skills,
    String? nativeTraitId,
    String? graftedTraitId,
    FormationSlot? slot,
    PlinthMaterial? plinthMaterial,
    String? customAvatarAsset,
    int? currentXp,
    bool? isFrontlineOverride,
    int? columnIndexOverride,
  }) {
    return UnitEntity(
      id: id ?? this.id,
      speciesId: speciesId ?? this.speciesId,
      name: name ?? this.name,
      generation: generation ?? this.generation,
      archetype: archetype ?? this.archetype,
      slot: slot ?? this.slot,
      plinthMaterial: plinthMaterial ?? this.plinthMaterial,
      isFrontlineOverride: isFrontlineOverride ?? this.isFrontlineOverride,
      columnIndexOverride: columnIndexOverride ?? this.columnIndexOverride,
      level: level ?? this.level,
      maxLevel: maxLevel,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      speed: speed ?? this.speed,
      resist: resist ?? this.resist,
      flatAbsorb: flatAbsorb ?? this.flatAbsorb,
      reviveCount: reviveCount ?? this.reviveCount,
      critRate: critRate ?? this.critRate,
      critDamage: critDamage ?? this.critDamage,
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
      'resist': resist,
      'flatAbsorb': flatAbsorb,
      'reviveCount': reviveCount,
      'critRate': critRate,
      'critDamage': critDamage,
      'nativeTraitId': nativeTraitId,
      'graftedTraitId': graftedTraitId,
      'lineageAncestors': lineageAncestors,
      'customAvatarAsset': customAvatarAsset,
      'currentXp': currentXp,
      'plinthMaterial': plinthMaterial.name,
      'isFrontlineOverride': isFrontlineOverride,
      'columnIndexOverride': columnIndexOverride,
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
      plinthMaterial: PlinthMaterial.values.firstWhere(
        (p) => p.name == json['plinthMaterial'],
        orElse: () => PlinthMaterial.slate,
      ),
      isFrontlineOverride: json['isFrontlineOverride'] as bool?,
      columnIndexOverride: (json['columnIndexOverride'] as num?)?.toInt(),
      level: (json['level'] as num).toInt(),
      maxLevel: (json['maxLevel'] as num).toInt(),
      currentHp: (json['currentHp'] as num).toInt(),
      maxHp: (json['maxHp'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      speed: (json['speed'] as num).toInt(),
      resist: (json['resist'] as num?)?.toInt() ?? 50,
      flatAbsorb: (json['flatAbsorb'] as num?)?.toInt() ?? 0,
      reviveCount: (json['reviveCount'] as num?)?.toInt() ?? 0,
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
