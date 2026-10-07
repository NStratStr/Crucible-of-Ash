import 'package:flutter/material.dart';

enum TraitTrigger {
  passiveStat,    // Permanent stat boost (e.g., +crit, +def, +atk)
  onAttackHit,    // Triggers when hitting an enemy (e.g., bleed, extra damage)
  onTurnStart,    // Triggers at start of unit turn (e.g., regen, TM boost)
  onTakeDamage,   // Triggers when attacked (e.g., reflect, blight on attacker)
  onCrit,         // Triggers on critical hit (e.g., TM surge)
}

@immutable
class TraitEntity {
  final String id;
  final String name;
  final String description;
  final TraitTrigger trigger;
  final IconData icon;
  final Color themeColor;

  const TraitEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.icon,
    this.themeColor = const Color(0xFFE5A93C),
  });

  static const Map<String, TraitEntity> registry = {
    'rend_flesh': TraitEntity(
      id: 'rend_flesh',
      name: 'Rend Flesh',
      description: 'Strikes tear open wounds, inflicting 1 stack of Bleed on hit.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.water_drop,
      themeColor: Color(0xFFE53935),
    ),
    'shield_bash': TraitEntity(
      id: 'shield_bash',
      name: 'Shield Bastion',
      description: 'Frontline fortitude grants +25% Armor defense while HP is above 50%.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.shield,
      themeColor: Color(0xFF1E88E5),
    ),
    'iron_bastion': TraitEntity(
      id: 'iron_bastion',
      name: 'Iron Bastion',
      description: 'Hardened iron plates grant permanent +30% Armor defense.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.security,
      themeColor: Color(0xFF90A4AE),
    ),
    'pack_instinct': TraitEntity(
      id: 'pack_instinct',
      name: 'Pack Instinct',
      description: 'Hunting coordination grants +10% Attack for each living ally in squad.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.groups,
      themeColor: Color(0xFFFB8C00),
    ),
    'dive_bomb': TraitEntity(
      id: 'dive_bomb',
      name: 'Aerial Predator',
      description: 'Diving strikes against backline Arcanum targets deal +30% bonus damage.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.air,
      themeColor: Color(0xFFFFB300),
    ),
    'piercing_arrow': TraitEntity(
      id: 'piercing_arrow',
      name: 'True Strike',
      description: 'Attacks bypass 50% of the target\'s Armor defense.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.gps_fixed,
      themeColor: Color(0xFF00ACC1),
    ),
    'blight_curse': TraitEntity(
      id: 'blight_curse',
      name: 'Blight Miasma',
      description: 'When struck by an attack, inflicts 1 stack of Blight on the attacker.',
      trigger: TraitTrigger.onTakeDamage,
      icon: Icons.bubble_chart,
      themeColor: Color(0xFF43A047),
    ),
    'plague_hex': TraitEntity(
      id: 'plague_hex',
      name: 'Virulent Hex',
      description: 'Damaging skills inflict 2 stacks of Blight upon targets.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.coronavirus,
      themeColor: Color(0xFF2E7D32),
    ),
    'keen_eye': TraitEntity(
      id: 'keen_eye',
      name: 'Keen Eye',
      description: 'Grants +20% Crit Chance and strikes can never become Glancing Blows.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.visibility,
      themeColor: Color(0xFF4DD0E1),
    ),
    'rabid_bite': TraitEntity(
      id: 'rabid_bite',
      name: 'Rabid Frenzy',
      description: 'Critical strikes grant an immediate +25% Turn Meter surge.',
      trigger: TraitTrigger.onCrit,
      icon: Icons.speed,
      themeColor: Color(0xFFFF7043),
    ),
    'claw_slash': TraitEntity(
      id: 'claw_slash',
      name: 'Savage Claws',
      description: 'Attacks deal +15% bonus base damage.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.colorize,
      themeColor: Color(0xFFE57373),
    ),
    'screech': TraitEntity(
      id: 'screech',
      name: 'Terrifying Shriek',
      description: 'Attacks reduce the target\'s Turn Meter by 15%.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.volume_up,
      themeColor: Color(0xFFBA68C8),
    ),
    'shadow_bolt': TraitEntity(
      id: 'shadow_bolt',
      name: 'Shadow Bolt',
      description: 'Attacks against targets below 50% HP deal +35% bonus execution damage.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.dark_mode,
      themeColor: Color(0xFF7E57C2),
    ),
    'dark_heal': TraitEntity(
      id: 'dark_heal',
      name: 'Sanguine Bloom',
      description: 'At the start of turn, regenerates 8% of maximum HP.',
      trigger: TraitTrigger.onTurnStart,
      icon: Icons.favorite,
      themeColor: Color(0xFFEC407A),
    ),
    'sanguine_mend': TraitEntity(
      id: 'sanguine_mend',
      name: 'Vitae Regeneration',
      description: 'At the start of turn, heals self and lowest HP ally for 6% max HP.',
      trigger: TraitTrigger.onTurnStart,
      icon: Icons.healing,
      themeColor: Color(0xFFE91E63),
    ),
    'death_mark': TraitEntity(
      id: 'death_mark',
      name: 'Death Mark',
      description: 'Strikes against enemies afflicted with Bleed or Blight deal +40% damage.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.dangerous,
      themeColor: Color(0xFFD32F2F),
    ),
    'vicious_strike': TraitEntity(
      id: 'vicious_strike',
      name: 'Vicious Strike',
      description: 'Increases Critical Damage multiplier by +35%.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.flash_on,
      themeColor: Color(0xFFFFB74D),
    ),
    'blood_sovereign': TraitEntity(
      id: 'blood_sovereign',
      name: 'Blood Sovereign',
      description: 'Squad attacks siphon +12% Lifesteal against wounded enemies.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.bloodtype,
      themeColor: Color(0xFFB71C1C),
    ),
    'rend': TraitEntity(
      id: 'rend',
      name: 'Rend',
      description: 'Strikes tear open wounds, inflicting 1 stack of Bleed on hit.',
      trigger: TraitTrigger.onAttackHit,
      icon: Icons.water_drop,
      themeColor: Color(0xFFE53935),
    ),
    'pack_hunter': TraitEntity(
      id: 'pack_hunter',
      name: 'Pack Hunter',
      description: 'Hunting coordination grants +10% Attack for each living ally in squad.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.groups,
      themeColor: Color(0xFFFB8C00),
    ),
  };

  static TraitEntity getTrait(String id) {
    if (registry.containsKey(id)) {
      return registry[id]!;
    }
    // Fallback for custom or generated traits
    return TraitEntity(
      id: id,
      name: id.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '),
      description: 'Ancient lineage trait inherited through the Crucible of Blood.',
      trigger: TraitTrigger.passiveStat,
      icon: Icons.fingerprint,
    );
  }
}
