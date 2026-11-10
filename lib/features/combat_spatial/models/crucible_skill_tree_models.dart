import 'package:flutter/material.dart';
import '../../generals/general_command_service.dart';

enum CrucibleSkillDiscipline {
  ash,
  iron,
  sanguine,
  mire,
}

enum CrucibleSkillBranch {
  wrath,      // Attack / Offense (Crimson & Embers)
  bastion,    // Defense / Protection (Iron & Stone)
  resonance,  // Hybrid / Retinue Synergy (Amethyst & Blood)
  apex,       // Crown Finishers (White-Gold Overdrive)
}

class CrucibleSkillNode {
  final String id;
  final String name;
  final CrucibleSkillDiscipline discipline;
  final CrucibleSkillBranch branch;
  final int defaultSlot; // 1 to 5
  final int cinderCost;
  final IconData icon;
  final Color primaryColor;
  final Color borderColor;
  final String actionType;
  final String summary;
  final List<String> rankDescriptions;
  final double baseMultiplier;
  final int maxRank;
  final double cooldownSeconds;

  int rank; // Current rank (0 = locked, 1..maxRank = unlocked/upgraded)

  CrucibleSkillNode({
    required this.id,
    required this.name,
    required this.discipline,
    this.branch = CrucibleSkillBranch.wrath,
    required this.defaultSlot,
    required this.cinderCost,
    required this.icon,
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
    configureDefaultsForGeneral(GeneralType.malakor);
  }

  void _initializeAllSkills() {
    // ==========================================
    // 1. ASH & PYRE DISCIPLINE (Malakor / Forge)
    // ==========================================
    allSkills['ash_cleave'] = CrucibleSkillNode(
      id: 'ash_cleave',
      branch: CrucibleSkillBranch.wrath,
      name: 'Forge Cleave',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 1.5,
      icon: Icons.sports_mma,
      primaryColor: const Color(0xFFB3261E),
      borderColor: const Color(0xFFFF8A80),
      actionType: 'forge_cleave',
      summary: 'Basic cleave consuming 0 Cinders. Generates +6 Cinders on strike and inflicts Bleed.',
      baseMultiplier: 1.40,
      rankDescriptions: [
        'Rank 1: 140% ATK cleave + 1 Bleed stack. Generates +6 Cinders.',
        'Rank 2: 175% ATK cleave + 2 Bleeds + 10% armor pierce. Generates +8 Cinders.',
        'Rank 3: 210% ATK cleave + 3 Bleeds + row splash. Generates +10 Cinders.',
      ],
    );

    allSkills['ash_brand'] = CrucibleSkillNode(
      id: 'ash_brand',
      name: 'Sundering Brand',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.wrath,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.local_fire_department,
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
      id: 'ash_bastion',
      branch: CrucibleSkillBranch.bastion,
      name: 'Obsidian Bastion',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.shield,
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
      id: 'ash_whirlwind',
      name: 'Ember Whirlwind',
      discipline: CrucibleSkillDiscipline.ash,
      branch: CrucibleSkillBranch.wrath,
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
      id: 'ash_pyre',
      branch: CrucibleSkillBranch.apex,
      name: 'Cataclysmic Pyre',
      discipline: CrucibleSkillDiscipline.ash,
      defaultSlot: 5,
      cinderCost: 80,
      cooldownSeconds: 20.0,
      icon: Icons.bolt,
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
      id: 'iron_slam',
      name: 'Cold Iron Slam',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 1.5,
      icon: Icons.shield,
      primaryColor: const Color(0xFF5D4037),
      borderColor: const Color(0xFFFFD54F),
      actionType: 'cold_iron_slam',
      summary: 'Tower shield bash consuming 0 Cinders. Generates +6 Cinders, shreds armor, and staggers turn order.',
      baseMultiplier: 1.30,
      rankDescriptions: [
        'Rank 1: 130% ATK DMG, shreds 20 Armor, -1,500 AP stagger. Generates +6 Cinders.',
        'Rank 2: 165% ATK DMG, shreds 35 Armor, -2,500 AP stagger. Generates +8 Cinders.',
        'Rank 3: 200% ATK DMG, shreds 50 Armor, stuns target for 1 turn. Generates +10 Cinders.',
      ],
    );

    allSkills['iron_judgment'] = CrucibleSkillNode(
      id: 'iron_judgment',
      name: 'Sundering Judgment',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.wrath,
      defaultSlot: 2,
      cinderCost: 30,
      cooldownSeconds: 6.0,
      icon: Icons.wb_sunny,
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
      id: 'iron_bulwark',
      name: 'Iron Bulwark',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 3,
      cinderCost: 25,
      cooldownSeconds: 9.0,
      icon: Icons.security,
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
      id: 'iron_retribution',
      name: 'Dawn Retribution',
      discipline: CrucibleSkillDiscipline.iron,
      branch: CrucibleSkillBranch.bastion,
      defaultSlot: 4,
      cinderCost: 45,
      cooldownSeconds: 12.0,
      icon: Icons.gavel,
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
      id: 'sanguine_rend',
      branch: CrucibleSkillBranch.resonance,
      name: 'Siphon Rend',
      discipline: CrucibleSkillDiscipline.sanguine,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 1.5,
      icon: Icons.bloodtype,
      primaryColor: const Color(0xFF880E4F),
      borderColor: const Color(0xFFFF5252),
      actionType: 'siphon_rend',
      summary: 'Serrated strike consuming 0 Cinders. Generates +6 Cinders and leeches vital essence to restore HP.',
      baseMultiplier: 1.35,
      rankDescriptions: [
        'Rank 1: 135% ATK DMG, leeches 40% DMG as HP. Generates +6 Cinders.',
        'Rank 2: 170% ATK DMG, leeches 60% DMG + heals lowest ally. Generates +8 Cinders.',
        'Rank 3: 210% ATK DMG, leeches 85% DMG + grants +15% lifesteal. Generates +10 Cinders.',
      ],
    );

    allSkills['sanguine_brand'] = CrucibleSkillNode(
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
      id: 'sanguine_vortex',
      name: 'Blood Vortex',
      discipline: CrucibleSkillDiscipline.sanguine,
      branch: CrucibleSkillBranch.resonance,
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
      id: 'mire_touch',
      name: 'Corrosive Touch',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.resonance,
      defaultSlot: 1,
      cinderCost: 0,
      cooldownSeconds: 1.5,
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
      id: 'mire_catacomb',
      name: 'Ossuary Catacomb',
      discipline: CrucibleSkillDiscipline.mire,
      branch: CrucibleSkillBranch.wrath,
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

  bool upgradeSkill(String skillId) {
    final skill = allSkills[skillId];
    if (skill == null) return false;
    if (availableSkillPoints <= 0) return false;
    if (!skill.canUpgrade) return false;

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

  bool get isMoltenOverdriveActive => wrathPointsSpent >= 3;
  bool get isSlagFortressActive => bastionPointsSpent >= 3;
  bool get isCrucibleSymbiosisActive => resonancePointsSpent >= 3;

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
