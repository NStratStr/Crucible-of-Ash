import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

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

    test('Campaign includes both Rest Haven and Watchtower scouting nodes at Depth 3', () {
      final nodes = CampaignMapGenerator.generateCuratedCampaign();
      final depth3Nodes = nodes.where((n) => n.depth == 3).toList();

      expect(depth3Nodes.length, equals(2));
      expect(depth3Nodes.any((n) => n.type == CampaignNodeType.restHaven), isTrue);
      expect(depth3Nodes.any((n) => n.type == CampaignNodeType.watchtower), isTrue);

      // Both branch into boss
      for (final n in depth3Nodes) {
        expect(n.nextNodeIds, contains('node_4_boss'));
      }
    });

    test('Chapter 2 (Sunken Necropolis) generates depths 0 to 5 terminating in Sunken Lich King', () {
      final nodes = CampaignMapGenerator.generateCampaignForChapter(2);

      expect(nodes.isNotEmpty, isTrue);

      final startingNodes = nodes.where((n) => n.depth == 0).toList();
      expect(startingNodes.every((n) => n.isReachable), isTrue);

      // Verify all forward node links exist
      final allNodeIds = nodes.map((n) => n.id).toSet();
      for (final node in nodes) {
        for (final nextId in node.nextNodeIds) {
          expect(allNodeIds.contains(nextId), isTrue,
              reason: 'Node ${node.id} links to unknown node $nextId in Ch 2');
        }
      }

      final bossNode = nodes.firstWhere((n) => n.type == CampaignNodeType.boss);
      expect(bossNode.depth, equals(5));
      expect(bossNode.name, contains('Sunken Lich King'));
      expect(bossNode.nextNodeIds.isEmpty, isTrue);
    });

    test('Chapter 3 (Abyssal Rift) generates depths 0 to 6 terminating in World Titan Sovereign', () {
      final nodes = CampaignMapGenerator.generateCampaignForChapter(3);

      expect(nodes.isNotEmpty, isTrue);

      final startingNodes = nodes.where((n) => n.depth == 0).toList();
      expect(startingNodes.every((n) => n.isReachable), isTrue);

      // Verify all forward node links exist
      final allNodeIds = nodes.map((n) => n.id).toSet();
      for (final node in nodes) {
        for (final nextId in node.nextNodeIds) {
          expect(allNodeIds.contains(nextId), isTrue,
              reason: 'Node ${node.id} links to unknown node $nextId in Ch 3');
        }
      }

      final bossNode = nodes.firstWhere((n) => n.type == CampaignNodeType.boss);
      expect(bossNode.depth, equals(6));
      expect(bossNode.name, contains('Titan Sovereign'));
      expect(bossNode.rewardSigils, equals(4));
    });

    test('StarterBrigades scales skirmish and elite enemies across Chapters 1, 2, and 3', () {
      final ch1Skirmish = StarterBrigades.createSkirmishEnemiesForChapter(1);
      final ch2Skirmish = StarterBrigades.createSkirmishEnemiesForChapter(2);
      final ch3Skirmish = StarterBrigades.createSkirmishEnemiesForChapter(3);

      expect(ch1Skirmish.first.level, lessThan(ch2Skirmish.first.level));
      expect(ch2Skirmish.first.level, lessThan(ch3Skirmish.first.level));
      expect(ch2Skirmish.first.generation, equals(2));
      expect(ch3Skirmish.first.generation, equals(3));

      final ch1Elite = StarterBrigades.createEliteEnemiesForChapter(1);
      final ch2Elite = StarterBrigades.createEliteEnemiesForChapter(2);
      final ch3Elite = StarterBrigades.createEliteEnemiesForChapter(3);

      expect(ch1Elite.first.maxHp, lessThan(ch2Elite.first.maxHp));
      expect(ch2Elite.first.maxHp, lessThan(ch3Elite.first.maxHp));
      expect(ch3Elite.first.generation, equals(3));
    });
  });
}
