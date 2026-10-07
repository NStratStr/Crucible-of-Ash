import 'package:flutter/material.dart';
import '../../shared/models/relic_entity.dart';
import '../relics/relic_service.dart';
import 'campaign_node.dart';

class RestHavenDialog extends StatelessWidget {
  final CampaignNode node;
  final VoidCallback onHealSquad;
  final RelicService relicService;
  final VoidCallback onGrantXp;
  final VoidCallback onDismiss;

  const RestHavenDialog({
    super.key,
    required this.node,
    required this.onHealSquad,
    required this.relicService,
    required this.onGrantXp,
    required this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required CampaignNode node,
    required VoidCallback onHealSquad,
    required RelicService relicService,
    required VoidCallback onGrantXp,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RestHavenDialog(
        node: node,
        onHealSquad: onHealSquad,
        relicService: relicService,
        onGrantXp: onGrantXp,
        onDismiss: onDismiss,
      ),
    );
  }

  void _upgradeFirstEquippedRelic(BuildContext context) {
    final equipped = relicService.allRelics.where((r) => r.equippedUnitId != null && r.canUpgrade).toList();
    if (equipped.isNotEmpty) {
      final target = equipped.first;
      final upgraded = relicService.upgradeRelic(target.id);
      Navigator.pop(context);
      onDismiss();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refinement Succeeded: ${upgraded.displayName} (+25% Stats)!'),
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    } else {
      // If no upgradable equipped relic, grant Ichor instead
      Navigator.pop(context);
      onDismiss();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No upgradable relics equipped. Salvaged materials for +150 Ichor!'),
          backgroundColor: Color(0xFFE5A93C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131318),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF43A047), width: 2),
      ),
      title: const Row(
        children: [
          Icon(Icons.healing, color: Color(0xFF81C784), size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'SANCTIFIED REST HAVEN',
              style: TextStyle(
                color: Color(0xFF81C784),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/bone_campfire.jpg',
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF43A047).withValues(alpha: 0.6), width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 8,
                    left: 10,
                    child: Text(
                      'CONSECRATED BONE PYRE',
                      style: TextStyle(
                        color: Color(0xFFE5A93C),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A241C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.5)),
              ),
              child: const Text(
                'The brigade halts within a hollowed sanctuary. Cold mist recedes before an altar of consecrated embers. '
                'Choose how your weary warriors prepare for the trials ahead.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'HAVEN RITES:',
              style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Choice 1: Communion of Blood (Heal Squad)
            _buildChoiceButton(
              icon: Icons.favorite,
              color: const Color(0xFF81C784),
              title: 'Communion of Blood',
              subtitle: 'Bind mortal wounds: Restore 40% HP to all active brigade vessels.',
              onTap: () {
                Navigator.pop(context);
                onHealSquad();
                onDismiss();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vessel wounds bound: +40% HP restored to Brigade!'),
                    backgroundColor: Color(0xFF1B5E20),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Choice 2: Anvil of Refinement (Upgrade Relic)
            _buildChoiceButton(
              icon: Icons.hardware,
              color: const Color(0xFFE5A93C),
              title: 'Anvil of Refinement',
              subtitle: 'Hone equipped weaponry: Upgrade 1 equipped relic by +1 refinement tier (+25% stats).',
              onTap: () => _upgradeFirstEquippedRelic(context),
            ),

            const SizedBox(height: 8),

            // Choice 3: Infuse Lineage (Grant XP)
            _buildChoiceButton(
              icon: Icons.auto_awesome,
              color: const Color(0xFF64B5F6),
              title: 'Meditative Crucible',
              subtitle: 'Focus martial discipline: Award +400 XP to all active brigade vessels.',
              onTap: () {
                Navigator.pop(context);
                onGrantXp();
                onDismiss();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Martial focus awakened: +400 XP granted to Brigade!'),
                    backgroundColor: Color(0xFF0D47A1),
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
