import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/models/relic_entity.dart';
import 'delve_models.dart';

/// Service orchestrating the Catacomb Delve procedural expedition,
/// persistent squad attrition, torchlight gloom mechanics, and risk/reward extraction.
class DelveService extends ChangeNotifier {
  final Random _rng = Random();

  int currentFloor = 1;
  int maxFloorReached = 1;
  int torchlight = 100; // 0 to 100
  int cryptKeys = 2; // Keys available for Vault of Antiquities

  // Accumulated Delve Loot Sack (Risk & Reward: 100% extract vs 50% wipe)
  int accumulatedIchor = 0;
  int accumulatedOre = 0;
  int accumulatedSigils = 0;
  int accumulatedPlinthShards = 0;
  final List<RelicEntity> accumulatedRelics = [];

  // Active Boons & Persistent Squad Health Map
  final List<DelveBoon> activeBoons = [];
  final Map<String, int> squadHpMap = {}; // unitId -> currentHp
  final Set<String> clearedRoomIds = {};
  String? currentRoomId;
  DelveFloor? currentFloorData;

  bool isRunActive = false;
  bool isExtracted = false;
  bool isWiped = false;

  /// High tension gloom mechanic: When torchlight <= 30, enemies deal +25% crits,
  /// but Petrified Plinth Shard drop rates are doubled!
  bool get isGloomActive => torchlight <= 30;

  /// Start a brand new expedition into the Catacombs
  void startNewRun(List<UnitEntity> squad) {
    currentFloor = 1;
    torchlight = 100;
    cryptKeys = max(1, 2);

    accumulatedIchor = 0;
    accumulatedOre = 0;
    accumulatedSigils = 0;
    accumulatedPlinthShards = 0;
    accumulatedRelics.clear();
    activeBoons.clear();
    clearedRoomIds.clear();
    currentRoomId = null;

    // Reset squad to full HP at the Citadel entrance
    squadHpMap.clear();
    for (final unit in squad) {
      squadHpMap[unit.id] = unit.maxHp;
    }

    isRunActive = true;
    isExtracted = false;
    isWiped = false;

    currentFloorData = _generateFloor(currentFloor);
    notifyListeners();
  }

  /// Generate a procedural 5-column branching catacomb floor
  DelveFloor _generateFloor(int floor) {
    final Map<String, DelveRoom> rooms = {};
    final List<List<String>> columns = List.generate(5, (_) => []);

    final double rewardScale = 1.0 + (floor - 1) * 0.45;

    // --- Column 0: Crypt Entrance (2 rooms, both accessible at start) ---
    final r0a = DelveRoom(
      id: 'f${floor}_c0_r0',
      floor: floor,
      column: 0,
      rowIndex: 0,
      type: DelveRoomType.skirmish,
      title: 'Bone-Littered Antechamber',
      description: 'Restless husks crawl from shallow grave trenches.',
      rewardIchor: (45 * rewardScale).round(),
      rewardOre: (12 * rewardScale).round(),
      rewardSigils: (2 * rewardScale).round(),
      rewardPlinthShards: 1,
      isAvailable: true,
    );
    final r0b = DelveRoom(
      id: 'f${floor}_c0_r1',
      floor: floor,
      column: 0,
      rowIndex: 1,
      type: DelveRoomType.skirmish,
      title: 'Damp Ossuary Gate',
      description: 'Chilled water drips upon calcified skeletons awaiting intruder blood.',
      rewardIchor: (50 * rewardScale).round(),
      rewardOre: (14 * rewardScale).round(),
      rewardSigils: (2 * rewardScale).round(),
      rewardPlinthShards: 1,
      isAvailable: true,
    );
    rooms[r0a.id] = r0a;
    rooms[r0b.id] = r0b;
    columns[0].addAll([r0a.id, r0b.id]);

    // --- Column 1: Corridors of Choice (Skirmish or Resting Shrine) ---
    final r1a = DelveRoom(
      id: 'f${floor}_c1_r0',
      floor: floor,
      column: 1,
      rowIndex: 0,
      type: DelveRoomType.skirmish,
      title: 'The Catacomb Aqueduct',
      description: 'Corrupted blood-rats and gargoyles prowl the stone ledges.',
      rewardIchor: (60 * rewardScale).round(),
      rewardOre: (16 * rewardScale).round(),
      rewardSigils: (3 * rewardScale).round(),
      rewardPlinthShards: 1,
    );
    final r1b = DelveRoom(
      id: 'f${floor}_c1_r1',
      floor: floor,
      column: 1,
      rowIndex: 1,
      type: DelveRoomType.restingShrine,
      title: 'Sanguine Sanctuary Shrine',
      description: 'An ancient basalt font offering rest, restorative incense, or bloody pacts.',
      rewardIchor: (15 * rewardScale).round(),
    );
    rooms[r1a.id] = r1a;
    rooms[r1b.id] = r1b;
    columns[1].addAll([r1a.id, r1b.id]);

    // Connect Col 0 -> Col 1
    r0a.connectedRoomIds.addAll([r1a.id, r1b.id]);
    r0b.connectedRoomIds.addAll([r1a.id, r1b.id]);

    // --- Column 2: Danger & Antiquities (Elite, Vault, or Skirmish) ---
    final affix1 = EliteAffix.allAffixes[_rng.nextInt(EliteAffix.allAffixes.length)];
    final r2a = DelveRoom(
      id: 'f${floor}_c2_r0',
      floor: floor,
      column: 2,
      rowIndex: 0,
      type: DelveRoomType.wanderingElite,
      title: 'Sepulcher Champion Chamber',
      description: 'A colossal bone-golem enshrouded in lethal elite sorcery.',
      rewardIchor: (110 * rewardScale).round(),
      rewardOre: (32 * rewardScale).round(),
      rewardSigils: (6 * rewardScale).round(),
      rewardPlinthShards: isGloomActive ? 4 : 2,
      eliteAffix: affix1,
    );
    final r2b = DelveRoom(
      id: 'f${floor}_c2_r1',
      floor: floor,
      column: 2,
      rowIndex: 1,
      type: DelveRoomType.vaultChest,
      title: 'Vault of Antiquities',
      description: 'Reinforced iron sarcophagus sealed with heavy runic padlocks.',
      rewardIchor: (80 * rewardScale).round(),
      rewardOre: (25 * rewardScale).round(),
      rewardSigils: (5 * rewardScale).round(),
      rewardPlinthShards: 2,
    );
    final r2c = DelveRoom(
      id: 'f${floor}_c2_r2',
      floor: floor,
      column: 2,
      rowIndex: 2,
      type: DelveRoomType.skirmish,
      title: 'Collapsing Burial Trench',
      description: 'Narrow corridor crowded with thralls eager to drag trespassers under.',
      rewardIchor: (65 * rewardScale).round(),
      rewardOre: (18 * rewardScale).round(),
      rewardSigils: (3 * rewardScale).round(),
      rewardPlinthShards: 1,
    );
    rooms[r2a.id] = r2a;
    rooms[r2b.id] = r2b;
    rooms[r2c.id] = r2c;
    columns[2].addAll([r2a.id, r2b.id, r2c.id]);

    // Connect Col 1 -> Col 2
    r1a.connectedRoomIds.addAll([r2a.id, r2b.id]);
    r1b.connectedRoomIds.addAll([r2b.id, r2c.id]);

    // --- Column 3: The Crossroads of Fate (Shrine or Elite) ---
    final affix2 = EliteAffix.allAffixes[_rng.nextInt(EliteAffix.allAffixes.length)];
    final r3a = DelveRoom(
      id: 'f${floor}_c3_r0',
      floor: floor,
      column: 3,
      rowIndex: 0,
      type: DelveRoomType.restingShrine,
      title: 'Forgotten Weeping Altar',
      description: 'Crimson vitae trickles through cracked obsidian drainage.',
      rewardIchor: (20 * rewardScale).round(),
    );
    final r3b = DelveRoom(
      id: 'f${floor}_c3_r1',
      floor: floor,
      column: 3,
      rowIndex: 1,
      type: DelveRoomType.wanderingElite,
      title: 'Crypt Arch-Inquisitor',
      description: 'A dual-scythe executioner guarding the threshold of the deep stairwell.',
      rewardIchor: (125 * rewardScale).round(),
      rewardOre: (36 * rewardScale).round(),
      rewardSigils: (7 * rewardScale).round(),
      rewardPlinthShards: isGloomActive ? 4 : 2,
      eliteAffix: affix2,
    );
    rooms[r3a.id] = r3a;
    rooms[r3b.id] = r3b;
    columns[3].addAll([r3a.id, r3b.id]);

    // Connect Col 2 -> Col 3
    r2a.connectedRoomIds.addAll([r3a.id, r3b.id]);
    r2b.connectedRoomIds.addAll([r3a.id, r3b.id]);
    r2c.connectedRoomIds.addAll([r3a.id, r3b.id]);

    // --- Column 4: Floor Culmination (Extraction Stone or Archon Boss on Floor 3/5) ---
    final bool isBossFloor = (floor == 3 || floor == 5);
    final r4 = DelveRoom(
      id: 'f${floor}_c4_r0',
      floor: floor,
      column: 4,
      rowIndex: 0,
      type: isBossFloor ? DelveRoomType.catacombArchon : DelveRoomType.extractionStone,
      title: isBossFloor ? 'Throne of the Catacomb Archon' : 'Stygian Extraction Runestone',
      description: isBossFloor
          ? 'The subterranean colossus awakes from centuries of slumber in stagnant ash.'
          : 'A shimmering azure runestone offering safe extraction to the Citadel or descent deeper.',
      rewardIchor: (isBossFloor ? 250 : 80) * rewardScale.round(),
      rewardOre: (isBossFloor ? 60 : 20) * rewardScale.round(),
      rewardSigils: (isBossFloor ? 12 : 5) * rewardScale.round(),
      rewardPlinthShards: isBossFloor ? 6 : 3,
    );
    rooms[r4.id] = r4;
    columns[4].add(r4.id);

    // Connect Col 3 -> Col 4
    r3a.connectedRoomIds.add(r4.id);
    r3b.connectedRoomIds.add(r4.id);

    return DelveFloor(
      floorNumber: floor,
      title: DelveFloor.getFloorTitle(floor),
      subtitle: DelveFloor.getFloorSubtitle(floor),
      rooms: rooms,
      columns: columns,
    );
  }

  /// Enter a room: drains torchlight and activates room state
  DelveRoom enterRoom(String roomId) {
    currentRoomId = roomId;
    final room = currentFloorData!.rooms[roomId]!;

    // Torchlight consumption: normally 14, 7 with Torchbearer's Resolve
    final bool hasTorchbearer = activeBoons.any((b) => b.id == 'torchbearer_resolve');
    final int drain = hasTorchbearer ? 7 : 14;
    torchlight = max(0, torchlight - drain);

    notifyListeners();
    return room;
  }

  /// Mark a room as cleared, deposit its rewards into the Delve Loot Sack,
  /// and make subsequent connected rooms available for traversal
  void completeRoom(String roomId, {
    int extraIchor = 0,
    int extraOre = 0,
    int extraSigils = 0,
    int extraPlinths = 0,
    RelicEntity? foundRelic,
  }) {
    clearedRoomIds.add(roomId);
    final room = currentFloorData?.rooms[roomId];

    if (room != null) {
      room.isCleared = true;

      // Calculate room spoils
      int earnedIchor = room.rewardIchor + extraIchor;
      int earnedOre = room.rewardOre + extraOre;
      int earnedSigils = room.rewardSigils + extraSigils;
      int earnedPlinths = room.rewardPlinthShards + extraPlinths;

      // Alchemist's Draught Boon: +50% Ichor
      if (activeBoons.any((b) => b.id == 'alchemists_draught')) {
        earnedIchor = (earnedIchor * 1.5).round();
      }

      // Stygian Gloom: 2x Plinth Shard drop rate!
      if (isGloomActive) {
        earnedPlinths *= 2;
      }

      accumulatedIchor += earnedIchor;
      accumulatedOre += earnedOre;
      accumulatedSigils += earnedSigils;
      accumulatedPlinthShards += earnedPlinths;

      if (foundRelic != null) {
        accumulatedRelics.add(foundRelic);
      }

      // Unlock connected forward rooms
      for (final nextId in room.connectedRoomIds) {
        final nextRoom = currentFloorData?.rooms[nextId];
        if (nextRoom != null) {
          nextRoom.isAvailable = true;
        }
      }
    }

    notifyListeners();
  }

  /// Rest at Sanguine Shrine / Blood Altar
  void restAtShrine({
    required bool healSquad,
    required bool stokeTorch,
    required bool takeBoon,
    DelveBoon? chosenBoon,
    required List<UnitEntity> squad,
  }) {
    if (healSquad) {
      // Mend living squad members by 35% max HP; revive fallen with 30%
      for (final unit in squad) {
        final current = squadHpMap[unit.id] ?? unit.maxHp;
        if (current <= 0) {
          squadHpMap[unit.id] = (unit.maxHp * 0.30).round();
        } else {
          squadHpMap[unit.id] = min(unit.maxHp, (current + unit.maxHp * 0.35).round());
        }
      }
    } else if (stokeTorch) {
      torchlight = min(100, torchlight + 45);
    } else if (takeBoon && chosenBoon != null) {
      // Blood sacrifice: costs 20% of current HP for all units
      for (final unit in squad) {
        final current = squadHpMap[unit.id] ?? unit.maxHp;
        squadHpMap[unit.id] = max(1, (current * 0.80).round());
      }
      if (!activeBoons.any((b) => b.id == chosenBoon.id)) {
        activeBoons.add(chosenBoon);
      }
    }

    notifyListeners();
  }

  /// Open Vault of Antiquities (Use Crypt Key or Force Lock)
  Map<String, dynamic> openVault({required bool useKey, required List<UnitEntity> squad}) {
    if (useKey) {
      if (cryptKeys > 0) cryptKeys--;
      final int bonusIchor = 90 + _rng.nextInt(60);
      final int bonusOre = 25 + _rng.nextInt(20);
      final int bonusPlinths = 2 + _rng.nextInt(3);
      accumulatedIchor += bonusIchor;
      accumulatedOre += bonusOre;
      accumulatedPlinthShards += bonusPlinths;
      notifyListeners();
      return {
        'success': true,
        'message': 'Runic lock clicks open smoothly with your Crypt Key!',
        'ichor': bonusIchor,
        'ore': bonusOre,
        'plinths': bonusPlinths,
      };
    } else {
      // Force lock: 70% success, 30% trapped
      final bool success = _rng.nextDouble() < 0.70;
      if (success) {
        final int bonusIchor = 60 + _rng.nextInt(40);
        final int bonusOre = 18 + _rng.nextInt(15);
        accumulatedIchor += bonusIchor;
        accumulatedOre += bonusOre;
        notifyListeners();
        return {
          'success': true,
          'message': 'With sheer force, the iron hinges snap open without springing the dart trap!',
          'ichor': bonusIchor,
          'ore': bonusOre,
          'plinths': 1,
        };
      } else {
        // Dart trap sprung: 20% HP damage to squad
        for (final unit in squad) {
          final current = squadHpMap[unit.id] ?? unit.maxHp;
          squadHpMap[unit.id] = max(1, (current * 0.80).round());
        }
        notifyListeners();
        return {
          'success': false,
          'message': 'TRAP SPRUNG! Toxic needle triggers, afflicting all squad members with 20% necrotic damage!',
          'ichor': 0,
          'ore': 0,
          'plinths': 0,
        };
      }
    }
  }

  /// Descend deeper to Floor X+1
  void descendNextFloor() {
    currentFloor++;
    maxFloorReached = max(maxFloorReached, currentFloor);
    torchlight = min(100, torchlight + 20); // Small kindle on new floor
    clearedRoomIds.clear();
    currentRoomId = null;
    currentFloorData = _generateFloor(currentFloor);
    notifyListeners();
  }

  /// Safe extraction: Player leaves with 100% of accumulated loot sack!
  Map<String, int> extractRun() {
    isRunActive = false;
    isExtracted = true;
    final spoils = {
      'ichor': accumulatedIchor,
      'ore': accumulatedOre,
      'sigils': accumulatedSigils,
      'plinths': accumulatedPlinthShards,
    };
    notifyListeners();
    return spoils;
  }

  /// Squad wiped: Player is defeated, salvaging only 50% consolation loot
  Map<String, int> wipeRun() {
    isRunActive = false;
    isWiped = true;
    final consolation = {
      'ichor': max(25, (accumulatedIchor * 0.50).round()),
      'ore': (accumulatedOre * 0.50).round(),
      'sigils': (accumulatedSigils * 0.50).round(),
      'plinths': (accumulatedPlinthShards * 0.50).round(),
    };
    notifyListeners();
    return consolation;
  }

  /// Update squad HP after a battle encounter
  void updateSquadHpAfterBattle(List<UnitEntity> allies) {
    bool allDead = true;
    for (final unit in allies) {
      squadHpMap[unit.id] = unit.currentHp;
      if (unit.currentHp > 0) {
        allDead = false;
      }
    }

    if (allDead) {
      wipeRun();
    } else {
      notifyListeners();
    }
  }

  /// Get current HP for a squad member, defaulting to maxHp if not yet tracked
  int getUnitHp(UnitEntity unit) {
    return squadHpMap[unit.id] ?? unit.maxHp;
  }
}
