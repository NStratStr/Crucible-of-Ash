import 'dart:math';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';

enum SummonBannerType {
  ashenBloodline,
  consecratedSigil,
  cryptCovenant,
  commanderCovenant,
}

class BannerConfig {
  final SummonBannerType type;
  final String title;
  final String subtitle;
  final String loreDescription;
  final String currencyName;
  final int singleCost;
  final int multiCost;
  final bool usesSigils;
  final double gen1Rate;
  final double gen2Rate;
  final double gen3Rate;
  final String bannerBadge;
  final String themeColorHex;

  const BannerConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.loreDescription,
    required this.currencyName,
    required this.singleCost,
    required this.multiCost,
    required this.usesSigils,
    required this.gen1Rate,
    required this.gen2Rate,
    required this.gen3Rate,
    required this.bannerBadge,
    required this.themeColorHex,
  });
}

class SummonResult {
  final List<UnitEntity> summonedUnits;
  final int ichorSpent;
  final int sigilsSpent;
  final BannerConfig banner;

  const SummonResult({
    required this.summonedUnits,
    required this.ichorSpent,
    required this.sigilsSpent,
    required this.banner,
  });
}

class SummoningService {
  static final Map<SummonBannerType, BannerConfig> banners = {
    SummonBannerType.ashenBloodline: const BannerConfig(
      type: SummonBannerType.ashenBloodline,
      title: 'ASHEN BLOODLINE RITE',
      subtitle: 'Standard Thrall Convocation',
      loreDescription:
          'Feed raw Ichor into the central crucible to awaken unshaped souls and standard line thralls. Excellent for Crucible donor stock.',
      currencyName: 'Ichor',
      singleCost: 100,
      multiCost: 900, // 10 pulls for 900 (10% discount)
      usesSigils: false,
      gen1Rate: 0.82,
      gen2Rate: 0.15,
      gen3Rate: 0.03,
      bannerBadge: 'BASIC PACT',
      themeColorHex: '#E5A93C',
    ),
    SummonBannerType.consecratedSigil: const BannerConfig(
      type: SummonBannerType.consecratedSigil,
      title: 'CONSECRATED COVENANT',
      subtitle: 'Pureblood Lineage Manifestation',
      loreDescription:
          'Spend ancestral Bloodline Sigils to compel ancient progenitors and high-generation champions from the crypts of old.',
      currencyName: 'Bloodline Sigils',
      singleCost: 1,
      multiCost: 9, // 10 pulls for 9 sigils (10% discount)
      usesSigils: true,
      gen1Rate: 0.40,
      gen2Rate: 0.45,
      gen3Rate: 0.15,
      bannerBadge: 'ELITE RITE',
      themeColorHex: '#D4AF37',
    ),
    SummonBannerType.cryptCovenant: const BannerConfig(
      type: SummonBannerType.cryptCovenant,
      title: 'CRYPT STALKER SUMMONS',
      subtitle: 'Undead & Occult Vanguard Focus',
      loreDescription:
          'Attune the altar with necrotic resonance to summon ghouls, skeletons, husks, and blight spellweavers with heightened affinity.',
      currencyName: 'Ichor',
      singleCost: 120,
      multiCost: 1000,
      usesSigils: false,
      gen1Rate: 0.75,
      gen2Rate: 0.20,
      gen3Rate: 0.05,
      bannerBadge: 'FOCUS BATCH',
      themeColorHex: '#9C27B0',
    ),
    SummonBannerType.commanderCovenant: const BannerConfig(
      type: SummonBannerType.commanderCovenant,
      title: 'PROGENITOR ARCHONS',
      subtitle: 'Legendary Commander Manifestation',
      loreDescription:
          'Invoke the primal bloodline of high commanders: Lord Vladislav, Lady Valeria, High Inquisitor Malakor, and Mother Morrigan with boosted pull rates.',
      currencyName: 'Bloodline Sigils',
      singleCost: 2,
      multiCost: 18,
      usesSigils: true,
      gen1Rate: 0.20,
      gen2Rate: 0.50,
      gen3Rate: 0.30,
      bannerBadge: 'COMMANDER RATE-UP',
      themeColorHex: '#FF1744',
    ),
  };

  /// Performs a single (1x) or multi (10x) summon based on count and selected banner.
  /// Deducts currency from totalIchor/bloodlineSigils and returns a SummonResult.
  static SummonResult performSummon({
    required SummonBannerType bannerType,
    required int count,
    required int currentIchor,
    required int currentSigils,
    Random? rng,
  }) {
    final banner = banners[bannerType]!;
    final cost = count >= 10
        ? (count ~/ 10) * banner.multiCost + (count % 10) * banner.singleCost
        : count * banner.singleCost;
    final random = rng ?? Random();

    if (banner.usesSigils) {
      if (currentSigils < cost) {
        throw StateError('Insufficient Bloodline Sigils: Required $cost, available $currentSigils');
      }
    } else {
      if (currentIchor < cost) {
        throw StateError('Insufficient Ichor: Required $cost, available $currentIchor');
      }
    }

    final List<UnitEntity> summoned = [];
    for (int i = 0; i < count; i++) {
      summoned.add(_rollSingleUnit(banner, random, i));
    }

    return SummonResult(
      summonedUnits: summoned,
      ichorSpent: banner.usesSigils ? 0 : cost,
      sigilsSpent: banner.usesSigils ? cost : 0,
      banner: banner,
    );
  }

  static UnitEntity _rollSingleUnit(BannerConfig banner, Random rng, int indexOffset) {
    final roll = rng.nextDouble();
    int generation;
    if (roll < banner.gen3Rate) {
      generation = 3;
    } else if (roll < banner.gen3Rate + banner.gen2Rate) {
      generation = 2;
    } else {
      generation = 1;
    }

    final archetypeIndex = rng.nextInt(6);
    final archetype = Archetype.values[archetypeIndex];
    final timestamp = DateTime.now().microsecondsSinceEpoch + indexOffset;

    if (banner.type == SummonBannerType.commanderCovenant) {
      return _generateCommanderOrArchon(generation, archetype, timestamp, rng);
    } else if (banner.type == SummonBannerType.cryptCovenant) {
      return _generateCryptSpecialist(generation, archetype, timestamp, rng);
    } else {
      return _generateAshOrStandardThrall(generation, archetype, timestamp, rng);
    }
  }

  static UnitEntity _generateAshOrStandardThrall(
    int generation,
    Archetype archetype,
    int timestamp,
    Random rng,
  ) {
    final statMult = 1.0 + (generation - 1) * 0.35;
    final String genPrefix = generation == 1 ? 'Novice' : (generation == 2 ? 'Elite' : 'Pureblood');

    switch (archetype) {
      case Archetype.juggernaut:
        return UnitEntity(
          id: 'summon_jug_$timestamp',
          speciesId: generation >= 3 ? 'cerberus_spawn' : 'iron_footman',
          name: '$genPrefix Iron Footman',
          generation: generation,
          archetype: Archetype.juggernaut,
          slot: FormationSlot.front1,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (850 * statMult).round(),
          maxHp: (850 * statMult).round(),
          attack: (115 * statMult).round(),
          defense: (135 * statMult).round(),
          speed: (90 * statMult).round(),
          nativeTraitId: 'shield_bash',
          graftedTraitId: generation >= 3 ? 'iron_bastion' : null,
          lineageAncestors: generation > 1 ? ['ironclad_veteran'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.assassin:
        return UnitEntity(
          id: 'summon_asn_$timestamp',
          speciesId: generation >= 3 ? 'strigoi_noble' : 'grave_duelist',
          name: '$genPrefix Grave Duelist',
          generation: generation,
          archetype: Archetype.assassin,
          slot: FormationSlot.front2,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (650 * statMult).round(),
          maxHp: (650 * statMult).round(),
          attack: (150 * statMult).round(),
          defense: (70 * statMult).round(),
          speed: (125 * statMult).round(),
          critRate: 0.20 + (generation * 0.05),
          critDamage: 1.60,
          nativeTraitId: 'vicious_strike',
          graftedTraitId: generation >= 3 ? 'rend_flesh' : null,
          lineageAncestors: generation > 1 ? ['ashen_inquisitor'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.marksman:
        return UnitEntity(
          id: 'summon_mrk_$timestamp',
          speciesId: generation >= 3 ? 'siege_sniper' : 'iron_arbalest',
          name: '$genPrefix Iron Arbalest',
          generation: generation,
          archetype: Archetype.marksman,
          slot: FormationSlot.back1,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (580 * statMult).round(),
          maxHp: (580 * statMult).round(),
          attack: (165 * statMult).round(),
          defense: (65 * statMult).round(),
          speed: (110 * statMult).round(),
          critRate: 0.22,
          critDamage: 1.65,
          nativeTraitId: 'piercing_bolt',
          graftedTraitId: generation >= 3 ? 'keen_eye' : null,
          lineageAncestors: generation > 1 ? ['siege_arbalest'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.skirmisher:
        return UnitEntity(
          id: 'summon_skm_$timestamp',
          speciesId: 'gargoyle_stalker',
          name: '$genPrefix Gargoyle Raider',
          generation: generation,
          archetype: Archetype.skirmisher,
          slot: FormationSlot.front3,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (620 * statMult).round(),
          maxHp: (620 * statMult).round(),
          attack: (140 * statMult).round(),
          defense: (80 * statMult).round(),
          speed: (124 * statMult).round(),
          nativeTraitId: 'dive_bomb',
          graftedTraitId: generation >= 3 ? 'pack_instinct' : null,
          lineageAncestors: generation > 1 ? ['gargoyle_elder'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.support:
        return UnitEntity(
          id: 'summon_sup_$timestamp',
          speciesId: 'field_medicus',
          name: '$genPrefix Field Medicus',
          generation: generation,
          archetype: Archetype.support,
          slot: FormationSlot.back2,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (720 * statMult).round(),
          maxHp: (720 * statMult).round(),
          attack: (115 * statMult).round(),
          defense: (90 * statMult).round(),
          speed: (102 * statMult).round(),
          nativeTraitId: 'healing_touch',
          graftedTraitId: generation >= 3 ? 'sanguine_mend' : null,
          lineageAncestors: generation > 1 ? ['sunlight_banneret'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.occultist:
        return UnitEntity(
          id: 'summon_occ_$timestamp',
          speciesId: 'grave_disciple',
          name: '$genPrefix Grave Occultist',
          generation: generation,
          archetype: Archetype.occultist,
          slot: FormationSlot.back2,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (590 * statMult).round(),
          maxHp: (590 * statMult).round(),
          attack: (155 * statMult).round(),
          defense: (68 * statMult).round(),
          speed: (96 * statMult).round(),
          nativeTraitId: 'blight_curse',
          graftedTraitId: generation >= 3 ? 'shadow_bolt' : null,
          lineageAncestors: generation > 1 ? ['lich_dominus'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
    }
  }

  static UnitEntity _generateCommanderOrArchon(
    int generation,
    Archetype archetype,
    int timestamp,
    Random rng,
  ) {
    // 60% chance to pull one of the four legendary commanders directly
    final isCommanderPull = rng.nextDouble() < 0.60;
    if (isCommanderPull) {
      final cmdRoll = rng.nextInt(4);
      final statMult = 1.0 + (generation - 1) * 0.40;
      switch (cmdRoll) {
        case 0:
          return UnitEntity(
            id: 'summon_cmd_vladislav_$timestamp',
            speciesId: 'commander_vladislav',
            name: generation >= 3 ? 'Paragon Lord Vladislav' : (generation == 2 ? 'Veteran Lord Vladislav' : 'Lord Vladislav'),
            generation: generation,
            rarity: UnitRarity.legendary,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 30 + (generation * 5),
            currentHp: (900 * statMult).round(),
            maxHp: (900 * statMult).round(),
            attack: (140 * statMult).round(),
            defense: (110 * statMult).round(),
            speed: (105 * statMult).round(),
            resist: 65,
            critRate: 0.20,
            critDamage: 1.60,
            nativeTraitId: 'vampiric_conduit',
            lineageAncestors: ['strigoi_lord'],
            plinthMaterial: PlinthMaterial.gold,
          );
        case 1:
          return UnitEntity(
            id: 'summon_cmd_valeria_$timestamp',
            speciesId: 'commander_valeria',
            name: generation >= 3 ? 'Paragon Lady Valeria' : (generation == 2 ? 'Veteran Lady Valeria' : 'Lady Valeria'),
            generation: generation,
            rarity: UnitRarity.legendary,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 30 + (generation * 5),
            currentHp: (950 * statMult).round(),
            maxHp: (950 * statMult).round(),
            attack: (130 * statMult).round(),
            defense: (135 * statMult).round(),
            speed: (100 * statMult).round(),
            resist: 70,
            critRate: 0.20,
            critDamage: 1.50,
            nativeTraitId: 'iron_fortitude',
            lineageAncestors: ['ironclad_matron'],
            plinthMaterial: PlinthMaterial.gold,
          );
        case 2:
          return UnitEntity(
            id: 'summon_cmd_malakor_$timestamp',
            speciesId: 'commander_malakor',
            name: generation >= 3 ? 'Paragon Inquisitor Malakor' : (generation == 2 ? 'Veteran Inquisitor Malakor' : 'High Inquisitor Malakor'),
            generation: generation,
            rarity: UnitRarity.legendary,
            archetype: Archetype.skirmisher,
            slot: FormationSlot.front2,
            level: 1,
            maxLevel: 30 + (generation * 5),
            currentHp: (880 * statMult).round(),
            maxHp: (880 * statMult).round(),
            attack: (150 * statMult).round(),
            defense: (110 * statMult).round(),
            speed: (115 * statMult).round(),
            resist: 60,
            critRate: 0.25,
            critDamage: 1.65,
            nativeTraitId: 'purifying_flame',
            lineageAncestors: ['calx_justiciar'],
            plinthMaterial: PlinthMaterial.gold,
          );
        case 3:
        default:
          return UnitEntity(
            id: 'summon_cmd_morrigan_$timestamp',
            speciesId: 'commander_morrigan',
            name: generation >= 3 ? 'Paragon Mother Morrigan' : (generation == 2 ? 'Veteran Mother Morrigan' : 'Mother Morrigan'),
            generation: generation,
            rarity: UnitRarity.legendary,
            archetype: Archetype.occultist,
            slot: FormationSlot.back2,
            level: 1,
            maxLevel: 30 + (generation * 5),
            currentHp: (780 * statMult).round(),
            maxHp: (780 * statMult).round(),
            attack: (165 * statMult).round(),
            defense: (90 * statMult).round(),
            speed: (105 * statMult).round(),
            resist: 75,
            critRate: 0.20,
            critDamage: 1.55,
            nativeTraitId: 'miasma_conduit',
            lineageAncestors: ['mire_matron'],
            plinthMaterial: PlinthMaterial.gold,
          );
      }
    }
    // Otherwise fallback to elite standard/crypt unit with Epic rarity
    final fallbackUnit = _generateAshOrStandardThrall(generation, archetype, timestamp, rng);
    return fallbackUnit.copyWith(rarity: UnitRarity.epic);
  }

  static UnitEntity _generateCryptSpecialist(
    int generation,
    Archetype archetype,
    int timestamp,
    Random rng,
  ) {
    final statMult = 1.0 + (generation - 1) * 0.35;
    final String genPrefix = generation == 1 ? 'Crypt' : (generation == 2 ? 'Awakened' : 'Ancient Sovereign');

    switch (archetype) {
      case Archetype.juggernaut:
        return UnitEntity(
          id: 'summon_crypt_jug_$timestamp',
          speciesId: 'rotting_husk',
          name: '$genPrefix Rotting Husk',
          generation: generation,
          archetype: Archetype.juggernaut,
          slot: FormationSlot.front1,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (880 * statMult).round(),
          maxHp: (880 * statMult).round(),
          attack: (105 * statMult).round(),
          defense: (138 * statMult).round(),
          speed: (85 * statMult).round(),
          nativeTraitId: 'iron_bastion',
          graftedTraitId: generation >= 3 ? 'shield_bash' : null,
          lineageAncestors: generation > 1 ? ['grave_titan'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
          customAvatarAsset: 'assets/images/Crypt Stalkers/CRY-01-VAN-G1 Tombstone Sentinel.png',
        );
      case Archetype.assassin:
        return UnitEntity(
          id: 'summon_crypt_asn_$timestamp',
          speciesId: 'grave_ghoul',
          name: '$genPrefix Grave Ghoul',
          generation: generation,
          archetype: Archetype.assassin,
          slot: FormationSlot.front2,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (620 * statMult).round(),
          maxHp: (620 * statMult).round(),
          attack: (152 * statMult).round(),
          defense: (68 * statMult).round(),
          speed: (124 * statMult).round(),
          nativeTraitId: 'rend_flesh',
          graftedTraitId: generation >= 3 ? 'death_mark' : null,
          lineageAncestors: generation > 1 ? ['strigoi_lord'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
          customAvatarAsset: 'assets/images/grave_ghoul_g1.png',
        );
      case Archetype.marksman:
        return UnitEntity(
          id: 'summon_crypt_mrk_$timestamp',
          speciesId: 'bone_archer',
          name: '$genPrefix Bone Archer',
          generation: generation,
          archetype: Archetype.marksman,
          slot: FormationSlot.back1,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (560 * statMult).round(),
          maxHp: (560 * statMult).round(),
          attack: (160 * statMult).round(),
          defense: (62 * statMult).round(),
          speed: (112 * statMult).round(),
          nativeTraitId: 'piercing_arrow',
          graftedTraitId: generation >= 3 ? 'keen_eye' : null,
          lineageAncestors: generation > 1 ? ['wraith_sniper'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.skirmisher:
        return UnitEntity(
          id: 'summon_crypt_skm_$timestamp',
          speciesId: 'blood_bat',
          name: '$genPrefix Vampiric Skirmisher',
          generation: generation,
          archetype: Archetype.skirmisher,
          slot: FormationSlot.front3,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (600 * statMult).round(),
          maxHp: (600 * statMult).round(),
          attack: (142 * statMult).round(),
          defense: (75 * statMult).round(),
          speed: (128 * statMult).round(),
          nativeTraitId: 'screech',
          graftedTraitId: generation >= 3 ? 'dive_bomb' : null,
          lineageAncestors: generation > 1 ? ['strigoi_lord'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
        );
      case Archetype.support:
        return UnitEntity(
          id: 'summon_crypt_sup_$timestamp',
          speciesId: 'blood_alchemist',
          name: '$genPrefix Blood Alchemist',
          generation: generation,
          archetype: Archetype.support,
          slot: FormationSlot.back2,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (670 * statMult).round(),
          maxHp: (670 * statMult).round(),
          attack: (118 * statMult).round(),
          defense: (85 * statMult).round(),
          speed: (100 * statMult).round(),
          nativeTraitId: 'toxic_infusion',
          graftedTraitId: generation >= 3 ? 'sanguine_mend' : null,
          lineageAncestors: generation > 1 ? ['sanguine_priestess'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
          customAvatarAsset: 'assets/images/blood_initiate.png',
        );
      case Archetype.occultist:
        return UnitEntity(
          id: 'summon_crypt_occ_$timestamp',
          speciesId: 'blight_necromancer',
          name: '$genPrefix Blight Necromancer',
          generation: generation,
          archetype: Archetype.occultist,
          slot: FormationSlot.back1,
          level: 1,
          maxLevel: 10 * generation,
          currentHp: (610 * statMult).round(),
          maxHp: (610 * statMult).round(),
          attack: (158 * statMult).round(),
          defense: (72 * statMult).round(),
          speed: (95 * statMult).round(),
          nativeTraitId: 'blight_curse',
          graftedTraitId: generation >= 3 ? 'shadow_bolt' : null,
          lineageAncestors: generation > 1 ? ['lich_dominus'] : const [],
          plinthMaterial: generation >= 3 ? PlinthMaterial.gold : (generation == 2 ? PlinthMaterial.obsidian : PlinthMaterial.iron),
          customAvatarAsset: 'assets/images/Crypt Stalkers/CRY-04-MAG-G1 Blood Scribe.png',
        );
    }
  }
}
