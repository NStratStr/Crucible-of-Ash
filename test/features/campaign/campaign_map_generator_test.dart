import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';

void main() {
  group('CampaignMapGenerator Tests', () {
    test('Generates connected campaign nodes across depth tiers with no isolated links', () {
      final nodes = CampaignMapGenerator.generateCuratedCampaign();

      expect(nodes.isNotEmpty, isTrue);

      // Depth 0 nodes are reachable by default
      final startingNodes = nodes.where((n) => n.depth == 0).toList();
      expect(startingNodes.every((n) => n.isReachable), isTrue);

      // Verify that every forward link points to a real existing node
      final allNodeIds = nodes.map((n) => n.id).toSet();
      for (final node in nodes) {
        for (final nextId in node.nextNodeIds) {
          expect(allNodeIds.contains(nextId), isTrue,
              reason: 'Node ${node.id} links to unknown node $nextId');
        }
      }

      // Final node is the boss
      final bossNode = nodes.last;
      expect(bossNode.type, equals(CampaignNodeType.boss));
      expect(bossNode.depth, equals(4));
      expect(bossNode.nextNodeIds.isEmpty, isTrue);
    });
  });
}
