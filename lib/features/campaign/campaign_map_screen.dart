import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/expedition_boon.dart';
import 'campaign_node.dart';

class ChapterTheme {
  final int chapter;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color pathColor;
  final Color activePathColor;
  final IconData chapterIcon;

  const ChapterTheme({
    required this.chapter,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.pathColor,
    required this.activePathColor,
    required this.chapterIcon,
  });

  static ChapterTheme forChapter(int chapter) {
    switch (chapter) {
      case 2:
        return const ChapterTheme(
          chapter: 2,
          title: 'CH. II: SUNKEN NECROPOLIS',
          subtitle: 'The Submerged Tombs • Depths 0–5',
          primaryColor: Color(0xFF00897B),
          secondaryColor: Color(0xFF26A69A),
          backgroundColor: Color(0xFF0A1312),
          surfaceColor: Color(0xFF10211F),
          pathColor: Color(0xFF1C3432),
          activePathColor: Color(0xFF00BFA5),
          chapterIcon: Icons.water,
        );
      case 3:
        return const ChapterTheme(
          chapter: 3,
          title: 'CH. III: ABYSSAL RIFT',
          subtitle: 'The Primordial Void • Depths 0–5',
          primaryColor: Color(0xFF8E24AA),
          secondaryColor: Color(0xFFBA68C8),
          backgroundColor: Color(0xFF0F0B16),
          surfaceColor: Color(0xFF1B1226),
          pathColor: Color(0xFF2C193C),
          activePathColor: Color(0xFFD500F9),
          chapterIcon: Icons.dark_mode,
        );
      case 1:
      default:
        return const ChapterTheme(
          chapter: 1,
          title: 'CH. I: ASHEN PERIMETER',
          subtitle: 'The Burning Outposts • Depths 0–4',
          primaryColor: Color(0xFFB3261E),
          secondaryColor: Color(0xFFE5A93C),
          backgroundColor: Color(0xFF111114),
          surfaceColor: Color(0xFF181820),
          pathColor: Color(0xFF2B2B36),
          activePathColor: Color(0xFFEF5350),
          chapterIcon: Icons.local_fire_department,
        );
    }
  }
}

class CampaignMapScreen extends StatelessWidget {
  final List<CampaignNode> nodes;
  final ValueChanged<CampaignNode> onSelectNode;
  final int totalIchor;
  final int cursedOre;
  final int bloodlineSigils;
  final VoidCallback? onOpenEndgameGauntlet;
  final int currentChapter;
  final int maxUnlockedChapter;
  final ValueChanged<int>? onChapterChanged;
  final Set<ExpeditionBoon> activeBoons;

  const CampaignMapScreen({
    super.key,
    required this.nodes,
    required this.onSelectNode,
    this.totalIchor = 0,
    this.cursedOre = 0,
    this.bloodlineSigils = 0,
    this.onOpenEndgameGauntlet,
    this.currentChapter = 1,
    this.maxUnlockedChapter = 1,
    this.onChapterChanged,
    this.activeBoons = const {},
  });

  static String chapterTitle(int ch) {
    switch (ch) {
      case 1:
        return 'CH. I: ASHEN PERIMETER';
      case 2:
        return 'CH. II: SUNKEN NECROPOLIS';
      case 3:
        return 'CH. III: ABYSSAL RIFT';
      default:
        return 'TIER $ch: DEEP DESCENT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChapterTheme.forChapter(currentChapter);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentChapter > 1 && onChapterChanged != null)
              IconButton(
                icon: Icon(Icons.arrow_left, size: 20, color: theme.secondaryColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onChapterChanged!(currentChapter - 1),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(theme.chapterIcon, size: 12, color: theme.secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        chapterTitle(currentChapter),
                        style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    theme.subtitle,
                    style: TextStyle(letterSpacing: 0.8, color: theme.secondaryColor.withValues(alpha: 0.75), fontSize: 8),
                  ),
                ],
              ),
            ),
            if (currentChapter < maxUnlockedChapter && onChapterChanged != null)
              IconButton(
                icon: Icon(Icons.arrow_right, size: 20, color: theme.secondaryColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onChapterChanged!(currentChapter + 1),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (onOpenEndgameGauntlet != null)
            IconButton(
              icon: const Icon(Icons.workspace_premium, color: Color(0xFFE5A93C), size: 20),
              tooltip: 'Endgame Gauntlet',
              onPressed: onOpenEndgameGauntlet,
            ),
          // Tri-Currency Display
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Row(
              children: [
                // Ichor
                const Icon(Icons.water_drop, color: Color(0xFFB3261E), size: 14),
                const SizedBox(width: 3),
                Text(
                  '$totalIchor',
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Cursed Ore
                const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 14),
                const SizedBox(width: 3),
                Text(
                  '$cursedOre',
                  style: const TextStyle(
                    color: Color(0xFF80CBC4),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Bloodline Sigils
                ClipOval(
                  child: Image.asset(
                    'assets/images/blood_altar_sigil.jpg',
                    width: 14,
                    height: 14,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.military_tech, color: Color(0xFFE5A93C), size: 14),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '$bloodlineSigils',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeBoons.isNotEmpty) _buildActiveBoonsBanner(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
          final double mapWidth = constraints.maxWidth;
          final double mapHeight = constraints.maxHeight;
          final double maxD = nodes.map((n) => n.depth).fold(1, (prev, elem) => elem > prev ? elem : prev).toDouble();

          return Stack(
            children: [
              // Background Parchment Grid
              Positioned.fill(
                child: CustomPaint(
                  painter: _CampaignPathPainter(
                    nodes: nodes,
                    maxDepth: maxD,
                    chapterTheme: theme,
                  ),
                ),
              ),
              // Node interactive badges
              ...nodes.map((node) {
                // Calculate position: depth (X axis: 0 to maxD), verticalRatio (Y axis: 0.1 to 0.9)
                final double x = (node.depth / (maxD > 0 ? maxD : 1.0)) * (mapWidth - 80) + 40;
                final double y = node.verticalRatio * (mapHeight - 80) + 40;
                final double badgeWidth = node.type == CampaignNodeType.boss ? 90.0 : 76.0;
                final double leftPos = (x - badgeWidth / 2).clamp(4.0, (mapWidth - badgeWidth - 4.0).clamp(4.0, double.infinity));

                return Positioned(
                  left: leftPos,
                  top: y - 28,
                  width: badgeWidth,
                  child: _buildNodeBadge(context, node),
                );
              }),
              // Endgame Gauntlet Banner Button
              if (onOpenEndgameGauntlet != null)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.workspace_premium, size: 16),
                    label: const Text('ENDGAME GAUNTLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E28),
                      foregroundColor: const Color(0xFFE5A93C),
                      side: const BorderSide(color: Color(0xFFE5A93C), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: onOpenEndgameGauntlet,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  ],
),
);
}

  Widget _buildActiveBoonsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1015),
        border: Border(bottom: BorderSide(color: Color(0xFFB3261E), width: 1.0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFF7043), size: 14),
          const SizedBox(width: 8),
          const Text(
            'ACTIVE COVENANTS:',
            style: TextStyle(
              color: Color(0xFFFF7043),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: activeBoons.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: b.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: b.color, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(b.icon, color: b.color, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      b.displayName,
                      style: TextStyle(color: b.color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeBadge(BuildContext context, CampaignNode node) {
    final bool canTap = node.isReachable && !node.isVisited;

    Color borderColor = const Color(0xFF2B2B36);
    Color bgColor = const Color(0xFF181820);
    IconData icon = _nodeIcon(node.type);

    if (node.isVisited) {
      borderColor = const Color(0xFF4CAF50);
      bgColor = const Color(0xFF1B5E20).withValues(alpha: 0.3);
      icon = Icons.check;
    } else if (node.isCurrent) {
      borderColor = const Color(0xFFE5A93C);
      bgColor = const Color(0xFFE5A93C).withValues(alpha: 0.2);
    } else if (node.isReachable) {
      borderColor = const Color(0xFFB3261E);
      bgColor = const Color(0xFF2A1515);
    }

    return GestureDetector(
      onTap: canTap ? () => _showNodeEncounterDialog(context, node) : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: node.type == CampaignNodeType.boss ? 56 : 46,
            height: node.type == CampaignNodeType.boss ? 56 : 46,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: (canTap || node.isCurrent) ? 2.5 : 1.2,
              ),
              boxShadow: canTap
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB3261E).withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: node.type == CampaignNodeType.boss ? 28 : 22,
              color: canTap ? Colors.white : (node.isVisited ? const Color(0xFF81C784) : Colors.white30),
            ),
          ),
          const SizedBox(height: 3),
          // Scouted Badge
          if (node.isScouted && !node.isVisited)
            Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
              decoration: BoxDecoration(
                color: const Color(0xFF006064).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF00E5FF), width: 0.7),
              ),
              child: const Text(
                'SCOUTED',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 6.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF14141B).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: canTap ? Colors.white : Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Scouted Affinities Chips
          if (node.isScouted && !node.isVisited && node.scoutedAffinities.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: node.scoutedAffinities.take(3).map((aff) {
                final color = _affinityColor(aff);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: color, width: 0.6),
                  ),
                  child: Text(
                    _affinityAbbr(aff),
                    style: TextStyle(
                      color: color,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  static String _bossImageForChapter(int ch) {
    switch (ch) {
      case 2:
        return 'assets/images/plague_occultist.jpg';
      case 3:
        return 'assets/images/ironclad_dreadnought.jpg';
      case 1:
      default:
        return 'assets/images/flayed_butcher.jpg';
    }
  }

  void _showNodeEncounterDialog(BuildContext context, CampaignNode node) {
    final double dialogWidth = (MediaQuery.of(context).size.width * 0.85).clamp(320.0, 480.0);
    final theme = ChapterTheme.forChapter(currentChapter);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.surfaceColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: node.type == CampaignNodeType.boss ? const Color(0xFFE5A93C) : theme.primaryColor,
              width: 1.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogWidth),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _nodeIcon(node.type),
                        color: node.type == CampaignNodeType.boss ? const Color(0xFFE5A93C) : theme.primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          node.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  // Chapter Boss Presentation Card
                  if (node.type == CampaignNodeType.boss) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5A93C), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                _bossImageForChapter(currentChapter),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B1B22)),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.85),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 10,
                              right: 10,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB3261E),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'WORLD TITAN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'PUREBLOOD ASCENSION GATEWAY',
                                      style: TextStyle(
                                        color: Color(0xFFE5A93C),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Text(
                    node.description,
                    style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Scouted Enemy Formation details
                  if (node.isScouted && node.scoutedAffinities.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101920),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00ACC1), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.visibility, color: Color(0xFF00E5FF), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'SCOUTED FORMATION AFFINITIES',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: node.scoutedAffinities.map((aff) {
                              final color = _affinityColor(aff);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: color, width: 0.8),
                                ),
                                child: Text(
                                  '${aff.name.toUpperCase()} (${_counterAdvice(aff)})',
                                  style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2B2B36)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop, color: Color(0xFFB3261E), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+${node.rewardIchor} ICHOR',
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+${node.rewardOre} ORE',
                          style: const TextStyle(
                            color: Color(0xFF80CBC4),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                        if (node.rewardSigils > 0) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.military_tech, color: Color(0xFFFFD54F), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '+${node.rewardSigils} SIGIL',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('RETREAT', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: node.type == CampaignNodeType.boss ? const Color(0xFFB3261E) : theme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onSelectNode(node);
                        },
                        child: Text(
                          _actionLabel(node.type),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _actionLabel(CampaignNodeType type) {
    switch (type) {
      case CampaignNodeType.skirmish:
      case CampaignNodeType.elite:
      case CampaignNodeType.boss:
        return 'ENGAGE HOSTILES';
      case CampaignNodeType.altar:
        return 'APPROACH ALTAR';
      case CampaignNodeType.restHaven:
        return 'BIND WOUNDS';
      case CampaignNodeType.crypt:
        return 'PRY SARCOPHAGUS';
      case CampaignNodeType.watchtower:
        return 'SCALE OBSIDIAN SPIRE';
    }
  }

  IconData _nodeIcon(CampaignNodeType type) {
    switch (type) {
      case CampaignNodeType.skirmish:
        return Icons.sports_kabaddi;
      case CampaignNodeType.elite:
        return Icons.local_fire_department;
      case CampaignNodeType.altar:
        return Icons.fireplace;
      case CampaignNodeType.restHaven:
        return Icons.healing;
      case CampaignNodeType.crypt:
        return Icons.vpn_key;
      case CampaignNodeType.watchtower:
        return Icons.visibility;
      case CampaignNodeType.boss:
        return Icons.shield;
    }
  }

  static Color _affinityColor(Archetype archetype) {
    switch (archetype) {
      case Archetype.juggernaut:
        return const Color(0xFF1E88E5);
      case Archetype.assassin:
        return const Color(0xFFE53935);
      case Archetype.marksman:
        return const Color(0xFFFB8C00);
      case Archetype.skirmisher:
        return const Color(0xFF00897B);
      case Archetype.support:
        return const Color(0xFF43A047);
      case Archetype.occultist:
        return const Color(0xFF8E24AA);
    }
  }

  static String _affinityAbbr(Archetype archetype) {
    switch (archetype) {
      case Archetype.juggernaut:
        return 'JUG';
      case Archetype.assassin:
        return 'ASN';
      case Archetype.marksman:
        return 'MRK';
      case Archetype.skirmisher:
        return 'SKR';
      case Archetype.support:
        return 'SUP';
      case Archetype.occultist:
        return 'OCC';
    }
  }

  static String _counterAdvice(Archetype archetype) {
    switch (archetype) {
      case Archetype.juggernaut:
        return 'Occultists rot heavy armor';
      case Archetype.assassin:
        return 'Juggernauts deflect strikes';
      case Archetype.marksman:
        return 'Assassins dive artillery';
      case Archetype.skirmisher:
        return 'Marksmen snipe flyers';
      case Archetype.support:
        return 'Skirmishers flank casters';
      case Archetype.occultist:
        return 'Supports cleanse hexes';
    }
  }
}

class _CampaignPathPainter extends CustomPainter {
  final List<CampaignNode> nodes;
  final double maxDepth;
  final ChapterTheme chapterTheme;

  _CampaignPathPainter({
    required this.nodes,
    this.maxDepth = 4.0,
    required this.chapterTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle ambient motes / particles matching the chapter's theme
    final motePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 16; i++) {
      final double px = ((i * 137.5 + chapterTheme.chapter * 53) % size.width);
      final double py = ((i * 89.3 + chapterTheme.chapter * 71) % size.height);
      final double radius = (i % 3 == 0) ? 2.5 : 1.5;
      final double alpha = ((i % 4) + 1) * 0.04;
      motePaint.color = chapterTheme.secondaryColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), radius, motePaint);
    }

    final Map<String, Offset> nodePositions = {};
    final double safeMaxD = maxDepth > 0 ? maxDepth : 1.0;

    for (final node in nodes) {
      final double x = (node.depth / safeMaxD) * (size.width - 80) + 40;
      final double y = node.verticalRatio * (size.height - 80) + 40;
      nodePositions[node.id] = Offset(x, y);
    }

    final Paint pathPaint = Paint()
      ..color = chapterTheme.pathColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint activePathPaint = Paint()
      ..color = chapterTheme.activePathColor.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      final from = nodePositions[node.id];
      if (from == null) continue;

      for (final nextId in node.nextNodeIds) {
        final to = nodePositions[nextId];
        if (to == null) continue;

        final Path path = Path();
        path.moveTo(from.dx, from.dy);

        final double controlX1 = from.dx + (to.dx - from.dx) * 0.5;
        final double controlY1 = from.dy;
        final double controlX2 = from.dx + (to.dx - from.dx) * 0.5;
        final double controlY2 = to.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, to.dx, to.dy);

        final targetNode = nodes.where((n) => n.id == nextId).firstOrNull;
        final bool isActivePath = node.isVisited && (targetNode?.isReachable ?? false);

        canvas.drawPath(path, isActivePath ? activePathPaint : pathPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CampaignPathPainter oldDelegate) =>
      oldDelegate.chapterTheme.chapter != chapterTheme.chapter ||
      oldDelegate.nodes != nodes ||
      oldDelegate.maxDepth != maxDepth;
}
