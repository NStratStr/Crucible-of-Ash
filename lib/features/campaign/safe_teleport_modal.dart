import 'package:flutter/material.dart';

class SafeTeleportModal extends StatelessWidget {
  final int accumulatedIchor;
  final int accumulatedOre;
  final int accumulatedSigils;
  final VoidCallback onConfirmExtraction;
  final VoidCallback onContinueDelve;

  const SafeTeleportModal({
    super.key,
    required this.accumulatedIchor,
    required this.accumulatedOre,
    required this.accumulatedSigils,
    required this.onConfirmExtraction,
    required this.onContinueDelve,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int accumulatedIchor,
    required int accumulatedOre,
    required int accumulatedSigils,
    required VoidCallback onConfirmExtraction,
    required VoidCallback onContinueDelve,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SafeTeleportModal(
        accumulatedIchor: accumulatedIchor,
        accumulatedOre: accumulatedOre,
        accumulatedSigils: accumulatedSigils,
        onConfirmExtraction: onConfirmExtraction,
        onContinueDelve: onContinueDelve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF12121C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.8),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RUNIC TELEPORT CIRCLE',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'SAFE DUNGEON EXTRACTION THRESHOLD',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Narrative Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181826),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'An ancient azure teleportation glyph glows beneath the stone rubble. '
                'You may activate this stone to safely extract your brigade to the Citadel with 100% of your plundered haul, '
                'or bypass it and press deeper into the Boss Chamber.\n\n'
                'WARNING: If your brigade falls deeper in the delve, only 50% of your accumulated loot will be recovered!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current Delve Loot Sack
            const Text(
              'SECURED RUN HAUL:',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLootTile(
                    icon: Icons.water_drop,
                    color: const Color(0xFFEF5350),
                    label: 'RAW ICHOR',
                    amount: '+$accumulatedIchor',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLootTile(
                    icon: Icons.diamond_outlined,
                    color: const Color(0xFF80CBC4),
                    label: 'CURSED ORE',
                    amount: '+$accumulatedOre',
                  ),
                ),
                if (accumulatedSigils > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLootTile(
                      icon: Icons.military_tech,
                      color: const Color(0xFFFFD54F),
                      label: 'SIGILS',
                      amount: '+$accumulatedSigils',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                // Push Deeper Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text(
                      'PRESS DEEPER',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onContinueDelve();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Extract with 100% Loot Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.exit_to_app, size: 16, color: Colors.black),
                    label: const Text(
                      'EXTRACT (100% LOOT)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirmExtraction();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLootTile({
    required IconData icon,
    required Color color,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}
