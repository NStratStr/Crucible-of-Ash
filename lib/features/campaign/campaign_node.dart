import 'package:flutter/foundation.dart';
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
    );
  }
}
