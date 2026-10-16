import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../generals/general_command_service.dart';
import '../settings/settings_dialog.dart';

class HomeScreen extends StatelessWidget {
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
  final VoidCallback onOpenSettings;

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
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final profile = GeneralProfile.getByType(activeGeneral);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Hero HUD Art
          Image.asset(
            'assets/images/UI/Main Page HUD background with less people.png',
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
                radius: 1.15,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE60A0A0E),
                  Color(0x33000000),
                  Color(0xF00A0A0E),
                ],
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),

          // Main Interactive Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: App Branding, Currencies, Settings & Telco Trigger
                _buildTopHeader(context, profile),

                // Main Content Body: Commander Dossier + Game Mode Cards
                Expanded(
                  child: SingleChildScrollView(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.90),
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
          Row(
            children: [
              Image.asset(
                'assets/images/UI/Ruby Shield Icon transparent.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 24),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'ASHEN CRUCIBLE',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'COMMAND CITADEL • CHAPTER HEADQUARTERS',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 8.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Tri-Currency Display
          _buildCurrencyPill(
            icon: Icons.water_drop,
            iconColor: const Color(0xFFB3261E),
            value: '$totalIchor',
            valueColor: const Color(0xFFEF5350),
            tooltip: 'Raw Ichor (Fusion & Evolution)',
          ),
          const SizedBox(width: 8),
          _buildCurrencyPill(
            icon: Icons.diamond_outlined,
            iconColor: const Color(0xFF26A69A),
            value: '$cursedOre',
            valueColor: const Color(0xFF80CBC4),
            tooltip: 'Cursed Ore (Relic Reforging)',
          ),
          const SizedBox(width: 8),
          _buildCurrencyPill(
            icon: Icons.military_tech,
            iconColor: const Color(0xFFFFD54F),
            value: '$bloodlineSigils',
            valueColor: const Color(0xFFFFE082),
            tooltip: 'Bloodline Sigils (Phylactery & Sanguine Altars)',
          ),

          const SizedBox(width: 12),

          // Settings / Telco Shield Button
          InkWell(
            onTap: onOpenSettings,
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

          // Close / Exit modal button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
            tooltip: 'Return to Overworld',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                onOpenCampaign();
              }
            },
          ),
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
                    _buildStatusChip('CAMPAIGN', 'CH. $currentChapter (Depths 0-5)', const Color(0xFFE5A93C)),
                    const SizedBox(width: 8),
                    _buildStatusChip('ASCENSION', 'A$currentAscension Tier', currentAscension > 0 ? const Color(0xFFFF5252) : const Color(0xFF81C784)),
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
            onPressed: onOpenBrigadeRoster,
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
            style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w600),
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
        'title': 'CAMPAIGN JOURNEY',
        'subtitle': 'Overworld nodes, bosses & Ascensions A0–A10',
        'badge': 'MAIN EXPEDITION',
        'badgeColor': const Color(0xFFE5A93C),
        'iconAsset': 'assets/images/UI/Campaign Map Shield Icon Transpartent.png',
        'action': onOpenCampaign,
        'borderColor': const Color(0xFFE5A93C),
      },
      {
        'title': 'SPATIAL BATTLE ARENA',
        'subtitle': '30 Hz real-time ticks, 2.5D nodes & 3-wave skirmish',
        'badge': 'TACTICAL COMBAT',
        'badgeColor': const Color(0xFFEF5350),
        'iconAsset': 'assets/images/UI/Crossed Sword Shield Icon Transparent.png',
        'action': onOpenBattleArena,
        'borderColor': const Color(0xFFB3261E),
      },
      {
        'title': 'THE CRUCIBLE ALTAR',
        'subtitle': 'Bloodline infusion, progenitor fusion & 6-gen pedigree',
        'badge': 'GENETIC EVOLUTION',
        'badgeColor': const Color(0xFFFF7043),
        'iconAsset': 'assets/images/UI/Flame Shield icon Transparent.png',
        'action': onOpenCrucible,
        'borderColor': const Color(0xFFFF7043),
      },
      {
        'title': 'THE RELIC FORGE',
        'subtitle': 'Equipment crafting, sockets & runic affixes',
        'badge': 'ARSENAL ENCHANT',
        'badgeColor': const Color(0xFF42A5F5),
        'iconAsset': 'assets/images/UI/Relic Forge Shield Icon Transparent.png',
        'action': onOpenRelicForge,
        'borderColor': const Color(0xFF1976D2),
      },
      {
        'title': 'ENDGAME GAUNTLET',
        'subtitle': 'World Titan, Void Herald & Colossus trials',
        'badge': 'CHALLENGE TRIAL',
        'badgeColor': const Color(0xFFAB47BC),
        'iconAsset': 'assets/images/UI/Dungeon Shield Icon Transparent.png',
        'action': onOpenEndgameGauntlet,
        'borderColor': const Color(0xFF9C27B0),
      },
      {
        'title': 'AFFINITY CODEX',
        'subtitle': 'Hexagonal affinity wheel & combat mechanics',
        'badge': 'LORE & MECHANICS',
        'badgeColor': const Color(0xFF26A69A),
        'iconAsset': 'assets/images/UI/Skull Shield Icon Transparent.png',
        'action': onOpenAffinityCodex,
        'borderColor': const Color(0xFF00897B),
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
          color: const Color(0xFF14141F).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Shield Crest Icon
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
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
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.8),
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
                      color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.65),
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
              color: borderColor.withValues(alpha: 0.7),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
            onTap: onOpenSettings,
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
