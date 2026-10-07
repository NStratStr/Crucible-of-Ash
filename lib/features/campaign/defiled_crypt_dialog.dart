import 'package:flutter/material.dart';

enum DefiledCryptChoice {
  desecrateTomb, // High risk / high reward: chance of rare relic + 250 ichor vs curse
  rebindThrall,   // Unseal sarcophagus to recruit a Crypt Assassin Thrall
  purifyTomb,     // Perform rites to heal 40% squad HP
}

class DefiledCryptDialog extends StatelessWidget {
  const DefiledCryptDialog({super.key});

  static Future<DefiledCryptChoice?> show(BuildContext context) {
    return showDialog<DefiledCryptChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DefiledCryptDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131318),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF6A1B9A), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFFAB47BC), size: 24),
                SizedBox(width: 8),
                Text(
                  'THE DEFILED SARCOPHAGUS',
                  style: TextStyle(
                    color: Color(0xFFE5A93C),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'A cracked sarcophagus of defiled black iron stands half-opened in the gloom. '
              'Poisonous miasma curls from within, carrying whispers of forgotten lineage.',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildChoiceButton(
              context: context,
              title: 'DESECRATE THE TOMB (HIGH RISK)',
              subtitle: 'Plunder ancient treasures. Gain +250 Ichor and an Ancient Relic.',
              icon: Icons.auto_awesome,
              color: const Color(0xFFFFB300),
              onTap: () => Navigator.pop(context, DefiledCryptChoice.desecrateTomb),
            ),
            const SizedBox(height: 10),
            _buildChoiceButton(
              context: context,
              title: 'REBIND THE RESTLESS CORPSE',
              subtitle: 'Unbind and animate a Generation 1 Crypt Assassin Thrall for the Crucible.',
              icon: Icons.person_add,
              color: const Color(0xFFAB47BC),
              onTap: () => Navigator.pop(context, DefiledCryptChoice.rebindThrall),
            ),
            const SizedBox(height: 10),
            _buildChoiceButton(
              context: context,
              title: 'PERFORM PURIFICATION RITES',
              subtitle: 'Cleanse the corrupted miasma, restoring 40% squad vitality.',
              icon: Icons.healing,
              color: const Color(0xFF81C784),
              onTap: () => Navigator.pop(context, DefiledCryptChoice.purifyTomb),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
