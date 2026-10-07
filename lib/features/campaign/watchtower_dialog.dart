import 'package:flutter/material.dart';
import '../../shared/models/relic_entity.dart';
import '../generals/general_command_service.dart';
import '../relics/relic_service.dart';
import 'campaign_node.dart';

class WatchtowerDialog extends StatelessWidget {
  final CampaignNode node;
  final RelicService relicService;
  final GeneralCommandService commandService;
  final ValueChanged<int> onGainIchor;
  final VoidCallback onDismiss;

  const WatchtowerDialog({
    super.key,
    required this.node,
    required this.relicService,
    required this.commandService,
    required this.onGainIchor,
    required this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required CampaignNode node,
    required RelicService relicService,
    required GeneralCommandService commandService,
    required ValueChanged<int> onGainIchor,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WatchtowerDialog(
        node: node,
        relicService: relicService,
        commandService: commandService,
        onGainIchor: onGainIchor,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131318),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF00ACC1), width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.visibility, color: Color(0xFF00E5FF), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'OBSIDIAN WATCHTOWER',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF142426),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00838F).withValues(alpha: 0.5)),
              ),
              child: const Text(
                'Perched upon a spire of volcanic glass, your scouts peer through the creeping gloom. '
                'The formations of the advancing horde are laid bare. Direct your vantage point.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'SCOUTING OBJECTIVES:',
              style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Choice 1: Chart Enemy Blindspots (+250 Ichor)
            _buildChoiceButton(
              icon: Icons.radar,
              color: const Color(0xFF00E5FF),
              title: 'Chart Enemy Blindspots',
              subtitle: 'Extract tactical routes: Harvest +250 Ichor from mapped supply veins.',
              onTap: () {
                Navigator.pop(context);
                onGainIchor(250);
                onDismiss();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tactical routes mapped: Harvested +250 Ichor!'),
                    backgroundColor: Color(0xFF006064),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Choice 2: Signal the Commander (Gain +1 Focus)
            _buildChoiceButton(
              icon: Icons.shield_moon,
              color: const Color(0xFFE5A93C),
              title: 'War Horn of Command',
              subtitle: 'Sound the signal: Banks +1 Command Focus for the General before the next battle.',
              onTap: () {
                Navigator.pop(context);
                commandService.registerCombatDamage(500); // Guarantees +1 Focus
                onDismiss();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('War horn sounded: General gained +1 Command Focus!'),
                    backgroundColor: Color(0xFF4527A0),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Choice 3: Plunder Spire Armory (Forge Rare Relic)
            _buildChoiceButton(
              icon: Icons.inventory_2,
              color: const Color(0xFFAB47BC),
              title: 'Plunder Spire Armory',
              subtitle: 'Unseal the garrison lockbox: Claim a Rare Armament Relic.',
              onTap: () {
                final drop = relicService.forgeRandomRelic(rarity: RelicRarity.rare);
                Navigator.pop(context);
                onDismiss();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Armory unsealed: Recovered ${drop.displayName}!'),
                    backgroundColor: const Color(0xFF4A148C),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF181820),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
