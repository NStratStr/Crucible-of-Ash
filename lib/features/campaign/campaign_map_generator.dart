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
      ),

      // Depth 2: Divergence
      const CampaignNode(
        id: 'node_2_a',
        depth: 2,
        verticalRatio: 0.35,
        type: CampaignNodeType.elite,
        name: 'Abyssal Juggernaut',
        description: 'Heavily armored titan wielding an iron slab.',
        nextNodeIds: ['node_3_a'],
        rewardIchor: 350,
      ),
      const CampaignNode(
        id: 'node_2_b',
        depth: 2,
        verticalRatio: 0.65,
        type: CampaignNodeType.skirmish,
        name: 'Ravenwood Thicket',
        description: 'Flock of winged skirmishers swooping low.',
        nextNodeIds: ['node_3_a'],
        rewardIchor: 180,
      ),

      // Depth 3: Sanctuary Threshold
      const CampaignNode(
        id: 'node_3_a',
        depth: 3,
        verticalRatio: 0.50,
        type: CampaignNodeType.restHaven,
        name: 'Smoldering Haven',
        description: 'Rest threshold to bind wounds before the colossus.',
        nextNodeIds: ['node_4_boss'],
        rewardIchor: 100,
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
      ),
    ];
  }
}
