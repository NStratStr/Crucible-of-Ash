import 'package:flutter/foundation.dart';

enum CampaignNodeType {
  skirmish,    // Standard brigade fight
  elite,       // Dangerous elite monster
  altar,       // Sacrifice HP for stat buff
  restHaven,   // Heal squad HP
  crypt,       // Narrative mystery event
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
  });

  CampaignNode copyWith({
    bool? isVisited,
    bool? isReachable,
    bool? isCurrent,
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
      rewardIchor: rewardIchor,
    );
  }
}
