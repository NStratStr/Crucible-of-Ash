import '../../core/combat_math.dart';
import 'campaign_node.dart';

class CampaignMapGenerator {
  /// Generates a curated, connected campaign trail across 6 depth tiers.
  static List<CampaignNode> generateCuratedCampaign() {
    return [
      // Depth 0: Incursion
      const CampaignNode(
        id: 'node_0_a',
        depth: 0,
        verticalRatio: 0.35,
        type: CampaignNodeType.skirmish,
        name: 'Ashen Outpost',
        description: 'Vanguard scouts defending the perimeter.',
        nextNodeIds: ['node_1_a', 'node_1_b'],
        isReachable: true,
        rewardIchor: 100,
        rewardOre: 20,
        scoutedAffinities: [Archetype.juggernaut, Archetype.marksman],
      ),
      const CampaignNode(
        id: 'node_0_b',
        depth: 0,
        verticalRatio: 0.65,
        type: CampaignNodeType.skirmish,
        name: 'Sunken Trench',
        description: 'Blighted beasts prowling through the mud.',
        nextNodeIds: ['node_1_b', 'node_1_c'],
        isReachable: true,
        rewardIchor: 100,
        rewardOre: 25,
        scoutedAffinities: [Archetype.skirmisher, Archetype.occultist],
      ),

      // Depth 1: Scouting & Sacrifice
      const CampaignNode(
        id: 'node_1_a',
        depth: 1,
        verticalRatio: 0.20,
        type: CampaignNodeType.altar,
        name: 'Crucible Siphon Altar',
        description: 'Ancient stone altar dripping with essence.',
        nextNodeIds: ['node_2_a'],
        rewardIchor: 200,
        rewardOre: 15,
      ),
      const CampaignNode(
        id: 'node_1_b',
        depth: 1,
        verticalRatio: 0.50,
        type: CampaignNodeType.skirmish,
        name: 'Fallen Caravan',
        description: 'Ambushed scavengers guarding cursed relics.',
        nextNodeIds: ['node_2_a', 'node_2_b'],
        rewardIchor: 150,
        rewardOre: 35,
        scoutedAffinities: [Archetype.assassin, Archetype.support],
      ),
      const CampaignNode(
        id: 'node_1_c',
        depth: 1,
        verticalRatio: 0.80,
        type: CampaignNodeType.crypt,
        name: 'Chained Sarcophagus',
        description: 'Crypt seal containing lost generational lore.',
        nextNodeIds: ['node_2_b'],
        rewardIchor: 250,
        rewardOre: 40,
        rewardSigils: 1,
      ),

      // Depth 2: Divergence
      const CampaignNode(
        id: 'node_2_a',
        depth: 2,
        verticalRatio: 0.35,
        type: CampaignNodeType.elite,
        name: 'Abyssal Juggernaut',
        description: 'Heavily armored titan wielding an iron slab.',
        nextNodeIds: ['node_3_a', 'node_3_b'],
        rewardIchor: 350,
        rewardOre: 60,
        rewardSigils: 1,
        scoutedAffinities: [Archetype.juggernaut, Archetype.occultist],
      ),
      const CampaignNode(
        id: 'node_2_b',
        depth: 2,
        verticalRatio: 0.65,
        type: CampaignNodeType.skirmish,
        name: 'Ravenwood Thicket',
        description: 'Flock of winged skirmishers swooping low.',
        nextNodeIds: ['node_3_a', 'node_3_b'],
        rewardIchor: 180,
        rewardOre: 30,
        scoutedAffinities: [Archetype.skirmisher, Archetype.marksman],
      ),

      // Depth 3: Sanctuary or Scouting Spire
      const CampaignNode(
        id: 'node_3_a',
        depth: 3,
        verticalRatio: 0.35,
        type: CampaignNodeType.restHaven,
        name: 'Smoldering Haven',
        description: 'Rest threshold to bind wounds or refine armaments.',
        nextNodeIds: ['node_4_boss'],
        rewardIchor: 100,
        rewardOre: 20,
      ),
      const CampaignNode(
        id: 'node_3_b',
        depth: 3,
        verticalRatio: 0.65,
        type: CampaignNodeType.watchtower,
        name: 'Obsidian Spire',
        description: 'Scout upcoming Titan weak points or harvest supplies.',
        nextNodeIds: ['node_4_boss'],
        rewardIchor: 150,
        rewardOre: 50,
      ),

      // Depth 4: Chapter Gatekeeper Boss
      const CampaignNode(
        id: 'node_4_boss',
        depth: 4,
        verticalRatio: 0.50,
        type: CampaignNodeType.boss,
        name: 'Gorgoroth the Flayed',
        description: 'The Chapter World Titan towering over the Ashen Rift.',
        nextNodeIds: [],
        rewardIchor: 800,
        rewardOre: 120,
        rewardSigils: 2,
        scoutedAffinities: [Archetype.juggernaut, Archetype.occultist, Archetype.assassin],
      ),
    ];
  }
}
