import 'package:flutter/material.dart';
import '../../shared/models/relic_entity.dart';

class RelicSetCodexDialog extends StatelessWidget {
  final int currentChapter;

  const RelicSetCodexDialog({
    super.key,
    required this.currentChapter,
  });

  static Future<void> show(BuildContext context, {int currentChapter = 1}) {
    return showDialog(
      context: context,
      builder: (ctx) => RelicSetCodexDialog(currentChapter: currentChapter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlockedSets = RelicEntity.setsForChapter(currentChapter);

    return Dialog(
      backgroundColor: const Color(0xFF101018),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF161622),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: Color(0xFF2B2B38))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RELIC & SET SYNERGY ENCYCLOPEDIA',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'EQUIPMENT SLOTS • SET BONUSES • CHAPTER DISCOVERY',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Section 1: Relic Mechanics Overview
                  _buildSectionBanner(
                    title: 'HOW RELICS & EQUIPMENT WORK',
                    subtitle: '4 Core Slots per Unit with Stat Scaling & Refinements',
                    accentColor: const Color(0xFF42A5F5),
                  ),
                  const SizedBox(height: 10),
                  _buildEquipmentSlotGuide(),
                  const SizedBox(height: 16),

                  // Section 2: Refinement & Chapter Caps
                  _buildRefinementGuide(context),
                  const SizedBox(height: 18),

                  // Section 3: All Relic Sets & Set Synergies
                  _buildSectionBanner(
                    title: 'ALL 7 RELIC SET SYNERGIES',
                    subtitle: 'Combine 2-Piece or 4-Piece Sets across the 4 equipment slots',
                    accentColor: const Color(0xFFFF7043),
                  ),
                  const SizedBox(height: 10),

                  ...RelicSetType.values.map((setType) {
                    final isDiscovered = unlockedSets.contains(setType);
                    return _buildRelicSetCard(setType, isDiscovered);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBanner({
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSlotGuide() {
    final slots = [
      {'name': 'WEAPON', 'icon': Icons.colorize, 'focus': 'Attack & Critical Hit Chance', 'color': const Color(0xFFEF5350)},
      {'name': 'ARMOR', 'icon': Icons.shield, 'focus': 'Defense & Maximum Health', 'color': const Color(0xFF42A5F5)},
      {'name': 'TALISMAN', 'icon': Icons.auto_awesome, 'focus': 'Speed, Turn-Meter & Health', 'color': const Color(0xFFFFD54F)},
      {'name': 'SIGIL', 'icon': Icons.token, 'focus': 'Hybrid Offensive & Defensive Affixes', 'color': const Color(0xFFAB47BC)},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: slots.map((s) {
              final color = s['color'] as Color;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(s['icon'] as IconData, color: color, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        s['name'] as String,
                        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s['focus'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 Pro-Tip: Because every hero has 4 slots, you can equip two different 2-piece sets (e.g. Ironclad + Tempest) OR one powerful 4-piece set (e.g. Blightweaver or Executioner).',
            style: TextStyle(color: Color(0xFFFFE082), fontSize: 9.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildRefinementGuide(BuildContext context) {
    final cap = RelicEntity.maxRefinementTierForChapter(currentChapter);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171724),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.upgrade, color: Color(0xFFD4AF37), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WORLD PROMOTION & REFINEMENT CAPS',
                      style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CURRENT CAP: +$cap',
                        style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Each Refinement level increases all base stats by +25% and grants +2 Speed. Maximum refinement tiers are gated by continental progression:\n'
                  '• Chapter 1: Cap at +2 • Chapter 2: Cap at +3 • Chapter 3+: Cap at +5 (Master Refinement)\n\n'
                  '★ SUB-STARS & ADVANCED REFINEMENT AFFIXES:\n'
                  'At refinement milestones (+2, +4, and +5), relics roll or enhance rare Sub-Stats:\n'
                  '• CRIT Rate (+3% to +6%) • CRIT DMG (+10% to +20%)\n'
                  '• Armor Penetration (+5% to +10% Armor Piercing)\n'
                  '• Ultimate Charge (+8% to +16% Limit Burst Rate)\n'
                  '• Ultimate DMG (+12% to +25% Limit Burst Power)\n'
                  '• Speed (+3 to +6) • Lifesteal (+4% to +8%)\n'
                  '• Attack (+15 to +30) • Defense (+15 to +30) • Health (+60 to +120)',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelicSetCard(RelicSetType setType, bool isDiscoveredInCurrentChapter) {
    final name = RelicEntity.setName(setType);
    final desc = RelicEntity.setBonusDescription(setType);
    final role = RelicEntity.setTacticalRole(setType);
    final color = RelicEntity.setAccentColor(setType);
    final icon = RelicEntity.setIcon(setType);
    final pieces = RelicEntity.setRequiredPieces(setType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDiscoveredInCurrentChapter ? 0.7 : 0.25),
          width: isDiscoveredInCurrentChapter ? 1.4 : 1.0,
        ),
        boxShadow: isDiscoveredInCurrentChapter
            ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8)]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDiscoveredInCurrentChapter ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : const Color(0xFF37474F).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDiscoveredInCurrentChapter ? const Color(0xFF81C784) : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isDiscoveredInCurrentChapter ? 'ACTIVE IN CH. $currentChapter' : 'DEEPER CHAPTERS',
                        style: TextStyle(
                          color: isDiscoveredInCurrentChapter ? const Color(0xFF81C784) : Colors.white54,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$pieces-Piece Required • $role',
                    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
