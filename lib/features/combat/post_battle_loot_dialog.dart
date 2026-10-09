import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';

class CombatRewardsData {
  final bool isVictory;
  final int rawAsh;
  final int emberShards;
  final int cryptKeys;
  final int xpGained;
  final List<String> levelUps;
  final UnitEntity? capturedThrall;
  final String? relicDropName;
  final String encounterTitle;

  const CombatRewardsData({
    required this.isVictory,
    required this.rawAsh,
    required this.emberShards,
    this.cryptKeys = 0,
    required this.xpGained,
    this.levelUps = const [],
    this.capturedThrall,
    this.relicDropName,
    this.encounterTitle = 'Ashen Skirmish',
  });
}

/// GDD v2.6 Section 2 & 12: Post-Match Extraction & Post-Battle Loot Screen
/// Displays victory extraction (Unbound Ash, Ember Shards, Crypt Keys, Brigade XP, Captured Thralls)
/// or defeat recovery with retreat options.
class PostBattleLootDialog extends StatelessWidget {
  final CombatRewardsData rewards;
  final VoidCallback onContinue;

  const PostBattleLootDialog({
    super.key,
    required this.rewards,
    required this.onContinue,
  });

  static Future<void> show({
    required BuildContext context,
    required CombatRewardsData rewards,
    required VoidCallback onContinue,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PostBattleLootDialog(
        rewards: rewards,
        onContinue: () {
          Navigator.of(ctx).pop();
          onContinue();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isVictory = rewards.isVictory;
    final Color primaryColor = isVictory ? const Color(0xFFFFD54F) : const Color(0xFFEF5350);
    final Color borderColor = isVictory ? const Color(0xFFE5A93C) : const Color(0xFFB71C1C);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isVictory ? const Color(0xFF1E1A14) : const Color(0xFF1E1012),
                  const Color(0xFF101015),
                  const Color(0xFF0A0A0E),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: (isVictory ? const Color(0xFFE5A93C) : const Color(0xFFB71C1C)).withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isVictory
                        ? const Color(0xFFB71C1C).withValues(alpha: 0.40)
                        : const Color(0xFF3E0A0E).withValues(alpha: 0.60),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVictory ? Icons.workspace_premium : Icons.dangerous,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isVictory ? 'EXTRACTION CONCLUDED' : 'BRIGADE VANQUISHED',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        rewards.encounterTitle.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Body Details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isVictory
                            ? 'The Crucible claims the defeated vessels. Raw Ash and soul-remnants have been harvested into your phylactery.'
                            : 'All frontline and arcanum vessels have collapsed into inert stone. Mortal essence retreats to the Ashen Encampment.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Currency Extraction Grid (GDD Sec 2 & 12)
                      if (isVictory) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildRewardTile(
                                icon: Icons.whatshot,
                                iconColor: const Color(0xFFFF7043),
                                label: 'UNBOUND ASH',
                                value: '+${rewards.rawAsh}',
                                valueColor: const Color(0xFFFFB74D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRewardTile(
                                icon: Icons.diamond_outlined,
                                iconColor: const Color(0xFF00E5FF),
                                label: 'EMBER SHARDS',
                                value: '+${rewards.emberShards}',
                                valueColor: const Color(0xFF80D8FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRewardTile(
                                icon: Icons.military_tech,
                                iconColor: const Color(0xFFFFD54F),
                                label: 'BRIGADE XP',
                                value: '+${rewards.xpGained} XP',
                                valueColor: const Color(0xFFFFD54F),
                              ),
                            ),
                            if (rewards.cryptKeys > 0) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildRewardTile(
                                  icon: Icons.vpn_key,
                                  iconColor: const Color(0xFFBA68C8),
                                  label: 'CRUCIBLE KEYS',
                                  value: '+${rewards.cryptKeys}',
                                  valueColor: const Color(0xFFCE93D8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF140D10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFB71C1C), width: 1.0),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.refresh, color: Color(0xFFEF5350), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vessels reconstituted with mortal essence. Regroup, synthesize duplicates, and challenge the Crucible again.',
                                  style: TextStyle(
                                    color: Color(0xFFFFCDD2),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Level Up Highlights
                      if (rewards.levelUps.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2818),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4CAF50), width: 1.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_upward, color: Color(0xFF81C784), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'LEVEL UP: ${rewards.levelUps.join(", ")}',
                                  style: const TextStyle(
                                    color: Color(0xFFA5D6A7),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Captured Miniature Drop (GDD Sec 2)
                      if (rewards.capturedThrall != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF261D2E),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFAB47BC), width: 1.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_add, color: Color(0xFFCE93D8), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'VESSEL SOUL BOUND',
                                      style: TextStyle(
                                        color: Color(0xFFCE93D8),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Text(
                                      '${rewards.capturedThrall!.name} (${rewards.capturedThrall!.archetype.name.toUpperCase()})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Relic Drop Highlight
                      if (rewards.relicDropName != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2614),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield, color: Color(0xFFFFD54F), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'FORGED RELIC: ${rewards.relicDropName}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFE082),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. Extraction Action Button
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('post_battle_continue_button'),
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVictory ? const Color(0xFFFFD54F) : const Color(0xFFB71C1C),
                        foregroundColor: isVictory ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: Icon(
                        isVictory ? Icons.check_circle_outline : Icons.exit_to_app,
                        size: 18,
                        color: isVictory ? Colors.black : Colors.white,
                      ),
                      label: Text(
                        isVictory ? 'COLLECT REWARDS' : 'RETURN TO CAMP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          color: isVictory ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF282836), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
