import 'package:flutter/material.dart';

/// GDD v2.6 Section 1: Ascension-Driven Replayability
/// Granular A0–A10 Ascension modifier stack demanding deep system comprehension.
enum AscensionLevel {
  a0, // Normal Expedition (Baseline)
  a1, // +15% Enemy Max HP & Damage
  a2, // +20% Enemy Speed, Faster Turn-Meter accumulation
  a3, // Reduced Healing & Barrier efficiency (-20%)
  a4, // Harder Elites with extra affixes
  a5, // Resource Scarcity (-25% Ash & Ember drops)
  a6, // Bleed & Blight durations extended by +1 turn on allies
  a7, // Bosses gain +30% Armor & Resist
  a8, // Lethal Executes: Allies below 15% HP risk immediate severance
  a9, // Terminal Collapse: Reckoning clock accelerates by +35%
  a10, // True Ashen Crucible: All previous modifiers combined + Permadeath in expedition
}

class AscensionTierData {
  final AscensionLevel level;
  final int tierNumber;
  final String title;
  final String subtitle;
  final String modifierSummary;
  final double enemyHpMultiplier;
  final double enemyDamageMultiplier;
  final double enemySpeedMultiplier;
  final double resourceDropMultiplier;
  final Color themeColor;

  const AscensionTierData({
    required this.level,
    required this.tierNumber,
    required this.title,
    required this.subtitle,
    required this.modifierSummary,
    this.enemyHpMultiplier = 1.0,
    this.enemyDamageMultiplier = 1.0,
    this.enemySpeedMultiplier = 1.0,
    this.resourceDropMultiplier = 1.0,
    required this.themeColor,
  });

  static const List<AscensionTierData> allTiers = [
    AscensionTierData(
      level: AscensionLevel.a0,
      tierNumber: 0,
      title: 'ASCENSION 0: AWAKENED',
      subtitle: 'Standard expedition baseline trial.',
      modifierSummary: 'Standard rules: 100% baseline Enemy HP, Damage, and Resource yields.',
      enemyHpMultiplier: 1.0,
      enemyDamageMultiplier: 1.0,
      enemySpeedMultiplier: 1.0,
      resourceDropMultiplier: 1.0,
      themeColor: Color(0xFF81C784),
    ),
    AscensionTierData(
      level: AscensionLevel.a1,
      tierNumber: 1,
      title: 'ASCENSION 1: HARDENED FLESH',
      subtitle: 'Enemies possess heightened durability.',
      modifierSummary: '+15% Enemy Max HP and +10% Enemy Damage across all nodes.',
      enemyHpMultiplier: 1.15,
      enemyDamageMultiplier: 1.10,
      enemySpeedMultiplier: 1.0,
      resourceDropMultiplier: 1.10,
      themeColor: Color(0xFF64B5F6),
    ),
    AscensionTierData(
      level: AscensionLevel.a2,
      tierNumber: 2,
      title: 'ASCENSION 2: CELERITY OF SHADOWS',
      subtitle: 'Enemy speed tickers accelerate.',
      modifierSummary: '+15% Enemy Speed; enemy Turn Meters cycle with swift initiative.',
      enemyHpMultiplier: 1.20,
      enemyDamageMultiplier: 1.15,
      enemySpeedMultiplier: 1.15,
      resourceDropMultiplier: 1.20,
      themeColor: Color(0xFF4FC3F7),
    ),
    AscensionTierData(
      level: AscensionLevel.a3,
      tierNumber: 3,
      title: 'ASCENSION 3: WITHERED VITAE',
      subtitle: 'Restorative arts falter under the gloom.',
      modifierSummary: 'Ally Healing and Aegis Barrier shielding potency reduced by 20%.',
      enemyHpMultiplier: 1.25,
      enemyDamageMultiplier: 1.20,
      enemySpeedMultiplier: 1.15,
      resourceDropMultiplier: 1.30,
      themeColor: Color(0xFFFFB74D),
    ),
    AscensionTierData(
      level: AscensionLevel.a4,
      tierNumber: 4,
      title: 'ASCENSION 4: FIENDISH VANGUARDS',
      subtitle: 'Elite guardians gain reinforced armor plating.',
      modifierSummary: 'Elite fiends and bosses gain +25% Armor and reflect 10% physical damage.',
      enemyHpMultiplier: 1.35,
      enemyDamageMultiplier: 1.25,
      enemySpeedMultiplier: 1.18,
      resourceDropMultiplier: 1.40,
      themeColor: Color(0xFFFF9800),
    ),
    AscensionTierData(
      level: AscensionLevel.a5,
      tierNumber: 5,
      title: 'ASCENSION 5: ASHEN SCARCITY',
      subtitle: 'Mortal caches dwindle in the deep perimeter.',
      modifierSummary: 'Harvest yields reduced: -25% Unbound Ash and Ember Shards extracted.',
      enemyHpMultiplier: 1.40,
      enemyDamageMultiplier: 1.30,
      enemySpeedMultiplier: 1.20,
      resourceDropMultiplier: 0.75,
      themeColor: Color(0xFFBA68C8),
    ),
    AscensionTierData(
      level: AscensionLevel.a6,
      tierNumber: 6,
      title: 'ASCENSION 6: LINGERING MIASMA',
      subtitle: 'Poisons and lacerations fester unabated.',
      modifierSummary: 'Bleed and Blight DoTs on allies persist for +1 extra turn duration.',
      enemyHpMultiplier: 1.50,
      enemyDamageMultiplier: 1.35,
      enemySpeedMultiplier: 1.22,
      resourceDropMultiplier: 1.50,
      themeColor: Color(0xFF9C27B0),
    ),
    AscensionTierData(
      level: AscensionLevel.a7,
      tierNumber: 7,
      title: 'ASCENSION 7: TITANIC FORTITUDE',
      subtitle: 'World Titans command impenetrable wards.',
      modifierSummary: 'Bosses possess +35% Armor & +35% Resist; immunity to Turn-Meter drains.',
      enemyHpMultiplier: 1.65,
      enemyDamageMultiplier: 1.45,
      enemySpeedMultiplier: 1.25,
      resourceDropMultiplier: 1.65,
      themeColor: Color(0xFFE91E63),
    ),
    AscensionTierData(
      level: AscensionLevel.a8,
      tierNumber: 8,
      title: 'ASCENSION 8: CRUEL SEVERANCE',
      subtitle: 'Frail vessels are executed without mercy.',
      modifierSummary: 'Enemy strikes against allies below 20% HP deal guaranteed Critical Hits.',
      enemyHpMultiplier: 1.80,
      enemyDamageMultiplier: 1.60,
      enemySpeedMultiplier: 1.28,
      resourceDropMultiplier: 1.80,
      themeColor: Color(0xFFD32F2F),
    ),
    AscensionTierData(
      level: AscensionLevel.a9,
      tierNumber: 9,
      title: 'ASCENSION 9: ACCELERATED COLLAPSE',
      subtitle: 'The Reckoning timer hastens toward oblivion.',
      modifierSummary: 'Reckoning clock advances +35% faster; Enrage triggers prematurely.',
      enemyHpMultiplier: 2.00,
      enemyDamageMultiplier: 1.75,
      enemySpeedMultiplier: 1.30,
      resourceDropMultiplier: 2.00,
      themeColor: Color(0xFFC2185B),
    ),
    AscensionTierData(
      level: AscensionLevel.a10,
      tierNumber: 10,
      title: 'ASCENSION 10: TRUE CRUCIBLE',
      subtitle: 'The pinnacle of dark fantasy tabletop mastery.',
      modifierSummary: 'All prior Ascension modifiers active simultaneously. Zero tolerance for errors.',
      enemyHpMultiplier: 2.30,
      enemyDamageMultiplier: 2.00,
      enemySpeedMultiplier: 1.35,
      resourceDropMultiplier: 2.50,
      themeColor: Color(0xFFFF1744),
    ),
  ];

  static AscensionTierData forTier(int tier) {
    final clamped = tier.clamp(0, 10);
    return allTiers[clamped];
  }
}
