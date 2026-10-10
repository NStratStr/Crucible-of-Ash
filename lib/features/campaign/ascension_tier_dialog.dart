import 'package:flutter/material.dart';
import 'ascension_tier_data.dart';

/// Modal dialog for inspecting and selecting the active Ascension Modifier Tier (A0–A10).
class AscensionTierDialog extends StatelessWidget {
  final int currentAscension;
  final int maxUnlockedAscension;
  final ValueChanged<int> onSelectAscension;

  const AscensionTierDialog({
    super.key,
    required this.currentAscension,
    required this.maxUnlockedAscension,
    required this.onSelectAscension,
  });

  static Future<int?> show({
    required BuildContext context,
    required int currentAscension,
    required int maxUnlockedAscension,
    required ValueChanged<int> onSelectAscension,
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AscensionTierDialog(
        currentAscension: currentAscension,
        maxUnlockedAscension: maxUnlockedAscension,
        onSelectAscension: onSelectAscension,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1418), Color(0xFF121016), Color(0xFF0A0A0E)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5A93C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB3261E).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                const BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF261215),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border(bottom: BorderSide(color: Color(0xFFB3261E), width: 1.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFEF5350), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASCENSION MODIFIERS (A0–A10)',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Scale difficulty and rewards across the Crucible',
                              style: TextStyle(color: Colors.white70, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Tier List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: AscensionTierData.allTiers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tier = AscensionTierData.allTiers[index];
                      final bool isUnlocked = tier.tierNumber <= maxUnlockedAscension;
                      final bool isCurrent = tier.tierNumber == currentAscension;

                      return _buildTierCard(
                        context: context,
                        tier: tier,
                        isUnlocked: isUnlocked,
                        isCurrent: isCurrent,
                      );
                    },
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF101016),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                    border: Border(top: BorderSide(color: Color(0xFF282836))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE: A$currentAscension • UNLOCKED: A$maxUnlockedAscension',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('DISMISS', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required BuildContext context,
    required AscensionTierData tier,
    required bool isUnlocked,
    required bool isCurrent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF2E1C22)
            : (isUnlocked ? const Color(0xFF161620) : const Color(0xFF0F0F14)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? tier.themeColor
              : (isUnlocked ? const Color(0xFF333346) : const Color(0xFF1E1E26)),
          width: isCurrent ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier Indicator Badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isUnlocked ? tier.themeColor.withValues(alpha: 0.2) : Colors.black45,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isUnlocked ? tier.themeColor : Colors.white24,
                width: 1.0,
              ),
            ),
            child: Center(
              child: isUnlocked
                  ? Text(
                      'A${tier.tierNumber}',
                      style: TextStyle(
                        color: tier.themeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    )
                  : const Icon(Icons.lock, color: Colors.white24, size: 16),
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tier.title,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white38,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tier.subtitle,
                  style: TextStyle(
                    color: isUnlocked ? Colors.white60 : Colors.white24,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tier.modifierSummary,
                  style: TextStyle(
                    color: isUnlocked ? tier.themeColor : Colors.white24,
                    fontSize: 9.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Select Button
          if (isUnlocked && !isCurrent)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF282836),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                onSelectAscension(tier.tierNumber);
                Navigator.of(context).pop(tier.tierNumber);
              },
              child: const Text('ENGAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
