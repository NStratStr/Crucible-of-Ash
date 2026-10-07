import 'package:flutter/material.dart';

enum EndgameTrialType {
  worldTitan,
  lineageCrypt,
  abyssalDescent,
}

class EndgameTrialDefinition {
  final EndgameTrialType type;
  final String title;
  final String subtitle;
  final String description;
  final String modifier;
  final String rewardsText;
  final IconData icon;
  final Color themeColor;

  const EndgameTrialDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.modifier,
    required this.rewardsText,
    required this.icon,
    required this.themeColor,
  });
}

class EndgameGauntletDialog extends StatelessWidget {
  const EndgameGauntletDialog({super.key});

  static const List<EndgameTrialDefinition> trials = [
    EndgameTrialDefinition(
      type: EndgameTrialType.worldTitan,
      title: 'THE ASHEN WORLD TITAN',
      subtitle: 'Chapter-Capping Colossus Siege',
      description: 'Face the colossal Generation 4 Pureblood Titan with 4,500 HP, backed by Void Archons and Iron Harbingers.',
      modifier: 'TITANIC FURY: Boss attacks strike all frontline Vanguard units simultaneously.',
      rewardsText: 'Guaranteed Legendary Relic • +2,000 Ichor • +1,500 Brigade XP',
      icon: Icons.shield,
      themeColor: Color(0xFFD32F2F),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.lineageCrypt,
      title: 'LINEAGE CRYPT: DEN OF FANGS',
      subtitle: 'Beastline Lineage Trial',
      description: 'A dark cavern teeming with Cerberus Alpha and stealth predators that inflict heavy bleed affictions.',
      modifier: 'BLOOD MOON: All critical strike damage is amplified by +50%.',
      rewardsText: 'Pureblood War-Hound Thrall • +800 Ichor • +800 Brigade XP',
      icon: Icons.pets,
      themeColor: Color(0xFFFB8C00),
    ),
    EndgameTrialDefinition(
      type: EndgameTrialType.abyssalDescent,
      title: 'ABYSSAL DESCENT: TORMENT I',
      subtitle: 'Affinity Shift Trial',
      description: 'Descend into the dark abyss where Arch-Lich Malgok wields toxic miasma and resurrective thralls.',
      modifier: 'CORROSIVE MIASMA: Non-Occultist units suffer 30 poison damage at start of turn.',
      rewardsText: 'Epic Relic • +1,200 Ichor • +1,000 Brigade XP',
      icon: Icons.dark_mode,
      themeColor: Color(0xFF8E24AA),
    ),
  ];

  static Future<EndgameTrialType?> show(BuildContext context) {
    return showModalBottomSheet<EndgameTrialType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EndgameGauntletDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFB3261E), width: 1.5),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB3261E)),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Color(0xFFE5A93C), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE ENDGAME GAUNTLET',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'High-stakes mastery trials & World Titan sieges',
                        style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2B2B36), height: 1),

          // Trial list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trials.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final trial = trials[index];
                return _buildTrialCard(context, trial);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(BuildContext context, EndgameTrialDefinition trial) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trial.themeColor.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: trial.themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: trial.themeColor),
                  ),
                  child: Icon(trial.icon, color: trial.themeColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trial.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trial.subtitle,
                        style: TextStyle(
                          color: trial.themeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              trial.description,
              style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
            const SizedBox(height: 8),
            // Modifier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: trial.themeColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: trial.themeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trial.modifier,
                      style: TextStyle(
                        color: trial.themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Rewards
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 13, color: Color(0xFFE5A93C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Yield: ${trial.rewardsText}',
                    style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sports_kabaddi, size: 16),
                label: const Text('ENGAGE TRIAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: trial.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, trial.type),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
