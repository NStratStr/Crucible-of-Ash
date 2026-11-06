import 'package:flutter/material.dart';

/// Plinth Archetypes available in the Sculptory
enum PlinthArchetype {
  obsidianBulwark, // Frontline defense, armor & starting aegis shield
  cinderSpire,     // Backline casting, initial focus & crit
  strigoiRunestone,// Midline hemomancy, speed & bleed
  titansFoundation,// Heavy resilience & telegraph damage reduction
}

class PlinthDefinition {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final PlinthArchetype archetype;
  final IconData icon;
  final Color primaryColor;
  final Color glowColor;
  final String baseRuneSymbol;

  const PlinthDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.archetype,
    required this.icon,
    required this.primaryColor,
    required this.glowColor,
    required this.baseRuneSymbol,
  });

  static const List<PlinthDefinition> allPlinths = [
    PlinthDefinition(
      id: 'obsidian_bulwark',
      name: 'Obsidian Bulwark Plinth',
      subtitle: 'Frontline Aegis & Defense',
      description: 'Carved from dense volcanic basalt. Frontline units gain +15% Armor and deploy with a +25 Aegis Shield barrier.',
      archetype: PlinthArchetype.obsidianBulwark,
      icon: Icons.shield,
      primaryColor: Color(0xFF00E5FF),
      glowColor: Color(0x6600E5FF),
      baseRuneSymbol: '🛡️',
    ),
    PlinthDefinition(
      id: 'cinder_spire',
      name: 'Cinder Spire Plinth',
      subtitle: 'Arcane Focus & Ignition',
      description: 'Chiseled with burning crucible brimstone. Squad starts combat with +1 Focus, and Casters deal +15% Spell Damage.',
      archetype: PlinthArchetype.cinderSpire,
      icon: Icons.local_fire_department,
      primaryColor: Color(0xFFFF9100),
      glowColor: Color(0x66FF9100),
      baseRuneSymbol: '🔥',
    ),
    PlinthDefinition(
      id: 'strigoi_runestone',
      name: 'Strigoi Runestone Plinth',
      subtitle: 'Flank Momentum & Hemomancy',
      description: 'Engraved with ancient sanguine channels. Midliners gain +15 Speed and basic attacks apply +2 Bleed stacks.',
      archetype: PlinthArchetype.strigoiRunestone,
      icon: Icons.water_drop,
      primaryColor: Color(0xFFFF1744),
      glowColor: Color(0x66FF1744),
      baseRuneSymbol: '🩸',
    ),
    PlinthDefinition(
      id: 'titans_foundation',
      name: 'Titan\'s Foundation Plinth',
      subtitle: 'Colossus Posture & Stability',
      description: 'Quarried from the petrified spine of primordial titans. All allies take 20% less damage from Boss Telegraphs and are immune to displacement.',
      archetype: PlinthArchetype.titansFoundation,
      icon: Icons.foundation,
      primaryColor: Color(0xFFFFD54F),
      glowColor: Color(0x66FFD54F),
      baseRuneSymbol: '🗿',
    ),
  ];
}

class TitanBossCore {
  final String id;
  final String name;
  final String bossOrigin;
  final String passiveTitle;
  final String passiveDescription;
  final IconData icon;
  final Color accentColor;
  final String assetGraphic;

  const TitanBossCore({
    required this.id,
    required this.name,
    required this.bossOrigin,
    required this.passiveTitle,
    required this.passiveDescription,
    required this.icon,
    required this.accentColor,
    required this.assetGraphic,
  });

  static const List<TitanBossCore> allCores = [
    TitanBossCore(
      id: 'gorgoroth_core',
      name: 'Calcified Heart of Gorgoroth',
      bossOrigin: 'Gorgoroth the Flayed',
      passiveTitle: 'Slag Resonator',
      passiveDescription: 'Breaking an enemy Break-Bar refunds 2 Focus and triggers an explosive shockwave dealing 60 True Damage to adjacent foes.',
      icon: Icons.whatshot,
      accentColor: Color(0xFFFF9100),
      assetGraphic: 'assets/images/Spells/Soul Shatter.jpg',
    ),
    TitanBossCore(
      id: 'malakor_core',
      name: 'Kinetic Bastion Plate',
      bossOrigin: 'Malakor the Unbroken',
      passiveTitle: 'Kinetic Grounding',
      passiveDescription: 'Frontline allies absorb 12% of incoming physical damage and store it as bonus kinetic attack on their next action.',
      icon: Icons.electric_bolt,
      accentColor: Color(0xFFFFD54F),
      assetGraphic: 'assets/images/Spells/Ash Armour.jpg',
    ),
    TitanBossCore(
      id: 'morvath_core',
      name: 'Putrid Phylactery of Morvath',
      bossOrigin: 'Morvath the Defiler',
      passiveTitle: 'Miasma Ward & Soul Leech',
      passiveDescription: 'Squad takes 50% less damage from ground hazards and poisons, and heals +8% max HP whenever an afflicted enemy perishes.',
      icon: Icons.coronavirus,
      accentColor: Color(0xFF69F0AE),
      assetGraphic: 'assets/images/Spells/Sanguine Siphon.jpg',
    ),
  ];
}
