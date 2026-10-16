import 'package:flutter/material.dart';
import '../../core/combat_math.dart';

enum CampaignNodeType {
  skirmish,    // Standard brigade fight
  elite,       // Dangerous elite monster
  altar,       // Sacrifice HP for stat buff
  restHaven,   // Heal squad HP or upgrade relic
  crypt,       // Narrative mystery event
  watchtower,  // Scout upcoming tiers and reveal enemy affinities
  boss,        // Chapter World Titan
}

/// Environmental Hazards on Campaign Overworld Nodes (GDD §4.3)
enum CampaignHazardType {
  none,
  ashenEmberStorm,  // Chapter 1: Scorching winds; non-vanguards suffer minor Burn
  miasmaMire,       // Chapter 2: Necrotic swamp; healing reduced by 25%
  voidDistortion,   // Chapter 3: Gravity flux; AP build rate fluctuated +/- 15%
}

extension CampaignHazardExtension on CampaignHazardType {
  String get displayName {
    switch (this) {
      case CampaignHazardType.ashenEmberStorm:
        return 'Ashen Emberstorm';
      case CampaignHazardType.miasmaMire:
        return 'Necrotic Miasma';
      case CampaignHazardType.voidDistortion:
        return 'Abyssal Void Flux';
      case CampaignHazardType.none:
        return 'Calm';
    }
  }

  String get shortDescription {
    switch (this) {
      case CampaignHazardType.ashenEmberStorm:
        return 'Scorching winds deal 2% Max HP burn damage to non-Vanguard units per turn.';
      case CampaignHazardType.miasmaMire:
        return 'Blighted vapors reduce all combat healing & shield generation by 25%.';
      case CampaignHazardType.voidDistortion:
        return 'Gravity flux causes turn meters & AP accumulation to fluctuate unpredictably.';
      case CampaignHazardType.none:
        return 'No atmospheric penalties.';
    }
  }

  IconData get icon {
    switch (this) {
      case CampaignHazardType.ashenEmberStorm:
        return Icons.local_fire_department;
      case CampaignHazardType.miasmaMire:
        return Icons.science;
      case CampaignHazardType.voidDistortion:
        return Icons.cyclone;
      case CampaignHazardType.none:
        return Icons.shield;
    }
  }

  Color get color {
    switch (this) {
      case CampaignHazardType.ashenEmberStorm:
        return const Color(0xFFFF5722);
      case CampaignHazardType.miasmaMire:
        return const Color(0xFF00E676);
      case CampaignHazardType.voidDistortion:
        return const Color(0xFFBA68C8);
      case CampaignHazardType.none:
        return Colors.white54;
    }
  }
}

@immutable
class CampaignNode {
  final String id;
  final int depth;               // Column tier (0 to 7)
  final double verticalRatio;    // Normalized vertical position (0.0 to 1.0)
  final CampaignNodeType type;
  final String name;
  final String description;
  final List<String> nextNodeIds; // Forward edges to depth + 1
  final bool isVisited;
  final bool isReachable;
  final bool isCurrent;
  final int rewardIchor;
  final int rewardOre;           // Cursed Ore for Relic Forge
  final int rewardSigils;        // Bloodline Sigils for Phylactery / Pureblood
  final bool isScouted;          // Revealed via Watchtower reconnaissance
  final List<Archetype> scoutedAffinities; // Enemy brigade roles at this node
  final CampaignHazardType hazard;        // Atmospheric hazard modifier
  final String? customThumbnailAsset;     // Thematic thumbnail for encounter cards

  const CampaignNode({
    required this.id,
    required this.depth,
    required this.verticalRatio,
    required this.type,
    required this.name,
    required this.description,
    required this.nextNodeIds,
    this.isVisited = false,
    this.isReachable = false,
    this.isCurrent = false,
    this.rewardIchor = 150,
    this.rewardOre = 25,
    this.rewardSigils = 0,
    this.isScouted = false,
    this.scoutedAffinities = const [],
    this.hazard = CampaignHazardType.none,
    this.customThumbnailAsset,
  });

  CampaignNode copyWith({
    bool? isVisited,
    bool? isReachable,
    bool? isCurrent,
    bool? isScouted,
    List<Archetype>? scoutedAffinities,
    int? rewardIchor,
    int? rewardOre,
    int? rewardSigils,
    CampaignHazardType? hazard,
    String? customThumbnailAsset,
  }) {
    return CampaignNode(
      id: id,
      depth: depth,
      verticalRatio: verticalRatio,
      type: type,
      name: name,
      description: description,
      nextNodeIds: nextNodeIds,
      isVisited: isVisited ?? this.isVisited,
      isReachable: isReachable ?? this.isReachable,
      isCurrent: isCurrent ?? this.isCurrent,
      rewardIchor: rewardIchor ?? this.rewardIchor,
      rewardOre: rewardOre ?? this.rewardOre,
      rewardSigils: rewardSigils ?? this.rewardSigils,
      isScouted: isScouted ?? this.isScouted,
      scoutedAffinities: scoutedAffinities ?? this.scoutedAffinities,
      hazard: hazard ?? this.hazard,
      customThumbnailAsset: customThumbnailAsset ?? this.customThumbnailAsset,
    );
  }
}

