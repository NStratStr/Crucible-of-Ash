import 'package:flutter/material.dart';
import '../../generals/general_command_service.dart';

enum CrucibleSkillDiscipline {
  ash,
  iron,
  sanguine,
  mire,
}

enum CrucibleSkillBranch {
  wrath,      // Attack / Single-Target Execution (Crimson & Embers)
  bastion,    // Defense / Protection (Iron & Stone)
  resonance,  // Hybrid / Retinue Synergy (Amethyst & Blood)
  vitae,      // Healing / Restoration (Emerald & Life Vitae)
  calamity,   // AoE / Area Cleaves & Novas (Amber & Volcanic Storms)
  apex,       // Crown Finishers (White-Gold Overdrive)
}

class CrucibleSkillNode {
  final String id;
  final String name;
  final CrucibleSkillDiscipline discipline;
  final CrucibleSkillBranch branch;
  final int tier; // 1 = Starter, 2 = Core Specialization, 3 = Heavy Devastation, 4 = Apex Finisher
  final int requiredBranchPoints; // Points required in this branch (0 for T1, 1 for T2, 2 for T3, 3 for Apex)
  final String? prerequisiteSkillId; // Specific preceding skill required to be at least Rank 2
  final int defaultSlot; // 1 to 5
  final int cinderCost;
  final IconData icon;
  final String? iconAsset;
  final Color primaryColor;
  final Color borderColor;
  final String actionType;
  final String summary;
  final List<String> rankDescriptions;
  final double baseMultiplier;
  final int maxRank;
  final double cooldownSeconds;

  int rank; // Current rank (1..maxRank = unlocked/upgraded)

  CrucibleSkillNode({
    required this.id,
    required this.name,
    required this.discipline,
    this.branch = CrucibleSkillBranch.wrath,
    this.tier = 1,
    this.requiredBranchPoints = 0,
    this.prerequisiteSkillId,
    required this.defaultSlot,
    required this.cinderCost,
    required this.icon,
    this.iconAsset,
    required this.primaryColor,
    required this.borderColor,
    required this.actionType,
    required this.summary,
    required this.rankDescriptions,
    required this.baseMultiplier,
    this.maxRank = 3,
    this.rank = 1,
    this.cooldownSeconds = 6.0,
  });

  bool get isUnlocked => rank > 0;
  bool get canUpgrade => rank < maxRank;

  double get effectiveMultiplier {
    if (rank <= 1) return baseMultiplier;
    if (rank == 2) return baseMultiplier * 1.25;
    return baseMultiplier * 1.50; // Rank 3
  }

  double get effectiveCooldownSeconds {
    if (rank <= 1) return cooldownSeconds;
    if (rank == 2) return (cooldownSeconds * 0.90); // 10% CDR
    return (cooldownSeconds * 0.80); // 20% CDR at Rank 3
  }

  String get currentRankDescription {
    final idx = (rank - 1).clamp(0, rankDescriptions.length - 1);
    return rankDescriptions[idx];
  }
}

class CrucibleSkillTreeState {
  final Map<String, CrucibleSkillNode> allSkills = {};
  final List<String> equippedSkillIds = List.filled(5, '');
  int availableSkillPoints = 5;

  CrucibleSkillTreeState() {
    _initializeAllSkills();
    configureStartingDiscipline(CrucibleSkillBranch.wrath, startWithBasics: true);
  }

  void _initializeAllSkills() {
    // ==========================================
    // 1. ASH & PYRE DISCIPLINE (Malakor / Forge)
    // ==========================================
    allSkills['ash_cleave'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'ash_cleave',
      branch: CrucibleSkillBranch.wrath,
      name: 'Forge Cleave',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 6.0,
      icon: Icons.sports_mma,
      iconAsset: 'assets/images/icons/skills/icon_skill_forge_cleave.png',
      primaryColor: const Color(0xFFB3261E),
      borderColor: const Color(0xFFFF8A80),
      actionType: 'forge_cleave',
      summary: 'Main cinder generator consuming 0 Cinders. Generates +18 Cinders on strike and inflicts Bleed.',
      baseMultiplier: 1.40,
      rankDescriptions: [
        'Rank 1: 140% ATK cleave + 1 Bleed stack. Generates +18 Cinders (6.0s CD).',
        'Rank 2: 175% ATK cleave + 2 Bleeds + 10% armor pierce. Generates +22 Cinders (5.4s CD).',
        'Rank 3: 210% ATK cleave + 3 Bleeds + row splash. Generates +26 Cinders (4.8s CD).',
      ],
    );

    allSkills['ash_brand'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'ash_cleave',
      id: 'ash_brand',
      name: 'Sundering Brand',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.wrath,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.local_fire_department,
      iconAsset: 'assets/images/icons/skills/icon_skill_sundering_brand.png',
      primaryColor: const Color(0xFFC2185B),
      borderColor: const Color(0xFFFF4081),
      actionType: 'sundering_brand',
      summary: 'Molten brand that permanently shatters armor and triggers retinue ambushes.',
      baseMultiplier: 1.75,
      rankDescriptions: [
        'Rank 1: 175% ATK DMG, shatters 50% Armor, triggers Crypt Stalker ambush.',
        'Rank 2: 215% ATK DMG, shatters 65% Armor + inflicts 3s Vulnerable.',
        'Rank 3: 260% ATK DMG, completely breaks Armor (100% shred) + triggers double ambush.',
      ],
    );

    allSkills['ash_bastion'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'iron_slam',
      id: 'ash_bastion',
      branch: CrucibleSkillBranch.bastion,
      name: 'Obsidian Bastion',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.shield,
      iconAsset: 'assets/images/icons/skills/icon_skill_cinder_bulwark.png',
      primaryColor: const Color(0xFF00695C),
      borderColor: const Color(0xFF00BFA5),
      actionType: 'obsidian_bastion',
      summary: 'Projects defensive volcanic basalt Aegis barriers across commander and retinue.',
      baseMultiplier: 0.25, // Shield % max HP
      rankDescriptions: [
        'Rank 1: 25% Max HP Aegis barrier to Sculptor, 65% of that to companions.',
        'Rank 2: 35% Max HP Aegis barrier + reflects 15% physical damage.',
        'Rank 3: 45% Max HP Aegis barrier + grants +20 Armor to all allies.',
      ],
    );

    allSkills['ash_whirlwind'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'ash_whirlwind',
      name: 'Ember Whirlwind',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.calamity,
      defaultSlot: 4,
      cinderCost: 45,
      cooldownSeconds: 12.0,
      icon: Icons.cyclone,
      primaryColor: const Color(0xFFE65100),
      borderColor: const Color(0xFFFFAB40),
      actionType: 'ember_whirlwind',
      summary: 'Sweeping vortex of white-hot slag striking all front and midline enemies.',
      baseMultiplier: 2.10,
      rankDescriptions: [
        'Rank 1: 210% AoE Cleave across frontline + 2 Burn stacks.',
        'Rank 2: 260% AoE Cleave + 3 Burns + shreds 25 Armor from all targets.',
        'Rank 3: 315% AoE Cleave + 4 Burns + staggers all targets by -1,500 AP.',
      ],
    );

    allSkills['ash_pyre'] = CrucibleSkillNode(
      tier: 4,
      requiredBranchPoints: 3,
      id: 'ash_pyre',
      branch: CrucibleSkillBranch.apex,
      name: 'Cataclysmic Pyre',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 5,
      cinderCost: 80,
      cooldownSeconds: 20.0,
      icon: Icons.bolt,
      iconAsset: 'assets/images/icons/skills/icon_skill_ash_pyre.png',
      primaryColor: const Color(0xFFFF6D00),
      borderColor: const Color(0xFFFFD54F),
      actionType: 'cataclysmic_pyre',
      summary: 'APEX FINISHER: Screen-shattering fire nova across all enemy ranks with Perfect Forge timing.',
      baseMultiplier: 2.50,
      rankDescriptions: [
        'Rank 1: 250% (350% Perfect Forge Crit) Fire Nova across all foes + 3s Burn.',
        'Rank 2: 300% (420% Perfect Forge Crit) Fire Nova + ignites all active bleeds.',
        'Rank 3: 360% (500% Perfect Forge Crit) Cataclysmic Overdrive Nova + ignores 50% Armor.',
      ],
    );

    // ==========================================
    // 2. IRON & BASTION DISCIPLINE (Valeria / Dawn)
    // ==========================================
    allSkills['iron_slam'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'iron_slam',
      name: 'Cold Iron Slam',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 6.0,
      icon: Icons.shield,
      iconAsset: 'assets/images/icons/skills/icon_skill_iron_bastion.png',
      primaryColor: const Color(0xFF5D4037),
      borderColor: const Color(0xFFFFD54F),
      actionType: 'cold_iron_slam',
      summary: 'Tower shield slam consuming 0 Cinders. Main cinder generator (+18 Cinders), shreds armor, and staggers turn order.',
      baseMultiplier: 1.30,
      rankDescriptions: [
        'Rank 1: 130% ATK DMG, shreds 20 Armor, -1,500 AP stagger. Generates +6 Cinders.',
        'Rank 2: 165% ATK DMG, shreds 35 Armor, -2,500 AP stagger. Generates +8 Cinders.',
        'Rank 3: 200% ATK DMG, shreds 50 Armor, stuns target for 1 turn. Generates +10 Cinders.',
      ],
    );

    allSkills['iron_judgment'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'ash_brand',
      id: 'iron_judgment',
      name: 'Sundering Judgment',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.wrath,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.wb_sunny,
      iconAsset: 'assets/images/icons/skills/icon_skill_iron_judgment.png',
      primaryColor: const Color(0xFFF57F17),
      borderColor: const Color(0xFFFFD54F),
      actionType: 'sundering_judgment',
      summary: 'Radiant hammer strike that breaks armor and exposes vulnerabilities.',
      baseMultiplier: 1.80,
      rankDescriptions: [
        'Rank 1: 180% Holy DMG, shreds 30% Armor, inflicts 3s Vulnerable.',
        'Rank 2: 225% Holy DMG, shreds 45% Armor, 5s Vulnerable + blinds target.',
        'Rank 3: 275% Holy DMG, shreds 60% Armor + bounces holy shockwave to adjacent column.',
      ],
    );

    allSkills['iron_bulwark'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'ash_bastion',
      id: 'iron_bulwark',
      name: 'Iron Bulwark',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.security,
      iconAsset: 'assets/images/icons/skills/icon_skill_granite_fortress.png',
      primaryColor: const Color(0xFF37474F),
      borderColor: const Color(0xFF81D4FA),
      actionType: 'iron_bulwark',
      summary: 'Reinforces squad armor and purges harmful afflictions.',
      baseMultiplier: 35.0, // Flat Armor boost
      rankDescriptions: [
        'Rank 1: +35 Armor to squad + cleanses all debuffs.',
        'Rank 2: +50 Armor to squad + cleanses debuffs + 15% damage reduction.',
        'Rank 3: +70 Armor to squad + grants 1 turn of debuff immunity.',
      ],
    );

    allSkills['iron_retribution'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'ash_bastion',
      id: 'iron_retribution',
      name: 'Dawn Retribution',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 4,
      cinderCost: 45,
      cooldownSeconds: 12.0,
      icon: Icons.gavel,
      iconAsset: 'assets/images/icons/skills/icon_skill_rampart_shockwave.png',
      primaryColor: const Color(0xFFFF8F00),
      borderColor: const Color(0xFFFFE082),
      actionType: 'dawn_retribution',
      summary: 'Crushing righteous hammer slam that staggers enemy ranks and enters Counter stance.',
      baseMultiplier: 2.20,
      rankDescriptions: [
        'Rank 1: 220% Holy Strike + staggers all targets by -2,500 AP + counter-reflect stance.',
        'Rank 2: 275% Holy Strike + -3,500 AP stagger + reflects 30% incoming DMG for 4s.',
        'Rank 3: 330% Holy Strike + completely resets target enemy action gauge to 0.',
      ],
    );

    allSkills['iron_wrath'] = CrucibleSkillNode(
      tier: 4,
      requiredBranchPoints: 3,
      id: 'iron_wrath',
      name: 'Wrath of Dawnbound',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.apex,
      defaultSlot: 5,
      cinderCost: 80,
      cooldownSeconds: 20.0,
      icon: Icons.flash_on,
      primaryColor: const Color(0xFFFFB300),
      borderColor: const Color(0xFFFFF176),
      actionType: 'wrath_of_the_dawnbound',
      summary: 'APEX FINISHER: Blinding holy tempest annihilating enemy ranks with righteous fury.',
      baseMultiplier: 2.80,
      rankDescriptions: [
        'Rank 1: 280% (380% Perfect Forge Crit) Radiant Nova across all foes.',
        'Rank 2: 340% (460% Perfect Forge Crit) Radiant Nova + blinds all foes for 4s.',
        'Rank 3: 410% (550% Perfect Forge Crit) Dawnbound Apotheosis + fully heals player frontline.',
      ],
    );

    // ==========================================
    // 3. SANGUINE & FLESH DISCIPLINE (Vladislav)
    // ==========================================
    allSkills['sanguine_rend'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'sanguine_rend',
      branch: CrucibleSkillBranch.resonance,
      name: 'Siphon Rend',
      discipline: CrucibleSkillDiscipline.sanguine,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 6.0,
      icon: Icons.bloodtype,
      primaryColor: const Color(0xFF880E4F),
      borderColor: const Color(0xFFFF5252),
      actionType: 'siphon_rend',
      summary: 'Serrated strike consuming 0 Cinders. Main cinder generator (+18 Cinders) and leeches vital essence to restore HP.',
      baseMultiplier: 1.35,
      rankDescriptions: [
        'Rank 1: 135% ATK DMG, leeches 40% DMG as HP. Generates +6 Cinders.',
        'Rank 2: 170% ATK DMG, leeches 60% DMG + heals lowest ally. Generates +8 Cinders.',
        'Rank 3: 210% ATK DMG, leeches 85% DMG + grants +15% lifesteal. Generates +10 Cinders.',
      ],
    );

    allSkills['sanguine_brand'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'sanguine_rend',
      id: 'sanguine_brand',
      name: 'Crimson Brand',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.wrath,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.whatshot,
      primaryColor: const Color(0xFFC2185B),
      borderColor: const Color(0xFFFF4081),
      actionType: 'crimson_brand',
      summary: 'Deep laceration that instantly ruptures and detonates active bleed wounds.',
      baseMultiplier: 1.65,
      rankDescriptions: [
        'Rank 1: 165% ATK + 3 Bleeds, detonates active bleeds for 2x remaining ticks.',
        'Rank 2: 210% ATK + 4 Bleeds, detonates bleeds for 3x remaining ticks.',
        'Rank 3: 260% ATK + 5 Bleeds, causes ruptured blood explosion splashing to adjacent nodes.',
      ],
    );

    allSkills['sanguine_tether'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'sanguine_rend',
      id: 'sanguine_tether',
      name: 'Vein Tether',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.resonance,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.all_inclusive,
      primaryColor: const Color(0xFF4A148C),
      borderColor: const Color(0xFFEA80FC),
      actionType: 'vein_tether',
      summary: 'Blood pact accelerating the circulatory vitality of the retinue.',
      baseMultiplier: 25.0,
      rankDescriptions: [
        'Rank 1: +2,500 AP haste & +25 Aegis to all allies.',
        'Rank 2: +3,500 AP haste & +35 Aegis + 15% bonus attack speed.',
        'Rank 3: +5,000 AP haste & +50 Aegis + resets retinue cooldowns by 1.',
      ],
    );

    allSkills['sanguine_vortex'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'ash_whirlwind',
      id: 'sanguine_vortex',
      name: 'Blood Vortex',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.calamity,
      defaultSlot: 4,
      cinderCost: 45,
      cooldownSeconds: 12.0,
      icon: Icons.water_drop,
      primaryColor: const Color(0xFFAD1457),
      borderColor: const Color(0xFFFF4081),
      actionType: 'blood_vortex',
      summary: 'Violent maelstrom that draws vitality from all bleeding enemies.',
      baseMultiplier: 2.00,
      rankDescriptions: [
        'Rank 1: 200% Blood Siphon across all bleeding foes + restores 20% Max HP to squad.',
        'Rank 2: 250% Blood Siphon + pulls backline enemies into reach.',
        'Rank 3: 310% Blood Siphon + detonates all bleeds for full remaining value.',
      ],
    );

    allSkills['sanguine_apex'] = CrucibleSkillNode(
      tier: 4,
      requiredBranchPoints: 3,
      id: 'sanguine_apex',
      name: 'Exsanguination Apex',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.apex,
      defaultSlot: 5,
      cinderCost: 80,
      cooldownSeconds: 20.0,
      icon: Icons.storm,
      primaryColor: const Color(0xFFB71C1C),
      borderColor: const Color(0xFFFF1744),
      actionType: 'exsanguination_apex',
      summary: 'APEX FINISHER: Tempest of arterial spray instantly executing wounded prey.',
      baseMultiplier: 2.60,
      rankDescriptions: [
        'Rank 1: 260% (360% Perfect Forge Crit) Blood Tempest; executes foes below 25% HP.',
        'Rank 2: 320% (440% Perfect Forge Crit); executes foes below 35% HP.',
        'Rank 3: 390% (520% Perfect Forge Crit); executes foes below 45% HP + revives fallen ally.',
      ],
    );

    // ==========================================
    // 4. MIRE & OCCULT DISCIPLINE (Morrigan)
    // ==========================================
    allSkills['mire_touch'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'sanguine_rend',
      id: 'mire_touch',
      name: 'Corrosive Touch',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.resonance,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 6.0,
      icon: Icons.coronavirus,
      primaryColor: const Color(0xFF1B5E20),
      borderColor: const Color(0xFF69F0AE),
      actionType: 'corrosive_touch',
      summary: 'Caustic fungal grasp consuming 0 Cinders. Generates +6 Cinders, poisons flesh, and slows reflexes.',
      baseMultiplier: 1.30,
      rankDescriptions: [
        'Rank 1: 130% ATK, 2 Poison stacks, -1,000 AP stagger. Generates +6 Cinders.',
        'Rank 2: 165% ATK, 3 Poison stacks, -2,000 AP stagger + slows SPD. Generates +8 Cinders.',
        'Rank 3: 200% ATK, 4 Poison stacks, -3,000 AP stagger + spreads. Generates +10 Cinders.',
      ],
    );

    allSkills['mire_brand'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'mire_touch',
      id: 'mire_brand',
      name: 'Miasmic Brand',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.resonance,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.bubble_chart,
      primaryColor: const Color(0xFF2E7D32),
      borderColor: const Color(0xFF00E676),
      actionType: 'miasmic_brand',
      summary: 'Plagues target with virulent spore contagion that infects their entire column.',
      baseMultiplier: 1.60,
      rankDescriptions: [
        'Rank 1: 160% ATK, plagues target column with 3 Poison & Vulnerable.',
        'Rank 2: 205% ATK, plagues column with 5 Poison & Vulnerable + reduces healing by 50%.',
        'Rank 3: 255% ATK, column contagion permanently disables target passives.',
      ],
    );

    allSkills['mire_ward'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'iron_slam',
      id: 'mire_ward',
      name: 'Bone Ward',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.healing,
      primaryColor: const Color(0xFF004D40),
      borderColor: const Color(0xFF64FFDA),
      actionType: 'bone_ward',
      summary: 'Weaves calcified ossuary bones into impenetrable protective aegis wards.',
      baseMultiplier: 0.30, // 30% Max HP
      rankDescriptions: [
        'Rank 1: 30% Max HP ossuary shields across all living allies.',
        'Rank 2: 40% Max HP ossuary shields + absorbs 2 negative status effects.',
        'Rank 3: 50% Max HP ossuary shields + detonates for 50% remaining shield on expiration.',
      ],
    );

    allSkills['mire_catacomb'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'sanguine_vortex',
      id: 'mire_catacomb',
      name: 'Ossuary Catacomb',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.calamity,
      defaultSlot: 4,
      cinderCost: 45,
      cooldownSeconds: 12.0,
      icon: Icons.grass,
      primaryColor: const Color(0xFF00796B),
      borderColor: const Color(0xFF80CBC4),
      actionType: 'ossuary_catacomb',
      summary: 'Erupts skeletal spikes across an entire enemy column, rooting and rotting all foes.',
      baseMultiplier: 2.00,
      rankDescriptions: [
        'Rank 1: 200% Blight Rupture + stuns target column for 1 turn + +40 Ossuary barrier.',
        'Rank 2: 250% Blight Rupture + 2 turn stun + inflicts 4 Poison stacks.',
        'Rank 3: 310% Blight Rupture + permanent -50% movement and action rate.',
      ],
    );

    allSkills['mire_apex'] = CrucibleSkillNode(
      tier: 4,
      requiredBranchPoints: 3,
      id: 'mire_apex',
      name: 'Cataclysmic Spore',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.apex,
      defaultSlot: 5,
      cinderCost: 80,
      cooldownSeconds: 20.0,
      icon: Icons.eco,
      primaryColor: const Color(0xFF00C853),
      borderColor: const Color(0xFFB9F6CA),
      actionType: 'cataclysmic_spore',
      summary: 'APEX FINISHER: Titanic toxic eruption detonating all poisons for cataclysmic devastation.',
      baseMultiplier: 2.40,
      rankDescriptions: [
        'Rank 1: 240% (340% Perfect Forge Crit) Nature eruption; procs 30% bonus DMG on poisoned foes.',
        'Rank 2: 300% (420% Perfect Forge Crit) eruption; procs 50% bonus DMG on poisoned foes.',
        'Rank 3: 370% (510% Perfect Forge Crit) Extinction Spore; instantly kills non-bosses with 5+ Poison.',
      ],
    );

    // ==========================================
    // 5. PATH OF CALAMITY (AoE / Storms)
    // ==========================================
    allSkills['calamity_nova'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'calamity_nova',
      name: 'Sunburst Nova',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.calamity,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.wb_sunny,
      primaryColor: const Color(0xFFFF9100),
      borderColor: const Color(0xFFFFD54F),
      actionType: 'calamity_nova',
      summary: 'Radiant cataclysm blasting all 9 enemy tiles. Blinds foes and staggers turn gauges by -1,500 AP.',
      baseMultiplier: 1.75,
      rankDescriptions: [
        'Rank 1: 175% ATK Holy Nova across all 9 tiles + 3s Blind + -1,500 AP stagger.',
        'Rank 2: 215% ATK Nova + -2,500 AP stagger + shreds 25 Armor.',
        'Rank 3: 260% ATK Nova + completely halts enemy Action Gauge accumulation for 2.5s.',
      ],
    );

    // ==========================================
    // 6. PATH OF VITAE (Healing & Restoration)
    // ==========================================
    allSkills['vitae_mending'] = CrucibleSkillNode(
      tier: 1,
      requiredBranchPoints: 0,
      id: 'vitae_mending',
      name: 'Mending Ash',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.vitae,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 6.0,
      icon: Icons.healing,
      primaryColor: const Color(0xFF00E676),
      borderColor: const Color(0xFFB9F6CA),
      actionType: 'vitae_mending',
      summary: 'Restorative strike consuming 0 Cinders. Main cinder generator (+18 Cinders) and heals lowest HP ally for +60 HP.',
      baseMultiplier: 1.10,
      rankDescriptions: [
        'Rank 1: 110% ATK strike, generates +6 Cinders, mends lowest HP ally for +60 HP (+20% ATK).',
        'Rank 2: 135% ATK strike, generates +8 Cinders, mends lowest HP ally for +110 HP (+30% ATK).',
        'Rank 3: 165% ATK strike, generates +10 Cinders, mends squad frontline for +160 HP (+40% ATK).',
      ],
    );

    allSkills['vitae_bloom'] = CrucibleSkillNode(
      tier: 2,
      requiredBranchPoints: 1,
      prerequisiteSkillId: 'vitae_mending',
      id: 'vitae_bloom',
      name: 'Sanctified Bloom',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.vitae,
      defaultSlot: 2,
      cinderCost: 25,
      cooldownSeconds: 6.0,
      icon: Icons.spa,
      primaryColor: const Color(0xFF00E676),
      borderColor: const Color(0xFF69F0AE),
      actionType: 'vitae_bloom',
      summary: 'Radiates life-giving ash, restoring 35% Max HP to entire retinue and cleansing all debuffs.',
      baseMultiplier: 0.0,
      rankDescriptions: [
        'Rank 1: Restores 35% Max HP (+140 HP) to all living squad members + cleanses all bleed/burn/poison.',
        'Rank 2: Restores 45% Max HP (+200 HP) + grants 25 Aegis Shield to entire squad.',
        'Rank 3: Restores 60% Max HP (+300 HP) + grants 3s Debuff Immunity to all allies.',
      ],
    );

    allSkills['vitae_conduit'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'vitae_bloom',
      id: 'vitae_conduit',
      name: 'Soul Transfusion',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.vitae,
      defaultSlot: 3,
      cinderCost: 40,
      cooldownSeconds: 9.0,
      icon: Icons.favorite,
      primaryColor: const Color(0xFF00C853),
      borderColor: const Color(0xFFA7FFEB),
      actionType: 'vitae_conduit',
      summary: 'Drains life from target enemy, converting 100% of damage dealt into squad-wide healing + Regeneration.',
      baseMultiplier: 2.20,
      rankDescriptions: [
        'Rank 1: 220% ATK Life Siphon; 100% of damage healed across squad + 4s Regeneration.',
        'Rank 2: 275% ATK Life Siphon; 125% of damage healed across squad + grants Haste for 3s.',
        'Rank 3: 340% ATK Life Siphon; full overhealing converted to permanent Max HP boost for encounter.',
      ],
    );

    allSkills['vitae_aegis'] = CrucibleSkillNode(
      tier: 3,
      requiredBranchPoints: 2,
      prerequisiteSkillId: 'vitae_bloom',
      id: 'vitae_aegis',
      name: 'Grace of the Martyr',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.vitae,
      defaultSlot: 4,
      cinderCost: 50,
      cooldownSeconds: 12.0,
      icon: Icons.shield_moon,
      primaryColor: const Color(0xFF1DE9B6),
      borderColor: const Color(0xFF64FFDA),
      actionType: 'vitae_aegis',
      summary: 'Bestows +80 Aegis Barrier & +30% PRR to target ally, or revives a fallen minion at 40% Max HP.',
      baseMultiplier: 0.0,
      rankDescriptions: [
        'Rank 1: Grants +80 Aegis Barrier & -30% damage taken to target ally, or revives fallen minion at 40% HP.',
        'Rank 2: Grants +120 Aegis Barrier & -40% damage taken, or revives fallen minion at 65% HP + full AP.',
        'Rank 3: Grants +180 Aegis Barrier to entire squad, or revives all fallen minions at 100% HP.',
      ],
    );

  }

  void configureStartingDiscipline(CrucibleSkillBranch branch, {bool startWithBasics = true}) {
    if (startWithBasics) {
      // Start with the basics (Slot 1 generator + Slot 2 core skill) and build up!
      // Slots 3, 4, 5 start empty and are unlocked as the player levels up and invests Skill Points.
      equippedSkillIds[2] = '';
      equippedSkillIds[3] = '';
      equippedSkillIds[4] = '';
      availableSkillPoints = 5;

      switch (branch) {
        case CrucibleSkillBranch.wrath:
          equippedSkillIds[0] = 'ash_cleave';
          equippedSkillIds[1] = 'ash_brand';
          allSkills['ash_cleave']?.rank = 1;
          allSkills['ash_brand']?.rank = 1;
          break;
        case CrucibleSkillBranch.bastion:
          equippedSkillIds[0] = 'iron_slam';
          equippedSkillIds[1] = 'ash_bastion';
          allSkills['iron_slam']?.rank = 1;
          allSkills['ash_bastion']?.rank = 1;
          break;
        case CrucibleSkillBranch.resonance:
          equippedSkillIds[0] = 'sanguine_rend';
          equippedSkillIds[1] = 'sanguine_tether';
          allSkills['sanguine_rend']?.rank = 1;
          allSkills['sanguine_tether']?.rank = 1;
          break;
        case CrucibleSkillBranch.vitae:
          equippedSkillIds[0] = 'mending_ash';
          equippedSkillIds[1] = 'sanctified_bloom';
          allSkills['mending_ash']?.rank = 1;
          allSkills['sanctified_bloom']?.rank = 1;
          break;
        case CrucibleSkillBranch.calamity:
          equippedSkillIds[0] = 'ash_whirlwind';
          equippedSkillIds[1] = 'sanguine_vortex';
          allSkills['ash_whirlwind']?.rank = 1;
          allSkills['sanguine_vortex']?.rank = 1;
          break;
        case CrucibleSkillBranch.apex:
          equippedSkillIds[0] = 'ash_cleave';
          equippedSkillIds[1] = 'ash_brand';
          allSkills['ash_cleave']?.rank = 1;
          allSkills['ash_brand']?.rank = 1;
          break;
      }
    } else {
      // Full 5-Slot Presets for Sandbox / Dev Testing
      switch (branch) {
        case CrucibleSkillBranch.wrath:
          equippedSkillIds[0] = 'ash_cleave';
          equippedSkillIds[1] = 'ash_brand';
          equippedSkillIds[2] = 'iron_judgment';
          equippedSkillIds[3] = 'ash_whirlwind';
          equippedSkillIds[4] = 'ash_pyre';
          break;
        case CrucibleSkillBranch.bastion:
          equippedSkillIds[0] = 'iron_slam';
          equippedSkillIds[1] = 'ash_bastion';
          equippedSkillIds[2] = 'iron_bulwark';
          equippedSkillIds[3] = 'iron_retribution';
          equippedSkillIds[4] = 'iron_wrath';
          break;
        case CrucibleSkillBranch.resonance:
          equippedSkillIds[0] = 'sanguine_rend';
          equippedSkillIds[1] = 'sanguine_tether';
          equippedSkillIds[2] = 'mire_curse';
          equippedSkillIds[3] = 'sanguine_vortex';
          equippedSkillIds[4] = 'sanguine_apex';
          break;
        case CrucibleSkillBranch.vitae:
          equippedSkillIds[0] = 'mending_ash';
          equippedSkillIds[1] = 'sanctified_bloom';
          equippedSkillIds[2] = 'soul_transfusion';
          equippedSkillIds[3] = 'grace_martyr';
          equippedSkillIds[4] = 'ash_pyre';
          break;
        case CrucibleSkillBranch.calamity:
          equippedSkillIds[0] = 'ash_whirlwind';
          equippedSkillIds[1] = 'sanguine_vortex';
          equippedSkillIds[2] = 'mire_nova';
          equippedSkillIds[3] = 'ash_cleave';
          equippedSkillIds[4] = 'mire_calamity';
          break;
        case CrucibleSkillBranch.apex:
          equippedSkillIds[0] = 'ash_cleave';
          equippedSkillIds[1] = 'ash_brand';
          equippedSkillIds[2] = 'ash_bastion';
          equippedSkillIds[3] = 'ash_whirlwind';
          equippedSkillIds[4] = 'ash_pyre';
          break;
      }
    }
  }

  void configureDefaultsForGeneral(GeneralType general) {
    switch (general) {
      case GeneralType.valeria:
        equippedSkillIds[0] = 'iron_slam';
        equippedSkillIds[1] = 'iron_judgment';
        equippedSkillIds[2] = 'iron_bulwark';
        equippedSkillIds[3] = 'iron_retribution';
        equippedSkillIds[4] = 'iron_wrath';
        break;
      case GeneralType.vladislav:
        equippedSkillIds[0] = 'sanguine_rend';
        equippedSkillIds[1] = 'sanguine_brand';
        equippedSkillIds[2] = 'sanguine_tether';
        equippedSkillIds[3] = 'sanguine_vortex';
        equippedSkillIds[4] = 'sanguine_apex';
        break;
      case GeneralType.morrigan:
        equippedSkillIds[0] = 'mire_touch';
        equippedSkillIds[1] = 'mire_brand';
        equippedSkillIds[2] = 'mire_ward';
        equippedSkillIds[3] = 'mire_catacomb';
        equippedSkillIds[4] = 'mire_apex';
        break;
      case GeneralType.malakor:
        equippedSkillIds[0] = 'ash_cleave';
        equippedSkillIds[1] = 'ash_brand';
        equippedSkillIds[2] = 'ash_bastion';
        equippedSkillIds[3] = 'ash_whirlwind';
        equippedSkillIds[4] = 'ash_pyre';
        break;
    }
  }

  CrucibleSkillNode? getSkillInSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= 5) return null;
    final id = equippedSkillIds[slotIndex];
    return allSkills[id];
  }

  bool equipSkill(int slotIndex, String skillId) {
    if (slotIndex < 0 || slotIndex >= 5) return false;
    final skill = allSkills[skillId];
    if (skill == null || !skill.isUnlocked) return false;

    // Check if already equipped elsewhere and swap
    final existingIdx = equippedSkillIds.indexOf(skillId);
    if (existingIdx != -1 && existingIdx != slotIndex) {
      equippedSkillIds[existingIdx] = equippedSkillIds[slotIndex];
    }
    equippedSkillIds[slotIndex] = skillId;
    return true;
  }

  int get totalPointsSpent {
    return wrathPointsSpent + bastionPointsSpent + resonancePointsSpent + vitaePointsSpent + calamityPointsSpent;
  }

  bool isSkillPrerequisiteMet(String skillId) {
    final skill = allSkills[skillId];
    if (skill == null) return false;

    // Apex Crown Finishers require 3 points spent anywhere or in discipline
    if (skill.branch == CrucibleSkillBranch.apex) {
      return totalPointsSpent >= 3;
    }

    // Branch points requirement
    if (getPointsSpentInBranch(skill.branch) < skill.requiredBranchPoints) {
      return false;
    }

    // Specific predecessor skill must be at least Rank 2 (meaning at least 1 upgrade invested in it)
    if (skill.prerequisiteSkillId != null) {
      final prereq = allSkills[skill.prerequisiteSkillId];
      if (prereq == null || prereq.rank < 2) {
        return false;
      }
    }

    return true;
  }

  String getPrerequisiteRequirementText(String skillId) {
    final skill = allSkills[skillId];
    if (skill == null) return '';

    if (skill.branch == CrucibleSkillBranch.apex) {
      if (totalPointsSpent < 3) {
        return 'Requires 3 points invested across any branch ($totalPointsSpent/3).';
      }
      return 'Apex Crown Overdrive Unlocked!';
    }

    final branchName = skill.branch.name.toUpperCase();
    final ptsSpent = getPointsSpentInBranch(skill.branch);
    if (ptsSpent < skill.requiredBranchPoints) {
      return 'Requires ${skill.requiredBranchPoints} pt${skill.requiredBranchPoints > 1 ? "s" : ""} in Path of $branchName ($ptsSpent/${skill.requiredBranchPoints}).';
    }

    if (skill.prerequisiteSkillId != null) {
      final prereq = allSkills[skill.prerequisiteSkillId];
      if (prereq != null && prereq.rank < 2) {
        return 'Requires Rank 2 in ${prereq.name} (invest 1 SP in ${prereq.name}).';
      }
    }

    return 'Prerequisites satisfied';
  }

  bool canUpgradeSkill(String skillId) {
    final skill = allSkills[skillId];
    if (skill == null) return false;
    if (availableSkillPoints <= 0) return false;
    if (!skill.canUpgrade) return false;
    return isSkillPrerequisiteMet(skillId);
  }

  void respecAllPoints() {
    int refunded = 0;
    for (final skill in allSkills.values) {
      if (skill.rank > 1) {
        refunded += (skill.rank - 1);
        skill.rank = 1;
      }
    }
    availableSkillPoints += refunded;
    remainingCooldowns.clear();
  }

  bool upgradeSkill(String skillId) {
    final skill = allSkills[skillId];
    if (skill == null) return false;
    if (availableSkillPoints <= 0) return false;
    if (!skill.canUpgrade) return false;
    if (!isSkillPrerequisiteMet(skillId)) return false;

    skill.rank++;
    availableSkillPoints--;
    return true;
  }


  // ==========================================
  // 3-BRANCH ARCHETYPE & KEYSTONE PASSIVES
  // ==========================================
  int getPointsSpentInBranch(CrucibleSkillBranch branch) {
    int total = 0;
    for (final skill in allSkills.values) {
      if (skill.branch == branch && skill.rank > 1) {
        total += (skill.rank - 1);
      }
    }
    return total;
  }

  int get wrathPointsSpent => getPointsSpentInBranch(CrucibleSkillBranch.wrath);
  int get bastionPointsSpent => getPointsSpentInBranch(CrucibleSkillBranch.bastion);
  int get resonancePointsSpent => getPointsSpentInBranch(CrucibleSkillBranch.resonance);
  int get vitaePointsSpent => getPointsSpentInBranch(CrucibleSkillBranch.vitae);
  int get calamityPointsSpent => getPointsSpentInBranch(CrucibleSkillBranch.calamity);

  bool get isMoltenOverdriveActive => wrathPointsSpent >= 3;
  bool get isSlagFortressActive => bastionPointsSpent >= 3;
  bool get isCrucibleSymbiosisActive => resonancePointsSpent >= 3;
  bool get isFontOfRebirthActive => vitaePointsSpent >= 3;
  bool get isSeismicCataclysmActive => calamityPointsSpent >= 3;

  List<CrucibleSkillNode> getSkillsForBranch(CrucibleSkillBranch branch) {
    return allSkills.values.where((s) => s.branch == branch).toList();
  }

  List<CrucibleSkillNode> getSkillsForDiscipline(CrucibleSkillDiscipline discipline) {
    return allSkills.values.where((s) => s.discipline == discipline).toList();
  }

  // ==========================================
  // REAL-TIME / TURN COOLDOWN TRACKING SYSTEM
  // ==========================================
  final Map<String, double> remainingCooldowns = {};

  double getCooldownRemaining(String skillId) {
    return remainingCooldowns[skillId] ?? 0.0;
  }

  double getCooldownRemainingForSlot(int slotIndex) {
    final skill = getSkillInSlot(slotIndex);
    if (skill == null) return 0.0;
    return getCooldownRemaining(skill.id);
  }

  void startCooldown(String skillId, double seconds) {
    if (seconds > 0.0) {
      remainingCooldowns[skillId] = seconds;
    }
  }

  void updateCooldowns(double deltaSeconds) {
    if (remainingCooldowns.isEmpty) return;
    final keys = remainingCooldowns.keys.toList();
    for (final key in keys) {
      final cur = remainingCooldowns[key] ?? 0.0;
      final next = cur - deltaSeconds;
      if (next <= 0.01) {
        remainingCooldowns.remove(key);
      } else {
        remainingCooldowns[key] = next;
      }
    }
  }

  void resetAllCooldowns() {
    remainingCooldowns.clear();
  }

  CrucibleSkillNode? findSkillForAction(String actionType) {
    for (final skill in allSkills.values) {
      if (skill.actionType == actionType) return skill;
    }
    // Prefix & Finisher fuzzy matching
    for (final skill in allSkills.values) {
      if (actionType.startsWith(skill.actionType) || skill.actionType.startsWith(actionType)) {
        return skill;
      }
    }
    if (actionType.contains('pyre') ||
        actionType.contains('cataclysmic') ||
        actionType.contains('apex') ||
        actionType.contains('wrath') ||
        actionType.contains('spore') ||
        actionType.contains('exsanguination')) {
      return getSkillInSlot(4);
    }
    if (actionType == 'cleave' || actionType == 'forge_cleave' || actionType == 'slam' || actionType == 'rend' || actionType == 'touch') {
      return getSkillInSlot(0);
    }
    return null;
  }
}
