import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/spatial_combat_models.dart';
import '../../shared/models/unit_entity.dart';
import '../../core/combat_math.dart';
import '../relics/relic_service.dart';
import '../generals/general_command_service.dart';

/// Deterministic 30 Hz Spatial Combat Engine simulating the 3-Row x 5-Col Grid Plane
class SpatialCombatEngine extends ChangeNotifier {
  static const int tickThreshold = 10000;
  static const int ticksPerSecond = 30;

  final List<CombatUnitState> playerUnits = [];
  final List<CombatUnitState> enemyUnits = [];

  // Multi-Wave Encounter State
  final List<List<UnitEntity>> _allEnemyWaves = [];
  int currentWaveIndex = 1;
  int totalWaves = 1;
  bool isBossEncounterFlag = false;

  // Active Commander & Grimoire Service
  GeneralCommandService? commandService;

  // Commander Focus Economy (Rank & Rite Spec Sec 6: Sculptor Tray / Shared Team Vitae pool max 7)
  int focus = 3;
  int maxFocus = 7;
  int get teamVitae => focus;
  set teamVitae(int val) => focus = val.clamp(0, maxFocus);

  /// Rank & Rite Spec Sec 2 & Sec 6: Active Unit awaiting turn execution during pause
  CombatUnitState? activeActingUnit;
  bool isTurnExecutionPaused = false;
  bool hasCastTuningSlipThisTurn = false;

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

  bool get isVictory =>
      currentWaveIndex >= totalWaves &&
      enemyUnits.isNotEmpty &&
      enemyUnits.every((u) => !u.isAlive);
  bool get isDefeat => playerUnits.isNotEmpty && playerUnits.every((u) => !u.isAlive);

  /// Active Commander Aura Summary for HUD display
  String get activeCommanderAuraLabel {
    final gen = commandService?.activeGeneralType;
    if (gen == null) return valeriaStance;
    switch (gen) {
      case GeneralType.vladislav:
        return 'Crimson Tithe (+10% Vampiric Siphon vs Wounded)';
      case GeneralType.valeria:
        return 'Iron Aegis (+25% Frontline Armor)';
      case GeneralType.malakor:
        return 'Carrion Miasma (Blight Detonation on Death)';
      case GeneralType.morrigan:
        return 'Temporal Threads (+10% Squad Speed)';
    }
  }

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
  // Combat Statistics & Performance Tracking
  final Map<String, int> unitDamageDealt = {};
  final Map<String, int> unitDamageTaken = {};
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;
  int totalHealingDone = 0;
  int bleedDetonationsCount = 0;

  SpatialCombatEngine({
    List<UnitEntity>? initialPlayerEntities,
    List<UnitEntity>? initialEnemyEntities,
    List<List<UnitEntity>>? enemyWaves,
    String? title,
    String? description,
    bool isBossEncounter = false,
    RelicService? relicService,
    this.commandService,
  })  : encounterTitle = title ?? 'The Sunder at Ashen Gate',
        encounterDescription = description ?? 'Encounter 4: Tabletop Colossus Battle' {
    final waves = (enemyWaves != null && enemyWaves.isNotEmpty)
        ? enemyWaves
        : (initialEnemyEntities != null && initialEnemyEntities.isNotEmpty ? [initialEnemyEntities] : null);
    if (waves != null && waves.isNotEmpty) {
      setupCampaignEncounter(
        playerEntities: initialPlayerEntities,
        enemyEntities: waves.first,
        enemyWaves: waves,
        isBoss: isBossEncounter,
        title: title,
        description: description,
        relicService: relicService,
        activeCommandService: commandService,
      );
    } else {
      setupSunderAtAshenGate();
    }
  }

  /// Maps a GeneralOrderDefinition from the active Commander's Grimoire into a SpatialCombatCard
  static SpatialCombatCard mapGeneralOrderToSpatialCard(GeneralOrderDefinition order) {
    TargetPattern pattern = TargetPattern.singleTarget;
    double dmgMult = 1.4;
    int armorShred = 0;
    int bleed = 0;

    switch (order.id) {
      case 'feast_of_ruin':
      case 'retributive_stride':
      case 'corpse_burst':
      case 'virulent_cascade':
      case 'disrupting_cleave':
      case 'blood_boil':
        pattern = TargetPattern.horizontalRowScythe;
        dmgMult = 1.6;
        break;
      case 'smite_the_wicked':
        pattern = TargetPattern.piercingColumnSkewer;
        dmgMult = 2.4;
        armorShred = 40;
        break;
      case 'siphon_vitality':
      case 'rend_flesh':
      case 'exsanguinating_strike':
        pattern = TargetPattern.singleTarget;
        dmgMult = 1.5;
        bleed = 3;
        break;
      case 'sanguine_ward':
      case 'stand_resolute':
      case 'rebind_flesh':
      case 'quicken':
      case 'echoing_hourglass':
      case 'iron_bulwark':
      case 'sanguine_revival':
        pattern = TargetPattern.singleTarget;
        dmgMult = 1.0;
        break;
      case 'unravel_hex':
        pattern = TargetPattern.stAshlarCross;
        dmgMult = 1.5;
        armorShred = 30;
        break;
    }

    return SpatialCombatCard(
      id: order.id,
      name: order.name,
      focusCost: order.focusCost,
      description: order.description,
      pattern: pattern,
      damageMultiplier: dmgMult,
      armorShredPercent: armorShred,
      bleedStacks: bleed,
    );
  }

  /// Spawns an enemy wave onto the 3x5 enemy spatial grid
  void _spawnEnemyWaveEntities(List<UnitEntity> waveEntities, {required bool isBossWave}) {
    enemyUnits.clear();
    if (waveEntities.isEmpty) return;

    if (isBossWave) {
      final bossEntity = waveEntities.first;
      const bossFootprint = UnitFootprint.quadColossus2x2;
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

      int minionIdx = 0;
      for (int i = 1; i < waveEntities.length; i++) {
        final minion = waveEntities[i];
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
      for (int i = 0; i < min(5, waveEntities.length); i++) {
        final e = waveEntities[i];
        final bool isVanguard = e.isFrontlineOverride ??
            (e.slot == FormationSlot.front1 || e.slot == FormationSlot.front2 || e.slot == FormationSlot.front3);
        final int targetRow = isVanguard ? 0 : (e.archetype == Archetype.support || e.archetype == Archetype.occultist ? 2 : 1);
        final int targetCol = (i * 2) % 5;

        enemyUnits.add(CombatUnitState(
          id: e.id,
          name: e.name,
          templateId: e.speciesId,
          isPlayer: false,
          footprint: e.isBoss ? UnitFootprint.quadColossus2x2 : UnitFootprint.single1x1,
          archetype: mapArchetypeToSpatial(e.archetype, isBoss: e.isBoss),
          occupiedNodes: e.isBoss
              ? [
                  GridNode(column: 1, row: 0, occupantUnitId: e.id),
                  GridNode(column: 2, row: 0, occupantUnitId: e.id),
                  GridNode(column: 1, row: 1, occupantUnitId: e.id),
                  GridNode(column: 2, row: 1, occupantUnitId: e.id),
                ]
              : [GridNode(column: targetCol, row: targetRow, occupantUnitId: e.id)],
          isDisplacementImmune: e.isBoss,
          isSlagCarapaceActive: e.isBoss,
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
  }

  /// Advances the encounter to the next enemy wave when all current enemies are defeated
  bool advanceToNextWaveIfPending() {
    if (enemyUnits.isEmpty || enemyUnits.any((u) => u.isAlive)) return false;
    if (currentWaveIndex >= totalWaves || currentWaveIndex >= _allEnemyWaves.length) return false;

    final nextWaveEntities = _allEnemyWaves[currentWaveIndex];
    currentWaveIndex++;
    final isFinalBossWave = isBossEncounterFlag && currentWaveIndex == totalWaves;
    _spawnEnemyWaveEntities(nextWaveEntities, isBossWave: isFinalBossWave);

    // Recover surviving player squad (+20% Max HP & +15 Aegis Shield & +1 Focus)
    for (final ally in playerUnits.where((u) => u.isAlive)) {
      final healAmt = max(25, (ally.maxHp * 0.20).round());
      ally.hp = min(ally.maxHp, ally.hp + healAmt);
      ally.aegisShield += 15;
      totalHealingDone += healAmt;
    }
    focus = min(maxFocus, focus + 1);

    lastBannerMessage = '⚔️ WAVE $currentWaveIndex/$totalWaves: ENEMY REINFORCEMENTS APPROACHING! (+20% Squad HP & +1 Focus)';
    addLog('=== WAVE $currentWaveIndex/$totalWaves ENGAGED: ${enemyUnits.length} hostile vessels entered the arena! Surviving allies restored +20% HP & +1 Focus. ===');
    notifyListeners();
    return true;
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
    List<List<UnitEntity>>? enemyWaves,
    bool isBoss = false,
    String? title,
    String? description,
    RelicService? relicService,
    GeneralCommandService? activeCommandService,
  }) {
    if (title != null) encounterTitle = title;
    if (description != null) encounterDescription = description;
    if (activeCommandService != null) commandService = activeCommandService;
    isBossEncounterFlag = isBoss;

    playerUnits.clear();
    enemyUnits.clear();
    _allEnemyWaves.clear();
    if (enemyWaves != null && enemyWaves.isNotEmpty) {
      _allEnemyWaves.addAll(enemyWaves);
    } else {
      _allEnemyWaves.add(enemyEntities);
    }
    currentWaveIndex = 1;
    totalWaves = _allEnemyWaves.length;

    drawPile.clear();
    hand.clear();
    burnPit.clear();
    combatLogs.clear();
    unitDamageDealt.clear();
    unitDamageTaken.clear();
    totalDamageDealt = 0;
    totalDamageTaken = 0;
    totalHealingDone = 0;
    bleedDetonationsCount = 0;
    currentTick = 0;
    isRunning = false;
    isPreBattlePhase = true;
    focus = 3;
    maxFocus = 7;
    isBulletTime = false;

    // --- POPULATE ENEMY UNITS ONTO SPATIAL GRID ---
    _spawnEnemyWaveEntities(
      _allEnemyWaves.first,
      isBossWave: isBoss && totalWaves == 1,
    );

    // --- POPULATE PLAYER SQUAD ONTO SPATIAL GRID ---
    if (playerEntities != null && playerEntities.isNotEmpty) {
      final activeGen = commandService?.activeGeneralType;
      final double morriganSpeedMult = activeGen == GeneralType.morrigan ? 1.10 : 1.0;
      final double valeriaArmorMult = activeGen == GeneralType.valeria ? 1.25 : 1.0;

      for (int i = 0; i < min(5, playerEntities.length); i++) {
        final p = playerEntities[i];

        // Apply Equipped Relic Bonuses, Plinth Material Passives, & Active Commander Aura
        final relicBonuses = relicService?.calculateBonuses(p.id) ?? const UnitRelicBonuses();
        final double plinthAllMult = p.plinthMaterial == PlinthMaterial.gold ? 1.10 : 1.0;
        final double plinthAtkMult = p.plinthMaterial == PlinthMaterial.obsidian ? 1.10 : plinthAllMult;
        final double plinthDefMult = (p.plinthMaterial == PlinthMaterial.iron ? 1.15 : plinthAllMult) * valeriaArmorMult;

        final effectiveAtk = ((p.attack + relicBonuses.bonusAttack) * plinthAtkMult).round();
        final effectiveDef = ((p.defense + relicBonuses.bonusDefense) * plinthDefMult).round();
        final effectiveMaxHp = ((p.maxHp + relicBonuses.bonusHp) * plinthAllMult).round();
        final effectiveHp = ((p.currentHp + relicBonuses.bonusHp) * plinthAllMult).round();
        final effectiveSpd = ((p.speed + relicBonuses.bonusSpeed) * plinthAllMult * morriganSpeedMult).round();
        final effectiveGraftId = p.graftedTraitId ?? (p.plinthMaterial == PlinthMaterial.bone ? 'plinth_vampiric_bone' : null);

        playerUnits.add(CombatUnitState(
          id: p.id,
          name: p.name,
          templateId: p.speciesId,
          isPlayer: true,
          footprint: UnitFootprint.single1x1,
          archetype: mapArchetypeToSpatial(p.archetype),
          occupiedNodes: [], // Spawn on Staging Reserve Dock for player tactical placement before battle
          level: p.level,
          maxHp: effectiveMaxHp,
          hp: effectiveHp,
          maxArmor: effectiveDef,
          armor: effectiveDef,
          attack: effectiveAtk,
          speed: effectiveSpd,
          customAssetPath: p.customAvatarAsset,
          nativeTraitId: p.nativeTraitId,
          graftedTraitId: effectiveGraftId,
        ));
      }
    } else {
      // Default fallback player squad (Ash & Stone Order)
      setupSunderAtAshenGate();
      return;
    }

    // Cards Setup: Deal Commander's Custom Grimoire Orders alongside Sovereign Tactics!
    final customGrimoireCards = commandService
            ?.getActiveGrimoireDeck()
            .map(mapGeneralOrderToSpatialCard)
            .toList() ??
        const <SpatialCombatCard>[];

    if (customGrimoireCards.isNotEmpty) {
      // Deal up to 2 equipped Commander Grimoire spells directly into opening hand + 1 Sovereign card
      hand.add(customGrimoireCards.first);
      if (customGrimoireCards.length > 1) {
        hand.add(customGrimoireCards[1]);
      } else {
        hand.add(const SpatialCombatCard(
          id: 'phalanx_intercept',
          name: 'Phalanx Intercept',
          focusCost: 2,
          description: 'Fortifies ally in Frontline with +35 Armor & taunt barrier.',
          pattern: TargetPattern.singleTarget,
        ));
      }
      hand.add(const SpatialCombatCard(
        id: 'stoke_the_embers',
        name: 'Stoke the Embers',
        focusCost: 1,
        description: 'Exhaust or burn to generate immediate +1 Focus & draw sovereign cards.',
        pattern: TargetPattern.singleTarget,
      ));
      for (int i = 2; i < customGrimoireCards.length; i++) {
        drawPile.add(customGrimoireCards[i]);
      }
      drawPile.add(const SpatialCombatCard(
        id: 'phalanx_intercept',
        name: 'Phalanx Intercept',
        focusCost: 2,
        description: 'Fortifies ally in Frontline with +35 Armor & taunt barrier.',
        pattern: TargetPattern.singleTarget,
      ));
      drawPile.add(const SpatialCombatCard(
        id: 'searing_brand',
        name: 'Searing Brand',
        focusCost: 2,
        description: 'Strikes enemy node and ignites cross pattern for 90 radiant damage.',
        pattern: TargetPattern.stAshlarCross,
        damageMultiplier: 1.2,
      ));
    } else {
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
    }

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

    if (commandService != null) {
      addLog('Active Commander Aura: $activeCommanderAuraLabel (${commandService!.currentProfile.name}).');
    }
    addLog('Encounter Initialized: $encounterTitle (Wave $currentWaveIndex/$totalWaves).');
    notifyListeners();
  }

  void dispatchAction(SpatialActionEvent event) {
    activeActionEvent = event;
    if (event.damage > 0) {
      if (event.isPlayerAttacker) {
        totalDamageDealt += event.damage;
        unitDamageDealt[event.attackerId] = (unitDamageDealt[event.attackerId] ?? 0) + event.damage;
      } else {
        totalDamageTaken += event.damage;
        unitDamageTaken[event.targetId] = (unitDamageTaken[event.targetId] ?? 0) + event.damage;
      }
    }
    // Also record secondary target damage
    if (event.secondaryTargetHits.isNotEmpty) {
      event.secondaryTargetHits.forEach((secId, secDmg) {
        if (event.isPlayerAttacker) {
          totalDamageDealt += secDmg;
          unitDamageDealt[event.attackerId] = (unitDamageDealt[event.attackerId] ?? 0) + secDmg;
        } else {
          totalDamageTaken += secDmg;
          unitDamageTaken[secId] = (unitDamageTaken[secId] ?? 0) + secDmg;
        }
      });
    }
    if (event.isHeal) {
      totalHealingDone += event.damage > 0 ? event.damage : 100;
    }
    if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova')) {
      bleedDetonationsCount++;
    }
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
    unitDamageDealt.clear();
    unitDamageTaken.clear();
    totalDamageDealt = 0;
    totalDamageTaken = 0;
    totalHealingDone = 0;
    bleedDetonationsCount = 0;
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
      ultimateGauge: 40,
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
      ultimateGauge: 40,
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
      ultimateGauge: 40,
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
      ultimateGauge: 40,
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
      const SpatialCombatCard(
        id: 'sanguine_siphon',
        name: 'Sanguine Siphon',
        focusCost: 2,
        description: 'Drains 85 HP from enemy, applies 3 Bleed stacks, and heals lowest ally for 100% of damage dealt.',
        pattern: TargetPattern.singleTarget,
        damageMultiplier: 1.4,
        bleedStacks: 3,
      ),
      const SpatialCombatCard(
        id: 'vitae_eruption',
        name: 'Vitae Eruption',
        focusCost: 3,
        description: 'Bloodnova across entire enemy frontline row: deals 120 DMG and detonates +20 bonus damage per bleed stack!',
        pattern: TargetPattern.horizontalRowScythe,
        damageMultiplier: 1.6,
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
    // If encounter is already decided, halt simulation immediately!
    if (isVictory || isDefeat) {
      isRunning = false;
      return;
    }

    // If a skill or attack cut-in is currently resolving on screen, pause tick progression
    // so players and enemies have kinetic focus and readability!
    if (isActionPauseEnabled && activeActionEvent != null) {
      return;
    }

    currentTick++;

    // Grimoire Card Draw: Draw 1 card every 90 ticks (~3.0 seconds) if hand has room (< 4 cards)
    if (currentTick % 90 == 0 && hand.length < 4) {
      if (drawPile.isEmpty && burnPit.isNotEmpty) {
        drawPile.addAll(burnPit);
        burnPit.clear();
        drawPile.shuffle();
        addLog('Grimoire reshuffled: ${drawPile.length} cards returned to draw pile.');
      }
      if (drawPile.isNotEmpty) {
        final drawn = drawPile.removeAt(0);
        hand.add(drawn);
        addLog('Grimoire: Drew sovereign card "${drawn.name}".');
        notifyListeners();
      }
    }

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

    // Check impending Boss Intents (Gorgoroth or any Campaign/Gauntlet Colossus Boss winds up on tick 135, and cycles every 160 ticks)
    // GDD §6.2: Under 50% HP, Boss enters Phase 2 Enkindled: winds up room-wide "Hearth Cataclysm"
    final bossUnit = enemyUnits
        .where((u) =>
            (u.id == 'gorgoroth_boss' ||
                u.archetype == UnitArchetype.colossusBehemoth ||
                u.footprint != UnitFootprint.single1x1) &&
            u.isAlive)
        .firstOrNull;
    if (bossUnit != null) {
      final bool isPhase2Enkindled = bossUnit.hp <= (bossUnit.maxHp * 0.50);

      if ((currentTick == 135 || (currentTick > 150 && currentTick % 160 == 0)) && bossUnit.pendingIntent == null) {
        if (isPhase2Enkindled) {
          // Hearth Cataclysm: 20-tick windup terminal channel hitting all Frontline (row 0) and Midline (row 1) nodes!
          final cataclysmNodes = [
            for (int col = 0; col < 5; col++) ...[
              GridNode(column: col, row: 0),
              GridNode(column: col, row: 1),
            ],
          ];
          bossUnit.pendingIntent = SpatialTelegraphIntent(
            id: 'hearth_cataclysm_$currentTick',
            skillName: 'Hearth Cataclysm',
            pattern: TargetPattern.horizontalRowScythe,
            originCol: 1,
            originRow: 0,
            targetNodes: cataclysmNodes,
            triggerTick: currentTick + 20,
            totalWindupTicks: 20,
            rawDamage: max(220, (bossUnit.attack * 2.8).round()),
          );
          lastBannerMessage = '🔥 ENKINDLED APEX: HEARTH CATACLYSM WINDING UP!';
          addLog('BOSS APEX: ${bossUnit.name} initiates HEARTH CATACLYSM incinerating Frontline and Midline in 20 ticks! Break with Smite or Retreat to Backline!');
        } else {
          // Wind up Apex Intent: Molten Great-Cleaver (Execution 15 ticks later)
          final telegraphNodes = [
            const GridNode(column: 1, row: 0), // Front Col 2 (primary target)
            const GridNode(column: 2, row: 0), // Front Col 3 (lateral splash toward Col 3)
            const GridNode(column: 1, row: 1), // Mid Col 2 (deep shockwave)
          ];
          bossUnit.pendingIntent = SpatialTelegraphIntent(
            id: 'cleave_intent_$currentTick',
            skillName: 'Molten Great-Cleaver',
            pattern: TargetPattern.tShapedCleave,
            originCol: 1,
            originRow: 0,
            targetNodes: telegraphNodes,
            triggerTick: currentTick + 15,
            totalWindupTicks: 15,
            rawDamage: bossUnit.id == 'gorgoroth_boss' ? 280 : max(180, (bossUnit.attack * 2.4).round()),
          );
          lastBannerMessage = '⚠️ ${bossUnit.name.toUpperCase()} WINDS UP: MOLTEN GREAT-CLEAVER!';
          addLog('TELEGRAPH: ${bossUnit.name} prepares Molten Great-Cleaver striking Col 2 T-Cleave in 15 ticks!');
        }
      }

      // Check Intent Trigger for Boss Apex skills
      if (bossUnit.pendingIntent != null && currentTick >= bossUnit.pendingIntent!.triggerTick) {
        _resolveGorgorothIntent(bossUnit, bossUnit.pendingIntent!);
        bossUnit.pendingIntent = null;
      }
    }

    // Check Intent Triggers for all non-boss enemy units (2-second / 60-tick telegraphed attacks)
    for (final enemy in enemyUnits.where((u) => u.isAlive && u.id != bossUnit?.id)) {
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
      // If action pause is enabled and this unit just triggered a visual action/skill,
      // break immediately so all other units' AP and turns freeze while we watch the skill in action!
      if (isActionPauseEnabled && activeActionEvent != null) {
        break;
      }
    }

    // If all current wave enemies are defeated and remaining waves exist, transition to next wave!
    advanceToNextWaveIfPending();

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

  /// --- RANK & RITE COMBAT SPECIFICATION METHODS ---

  /// Rank & Rite Spec Sec 3: Vanguard Cover Rule
  /// If an ally sits in the direct vertical column behind a living Vanguard:
  /// - Ally gains Cover: -25% damage from direct frontal attacks.
  /// - Vanguard takes 0 redirected damage (Passive Deflection).
  /// - Attacks originating from the same row ignore Cover (Flanking).
    /// Applies damage factoring Vanguard Cover (-25% from direct frontal attacks if behind living Vanguard).
  int applyDamageToTarget(
    CombatUnitState target,
    int rawDamage, {
    AttackTrajectory trajectory = AttackTrajectory.directPhysical,
    int? attackerRow,
    bool ignoreArmor = false,
    bool isPhysical = true,
  }) {
    double finalDmg = rawDamage.toDouble();
    if (isCoveredByVanguard(target, trajectory: trajectory, attackerRow: attackerRow)) {
      finalDmg *= 0.75; // -25% damage from Cover (Rank & Rite Spec Sec 3)
      addLog('🛡️ VANGUARD COVER: ${target.name} takes -25% damage behind Vanguard line!');
    }
    return target.takeDamage(finalDmg.round(), ignoreArmor: ignoreArmor, isPhysical: isPhysical);
  }

  bool isCoveredByVanguard(CombatUnitState target, {required AttackTrajectory trajectory, int? attackerRow}) {
    if (trajectory == AttackTrajectory.lobbedMagic) return false;
    if (trajectory == AttackTrajectory.flanking) return false;
    if (target.occupiedNodes.isEmpty) return false;
    final tCol = target.occupiedNodes.first.column;
    final tRow = target.occupiedNodes.first.row;

    // Attacks originating from the same row ignore Cover (Flanking)
    if (attackerRow != null && attackerRow == tRow) return false;

    // Check if target is behind Row 0 (i.e. Row 1 Midline or Row 2 Backline)
    if (tRow <= 0) return false;

    // Check if a living Vanguard exists in Row 0 of the exact same column
    final squad = target.isPlayer ? playerUnits : enemyUnits;
    final vanguard = squad.where((u) =>
        u.isAlive &&
        u.archetype == UnitArchetype.vanguardMelee &&
        u.occupies(tCol, 0)).firstOrNull;

    return vanguard != null;
  }

  /// Line of sight check (Rank & Rite Spec Sec 1 & 5)
  /// Checks whether a direct physical attack can reach target or is blocked by Frontline / Petrified Plinth.
  bool hasLineOfSight(CombatUnitState attacker, CombatUnitState target, {required AttackTrajectory trajectory}) {
    if (trajectory == AttackTrajectory.lobbedMagic) return true;
    if (attacker.occupiedNodes.isEmpty || target.occupiedNodes.isEmpty) return true;
    final tCol = target.occupiedNodes.first.column;
    final tRow = target.occupiedNodes.first.row;
    final opposingSquad = target.isPlayer ? playerUnits : enemyUnits;

    // Check for any solid stone plinths or frontline units between clash line and target
    for (int r = 0; r < tRow; r++) {
      final blocking = opposingSquad.where((u) => (u.isAlive || u.isSolidObstacle) && u.occupies(tCol, r)).firstOrNull;
      if (blocking != null) return false;
    }
    return true;
  }

  /// Rank & Rite Spec Sec 4: Displacement & Collision Physics (Knockback & Kinetic Splat)
  /// Knockback displaces a unit backward along their column lane (increasing row index).
  /// If path is blocked by ally, enemy, stone plinth, or back wall:
  /// - Unit stops immediately before the obstacle.
  /// - Kinetic Splat: Moving unit and stationary obstacle both take 50% bonus collision damage.
  void applyKnockback(CombatUnitState unit, int distanceRows, {int baseImpactDamage = 50}) {
    if (unit.isDisplacementImmune || unit.occupiedNodes.isEmpty) return;
    final uCol = unit.occupiedNodes.first.column;
    final startRow = unit.occupiedNodes.first.row;
    final friendlySquad = unit.isPlayer ? playerUnits : enemyUnits;
    final allObstacles = [...playerUnits, ...enemyUnits].where((u) => u.id != unit.id && (u.isAlive || u.isSolidObstacle)).toList();

    int currentRow = startRow;
    bool hadCollision = false;
    CombatUnitState? hitObstacle;

    for (int step = 1; step <= distanceRows; step++) {
      final nextRow = currentRow + 1;
      if (nextRow > 2) {
        // Back Wall Collision!
        hadCollision = true;
        break;
      }
      final blocking = allObstacles.where((o) => o.occupies(uCol, nextRow)).firstOrNull;
      if (blocking != null) {
        hadCollision = true;
        hitObstacle = blocking;
        break;
      }
      currentRow = nextRow;
    }

    // Move unit up to collision point
    if (currentRow != startRow) {
      unit.occupiedNodes.clear();
      unit.occupiedNodes.add(GridNode(column: uCol, row: currentRow, occupantUnitId: unit.id));
      addLog('${unit.name} knocked back along Col ${uCol + 1} to Row $currentRow.');
    }

    // Kinetic Splat Resolution
    if (hadCollision) {
      final collisionDmg = max(10, (baseImpactDamage * 0.50).round());
      final splatVictimDmg = unit.takeDamage(collisionDmg, ignoreArmor: true, isPhysical: true);
      addLog('💥 KINETIC SPLAT: ${unit.name} collided! Suffers $splatVictimDmg true impact damage.');

      if (hitObstacle != null) {
        if (hitObstacle.isSolidObstacle) {
          final shattered = hitObstacle.strikePlinth();
          addLog('💥 KINETIC SPLAT: Petrified Plinth ${hitObstacle.name} struck! (Durability: ${hitObstacle.plinthDurability}/3)${shattered ? " - SHATTERED TO DUST!" : ""}');
        } else {
          final obstDmg = hitObstacle.takeDamage(collisionDmg, ignoreArmor: true, isPhysical: true);
          addLog('💥 KINETIC SPLAT: Obstacle ${hitObstacle.name} struck for $obstDmg collision damage!');
        }
      } else {
        addLog('💥 KINETIC SPLAT: ${unit.name} crashed violently into the Citadel Back Wall!');
      }
    }
  }

  /// Rank & Rite Spec Sec 6: Cast 1 Tuning Slip from hand during active ally turn
  bool castTuningSlip(String cardId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) {
    if (hasCastTuningSlipThisTurn) {
      addLog('Tuning Slip limit reached! Only 1 Tuning Slip can be cast per active ally turn.');
      lastBannerMessage = '⚠️ 1 TUNING SLIP PER TURN: Select unit action or end turn!';
      return false;
    }
    final success = castCard(cardId, targetUnit: targetUnit, targetCol: targetCol, targetRow: targetRow);
    if (success) {
      hasCastTuningSlipThisTurn = true;
      addLog('TUNING SLIP: Cast slip from Sculptor Tray (Vitae Remaining: $focus/7).');
    }
    return success;
  }

  /// Rank & Rite Spec Sec 2: Turn Meter Action Cost Resolution
  /// - Skill / Attack: TM resets to 0.
  /// - Reposition (1 tile shift): TM resets to 7,500 (25% cost). Unit acts again soon.
  void executeUnitAction(CombatUnitState unit, {bool isReposition = false, int? shiftCol, int? shiftRow}) {
    if (isReposition && shiftCol != null && shiftRow != null) {
      movePlayerUnit(unit.id, shiftCol, shiftRow);
      unit.currentAp = CombatUnitState.moveRetainedTm; // 7,500 TM
      addLog('TACTICAL SHIFT: ${unit.name} repositioned (TM retained: 7,500 / 25% cost).');
    } else {
      _executeUnitTurn(unit);
      unit.currentAp = 0; // Skill / Attack consumes full TM
    }
    hasCastTuningSlipThisTurn = false;
    activeActingUnit = null;
    isTurnExecutionPaused = false;
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
    } else if (!unit.isPlayer &&
        unit.pendingIntent == null &&
        unit.actionCycleCount % 2 == 1 &&
        (unit.archetype == UnitArchetype.backlineCaster ||
            unit.templateId.contains('arbalest') ||
            unit.templateId.contains('archer') ||
            unit.templateId.contains('marksman'))) {
      // Dynamic Campaign Enemy Telegraph: Every 2nd turn, enemy casters & marksmen wind up a 60-tick (2.0s)
      // telegraphed column/node danger zone so players can tactically dodge or shield!
      unit.actionCycleCount++;
      final eCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 2;
      final eRow = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.row : 2;
      final target = _resolveColumnTarget(unitCol: eCol, targetingPlayers: true);
      final targetNode = target?.occupiedNodes.firstOrNull ?? GridNode(column: eCol, row: 0);
      final isPiercing = unit.archetype == UnitArchetype.reachMidline;
      final skillLabel = isPiercing ? 'Deadeye Volley' : 'Abyssal Hex Bolt';
      unit.pendingIntent = SpatialTelegraphIntent(
        id: 'telegraph_${currentTick}_${unit.id}',
        skillName: skillLabel,
        pattern: isPiercing ? TargetPattern.piercingColumnSkewer : TargetPattern.singleTarget,
        originCol: eCol,
        originRow: eRow,
        targetNodes: [
          GridNode(column: targetNode.column, row: targetNode.row),
          if (isPiercing && targetNode.row != 0) GridNode(column: targetNode.column, row: 0),
        ],
        triggerTick: currentTick + 60,
        totalWindupTicks: 60,
        rawDamage: (unit.effectiveAttack * 1.35).round(),
      );
      lastBannerMessage = '⚠️ ${unit.name.toUpperCase()} WINDS UP: ${skillLabel.toUpperCase()} (2.0s)!';
      addLog('TELEGRAPH: ${unit.name} winds up $skillLabel targeting Col ${targetNode.column + 1} in 2.0s!');
    } else if (unit.archetype == UnitArchetype.reachMidline) {
      _executeReachMidlineAction(unit);
    } else if (unit.archetype == UnitArchetype.vanguardMelee) {
      _executeVanguardAction(unit);
    } else if (unit.archetype == UnitArchetype.backlineCaster) {
      _executeCasterAction(unit);
    } else if (unit.id == 'gorgoroth_boss' || unit.archetype == UnitArchetype.colossusBehemoth) {
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

  /// Applies Crucible Grafted Trait proc & Active Commander Aura on any attack or signature skill
  String? _applyGraftedTraitProc(CombatUnitState attacker, CombatUnitState target, int damageDealt) {
    // Active Commander Aura: Lord Vladislav's Crimson Tithe (+10% Vampiric Siphon vs Wounded/Bleeding foes)
    if (attacker.isPlayer &&
        commandService?.activeGeneralType == GeneralType.vladislav &&
        damageDealt > 0 &&
        (target.bleedStacks > 0 || target.hp < target.maxHp)) {
      final titheHeal = max(5, (damageDealt * 0.12).round());
      attacker.hp = min(attacker.maxHp, attacker.hp + titheHeal);
      totalHealingDone += titheHeal;
      addLog('  🩸 [AURA: CRIMSON TITHE] ${attacker.name} siphons +$titheHeal HP from wounded ${target.name}!');
    }
    // Active Commander Aura: Arch-Lich Malakor's Carrion Miasma (If target died, spread +2 Poison to all enemies)
    if (attacker.isPlayer &&
        commandService?.activeGeneralType == GeneralType.malakor &&
        !target.isAlive) {
      for (final other in enemyUnits.where((u) => u.isAlive)) {
        other.poisonStacks += 2;
      }
      addLog('  ☠️ [AURA: CARRION MIASMA] Slain ${target.name} erupts, infecting all enemies with +2 Poison!');
    }
    final trait = attacker.graftedTraitId;
    if (trait == null || trait.isEmpty) return null;
    final t = trait.toLowerCase();

    if (t.contains('vampiric') || t.contains('siphon') || t.contains('leech')) {
      final healAmt = max(8, (damageDealt * 0.25).round());
      attacker.hp = min(attacker.maxHp, attacker.hp + healAmt);
      if (attacker.isPlayer) totalHealingDone += healAmt;
      addLog('  🧬 [GRAFT: VAMPIRIC CONDUIT] ${attacker.name} siphons +$healAmt HP!');
      return 'VAMPIRIC CONDUIT (+$healAmt HP)';
    }
    if (t.contains('rabid') || t.contains('serrated') || t.contains('bleed') || t.contains('hemorrhage')) {
      target.bleedStacks += 1;
      attacker.hasteDuration = max(attacker.hasteDuration, 60); // 2s Haste
      addLog('  🧬 [GRAFT: SERRATED LINEAGE] ${attacker.name} inflicts +1 Bleed & gains 2s Haste!');
      return 'SERRATED LINEAGE (+1 BLEED & HASTE)';
    }
    if (t.contains('bastion') || t.contains('carapace') || t.contains('bulwark') || t.contains('iron') || t.contains('shield')) {
      attacker.aegisShield += 20;
      addLog('  🧬 [GRAFT: IRON BASTION] ${attacker.name} fortifies with +20 Aegis Shield!');
      return 'IRON BASTION (+20 AEGIS)';
    }
    if (t.contains('solar') || t.contains('cinder') || t.contains('pyre') || t.contains('burn') || t.contains('flame')) {
      target.burnDuration = max(target.burnDuration, 60); // 2s Burn
      addLog('  🧬 [GRAFT: SOLAR IGNITION] ${attacker.name} ignites ${target.name} for 2s Burn!');
      return 'SOLAR IGNITION (+2s BURN)';
    }
    if (t.contains('miasma') || t.contains('venom') || t.contains('blight') || t.contains('poison') || t.contains('spore')) {
      target.poisonStacks += 2;
      addLog('  🧬 [GRAFT: MIASMIC SPORES] ${attacker.name} infects ${target.name} with +2 Poison!');
      return 'MIASMIC SPORES (+2 POISON)';
    }
    if (t.contains('keen') || t.contains('predator') || t.contains('pack') || t.contains('execution')) {
      final bonusDmg = max(5, (damageDealt * 0.20).round());
      target.takeDamage(bonusDmg, ignoreArmor: true, isPhysical: true);
      attacker.currentAp = min(SpatialCombatEngine.tickThreshold, attacker.currentAp + 1200);
      addLog('  🧬 [GRAFT: PREDATOR INSTINCT] ${attacker.name} deals +$bonusDmg True DMG & gains +1,200 AP!');
      return 'PREDATOR INSTINCT (+$bonusDmg DMG & AP)';
    }

    // Default generic Crucible Graft proc
    final bonusDmg = max(5, (damageDealt * 0.15).round());
    target.takeDamage(bonusDmg, ignoreArmor: true, isPhysical: true);
    attacker.aegisShield += 15;
    final label = attacker.graftedTraitDisplayName?.split(' (').first.toUpperCase() ?? 'CRUCIBLE GRAFT';
    addLog('  🧬 [GRAFT: $label] ${attacker.name} deals +$bonusDmg True DMG & gains +15 Aegis!');
    return '$label (+$bonusDmg DMG & +15 AEGIS)';
  }

  /// Executes a unit's distinct Signature Skill every 3rd action cycle (+25% Ultimate Charge)
  void _executeSignatureSkill(CombatUnitState unit, CombatUnitState target) {
    final key = '${unit.id.toLowerCase()}_${unit.templateId.toLowerCase()}';
    final skillName = unit.signatureSkillName;
    int dmg = 0;
    int appliedBleed = 0;
    TargetPattern pattern = TargetPattern.singleTarget;
    final Map<String, int> secondaryHits = {};
    final friendlySquad = unit.isPlayer ? playerUnits : enemyUnits;
    final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;

    if (key.contains('vladislav')) {
      final rawDmg = (unit.effectiveAttack * 1.60).round();
      dmg = target.takeDamage(rawDmg, isPhysical: true);
      appliedBleed = 2;
      target.bleedStacks += appliedBleed;
      final drainHeal = max(15, (dmg * 0.35).round());
      unit.hp = min(unit.maxHp, unit.hp + drainHeal);
      if (unit.isPlayer) totalHealingDone += drainHeal;
      pattern = TargetPattern.horizontalRowScythe;
      addLog('★ SIGNATURE SKILL: ${unit.name} unleashes $skillName on ${target.name} for $dmg DMG (+2 Bleed, +$drainHeal HP drained)!');
    } else if (key.contains('valeria')) {
      final rawDmg = (unit.effectiveAttack * 1.45).round();
      dmg = target.takeDamage(rawDmg, isPhysical: true);
      target.sunderArmor(0.25);
      target.currentAp = max(0, target.currentAp - 1500);
      for (final ally in friendlySquad.where((u) => u.isAlive && u.currentDepth == RowDepth.front)) {
        ally.aegisShield += 25;
      }
      pattern = TargetPattern.piercingColumnSkewer;
      addLog('★ SIGNATURE SKILL: ${unit.name} unleashes $skillName for $dmg DMG, sunders 25% Armor, and shields Frontline (+25 Aegis)!');
    } else if (key.contains('malakor')) {
      final rawDmg = (unit.effectiveAttack * 1.60).round();
      dmg = target.takeDamage(rawDmg, isPhysical: false);
      target.burnDuration = max(target.burnDuration, 90);
      target.vulnerableDuration = max(target.vulnerableDuration, 90);
      pattern = TargetPattern.stAshlarCross;
      addLog('★ SIGNATURE SKILL: ${unit.name} calls down $skillName on ${target.name} for $dmg Holy DMG (3s Burn & Vulnerable)!');
    } else if (key.contains('morrigan')) {
      final rawDmg = (unit.effectiveAttack * 1.45).round();
      dmg = target.takeDamage(rawDmg, isPhysical: false);
      target.poisonStacks += 3;
      target.vulnerableDuration = max(target.vulnerableDuration, 90);
      pattern = TargetPattern.stAshlarCross;
      addLog('★ SIGNATURE SKILL: ${unit.name} weaves $skillName on ${target.name} for $dmg DMG (+3 Poison & Vulnerable)!');
    } else if (key.contains('iron_footman') || key.contains('sentinel') || key.contains('juggernaut') || key.contains('dreadnought')) {
      final rawDmg = (unit.effectiveAttack * 1.35).round();
      dmg = target.takeDamage(rawDmg, isPhysical: true);
      target.armor = max(0, target.armor - 15);
      target.currentAp = max(0, target.currentAp - 1500);
      unit.aegisShield += 25;
      addLog('★ SIGNATURE SKILL: ${unit.name} slams ${target.name} with $skillName for $dmg DMG (-15 Armor, -1,500 AP, +25 Aegis)!');
    } else if (key.contains('sanguine_blade') || key.contains('duelist') || key.contains('flayer')) {
      final rawDmg = (unit.effectiveAttack * 1.50).round();
      dmg = target.takeDamage(rawDmg, isPhysical: true);
      appliedBleed = 2;
      target.bleedStacks += appliedBleed;
      unit.currentAp = min(SpatialCombatEngine.tickThreshold, unit.currentAp + 2000);
      pattern = TargetPattern.reachMidToFront;
      addLog('★ SIGNATURE SKILL: ${unit.name} executes $skillName on ${target.name} for $dmg CRIT DMG (+2 Bleed, +2,000 AP)!');
    } else if (key.contains('arbalest') || key.contains('marksman') || key.contains('archer')) {
      final rawDmg = (unit.effectiveAttack * 1.55).round();
      dmg = target.takeDamage(rawDmg, ignoreArmor: true, isPhysical: true);
      target.vulnerableDuration = max(target.vulnerableDuration, 90);
      pattern = TargetPattern.piercingColumnSkewer;
      addLog('★ SIGNATURE SKILL: ${unit.name} fires $skillName piercing ${target.name} for $dmg True DMG & Vulnerable (3s)!');
    } else if (key.contains('hound') || key.contains('cerberus') || key.contains('warhound')) {
      final rawDmg = (unit.effectiveAttack * 1.50).round();
      dmg = target.takeDamage(rawDmg, isPhysical: true);
      appliedBleed = 2;
      target.bleedStacks += appliedBleed;
      unit.hasteDuration = max(unit.hasteDuration, 90);
      addLog('★ SIGNATURE SKILL: ${unit.name} mauls ${target.name} with $skillName for $dmg DMG (+2 Bleed & 3s Haste)!');
    } else if (key.contains('sun_smith') || key.contains('cleric') || key.contains('medicus') || key.contains('priestess') || key.contains('alchemist')) {
      final rawDmg = (unit.effectiveAttack * 1.30).round();
      dmg = target.takeDamage(rawDmg, isPhysical: false);
      final allies = friendlySquad.where((u) => u.isAlive).toList()
        ..sort((a, b) => (a.hp / a.maxHp).compareTo(b.hp / b.maxHp));
      final lowestAlly = allies.firstOrNull;
      if (lowestAlly != null) {
        lowestAlly.hp = min(lowestAlly.maxHp, lowestAlly.hp + 40);
        lowestAlly.aegisShield += 20;
        if (unit.isPlayer) totalHealingDone += 40;
      }
      if (unit.isPlayer && focus < maxFocus) {
        focus = min(maxFocus, focus + 1);
      }
      pattern = TargetPattern.stAshlarCross;
      addLog('★ SIGNATURE SKILL: ${unit.name} channels $skillName for $dmg DMG and restores +40 HP & +20 Aegis to ${lowestAlly?.name ?? unit.name}!');
    } else if (key.contains('cinder_witch') || key.contains('scribe') || key.contains('sorcerer') || key.contains('archon') || key.contains('occultist')) {
      final rawDmg = (unit.effectiveAttack * 1.55).round();
      dmg = target.takeDamage(rawDmg, isPhysical: false);
      target.burnDuration = max(target.burnDuration, 60);
      appliedBleed = 1;
      target.bleedStacks += appliedBleed;
      if (unit.isPlayer && focus < maxFocus) {
        focus = min(maxFocus, focus + 1);
      }
      pattern = TargetPattern.piercingColumnSkewer;
      addLog('★ SIGNATURE SKILL: ${unit.name} unleashes $skillName on ${target.name} for $dmg Arcane DMG (+2s Burn, +1 Focus)!');
    } else {
      final rawDmg = (unit.effectiveAttack * 1.45).round();
      dmg = target.takeDamage(rawDmg, isPhysical: unit.archetype != UnitArchetype.backlineCaster);
      for (final neighbor in opposingSquad.where((u) => u.isAlive && u.id != target.id).take(1)) {
        final splash = neighbor.takeDamage((rawDmg * 0.5).round());
        secondaryHits[neighbor.id] = splash;
      }
      addLog('★ SIGNATURE SKILL: ${unit.name} unleashes $skillName on ${target.name} for $dmg DMG!');
    }

    // Signature Skills accelerate Ultimate Gauge by +25%
    unit.ultimateGauge = min(100, unit.ultimateGauge + 25);
    unit.signatureCooldown = 2; // Reset to 2 basic actions until next Signature Skill
    unit.actionCycleCount++;

    final graftProc = _applyGraftedTraitProc(unit, target, dmg);
    lastBannerMessage = '★ SIGNATURE SKILL: ${unit.name.toUpperCase()} — ${skillName.toUpperCase()} ($dmg DMG)!';

    dispatchAction(SpatialActionEvent(
      id: 'sig_${currentTick}_${unit.id}',
      attackerId: unit.id,
      attackerName: unit.name,
      skillName: '★ $skillName',
      targetId: target.id,
      targetName: target.name,
      damage: dmg,
      bleedStacks: appliedBleed,
      isCrit: true,
      isPlayerAttacker: unit.isPlayer,
      pattern: pattern,
      secondaryTargetHits: secondaryHits,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      isSignatureSkill: true,
      graftedTraitProc: graftProc,
    ));
  }

  /// Adaptive Posture System: Resolves action for Reach / Midline Strikers (Skirmishers, Assassins, Marksmen)
  void _executeReachMidlineAction(CombatUnitState unit) {
    if (unit.occupiedNodes.isEmpty) return;
    final sbCol = unit.occupiedNodes.first.column;
    final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;
    final target = _resolveColumnTarget(unitCol: sbCol, targetingPlayers: !unit.isPlayer) ??
        opposingSquad.where((u) => u.isAlive).firstOrNull;

    if (target != null) {
      // Every 3rd action cycle (after 2 basic attacks), unleash distinct Unit Signature Skill!
      if (unit.isSignatureReady) {
        _executeSignatureSkill(unit, target);
        return;
      }

      unit.actionCycleCount++;
      unit.signatureCooldown = max(0, unit.signatureCooldown - 1);

      // Flanking Momentum / Marksman Precision check:
      // Triggered if unit moved this turn cycle, target has active Bleed, or Marksman shooting from Backline
      final bool isBacklineMarksman = unit.currentDepth == RowDepth.back;
      final bool isFlankingBonus = unit.hasStanceBonusReady || target.bleedStacks > 0 || isBacklineMarksman;
      final int baseDmg = isFlankingBonus ? (unit.effectiveAttack * 1.4).round() : unit.effectiveAttack;
      final dmg = target.takeDamage(baseDmg, isPhysical: true);

      // Skirmishers / Assassins inflict bleed (4 on Flanking crit, 2 on basic hit); Marksmen inflict 1
      final bool isMarksman = unit.templateId == 'iron_arbalest' || unit.name.toLowerCase().contains('arbalest');
      final int appliedBleed = isMarksman ? (isFlankingBonus ? 2 : 1) : (isFlankingBonus ? 4 : 2);
      target.bleedStacks += appliedBleed;

      // Ultimate charge: +15% per basic action
      unit.ultimateGauge = min(100, unit.ultimateGauge + 15);

      String skillName;
      if (unit.id == 'sanguine_blade') {
        skillName = isFlankingBonus ? 'Flanking Evisceration' : 'Flensing Thrust';
      } else if (unit.templateId == 'iron_arbalest' || unit.name.toLowerCase().contains('arbalest')) {
        skillName = isBacklineMarksman ? 'Armor-Piercing Bolt' : 'Heavy Crossbow Volley';
      } else if (unit.templateId == 'grave_duelist' || unit.name.toLowerCase().contains('duelist')) {
        skillName = isFlankingBonus ? 'Riposte Evisceration' : 'Dueling Thrust';
      } else {
        skillName = isFlankingBonus ? 'Flanking Strike' : 'Skirmish Thrust';
      }

      if (isFlankingBonus) {
        // Refund 3,000 AP (initiating next attack cadence 30% faster)
        unit.currentAp = min(SpatialCombatEngine.tickThreshold, unit.currentAp + 3000);
        unit.hasStanceBonusReady = false;
        unit.movedSinceLastTurn = false;
        addLog('${unit.name} [FLANKING MOMENTUM] crits ${target.name} for $dmg DMG with $skillName! Refunds +3,000 AP!');
        lastBannerMessage = '⚡ FLANKING MOMENTUM: ${unit.name} dealt $dmg CRIT & refunded 3,000 AP!';
      } else {
        addLog('${unit.name} executes $skillName on ${target.name} for $dmg DMG & $appliedBleed BLEED stacks.');
      }

      final graftProc = _applyGraftedTraitProc(unit, target, dmg);

      dispatchAction(SpatialActionEvent(
        id: 'act_${currentTick}_${unit.id}',
        attackerId: unit.id,
        attackerName: unit.name,
        skillName: skillName,
        targetId: target.id,
        targetName: target.name,
        damage: dmg,
        bleedStacks: appliedBleed,
        isCrit: isFlankingBonus,
        isPlayerAttacker: unit.isPlayer,
        pattern: isBacklineMarksman ? TargetPattern.piercingColumnSkewer : TargetPattern.reachMidToFront,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        graftedTraitProc: graftProc,
      ));
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
          // If Signature Skill is ready (and not overriding a Hold the Line stationary cleave), unleash Signature Skill!
          if (unit.isSignatureReady && !hasHoldTheLineBonus) {
            _executeSignatureSkill(unit, target);
            break;
          }
          unit.actionCycleCount++;
          unit.signatureCooldown = max(0, unit.signatureCooldown - 1);

          final int baseDmg = hasHoldTheLineBonus ? (unit.effectiveAttack * 1.35).round() : unit.effectiveAttack;
          final dmg = target.takeDamage(baseDmg, isPhysical: true);
          final skillName = hasHoldTheLineBonus
              ? (unit.id == 'lady_valeria' ? 'Solar Sunder Cleave' : 'Earth-Shattering Bash')
              : (unit.id == 'lady_valeria' ? 'Sunbrand Slash' : (unit.id == 'iron_footman' ? 'Shield Bash' : 'Vanguard Sunder'));

          final Map<String, int> lateralHits = {};

          if (hasHoldTheLineBonus) {
            // Earth-Shattering Bash cleaves laterally and resets 1,500 AP on targets hit
            target.currentAp = max(0, target.currentAp - 1500);

            // Lateral cleave across adjacent enemies in Row 0
            final opposingSquad = unit.isPlayer ? enemyUnits : playerUnits;
            for (final neighbor in opposingSquad.where((u) => u.isAlive && u.id != target.id && u.occupiedNodes.any((n) => n.row == 0 && (n.column - col).abs() <= 1))) {
              final cleaveDmg = neighbor.takeDamage((baseDmg * 0.60).round(), isPhysical: true);
              neighbor.currentAp = max(0, neighbor.currentAp - 1500);
              lateralHits[neighbor.id] = cleaveDmg;
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
          final graftProc = _applyGraftedTraitProc(unit, target, dmg);

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
            secondaryTargetHits: lateralHits,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            graftedTraitProc: graftProc,
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
        // Rank & Rite Spec Sec 4: Apply 1-row Knockback with Kinetic Splat
        applyKnockback(target, 1, baseImpactDamage: dmg);
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
      final primaryColumnTarget = _resolveColumnTarget(unitCol: targetCol, targetingPlayers: !unit.isPlayer) ??
          opposingSquad.where((u) => u.isAlive).firstOrNull;

      if (unit.isSignatureReady && primaryColumnTarget != null) {
        _executeSignatureSkill(unit, primaryColumnTarget);
        return;
      }

      unit.actionCycleCount++;
      unit.signatureCooldown = max(0, unit.signatureCooldown - 1);

      if (isAethericBonus) {
        // Piercing strike hitting entire column
        int hitCount = 0;
        int primaryDmg = 0;
        CombatUnitState? primaryTarget;
        final Map<String, int> pierceHits = {};

        for (int r = 0; r <= 2; r++) {
          final occupant = opposingSquad.where((u) => u.isAlive && u.occupies(targetCol, r)).firstOrNull;
          if (occupant != null) {
            final dmg = occupant.takeDamage(unit.effectiveAttack, isPhysical: false);
            hitCount++;
            if (primaryTarget == null) {
              primaryTarget = occupant;
              primaryDmg = dmg;
            } else {
              pierceHits[occupant.id] = dmg;
            }
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

        if (primaryTarget != null) {
          final graftProc = _applyGraftedTraitProc(unit, primaryTarget, primaryDmg);
          dispatchAction(SpatialActionEvent(
            id: 'act_${currentTick}_${unit.id}',
            attackerId: unit.id,
            attackerName: unit.name,
            skillName: 'Aetheric Piercing Beam',
            targetId: primaryTarget.id,
            targetName: primaryTarget.name,
            damage: primaryDmg,
            secondaryTargetHits: pierceHits,
            isPlayerAttacker: unit.isPlayer,
            pattern: TargetPattern.piercingColumnSkewer,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            graftedTraitProc: graftProc,
          ));
        }
      } else {
        final target = opposingSquad.where((u) => u.isAlive).firstOrNull;
        if (target != null) {
          final dmg = target.takeDamage(unit.attack);
          unit.ultimateGauge = min(100, unit.ultimateGauge + 15);
          addLog('${unit.name} fires Sun-Bolts at ${target.name} for $dmg DMG.');
          final graftProc = _applyGraftedTraitProc(unit, target, dmg);
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
            graftedTraitProc: graftProc,
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
    // If any units were left on the staging bench, automatically assign them to available tiles
    final unplaced = playerUnits.where((u) => u.isAlive && u.occupiedNodes.isEmpty).toList();
    if (unplaced.isNotEmpty) {
      for (final unit in unplaced) {
        // Preferred row based on archetype
        final preferredRow = unit.archetype == UnitArchetype.vanguardMelee
            ? 0
            : (unit.archetype == UnitArchetype.backlineCaster ? 2 : 1);
        
        bool placed = false;
        // Search preferred row first, then others
        for (final r in [preferredRow, 0, 1, 2]) {
          for (int c = 0; c < 5; c++) {
            final isOccupied = playerUnits.any((u) => u.isAlive && u.occupies(c, r));
            if (!isOccupied) {
              unit.occupiedNodes.clear();
              unit.occupiedNodes.add(GridNode(column: c, row: r, occupantUnitId: unit.id));
              placed = true;
              break;
            }
          }
          if (placed) break;
        }
      }
    }

    isPreBattlePhase = false;
    isRunning = true;
    lastBannerMessage = '⚔️ THE SUNDER INITIATED! ENGAGE THE FOE!';
    addLog('DEPLOYMENT CONCLUDED: Battle engaged at 30 Hz discrete simulation speed.');
    notifyListeners();
  }

  /// Deploys an unplaced unit from the staging bench onto the player's 3x5 grid.
  bool deployUnitFromBench(String unitId, int targetCol, int targetRow) {
    if (!isPreBattlePhase) {
      addLog('Units can only be deployed from the bench during the Pre-Battle phase.');
      return false;
    }
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null) return false;
    if (targetCol < 0 || targetCol > 4 || targetRow < 0 || targetRow > 2) return false;

    // If target node is occupied by another friendly unit, swap or displace to bench
    final existingOccupant = playerUnits
        .where((u) => u.isAlive && u.id != unit.id && u.occupies(targetCol, targetRow))
        .firstOrNull;

    if (existingOccupant != null) {
      if (unit.occupiedNodes.isNotEmpty) {
        // Normal formation swap on the board
        final oldCol = unit.occupiedNodes.first.column;
        final oldRow = unit.occupiedNodes.first.row;
        existingOccupant.occupiedNodes.clear();
        existingOccupant.occupiedNodes.add(GridNode(column: oldCol, row: oldRow, occupantUnitId: existingOccupant.id));
      } else {
        // Displace the existing occupant back to the bench so the incoming unit takes this tile
        existingOccupant.occupiedNodes.clear();
        addLog('${existingOccupant.name} was returned to the staging bench.');
      }
    }

    unit.occupiedNodes.clear();
    unit.occupiedNodes.add(GridNode(column: targetCol, row: targetRow, occupantUnitId: unit.id));
    lastBannerMessage = '📍 ${unit.name.toUpperCase()} DEPLOYED to (Col ${targetCol + 1}, Row $targetRow)';
    addLog('${unit.name} deployed from bench to Col ${targetCol + 1}, Row $targetRow.');
    notifyListeners();
    return true;
  }

  /// Recalls all player units to the staging reserve bench during pre-battle
  void clearAllUnitsToBench() {
    if (!isPreBattlePhase) return;
    for (final unit in playerUnits.where((u) => u.isAlive)) {
      unit.occupiedNodes.clear();
    }
    lastBannerMessage = '↩️ ALL UNITS RECALLED: Drag any unit from the dock to position!';
    addLog('All squad units recalled to the staging reserve bench.');
    notifyListeners();
  }

  /// Automatically places any unplaced reserve bench units onto available formation tiles
  void autoDeployAllFromBench() {
    if (!isPreBattlePhase) return;
    final unplaced = playerUnits.where((u) => u.isAlive && u.occupiedNodes.isEmpty).toList();
    for (final unit in unplaced) {
      final preferredRow = unit.archetype == UnitArchetype.vanguardMelee
          ? 0
          : (unit.archetype == UnitArchetype.backlineCaster ? 2 : 1);
      bool placed = false;
      for (final r in [preferredRow, 0, 1, 2]) {
        for (int c = 0; c < 5; c++) {
          final isOccupied = playerUnits.any((u) => u.isAlive && u.occupies(c, r));
          if (!isOccupied) {
            unit.occupiedNodes.clear();
            unit.occupiedNodes.add(GridNode(column: c, row: r, occupantUnitId: unit.id));
            placed = true;
            break;
          }
        }
        if (placed) break;
      }
    }
    lastBannerMessage = '✨ SQUAD DEPLOYED: Units stationed across tactical grid.';
    addLog('All bench units auto-deployed onto tactical grid.');
    notifyListeners();
  }

  /// Recalls a deployed unit back to the reserve staging bench during pre-battle
  bool undeployUnitToBench(String unitId) {
    if (!isPreBattlePhase) return false;
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null || unit.occupiedNodes.isEmpty) return false;
    unit.occupiedNodes.clear();
    lastBannerMessage = '↩️ ${unit.name.toUpperCase()} recalled to staging bench';
    addLog('${unit.name} recalled to reserve bench.');
    notifyListeners();
    return true;
  }

  /// Swaps an existing player unit with a new unit from the reserve roster during pre-battle deployment
  bool swapPlayerUnit(String outgoingUnitId, UnitEntity incomingEntity, {RelicService? relicService}) {
    if (!isPreBattlePhase) {
      addLog('Roster substitutions can only be executed during Pre-Battle Deployment.');
      return false;
    }
    final index = playerUnits.indexWhere((u) => u.id == outgoingUnitId);
    if (index == -1) return false;

    final oldUnit = playerUnits[index];
    // Preserve current grid positioning if oldUnit was placed on the field
    final preservedNodes = oldUnit.occupiedNodes.map((node) => GridNode(
      column: node.column,
      row: node.row,
      occupantUnitId: incomingEntity.id,
    )).toList();

    // Compute effective stats including any equipped relics & Plinth Material passives
    final relicBonuses = relicService?.calculateBonuses(incomingEntity.id) ?? const UnitRelicBonuses();
    final double plinthAllMult = incomingEntity.plinthMaterial == PlinthMaterial.gold ? 1.10 : 1.0;
    final double plinthAtkMult = incomingEntity.plinthMaterial == PlinthMaterial.obsidian ? 1.10 : plinthAllMult;
    final double plinthDefMult = incomingEntity.plinthMaterial == PlinthMaterial.iron ? 1.15 : plinthAllMult;

    final effectiveAtk = ((incomingEntity.attack + relicBonuses.bonusAttack) * plinthAtkMult).round();
    final effectiveDef = ((incomingEntity.defense + relicBonuses.bonusDefense) * plinthDefMult).round();
    final effectiveMaxHp = ((incomingEntity.maxHp + relicBonuses.bonusHp) * plinthAllMult).round();
    final effectiveHp = ((incomingEntity.currentHp + relicBonuses.bonusHp) * plinthAllMult).round();
    final effectiveSpd = ((incomingEntity.speed + relicBonuses.bonusSpeed) * plinthAllMult).round();
    final effectiveGraftId = incomingEntity.graftedTraitId ??
        (incomingEntity.plinthMaterial == PlinthMaterial.bone ? 'plinth_vampiric_bone' : null);

    final newCombatUnit = CombatUnitState(
      id: incomingEntity.id,
      name: incomingEntity.name,
      templateId: incomingEntity.speciesId,
      isPlayer: true,
      footprint: UnitFootprint.single1x1,
      archetype: mapArchetypeToSpatial(incomingEntity.archetype),
      occupiedNodes: preservedNodes,
      level: incomingEntity.level,
      maxHp: effectiveMaxHp,
      hp: effectiveHp,
      maxArmor: effectiveDef,
      armor: effectiveDef,
      attack: effectiveAtk,
      speed: effectiveSpd,
      customAssetPath: incomingEntity.customAvatarAsset,
      nativeTraitId: incomingEntity.nativeTraitId,
      graftedTraitId: effectiveGraftId,
      ultimateGauge: 40,
    );

    playerUnits[index] = newCombatUnit;
    lastBannerMessage = '⚔️ DEPLOYED: ${incomingEntity.name} replaced ${oldUnit.name}';
    addLog('Substituted ${oldUnit.name} with ${incomingEntity.name} in combat lineup.');
    notifyListeners();
    return true;
  }

  /// Adds a new unit from reserve into an open squad slot (up to max 5 units) during pre-battle deployment
  bool addPlayerUnitFromReserve(UnitEntity incomingEntity, {RelicService? relicService}) {
    if (!isPreBattlePhase) {
      addLog('Roster deployment can only be executed during Pre-Battle Deployment.');
      return false;
    }
    if (playerUnits.length >= 5) {
      addLog('Maximum squad capacity reached (5/5 deployed).');
      return false;
    }
    if (playerUnits.any((u) => u.id == incomingEntity.id)) {
      return false;
    }

    final relicBonuses = relicService?.calculateBonuses(incomingEntity.id) ?? const UnitRelicBonuses();
    final double plinthAllMult = incomingEntity.plinthMaterial == PlinthMaterial.gold ? 1.10 : 1.0;
    final double plinthAtkMult = incomingEntity.plinthMaterial == PlinthMaterial.obsidian ? 1.10 : plinthAllMult;
    final double plinthDefMult = incomingEntity.plinthMaterial == PlinthMaterial.iron ? 1.15 : plinthAllMult;

    final effectiveAtk = ((incomingEntity.attack + relicBonuses.bonusAttack) * plinthAtkMult).round();
    final effectiveDef = ((incomingEntity.defense + relicBonuses.bonusDefense) * plinthDefMult).round();
    final effectiveMaxHp = ((incomingEntity.maxHp + relicBonuses.bonusHp) * plinthAllMult).round();
    final effectiveHp = ((incomingEntity.currentHp + relicBonuses.bonusHp) * plinthAllMult).round();
    final effectiveSpd = ((incomingEntity.speed + relicBonuses.bonusSpeed) * plinthAllMult).round();
    final effectiveGraftId = incomingEntity.graftedTraitId ??
        (incomingEntity.plinthMaterial == PlinthMaterial.bone ? 'plinth_vampiric_bone' : null);

    final newCombatUnit = CombatUnitState(
      id: incomingEntity.id,
      name: incomingEntity.name,
      templateId: incomingEntity.speciesId,
      isPlayer: true,
      footprint: UnitFootprint.single1x1,
      archetype: mapArchetypeToSpatial(incomingEntity.archetype),
      occupiedNodes: [], // Staged on reserve bench, ready to drag onto grid or auto-deploy
      level: incomingEntity.level,
      maxHp: effectiveMaxHp,
      hp: effectiveHp,
      maxArmor: effectiveDef,
      armor: effectiveDef,
      attack: effectiveAtk,
      speed: effectiveSpd,
      customAssetPath: incomingEntity.customAvatarAsset,
      nativeTraitId: incomingEntity.nativeTraitId,
      graftedTraitId: effectiveGraftId,
      ultimateGauge: 40,
    );

    playerUnits.add(newCombatUnit);
    lastBannerMessage = '⚔️ REINFORCEMENT: ${incomingEntity.name} joined the squad!';
    addLog('Added ${incomingEntity.name} to active squad.');
    notifyListeners();
    return true;
  }

  /// Tactical Plinth Triage: Player shifts or swaps unit across nodes
  /// In Pre-Battle Deployment Phase: 0 AP cost & anywhere on player grid (Rows 0-2, Cols 0-4), supports swapping
  /// In Live Combat: 50% AP cost & restricted to unit moveRange, supports adjacent formation swaps
  bool movePlayerUnit(String unitId, int targetCol, int targetRow) {
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null) return false;

    // If unit is currently on the staging bench (not placed on grid), deploy directly!
    if (unit.occupiedNodes.isEmpty) {
      return deployUnitFromBench(unitId, targetCol, targetRow);
    }
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

  /// Grimoire Redraw: Discards current hand into Burn Pit and draws up to 3 fresh cards (Costs 1 Focus)
  bool redrawHand() {
    if (isPreBattlePhase) {
      addLog('Cannot redraw during Deployment Phase! Start battle first.');
      lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle first!';
      notifyListeners();
      return false;
    }
    if (focus < 1) {
      lastBannerMessage = '⚠️ NEED 1 FOCUS TO REDRAW GRIMOIRE!';
      addLog('Redraw failed: Requires 1 Focus.');
      notifyListeners();
      return false;
    }

    focus--; // Consume 1 Focus
    final int discardedCount = hand.length;
    burnPit.addAll(hand);
    hand.clear();

    // Replenish draw pile if empty
    if (drawPile.length < 3 && burnPit.isNotEmpty) {
      drawPile.addAll(burnPit);
      burnPit.clear();
      drawPile.shuffle();
      addLog('Grimoire reshuffled: ${drawPile.length} cards returned to draw pile.');
    }

    // Draw up to 3 new cards
    final int toDraw = min(3, drawPile.length);
    for (int i = 0; i < toDraw; i++) {
      hand.add(drawPile.removeAt(0));
    }

    lastBannerMessage = '📖 GRIMOIRE REDRAW: Cycled $discardedCount cards into Burn Pit & drew ${hand.length} fresh spells!';
    addLog('GRIMOIRE REDRAW: Consumed 1 Focus. Hand refreshed with ${hand.length} sovereign spells.');
    notifyListeners();
    return true;
  }

  /// Casts a tactical card on a target node / unit
  bool castCard(String cardId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) {
    if (isPreBattlePhase) {
      addLog('Cannot cast Sovereign Spells during Deployment Phase! Start battle first.');
      lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle before casting spells!';
      notifyListeners();
      return false;
    }
    final card = hand.where((c) => c.id == cardId).firstOrNull;
    if (card == null) return false;
    if (focus < card.focusCost) {
      addLog('Not enough Focus! Requires ${card.focusCost}, have $focus.');
      return false;
    }

    focus -= card.focusCost;
    hand.remove(card);
    burnPit.add(card);

    if (card.id == 'smite_the_calcified' || card.id == 'smite_the_wicked') {
      final boss = targetUnit ??
          enemyUnits
              .where((u) => (u.id == 'gorgoroth_boss' || u.archetype == UnitArchetype.colossusBehemoth) && u.isAlive)
              .firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;
      if (boss != null) {
        final rawDmg = (74 * 2.5 * (commandService?.potencyMultiplier ?? 1.0)).round();
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
          boss.sunderArmor(0.35);
          boss.pendingIntent = null;
          lastBannerMessage = '⚡ ${card.name.toUpperCase()} DEALS $dmg DMG & SUNDERS ARMOR!';
        }

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_smite',
          attackerId: 'player_valeria',
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'VALERIA',
          skillName: card.name,
          targetId: boss.id,
          targetName: boss.name,
          damage: dmg,
          isCrit: true,
          isPlayerAttacker: true,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'phalanx_intercept' || card.id == 'stand_resolute' || card.id == 'iron_bulwark' || card.id == 'sanguine_ward') {
      final recipient = targetUnit ??
          playerUnits.where((u) => u.isAlive && u.currentDepth == RowDepth.front).firstOrNull ??
          playerUnits.where((u) => u.isAlive).firstOrNull;
      if (recipient != null) {
        final armorGain = (35 * (commandService?.potencyMultiplier ?? 1.0)).round();
        final shieldGain = (50 * (commandService?.potencyMultiplier ?? 1.0)).round();
        recipient.armor += armorGain;
        recipient.aegisShield += shieldGain;
        if (card.id == 'stand_resolute' || card.id == 'iron_bulwark') {
          for (final ally in playerUnits.where((u) => u.isAlive && u.id != recipient.id && u.currentDepth == RowDepth.front)) {
            ally.armor += 20;
            ally.aegisShield += 30;
          }
        }
        lastBannerMessage = '🛡️ ${card.name.toUpperCase()}: +$armorGain Armor & +$shieldGain Aegis Shield to ${recipient.name}!';
        addLog('CAST: ${card.name} fortified ${recipient.name} (+$armorGain Armor, +$shieldGain Aegis Shield)!');

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_phalanx',
          attackerId: 'player_valeria',
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'VALERIA',
          skillName: card.name,
          targetId: recipient.id,
          targetName: recipient.name,
          damage: 0,
          isHeal: true,
          isPlayerAttacker: true,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'searing_brand' || card.id == 'unravel_hex') {
      final target = targetUnit ??
          (targetCol != null && targetRow != null
              ? enemyUnits.where((u) => u.isAlive && u.occupies(targetCol, targetRow)).firstOrNull
              : null) ??
          enemyUnits
              .where((u) => (u.id == 'gorgoroth_boss' || u.archetype == UnitArchetype.colossusBehemoth) && u.isAlive)
              .firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;

      if (target != null) {
        final dmg = target.takeDamage(105);
        if (card.id == 'unravel_hex') {
          target.sunderArmor(0.35);
          target.vulnerableDuration = max(target.vulnerableDuration, 90);
        }
        lastBannerMessage = '🔥 ${card.name.toUpperCase()}: Strikes ${target.name} for $dmg DMG!';
        addLog('CAST: ${card.name} struck ${target.name} for $dmg damage.');

        // Splash on other alive enemies
        final Map<String, int> splashHits = {};
        for (final other in enemyUnits.where((u) => u.isAlive && u.id != target.id)) {
          final splash = other.takeDamage(45);
          splashHits[other.id] = splash;
          addLog('  Splash: ${other.name} took $splash damage.');
        }

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_searing',
          attackerId: 'sun_smith',
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SUN-SMITH',
          skillName: card.name,
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: true,
          pattern: TargetPattern.stAshlarCross,
          secondaryTargetHits: splashHits,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      } else if (targetCol != null && targetRow != null) {
        // Target is an empty grid tile: resolve cross pattern splash on adjacent enemies!
        final splashTargets = enemyUnits.where((u) {
          if (!u.isAlive) return false;
          // Cross pattern: center (col, row), (col±1, row), (col, row±1)
          return u.occupiedNodes.any((n) {
            final dist = (n.column - targetCol).abs() + (n.row - targetRow).abs();
            return dist <= 1;
          });
        }).toList();

        if (splashTargets.isNotEmpty) {
          lastBannerMessage = '🔥 ${card.name.toUpperCase()}: Ground detonation ignited ${splashTargets.length} enemy targets!';
          final primary = splashTargets.first;
          final primaryDmg = primary.takeDamage(75);
          final Map<String, int> otherSplashes = {};

          for (final splashTarget in splashTargets.skip(1)) {
            final splash = splashTarget.takeDamage(75);
            otherSplashes[splashTarget.id] = splash;
            addLog('  Splash: ${splashTarget.name} took $splash Holy damage from ground detonation.');
          }

          dispatchAction(SpatialActionEvent(
            id: 'card_${currentTick}_searing',
            attackerId: 'sun_smith',
            attackerName: 'SUN-SMITH',
            skillName: card.name,
            targetId: primary.id,
            targetName: primary.name,
            damage: primaryDmg,
            isPlayerAttacker: true,
            pattern: TargetPattern.stAshlarCross,
            secondaryTargetHits: otherSplashes,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        } else {
          lastBannerMessage = '🔥 ${card.name.toUpperCase()}: Ground detonation struck empty stone.';
          addLog('CAST: ${card.name} detonated on empty stone ($targetCol, $targetRow).');

          dispatchAction(SpatialActionEvent(
            id: 'card_${currentTick}_searing',
            attackerId: 'sun_smith',
            attackerName: 'SUN-SMITH',
            skillName: card.name,
            targetId: 'ground_tile_${targetCol}_$targetRow',
            targetName: 'Ground Target ($targetCol, $targetRow)',
            damage: 0,
            isPlayerAttacker: true,
            pattern: TargetPattern.stAshlarCross,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    } else if (card.id == 'stoke_the_embers' || card.id == 'quicken' || card.id == 'echoing_hourglass') {
      focus = min(maxFocus, focus + 2);
      String drawMsg = '';
      if (drawPile.isNotEmpty) {
        final drawn = drawPile.removeAt(0);
        hand.add(drawn);
        drawMsg = ' & drew ${drawn.name}';
      }
      if (card.id == 'quicken' || card.id == 'echoing_hourglass') {
        for (final ally in playerUnits.where((u) => u.isAlive)) {
          ally.currentAp = min(tickThreshold, ally.currentAp + 3500);
          ally.hasteDuration = max(ally.hasteDuration, 90);
        }
      }
      lastBannerMessage = '✨ ${card.name.toUpperCase()}: +2 Focus generated$drawMsg!';
      addLog('CAST: ${card.name} restored 2 Focus$drawMsg.');

      final recipient = targetUnit ?? playerUnits.where((u) => u.isAlive).first;
      dispatchAction(SpatialActionEvent(
        id: 'card_${currentTick}_stoke',
        attackerId: 'sun_smith',
        attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SUN-SMITH',
        skillName: card.name,
        targetId: recipient.id,
        targetName: recipient.name,
        damage: 0,
        isHeal: true,
        isPlayerAttacker: true,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    } else if (card.id == 'sun_ashlar_wrath' || card.id == 'virulent_cascade' || card.id == 'corpse_burst') {
      final livingEnemies = enemyUnits.where((u) => u.isAlive).toList();
      int totalDmg = 0;
      final Map<String, int> enemyHits = {};

      for (final enemy in livingEnemies) {
        final dmg = enemy.takeDamage(110);
        if (card.id == 'virulent_cascade' || card.id == 'corpse_burst') {
          enemy.poisonStacks += 3;
        }
        totalDmg += dmg;
        enemyHits[enemy.id] = dmg;
        addLog('AOE BURST: ${enemy.name} took $dmg damage.');
      }

      final boss = livingEnemies.firstOrNull;
      lastBannerMessage = '☀️ ${card.name.toUpperCase()}: Strikes all enemies for $totalDmg total DMG!';
      if (boss != null) {
        final bossDmg = enemyHits.remove(boss.id) ?? 110;
        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_wrath',
          attackerId: 'sun_smith',
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SUN-SMITH',
          skillName: card.name,
          targetId: boss.id,
          targetName: boss.name,
          damage: bossDmg,
          isCrit: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.stAshlarCross,
          secondaryTargetHits: enemyHits,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'sun_king_cataclysm') {
      // APEX RITE: Pierces through chosen enemy column (or boss) for 260 Holy Damage & interrupts any active telegraph!
      final target = targetUnit ??
          enemyUnits
              .where((u) => (u.id == 'gorgoroth_boss' || u.archetype == UnitArchetype.colossusBehemoth) && u.isAlive)
              .firstOrNull ??
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
        final Map<String, int> cataclysmSplashes = {};
        for (final other in enemyUnits.where((u) => u.isAlive && u.id != target.id)) {
          final splash = other.takeDamage(85);
          cataclysmSplashes[other.id] = splash;
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
          secondaryTargetHits: cataclysmSplashes,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (card.id == 'revive_vitae' || card.id == 'rebind_flesh' || card.id == 'sanguine_revival') {
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
        downedTarget.isPetrifiedPlinth = false;
        downedTarget.plinthDurability = 3;
        downedTarget.isShattered = false;
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
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'INFUSED VITAE',
          skillName: card.name,
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
          lastBannerMessage = '✨ ${card.name.toUpperCase()}: +120 HP & +40 Shield to ${target.name}!';
          addLog('CAST: ${card.name} invigorated ${target.name} (+120 HP, +40 Shield).');
          dispatchAction(SpatialActionEvent(
            id: 'card_${currentTick}_vital_mend',
            attackerId: 'vital_wellspring',
            attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'INFUSED VITAE',
            skillName: card.name,
            targetId: target.id,
            targetName: target.name,
            damage: 0,
            isHeal: true,
            isPlayerAttacker: true,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    } else if (card.id == 'sanguine_siphon' ||
        card.id == 'siphon_vitality' ||
        card.id == 'rend_flesh' ||
        card.id == 'exsanguinating_strike') {
      // Sanguine Siphon / Siphon Vitality / Rend Flesh / Exsanguinating Strike:
      // Drains HP from enemy, applies 3 Bleed stacks, and heals lowest ally
      final target = targetUnit ??
          enemyUnits
              .where((u) => (u.id == 'gorgoroth_boss' || u.archetype == UnitArchetype.colossusBehemoth) && u.isAlive)
              .firstOrNull ??
          enemyUnits.where((u) => u.isAlive).firstOrNull;

      if (target != null) {
        final baseRaw = card.id == 'exsanguinating_strike' ? (105 + target.bleedStacks * 25) : 85;
        final dmg = target.takeDamage(baseRaw, isPhysical: false);
        target.bleedStacks += 3;

        // Heal lowest living player ally for 100% of damage dealt
        final livingAllies = playerUnits.where((u) => u.isAlive).toList()..sort((a, b) => a.hp.compareTo(b.hp));
        final lowestAlly = livingAllies.firstOrNull;
        if (lowestAlly != null) {
          lowestAlly.hp = min(lowestAlly.maxHp, lowestAlly.hp + dmg);
          addLog('  Siphon Transfusion: Restored $dmg HP to ${lowestAlly.name} (${lowestAlly.hp}/${lowestAlly.maxHp}).');
        }

        lastBannerMessage = '🩸 ${card.name.toUpperCase()}: Drained $dmg HP from ${target.name} & applied 3 Bleed stacks!';
        addLog('CAST: ${card.name} drained $dmg HP from ${target.name} and healed ${lowestAlly?.name ?? "ally"}.');

        dispatchAction(SpatialActionEvent(
          id: 'card_${currentTick}_siphon',
          attackerId: 'sanguine_blade',
          attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SANGUINE BLADE',
          skillName: card.name,
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          bleedStacks: 3,
          isCrit: true,
          isPlayerAttacker: true,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));

        if (lowestAlly != null) {
          dispatchAction(SpatialActionEvent(
            id: 'card_${currentTick}_siphon_heal',
            attackerId: 'sanguine_blade',
            attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SANGUINE BLADE',
            skillName: 'Siphon Transfusion',
            targetId: lowestAlly.id,
            targetName: lowestAlly.name,
            damage: dmg,
            isHeal: true,
            isPlayerAttacker: true,
            pattern: TargetPattern.singleTarget,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    } else if (card.id == 'vitae_eruption' ||
        card.id == 'feast_of_ruin' ||
        card.id == 'retributive_stride' ||
        card.id == 'disrupting_cleave' ||
        card.id == 'blood_boil') {
      // Vitae Eruption / Feast of Ruin / Retributive Stride / Disrupting Cleave / Blood Boil:
      // Bloodnova across entire enemy frontline row: 120 DMG + 20 bonus damage per bleed stack!
      int totalDmg = 0;
      int enemiesHit = 0;
      final frontEnemies = enemyUnits.where((u) => u.isAlive && u.occupiedNodes.any((n) => n.row == 0)).toList();
      final affectedEnemies = frontEnemies.isNotEmpty ? frontEnemies : enemyUnits.where((u) => u.isAlive).toList();

      final Map<String, int> eruptionHits = {};
      for (final enemy in affectedEnemies) {
        final int bleedBonus = enemy.bleedStacks * 20;
        final int rawHit = 120 + bleedBonus;
        final dmg = enemy.takeDamage(rawHit, isPhysical: false);
        if (card.id == 'disrupting_cleave') {
          enemy.currentAp = max(0, enemy.currentAp - 2500);
          enemy.pendingIntent = null;
        } else if (card.id == 'blood_boil') {
          enemy.burnDuration = max(enemy.burnDuration, 90);
        }
        totalDmg += dmg;
        enemiesHit++;
        eruptionHits[enemy.id] = dmg;
        addLog('  ${card.name}: ${enemy.name} struck for $dmg DMG (Base 120 + $bleedBonus Bleed Detonation)!');
      }

      if (card.id == 'feast_of_ruin' || card.id == 'retributive_stride') {
        for (final ally in playerUnits.where((u) => u.isAlive)) {
          ally.hp = min(ally.maxHp, ally.hp + 35);
          ally.aegisShield += 25;
        }
      }

      final primary = affectedEnemies.firstOrNull ?? enemyUnits.first;
      final primaryDmg = eruptionHits.remove(primary.id) ?? totalDmg;
      lastBannerMessage = '💥 ${card.name.toUpperCase()}: Detonated $totalDmg total damage across $enemiesHit frontline enemies!';
      addLog('APEX NOVA: ${card.name} cleaved through enemy line for $totalDmg total DMG.');

      dispatchAction(SpatialActionEvent(
        id: 'card_${currentTick}_vitae_eruption',
        attackerId: 'sanguine_blade',
        attackerName: commandService?.currentProfile.name.toUpperCase() ?? 'SANGUINE BLADE',
        skillName: card.name,
        targetId: primary.id,
        targetName: primary.name,
        damage: primaryDmg,
        isCrit: true,
        isPlayerAttacker: true,
        pattern: TargetPattern.horizontalRowScythe,
        secondaryTargetHits: eruptionHits,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    // Check if casting this card cleared the current wave and remaining waves exist
    advanceToNextWaveIfPending();

    notifyListeners();
    return true;
  }

  /// Ultimate Burst Resolution: Player manually drags charged unit mini-slate onto grid target
  bool castUltimate(String unitId, {CombatUnitState? targetUnit, int? targetCol, int? targetRow}) {
    if (isPreBattlePhase) {
      addLog('Cannot cast Ultimate Burst during Deployment Phase! Start battle first.');
      lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle before unleashing Ultimates!';
      notifyListeners();
      return false;
    }
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

      default:
        // Universal Archetype Fallback Ultimate Burst for campaign party units:
        if (unit.archetype == UnitArchetype.vanguardMelee) {
          // Vanguard Colossus Cleave: 220 DMG + 30 Armor to Frontline allies
          final target = targetUnit ?? enemyUnits.where((u) => u.isAlive).firstOrNull;
          if (target != null) {
            final dmg = target.takeDamage((unit.effectiveAttack * 2.2).round(), isPhysical: true);
            for (final ally in playerUnits.where((u) => u.isAlive && u.occupiedNodes.any((n) => n.row == 0))) {
              ally.armor = min(ally.maxArmor + 35, ally.armor + 25);
            }
            addLog('${unit.name} unleashes Sovereign Cleave for $dmg DMG!');
            lastBannerMessage = '⚔️ SOVEREIGN CLEAVE: ${unit.name} dealt $dmg DMG & reinforced Frontline!';
            dispatchAction(SpatialActionEvent(
              id: 'ult_${currentTick}_${unit.id}',
              attackerId: unit.id,
              attackerName: unit.name,
              skillName: 'Sovereign Cleave',
              targetId: target.id,
              targetName: target.name,
              damage: dmg,
              isCrit: true,
              isPlayerAttacker: true,
              pattern: TargetPattern.horizontalRowScythe,
              timestampMs: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        } else if (unit.archetype == UnitArchetype.reachMidline) {
          // Skirmisher / Marksman Deadeye Execution: 260 DMG + 3 Bleed
          final target = targetUnit ?? enemyUnits.where((u) => u.isAlive).firstOrNull;
          if (target != null) {
            final dmg = target.takeDamage((unit.effectiveAttack * 2.4).round(), isPhysical: true);
            target.bleedStacks += 3;
            addLog('${unit.name} unleashes Deadeye Execution for $dmg DMG & 3 Bleed stacks!');
            lastBannerMessage = '🎯 DEADEYE EXECUTION: ${unit.name} dealt $dmg CRIT & applied 3 Bleed!';
            dispatchAction(SpatialActionEvent(
              id: 'ult_${currentTick}_${unit.id}',
              attackerId: unit.id,
              attackerName: unit.name,
              skillName: 'Deadeye Execution',
              targetId: target.id,
              targetName: target.name,
              damage: dmg,
              bleedStacks: 3,
              isCrit: true,
              isPlayerAttacker: true,
              pattern: TargetPattern.singleTarget,
              timestampMs: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        } else {
          // Caster Celestial Burst: 200 Magic DMG across enemies + heals allies
          final target = targetUnit ?? enemyUnits.where((u) => u.isAlive).firstOrNull;
          if (target != null) {
            final dmg = target.takeDamage((unit.effectiveAttack * 2.0).round(), isPhysical: false);
            for (final ally in playerUnits.where((u) => u.isAlive)) {
              ally.hp = min(ally.maxHp, ally.hp + 60);
            }
            addLog('${unit.name} unleashes Celestial Surge for $dmg DMG & heals squad for 60 HP!');
            lastBannerMessage = '✨ CELESTIAL SURGE: ${unit.name} dealt $dmg DMG & restored squad HP!';
            dispatchAction(SpatialActionEvent(
              id: 'ult_${currentTick}_${unit.id}',
              attackerId: unit.id,
              attackerName: unit.name,
              skillName: 'Celestial Surge',
              targetId: target.id,
              targetName: target.name,
              damage: dmg,
              isCrit: true,
              isPlayerAttacker: true,
              pattern: TargetPattern.stAshlarCross,
              timestampMs: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
        break;
    }

    // Check if this Ultimate cleared the current enemy wave and remaining waves exist
    advanceToNextWaveIfPending();

    notifyListeners();
    return true;
  }
}
