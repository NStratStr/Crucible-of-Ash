import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/spatial_combat_models.dart';
import '../../shared/models/unit_entity.dart';
import '../../core/combat_math.dart';

/// Deterministic 30 Hz Spatial Combat Engine simulating the 3-Row x 5-Col Grid Plane
class SpatialCombatEngine extends ChangeNotifier {
  static const int tickThreshold = 10000;
  static const int ticksPerSecond = 30;

  final List<CombatUnitState> playerUnits = [];
  final List<CombatUnitState> enemyUnits = [];

  // Commander Focus Economy
  int focus = 3;
  int maxFocus = 7;

  // Deck & Hand Management
  final List<SpatialCombatCard> drawPile = [];
  final List<SpatialCombatCard> hand = [];
  final List<SpatialCombatCard> burnPit = [];

  int currentTick = 0;
  bool isRunning = false; // Starts paused in pre-battle deployment phase
  bool isPreBattlePhase = true; // Tactical Deployment Phase
  double simulationSpeed = 1.0;
  bool isBulletTime = false;

  // Recent Event Logs & Popups
  final List<String> combatLogs = [];
  String? lastBannerMessage;
  SpatialActionEvent? activeActionEvent;
  bool isActionPauseEnabled = false;

  bool get isVictory => enemyUnits.isNotEmpty && enemyUnits.every((u) => !u.isAlive);
  bool get isDefeat => playerUnits.isNotEmpty && playerUnits.every((u) => !u.isAlive);

  /// GDD Section 4.2: Positional Commander Stance Aura for Lady Valeria
  /// Row 0 = Frontline ("Bastion of Cold Iron": Frontline allies gain +25 Armor)
  /// Row 1 or 2 = Rearguard ("Aegis Rearguard": Mid/Backline allies gain +20% Shield/Ward potency)
  String get valeriaStance {
    final valeria = playerUnits.where((u) => u.id == 'lady_valeria' && u.isAlive).firstOrNull;
    if (valeria == null) return 'Severed Resonance';
    final row = valeria.occupiedNodes.isNotEmpty ? valeria.occupiedNodes.first.row : 0;
    return row == 0 ? 'Bastion of Cold Iron (Frontline)' : 'Aegis Rearguard (Backline)';
  }

  bool get isValeriaInFrontline {
    final valeria = playerUnits.where((u) => u.id == 'lady_valeria' && u.isAlive).firstOrNull;
    if (valeria == null) return false;
    return valeria.occupiedNodes.isNotEmpty && valeria.occupiedNodes.first.row == 0;
  }

  /// GDD Section 7.3: Star Rating & Extraction
  /// 3 Stars: Flawless Clear (0 casualties) -> Permanently unlocks Instant Sweep / Extraction
  /// 2 Stars: Encounter Cleared with 1 casualty
  /// 1 Star: Encounter Cleared with >= 2 casualties
  int get casualtiesCount => playerUnits.where((u) => u.isDowned).length;
  int get starRating {
    if (!isVictory) return 0;
    if (casualtiesCount == 0) return 3;
    if (casualtiesCount == 1) return 2;
    return 1;
  }

  bool get isFlawlessClear => isVictory && casualtiesCount == 0;

  // GDD §7.1: Crypt Currencies & Reagents
  int get rewardUnboundAsh => isVictory ? (240 + (starRating * 80)) : 45;
  int get rewardDistilledVitae => isVictory ? (18 + (starRating * 6)) : 2;
  String? get rewardBossReagent => isVictory ? 'Molten Brim-Slag (Tier 2 Keystone)' : null;

  /// GDD Section 6.3: Ashen Reckoning (Universal Soft Enrage)
  /// Skirmishes / encounters enter Reckoning at 3:00 (5,400 ticks), or demo threshold (tick 900)
  /// Modifiers during Reckoning: Damage dealt x2.0, healing received -50%
  static const int reckoningTickThreshold = 900; // ~30 seconds demo threshold for fast testing
  bool get isAshenReckoning => currentTick >= reckoningTickThreshold;
  double get reckoningDamageMultiplier => isAshenReckoning ? 2.0 : 1.0;

  /// Returns all grid nodes currently telegraphed by any enemy intent
  List<GridNode> get activeTelegraphedNodes {
    final List<GridNode> nodes = [];
    for (final enemy in enemyUnits) {
      if (enemy.isAlive && enemy.pendingIntent != null) {
        nodes.addAll(enemy.pendingIntent!.targetNodes);
      }
    }
    return nodes;
  }

  String encounterTitle;
  String encounterDescription;

  SpatialCombatEngine({
    List<UnitEntity>? initialPlayerEntities,
    List<UnitEntity>? initialEnemyEntities,
    String? title,
    String? description,
    bool isBossEncounter = false,
  })  : encounterTitle = title ?? 'The Sunder at Ashen Gate',
        encounterDescription = description ?? 'Encounter 4: Tabletop Colossus Battle' {
    if (initialEnemyEntities != null && initialEnemyEntities.isNotEmpty) {
      setupCampaignEncounter(
        playerEntities: initialPlayerEntities,
        enemyEntities: initialEnemyEntities,
        isBoss: isBossEncounter,
        title: title,
        description: description,
      );
    } else {
      setupSunderAtAshenGate();
    }
  }

  /// Maps an Archetype to a tactical UnitArchetype for 2.5D spatial combat
  static UnitArchetype mapArchetypeToSpatial(Archetype arc, {bool isBoss = false}) {
    if (isBoss) return UnitArchetype.colossusBehemoth;
    switch (arc) {
      case Archetype.juggernaut:
        return UnitArchetype.vanguardMelee;
      case Archetype.assassin:
      case Archetype.skirmisher:
      case Archetype.marksman:
        return UnitArchetype.reachMidline;
      case Archetype.occultist:
      case Archetype.support:
        return UnitArchetype.backlineCaster;
    }
  }

  /// Configures a dynamic 2.5D spatial encounter from Campaign Map entities
  void setupCampaignEncounter({
    List<UnitEntity>? playerEntities,
    required List<UnitEntity> enemyEntities,
    bool isBoss = false,
    String? title,
    String? description,
  }) {
    if (title != null) encounterTitle = title;
    if (description != null) encounterDescription = description;
    playerUnits.clear();
    enemyUnits.clear();
    drawPile.clear();
    hand.clear();
    burnPit.clear();
    combatLogs.clear();
    currentTick = 0;
    isRunning = false;
    isPreBattlePhase = true;
    focus = 3;
    maxFocus = 7;
    isBulletTime = false;

    // --- POPULATE ENEMY UNITS ONTO SPATIAL GRID ---
    // If Boss encounter, place Boss as 2x2 Colossus or central behemoth
    if (isBoss) {
      final bossEntity = enemyEntities.first;
      final bossFootprint = UnitFootprint.quadColossus2x2;
      final bossUnit = CombatUnitState(
        id: bossEntity.id,
        name: bossEntity.name,
        templateId: bossEntity.speciesId,
        isPlayer: false,
        footprint: bossFootprint,
        archetype: UnitArchetype.colossusBehemoth,
        occupiedNodes: [
          GridNode(column: 1, row: 0, occupantUnitId: bossEntity.id),
          GridNode(column: 2, row: 0, occupantUnitId: bossEntity.id),
          GridNode(column: 1, row: 1, occupantUnitId: bossEntity.id),
          GridNode(column: 2, row: 1, occupantUnitId: bossEntity.id),
        ],
        isDisplacementImmune: true,
        maxHp: bossEntity.maxHp,
        hp: bossEntity.currentHp,
        maxArmor: bossEntity.defense,
        armor: bossEntity.defense,
        attack: bossEntity.attack,
        speed: bossEntity.speed,
        isSlagCarapaceActive: true,
        customAssetPath: bossEntity.customAvatarAsset,
      );
      enemyUnits.add(bossUnit);

      // Add remaining minions (if any) to flanks
      int minionIdx = 0;
      for (int i = 1; i < enemyEntities.length; i++) {
        final minion = enemyEntities[i];
        final col = (minionIdx % 2 == 0) ? 0 : 4;
        final row = (minionIdx ~/ 2 == 0) ? 0 : 2;
        minionIdx++;

        enemyUnits.add(CombatUnitState(
          id: minion.id,
          name: minion.name,
          templateId: minion.speciesId,
          isPlayer: false,
          footprint: UnitFootprint.single1x1,
          archetype: mapArchetypeToSpatial(minion.archetype),
          occupiedNodes: [GridNode(column: col, row: row, occupantUnitId: minion.id)],
          level: minion.level,
          maxHp: minion.maxHp,
          hp: minion.currentHp,
          maxArmor: minion.defense,
          armor: minion.defense,
          attack: minion.attack,
          speed: minion.speed,
          customAssetPath: minion.customAvatarAsset,
        ));
      }
    } else {
      // Standard Skirmish / Elite: Place enemies across columns 0..4
      for (int i = 0; i < min(5, enemyEntities.length); i++) {
        final e = enemyEntities[i];
        final bool isVanguard = e.isFrontlineOverride ?? (e.slot == FormationSlot.front1 || e.slot == FormationSlot.front2 || e.slot == FormationSlot.front3);
        final int targetRow = isVanguard ? 0 : (e.archetype == Archetype.support || e.archetype == Archetype.occultist ? 2 : 1);
        final int targetCol = (i * 2) % 5; // Stagger across columns 0, 2, 4, 1, 3

        enemyUnits.add(CombatUnitState(
          id: e.id,
          name: e.name,
          templateId: e.speciesId,
          isPlayer: false,
          footprint: UnitFootprint.single1x1,
          archetype: mapArchetypeToSpatial(e.archetype),
          occupiedNodes: [GridNode(column: targetCol, row: targetRow, occupantUnitId: e.id)],
          level: e.level,
          maxHp: e.maxHp,
          hp: e.currentHp,
          maxArmor: e.defense,
          armor: e.defense,
          attack: e.attack,
          speed: e.speed,
          customAssetPath: e.customAvatarAsset,
        ));
      }
    }

    // --- POPULATE PLAYER SQUAD ONTO SPATIAL GRID ---
    if (playerEntities != null && playerEntities.isNotEmpty) {
      for (int i = 0; i < min(5, playerEntities.length); i++) {
        final p = playerEntities[i];
        final bool isFront = p.isFrontlineOverride ?? (p.slot == FormationSlot.front1 || p.slot == FormationSlot.front2 || p.slot == FormationSlot.front3);
        final int pRow = isFront ? 0 : (p.archetype == Archetype.occultist || p.archetype == Archetype.support ? 2 : 1);
        final int pCol = p.columnIndexOverride ?? (i % 5);

        playerUnits.add(CombatUnitState(
          id: p.id,
          name: p.name,
          templateId: p.speciesId,
          isPlayer: true,
          footprint: UnitFootprint.single1x1,
          archetype: mapArchetypeToSpatial(p.archetype),
          occupiedNodes: [GridNode(column: pCol, row: pRow, occupantUnitId: p.id)],
          level: p.level,
          maxHp: p.maxHp,
          hp: p.currentHp,
          maxArmor: p.defense,
          armor: p.defense,
          attack: p.attack,
          speed: p.speed,
          customAssetPath: p.customAvatarAsset,
        ));
      }
    } else {
      // Default fallback player squad (Ash & Stone Order)
      setupSunderAtAshenGate();
      return;
    }

    // Cards Setup
    hand.addAll([
      const SpatialCombatCard(
        id: 'phalanx_intercept',
        name: 'Phalanx Intercept',
        focusCost: 2,
        description: 'Fortifies ally in Frontline with +35 Armor & taunt barrier.',
        pattern: TargetPattern.singleTarget,
      ),
      const SpatialCombatCard(
        id: 'searing_brand',
        name: 'Searing Brand',
        focusCost: 2,
        description: 'Strikes enemy node and ignites cross pattern for 90 radiant damage.',
        pattern: TargetPattern.stAshlarCross,
        damageMultiplier: 1.2,
      ),
      const SpatialCombatCard(
        id: 'stoke_the_embers',
        name: 'Stoke the Embers',
        focusCost: 1,
        description: 'Exhaust or burn to generate immediate +1 Focus & draw sovereign cards.',
        pattern: TargetPattern.singleTarget,
      ),
    ]);

    drawPile.addAll([
      const SpatialCombatCard(
        id: 'smite_the_calcified',
        name: 'Smite the Calcified',
        focusCost: 4,
        description: 'Kinetic strike (2.5x ATK). If target PRR > 40%, shatters armor by 50%!',
        pattern: TargetPattern.singleTarget,
        damageMultiplier: 2.5,
        armorShredPercent: 50,
      ),
      const SpatialCombatCard(
        id: 'sun_ashlar_wrath',
        name: 'Wrath of Ashlar',
        focusCost: 3,
        description: 'Radiant cross beam hitting North, South, East, West.',
        pattern: TargetPattern.stAshlarCross,
        damageMultiplier: 1.8,
      ),
      const SpatialCombatCard(
        id: 'sun_king_cataclysm',
        name: 'Cataclysm of the Sun-King',
        focusCost: 5,
        description: 'APEX RITE: Unleashes solar pillar incinerating enemy column for 260 DMG & dispelling intents!',
        pattern: TargetPattern.piercingColumnSkewer,
        damageMultiplier: 3.2,
      ),
      const SpatialCombatCard(
        id: 'revive_vitae',
        name: 'Infused Vitae Resurgence',
        focusCost: 3,
        description: 'SOVEREIGN SLIP: Resurrects downed plinth with 50% HP & 6-tick invulnerability (-20% max HP Soul Fracture).',
        pattern: TargetPattern.singleTarget,
      ),
    ]);

    addLog('Encounter Initialized: $encounterTitle.');
    notifyListeners();
  }

  void dispatchAction(SpatialActionEvent event) {
    activeActionEvent = event;
    notifyListeners();
  }

  void clearActiveAction() {
    activeActionEvent = null;
    notifyListeners();
  }

  /// Sets up Encounter 4: "The Sunder at Ashen Gate" per GDD v3.2 Spec
  void setupSunderAtAshenGate() {
    playerUnits.clear();
    enemyUnits.clear();
    drawPile.clear();
    hand.clear();
    burnPit.clear();
    combatLogs.clear();
    currentTick = 0;
    isRunning = false;
    isPreBattlePhase = true;
    focus = 3;
    maxFocus = 7;
    isBulletTime = false;

    // --- ENEMY SQUAD: PYRE SYNOD COHORT ---
    // Gorgoroth the Flayed: 2x2 Quad-Colossus Behemoth Boss occupying 4 tiles (Cols 1-2, Rows 0-1)
    final gorgoroth = CombatUnitState(
      id: 'gorgoroth_boss',
      name: 'Gorgoroth the Flayed',
      templateId: 'gorgoroth_boss',
      isPlayer: false,
      footprint: UnitFootprint.quadColossus2x2,
      occupiedNodes: [
        const GridNode(column: 1, row: 0, occupantUnitId: 'gorgoroth_boss'), // Col 2 Front (Anchor)
        const GridNode(column: 2, row: 0, occupantUnitId: 'gorgoroth_boss'), // Col 3 Front
        const GridNode(column: 1, row: 1, occupantUnitId: 'gorgoroth_boss'), // Col 2 Mid
        const GridNode(column: 2, row: 1, occupantUnitId: 'gorgoroth_boss'), // Col 3 Mid
      ],
      isDisplacementImmune: true,
      maxHp: 2400,
      hp: 2400,
      maxArmor: 75,
      armor: 75,
      attack: 110,
      speed: 70,
      isSlagCarapaceActive: true,
    );

    // Cinder Witch: 1x1 Arcanum in Col 1 Backline (Col index 0, Row 2)
    final cinderWitch = CombatUnitState(
      id: 'cinder_witch',
      name: 'Cinder Witch',
      templateId: 'cinder_witch',
      isPlayer: false,
      archetype: UnitArchetype.backlineCaster,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 0, row: 2, occupantUnitId: 'cinder_witch'),
      ],
      maxHp: 320,
      hp: 320,
      maxArmor: 15,
      armor: 15,
      attack: 65,
      speed: 110,
    );

    // Pyre Zealot: 1x1 Striker in Col 5 Frontline (Col index 4, Row 0)
    final pyreZealot = CombatUnitState(
      id: 'pyre_zealot',
      name: 'Pyre Zealot',
      templateId: 'pyre_zealot',
      isPlayer: false,
      archetype: UnitArchetype.vanguardMelee,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 4, row: 0, occupantUnitId: 'pyre_zealot'),
      ],
      maxHp: 410,
      hp: 410,
      maxArmor: 25,
      armor: 25,
      attack: 85,
      speed: 125,
    );

    enemyUnits.addAll([gorgoroth, cinderWitch, pyreZealot]);

    // --- PLAYER SQUAD: ASH & STONE ORDER ---
    // Lady Valeria: 1x1 Commander in Col 2 Frontline (Col index 1, Row 0)
    final valeria = CombatUnitState(
      id: 'lady_valeria',
      name: 'Lady Valeria',
      templateId: 'lady_valeria',
      isPlayer: true,
      archetype: UnitArchetype.vanguardMelee,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 1, row: 0, occupantUnitId: 'lady_valeria'),
      ],
      maxHp: 560,
      hp: 560,
      maxArmor: 55,
      armor: 55,
      attack: 74,
      speed: 85,
    );

    // Iron Footman: 1x1 Vanguard in Col 4 Frontline (Col index 3, Row 0)
    final ironFootman = CombatUnitState(
      id: 'iron_footman',
      name: 'Iron Footman',
      templateId: 'iron_footman',
      isPlayer: true,
      archetype: UnitArchetype.vanguardMelee,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 3, row: 0, occupantUnitId: 'iron_footman'),
      ],
      maxHp: 450,
      hp: 450,
      maxArmor: 45,
      armor: 45,
      attack: 60,
      speed: 80,
    );

    // Sanguine Blade: 1x1 Midline in Col 4 Midline (Col index 3, Row 1)
    final sanguineBlade = CombatUnitState(
      id: 'sanguine_blade',
      name: 'Sanguine Blade',
      templateId: 'sanguine_blade',
      isPlayer: true,
      archetype: UnitArchetype.reachMidline,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 3, row: 1, occupantUnitId: 'sanguine_blade'),
      ],
      moveRange: 2,
      maxHp: 310,
      hp: 310,
      maxArmor: 20,
      armor: 20,
      attack: 78,
      speed: 120,
    );

    // Sun-Smith Artificer: 1x1 Arcanum in Col 5 Backline (Col index 4, Row 2)
    final sunSmith = CombatUnitState(
      id: 'sun_smith',
      name: 'Sun-Smith Artificer',
      templateId: 'sun_smith',
      isPlayer: true,
      archetype: UnitArchetype.backlineCaster,
      footprint: UnitFootprint.single1x1,
      occupiedNodes: [
        const GridNode(column: 4, row: 2, occupantUnitId: 'sun_smith'),
      ],
      maxHp: 280,
      hp: 280,
      maxArmor: 15,
      armor: 15,
      attack: 70,
      speed: 95,
    );

    playerUnits.addAll([valeria, ironFootman, sanguineBlade, sunSmith]);

    // Cards Setup
    hand.addAll([
      const SpatialCombatCard(
        id: 'phalanx_intercept',
        name: 'Phalanx Intercept',
        focusCost: 2,
        description: 'Fortifies ally in Frontline with +35 Armor & taunt barrier.',
        pattern: TargetPattern.singleTarget,
      ),
      const SpatialCombatCard(
        id: 'searing_brand',
        name: 'Searing Brand',
        focusCost: 2,
        description: 'Strikes enemy node and ignites cross pattern for 90 radiant damage.',
        pattern: TargetPattern.stAshlarCross,
        damageMultiplier: 1.2,
      ),
      const SpatialCombatCard(
        id: 'stoke_the_embers',
        name: 'Stoke the Embers',
        focusCost: 1,
        description: 'Exhaust or burn to generate immediate +1 Focus & draw sovereign cards.',
        pattern: TargetPattern.singleTarget,
      ),
    ]);

    drawPile.addAll([
      const SpatialCombatCard(
        id: 'smite_the_calcified',
        name: 'Smite the Calcified',
        focusCost: 4,
        description: 'Kinetic strike (2.5x ATK). If target PRR > 40%, shatters armor by 50%!',
        pattern: TargetPattern.singleTarget,
        damageMultiplier: 2.5,
        armorShredPercent: 50,
      ),
      const SpatialCombatCard(
        id: 'sun_ashlar_wrath',
        name: 'Wrath of Ashlar',
        focusCost: 3,
        description: 'Radiant cross beam hitting North, South, East, West.',
        pattern: TargetPattern.stAshlarCross,
        damageMultiplier: 1.8,
      ),
      const SpatialCombatCard(
        id: 'sun_king_cataclysm',
        name: 'Cataclysm of the Sun-King',
        focusCost: 5,
        description: 'APEX RITE: Unleashes solar pillar incinerating enemy column for 260 DMG & dispelling intents!',
        pattern: TargetPattern.piercingColumnSkewer,
        damageMultiplier: 3.2,
      ),
      const SpatialCombatCard(
        id: 'revive_vitae',
        name: 'Infused Vitae Resurgence',
        focusCost: 3,
        description: 'SOVEREIGN SLIP: Resurrects downed plinth with 50% HP & 6-tick invulnerability (-20% max HP Soul Fracture).',
        pattern: TargetPattern.singleTarget,
      ),
    ]);

    addLog('Encounter Initialized: The Sunder at Ashen Gate.');
    notifyListeners();
  }

  void addLog(String message) {
    combatLogs.insert(0, '[Tick $currentTick] $message');
    if (combatLogs.length > 50) {
      combatLogs.removeLast();
    }
    notifyListeners();
  }

  void setBulletTime(bool active) {
    isBulletTime = active;
    simulationSpeed = active ? 0.30 : 1.0;
    notifyListeners();
  }

  /// 30 Hz Discrete Tick Execution
  void stepTick() {
    // If a skill or attack cut-in is currently resolving on screen, pause tick progression
    // so players and enemies have kinetic focus and readability!
    if (isActionPauseEnabled && activeActionEvent != null) {
      return;
    }

    currentTick++;

    // Focus Passive Accumulation: Lady Valeria fills 1 Focus per 40 ticks (~1.33 seconds).
    // GDD §4.3: If Commander is in downed state ("Severed Resonance"), Focus generation is throttled by 50% (80 ticks).
    final isCommanderDowned = playerUnits.any((u) => u.id == 'lady_valeria' && u.isDowned);
    final focusInterval = isCommanderDowned ? 80 : 40;
    if (currentTick % focusInterval == 0 && focus < maxFocus) {
      focus++;
      notifyListeners();
    }

    // Process Invulnerability Window Decay (e.g. 6 ticks = 0.2s after revive)
    for (final unit in [...playerUnits, ...enemyUnits]) {
      if (unit.invulnerabilityTicks > 0) {
        unit.invulnerabilityTicks--;
      }
    }

    // Bleed & Poison Ticks (Every 30 ticks = 1 second)
    if (currentTick % 30 == 0) {
      for (final unit in [...playerUnits, ...enemyUnits]) {
        if (unit.isAlive && unit.bleedStacks > 0) {
          final bleedDmg = (unit.bleedStacks * 18 * reckoningDamageMultiplier).round();
          unit.takeDamage(bleedDmg, ignoreArmor: true, isPhysical: true);
          addLog('${unit.name} suffers $bleedDmg Bleed damage ($unit.hp/${unit.maxHp} HP).');
          dispatchAction(SpatialActionEvent(
            id: 'bleed_${currentTick}_${unit.id}',
            attackerId: 'status_bleed',
            attackerName: 'BLEED',
            skillName: 'Hemorrhage',
            targetId: unit.id,
            targetName: unit.name,
            damage: bleedDmg,
            isPlayerAttacker: false,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Poison Ticks (DoT Nature: true damage per second, GDD §6.1)
        if (unit.isAlive && unit.poisonStacks > 0) {
          final poisonDmg = (unit.poisonStacks * 14 * reckoningDamageMultiplier).round();
          unit.takeDamage(poisonDmg, ignoreArmor: true, isPhysical: false);
          addLog('${unit.name} suffers $poisonDmg Poison true damage ($unit.hp/${unit.maxHp} HP, -${unit.poisonStacks * 2}% ATK/SPD).');
          dispatchAction(SpatialActionEvent(
            id: 'poison_${currentTick}_${unit.id}',
            attackerId: 'status_poison',
            attackerName: 'POISON',
            skillName: 'Caustic Toxin',
            targetId: unit.id,
            targetName: unit.name,
            damage: poisonDmg,
            isPlayerAttacker: false,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Burn Ticks (Every 30 ticks = 1 second)
        if (unit.isAlive && unit.burnDuration > 0) {
          unit.burnDuration = max(0, unit.burnDuration - 30);
          final burnDmg = (24 * reckoningDamageMultiplier).round();
          unit.takeDamage(burnDmg, ignoreArmor: false, isPhysical: false);
          addLog('${unit.name} burns for $burnDmg Fire damage (${unit.burnDuration ~/ 30}s remaining).');
          dispatchAction(SpatialActionEvent(
            id: 'burn_${currentTick}_${unit.id}',
            attackerId: 'status_burn',
            attackerName: 'BURNING',
            skillName: 'Ignition',
            targetId: unit.id,
            targetName: unit.name,
            damage: burnDmg,
            isPlayerAttacker: false,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Stun countdown
        if (unit.isAlive && unit.stunDuration > 0) {
          unit.stunDuration = max(0, unit.stunDuration - 30);
        }

        // Freeze countdown (Hard CC: cannot act or gain AP)
        if (unit.isAlive && unit.freezeDuration > 0) {
          unit.freezeDuration = max(0, unit.freezeDuration - 30);
        }

        // Vulnerable countdown
        if (unit.isAlive && unit.vulnerableDuration > 0) {
          unit.vulnerableDuration = max(0, unit.vulnerableDuration - 30);
        }

        // Haste countdown
        if (unit.isAlive && unit.hasteDuration > 0) {
          unit.hasteDuration = max(0, unit.hasteDuration - 30);
        }
      }
    }

    // Step AP Accumulation for all living units (Stun & Freeze pause AP accumulation per GDD §4 / §6.1)
    final allUnits = [...enemyUnits, ...playerUnits].where((u) => u.isAlive).toList();
    for (final unit in allUnits) {
      if (!unit.isStunned && !unit.isFrozen) {
        unit.currentAp += unit.effectiveSpeed;
      }
    }

    // Check impending Boss Intents (Gorgoroth winds up Molten Great-Cleaver on tick 135, and cycles every 160 ticks)
    // GDD §6.2: Under 50% HP, Gorgoroth enters Phase 2 Enkindled: winds up room-wide "Hearth Cataclysm"
    final gorgoroth = enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull;
    if (gorgoroth != null) {
      final bool isPhase2Enkindled = gorgoroth.hp <= (gorgoroth.maxHp * 0.50);

      if ((currentTick == 135 || (currentTick > 150 && currentTick % 160 == 0)) && gorgoroth.pendingIntent == null) {
        if (isPhase2Enkindled) {
          // Hearth Cataclysm: 20-tick windup terminal channel hitting all Frontline (row 0) and Midline (row 1) nodes!
          final cataclysmNodes = [
            for (int col = 0; col < 5; col++) ...[
              GridNode(column: col, row: 0),
              GridNode(column: col, row: 1),
            ],
          ];
          gorgoroth.pendingIntent = SpatialTelegraphIntent(
            id: 'hearth_cataclysm_$currentTick',
            skillName: 'Hearth Cataclysm',
            pattern: TargetPattern.horizontalRowScythe,
            originCol: 1,
            originRow: 0,
            targetNodes: cataclysmNodes,
            triggerTick: currentTick + 20,
            totalWindupTicks: 20,
            rawDamage: 320,
          );
          lastBannerMessage = '🔥 ENKINDLED APEX: HEARTH CATACLYSM WINDING UP!';
          addLog('BOSS APEX: Gorgoroth initiates HEARTH CATACLYSM incinerating Frontline and Midline in 20 ticks! Break with Smite or Retreat to Backline!');
        } else {
          // Wind up Apex Intent: Molten Great-Cleaver (Execution 15 ticks later)
          final telegraphNodes = [
            const GridNode(column: 1, row: 0), // Front Col 2 (primary target)
            const GridNode(column: 2, row: 0), // Front Col 3 (lateral splash toward Col 3)
            const GridNode(column: 1, row: 1), // Mid Col 2 (deep shockwave)
          ];
          gorgoroth.pendingIntent = SpatialTelegraphIntent(
            id: 'cleave_intent_$currentTick',
            skillName: 'Molten Great-Cleaver',
            pattern: TargetPattern.tShapedCleave,
            originCol: 1,
            originRow: 0,
            targetNodes: telegraphNodes,
            triggerTick: currentTick + 15,
            totalWindupTicks: 15,
            rawDamage: 280,
          );
          lastBannerMessage = '⚠️ GORGOROTH WINDS UP: MOLTEN GREAT-CLEAVER!';
          addLog('TELEGRAPH: Gorgoroth prepares Molten Great-Cleaver striking Col 2 T-Cleave in 15 ticks!');
        }
      }

      // Check Intent Trigger for Gorgoroth Apex skills
      if (gorgoroth.pendingIntent != null && currentTick >= gorgoroth.pendingIntent!.triggerTick) {
        _resolveGorgorothIntent(gorgoroth, gorgoroth.pendingIntent!);
        gorgoroth.pendingIntent = null;
      }
    }

    // Check Intent Triggers for all enemy units (2-second / 60-tick telegraphed attacks)
    for (final enemy in enemyUnits.where((u) => u.isAlive && u.id != 'gorgoroth_boss')) {
      if (enemy.pendingIntent != null && currentTick >= enemy.pendingIntent!.triggerTick) {
        _resolveEnemyTelegraphedAttack(enemy, enemy.pendingIntent!);
        enemy.pendingIntent = null;
      }
    }

    // Resolve Ready Units crossing AP Threshold
    final readyUnits = allUnits.where((u) => u.currentAp >= tickThreshold).toList();
    // Sort by AP overflow then speed
    readyUnits.sort((a, b) {
      final apComp = b.currentAp.compareTo(a.currentAp);
      if (apComp != 0) return apComp;
      return b.speed.compareTo(a.speed);
    });

    for (final unit in readyUnits) {
      if (!unit.isAlive || unit.currentAp < tickThreshold) continue;
      unit.currentAp -= tickThreshold; // Consume turn
      _executeUnitTurn(unit);
    }

    notifyListeners();
  }

  void _resolveGorgorothIntent(CombatUnitState boss, SpatialTelegraphIntent intent) {
    addLog('${boss.name} releases ${intent.skillName} across ${intent.pattern.name} zone!');
    int hitCount = 0;
    CombatUnitState? primaryTarget;
    int totalDmg = 0;

    for (final node in intent.targetNodes) {
      final occupant = playerUnits.where((u) => u.isAlive && u.occupies(node.column, node.row)).firstOrNull;
      if (occupant != null) {
        final dmg = occupant.takeDamage(intent.rawDamage);
        totalDmg += dmg;
        primaryTarget ??= occupant;
        addLog('CRITICAL HIT: ${occupant.name} struck for $dmg DMG by ${intent.skillName}!');
        hitCount++;
      }
    }

    if (hitCount == 0) {
      addLog('CLANG! ${intent.skillName} crashed onto barren flagstone—MISS!');
      lastBannerMessage = '🛡️ DODGE! ${intent.skillName} struck empty tiles!';
    } else if (primaryTarget != null) {
      dispatchAction(SpatialActionEvent(
        id: 'intent_impact_$currentTick',
        attackerId: boss.id,
        attackerName: boss.name,
        skillName: intent.skillName,
        targetId: primaryTarget.id,
        targetName: primaryTarget.name,
        damage: totalDmg,
        isCrit: true,
        isPlayerAttacker: false,
        pattern: intent.pattern,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _resolveEnemyTelegraphedAttack(CombatUnitState enemy, SpatialTelegraphIntent intent) {
    addLog('${enemy.name} fires ${intent.skillName} across telegraphed grid nodes!');
    CombatUnitState? struckTarget;
    int appliedDmg = 0;

    for (final node in intent.targetNodes) {
      final occupant = playerUnits.where((u) => u.isAlive && u.occupies(node.column, node.row)).firstOrNull;
      if (occupant != null) {
        final dmg = occupant.takeDamage(intent.rawDamage);
        appliedDmg += dmg;
        struckTarget ??= occupant;

        if (enemy.id == 'cinder_witch') {
          occupant.burnDuration = max(occupant.burnDuration, 60); // 2s Burn
        }

        addLog('HIT: ${occupant.name} struck for $dmg DMG by ${intent.skillName} at (Col ${node.column + 1}, Row ${node.row})!');
        break; // Single column or target impact
      }
    }

    if (struckTarget == null) {
      addLog('MISS! ${intent.skillName} struck empty flagstones—allied unit dodged in time!');
      lastBannerMessage = '🛡️ DODGE! ${enemy.name}\'s ${intent.skillName} missed!';
    } else {
      dispatchAction(SpatialActionEvent(
        id: 'act_${currentTick}_${enemy.id}',
        attackerId: enemy.id,
        attackerName: enemy.name,
        skillName: intent.skillName,
        targetId: struckTarget.id,
        targetName: struckTarget.name,
        damage: appliedDmg,
        isPlayerAttacker: false,
        pattern: intent.pattern,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _executeUnitTurn(CombatUnitState unit) {
    if (unit.id == 'pyre_zealot') {
      // Pyre Zealot: Winds up 60-tick (2.0s) telegraphed piercing skewer down its column
      // Highlights target nodes with a red tinge, giving 2s to reposition (50% AP) or shield
      final zCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 4;
      final zRow = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.row : 2;
      final target = _resolveColumnTarget(unitCol: zCol, targetingPlayers: true);
      final targetNode = target?.occupiedNodes.firstOrNull ?? GridNode(column: zCol, row: 0);
      unit.pendingIntent = SpatialTelegraphIntent(
        id: 'skewer_${currentTick}_${unit.id}',
        skillName: 'Pyre Skewer',
        pattern: TargetPattern.piercingColumnSkewer,
        originCol: zCol,
        originRow: zRow,
        targetNodes: [
          GridNode(column: zCol, row: targetNode.row),
          if (targetNode.row != 0) GridNode(column: zCol, row: 0),
        ],
        triggerTick: currentTick + 60, // 2.0 seconds windup (60 ticks)
        totalWindupTicks: 60,
        rawDamage: unit.attack,
      );
      lastBannerMessage = '⚠️ PYRE ZEALOT WINDS UP: PYRE SKEWER (2.0s)!';
      addLog('${unit.name} begins 2s windup for Pyre Skewer targeting Col ${zCol + 1}!');
    } else if (unit.id == 'sanguine_blade') {
      // Sanguine Blade: Dynamically resolves target from her current column (cascading to adjacent columns if empty)
      final sbCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 3;
      final target = _resolveColumnTarget(unitCol: sbCol, targetingPlayers: false) ??
          _resolveColumnTarget(unitCol: 2, targetingPlayers: false);
      if (target != null) {
        // Flanking Momentum check: Triggered if moved this turn cycle OR target has active Bleed
        final bool isFlankingBonus = unit.hasStanceBonusReady || target.bleedStacks > 0;
        final int baseDmg = isFlankingBonus ? (unit.effectiveAttack * 1.4).round() : unit.effectiveAttack;
        final dmg = target.takeDamage(baseDmg, isPhysical: true);
        final int appliedBleed = isFlankingBonus ? 4 : 2;
        target.bleedStacks += appliedBleed;

        // Ultimate charge: +15% per basic action
        unit.ultimateGauge = min(100, unit.ultimateGauge + 15);

        if (isFlankingBonus) {
          // Refund 3,000 AP (initiating next attack cadence 30% faster)
          unit.currentAp = min(SpatialCombatEngine.tickThreshold, unit.currentAp + 3000);
          unit.hasStanceBonusReady = false;
          unit.movedSinceLastTurn = false;
          addLog('${unit.name} [FLANKING MOMENTUM] crits ${target.name} for $dmg DMG & 4 BLEED stacks! Refunds +3,000 AP!');
          lastBannerMessage = '⚡ FLANKING MOMENTUM: ${unit.name} dealt $dmg CRIT & refunded 3,000 AP!';
        } else {
          addLog('${unit.name} executes Flensing Thrust on ${target.name} for $dmg DMG & 2 BLEED stacks.');
        }

        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: isFlankingBonus ? 'Flanking Evisceration' : 'Flensing Thrust',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          bleedStacks: appliedBleed,
          isCrit: isFlankingBonus,
          isPlayerAttacker: true,
          pattern: TargetPattern.reachMidToFront,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'cinder_witch') {
      // Cinder Witch: Winds up 60-tick (2.0s) telegraphed Cinder Orb down her column
      final wCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 1;
      final wRow = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.row : 2;
      final target = _resolveColumnTarget(unitCol: wCol, targetingPlayers: true);
      final targetNode = target?.occupiedNodes.firstOrNull ?? GridNode(column: wCol, row: 0);
      unit.pendingIntent = SpatialTelegraphIntent(
        id: 'cinder_${currentTick}_${unit.id}',
        skillName: 'Cinder Orb',
        pattern: TargetPattern.singleTarget,
        originCol: wCol,
        originRow: wRow,
        targetNodes: [
          GridNode(column: wCol, row: targetNode.row),
        ],
        triggerTick: currentTick + 60, // 2.0 seconds windup (60 ticks)
        totalWindupTicks: 60,
        rawDamage: unit.attack,
      );
      lastBannerMessage = '⚠️ CINDER WITCH WINDS UP: CINDER ORB (2.0s)!';
      addLog('${unit.name} begins 2s windup for Cinder Orb targeting Col ${wCol + 1}!');
    } else if (unit.archetype == UnitArchetype.vanguardMelee) {
      _executeVanguardAction(unit);
    } else if (unit.archetype == UnitArchetype.backlineCaster) {
      _executeCasterAction(unit);
    } else if (unit.id == 'gorgoroth_boss') {
      // Regular attack if not channeling
      if (unit.pendingIntent == null) {
        final target = _resolveColumnTarget(unitCol: 1, targetingPlayers: true) ??
            _resolveColumnTarget(unitCol: 2, targetingPlayers: true);
        if (target != null) {
          final dmg = target.takeDamage(unit.attack);
          addLog('${unit.name} crushes ${target.name} for $dmg DMG.');
          dispatchAction(SpatialActionEvent(
            id: 'act_${currentTick}_${unit.id}',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Titanic Crush',
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isPlayerAttacker: false,
            pattern: TargetPattern.singleTarget,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    }
  }

  /// Adaptive Posture System: Resolves action based on Vanguard's current physical row depth
  void _executeVanguardAction(CombatUnitState unit) {
    final col = unit.occupiedNodes.first.column;
    switch (unit.currentDepth) {
      case RowDepth.front:
        // [ FRONT ROW ] ───► BRAWL STANCE (Default)
        // Stance Mastery: "Hold the Line" (Steadfast Anchor)
        // If unmoving for 2 consecutive cycles on Frontline:
        // -> Gains +30% Armor (PRR) & Stagger Immunity
        // -> Next strike becomes Earth-Shattering Bash (cleaves laterally across Row 0, resets 1,500 AP on targets)
        if (unit.movedSinceLastTurn) {
          unit.consecutiveTurnsStationary = 0;
          unit.hasStanceBonusReady = false;
          unit.movedSinceLastTurn = false;
        } else {
          unit.consecutiveTurnsStationary++;
          if (unit.consecutiveTurnsStationary >= 2) {
            unit.hasStanceBonusReady = true;
          }
        }

        final bool hasHoldTheLineBonus = unit.hasStanceBonusReady;
        final target = _resolveColumnTarget(unitCol: col, targetingPlayers: !unit.isPlayer);
        if (target != null) {
          final int baseDmg = hasHoldTheLineBonus ? (unit.effectiveAttack * 1.35).round() : unit.effectiveAttack;
          final dmg = target.takeDamage(baseDmg, isPhysical: true);
          final skillName = hasHoldTheLineBonus
              ? (unit.id == 'lady_valeria' ? 'Solar Sunder Cleave' : 'Earth-Shattering Bash')
              : (unit.id == 'lady_valeria' ? 'Sunbrand Slash' : 'Shield Bash');

          if (hasHoldTheLineBonus) {
            // Earth-Shattering Bash cleaves laterally and resets 1,500 AP on targets hit
            target.currentAp = max(0, target.currentAp - 1500);

            // Lateral cleave across adjacent enemies in Row 0
            final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;
            for (final neighbor in opposingSquad.where((u) => u.isAlive && u.id != target.id && u.occupiedNodes.any((n) => n.row == 0 && (n.column - col).abs() <= 1))) {
              final cleaveDmg = neighbor.takeDamage((baseDmg * 0.60).round(), isPhysical: true);
              neighbor.currentAp = max(0, neighbor.currentAp - 1500);
              addLog('  Lateral Cleave: ${neighbor.name} struck for $cleaveDmg DMG (-1,500 AP reset)!');
            }

            unit.hasStanceBonusReady = false; // Consumed
            addLog('${unit.name} [HOLD THE LINE] unleashes $skillName for $dmg DMG, resetting 1,500 AP!');
            lastBannerMessage = '🛡️ HOLD THE LINE: ${unit.name} unleashed $skillName cleaving frontline!';
          } else if (unit.id == 'iron_footman' && target.id != 'gorgoroth_boss') {
            target.stunDuration = 30; // 1s stun
            addLog('${unit.name} [BRAWL STANCE] bashes ${target.name} for $dmg DMG & STUNS for 1s!');
          } else {
            addLog('${unit.name} [BRAWL STANCE] strikes ${target.name} for $dmg DMG (100% Impact).');
          }

          // Basic attack grants +15% Ultimate gauge
          unit.ultimateGauge = min(100, unit.ultimateGauge + 15);

          dispatchAction(SpatialActionEvent(
            id: 'act_${currentTick}_${unit.id}',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: skillName,
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isCrit: hasHoldTheLineBonus,
            isPlayerAttacker: unit.isPlayer,
            pattern: hasHoldTheLineBonus ? TargetPattern.horizontalRowScythe : TargetPattern.singleTarget,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
        break;

      case RowDepth.mid:
        // [ MID ROW ] ───► ADVANCING / RECOVERY STRIDE
        // Reset Hold the Line stationary counter
        unit.consecutiveTurnsStationary = 0;
        unit.hasStanceBonusReady = false;

        // Shockwave / Tremor Slam: 60% Dmg + minor stagger / 15 armor chip down column.
        // If front tile in column is empty, unit automatically steps forward to reclaim the Frontline!
        final target = _resolveColumnTarget(unitCol: col, targetingPlayers: !unit.isPlayer);
        final shockwaveDmg = (unit.attack * 0.60).round();
        if (target != null) {
          final dmg = target.takeDamage(shockwaveDmg);
          // Apply 15 armor chip / stagger
          target.armor = max(0, target.armor - 15);
          unit.ultimateGauge = min(100, unit.ultimateGauge + 15);
          addLog('${unit.name} [ADVANCING STRIDE] slams ground with Shockwave Tremor for $dmg DMG (60%) & chips 15 Armor from ${target.name}!');
          dispatchAction(SpatialActionEvent(
            id: 'act_${currentTick}_${unit.id}',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Shockwave Tremor',
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isPlayerAttacker: unit.isPlayer,
            pattern: TargetPattern.piercingColumnSkewer,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }

        // Automated Advancing Step: Reclaim Frontline (row 0) if vacant
        final squad = unit.isPlayer ? playerUnits : enemyUnits;
        final isFrontOccupied = squad.any((u) => u.isAlive && u.occupies(col, 0));
        if (!isFrontOccupied) {
          unit.occupiedNodes.clear();
          unit.occupiedNodes.add(GridNode(column: col, row: 0, occupantUnitId: unit.id));
          addLog('${unit.name} advances stride forward into the Frontline (Col ${col + 1}, Row 0)!');
          lastBannerMessage = '⚔️ RECLAIMED FRONTLINE: ${unit.name} stepped up to Row 0!';
        }
        break;

      case RowDepth.back:
        // [ BACK ROW ] ───► OUT OF FORMATION (Braced Bulwark)
        unit.consecutiveTurnsStationary = 0;
        unit.hasStanceBonusReady = false;

        // 0 kinetic damage dealt to enemy.
        // Slams shield into ground: grants temporary +25 Armor & +30 Aegis Shield to allied units
        // ahead of it in that column (Row 0 & 1).
        // Fills +20% Ultimate gauge.
        final squad = unit.isPlayer ? playerUnits : enemyUnits;
        final alliesAhead = squad.where((u) => u.isAlive && u.id != unit.id && u.occupiedNodes.any((n) => n.column == col && n.row < 2)).toList();
        for (final ally in alliesAhead) {
          ally.armor = min(ally.maxArmor + 35, ally.armor + 25);
          ally.aegisShield += 30;
          addLog('${unit.name} [BRACED BULWARK] shields ${ally.name} ahead (+25 Armor, +30 Aegis)!');
        }
        unit.ultimateGauge = min(100, unit.ultimateGauge + 20);
        addLog('${unit.name} [BRACED BULWARK] braces defense! (+20% Ultimate: ${unit.ultimateGauge}%)');
        lastBannerMessage = '🛡️ BRACED BULWARK: ${unit.name} granted +25 Armor & +30 Aegis to column allies!';
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Braced Bulwark',
          targetId: alliesAhead.isNotEmpty ? alliesAhead.first.id : unit.id,
          targetName: alliesAhead.isNotEmpty ? alliesAhead.first.name : unit.name,
          damage: 0,
          isPlayerAttacker: unit.isPlayer,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
        break;
    }
  }

  /// Adaptive Posture System: Resolves action for Backline Casters
  void _executeCasterAction(CombatUnitState unit) {
    if (unit.currentDepth == RowDepth.front) {
      // Point-Blank Vulnerability:
      // Basic spell becomes Panic Discharge: radial blast with high knockback pushing enemy Vanguard back
      final enemySquad = unit.isPlayer ? enemyUnits : playerUnits;
      final frontEnemies = enemySquad.where((u) => u.isAlive && u.occupies(unit.occupiedNodes.first.column, 0)).toList();
      final target = frontEnemies.firstOrNull ?? _resolveColumnTarget(unitCol: unit.occupiedNodes.first.column, targetingPlayers: !unit.isPlayer);
      if (target != null) {
        final dmg = (unit.effectiveAttack * 1.1).round();
        target.takeDamage(dmg, isPhysical: false);
        unit.ultimateGauge = min(100, unit.ultimateGauge + 15);
        // Push target back 1 row if target is displaceable and space is open
        if (!target.isDisplacementImmune && target.occupiedNodes.isNotEmpty) {
          final tCol = target.occupiedNodes.first.column;
          final tRow = target.occupiedNodes.first.row;
          if (tRow < 2 && !enemySquad.any((u) => u.isAlive && u.occupies(tCol, tRow + 1))) {
            target.occupiedNodes.clear();
            target.occupiedNodes.add(GridNode(column: tCol, row: tRow + 1, occupantUnitId: target.id));
            addLog('${unit.name} [PANIC DISCHARGE] knocks ${target.name} back to Row ${tRow + 1}!');
          }
        }
        addLog('${unit.name} [PANIC DISCHARGE] point-blank detonation blasts ${target.name} for $dmg DMG!');
        lastBannerMessage = '💥 PANIC DISCHARGE: ${unit.name} blasted enemy away!';
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Panic Discharge',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: unit.isPlayer,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else {
      // Midline / Backline
      // Stance Mastery: "Aetheric Alignment" (Spell Weave)
      // When casting from Backline (Row 2):
      // -> Strike pierces straight down column (Row 0, 1, 2)
      // -> Generates +1 Global Focus for Gauntlet reservoir
      final bool isAethericBonus = unit.currentDepth == RowDepth.back;
      final targetCol = unit.occupiedNodes.first.column;
      final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;

      if (isAethericBonus) {
        // Piercing strike hitting entire column
        int hitCount = 0;
        for (int r = 0; r <= 2; r++) {
          final occupant = opposingSquad.where((u) => u.isAlive && u.occupies(targetCol, r)).firstOrNull;
          if (occupant != null) {
            final dmg = occupant.takeDamage(unit.effectiveAttack, isPhysical: false);
            hitCount++;
            addLog('${unit.name} [AETHERIC ALIGNMENT] beam pierces ${occupant.name} for $dmg DMG (Hit #$hitCount)!');
          }
        }

        // Generate +1 Global Focus
        if (unit.isPlayer && focus < maxFocus) {
          focus = min(maxFocus, focus + 1);
          addLog('${unit.name} [AETHERIC ALIGNMENT] weaves aetheric resonance: +1 Global Focus (Pool: $focus)!');
        }

        unit.ultimateGauge = min(100, unit.ultimateGauge + 20);
        lastBannerMessage = '✨ AETHERIC ALIGNMENT: ${unit.name} column beam pierced enemies & granted +1 Focus!';

        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Aetheric Piercing Beam',
          targetId: opposingSquad.first.id,
          targetName: opposingSquad.first.name,
          damage: unit.attack,
          isPlayerAttacker: unit.isPlayer,
          pattern: TargetPattern.piercingColumnSkewer,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        final target = opposingSquad.where((u) => u.isAlive).firstOrNull;
        if (target != null) {
          final dmg = target.takeDamage(unit.attack);
          unit.ultimateGauge = min(100, unit.ultimateGauge + 15);
          addLog('${unit.name} fires Sun-Bolts at ${target.name} for $dmg DMG.');
          dispatchAction(SpatialActionEvent(
            id: 'act_${currentTick}_${unit.id}',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Sun-Bolt Volley',
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isPlayerAttacker: unit.isPlayer,
            pattern: TargetPattern.singleTarget,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    }
  }

  /// Geometric Column & Row Penetration Targeting:
  /// Checks Front (row:0) -> Mid (row:1) -> Back (row:2)
  CombatUnitState? _resolveColumnTarget({required int unitCol, required bool targetingPlayers}) {
    final squad = targetingPlayers ? playerUnits : enemyUnits;
    for (int r = 0; r <= 2; r++) {
      final occupant = squad.where((u) => u.isAlive && u.occupies(unitCol, r)).firstOrNull;
      if (occupant != null) return occupant;
    }
    // Adjacency Fallback
    for (int dist = 1; dist <= 4; dist++) {
      for (final col in [unitCol - dist, unitCol + dist]) {
        if (col >= 0 && col <= 4) {
          for (int r = 0; r <= 2; r++) {
            final occupant = squad.where((u) => u.isAlive && u.occupies(col, r)).firstOrNull;
            if (occupant != null) return occupant;
          }
        }
      }
    }
    return squad.where((u) => u.isAlive).firstOrNull;
  }

  /// Resolves the enemy target that a unit would strike with its basic action.
  /// Accepts an optional [simulatedCol] to test trajectories during dragging or planning.
  CombatUnitState? resolveProjectedTarget(CombatUnitState unit, {int? simulatedCol}) {
    if (unit.occupiedNodes.isEmpty && simulatedCol == null) return null;
    final col = simulatedCol ?? unit.occupiedNodes.first.column;
    return _resolveColumnTarget(unitCol: col, targetingPlayers: !unit.isPlayer);
  }

  /// Resolves secondary targets hit by a unit's basic action (lateral cleave or column piercing).
  List<CombatUnitState> resolveSecondaryProjectedTargets(
    CombatUnitState unit, {
    int? simulatedCol,
    int? simulatedRow,
  }) {
    if (unit.occupiedNodes.isEmpty && simulatedCol == null) return const [];
    final col = simulatedCol ?? unit.occupiedNodes.first.column;
    final row = simulatedRow ?? unit.occupiedNodes.first.row;
    final primary = resolveProjectedTarget(unit, simulatedCol: col);
    if (primary == null) return const [];

    final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;
    final List<CombatUnitState> secondaries = [];

    // 1. Arcanum / Mage in Backline ("Aetheric Alignment"): Pierces entire column
    if (unit.id == 'sun_smith' && row == 2) {
      for (final enemy in opposingSquad.where((u) => u.isAlive && u.id != primary.id)) {
        if (enemy.occupiedNodes.any((n) => n.column == col)) {
          secondaries.add(enemy);
        }
      }
    }

    // 2. Vanguard in Frontline with "Hold the Line" ready: Lateral cleave across adjacent Frontline tiles
    if (unit.archetype == UnitArchetype.vanguardMelee &&
        row == 0 &&
        (unit.hasStanceBonusReady || unit.consecutiveTurnsStationary >= 1)) {
      for (final enemy in opposingSquad.where((u) => u.isAlive && u.id != primary.id)) {
        if (enemy.occupiedNodes.any((n) => n.row == 0 && (n.column - col).abs() <= 1)) {
          secondaries.add(enemy);
        }
      }
    }

    return secondaries;
  }

  /// Starts the combat encounter, transitioning from Pre-Battle Deployment to Live 30Hz Simulation
  void startBattle() {
    isPreBattlePhase = false;
    isRunning = true;
    lastBannerMessage = '⚔️ THE SUNDER INITIATED! ENGAGE THE FOE!';
    addLog('DEPLOYMENT CONCLUDED: Battle engaged at 30 Hz discrete simulation speed.');
    notifyListeners();
  }

  /// Tactical Plinth Triage: Player shifts or swaps unit across nodes
  /// In Pre-Battle Deployment Phase: 0 AP cost & anywhere on player grid (Rows 0-2, Cols 0-4), supports swapping
  /// In Live Combat: 50% AP cost & restricted to unit moveRange, supports adjacent formation swaps
  bool movePlayerUnit(String unitId, int targetCol, int targetRow) {
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null) return false;
    if (unit.occupies(targetCol, targetRow)) return false;
    if (unit.isDisplacementImmune) {
      addLog('${unit.name} has Mass Tenacity and cannot be shifted!');
      return false;
    }

    if (!isPreBattlePhase) {
      // Check if unit has at least 50% AP (5,000 AP)
      if (!unit.canAffordMovement) {
        final currentApPct = (unit.currentAp / SpatialCombatEngine.tickThreshold * 100).round();
        lastBannerMessage = '⚠️ INSUFFICIENT AP: Moving costs 50% AP (${unit.name} has $currentApPct%)';
        addLog('${unit.name} cannot move! Needs at least 50% AP (has $currentApPct%).');
        return false;
      }

      // Restrict movement to unit's moveRange (e.g. 1 tile adjacent/diagonal)
      if (!unit.canMoveTo(targetCol, targetRow)) {
        addLog('${unit.name} cannot reach (Col ${targetCol + 1}, Row $targetRow)! Movement limit is ${unit.moveRange} tile(s).');
        return false;
      }
    }

    final oldCol = unit.occupiedNodes.first.column;
    final oldRow = unit.occupiedNodes.first.row;
    final apCost = isPreBattlePhase ? 0 : CombatUnitState.moveApCost;

    // Check if target node is occupied by another friendly unit -> Tactical Formation Swap!
    final existingOccupant = playerUnits
        .where((u) => u.isAlive && u.id != unit.id && u.occupies(targetCol, targetRow))
        .firstOrNull;
    if (existingOccupant != null) {
      if (existingOccupant.isDisplacementImmune) {
        addLog('${existingOccupant.name} has Mass Tenacity and cannot be swapped!');
        return false;
      }
      existingOccupant.repositionTo(
        [GridNode(column: oldCol, row: oldRow, occupantUnitId: existingOccupant.id)],
        apPenalty: 0,
      );
      unit.repositionTo(
        [GridNode(column: targetCol, row: targetRow, occupantUnitId: unit.id)],
        apPenalty: apCost,
      );
      final costStr = isPreBattlePhase ? '[Pre-Battle Swap]' : '[-5,000 AP / -50% Swap]';
      lastBannerMessage = '⇄ FORMATION SWAP: ${unit.name} exchanged positions with ${existingOccupant.name} $costStr';
      addLog('FORMATION SWAP: ${unit.name} and ${existingOccupant.name} swapped tiles $costStr.');
      notifyListeners();
      return true;
    }

    // Do not allow walking onto a downed inert plinth unless revived
    final downedOccupant = playerUnits.where((u) => u.isDowned && u.occupies(targetCol, targetRow)).firstOrNull;
    if (downedOccupant != null) {
      addLog('${downedOccupant.name} lies as an Inert Vessel on this tile. Cast Infused Vitae Resurgence to revive!');
      lastBannerMessage = '🪨 INERT VESSEL: Tile is occupied by downed ${downedOccupant.name}!';
      return false;
    }

    final success = unit.repositionTo([GridNode(column: targetCol, row: targetRow, occupantUnitId: unit.id)], apPenalty: apCost);
    if (success) {
      if (unit.id == 'lady_valeria' && oldRow != targetRow) {
        lastBannerMessage = targetRow == 0
            ? '🛡️ COMMANDER STANCE: BASTION OF COLD IRON (Frontline Allies +25 Armor)'
            : '✨ COMMANDER STANCE: AEGIS REARGUARD (Rearguard Wards Activated)';
        addLog('STANCE TRANSITION: Lady Valeria assumed $valeriaStance!');
      } else {
        final costStr = isPreBattlePhase ? '[Pre-Battle Free Placement]' : '[-5,000 AP / -50%]';
        addLog('${unit.name} shifted from (Col ${oldCol + 1}, Row $oldRow) to (Col ${targetCol + 1}, Row $targetRow) $costStr.');
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Burn Pit Cycling: Exhaust card for 0 Focus, refund +1 Focus, and draw next card
  bool burnCard(String cardId) {
    final cardIndex = hand.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) return false;
    final card = hand.removeAt(cardIndex);
    burnPit.add(card);

    // Dynamic Ash Pyre Rebate: +1 Focus
    focus = min(maxFocus, focus + 1);

    // Draw card if deck has cards
    if (drawPile.isNotEmpty) {
      final drawn = drawPile.removeAt(0);
      hand.add(drawn);
      addLog('BURN PIT: Exhausted ${card.name} for +1 Focus (Pool: $focus). Drew ${drawn.name}!');
    } else {
      addLog('BURN PIT: Exhausted ${card.name} for +1 Focus (Pool: $focus). Draw pile empty.');
    }
    notifyListeners();
    return true;
  }

  /// Casts a tactical card on a target node / unit
  bool castCard(String cardId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) {
    final card = hand.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return false;
    if (focus < card.focusCost) {
      addLog('Not enough Focus! Requires ${card.focusCost}, have $focus.');
      return false;
    }

    focus -= card.focusCost;
    hand.remove(card);

    if (card.id == 'smite_the_calcified') {
      final boss = targetUnit ?? enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;
      if (boss != null) {
        final rawDmg = (74 * 2.5).round(); // 185 damage
        final dmg = boss.takeDamage(rawDmg);
        addLog('SMITE CAST: Dealt $dmg kinetic damage to ${boss.name}!');

        // Slag Carapace Shatter condition
        if (boss.isSlagCarapaceActive) {
          boss.isSlagCarapaceActive = false;
          boss.sunderArmor(0.50); // Sunder armor by 50%
          boss.pendingIntent = null; // Staggers channel
          lastBannerMessage = '⚡ SLAG CARAPACE SHATTERED! ⚡';
          addLog('RESULT: Slag Carapace SHATTERS! Armor halved to ${boss.armor}. Channeled intent interrupted!');
        } else {
          lastBannerMessage = '⚡ SMITE THE CALCIFIED DEALS $dmg DMG!';
        }

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_smite',
          attackerId: 'player_valeria',
          attackerName: 'VALERIA',
          skillName: 'Smite the Calcified',
          targetId: boss.id,
          targetName: boss.name,
          damage: dmg,
          isCrit: true,
          isPlayerAttacker: true,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'phalanx_intercept') {
      final recipient = targetUnit ?? playerUnits.where((u) => u.isAlive && u.id == 'lady_valeria').firstOrNull ??
          playerUnits.where((u) => u.isAlive).first;
      recipient.armor += 35;
      recipient.aegisShield += 50; // Aegis Barrier absorbs 50 damage
      lastBannerMessage = '🛡️ PHALANX INTERCEPT: +35 Armor & +50 Aegis Shield to ${recipient.name}!';
      addLog('CAST: Phalanx Intercept fortified ${recipient.name} (+35 Armor, +50 Aegis Shield)!');

      dispatchAction(SpatialActionEvent(
        id: 'card_${currentTick}_phalanx',
        attackerId: 'player_valeria',
        attackerName: 'VALERIA',
        skillName: 'Phalanx Intercept',
        targetId: recipient.id,
        targetName: recipient.name,
        damage: 0,
        isHeal: true,
        isPlayerAttacker: true,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    } else if (card.id == 'searing_brand') {
      final target = targetUnit ?? enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;
      if (target != null) {
        final dmg = target.takeDamage(105);
        lastBannerMessage = '🔥 SEARING BRAND: Radiant strike ignites ${target.name} for $dmg DMG!';
        addLog('CAST: Searing Brand struck ${target.name} for $dmg Holy damage.');

        // Splash on other alive enemies
        for (final other in enemyUnits.where((u) => u.isAlive && u.id != target.id)) {
          final splash = other.takeDamage(45);
          addLog('  Splash: ${other.name} took $splash Holy damage.');
        }

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_searing',
          attackerId: 'sun_smith',
          attackerName: 'SUN-SMITH',
          skillName: 'Searing Brand',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: true,
          pattern: TargetPattern.stAshlarCross,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'stoke_the_embers') {
      focus = min(maxFocus, focus + 2);
      String drawMsg = '';
      if (drawPile.isNotEmpty) {
        final drawn = drawPile.removeAt(0);
        hand.add(drawn);
        drawMsg = ' & drew ${drawn.name}';
      }
      lastBannerMessage = '✨ STOKE THE EMBERS: +2 Focus generated$drawMsg!';
      addLog('CAST: Stoke the Embers restored 2 Focus$drawMsg.');

      final recipient = playerUnits.where((u) => u.isAlive).first;
      dispatchAction(SpatialActionEvent(
        id: 'card_${currentTick}_stoke',
        attackerId: 'sun_smith',
        attackerName: 'SUN-SMITH',
        skillName: 'Stoke the Embers',
        targetId: recipient.id,
        targetName: recipient.name,
        damage: 0,
        isHeal: true,
        isPlayerAttacker: true,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    } else if (card.id == 'sun_ashlar_wrath') {
      int totalDmg = 0;
      for (final enemy in enemyUnits.where((u) => u.isAlive)) {
        final dmg = enemy.takeDamage(110);
        totalDmg += dmg;
        addLog('RADIANT BURST: ${enemy.name} took $dmg Holy damage.');
      }
      final boss = enemyUnits.where((u) => u.isAlive).firstOrNull;
      lastBannerMessage = '☀️ WRATH OF ASHLAR: Radiant Cross strikes all enemies for $totalDmg total DMG!';
      if (boss != null) {
        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_wrath',
          attackerId: 'sun_smith',
          attackerName: 'SUN-SMITH',
          skillName: 'Wrath of Ashlar',
          targetId: boss.id,
          targetName: boss.name,
          damage: 110,
          isCrit: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.stAshlarCross,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'sun_king_cataclysm') {
      // APEX RITE: Pierces through chosen enemy column (or boss) for 260 Holy Damage & interrupts any active telegraph!
      final target = targetUnit ??
          enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;

      if (target != null) {
        final dmg = target.takeDamage(260);
        // Cleanse/Interrupt Boss Intent
        if (target.pendingIntent != null) {
          final interruptedSkill = target.pendingIntent!.skillName;
          target.pendingIntent = null;
          addLog('APEX DISRUPTION: ${target.name} channel ($interruptedSkill) DISPELLED by Sun-King Cataclysm!');
          lastBannerMessage = '☀️ APEX DISRUPTION: $interruptedSkill INTERRUPTED!';
        } else {
          lastBannerMessage = '☀️ APEX RITE: CATACLYSM OF THE SUN-KING DEALS $dmg DMG!';
        }
        addLog('APEX RITE: Cataclysm of the Sun-King incinerated ${target.name} for $dmg Holy damage!');

        // Splash on other alive enemies in adjacent columns
        for (final other in enemyUnits.where((u) => u.isAlive && u.id != target.id)) {
          final splash = other.takeDamage(85);
          addLog('  Solar Fallout: ${other.name} took $splash collateral Holy damage.');
        }

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_apex_cataclysm',
          attackerId: 'lady_valeria',
          attackerName: 'VALERIA',
          skillName: 'Cataclysm of the Sun-King',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isCrit: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.piercingColumnSkewer,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'revive_vitae') {
      // SOVEREIGN SLIP: Resurrects downed unit (GDD §3.6 / §4.4)
      // 1. Scales from Caster Attack (Sun-Smith = 88) + Generation bonus (G1 = +15%)
      // 2. Incurs stacking -20% Max HP penalty (Soul Fracture) based on baseline Max HP
      // 3. Overflow vitality converts into an Aegis Shield Ring (50% of excess)
      // 4. Awakening State: 6-tick (0.2s) invulnerability window, cleansed debuffs, and AP reset to 0
      final downedTarget = targetUnit ?? playerUnits.where((u) => u.isDowned).firstOrNull;
      if (downedTarget != null) {
        downedTarget.reviveCount++;
        final int baselineMax = downedTarget.baseMaxHp ?? downedTarget.maxHp;
        final double soulFracturePenalty = (1.0 - (downedTarget.reviveCount * 0.20)).clamp(0.20, 1.0);
        downedTarget.maxHp = max(50, (baselineMax * soulFracturePenalty).round());

        // Revived vitality: (Caster ATK 88 * 2.2) * (1 + 1 * 0.15) ≈ 193.6 * 1.15 ≈ 222 HP
        const int casterAtk = 88;
        const double skillCoeff = 2.2;
        const int casterGen = 1;
        final int targetVitality = (casterAtk * skillCoeff * (1 + casterGen * 0.15)).round();

        int restoredHp = targetVitality;
        int overflowAegis = 0;
        if (restoredHp > downedTarget.maxHp) {
          final excess = restoredHp - downedTarget.maxHp;
          overflowAegis = (excess * 0.50).round();
          restoredHp = downedTarget.maxHp;
        }

        downedTarget.hp = max(1, restoredHp);
        downedTarget.currentAp = 0;
        downedTarget.bleedStacks = 0;
        downedTarget.burnDuration = 0;
        downedTarget.stunDuration = 0;
        downedTarget.invulnerabilityTicks = 6; // 6-tick (0.2s) invulnerability window per GDD §3.6
        downedTarget.aegisShield = 40 + overflowAegis; // Base 40 + 50% overflow vitality

        lastBannerMessage = '✨ RESURGENCE: ${downedTarget.name} REAWAKENED (${downedTarget.hp}/${downedTarget.maxHp} HP + ${downedTarget.aegisShield} Aegis)!';
        addLog('REVIVE CAST: ${downedTarget.name} awakened with ${downedTarget.hp} HP & ${downedTarget.aegisShield} Aegis! Gained 6-tick invulnerability. Soul Fracture #${downedTarget.reviveCount} applied (-20% max HP).');

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_revive',
          attackerId: 'vital_wellspring',
          attackerName: 'INFUSED VITAE',
          skillName: 'Infused Vitae Resurgence',
          targetId: downedTarget.id,
          targetName: downedTarget.name,
          damage: 0,
          isHeal: true,
          isPlayerAttacker: true,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        // Fallback: If no unit is downed, grant a major +120 HP heal and +40 Shield to the lowest HP ally
        final lowestAlly = playerUnits.where((u) => u.isAlive).toList()..sort((a, b) => a.hp.compareTo(b.hp));
        if (lowestAlly.isNotEmpty) {
          final target = lowestAlly.first;
          target.hp = min(target.maxHp, target.hp + 120);
          target.aegisShield += 40;
          lastBannerMessage = '✨ INFUSED VITAE: +120 HP & +40 Shield to ${target.name}!';
          addLog('CAST: Infused Vitae invigorated ${target.name} (+120 HP, +40 Shield).');
          dispatchAction(SpatialActionEvent(
            id: 'card_${currentTick}_vital_mend',
            attackerId: 'vital_wellspring',
            attackerName: 'INFUSED VITAE',
            skillName: 'Vital Mend',
            targetId: target.id,
            targetName: target.name,
            damage: 0,
            isHeal: true,
            isPlayerAttacker: true,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    }

    notifyListeners();
    return true;
  }

  /// Ultimate Burst Resolution: Player manually drags charged unit mini-slate onto grid target
  bool castUltimate(String unitId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) {
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null || !unit.isUltimateReady) {
      addLog('${unit?.name ?? "Unit"} Ultimate is not fully charged!');
      return false;
    }

    unit.ultimateGauge = 0; // Consume meter

    switch (unit.id) {
      case 'lady_valeria':
        // Wrath of the Dawnbound: Solar pillar crashes down for 240 Radiant DMG,
        // shatters Slag Carapace, and fortifies Frontline allies with +30 Armor
        final col = targetCol ?? targetUnit?.occupiedNodes.firstOrNull?.column ?? 1;
        int totalHits = 0;
        for (int r = 0; r <= 2; r++) {
          final enemy = enemyUnits.where((u) => u.isAlive && u.occupies(col, r)).firstOrNull;
          if (enemy != null) {
            enemy.isSlagCarapaceActive = false; // Shatter
            final dmg = enemy.takeDamage(240);
            totalHits++;
            addLog('WRATH OF DAWNBOUND: Solar pillar smote ${enemy.name} for $dmg Radiant DMG (Carapace Shattered)!');
          }
        }
        for (final ally in playerUnits.where((u) => u.isAlive && u.occupiedNodes.any((n) => n.row == 0))) {
          ally.armor = min(ally.maxArmor + 40, ally.armor + 30);
          addLog('  Dawnbound Ward: Fortified ${ally.name} with +30 Armor ($totalHits enemies smitten)!');
        }
        lastBannerMessage = '☀️ WRATH OF THE DAWNBOUND: Solar Pillar incinerated Col ${col + 1} & granted Frontline +30 Armor!';
        dispatchAction(SpatialActionEvent(
          id: 'ult_${currentTick}_valeria',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Wrath of the Dawnbound',
          targetId: enemyUnits.first.id,
          targetName: enemyUnits.first.name,
          damage: 240,
          isCrit: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.piercingColumnSkewer,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
        break;

      case 'iron_footman':
        // Unbreakable Phalanx: Slams tower shield into earth, granting +60 Aegis Barrier
        // to all allies in Row 0 for 4s
        final alliesInRow = playerUnits.where((u) => u.isAlive && u.occupiedNodes.any((n) => n.row == 0)).toList();
        for (final ally in alliesInRow) {
          ally.aegisShield += 60;
          ally.armor = min(ally.maxArmor + 30, ally.armor + 25);
          addLog('UNBREAKABLE PHALANX: ${ally.name} warded with +60 Aegis Barrier & +25 Armor!');
        }
        lastBannerMessage = '🛡️ UNBREAKABLE PHALANX: Iron Footman warded Frontline with +60 Aegis Barrier!';
        dispatchAction(SpatialActionEvent(
          id: 'ult_${currentTick}_footman',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Unbreakable Phalanx',
          targetId: alliesInRow.isNotEmpty ? alliesInRow.first.id : unit.id,
          targetName: alliesInRow.isNotEmpty ? alliesInRow.first.name : unit.name,
          damage: 0,
          isHeal: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.horizontalRowScythe,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
        break;

      case 'sanguine_blade':
        // Crimson Evisceration: Strikes target for 280 DMG + detonates all Bleed stacks
        final target = targetUnit ??
            enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
            enemyUnits.where((u) => u.isAlive).firstOrNull;
        if (target != null) {
          final int bonusBleedDmg = target.bleedStacks * 35;
          final int totalRawDmg = 280 + bonusBleedDmg;
          final dmg = target.takeDamage(totalRawDmg);
          final oldBleed = target.bleedStacks;
          target.bleedStacks = 0; // Detonated
          addLog('CRIMSON EVISCERATION: Sanguine Blade detonated $oldBleed Bleed stacks on ${target.name} for $dmg Total DMG!');
          lastBannerMessage = '🩸 CRIMSON EVISCERATION: $dmg DMG ($oldBleed Bleed Stacks Detonated)!';
          dispatchAction(SpatialActionEvent(
            id: 'ult_${currentTick}_sanguine',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Crimson Evisceration',
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isCrit: true,
            isPlayerAttacker: true,
            pattern: TargetPattern.singleTarget,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
        break;

      case 'sun_smith':
        // Solar Crucible Ignition: Calls down an alchemical solar beam dealing 180 Fire DMG
        // and igniting enemies with 90-tick (3s) Burn
        final target = targetUnit ??
            enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
            enemyUnits.where((u) => u.isAlive).firstOrNull;
        if (target != null) {
          final dmg = target.takeDamage(180);
          target.burnDuration = max(target.burnDuration, 90);
          addLog('SOLAR CRUCIBLE: Incinerated ${target.name} for $dmg DMG & 3s Burn hazard!');
          for (final splash in enemyUnits.where((u) => u.isAlive && u.id != target.id)) {
            final sDmg = splash.takeDamage(80);
            splash.burnDuration = max(splash.burnDuration, 90);
            addLog('  Crucible Ignition: ${splash.name} suffered $sDmg Burn damage.');
          }
          lastBannerMessage = '🔥 SOLAR CRUCIBLE IGNITION: Incinerated enemies for $dmg DMG & 3s Hazard!';
          dispatchAction(SpatialActionEvent(
            id: 'ult_${currentTick}_sunsmith',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Solar Crucible Ignition',
            targetId: target.id,
            targetName: target.name,
            damage: dmg,
            isCrit: true,
            isPlayerAttacker: true,
            pattern: TargetPattern.stAshlarCross,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
        break;
    }

    notifyListeners();
    return true;
  }
}
