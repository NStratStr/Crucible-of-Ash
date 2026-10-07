import 'package:flutter/material.dart';

enum BloodAltarChoice {
  bloodTithe,       // Sacrifice 25% squad HP for 350 Ichor + 2 Focus
  sanguineOffering, // Sacrifice 40% squad HP for Epic Relic
  walkAway,         // Leave unharmed
}

class BloodAltarDialog extends StatelessWidget {
  final int squadLivingCount;

  const BloodAltarDialog({
    super.key,
    required this.squadLivingCount,
  });

  static Future<BloodAltarChoice?> show(BuildContext context, {required int squadLivingCount}) {
    return showDialog<BloodAltarChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BloodAltarDialog(squadLivingCount: squadLivingCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131318),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fireplace, color: Color(0xFFB3261E), size: 24),
                SizedBox(width: 8),
                Text(
                  'ALTAR OF ANCESTRAL BLOOD',
                  style: TextStyle(
                    color: Color(0xFFE5A93C),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFB3261E), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB3261E).withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/blood_altar_sigil.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.fireplace, color: Color(0xFFB3261E), size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'A jagged obsidian slab groans as raw vitae pulses through carved stone gutters. '
              'The ancient slumbering entity demands sacrifice in exchange for dark power.',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildChoiceButton(
              context: context,
              title: 'BLOOD TITHE (SACRIFICE 25% SQUAD HP)',
              subtitle: 'Extract +350 Crucible Ichor & +2 Commander Focus.',
              icon: Icons.water_drop,
              color: const Color(0xFFB3261E),
              onTap: () => Navigator.pop(context, BloodAltarChoice.bloodTithe),
            ),
            const SizedBox(height: 10),
            _buildChoiceButton(
              context: context,
              title: 'SANGUINE OFFERING (SACRIFICE 40% SQUAD HP)',
              subtitle: 'Transmute life-essence to forge a guaranteed Epic Relic.',
              icon: Icons.token,
              color: const Color(0xFFAB47BC),
              onTap: () => Navigator.pop(context, BloodAltarChoice.sanguineOffering),
            ),
            const SizedBox(height: 10),
            _buildChoiceButton(
              context: context,
              title: 'DEPART WITH REVERENCE',
              subtitle: 'Leave the altar untouched without spilling blood.',
              icon: Icons.arrow_back,
              color: Colors.white38,
              onTap: () => Navigator.pop(context, BloodAltarChoice.walkAway),
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
