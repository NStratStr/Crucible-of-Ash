import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/spatial_combat_models.dart';

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
  bool isRunning = true;
  double simulationSpeed = 1.0;
  bool isBulletTime = false;

  // Recent Event Logs & Popups
  final List<String> combatLogs = [];
  String? lastBannerMessage;
  SpatialActionEvent? activeActionEvent;
  bool isActionPauseEnabled = false;

  SpatialCombatEngine() {
    setupSunderAtAshenGate();
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

    // Focus Passive Accumulation: Lady Valeria fills 1 Focus per 40 ticks (~1.33 seconds)
    if (currentTick % 40 == 0 && focus < maxFocus) {
      focus++;
      notifyListeners();
    }

    // Bleed Ticks (Every 30 ticks = 1 second)
    if (currentTick % 30 == 0) {
      for (final unit in [...playerUnits, ...enemyUnits]) {
        if (unit.isAlive && unit.bleedStacks > 0) {
          final bleedDmg = unit.bleedStacks * 18;
          unit.takeDamage(bleedDmg, ignoreArmor: true);
          addLog('${unit.name} suffers $bleedDmg Bleed damage ($unit.hp/${unit.maxHp} HP).');
        }
      }
    }

    // Step AP Accumulation for all living units
    final allUnits = [...enemyUnits, ...playerUnits].where((u) => u.isAlive).toList();
    for (final unit in allUnits) {
      unit.currentAp += unit.speed;
    }

    // Check impending Boss Intents (e.g. Gorgoroth's T-Shaped Cleave at Tick 135)
    final gorgoroth = enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull;
    if (gorgoroth != null) {
      if (currentTick == 135 && gorgoroth.pendingIntent == null) {
        // Wind up Apex Intent: Molten Great-Cleaver (Execution at Tick 150)
        // Strikes primary Col 2 Frontline (col:1, row:0), Col 3 Frontline (col:2, row:0), and Col 2 Midline (col:1, row:1).
        // Shifting laterally into Col 1 (col:0, row:0) dodges the cleave completely per Section 4.2!
        final telegraphNodes = [
          const GridNode(column: 1, row: 0), // Front Col 2 (primary target)
          const GridNode(column: 2, row: 0), // Front Col 3 (lateral splash toward Col 3)
          const GridNode(column: 1, row: 1), // Mid Col 2 (deep shockwave)
        ];
        gorgoroth.pendingIntent = SpatialTelegraphIntent(
          id: 'cleave_intent_1',
          skillName: 'Molten Great-Cleaver',
          pattern: TargetPattern.tShapedCleave,
          originCol: 1,
          originRow: 0,
          targetNodes: telegraphNodes,
          triggerTick: 150,
          totalWindupTicks: 15,
          rawDamage: 280,
        );
        lastBannerMessage = '⚠️ GORGOROTH WINDS UP: MOLTEN GREAT-CLEAVER!';
        addLog('TELEGRAPH: Gorgoroth prepares Molten Great-Cleaver striking Col 2 T-Cleave!');
      }

      // Check Intent Trigger
      if (gorgoroth.pendingIntent != null && currentTick >= gorgoroth.pendingIntent!.triggerTick) {
        _resolveGorgorothCleave(gorgoroth, gorgoroth.pendingIntent!);
        gorgoroth.pendingIntent = null;
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
      _executeUnitTurn(unit);
      unit.currentAp %= tickThreshold; // Consume turn
    }

    notifyListeners();
  }

  void _resolveGorgorothCleave(CombatUnitState boss, SpatialTelegraphIntent intent) {
    addLog('${boss.name} releases ${intent.skillName} across T-Cleave zone!');
    int hitCount = 0;
    for (final node in intent.targetNodes) {
      final occupant = playerUnits.where((u) => u.isAlive && u.occupies(node.column, node.row)).firstOrNull;
      if (occupant != null) {
        final dmg = occupant.takeDamage(intent.rawDamage);
        addLog('CRITICAL HIT: ${occupant.name} struck for $dmg DMG at (Col ${node.column + 1}, Row ${node.row})!');
        hitCount++;
      }
    }
    if (hitCount == 0) {
      addLog('CLANG! The Great-Cleaver crashed onto barren flagstone—MISS!');
      lastBannerMessage = '🛡️ DODGE! Cleave struck empty tiles!';
    }
  }

  void _executeUnitTurn(CombatUnitState unit) {
    if (unit.id == 'pyre_zealot') {
      // Tick 80: Pyre Zealot strikes Facing Col 5. Facing player Front/Mid is empty -> Strikes Backline Sun-Smith
      final target = _resolveColumnTarget(unitCol: 4, targetingPlayers: true);
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        addLog('${unit.name} strikes ${target.name} for $dmg DMG ($target.hp/${target.maxHp} HP).');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Pyre Skewer',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: false,
          pattern: TargetPattern.piercingColumnSkewer,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'sanguine_blade') {
      // Sanguine Blade: Sits in Col 4 Midline. Direct facing Col 4 is empty; cascades to adjacent Col 3 (Gorgoroth)
      final target = _resolveColumnTarget(unitCol: 3, targetingPlayers: false) ??
          _resolveColumnTarget(unitCol: 2, targetingPlayers: false);
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        target.bleedStacks += 2;
        addLog('${unit.name} executes Flensing Thrust on ${target.name} for $dmg DMG & 2 BLEED stacks!');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Flensing Thrust',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          bleedStacks: 2,
          isPlayerAttacker: true,
          pattern: TargetPattern.reachMidToFront,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'cinder_witch') {
      // Cinder Witch: Launches flame bolt down Col 2
      final target = _resolveColumnTarget(unitCol: 1, targetingPlayers: true);
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        addLog('${unit.name} casts Cinder Orb on ${target.name} for $dmg DMG.');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Cinder Orb',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: false,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'lady_valeria') {
      // Valeria basic attack down facing column
      final target = _resolveColumnTarget(unitCol: unit.occupiedNodes.first.column, targetingPlayers: false);
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        addLog('${unit.name} slashes ${target.name} for $dmg DMG.');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Sunbrand Slash',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: true,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'iron_footman') {
      final target = _resolveColumnTarget(unitCol: unit.occupiedNodes.first.column, targetingPlayers: false);
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        addLog('${unit.name} bashes ${target.name} for $dmg DMG.');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Shield Bash',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: true,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } else if (unit.id == 'sun_smith') {
      final target = enemyUnits.where((u) => u.isAlive).firstOrNull;
      if (target != null) {
        final dmg = target.takeDamage(unit.attack);
        addLog('${unit.name} fires Sun-Bolts at ${target.name} for $dmg DMG.');
        dispatchAction(SpatialActionEvent(
          id: 'act_${currentTick}_${unit.id}',
          attackerId: unit.id,
          attackerName: unit.name,
          skillName: 'Sun-Bolt Volley',
          targetId: target.id,
          targetName: target.name,
          damage: dmg,
          isPlayerAttacker: true,
          pattern: TargetPattern.singleTarget,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
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

  /// Tactical Plinth Triage: Player shifts unit across nodes in bullet-time
  bool movePlayerUnit(String unitId, int targetCol, int targetRow) {
    final unit = playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    if (unit == null) return false;
    if (unit.isDisplacementImmune) {
      addLog('${unit.name} has Mass Tenacity and cannot be shifted!');
      return false;
    }

    // Restrict movement to unit's moveRange (e.g. 1 tile adjacent/diagonal)
    if (!unit.canMoveTo(targetCol, targetRow)) {
      addLog('${unit.name} cannot reach (Col ${targetCol + 1}, Row $targetRow)! Movement limit is ${unit.moveRange} tile(s).');
      return false;
    }

    // Check if target node is empty
    final isOccupied = playerUnits.any((u) => u.isAlive && u.occupies(targetCol, targetRow));
    if (isOccupied) {
      addLog('Node (Col ${targetCol + 1}, Row $targetRow) is occupied!');
      return false;
    }

    final oldCol = unit.occupiedNodes.first.column;
    final oldRow = unit.occupiedNodes.first.row;
    final success = unit.repositionTo([GridNode(column: targetCol, row: targetRow, occupantUnitId: unit.id)]);
    if (success) {
      addLog('${unit.name} shifted from (Col ${oldCol + 1}, Row $oldRow) to (Col ${targetCol + 1}, Row $targetRow)! [-2,000 AP]');
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
      lastBannerMessage = '🛡️ PHALANX INTERCEPT: +35 Armor to ${recipient.name}!';
      addLog('CAST: Phalanx Intercept fortified ${recipient.name} (+35 Armor)!');

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
    }

    notifyListeners();
    return true;
  }
}
