import 'dart:math';

/// Grid footprint sizing
enum UnitFootprint {
  single1x1,
  horizontal1x2,
  vertical2x1,
  quadColossus2x2,
}

/// Geometric area-of-effect and targeting vectors
enum TargetPattern {
  singleTarget,
  reachMidToFront,
  piercingColumnSkewer,
  tShapedCleave,
  stAshlarCross,
  horizontalRowScythe,
  flankShadowLeap,
}

/// Visual combat action event dispatched by the simulation engine
class SpatialActionEvent {
  final String id;
  final String attackerId;
  final String attackerName;
  final String skillName;
  final String targetId;
  final String targetName;
  final int damage;
  final bool isCrit;
  final bool isHeal;
  final int bleedStacks;
  final bool isPlayerAttacker;
  final TargetPattern pattern;
  final List<GridNode> affectedNodes;
  final int timestampMs;

  const SpatialActionEvent({
    required this.id,
    required this.attackerId,
    required this.attackerName,
    required this.skillName,
    required this.targetId,
    required this.targetName,
    required this.damage,
    this.isCrit = false,
    this.isHeal = false,
    this.bleedStacks = 0,
    required this.isPlayerAttacker,
    this.pattern = TargetPattern.singleTarget,
    this.affectedNodes = const [],
    required this.timestampMs,
  });
}

/// Dynamic grid node representation on the 3-Row (0=Front, 1=Mid, 2=Back) x 5-Column (0..4) plane
class GridNode {
  final int column; // 0 to 4
  final int row;    // 0 = Front, 1 = Mid, 2 = Back
  final String? occupantUnitId;

  const GridNode({
    required this.column,
    required this.row,
    this.occupantUnitId,
  });

  GridNode copyWith({int? column, int? row, String? occupantUnitId}) {
    return GridNode(
      column: column ?? this.column,
      row: row ?? this.row,
      occupantUnitId: occupantUnitId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridNode && runtimeType == other.runtimeType && column == other.column && row == other.row;

  @override
  int get hashCode => column.hashCode ^ row.hashCode;

  @override
  String toString() => 'GridNode(col: $column, row: $row, occupant: $occupantUnitId)';
}

/// Dynamic Combat Card in Hand
class SpatialCombatCard {
  final String id;
  final String name;
  final int focusCost;
  final String description;
  final TargetPattern pattern;
  final double damageMultiplier;
  final int armorShredPercent;
  final int bleedStacks;
  final bool exhaustsOnCast;

  const SpatialCombatCard({
    required this.id,
    required this.name,
    required this.focusCost,
    required this.description,
    required this.pattern,
    this.damageMultiplier = 1.0,
    this.armorShredPercent = 0,
    this.bleedStacks = 0,
    this.exhaustsOnCast = false,
  });

  String get assetPath {
    if (id == 'phalanx_intercept') {
      return 'assets/images/Spells/Ash Armour.jpg';
    }
    if (id == 'searing_brand') {
      return 'assets/images/Spells/Sunburst - Tier 1 Spell no text.png';
    }
    if (id == 'smite_the_calcified') {
      return 'assets/images/Spells/Soul Shatter.jpg';
    }
    if (id == 'sun_ashlar_wrath' || id == 'sun_king_cataclysm') {
      return 'assets/images/Spells/Sunburst - Tier 1 Spell.png';
    }
    if (id == 'revive_vitae') {
      return 'assets/images/Spells/Sanguine Re-Summon.png';
    }
    if (id == 'stoke_the_embers') {
      return 'assets/images/Spells/Attack_spell_magic_circle.png';
    }
    return 'assets/images/Spells/Attack_spell_magic_circle.png';
  }
}

/// Intent Telegraph for live combat anticipation
class SpatialTelegraphIntent {
  final String id;
  final String skillName;
  final TargetPattern pattern;
  final int originCol;
  final int originRow;
  final List<GridNode> targetNodes;
  final int triggerTick;
  final int totalWindupTicks;
  final int rawDamage;

  const SpatialTelegraphIntent({
    required this.id,
    required this.skillName,
    required this.pattern,
    required this.originCol,
    required this.originRow,
    required this.targetNodes,
    required this.triggerTick,
    required this.totalWindupTicks,
    required this.rawDamage,
  });
}

/// Tactical Unit Archetype determining posture adaptation
enum UnitArchetype {
  vanguardMelee, // Melee frontline tank/brawler (Iron Footman, Valeria)
  reachMidline,  // Flayer/spear/rogue (Sanguine Blade)
  backlineCaster, // Mage/healer/artificer (Sun-Smith, Cinder Witch)
  colossusBehemoth, // Multi-node boss (Gorgoroth)
}

/// Physical Row Depth relative to clash line
enum RowDepth {
  front, // Row 0: Direct clash
  mid,   // Row 1: Advancing / reach depth
  back,  // Row 2: Rearguard / distant depth
}

/// Extended Spatial Unit State for 30 Hz deterministic simulation loop
class CombatUnitState {
  final String id;
  final String name;
  final String templateId;
  final bool isPlayer;
  final UnitFootprint footprint;
  final UnitArchetype archetype;
  final List<GridNode> occupiedNodes;
  final bool isDisplacementImmune;
  final int moveRange;
  int currentAp; // 0 to 10,000 threshold
  int maxHp;
  int hp;
  int maxArmor;
  int armor;
  int attack;
  int speed;
  int bleedStacks;
  int burnDuration; // in ticks (30 ticks = 1 sec)
  int stunDuration; // in ticks (freezes AP)
  int aegisShield; // absorbs damage before HP
  int reviveCount; // tracking Soul Fracture (-20% max HP per revive)
  int ultimateGauge; // 0 to 100%
  bool isSlagCarapaceActive;
  SpatialTelegraphIntent? pendingIntent;

  CombatUnitState({
    required this.id,
    required this.name,
    required this.templateId,
    required this.isPlayer,
    required this.footprint,
    this.archetype = UnitArchetype.vanguardMelee,
    required this.occupiedNodes,
    bool? isDisplacementImmune,
    this.moveRange = 1,
    this.currentAp = 0,
    required this.maxHp,
    required this.hp,
    required this.maxArmor,
    required this.armor,
    required this.attack,
    required this.speed,
    this.bleedStacks = 0,
    this.burnDuration = 0,
    this.stunDuration = 0,
    this.aegisShield = 0,
    this.reviveCount = 0,
    this.ultimateGauge = 0,
    this.isSlagCarapaceActive = false,
    this.pendingIntent,
  }) : isDisplacementImmune = isDisplacementImmune ?? (footprint != UnitFootprint.single1x1);

  /// Current physical row depth (0=front, 1=mid, 2=back)
  RowDepth get currentDepth {
    if (occupiedNodes.isEmpty) return RowDepth.front;
    final row = occupiedNodes.first.row;
    if (row == 0) return RowDepth.front;
    if (row == 1) return RowDepth.mid;
    return RowDepth.back;
  }

  /// Dynamic posture label based on archetype and current row depth
  String get postureLabel {
    if (archetype == UnitArchetype.vanguardMelee) {
      switch (currentDepth) {
        case RowDepth.front:
          return 'Brawl Stance (100% Melee)';
        case RowDepth.mid:
          return 'Advancing Stride (Shockwave 60%)';
        case RowDepth.back:
          return 'Braced Bulwark (Guard +25 Armor)';
      }
    } else if (archetype == UnitArchetype.backlineCaster) {
      switch (currentDepth) {
        case RowDepth.front:
          return 'Point-Blank Panic (Knockback Blast)';
        case RowDepth.mid:
          return 'Midline Channel (Standard Reach)';
        case RowDepth.back:
          return 'Guarded Sanctuary (+20% Defense)';
      }
    }
    return 'Standard Stance';
  }

  bool get isAlive => hp > 0;
  bool get isDowned => hp <= 0;
  bool get isStunned => stunDuration > 0;
  bool get isBurning => burnDuration > 0;

  /// Minimum AP requirement to reposition (50% of 10,000 threshold = 5,000 AP)
  static const int moveApCost = 5000;
  bool get canAffordMovement => currentAp >= moveApCost;

  /// Checks if unit can move to target coordinates based on its moveRange and AP cost
  bool canMoveTo(int targetCol, int targetRow) {
    if (isDisplacementImmune) return false;
    if (currentAp < moveApCost) return false;
    if (targetCol < 0 || targetCol > 4 || targetRow < 0 || targetRow > 2) return false;
    if (occupiedNodes.isEmpty) return false;
    final anchor = occupiedNodes.first;
    if (anchor.column == targetCol && anchor.row == targetRow) return false;
    final colDist = (targetCol - anchor.column).abs();
    final rowDist = (targetRow - anchor.row).abs();
    final dist = max(colDist, rowDist);
    return dist > 0 && dist <= moveRange;
  }

  /// Repositions unit to new target nodes with 50% AP cost
  bool repositionTo(List<GridNode> newNodes, {int apPenalty = moveApCost}) {
    if (isDisplacementImmune || currentAp < apPenalty) return false;
    occupiedNodes.clear();
    occupiedNodes.addAll(newNodes);
    currentAp -= apPenalty;
    return true;
  }

  /// High-resolution miniature cutout asset path matching Dark Fantasy art roster
  String get assetPath {
    if (id.contains('gorgoroth') || templateId.contains('gorgoroth')) {
      return 'assets/images/flayed_butcher.png';
    }
    if (id.contains('cinder_witch') || templateId.contains('cinder_witch')) {
      return 'assets/images/occultist_base.png';
    }
    if (id.contains('pyre_zealot') || templateId.contains('pyre_zealot')) {
      return 'assets/images/grave_ghoul_g1.png';
    }
    if (id.contains('valeria') || templateId.contains('valeria')) {
      return 'assets/images/Ash Legion/lady_valeria_g1.png';
    }
    if (id.contains('iron_footman') || templateId.contains('iron_footman')) {
      return 'assets/images/iron_footman_g1.png';
    }
    if (id.contains('sanguine_blade') || templateId.contains('sanguine_blade')) {
      return 'assets/images/sanguine_flayer_g3.png';
    }
    if (id.contains('sun_smith') || templateId.contains('sun_smith')) {
      return 'assets/images/sun_scorched_cleric.png';
    }
    return 'assets/images/footman_base.png';
  }

  /// Physical Damage Reduction Ratio based on Armor
  double get physicalReductionRatio {
    if (armor <= 0) return 0.0;
    return (armor / (armor + 105.0)).clamp(0.0, 0.85);
  }

  /// Check if unit occupies a specific grid node
  bool occupies(int col, int row) {
    return occupiedNodes.any((n) => n.column == col && n.row == row);
  }

  /// Inflicts damage taking Slag Carapace, Aegis Shield, and Armor into account
  int takeDamage(int rawDamage, {bool ignoreArmor = false}) {
    double finalDmg = rawDamage.toDouble();
    if (isSlagCarapaceActive && armor > 0) {
      finalDmg *= 0.50; // -50% damage while Slag Carapace armor holds
    }
    if (!ignoreArmor) {
      finalDmg *= (1.0 - physicalReductionRatio);
    }
    int applied = max(1, finalDmg.round());

    // Aegis Shield absorbs incoming damage first
    if (aegisShield > 0) {
      if (aegisShield >= applied) {
        aegisShield -= applied;
        return applied;
      } else {
        applied -= aegisShield;
        aegisShield = 0;
      }
    }

    hp = max(0, hp - applied);
    return applied;
  }

  /// Sunders armor by percentage
  void sunderArmor(double ratio) {
    final int shred = (armor * ratio).round();
    armor = max(0, armor - shred);
    if (armor <= 0) {
      isSlagCarapaceActive = false;
    }
  }
}
