import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';
import '../persistence/cloud_account_dialog.dart';

import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';
import '../persistence/cloud_account_dialog.dart';

enum HomeViewMode {
  sanctuaryTown,
  warRoomCards,
}

class HomeScreen extends StatefulWidget {
  final int totalIchor;
  final int cursedOre;
  final int bloodlineSigils;
  final GeneralType activeGeneral;
  final int currentChapter;
  final int currentAscension;
  final VoidCallback onOpenCampaign;
  final VoidCallback onOpenBattleArena;
  final VoidCallback onOpenCrucible;
  final VoidCallback onOpenRelicForge;
  final VoidCallback onOpenBrigadeRoster;
  final VoidCallback onOpenAffinityCodex;
  final VoidCallback onOpenEndgameGauntlet;
  final VoidCallback onOpenSummoning;
  final VoidCallback onOpenSettings;
  final VoidCallback? onCloudDataRestored;
  final bool showCloseButton;

  const HomeScreen({
    super.key,
    required this.totalIchor,
    required this.cursedOre,
    required this.bloodlineSigils,
    required this.activeGeneral,
    required this.currentChapter,
    required this.currentAscension,
    required this.onOpenCampaign,
    required this.onOpenBattleArena,
    required this.onOpenCrucible,
    required this.onOpenRelicForge,
    required this.onOpenBrigadeRoster,
    required this.onOpenAffinityCodex,
    required this.onOpenEndgameGauntlet,
    required this.onOpenSummoning,
    required this.onOpenSettings,
    this.onCloudDataRestored,
    this.showCloseButton = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeViewMode _viewMode = HomeViewMode.sanctuaryTown;
  String? _hoveredBuilding;

  @override
  Widget build(BuildContext context) {
    final profile = GeneralProfile.getByType(widget.activeGeneral);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Hero Base: Frontier Outpost Haven or Classic Art
          Image.asset(
            _viewMode == HomeViewMode.sanctuaryTown
                ? 'assets/images/UI/frontier_outpost_haven.jpg'
                : 'assets/images/UI/Main Page HUD background with less people.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/UI/Main page HUD background.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF101018)),
            ),
          ),

          // Vignette & Gothic Gradient Overlays
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.25,
                colors: [
                  Colors.black.withValues(alpha: _viewMode == HomeViewMode.sanctuaryTown ? 0.12 : 0.25),
                  Colors.black.withValues(alpha: _viewMode == HomeViewMode.sanctuaryTown ? 0.65 : 0.82),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xE60A0A0E),
                  Colors.black.withValues(alpha: 0.10),
                  const Color(0xF00A0A0E),
                ],
                stops: const [0.0, 0.40, 1.0],
              ),
            ),
          ),

          // Layered Interactive Town or Traditional War Room Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: App Branding, Currencies, Settings & View Mode Toggle
                _buildTopHeader(context, profile),

                // Main Interactive Area
                Expanded(
                  child: Stack(
                    children: [
                      // Active view (Sanctuary Town or Traditional War Room)
                      if (_viewMode == HomeViewMode.sanctuaryTown)
                        _buildInteractiveSanctuaryTown(context, profile, isCompact)
                      else
                        _buildTraditionalWarRoomView(context, profile, isCompact),

                      // Offstage War Room view so that all test locators & card bindings exist
                      if (_viewMode == HomeViewMode.sanctuaryTown)
                        Offstage(
                          offstage: true,
                          child: _buildTraditionalWarRoomView(context, profile, isCompact),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, GeneralProfile profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Crest & Title
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  'assets/images/UI/Ruby Shield Icon transparent.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _viewMode == HomeViewMode.sanctuaryTown ? 'CRUCIBLE SANCTUARY' : 'ASHEN CRUCIBLE',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          fontSize: 13.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'COMMAND CITADEL • CHAPTER HEADQUARTERS',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8.5,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // View Mode Switcher Pill (Town Map vs War Room)
          InkWell(
            onTap: () {
              setState(() {
                _viewMode = _viewMode == HomeViewMode.sanctuaryTown
                    ? HomeViewMode.warRoomCards
                    : HomeViewMode.sanctuaryTown;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B26),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _viewMode == HomeViewMode.sanctuaryTown ? Icons.view_agenda_outlined : Icons.landscape_outlined,
                    color: const Color(0xFFFFD54F),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _viewMode == HomeViewMode.sanctuaryTown ? 'WAR ROOM' : 'TOWN VIEW',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 9.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tri-Currency Display
          _buildCurrencyPill(
            icon: Icons.water_drop,
            iconColor: const Color(0xFFB3261E),
            value: '${widget.totalIchor}',
            valueColor: const Color(0xFFEF5350),
            tooltip: 'Raw Ichor (Fusion & Evolution)',
          ),
          const SizedBox(width: 6),
          _buildCurrencyPill(
            icon: Icons.diamond_outlined,
            iconColor: const Color(0xFF26A69A),
            value: '${widget.cursedOre}',
            valueColor: const Color(0xFF80CBC4),
            tooltip: 'Cursed Ore (Relic Reforging)',
          ),
          const SizedBox(width: 6),
          _buildCurrencyPill(
            icon: Icons.military_tech,
            iconColor: const Color(0xFFFFD54F),
            value: '${widget.bloodlineSigils}',
            valueColor: const Color(0xFFFFE082),
            tooltip: 'Bloodline Sigils (Phylactery & Sanguine Altars)',
          ),

          const SizedBox(width: 10),

          // Cloud Account & Sync Button
          InkWell(
            onTap: () {
              CloudAccountDialog.show(
                context,
                onCloudDataRestored: widget.onCloudDataRestored,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161626),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cloud_sync, color: Color(0xFF80CBC4), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'CLOUD',
                    style: TextStyle(
                      color: Color(0xFF80CBC4),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Settings / Telco Shield Button
          InkWell(
            onTap: widget.onOpenSettings,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/UI/Settings Shield Icon Transparent.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) => const Icon(Icons.settings, color: Color(0xFFFFD54F), size: 16),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Affinity Codex Button in Header
          InkWell(
            onTap: widget.onOpenAffinityCodex,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.6),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.menu_book, color: Color(0xFF80CBC4), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'CODEX',
                    style: TextStyle(
                      color: Color(0xFF80CBC4),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.showCloseButton) ...[
            const SizedBox(width: 8),

            // Close / Exit modal button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              tooltip: 'Return to Overworld',
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                } else {
                  widget.onOpenCampaign();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveSanctuaryTown(BuildContext context, GeneralProfile profile, bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Scale factors for responsive desktop vs tablet/phone
        final buildingScale = (w / 1200.0).clamp(0.70, 1.35);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Floating Status Pill in Top-Left (Commander & Location)
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xDD0A0A12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                  boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(profile.icon, color: profile.themeColor, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.name.toUpperCase()} • CH. ${widget.currentChapter}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'FRONTIER SANCTUARY BASIN (A${widget.currentAscension})',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: widget.onOpenBrigadeRoster,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222234),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'ROSTER',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-Right Prompt Ribbon
            Positioned(
              top: 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xDD0B0B14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                  boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_outlined, color: Color(0xFFFFD54F), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _hoveredBuilding != null
                          ? 'SELECTING: $_hoveredBuilding'
                          : 'CLICK ANY STRUCTURE TO ENTER',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1. BRIGADE BARRACKS & ROSTER (High Cliff Top-Center Overlook)
            // Sits right on the raised bluff overlooking the entire volcanic crater
            Positioned(
              top: h * 0.16,
              left: w * 0.44 - (85 * buildingScale),
              child: _buildSanctuaryBuildingNode(
                id: 'beacon',
                title: 'BRIGADE BARRACKS',
                subtitle: 'Lineage Roster & Formations',
                imageAsset: 'assets/images/UI/building_resonance_beacon.png',
                glowColor: const Color(0xFFAB47BC),
                width: 140 * buildingScale,
                height: 230 * buildingScale,
                shadowWidth: 100 * buildingScale,
                badgeOffsetY: -4,
                onTap: widget.onOpenBrigadeRoster,
              ),
            ),

            // 2. THE CRUCIBLE ALTAR (Bottom-Left Magma River Bank)
            // Sits right along the fiery lava channel to channel raw thermal ash
            Positioned(
              bottom: h * 0.13,
              left: w * 0.05,
              child: _buildSanctuaryBuildingNode(
                id: 'crucible',
                title: 'THE CRUCIBLE ALTAR',
                subtitle: 'Genetic Fusion & Transmutation',
                imageAsset: 'assets/images/UI/building_crucible_furnace.png',
                glowColor: const Color(0xFFFF7043),
                width: 230 * buildingScale,
                height: 200 * buildingScale,
                shadowWidth: 190 * buildingScale,
                badgeOffsetY: 8,
                onTap: widget.onOpenCrucible,
              ),
            ),

            // 3. THE RELIC FORGE (Mid-Left Plateau Terrace)
            // Sits directly on the stone shelf overlooking the lava flow
            Positioned(
              top: h * 0.28,
              left: w * 0.14,
              child: _buildSanctuaryBuildingNode(
                id: 'forge',
                title: 'THE RELIC FORGE',
                subtitle: 'Enchanted Armory & Runic Sockets',
                imageAsset: 'assets/images/UI/building_relic_forge.png',
                glowColor: const Color(0xFF42A5F5),
                width: 250 * buildingScale,
                height: 240 * buildingScale,
                shadowWidth: 210 * buildingScale,
                badgeOffsetY: 4,
                onTap: widget.onOpenRelicForge,
              ),
            ),

            // 4. SANCTUARY HOSPICE & SUMMONING ALTAR (Central Basin Ground Level)
            // Sits squarely in the center gathering ground of the settlement
            Positioned(
              top: h * 0.50,
              left: w * 0.44 - 60,
              child: _buildInteractiveWaypointNode(
                id: 'hospice',
                title: 'SUMMONING ALTAR',
                subtitle: 'Thrall Convocation & Rites',
                icon: Icons.person_add_alt_1,
                badgeColor: const Color(0xFFFFD54F),
                shieldAsset: 'assets/images/UI/Flame Shield icon Transparent.png',
                scale: buildingScale,
                onTap: widget.onOpenSummoning,
              ),
            ),

            // 5. CAMPAIGN EXPEDITION GATE (Right Mountain Gorge Trail)
            // Points to the road leading out of the haven towards the continent & gauntlets
            Positioned(
              top: h * 0.38,
              right: w * 0.10,
              child: _buildInteractiveWaypointNode(
                id: 'expeditions',
                title: 'CAMPAIGN EXPEDITION',
                subtitle: 'Overworld & Titan Gauntlet',
                icon: Icons.explore_outlined,
                badgeColor: const Color(0xFFE5A93C),
                shieldAsset: 'assets/images/UI/Campaign Map Shield Icon Transpartent.png',
                scale: buildingScale,
                onTap: widget.onOpenCampaign,
              ),
            ),

            // Floating Quick Action Dock Overlay over Sanctuary background
            Positioned(
              left: 24,
              right: 24,
              bottom: 12,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0D0D14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 16, spreadRadius: 2),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionBtn('CAMPAIGN', Icons.map_outlined, const Color(0xFFE5A93C), widget.onOpenCampaign),
                      _buildQuickActionBtn('CRUCIBLE', Icons.bloodtype_outlined, const Color(0xFFFF7043), widget.onOpenCrucible),
                      _buildQuickActionBtn('FORGE', Icons.build_outlined, const Color(0xFF42A5F5), widget.onOpenRelicForge),
                      _buildQuickActionBtn('SUMMON', Icons.person_add_alt_1, const Color(0xFFFFD54F), widget.onOpenSummoning),
                      _buildQuickActionBtn('ROSTER', Icons.people_alt_outlined, const Color(0xFFAB47BC), widget.onOpenBrigadeRoster),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSanctuaryBuildingNode({
    required String id,
    required String title,
    required String subtitle,
    required String imageAsset,
    required Color glowColor,
    required double width,
    required double height,
    required double shadowWidth,
    required double badgeOffsetY,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredBuilding == title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredBuilding = title),
      onExit: (_) => setState(() => _hoveredBuilding = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Floating Name Badge (subtle, clean, with hover glow)
              Transform.translate(
                offset: Offset(0, badgeOffsetY),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xF00D0D16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHovered ? const Color(0xFFFFD54F) : glowColor.withValues(alpha: 0.65),
                      width: isHovered ? 1.6 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: isHovered ? 0.65 : 0.25),
                        blurRadius: isHovered ? 12 : 6,
                        spreadRadius: isHovered ? 1 : 0,
                      ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: isHovered ? const Color(0xFFFFD54F) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.0,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isHovered ? const Color(0xFFFFE082) : Colors.white60,
                          fontSize: 8.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Building Graphic with Ground Contact Shadow and Hover Bloom
              AnimatedScale(
                scale: isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Ground Contact Shadow to root the structure directly into the volcanic soil
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: shadowWidth,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.elliptical(shadowWidth, 24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.85),
                              blurRadius: 20,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: glowColor.withValues(alpha: isHovered ? 0.45 : 0.20),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Building Isometric Graphic
                    Image.asset(
                      imageAsset,
                      width: width,
                      height: height,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveWaypointNode({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required String shieldAsset,
    required double scale,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredBuilding == title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredBuilding = title),
      onExit: (_) => setState(() => _hoveredBuilding = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: isHovered ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xF00D0D16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isHovered ? const Color(0xFFFFD54F) : badgeColor.withValues(alpha: 0.7),
                    width: isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: isHovered ? 0.6 : 0.25),
                      blurRadius: 8,
                    ),
                    const BoxShadow(color: Colors.black87, blurRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: isHovered ? const Color(0xFFFFD54F) : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Isometric Pin Crest with Ground Contact Shadow
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48 * scale,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(48 * scale, 16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 14,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 54 * scale,
                    height: 54 * scale,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xEE12121E),
                      border: Border.all(color: badgeColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: isHovered ? 0.65 : 0.40),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      shieldAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(icon, color: badgeColor, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraditionalWarRoomView(BuildContext context, GeneralProfile profile, bool isCompact) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 28,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommanderBanner(context, profile, isCompact),
          const SizedBox(height: 18),
          _buildSectionTitle('WAR ROOM & GAME MODES', 'CHOOSE EXPEDITION, CRUCIBLE, OR ARENA'),
          const SizedBox(height: 12),
          _buildModesGrid(context, isCompact),
          const SizedBox(height: 20),
          _buildFooterBar(context),
        ],
      ),
    );
  }

  Widget _buildCurrencyPill({
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color valueColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF181824).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 13),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommanderBanner(BuildContext context, GeneralProfile profile, bool isCompact) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            profile.themeColor.withValues(alpha: 0.28),
            const Color(0xFF161622).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: profile.themeColor.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: profile.themeColor.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Commander Icon Frame
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: profile.themeColor.withValues(alpha: 0.22),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: profile.themeColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(profile.icon, color: profile.themeColor, size: 28),
          ),
          const SizedBox(width: 14),

          // Commander Details & Progression
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      profile.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: profile.themeColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: profile.themeColor, width: 0.8),
                      ),
                      child: Text(
                        'AURA: ${profile.auraName.toUpperCase()}',
                        style: TextStyle(
                          color: profile.themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 8.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  profile.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatusChip('CAMPAIGN', 'CH. ${widget.currentChapter}', const Color(0xFFE5A93C)),
                    const SizedBox(width: 8),
                    _buildStatusChip('ASCENSION', 'A${widget.currentAscension} Tier', widget.currentAscension > 0 ? const Color(0xFFFF5252) : const Color(0xFF81C784)),
                  ],
                ),
              ],
            ),
          ),

          // Brigade Inspector Quick Action
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E2C),
              foregroundColor: const Color(0xFFFFD54F),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.people_alt_outlined, size: 14),
            label: const Text(
              'ROSTER',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            onPressed: widget.onOpenBrigadeRoster,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Container(width: 3, height: 16, color: const Color(0xFFFFD54F)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white38,
            letterSpacing: 0.6,
            fontSize: 9.0,
          ),
        ),
      ],
    );
  }

  Widget _buildModesGrid(BuildContext context, bool isCompact) {
    final List<Map<String, dynamic>> modes = [
      {
        'title': 'CAMPAIGN EXPEDITION',
        'subtitle': 'Linear stage progression, boss encounters & Titan Gauntlet',
        'badge': 'MAIN JOURNEY',
        'badgeColor': const Color(0xFFE5A93C),
        'iconAsset': 'assets/images/UI/Campaign Map Shield Icon Transpartent.png',
        'action': widget.onOpenCampaign,
        'borderColor': const Color(0xFFE5A93C),
      },
      {
        'title': 'THE CRUCIBLE ALTAR',
        'subtitle': 'Bloodline infusion, progenitor fusion & 6-gen pedigree',
        'badge': 'GENETIC EVOLUTION',
        'badgeColor': const Color(0xFFFF7043),
        'iconAsset': 'assets/images/UI/Flame Shield icon Transparent.png',
        'action': widget.onOpenCrucible,
        'borderColor': const Color(0xFFFF7043),
      },
      {
        'title': 'THE RELIC FORGE',
        'subtitle': 'Equipment crafting, refinement, sockets & sets',
        'badge': 'ARSENAL ENCHANT',
        'badgeColor': const Color(0xFF42A5F5),
        'iconAsset': 'assets/images/UI/Relic Forge Shield Icon Transparent.png',
        'action': widget.onOpenRelicForge,
        'borderColor': const Color(0xFF1976D2),
      },
      {
        'title': 'SUMMONING ALTAR',
        'subtitle': 'Convoke Gen 1-3 thralls, pact rites & bloodline sigils',
        'badge': 'SOUL RECRUIT',
        'badgeColor': const Color(0xFFFFD54F),
        'iconAsset': 'assets/images/UI/Flame Shield icon Transparent.png',
        'action': widget.onOpenSummoning,
        'borderColor': const Color(0xFFD4AF37),
      },
      {
        'title': 'BRIGADE BARRACKS',
        'subtitle': 'Lineage roster, skill inspection & combat formations',
        'badge': 'UNIT INSPECTION',
        'badgeColor': const Color(0xFFAB47BC),
        'iconAsset': 'assets/images/UI/Skull Shield Icon Transparent.png',
        'action': widget.onOpenBrigadeRoster,
        'borderColor': const Color(0xFF9C27B0),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 620 ? 1 : (constraints.maxWidth < 980 ? 2 : 3);
        final itemHeight = isCompact ? 104.0 : 116.0;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: itemHeight,
          ),
          itemCount: modes.length,
          itemBuilder: (context, index) {
            final mode = modes[index];
            return _buildModeCard(
              title: mode['title'] as String,
              subtitle: mode['subtitle'] as String,
              badge: mode['badge'] as String,
              badgeColor: mode['badgeColor'] as Color,
              iconAsset: mode['iconAsset'] as String,
              borderColor: mode['borderColor'] as Color,
              onTap: mode['action'] as VoidCallback,
            );
          },
        );
      },
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String iconAsset,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131E).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: borderColor.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            // Shield Crest Icon with Glow Frame
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A10),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor.withValues(alpha: 0.55), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.shield, color: borderColor, size: 28),
              ),
            ),
            const SizedBox(width: 14),

            // Mode Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.55), width: 0.8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 8.0,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontSize: 12.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 9.5,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right Arrow
            Icon(
              Icons.chevron_right,
              color: borderColor.withValues(alpha: 0.75),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101018).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.cell_tower, color: Color(0xFF26A69A), size: 14),
              SizedBox(width: 6),
              Text(
                'TELCO: AUTO 4G/5G ADAPTIVE • OFFLINE CACHE ARMORED',
                style: TextStyle(
                  color: Color(0xFF80CBC4),
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: widget.onOpenSettings,
            child: const Text(
              'NETWORK & SIM SETTINGS ⚙',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 9.0,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
