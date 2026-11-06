import 'package:flutter/material.dart';

/// Room type in the Catacomb Delve procedural expedition
enum DelveRoomType {
  skirmish,         // Standard corrupted thralls encounter
  wanderingElite,   // Threat mini-boss with dangerous affix & high plinth drop rate
  restingShrine,    // Blood Altar / Rest Site (Heal, Stoke Torch, or Sacrifice)
  vaultChest,       // Vault of Antiquities (Runic locked chest with loot)
  extractionStone,  // Teleport Runestone: Extract 100% loot OR Descend deeper
  catacombArchon,   // Deep floor titan boss encounter
}

/// Affixes that modify elite combat encounters in the catacombs
class EliteAffix {
  final String id;
  final String name;
  final String description;
  final Color color;
  final IconData icon;

  const EliteAffix({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
  });

  static const List<EliteAffix> allAffixes = [
    EliteAffix(
      id: 'brimstone_aura',
      name: 'Brimstone Aura',
      description: 'Pulses 20 fire damage to adjacent allies every 3 seconds.',
      color: Color(0xFFFF5722),
      icon: Icons.local_fire_department,
    ),
    EliteAffix(
      id: 'vampiric_thirst',
      name: 'Vampiric Thirst',
      description: 'Heals 25% of all damage dealt to player frontliners.',
      color: Color(0xFFE91E63),
      icon: Icons.bloodtype,
    ),
    EliteAffix(
      id: 'spectral_ward',
      name: 'Spectral Ward',
      description: 'Takes 35% reduced damage from backline casters and rangers.',
      color: Color(0xFF00E5FF),
      icon: Icons.shield_moon,
    ),
    EliteAffix(
      id: 'kinetic_tremor',
      name: 'Kinetic Tremor',
      description: 'Counter-cleaves when posture broken, dealing 50 blunt damage.',
      color: Color(0xFFFFD54F),
      icon: Icons.electric_bolt,
    ),
  ];
}

/// Run-specific temporary boons acquired inside the catacombs
class DelveBoon {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const DelveBoon({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const List<DelveBoon> pool = [
    DelveBoon(
      id: 'obsidian_mantle',
      name: 'Obsidian Mantle',
      description: 'Allies begin every catacomb encounter with +30 Aegis Shield.',
      icon: Icons.security,
      color: Color(0xFF80D8FF),
    ),
    DelveBoon(
      id: 'vampiric_fervor',
      name: 'Vampiric Fervor',
      description: 'Critical strikes siphon 20% damage dealt as Vitae healing.',
      icon: Icons.favorite,
      color: Color(0xFFFF5252),
    ),
    DelveBoon(
      id: 'alchemists_draught',
      name: 'Alchemist\'s Draught',
      description: 'Enemies slain inside the delve drop +50% Raw Ash & Ichor.',
      icon: Icons.science,
      color: Color(0xFF69F0AE),
    ),
    DelveBoon(
      id: 'torchbearer_resolve',
      name: 'Torchbearer\'s Resolve',
      description: 'Torchlight drains 50% slower while traversing dark passages.',
      icon: Icons.wb_incandescent,
      color: Color(0xFFFFD54F),
    ),
    DelveBoon(
      id: 'titan_echo',
      name: 'Titan\'s Echo',
      description: 'The first ultimate command card used in battle is free.',
      icon: Icons.auto_awesome,
      color: Color(0xFFE040FB),
    ),
  ];
}

/// Individual node/room in a catacomb floor layout
class DelveRoom {
  final String id;
  final int floor;
  final int column; // Depth on this floor (0..4)
  final int rowIndex; // Vertical branch position (0..2)
  final DelveRoomType type;
  final String title;
  final String description;
  final List<String> connectedRoomIds;
  final int rewardIchor;
  final int rewardOre;
  final int rewardSigils;
  final int rewardPlinthShards;
  final EliteAffix? eliteAffix;
  bool isCleared;
  bool isAvailable;

  DelveRoom({
    required this.id,
    required this.floor,
    required this.column,
    required this.rowIndex,
    required this.type,
    required this.title,
    required this.description,
    this.connectedRoomIds = const [],
    this.rewardIchor = 0,
    this.rewardOre = 0,
    this.rewardSigils = 0,
    this.rewardPlinthShards = 0,
    this.eliteAffix,
    this.isCleared = false,
    this.isAvailable = false,
  });

  IconData get icon {
    switch (type) {
      case DelveRoomType.skirmish:
        return Icons.sports_kabaddi;
      case DelveRoomType.wanderingElite:
        return Icons.warning_amber_rounded;
      case DelveRoomType.restingShrine:
        return Icons.healing;
      case DelveRoomType.vaultChest:
        return Icons.inventory_2;
      case DelveRoomType.extractionStone:
        return Icons.vpn_key;
      case DelveRoomType.catacombArchon:
        return Icons.cruelty_free;
    }
  }

  Color get color {
    switch (type) {
      case DelveRoomType.skirmish:
        return const Color(0xFFFF7043);
      case DelveRoomType.wanderingElite:
        return const Color(0xFFFF1744);
      case DelveRoomType.restingShrine:
        return const Color(0xFF69F0AE);
      case DelveRoomType.vaultChest:
        return const Color(0xFFFFD54F);
      case DelveRoomType.extractionStone:
        return const Color(0xFF00E5FF);
      case DelveRoomType.catacombArchon:
        return const Color(0xFFD500F9);
    }
  }

  String get typeLabel {
    switch (type) {
      case DelveRoomType.skirmish:
        return 'CRYPT SKIRMISH';
      case DelveRoomType.wanderingElite:
        return 'WANDERING ELITE';
      case DelveRoomType.restingShrine:
        return 'BLOOD SHRINE';
      case DelveRoomType.vaultChest:
        return 'VAULT OF ANTIQUITIES';
      case DelveRoomType.extractionStone:
        return 'EXTRACTION RUNESTONE';
      case DelveRoomType.catacombArchon:
        return 'CATACOMB ARCHON';
    }
  }
}

/// Represents a single floor layer of the catacomb expedition
class DelveFloor {
  final int floorNumber;
  final String title;
  final String subtitle;
  final Map<String, DelveRoom> rooms;
  final List<List<String>> columns; // roomIds grouped by depth column (0 to 4)

  const DelveFloor({
    required this.floorNumber,
    required this.title,
    required this.subtitle,
    required this.rooms,
    required this.columns,
  });

  static String getFloorTitle(int floor) {
    switch (floor) {
      case 1:
        return 'FLOOR I: THE OSSUARY OF ASH';
      case 2:
        return 'FLOOR II: CRYPT OF WEEPING SKULLS';
      case 3:
        return 'FLOOR III: THE SEPULCHRAL LABYRINTH';
      case 4:
        return 'FLOOR IV: CATACOMBS OF CHRONIC MIASMA';
      default:
        return 'FLOOR V: THE STYGIAN CORE';
    }
  }

  static String getFloorSubtitle(int floor) {
    switch (floor) {
      case 1:
        return 'Shallow catacomb corridors haunted by wandering bone-harvesters';
      case 2:
        return 'Flooded blood conduits with dense elite thrall patrols';
      case 3:
        return 'Ancient labyrinthine halls where the Archon\'s guardians sleep';
      case 4:
        return 'Noxious miasma corridors where torchlight falters rapidly';
      default:
        return 'The abyssal floor where primordial colossi feed on raw vitae';
    }
  }
}
