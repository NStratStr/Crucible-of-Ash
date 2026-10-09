import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/combat_math.dart';
import '../../shared/models/skill_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/models/expedition_boon.dart';
import '../../shared/models/relic_entity.dart';
import '../generals/general_command_service.dart';
import '../relics/relic_service.dart';
import 'initiative_tick_manager.dart';

@immutable
class ActionResult {
  final UnitEntity attacker;
  final UnitEntity target;
  final int damageDealt;
  final bool isCritical;
  final bool isGlancing;
  final double affinityMultiplier;
  final bool targetDefeated;
  final int lifestealRecovered;
  final String skillName;
  final String? appliedStatusName;
  final int healAmount;

  const ActionResult({
    required this.attacker,
    required this.target,
    required this.damageDealt,
    required this.isCritical,
    required this.isGlancing,
    required this.affinityMultiplier,
    required this.targetDefeated,
    required this.lifestealRecovered,
    this.skillName = 'Basic Strike',
    this.appliedStatusName,
    this.healAmount = 0,
  });
}

@immutable
class TurnStartResult {
  final UnitEntity unit;
  final int dotDamage;
  final int healAmount;
  final bool isDefeated;
  final bool isStunned;
  final String? message;
  final List<String> triggeredTraits;

  const TurnStartResult({
    required this.unit,
    this.dotDamage = 0,
    this.healAmount = 0,
    this.isDefeated = false,
    this.isStunned = false,
    this.message,
    this.triggeredTraits = const [],
  });
}

enum BattleModifier {
  none,
  titanicFury,      // Boss attacks cleave all frontline Vanguard units
  bloodMoon,        // +50% critical strike damage amplification
  corrosiveMiasma,  // Non-Occultists suffer 30 poison damage at start of turn
  voidCorruption,   // Non-Occultists take 45 poison at turn start; Occultist strikes apply Blight
  abyssalEclipse,   // Boss attacks cleave frontlines AND non-Occultists suffer 40 poison damage
}

class CombatResolutionService {
  final InitiativeTickManager tickManager;
  final GeneralCommandService? commandService;
  final RelicService? relicService;
  final BattleModifier battleModifier;
  final Set<ExpeditionBoon> activeBoons;
  final Random _rng;

  CombatResolutionService({
    required this.tickManager,
    this.commandService,
    this.relicService,
    this.battleModifier = BattleModifier.none,
    this.activeBoons = const {},
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Executes basic attack for backwards-compatibility
  ActionResult executeBasicAttack({
    required String targetUnitId,
    double skillCoefficient = 1.0,
    double lifestealRatio = 0.0,
    bool autoResumeTickEngine = true,
  }) {
    return executeSkill(
      targetUnitId: targetUnitId,
      skill: SkillEntity(
        id: 'basic_attack',
        name: 'Basic Strike',
        description: 'Standard physical attack',
        damageCoefficient: skillCoefficient,
        lifestealRatio: lifestealRatio,
      ),
      autoResumeTickEngine: autoResumeTickEngine,
    );
  }

  /// Backwards-compatible check if active unit is stunned
  bool checkAndHandleStun() {
    final active = tickManager.activeUnit;
    if (active == null || !active.isStunned) return false;
    final res = processTurnStart(unitId: active.id);
    return res.isStunned || res.isDefeated;
  }

  /// Resolves turn-start effects: regeneration traits (dark_heal, sanguine_mend),
  /// damage-over-time effects (Bleed, Blight), status effect duration ticks, and Stun.
  TurnStartResult processTurnStart({
    required String unitId,
    bool autoResumeIfTurnSkipped = true,
  }) {
    final bool isAlly = tickManager.allies.any((u) => u.id == unitId);
    final List<UnitEntity> friendlySquad = isAlly ? tickManager.allies : tickManager.enemies;
    final List<UnitEntity> opposingSquad = isAlly ? tickManager.enemies : tickManager.allies;

    final unitIndex = friendlySquad.indexWhere((u) => u.id == unitId);
    if (unitIndex == -1) {
      throw ArgumentError('Unit $unitId not found in active combatants.');
    }

    final UnitEntity currentUnit = friendlySquad[unitIndex];
    if (!currentUnit.isAlive) {
      return TurnStartResult(unit: currentUnit, isDefeated: true);
    }

    int healAmount = 0;
    int dotDamage = 0;
    final List<String> triggeredTraits = [];
    final traits = [
      currentUnit.nativeTraitId,
      if (currentUnit.graftedTraitId != null) currentUnit.graftedTraitId!,
    ];

    // Trait: Sanguine Bloom (dark_heal) - regenerates 8% max HP at turn start
    if (traits.contains('dark_heal') && currentUnit.currentHp < currentUnit.maxHp) {
      final reg = max(1, (currentUnit.maxHp * 0.08).round());
      healAmount += reg;
      triggeredTraits.add('dark_heal');
    }

    // Trait: Vitae Regeneration (sanguine_mend) - heals self by 6% and lowest HP ally by 6%
    UnitEntity? healedAlly;
    if (traits.contains('sanguine_mend')) {
      final regSelf = max(1, (currentUnit.maxHp * 0.06).round());
      healAmount += regSelf;
      triggeredTraits.add('sanguine_mend');

      final livingOthers = friendlySquad.where((u) => u.id != currentUnit.id && u.isAlive).toList();
      if (livingOthers.isNotEmpty) {
        livingOthers.sort((a, b) => (a.currentHp / a.maxHp).compareTo(b.currentHp / b.maxHp));
        final targetAlly = livingOthers.first;
        final allyHeal = max(1, (targetAlly.maxHp * 0.06).round());
        healedAlly = targetAlly.copyWith(
          currentHp: min(targetAlly.maxHp, targetAlly.currentHp + allyHeal),
        );
      }
    }

    // Damage-Over-Time (Bleed and Blight)
    for (final effect in currentUnit.activeEffects) {
      if (effect.type == StatusEffectType.bleed) {
        final dmg = effect.value > 0 ? effect.value : max(1, (currentUnit.maxHp * 0.05).round());
        dotDamage += dmg;
      } else if (effect.type == StatusEffectType.blight) {
        final dmg = effect.value > 0 ? effect.value : max(1, (currentUnit.maxHp * 0.06).round());
        dotDamage += dmg;
      }
    }

    // Battle Modifier: Corrosive Miasma / Void Corruption / Abyssal Eclipse
    if ((battleModifier == BattleModifier.corrosiveMiasma ||
            battleModifier == BattleModifier.abyssalEclipse) &&
        currentUnit.archetype != Archetype.occultist) {
      final poison = battleModifier == BattleModifier.abyssalEclipse ? 40 : 30;
      dotDamage += poison;
      triggeredTraits.add('corrosive_miasma');
    } else if (battleModifier == BattleModifier.voidCorruption && currentUnit.archetype != Archetype.occultist) {
      dotDamage += 45;
      triggeredTraits.add('void_corruption');
    }

    // Decrement durations on active effects
    final bool wasStunned = currentUnit.isStunned;
    // Rebind Flesh thralls collapse once their final Decaying turn elapses
    final bool decayExpired = currentUnit.activeEffects
        .any((e) => e.type == StatusEffectType.decaying && e.durationTurns <= 1);
    final updatedEffects = currentUnit.activeEffects
        .map((e) => StatusEffect(type: e.type, durationTurns: e.durationTurns - 1, value: e.value))
        .where((e) => e.durationTurns > 0)
        .toList();

    // Calculate final HP
    final int netHp = decayExpired
        ? 0
        : (currentUnit.currentHp + healAmount - dotDamage).clamp(0, currentUnit.maxHp);
    if (decayExpired) triggeredTraits.add('decay_collapse');
    final updatedUnit = currentUnit.copyWith(
      currentHp: netHp,
      activeEffects: updatedEffects,
    );

    // Update squads
    List<UnitEntity> updatedFriendly = friendlySquad.map((u) {
      if (u.id == currentUnit.id) return updatedUnit;
      if (healedAlly != null && u.id == healedAlly.id) return healedAlly;
      return u;
    }).toList();

    List<UnitEntity> updatedOpposing = List.of(opposingSquad);

    // If unit died from DoT
    if (netHp <= 0) {
      // Malakor's Carrion Miasma: When an ally falls, all enemies gain 2 stacks of Blight
      if (isAlly && commandService?.activeGeneralType == GeneralType.malakor) {
        updatedOpposing = updatedOpposing.map((foe) {
          if (!foe.isAlive) return foe;
          final currentBlights = List<StatusEffect>.from(foe.activeEffects)
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40))
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
          return foe.copyWith(activeEffects: currentBlights);
        }).toList();
      }

      final updatedAllies = isAlly ? updatedFriendly : updatedOpposing;
      final updatedEnemies = isAlly ? updatedOpposing : updatedFriendly;

      tickManager.consumeTurn(
        retainedOverflow: false,
        updatedAllies: updatedAllies,
        updatedEnemies: updatedEnemies,
        autoResume: autoResumeIfTurnSkipped,
      );

      return TurnStartResult(
        unit: updatedUnit,
        dotDamage: dotDamage,
        healAmount: healAmount,
        isDefeated: true,
        message: decayExpired
            ? '${currentUnit.name}\'s rebound flesh crumbles back into the grave!'
            : '${currentUnit.name} succumbed to internal rot and wounds!',
        triggeredTraits: triggeredTraits,
      );
    }

    // If unit was stunned, turn is skipped
    if (wasStunned) {
      final updatedAllies = isAlly ? updatedFriendly : updatedOpposing;
      final updatedEnemies = isAlly ? updatedOpposing : updatedFriendly;

      tickManager.consumeTurn(
        retainedOverflow: false,
        updatedAllies: updatedAllies,
        updatedEnemies: updatedEnemies,
        autoResume: autoResumeIfTurnSkipped,
      );

      return TurnStartResult(
        unit: updatedUnit,
        dotDamage: dotDamage,
        healAmount: healAmount,
        isStunned: true,
        message: '${currentUnit.name} is Stunned and unable to act!',
        triggeredTraits: triggeredTraits,
      );
    }

    // Alive and not stunned: update tickManager without consuming turn
    if (isAlly) {
      tickManager.updateSquads(allies: updatedFriendly, enemies: updatedOpposing);
    } else {
      tickManager.updateSquads(allies: updatedOpposing, enemies: updatedFriendly);
    }

    return TurnStartResult(
      unit: updatedUnit,
      dotDamage: dotDamage,
      healAmount: healAmount,
      isDefeated: false,
      isStunned: false,
      triggeredTraits: triggeredTraits,
    );
  }

  /// Executes a designated skill from the active unit
  ActionResult executeSkill({
    required String targetUnitId,
    required SkillEntity skill,
    bool autoResumeTickEngine = true,
  }) {
    final UnitEntity? attacker = tickManager.activeUnit;
    if (attacker == null || tickManager.phase != CombatPhase.awaitingAction) {
      throw StateError('Cannot execute skill: No active unit awaiting action.');
    }

    final bool attackerIsAlly = tickManager.allies.any((u) => u.id == attacker.id);
    final List<UnitEntity> opposingSquad = attackerIsAlly ? tickManager.enemies : tickManager.allies;
    final List<UnitEntity> friendlySquad = attackerIsAlly ? tickManager.allies : tickManager.enemies;

    // Remember the ally's last (non-Limit-Burst) action for Echoing Hourglass replays
    if (attackerIsAlly && !skill.isLimitBurst) {
      commandService?.recordUnitAction(attacker.id, skill, targetUnitId);
    }

    // Healing / Friendly skill
    if (skill.targetType == SkillTargetType.singleAlly || skill.damageCoefficient == 0.0) {
      return _executeSupportSkill(
        attacker: attacker,
        friendlySquad: friendlySquad,
        targetUnitId: targetUnitId,
        skill: skill,
        attackerIsAlly: attackerIsAlly,
        autoResumeTickEngine: autoResumeTickEngine,
      );
    }

    return _executeOffensiveSkill(
      attacker: attacker,
      opposingSquad: opposingSquad,
      targetUnitId: targetUnitId,
      skill: skill,
      attackerIsAlly: attackerIsAlly,
      autoResumeTickEngine: autoResumeTickEngine,
    );
  }

  ActionResult _executeSupportSkill({
    required UnitEntity attacker,
    required List<UnitEntity> friendlySquad,
    required String targetUnitId,
    required SkillEntity skill,
    required bool attackerIsAlly,
    required bool autoResumeTickEngine,
  }) {
    final int targetIndex = friendlySquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    final UnitEntity target = targetIndex != -1 ? friendlySquad[targetIndex] : attacker;

    int healValue = max(50, (target.maxHp * 0.25).round());
    healValue = (healValue * tickManager.reckoningHealingMultiplier).round();
    final int newHp = min(target.maxHp, target.currentHp + healValue);
    List<StatusEffect> effects = List.of(target.activeEffects);
    if (skill.appliedStatus != null) {
      effects.add(skill.appliedStatus!);
    }

    final UnitEntity updatedTarget = target.copyWith(
      currentHp: newHp,
      activeEffects: effects,
    );

    final List<SkillEntity> updatedSkills = attacker.resolvedSkills.map((s) {
      if (s.id == skill.id) {
        return s.copyWith(currentCooldown: s.cooldownTurns);
      } else if (s.currentCooldown > 0) {
        return s.copyWith(currentCooldown: s.currentCooldown - 1);
      }
      return s;
    }).toList();

    final UnitEntity updatedAttacker = attacker.id == updatedTarget.id
        ? updatedTarget.copyWith(skills: updatedSkills)
        : attacker.copyWith(skills: updatedSkills);

    List<UnitEntity> updatedAllies = List.of(tickManager.allies);
    List<UnitEntity> updatedEnemies = List.of(tickManager.enemies);

    if (attackerIsAlly) {
      updatedAllies = updatedAllies.map((u) {
        if (u.id == updatedAttacker.id) return updatedAttacker;
        if (u.id == updatedTarget.id) return updatedTarget;
        return u;
      }).toList();
    } else {
      updatedEnemies = updatedEnemies.map((u) {
        if (u.id == updatedAttacker.id) return updatedAttacker;
        if (u.id == updatedTarget.id) return updatedTarget;
        return u;
      }).toList();
    }

    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: autoResumeTickEngine,
    );

    return ActionResult(
      attacker: updatedAttacker,
      target: updatedTarget,
      damageDealt: 0,
      isCritical: false,
      isGlancing: false,
      affinityMultiplier: 1.0,
      targetDefeated: false,
      lifestealRecovered: 0,
      healAmount: healValue,
      skillName: skill.name,
      appliedStatusName: skill.appliedStatus?.displayName,
    );
  }

  ActionResult _executeOffensiveSkill({
    required UnitEntity attacker,
    required List<UnitEntity> opposingSquad,
    required String targetUnitId,
    required SkillEntity skill,
    required bool attackerIsAlly,
    required bool autoResumeTickEngine,
  }) {
    final int targetIndex = opposingSquad.indexWhere((u) => u.id == targetUnitId && u.isAlive);
    if (targetIndex == -1) {
      throw ArgumentError('Target unit $targetUnitId is either not found or already defeated.');
    }

    final UnitEntity target = opposingSquad[targetIndex];
    final List<UnitEntity> friendlySquad = attackerIsAlly ? tickManager.allies : tickManager.enemies;

    final attackerRelics = relicService?.calculateBonuses(attacker.id) ?? const UnitRelicBonuses();
    final targetRelics = relicService?.calculateBonuses(target.id) ?? const UnitRelicBonuses();

    final Set<String> attackerTraits = {
      attacker.nativeTraitId,
      if (attacker.graftedTraitId != null) attacker.graftedTraitId!,
    };
    final Set<String> targetTraits = {
      target.nativeTraitId,
      if (target.graftedTraitId != null) target.graftedTraitId!,
    };

    // 1. Evaluate Hex Affinity and Glancing Blow status
    final double affinityMod = CombatMath.getAffinityMultiplier(attacker.archetype, target.archetype);
    bool isGlancing = CombatMath.isGlancingBlow(attacker.archetype, target.archetype, _rng);
    // Trait: Keen Eye prevents glancing blows
    if (attackerTraits.contains('keen_eye')) {
      isGlancing = false;
    }

    // 2. Evaluate Critical Strike
    double effectiveCritRate = (attacker.critRate + attackerRelics.bonusCritRate).clamp(0.0, 1.0);
    if (attackerTraits.contains('keen_eye')) {
      effectiveCritRate = (effectiveCritRate + 0.20).clamp(0.0, 1.0);
    }

    double effectiveCritDmg = attacker.critDamage + attackerRelics.bonusCritDamage;
    if (attackerTraits.contains('vicious_strike')) {
      effectiveCritDmg += 0.35;
    }
    if (attackerIsAlly && activeBoons.contains(ExpeditionBoon.sanguineCovenant)) {
      effectiveCritDmg += 0.15;
    }

    final bool isCritical = !isGlancing && (_rng.nextDouble() < effectiveCritRate);
    double critMod = isCritical ? effectiveCritDmg : 1.0;
    // Battle Modifier: Blood Moon (All critical strike damage is amplified by +50%)
    if (battleModifier == BattleModifier.bloodMoon && isCritical) {
      critMod += 0.50;
    }

    // 3. Compute Defense Mitigation
    int baseDefense = target.defense + targetRelics.bonusDefense;
    // Trait: Iron Bastion (+30% Armor)
    if (targetTraits.contains('iron_bastion')) {
      baseDefense = (baseDefense * 1.30).round();
    }
    // Trait: Shield Bastion (+25% Armor while HP > 50%)
    if (targetTraits.contains('shield_bash') && target.currentHp > (target.maxHp * 0.5)) {
      baseDefense = (baseDefense * 1.25).round();
    }

    // Valeria's Iron Aegis: Frontline Vanguard allies gain +25% Armor
    if (!attackerIsAlly && commandService?.activeGeneralType == GeneralType.valeria && target.isVanguard) {
      baseDefense = (baseDefense * 1.25).round();
    }

    // Expedition Boon: Obsidian Aegis (+20% Defense to all ally targets)
    if (!attackerIsAlly && activeBoons.contains(ExpeditionBoon.obsidianAegis)) {
      baseDefense = (baseDefense * 1.20).round();
    }

    // Trait: Piercing Arrow (ignores 50% defense)
    final bool bypassArmor = skill.ignoresArmor || attackerTraits.contains('piercing_arrow');
    final int effectiveDefense = bypassArmor ? (baseDefense * 0.5).round() : baseDefense;
    final double mitigation = CombatMath.calculateMitigation(effectiveDefense);

    // 4. Compute Base and Final Damage
    int effectiveAttack = attacker.attack + attackerRelics.bonusAttack;
    // Trait: Pack Instinct / Pack Hunter (+10% Attack per living ally)
    if (attackerTraits.contains('pack_instinct') || attackerTraits.contains('pack_hunter')) {
      final int livingAllies = friendlySquad.where((u) => u.isAlive).length;
      effectiveAttack = (effectiveAttack * (1.0 + (0.10 * livingAllies))).round();
    }

    // Expedition Boon: Sanguine Covenant (+15% Attack to all allies)
    if (attackerIsAlly && activeBoons.contains(ExpeditionBoon.sanguineCovenant)) {
      effectiveAttack = (effectiveAttack * 1.15).round();
    }

    double baseDamage = effectiveAttack * skill.damageCoefficient * mitigation;
    // Trait: Savage Claws (+15% damage)
    if (attackerTraits.contains('claw_slash')) {
      baseDamage *= 1.15;
    }

    final double variance = 0.95 + (_rng.nextDouble() * 0.10);
    double totalDamage = baseDamage * affinityMod * critMod * variance;

    // Trait: Aerial Predator (+30% damage vs backline Arcanum)
    if (attackerTraits.contains('dive_bomb') && !target.isVanguard) {
      totalDamage *= 1.30;
    }

    // Trait: Shadow Bolt (+35% damage vs targets below 50% HP)
    if (attackerTraits.contains('shadow_bolt') && target.currentHp < (target.maxHp * 0.5)) {
      totalDamage *= 1.35;
    }

    // Trait: Death Mark (+40% damage vs Bleeding or Blighted foes)
    if (attackerTraits.contains('death_mark')) {
      final bool hasDoT = target.isBleeding || target.activeEffects.any((e) => e.type == StatusEffectType.blight);
      if (hasDoT) {
        totalDamage *= 1.40;
      }
    }

    // Relic Set: Blightweaver (4-pc: +30% damage vs Blighted foes)
    if (attackerRelics.activeSetBonuses.contains(RelicSetType.blightweaver)) {
      final bool hasDoT = target.isBleeding || target.activeEffects.any((e) => e.type == StatusEffectType.blight);
      if (hasDoT) {
        totalDamage *= 1.30;
      }
    }

    // Battle Modifier: Void Corruption (Non-Occultist targets suffer +20% damage)
    if (battleModifier == BattleModifier.voidCorruption && target.archetype != Archetype.occultist) {
      totalDamage *= 1.20;
    }

    // GDD v2.6 Sec 4: Vulnerable status (+25% incoming damage)
    if (target.activeEffects.any((e) => e.type == StatusEffectType.vulnerable)) {
      totalDamage *= 1.25;
    }

    // GDD v2.6 Sec 13.1: The Ashen Reckoning Phase 1/2 Damage Amplification (2.0x)
    totalDamage *= tickManager.reckoningDamageMultiplier;

    if (isGlancing) {
      totalDamage *= 0.70;
    }

    // GDD v2.6 Sec 3.4: Awakening Grace Window (Immune to damage while invulnerable)
    final bool isInvulnerable = target.activeEffects.any((e) => e.type == StatusEffectType.invulnerable);
    int finalDamage = isInvulnerable ? 0 : max(1, totalDamage.round());

    // GDD v2.6 Sec 4: Shield absorption
    List<StatusEffect> targetEffects = List.of(target.activeEffects);
    final int shieldIndex = targetEffects.indexWhere((e) => e.type == StatusEffectType.shield);
    if (shieldIndex != -1 && finalDamage > 0) {
      final shield = targetEffects[shieldIndex];
      if (shield.value >= finalDamage) {
        final remainingShield = shield.value - finalDamage;
        finalDamage = 0;
        if (remainingShield > 0) {
          targetEffects[shieldIndex] = StatusEffect(
            type: StatusEffectType.shield,
            durationTurns: shield.durationTurns,
            value: remainingShield,
          );
        } else {
          targetEffects.removeAt(shieldIndex);
        }
      } else {
        finalDamage -= shield.value;
        targetEffects.removeAt(shieldIndex);
      }
    }

    // 5. Apply Damage to Defender & Status Effects
    final int newTargetHp = max(0, target.currentHp - finalDamage);
    if (skill.appliedStatus != null && !isGlancing && newTargetHp > 0) {
      targetEffects.add(skill.appliedStatus!);
    }

    // Relic Set: Blightweaver (4-pc: Strikes inflict Blight)
    if (attackerRelics.activeSetBonuses.contains(RelicSetType.blightweaver) && !isGlancing && newTargetHp > 0) {
      targetEffects.add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 3, value: 45));
    }

    // Battle Modifier: Void Corruption (Occultist strikes inflict Blight)
    if (battleModifier == BattleModifier.voidCorruption && attacker.archetype == Archetype.occultist && !isGlancing && newTargetHp > 0) {
      targetEffects.add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
    }

    // Trait: Rend Flesh / Rend (Applies Bleed on hit)
    if ((attackerTraits.contains('rend_flesh') || attackerTraits.contains('rend')) && !isGlancing && newTargetHp > 0) {
      targetEffects.add(const StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 50));
    }

    // Trait: Virulent Hex (Applies Blight on hit)
    if (attackerTraits.contains('plague_hex') && !isGlancing && newTargetHp > 0) {
      targetEffects.add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 3, value: 40));
    }

    double targetTurnMeter = target.turnMeter;
    // Trait: Terrifying Shriek / Screech (reduces target TM by 15%)
    if (attackerTraits.contains('screech') && newTargetHp > 0) {
      targetTurnMeter = max(0.0, targetTurnMeter - 15.0);
    }

    final UnitEntity updatedTarget = target.copyWith(
      currentHp: newTargetHp,
      turnMeter: targetTurnMeter,
      activeEffects: targetEffects,
    );

    // Trait: Blight Miasma (inflicts Blight on attacker when hit)
    List<StatusEffect> attackerEffects = List.of(attacker.activeEffects);
    if (targetTraits.contains('blight_curse') && attacker.isAlive) {
      attackerEffects.add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 35));
    }

    // 6. Resolve Lifesteal
    double effectiveLifestealRatio = skill.lifestealRatio + attackerRelics.bonusLifesteal;
    // Trait: Blood Sovereign (+12% Lifesteal)
    if (attackerTraits.contains('blood_sovereign')) {
      effectiveLifestealRatio += 0.12;
    }

    // Expedition Boon: Vitality Wellspring (+15% Lifesteal)
    if (attackerIsAlly && activeBoons.contains(ExpeditionBoon.vitalityWellspring)) {
      effectiveLifestealRatio += 0.15;
    }

    // Vladislav's Crimson Tithe: +8% Lifesteal against wounded or bleeding targets
    if (attackerIsAlly && commandService?.activeGeneralType == GeneralType.vladislav) {
      if (target.isBleeding || target.currentHp < target.maxHp) {
        effectiveLifestealRatio += 0.08;
      }
    }

    int lifestealRecovered = 0;
    int attackerHp = attacker.currentHp;
    if (effectiveLifestealRatio > 0.0 && attacker.isAlive) {
      lifestealRecovered = (finalDamage * effectiveLifestealRatio).round();
      attackerHp = min(attacker.maxHp, attackerHp + lifestealRecovered);
    }

    // Valeria's Iron Aegis: If enemy attacks an allied Vanguard, 15% physical damage reflected back to attacker
    if (!attackerIsAlly && commandService?.activeGeneralType == GeneralType.valeria && target.isVanguard) {
      final int reflected = max(1, (finalDamage * 0.15).round());
      attackerHp = max(0, attackerHp - reflected);
    }

    // Relic Set: Dreadnought (4-pc: Reflects 20% incoming damage back to attacker)
    if (targetRelics.activeSetBonuses.contains(RelicSetType.dreadnought) && attacker.isAlive) {
      final int reflected = max(1, (finalDamage * 0.20).round());
      attackerHp = max(0, attackerHp - reflected);
    }

    // Morrigan's Temporal Threads: Crits grant +5% Turn Meter
    double bonusTmFromCrit = 0.0;
    if (attackerIsAlly && commandService?.activeGeneralType == GeneralType.morrigan && isCritical) {
      bonusTmFromCrit += 5.0;
    }

    // Trait: Rabid Frenzy (+25% TM on crit)
    if (attackerTraits.contains('rabid_bite') && isCritical) {
      bonusTmFromCrit += 25.0;
    }

    // 7. Update Cooldowns and Ultimate Charge
    final double newUltimate = skill.isLimitBurst
        ? 0.0
        : (attacker.ultimateCharge + 25.0).clamp(0.0, 100.0);

    final List<SkillEntity> updatedSkills = attacker.resolvedSkills.map((s) {
      if (s.id == skill.id) {
        return s.copyWith(currentCooldown: s.cooldownTurns);
      } else if (s.currentCooldown > 0) {
        return s.copyWith(currentCooldown: s.currentCooldown - 1);
      }
      return s;
    }).toList();

    final UnitEntity updatedAttacker = attacker.copyWith(
      currentHp: attackerHp,
      turnMeter: attacker.turnMeter + bonusTmFromCrit,
      ultimateCharge: newUltimate,
      skills: updatedSkills,
      activeEffects: attackerEffects,
    );

    // 8. Reconstruct Squad State
    List<UnitEntity> updatedAllies = List.of(tickManager.allies);
    List<UnitEntity> updatedEnemies = List.of(tickManager.enemies);

    if (attackerIsAlly) {
      updatedAllies = updatedAllies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();
    } else {
      updatedEnemies = updatedEnemies.map((u) => u.id == updatedAttacker.id ? updatedAttacker : u).toList();
      updatedAllies = updatedAllies.map((u) => u.id == updatedTarget.id ? updatedTarget : u).toList();

      // Battle Modifier: Titanic Fury / Abyssal Eclipse (Boss attacks strike all frontline Vanguard units simultaneously)
      if ((battleModifier == BattleModifier.titanicFury || battleModifier == BattleModifier.abyssalEclipse) && target.isVanguard) {
        final cleaveDmg = max(1, (finalDamage * 0.75).round());
        updatedAllies = updatedAllies.map((ally) {
          if (ally.id != updatedTarget.id && ally.isVanguard && ally.isAlive) {
            final newHp = max(0, ally.currentHp - cleaveDmg);
            return ally.copyWith(currentHp: newHp);
          }
          return ally;
        }).toList();
      }
    }

    // Malakor's Carrion Miasma: When an ally falls, all enemies gain 2 stacks of Blight
    if (commandService?.activeGeneralType == GeneralType.malakor) {
      final bool allyJustDied = (attackerIsAlly && updatedAttacker.currentHp == 0) ||
          (!attackerIsAlly && updatedTarget.currentHp == 0);
      if (allyJustDied) {
        updatedEnemies = updatedEnemies.map((e) {
          if (!e.isAlive) return e;
          final effects = List<StatusEffect>.from(e.activeEffects)
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40))
            ..add(const StatusEffect(type: StatusEffectType.blight, durationTurns: 2, value: 40));
          return e.copyWith(activeEffects: effects);
        }).toList();
      }
    }

    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: autoResumeTickEngine,
    );

    return ActionResult(
      attacker: updatedAttacker,
      target: updatedTarget,
      damageDealt: finalDamage,
      isCritical: isCritical,
      isGlancing: isGlancing,
      affinityMultiplier: affinityMod,
      targetDefeated: updatedTarget.currentHp == 0,
      lifestealRecovered: lifestealRecovered,
      skillName: skill.name,
      appliedStatusName: skill.appliedStatus?.displayName,
    );
  }

  /// GDD v2.6 Section 3.4: Infused Vitae Revive on downed "Inert Vessel"
  /// Formula: Revived_HP = (Caster_ATK * SkillCoeff) * (1 + Caster_Gen * 0.15)
  /// Capped at target effectiveMaxHp; overflow converts into an Aegis Shield Ring (50% excess).
  /// Revived unit gains 6-tick invulnerability grace window, cleansed debuffs, and AP reset to 0.
  /// Target suffers stacking Soul Fracture penalty (-20% Max HP).
  ActionResult? executeInfusedVitaeRevive({
    required String targetUnitId,
    double skillCoefficient = 1.2,
    bool autoResumeTickEngine = true,
  }) {
    if (tickManager.areRevivesDisabled) {
      return null; // Terminal Collapse forbids revives!
    }

    final UnitEntity? caster = tickManager.activeUnit;
    if (caster == null) return null;

    final bool casterIsAlly = tickManager.allies.any((u) => u.id == caster.id);
    final List<UnitEntity> friendlySquad = casterIsAlly ? tickManager.allies : tickManager.enemies;

    // Find the downed "Inert Vessel" (currentHp == 0)
    final int targetIndex = friendlySquad.indexWhere((u) => u.id == targetUnitId && !u.isAlive);
    if (targetIndex == -1) return null;

    final UnitEntity target = friendlySquad[targetIndex];

    // GDD v2.6 Sec 3.4: Soul Fracture penalty (+1 revive count -> -20% Max HP)
    final int newReviveCount = target.reviveCount + 1;
    final int effectiveCap = (target.maxHp * pow(0.80, newReviveCount)).round();

    // Infused Vitae formula: (Caster_ATK * SkillCoeff) * (1 + Caster_Gen * 0.15)
    final double rawHeal = (caster.attack * skillCoefficient) * (1.0 + (caster.generation * 0.15));
    int calculatedHeal = rawHeal.round();
    calculatedHeal = (calculatedHeal * tickManager.reckoningHealingMultiplier).round();

    final int finalHp = min(effectiveCap, max(1, calculatedHeal));
    final int overflow = max(0, calculatedHeal - effectiveCap);
    final int aegisShield = (overflow * 0.50).round();

    // Cleanse debuffs and apply 6-tick invulnerability grace window & aegis shield
    final List<StatusEffect> updatedEffects = target.activeEffects
        .where((e) => !e.isDebuff)
        .toList();

    updatedEffects.add(const StatusEffect(
      type: StatusEffectType.invulnerable,
      durationTurns: 1,
      value: 6,
    ));

    if (aegisShield > 0) {
      updatedEffects.add(StatusEffect(
        type: StatusEffectType.shield,
        durationTurns: 2,
        value: aegisShield,
      ));
    }

    final UnitEntity revivedUnit = target.copyWith(
      currentHp: finalHp,
      reviveCount: newReviveCount,
      turnMeter: 0.0,
      activeEffects: updatedEffects,
    );

    final List<UnitEntity> updatedFriendly = friendlySquad.map((u) {
      return u.id == target.id ? revivedUnit : u;
    }).toList();

    final updatedAllies = casterIsAlly ? updatedFriendly : tickManager.allies;
    final updatedEnemies = casterIsAlly ? tickManager.enemies : updatedFriendly;

    tickManager.consumeTurn(
      retainedOverflow: false,
      updatedAllies: updatedAllies,
      updatedEnemies: updatedEnemies,
      autoResume: autoResumeTickEngine,
    );

    return ActionResult(
      attacker: caster,
      target: revivedUnit,
      damageDealt: 0,
      isCritical: false,
      isGlancing: false,
      affinityMultiplier: 1.0,
      targetDefeated: false,
      lifestealRecovered: 0,
      skillName: 'Infused Vitae Revival',
      healAmount: finalHp,
    );
  }
}
