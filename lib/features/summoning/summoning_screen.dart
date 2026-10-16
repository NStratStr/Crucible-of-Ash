import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
import 'summoning_service.dart';

class SummoningScreen extends StatefulWidget {
  final int totalIchor;
  final int bloodlineSigils;
  final Function(SummonResult result) onSummonExecuted;
  final VoidCallback? onClose;

  const SummoningScreen({
    super.key,
    required this.totalIchor,
    required this.bloodlineSigils,
    required this.onSummonExecuted,
    this.onClose,
  });

  static Future<void> showAsModal({
    required BuildContext context,
    required int totalIchor,
    required int bloodlineSigils,
    required Function(SummonResult result) onSummonExecuted,
  }) {
    return showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => SummoningScreen(
        totalIchor: totalIchor,
        bloodlineSigils: bloodlineSigils,
        onSummonExecuted: onSummonExecuted,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<SummoningScreen> createState() => _SummoningScreenState();
}

class _SummoningScreenState extends State<SummoningScreen> {
  SummonBannerType _selectedBannerType = SummonBannerType.ashenBloodline;
  bool _isPerformingRitual = false;
  List<UnitEntity>? _revealedUnits;
  int _revealedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final banner = SummoningService.banners[_selectedBannerType]!;
    final bool canAffordSingle = banner.usesSigils
        ? widget.bloodlineSigils >= banner.singleCost
        : widget.totalIchor >= banner.singleCost;
    final bool canAffordMulti = banner.usesSigils
        ? widget.bloodlineSigils >= banner.multiCost
        : widget.totalIchor >= banner.multiCost;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background occult artwork
          Image.asset(
            'assets/images/blood_altar_sigil.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/UI/Main Page HUD background with less people.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F0F18)),
            ),
          ),

          // Vignette & Gothic Dark Overlays
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.88),
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
                  Color(0xE60A0A10),
                  Color(0x55000000),
                  Color(0xF50A0A10),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar (Title, Currencies, Rates Modal, Close Button)
                _buildHeader(context),

                // Main Altar & Banner Presentation
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Banner Type Switcher Tabs
                        _buildBannerTabs(),
                        const SizedBox(height: 14),

                        // Center Summoning Circle & Focus Miniature Hero Card
                        _buildCenterAltarStage(banner),
                        const SizedBox(height: 14),

                        // Banner Lore & Affordability Guidance
                        _buildBannerLoreCard(banner),
                      ],
                    ),
                  ),
                ),

                // Bottom Summoning Action Controls (1x and 10x Pulls)
                _buildActionControlPanel(banner, canAffordSingle, canAffordMulti),
              ],
            ),
          ),

          // Ritual In-Progress Overlay
          if (_isPerformingRitual)
            _buildRitualLoadingOverlay(),

          // Card Reveal Dialog Overlay
          if (_revealedUnits != null && _revealedUnits!.isNotEmpty)
            _buildCardsRevealModal(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/UI/Flame Shield icon Transparent.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.fireplace, color: Color(0xFFFFD54F), size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'SUMMONING CONVOCATION',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
              ),
              Text(
                'THE OCCULT ALTAR • AWAKEN BLOODLINE THRALLS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 8.5,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Currencies
          _buildCurrencyBadge(
            icon: Icons.water_drop,
            color: const Color(0xFFEF5350),
            value: '${widget.totalIchor}',
            tooltip: 'Raw Ichor',
          ),
          const SizedBox(width: 8),
          _buildCurrencyBadge(
            icon: Icons.military_tech,
            color: const Color(0xFFFFD54F),
            value: '${widget.bloodlineSigils}',
            tooltip: 'Bloodline Sigils',
          ),

          const SizedBox(width: 10),

          // Rates & Probability Info Button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 22),
            tooltip: 'Convocation Rates & Probabilities',
            onPressed: () => _showRatesDialog(context),
          ),

          // Close Button
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              tooltip: 'Leave Altar',
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencyBadge({
    required IconData icon,
    required Color color,
    required String value,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
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

  Widget _buildBannerTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: SummonBannerType.values.map((type) {
          final banner = SummoningService.banners[type]!;
          final isSelected = _selectedBannerType == type;
          final accentColor = type == SummonBannerType.consecratedSigil
              ? const Color(0xFFFFD54F)
              : (type == SummonBannerType.cryptCovenant ? const Color(0xFFAB47BC) : const Color(0xFFE5A93C));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => setState(() => _selectedBannerType = type),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withValues(alpha: 0.22) : const Color(0xFF181822),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? accentColor : Colors.white12,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      banner.usesSigils ? Icons.military_tech : Icons.auto_awesome,
                      color: isSelected ? accentColor : Colors.white54,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      banner.title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCenterAltarStage(BannerConfig banner) {
    final accentColor = banner.type == SummonBannerType.consecratedSigil
        ? const Color(0xFFFFD54F)
        : (banner.type == SummonBannerType.cryptCovenant ? const Color(0xFFAB47BC) : const Color(0xFFE5A93C));

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.18),
            const Color(0xFF14141E).withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor, width: 0.8),
            ),
            child: Text(
              banner.bannerBadge,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Occult Runic Seal Centerpiece
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F0F16),
              border: Border.all(color: accentColor, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.all_inclusive,
                    color: accentColor.withValues(alpha: 0.3),
                    size: 80,
                  ),
                  Icon(
                    banner.usesSigils ? Icons.military_tech : Icons.fireplace,
                    color: accentColor,
                    size: 52,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Banner Title & Subtitle
          Text(
            banner.title,
            style: TextStyle(
              color: accentColor,
              fontFamily: 'serif',
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            banner.subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBannerLoreCard(BannerConfig banner) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_stories, color: Color(0xFFFFD54F), size: 14),
              SizedBox(width: 6),
              Text(
                'COVENANT INSCRIPTION',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            banner.loreDescription,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRateIndicator('GEN 1 THRALL', '${(banner.gen1Rate * 100).toInt()}%', const Color(0xFFB0BEC5)),
              _buildRateIndicator('GEN 2 ELITE', '${(banner.gen2Rate * 100).toInt()}%', const Color(0xFFFFB74D)),
              _buildRateIndicator('GEN 3 PUREBLOOD', '${(banner.gen3Rate * 100).toInt()}%', const Color(0xFFFFD54F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateIndicator(String label, String rate, Color color) {
    return Column(
      children: [
        Text(
          rate,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionControlPanel(BannerConfig banner, bool canAfford1x, bool canAfford10x) {
    final currencyIcon = banner.usesSigils ? Icons.military_tech : Icons.water_drop;
    final currencyColor = banner.usesSigils ? const Color(0xFFFFD54F) : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1x Summon Button
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford1x ? const Color(0xFF263238) : const Color(0xFF181820),
                foregroundColor: canAfford1x ? Colors.white : Colors.white30,
                side: BorderSide(
                  color: canAfford1x ? const Color(0xFF78909C) : Colors.white12,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canAfford1x ? () => _executeSummon(1) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SUMMON 1x',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currencyIcon, color: canAfford1x ? currencyColor : Colors.white30, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${banner.singleCost} ${banner.currencyName}',
                        style: TextStyle(
                          color: canAfford1x ? currencyColor : Colors.white30,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 10x Multi-Summon Button (Discounted)
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford10x ? const Color(0xFF3E2723) : const Color(0xFF181820),
                foregroundColor: canAfford10x ? const Color(0xFFFFD54F) : Colors.white30,
                side: BorderSide(
                  color: canAfford10x ? const Color(0xFFFFD54F) : Colors.white12,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                shadowColor: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                elevation: canAfford10x ? 6 : 0,
              ),
              onPressed: canAfford10x ? () => _executeSummon(10) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'SUMMON 10x',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 12.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '(SAVE 10%)',
                        style: TextStyle(
                          color: Color(0xFF81C784),
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currencyIcon, color: canAfford10x ? currencyColor : Colors.white30, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${banner.multiCost} ${banner.currencyName}',
                        style: TextStyle(
                          color: canAfford10x ? currencyColor : Colors.white30,
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _executeSummon(int count) {
    try {
      setState(() {
        _isPerformingRitual = true;
      });

      final result = SummoningService.performSummon(
        bannerType: _selectedBannerType,
        count: count,
        currentIchor: widget.totalIchor,
        currentSigils: widget.bloodlineSigils,
      );

      // Invoke parent callback to deduct currencies & update reserve inventory
      widget.onSummonExecuted(result);

      setState(() {
        _isPerformingRitual = false;
        _revealedUnits = result.summonedUnits;
        _revealedIndex = 0;
      });
    } catch (e) {
      setState(() {
        _isPerformingRitual = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  Widget _buildRitualLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
            ),
            SizedBox(height: 16),
            Text(
              'CHANNELING BLOODLINE ESSENCE...',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsRevealModal(BuildContext context) {
    final units = _revealedUnits!;
    final currentUnit = units[_revealedIndex];
    final isMulti = units.length > 1;

    Color rarityColor;
    String rarityBadge;
    if (currentUnit.generation >= 3) {
      rarityColor = const Color(0xFFFFD54F);
      rarityBadge = 'GEN 3 PUREBLOOD';
    } else if (currentUnit.generation == 2) {
      rarityColor = const Color(0xFFFFB74D);
      rarityBadge = 'GEN 2 ELITE';
    } else {
      rarityColor = const Color(0xFFB0BEC5);
      rarityBadge = 'GEN 1 THRALL';
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Counter for Multi-Summon
                if (isMulti)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'CONVOCATION RESULT ${_revealedIndex + 1} OF ${units.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
                    ),
                  ),

                // Gothic Card Display
                Container(
                  width: 290,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        rarityColor.withValues(alpha: 0.25),
                        const Color(0xFF161622),
                        const Color(0xFF0F0F16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: rarityColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rarity Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: rarityColor, width: 1.0),
                        ),
                        child: Text(
                          rarityBadge,
                          style: TextStyle(
                            color: rarityColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Avatar Frame
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF20202C),
                          border: Border.all(color: rarityColor, width: 2.0),
                        ),
                        child: Center(
                          child: Icon(
                            _getArchetypeIcon(currentUnit.archetype),
                            color: rarityColor,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Unit Name & Archetype
                      Text(
                        currentUnit.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentUnit.archetype.name.toUpperCase()} • ${currentUnit.plinthMaterial.name.toUpperCase()} PLINTH',
                        style: TextStyle(
                          color: rarityColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 20),

                      // Unit Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('HP', '${currentUnit.maxHp}'),
                          _buildStatItem('ATK', '${currentUnit.attack}'),
                          _buildStatItem('DEF', '${currentUnit.defense}'),
                          _buildStatItem('SPD', '${currentUnit.speed}'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Native Trait Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'TRAIT: ${currentUnit.nativeTraitId.replaceAll('_', ' ').toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Navigation Controls (Next Card or Collect All)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isMulti && _revealedIndex < units.length - 1)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E2C),
                          foregroundColor: const Color(0xFFFFD54F),
                          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text(
                          'NEXT CONVOCATION',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        onPressed: () {
                          setState(() {
                            _revealedIndex++;
                          });
                        },
                      ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3261E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _revealedUnits = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Claimed ${units.length} summoned thrall(s) to Reserve Inventory!'),
                            backgroundColor: const Color(0xFF388E3C),
                          ),
                        );
                      },
                      child: Text(
                        isMulti && _revealedIndex < units.length - 1 ? 'CLAIM ALL' : 'CLAIM THRALL',
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getArchetypeIcon(Archetype archetype) {
    switch (archetype) {
      case Archetype.juggernaut:
        return Icons.shield;
      case Archetype.assassin:
        return Icons.flash_on;
      case Archetype.marksman:
        return Icons.gps_fixed;
      case Archetype.skirmisher:
        return Icons.directions_run;
      case Archetype.support:
        return Icons.favorite;
      case Archetype.occultist:
        return Icons.auto_awesome;
    }
  }

  void _showRatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
        ),
        title: Row(
          children: const [
            Icon(Icons.pie_chart, color: Color(0xFFFFD54F), size: 20),
            SizedBox(width: 8),
            Text(
              'CONVOCATION PROBABILITIES',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summoning utilizes true weighted odds without deceptive pity hidden caps. Every thrall summoned is fully functional in battle and eligible for Crucible fusion and trait grafting.',
              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
            const Divider(color: Colors.white12, height: 20),
            _buildDialogRateRow('Ashen Bloodline Rite', 'Gen 1: 82%  •  Gen 2: 15%  •  Gen 3: 3%'),
            const SizedBox(height: 10),
            _buildDialogRateRow('Consecrated Covenant', 'Gen 1: 40%  •  Gen 2: 45%  •  Gen 3: 15%'),
            const SizedBox(height: 10),
            _buildDialogRateRow('Crypt Stalker Focus', 'Gen 1: 75%  •  Gen 2: 20%  •  Gen 3: 5%'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('DISMISS', style: TextStyle(color: Color(0xFFFFD54F))),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRateRow(String title, String rates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontWeight: FontWeight.bold,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          rates,
          style: const TextStyle(
            color: Colors.white60,
            fontFamily: 'monospace',
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
