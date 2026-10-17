import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/expedition_boon.dart';
import 'ascension_tier_data.dart';
import 'ascension_tier_dialog.dart';
import 'campaign_node.dart';
import 'linear_campaign_stage.dart';

enum CampaignViewMode {
  linearLadder,     // Linear story campaign (Stage 1-1 to 1-10)
  catacombDelve,    // Branching roguelite dungeon delve with safe teleport extraction
}

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
  final String backgroundAsset;

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
    this.backgroundAsset = 'assets/images/ashen_trail_desolation.jpg',
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
          backgroundAsset: 'assets/images/gothic_arch_battlefield.jpg',
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
          backgroundAsset: 'assets/images/realm_overworld_map.jpg',
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
          backgroundAsset: 'assets/images/ashen_trail_desolation.jpg',
        );
    }
  }
}

class CampaignMapScreen extends StatefulWidget {
  final List<CampaignNode> nodes;
  final ValueChanged<CampaignNode> onSelectNode;
  final int totalIchor;
  final int cursedOre;
  final int bloodlineSigils;
  final VoidCallback? onOpenEndgameGauntlet;
  final VoidCallback? onLaunchMvpSkirmish;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenSummoning;
  final VoidCallback? onOpenSettings;
  final int currentChapter;
  final int maxUnlockedChapter;
  final ValueChanged<int>? onChapterChanged;
  final int currentAscension;
  final int maxUnlockedAscension;
  final ValueChanged<int>? onAscensionChanged;
  final Set<ExpeditionBoon> activeBoons;
  final CampaignViewMode initialViewMode;
  final int completedLinearStages;

  const CampaignMapScreen({
    super.key,
    required this.nodes,
    required this.onSelectNode,
    this.totalIchor = 0,
    this.cursedOre = 0,
    this.bloodlineSigils = 0,
    this.onOpenEndgameGauntlet,
    this.onLaunchMvpSkirmish,
    this.onOpenHome,
    this.onOpenSummoning,
    this.onOpenSettings,
    this.currentChapter = 1,
    this.maxUnlockedChapter = 1,
    this.onChapterChanged,
    this.currentAscension = 0,
    this.maxUnlockedAscension = 0,
    this.onAscensionChanged,
    this.activeBoons = const {},
    this.initialViewMode = CampaignViewMode.linearLadder,
    this.completedLinearStages = 2,
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
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  late CampaignViewMode _viewMode;
  late int _completedLinearStages;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _completedLinearStages = widget.completedLinearStages;
  }

  @override
  void didUpdateWidget(CampaignMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completedLinearStages != widget.completedLinearStages) {
      _completedLinearStages = widget.completedLinearStages;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChapterTheme.forChapter(widget.currentChapter);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        leading: widget.onOpenHome != null
            ? IconButton(
                icon: const Icon(Icons.home, color: Color(0xFFFFD54F), size: 22),
                tooltip: 'Citadel War Room (Home)',
                onPressed: widget.onOpenHome,
              )
            : null,
        titleSpacing: widget.onOpenHome != null ? 0 : 8,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.currentChapter > 1 && widget.onChapterChanged != null)
                IconButton(
                  icon: Icon(Icons.arrow_left, size: 16, color: theme.secondaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => widget.onChapterChanged!(widget.currentChapter - 1),
                ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(theme.chapterIcon, size: 10, color: theme.secondaryColor),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              CampaignMapScreen.chapterTitle(widget.currentChapter),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 9.5 : 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        theme.subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          letterSpacing: 0.5,
                          color: theme.secondaryColor.withValues(alpha: 0.75),
                          fontSize: 7.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.currentChapter < widget.maxUnlockedChapter && widget.onChapterChanged != null)
                IconButton(
                  icon: Icon(Icons.arrow_right, size: 16, color: theme.secondaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => widget.onChapterChanged!(widget.currentChapter + 1),
                ),
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          // View Mode Toggle (Linear Ladder vs. Catacomb Delve)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF14141E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF38384E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _viewMode = CampaignViewMode.linearLadder),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _viewMode == CampaignViewMode.linearLadder ? const Color(0xFFE5A93C) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.linear_scale,
                          size: 11,
                          color: _viewMode == CampaignViewMode.linearLadder ? Colors.black : Colors.white60,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'CAMPAIGN',
                          style: TextStyle(
                            color: _viewMode == CampaignViewMode.linearLadder ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _viewMode = CampaignViewMode.catacombDelve),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _viewMode == CampaignViewMode.catacombDelve ? const Color(0xFF00E5FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 11,
                          color: _viewMode == CampaignViewMode.catacombDelve ? Colors.black : const Color(0xFF00E5FF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'DUNGEON',
                          style: TextStyle(
                            color: _viewMode == CampaignViewMode.catacombDelve ? Colors.black : const Color(0xFF00E5FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ascension Tier Badge (A0–A10)
          GestureDetector(
            key: const ValueKey('ascension_tier_button'),
            onTap: () {
              if (widget.onAscensionChanged != null) {
                AscensionTierDialog.show(
                  context: context,
                  currentAscension: widget.currentAscension,
                  maxUnlockedAscension: widget.maxUnlockedAscension,
                  onSelectAscension: widget.onAscensionChanged!,
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: widget.currentAscension > 0
                    ? const Color(0xFFB71C1C).withValues(alpha: 0.35)
                    : const Color(0xFF1E1E28),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: widget.currentAscension > 0
                      ? const Color(0xFFFF5252)
                      : const Color(0xFFE5A93C).withValues(alpha: 0.8),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_graph,
                    size: 11,
                    color: widget.currentAscension > 0
                        ? const Color(0xFFFF5252)
                        : const Color(0xFFFFD54F),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'A${widget.currentAscension}',
                    style: TextStyle(
                      color: widget.currentAscension > 0
                          ? const Color(0xFFFF5252)
                          : const Color(0xFFFFD54F),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isMobile && widget.onLaunchMvpSkirmish != null)
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: Color(0xFFFF7043), size: 18),
              tooltip: 'MVP 3-Wave Skirmish (GDD Sec 14.1)',
              onPressed: widget.onLaunchMvpSkirmish,
            ),
          if (!isMobile && widget.onOpenEndgameGauntlet != null)
            IconButton(
              icon: const Icon(Icons.workspace_premium, color: Color(0xFFE5A93C), size: 18),
              tooltip: 'Endgame Gauntlet',
              onPressed: widget.onOpenEndgameGauntlet,
            ),
          // Tri-Currency Display
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ichor
                const Icon(Icons.water_drop, color: Color(0xFFB3261E), size: 12),
                const SizedBox(width: 2),
                Text(
                  '${widget.totalIchor}',
                  style: const TextStyle(
                    color: Color(0xFFEF5350),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(width: 5),
                // Cursed Ore
                const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 12),
                const SizedBox(width: 2),
                Text(
                  '${widget.cursedOre}',
                  style: const TextStyle(
                    color: Color(0xFF80CBC4),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(width: 5),
                // Bloodline Sigils
                ClipOval(
                  child: Image.asset(
                    'assets/images/blood_altar_sigil.jpg',
                    width: 12,
                    height: 12,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.military_tech, color: Color(0xFFE5A93C), size: 12),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '${widget.bloodlineSigils}',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onOpenSummoning != null)
            IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Color(0xFFFFD54F), size: 19),
              tooltip: 'Summoning Altar',
              onPressed: widget.onOpenSummoning,
            ),
          if (widget.onOpenSettings != null)
            IconButton(
              icon: Image.asset(
                'assets/images/UI/Settings Shield Icon Transparent.png',
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) => const Icon(Icons.settings, color: Color(0xFFFFD54F), size: 18),
              ),
              tooltip: 'Settings & Telco Network',
              onPressed: widget.onOpenSettings,
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.activeBoons.isNotEmpty) _buildActiveBoonsBanner(),
          if (widget.onLaunchMvpSkirmish != null) _buildMvpSkirmishBanner(),
          Expanded(
            child: _viewMode == CampaignViewMode.linearLadder
                ? _buildLinearCampaignView(context, theme)
                : LayoutBuilder(
              builder: (context, constraints) {
                final double mapWidth = constraints.maxWidth;
                final double mapHeight = constraints.maxHeight;
                final double maxD = widget.nodes.map((n) => n.depth).fold(1, (prev, elem) => elem > prev ? elem : prev).toDouble();

                // Vertical bounds: provide generous top/bottom safe clearance so all badges and labels fit
                // within the screen height without requiring scrolling
                final double topInset = 36.0;
                final double bottomInset = 64.0;
                final double usableHeight = (mapHeight - topInset - bottomInset).clamp(80.0, double.infinity);

                return Stack(
                  children: [
                    // Thematic Chapter Background Artwork
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.32,
                        child: Image.asset(
                          theme.backgroundAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // Background Parchment Grid & Leylines
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CampaignPathPainter(
                          nodes: widget.nodes,
                          maxDepth: maxD,
                          chapterTheme: theme,
                          topInset: topInset,
                          usableHeight: usableHeight,
                        ),
                      ),
                    ),
                    // Node interactive badges
                    ...widget.nodes.map((node) {
                      // Calculate position: depth (X axis: 0 to maxD), verticalRatio (Y axis: normalized within usable height)
                      final double x = (node.depth / (maxD > 0 ? maxD : 1.0)) * (mapWidth - 80) + 40;
                      final double y = topInset + node.verticalRatio * usableHeight;
                      final double badgeWidth = node.type == CampaignNodeType.boss ? 76.0 : 64.0;
                      final double leftPos = (x - badgeWidth / 2).clamp(4.0, (mapWidth - badgeWidth - 4.0).clamp(4.0, double.infinity));
                      final double badgeCenterOffset = node.type == CampaignNodeType.boss ? 24.0 : 19.0;

                      return Positioned(
                        left: leftPos,
                        top: y - badgeCenterOffset,
                        width: badgeWidth,
                        child: _buildNodeBadge(context, node),
                      );
                    }),
                    // Endgame Gauntlet Banner Button
                    if (widget.onOpenEndgameGauntlet != null)
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
                          onPressed: widget.onOpenEndgameGauntlet,
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

  Widget _buildLinearCampaignView(BuildContext context, ChapterTheme theme) {
    final stages = LinearCampaignStage.getStagesForChapter(widget.currentChapter);

    return Stack(
      children: [
        // Thematic Overworld Background
        Positioned.fill(
          child: Opacity(
            opacity: 0.38,
            child: Image.asset(
              'assets/images/realm_overworld_map.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F0F16)),
            ),
          ),
        ),

        // Gradient vignettes
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC0E0E14),
                Color(0x33000000),
                Color(0xF00A0A0E),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Horizontal Story Progression Stage Ladder
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.linear_scale, color: Color(0xFFE5A93C), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CAMPAIGN STORY TRACK: ${CampaignMapScreen.chapterTitle(widget.currentChapter)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          '$_completedLinearStages/${stages.length} CLEARED',
                          style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (widget.onOpenEndgameGauntlet != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.workspace_premium, size: 14),
                            label: const Text('ENDGAME GAUNTLET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E28),
                              foregroundColor: const Color(0xFFE5A93C),
                              side: const BorderSide(color: Color(0xFFE5A93C), width: 1.0),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: widget.onOpenEndgameGauntlet,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Horizontal Stages ListView
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: stages.length,
                  separatorBuilder: (_, __) => Center(
                    child: Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A93C).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final stage = stages[index];
                    final isUnlocked = stage.stageNumber <= (_completedLinearStages + 1);
                    final isCompleted = stage.stageNumber <= _completedLinearStages;
                    final isCurrent = stage.stageNumber == (_completedLinearStages + 1);

                    return _buildStageCard(context, stage, isUnlocked, isCompleted, isCurrent, theme);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageCard(
    BuildContext context,
    LinearCampaignStage stage,
    bool isUnlocked,
    bool isCompleted,
    bool isCurrent,
    ChapterTheme theme,
  ) {
    Color borderColor = const Color(0xFF2B2B38);
    if (stage.isBoss) {
      borderColor = const Color(0xFFE5A93C);
    } else if (isCurrent) {
      borderColor = const Color(0xFFEF5350);
    } else if (isCompleted) {
      borderColor = const Color(0xFF4CAF50);
    }

    return Container(
      width: 220,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isCurrent || stage.isBoss ? 2.0 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFB3261E).withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stage Thumbnail Header
            Stack(
              children: [
                SizedBox(
                  height: 85,
                  width: double.infinity,
                  child: Image.asset(
                    stage.thumbnailAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E28)),
                  ),
                ),
                Container(
                  height: 85,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE614141E)],
                    ),
                  ),
                ),
                // Stage Code Badge (e.g. 1-1)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stage.isBoss ? const Color(0xFFB3261E) : Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: stage.isBoss ? const Color(0xFFFFD54F) : const Color(0xFFE5A93C),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      stage.isBoss ? '👑 STAGE ${stage.stageCode}' : 'STAGE ${stage.stageCode}',
                      style: TextStyle(
                        color: stage.isBoss ? const Color(0xFFFFD54F) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Status Tag (COMPLETED / ACTIVE / LOCKED)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF2E7D32)
                          : (isCurrent ? const Color(0xFFC62828) : Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCompleted ? 'CLEARED' : (isCurrent ? 'ENGAGE' : 'LOCKED'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Stage Title & Description
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stage.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      stage.environmentTitle,
                      style: TextStyle(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Flexible(
                      child: Text(
                        stage.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 8.5,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Rewards Bar & Action Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: const Color(0xFF111118),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop, color: Color(0xFFB3261E), size: 11),
                      const SizedBox(width: 2),
                      Text(
                        '+${stage.rewardIchor}',
                        style: const TextStyle(color: Color(0xFFEF5350), fontSize: 9.0, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 11),
                      const SizedBox(width: 2),
                      Text(
                        '+${stage.rewardOre}',
                        style: const TextStyle(color: Color(0xFF80CBC4), fontSize: 9.0, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrent ? const Color(0xFFB3261E) : (isCompleted ? const Color(0xFF263238) : Colors.white12),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: isUnlocked
                        ? () {
                            // Synthesize campaign node from linear stage
                            final node = CampaignNode(
                              id: 'linear_${stage.stageCode}',
                              depth: stage.stageNumber,
                              verticalRatio: 0.5,
                              type: stage.type,
                              name: stage.name,
                              description: stage.description,
                              nextNodeIds: const [],
                              rewardIchor: stage.rewardIchor,
                              rewardOre: stage.rewardOre,
                              rewardSigils: stage.rewardSigils,
                              isCurrent: isCurrent,
                              isReachable: isUnlocked,
                              isVisited: isCompleted,
                              hazard: stage.hazard,
                              customThumbnailAsset: stage.thumbnailAsset,
                              customBackgroundAsset: stage.backgroundAsset,
                              scoutedAffinities: stage.enemyAffinities,
                            );
                            widget.onSelectNode(node);
                          }
                        : null,
                    child: Text(
                      isCurrent ? 'BATTLE' : (isCompleted ? 'REPLAY' : 'LOCKED'),
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              children: widget.activeBoons.map((b) => Container(
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

  Widget _buildMvpSkirmishBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB71C1C).withValues(alpha: 0.85),
            const Color(0xFF1E1E28).withValues(alpha: 0.95),
          ],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFFF5252), width: 1.2)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF5252), width: 1.0),
            ),
            child: const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MVP TRIAL: 3-WAVE ASHEN SKIRMISH',
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Ash Legion vs Crypt Stalkers • Boss Gorgoroth the Flayed • Vladislav Grimoire',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            key: const ValueKey('launch_mvp_skirmish_button'),
            onPressed: widget.onLaunchMvpSkirmish,
            icon: const Icon(Icons.sports_kabaddi, size: 14, color: Colors.black),
            label: const Text(
              'ENGAGE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
    } else if (node.type == CampaignNodeType.teleportStone) {
      borderColor = const Color(0xFF00E5FF);
      bgColor = const Color(0xFF00384D);
      icon = Icons.auto_awesome;
    } else if (node.isCurrent) {
      borderColor = const Color(0xFFE5A93C);
      bgColor = const Color(0xFFE5A93C).withValues(alpha: 0.2);
    } else if (node.isReachable) {
      borderColor = const Color(0xFFB3261E);
      bgColor = const Color(0xFF2A1515);
    }

    final double circleSize = node.type == CampaignNodeType.boss ? 48.0 : (node.type == CampaignNodeType.teleportStone ? 42.0 : 38.0);

    return GestureDetector(
      onTap: canTap ? () => _showNodeEncounterDialog(context, node) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular node avatar with stacked hazard indicator badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: (canTap || node.isCurrent) ? 2.2 : 1.2,
                  ),
                  boxShadow: canTap
                      ? [
                          BoxShadow(
                            color: node.type == CampaignNodeType.teleportStone
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                                : const Color(0xFFB3261E).withValues(alpha: 0.45),
                            blurRadius: node.type == CampaignNodeType.teleportStone ? 12 : 8,
                            spreadRadius: node.type == CampaignNodeType.teleportStone ? 2.5 : 1.5,
                          )
                        ]
                      : null,
                ),
                child: node.customThumbnailAsset != null && node.type != CampaignNodeType.boss
                    ? ClipOval(
                        child: Opacity(
                          opacity: canTap ? 0.95 : 0.45,
                          child: Image.asset(
                            node.customThumbnailAsset!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              icon,
                              size: 18,
                              color: canTap ? Colors.white : (node.isVisited ? const Color(0xFF81C784) : Colors.white30),
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: node.type == CampaignNodeType.boss ? 24 : 18,
                        color: canTap ? Colors.white : (node.isVisited ? const Color(0xFF81C784) : Colors.white30),
                      ),
              ),
              // Corner Hazard Icon Badge overlay
              if (node.hazard != CampaignHazardType.none && !node.isVisited)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141B),
                      shape: BoxShape.circle,
                      border: Border.all(color: node.hazard.color, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: node.hazard.color.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(node.hazard.icon, color: node.hazard.color, size: 8.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Scouted Badge
          if (node.isScouted && !node.isVisited)
            Container(
              margin: const EdgeInsets.only(bottom: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: const Color(0xFF006064).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF00E5FF), width: 0.6),
              ),
              child: const Text(
                'SCOUTED',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 6.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          // Node Title Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
            decoration: BoxDecoration(
              color: const Color(0xFF14141B).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: canTap ? Colors.white : Colors.white38,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Scouted Affinities Chips
          if (node.isScouted && !node.isVisited && node.scoutedAffinities.isNotEmpty) ...[
            const SizedBox(height: 1.5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: node.scoutedAffinities.take(3).map((aff) {
                final color = _affinityColor(aff);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: color, width: 0.5),
                  ),
                  child: Text(
                    _affinityAbbr(aff),
                    style: TextStyle(
                      color: color,
                      fontSize: 5.5,
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
    final theme = ChapterTheme.forChapter(widget.currentChapter);

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
                                _bossImageForChapter(widget.currentChapter),
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
                  // Non-Boss Thematic Thumbnail Card
                  if (node.type != CampaignNodeType.boss && node.customThumbnailAsset != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              node.customThumbnailAsset!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
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
                  // Environmental Hazard Warning Banner
                  if (node.hazard != CampaignHazardType.none) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: node.hazard.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: node.hazard.color.withValues(alpha: 0.8), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(node.hazard.icon, color: node.hazard.color, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HAZARD: ${node.hazard.displayName.toUpperCase()}',
                                  style: TextStyle(
                                    color: node.hazard.color,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  node.hazard.shortDescription,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 8.5,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (node.type == CampaignNodeType.teleportStone)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00384D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SAFE EXTRACTION: Leave delve with 100% of accumulated loot or continue to Boss Chamber.',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
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
                          widget.onSelectNode(node);
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
      case CampaignNodeType.teleportStone:
        return 'ACTIVATE RUNIC EXTRACTION';
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
      case CampaignNodeType.teleportStone:
        return Icons.auto_awesome;
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
  final double topInset;
  final double? usableHeight;

  _CampaignPathPainter({
    required this.nodes,
    this.maxDepth = 4.0,
    required this.chapterTheme,
    this.topInset = 36.0,
    this.usableHeight,
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
    final double effUsableHeight = usableHeight ?? (size.height - topInset - 64.0).clamp(80.0, double.infinity);

    for (final node in nodes) {
      final double x = (node.depth / safeMaxD) * (size.width - 80) + 40;
      final double y = topInset + node.verticalRatio * effUsableHeight;
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
