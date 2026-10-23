import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';

class CombatRewardsData {
  final bool isVictory;
  final int rawAsh;
  final int emberShards;
  final int cryptKeys;
  final int distilledVitae;
  final int xpGained;
  final List<String> levelUps;
  final UnitEntity? capturedThrall;
  final String? relicDropName;
  final String encounterTitle;
  final int ascensionTier;
  final double resourceDropMultiplier;
  final String? bossReagentDrop;

  const CombatRewardsData({
    required this.isVictory,
    required this.rawAsh,
    required this.emberShards,
    this.cryptKeys = 0,
    this.distilledVitae = 0,
    required this.xpGained,
    this.levelUps = const [],
    this.capturedThrall,
    this.relicDropName,
    this.encounterTitle = 'Ashen Skirmish',
    this.ascensionTier = 0,
    this.resourceDropMultiplier = 1.0,
    this.bossReagentDrop,
  });
}

/// GDD v2.8 Section 1, 2, & 12: Post-Match Extraction & Post-Battle Loot Screen
/// Living Mineral tabletop miniature aesthetic presenting target-farmed Ash/Vitae spoils,
/// pureblood progenitor drops, ascension modifier scaling, and tactile extraction claims.
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
    final Color primaryGold = const Color(0xFFFFD54F);
    final Color headerBorderColor = isVictory ? const Color(0xFFE5A93C) : const Color(0xFFB71C1C);
    final double dialogMaxWidth = (MediaQuery.of(context).size.width * 0.90).clamp(360.0, 460.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isVictory ? const Color(0xFF1E1A14) : const Color(0xFF200F12),
                  const Color(0xFF121217),
                  const Color(0xFF09090D),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: headerBorderColor, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: (isVictory ? const Color(0xFFE5A93C) : const Color(0xFFB71C1C))
                      .withValues(alpha: 0.35),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 20,
                  offset: Offset(0, 10),
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
                        ? const Color(0xFFB71C1C).withValues(alpha: 0.35)
                        : const Color(0xFF3E0A0E).withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: headerBorderColor, width: 1.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isVictory ? Icons.workspace_premium : Icons.dangerous,
                            color: isVictory ? primaryGold : const Color(0xFFEF5350),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isVictory ? 'EXTRACTION CONCLUDED' : 'BRIGADE VANQUISHED',
                                style: TextStyle(
                                  color: isVictory ? primaryGold : const Color(0xFFFF8A80),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            rewards.encounterTitle.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (rewards.ascensionTier > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB71C1C).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: const Color(0xFFFF5252), width: 0.8),
                              ),
                              child: Text(
                                'A${rewards.ascensionTier}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8A80),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Body Details & Spoils Grids
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isVictory
                              ? 'The Crucible claims the defeated mineral vessels. Ambient Ash, Distilled Vitae aquifers, and soul-remnants have condensed into your alchemical gauntlet.'
                              : 'All frontline and arcanum vessels have collapsed into inert stone husks. Mortal essence retreats to the Ashen Encampment.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),

                        // Ascension Bonus/Scarcity Notification Pill
                        if (rewards.ascensionTier > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1724),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF9C27B0), width: 0.9),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_graph, color: Color(0xFFCE93D8), size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ASCENSION ${rewards.ascensionTier} MODIFIER: ${(rewards.resourceDropMultiplier * 100).round()}% REWARD RATE',
                                    style: const TextStyle(
                                      color: Color(0xFFE1BEE7),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Primary Currencies Grid
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
                                  icon: Icons.water_drop,
                                  iconColor: const Color(0xFFFF1744),
                                  label: 'DISTILLED VITAE',
                                  value: '+${rewards.distilledVitae}',
                                  valueColor: const Color(0xFFFF5252),
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
                                  iconColor: primaryGold,
                                  label: 'BRIGADE XP',
                                  value: '+${rewards.xpGained} XP',
                                  valueColor: primaryGold,
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
                          if (rewards.cryptKeys > 0) ...[
                            const SizedBox(height: 8),
                            _buildRewardTile(
                              icon: Icons.vpn_key,
                              iconColor: const Color(0xFFBA68C8),
                              label: 'CRUCIBLE KEYS / BLOODLINE SIGILS',
                              value: '+${rewards.cryptKeys}',
                              valueColor: const Color(0xFFCE93D8),
                            ),
                          ],
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

                        // Boss Reagent Drop (Target-Farmable Trophy)
                        if (rewards.bossReagentDrop != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B1612),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFF5722), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Color(0xFFFF7043), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TITAN BOSS REAGENT EXTRACTED',
                                        style: TextStyle(
                                          color: Color(0xFFFFAB91),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                      Text(
                                        rewards.bossReagentDrop!,
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

                        // Level Up Highlights
                        if (rewards.levelUps.isNotEmpty) ...[
                          const SizedBox(height: 10),
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

                        // Captured Miniature Drop (Living Mineral Figurine Presentation)
                        if (rewards.capturedThrall != null) ...[
                          const SizedBox(height: 10),
                          _buildCapturedThrallCard(rewards.capturedThrall!),
                        ],

                        // Relic Drop Highlight
                        if (rewards.relicDropName != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2614),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: primaryGold, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield, color: primaryGold, size: 16),
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
                ),

                // 3. Extraction Action Button
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('post_battle_continue_button'),
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVictory ? primaryGold : const Color(0xFFB71C1C),
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
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildCapturedThrallCard(UnitEntity thrall) {
    final bool isCutout = thrall.isFigurineCutout;
    final Color badgeColor = thrall.isPureblood ? const Color(0xFFFF5252) : const Color(0xFFBA68C8);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF221A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Miniature Avatar / Plinth Cutout Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCutout ? Colors.transparent : const Color(0xFF121218),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                thrall.effectiveAvatarAsset,
                fit: isCutout ? BoxFit.contain : BoxFit.cover,
                alignment: isCutout ? Alignment.bottomCenter : Alignment.topCenter,
                errorBuilder: (_, __, ___) => Icon(Icons.person, color: badgeColor, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: badgeColor, width: 0.6),
                      ),
                      child: Text(
                        thrall.isPureblood ? 'PUREBLOOD G${thrall.generation}' : 'GEN ${thrall.generation}',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VESSEL SOUL BOUND',
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${thrall.name} (${thrall.archetype.name.toUpperCase()})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'HP ${thrall.maxHp} • ATK ${thrall.attack} • DEF ${thrall.defense} • SPD ${thrall.speed}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 8.5,
                    fontFamily: 'monospace',
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
