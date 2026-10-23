import 'dart:math';
import 'package:flutter/material.dart';
import '../../features/relics/relic_service.dart';
import '../models/relic_entity.dart';
import '../models/skill_entity.dart';
import '../models/unit_entity.dart';
import 'hexagonal_affinity_wheel_widget.dart';

/// Detailed inspection target selected on the back of the card
enum SelectedDetailType {
  none,
  skill,
  equipment,
  stance,
}

class DetailedInspectionItem {
  final SelectedDetailType type;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color themeColor;
  final String? badgeText;
  final Map<String, String>? stats;
  final RelicEntity? relic;
  final SkillEntity? skill;

  const DetailedInspectionItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.themeColor,
    this.badgeText,
    this.stats,
    this.relic,
    this.skill,
  });
}

/// The unified diegetic Gothic Character / Faction Sheet Card
/// Directly maps onto the architectural slots of the physical card frame:
/// - Front: Plinth Miniature, Name Banner, Level/XP Infusion, Hexagonal Affinity Wheel, Combat Attributes
/// - Back: Active Skills, Formation Stance / Passive, 6-Slot Relic/Equipment Matrix
/// - Pop-out: Contextual right-side inspector drawer for deep skill & equipment customization
class GothicCharacterSheetCard extends StatefulWidget {
  final UnitEntity unit;
  final RelicService? relicService;
  final int totalIchor;
  final void Function(UnitEntity updatedUnit, int ichorCost)? onLevelUp;
  final VoidCallback? onClose;
  final VoidCallback? onToggleClassicCodex;

  const GothicCharacterSheetCard({
    super.key,
    required this.unit,
    this.relicService,
    this.totalIchor = 0,
    this.onLevelUp,
    this.onClose,
    this.onToggleClassicCodex,
  });

  @override
  State<GothicCharacterSheetCard> createState() => _GothicCharacterSheetCardState();
}

class _GothicCharacterSheetCardState extends State<GothicCharacterSheetCard> with SingleTickerProviderStateMixin {
  late UnitEntity _currentUnit;
  late int _currentIchor;
  bool _isViewingBack = false;
  DetailedInspectionItem? _selectedDetail;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _currentUnit = widget.unit;
    _currentIchor = widget.totalIchor;

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _selectedDetail = null;
      if (_isViewingBack) {
        _flipController.reverse();
        _isViewingBack = false;
      } else {
        _flipController.forward();
        _isViewingBack = true;
      }
    });
  }

  void _handleLevelUp(int levels) {
    final cost = _currentUnit.xpNeededForNextLevel;
    if (_currentIchor < cost) return;
    final updated = _currentUnit.levelUp(levels: levels);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= cost;
    });
    widget.onLevelUp?.call(updated, cost);
  }

  void _handleInfuseXp(int xp) {
    if (_currentIchor < xp) return;
    final updated = _currentUnit.addXp(xp);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= xp;
    });
    widget.onLevelUp?.call(updated, xp);
  }

  void _handlePromoteRarity() {
    if (!_currentUnit.canPromoteRarity) return;
    final cost = 200 * (_currentUnit.rarity.index + 1);
    if (_currentIchor < cost) return;
    final updated = _currentUnit.promoteRarity();
    setState(() {
      _currentUnit = updated;
      _currentIchor -= cost;
    });
    widget.onLevelUp?.call(updated, cost);
  }

  String _getFactionKey() {
    final faction = _currentUnit.factionName.toLowerCase();
    if (faction.contains('crypt') || faction.contains('stalker')) return 'crypt_stalkers';
    if (faction.contains('mire') || faction.contains('coven')) return 'mire_coven';
    if (faction.contains('calx') || faction.contains('void') || faction.contains('cult')) return 'calx_order';
    return 'ash_legion';
  }

  Color _getFactionColor() {
    switch (_getFactionKey()) {
      case 'crypt_stalkers':
        return const Color(0xFFE53935);
      case 'mire_coven':
        return const Color(0xFF43A047);
      case 'calx_order':
        return const Color(0xFF00E5FF);
      case 'ash_legion':
      default:
        return const Color(0xFFFFB300);
    }
  }

  String _getFactionSealAsset() {
    switch (_getFactionKey()) {
      case 'crypt_stalkers':
        return 'assets/images/UI/Skull Shield Icon Transparent.png';
      case 'mire_coven':
        return 'assets/images/UI/Ruby Shield Icon transparent.png';
      case 'calx_order':
        return 'assets/images/UI/Relic Forge Shield Icon Transparent.png';
      case 'ash_legion':
      default:
        return 'assets/images/UI/Flame Shield icon Transparent.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Card dimensions proportional to art asset 1792 x 2400 (aspect ratio ~1 : 1.34)
    // Max width 420, max height 88% of screen height
    final double cardWidth = min(screenWidth * 0.94, min(420.0, (screenHeight * 0.86) / 1.34));
    final double cardHeight = cardWidth * 1.34;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Physical Gothic Faction Card with 3D Flip
          AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * pi;
              final isUnder = angle > (pi / 2);
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isUnder
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _buildCardBack(cardWidth, cardHeight),
                      )
                    : _buildCardFront(cardWidth, cardHeight),
              );
            },
          ),

          // Contextual Pop-out Inspection Drawer (Overlay with backdrop dismiss, never overflows)
          if (_selectedDetail != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDetail = null),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: GestureDetector(
                    onTap: () {}, // Catch taps on the drawer itself
                    child: _buildPopOutDetailDrawer(maxWidth: min(cardWidth - 24, 380)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // FRONT OF CARD: VITALS, DIORAMA, PROGRESS, STATS
  // ==========================================
  Widget _buildCardFront(double cardWidth, double cardHeight) {
    final factionColor = _getFactionColor();
    final unit = _currentUnit;

    final double xpProgress = unit.isMaxLevel ? 1.0 : (unit.currentXp / max(1, unit.xpToNextLevel)).clamp(0.0, 1.0);
    final canAffordNext = _currentIchor >= unit.xpNeededForNextLevel && !unit.isMaxLevel;
    final canAfford100 = _currentIchor >= 100 && !unit.isMaxLevel;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: factionColor.withValues(alpha: 0.30),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 1. High-fidelity Iron/Slag Gothic Border Frame
            Positioned.fill(
              child: Image.asset(
                'assets/images/UI/character_sheet_front_${_getFactionKey()}.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF14141E),
                ),
              ),
            ),

            // 2. Top Header Seal & Name Plate (Nested directly inside top engraved plaque)
            Positioned(
              top: cardHeight * 0.065,
              left: cardWidth * 0.05,
              right: cardWidth * 0.05,
              height: cardHeight * 0.082,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Faction Coin Seal
                  Container(
                    width: cardWidth * 0.10,
                    height: cardWidth * 0.10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.65),
                      border: Border.all(color: factionColor, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: factionColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      _getFactionSealAsset(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(Icons.shield, color: factionColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name & Epithet Banner
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          unit.name.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'serif',
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: cardWidth * 0.038,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'GEN ${unit.generation} • ${unit.rarity.displayName.toUpperCase()} • ${unit.archetype.name.toUpperCase()}',
                          style: TextStyle(
                            color: factionColor,
                            fontSize: cardWidth * 0.024,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Close Button
                  if (widget.onClose != null)
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Icon(Icons.close, color: Colors.white70, size: cardWidth * 0.04),
                      ),
                    )
                  else
                    SizedBox(width: cardWidth * 0.06),
                ],
              ),
            ),

            // 3. Mini-Diorama Arch Chamber (Unit Figure on Pedestal)
            // Perfectly contained inside the stone arch chamber (y: 15.5% to 44.5%)
            Positioned(
              top: cardHeight * 0.155,
              left: cardWidth * 0.22,
              right: cardWidth * 0.22,
              height: cardHeight * 0.29,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: cardWidth * 0.46,
                  height: cardHeight * 0.28,
                  child: Image.asset(
                    unit.effectiveAvatarAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white38, size: 64),
                  ),
                ),
              ),
            ),

            // 4. Middle Tier: Level Progression & Bloodline Infusion Bar
            // Sits directly across the stone tier bar (y: 45.5% to 51.5%)
            Positioned(
              top: cardHeight * 0.455,
              left: cardWidth * 0.08,
              right: cardWidth * 0.08,
              height: cardHeight * 0.060,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LV. ${unit.level}/${unit.maxLevel}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: cardWidth * 0.028,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: factionColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: factionColor, width: 0.6),
                            ),
                            child: Text(
                              unit.isVanguard ? 'VANGUARD' : 'ARCANUM',
                              style: TextStyle(
                                color: factionColor,
                                fontSize: cardWidth * 0.020,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Quick Infusion or Rarity Promotion Pill Button
                      if (!unit.isMaxLevel)
                        GestureDetector(
                          onTap: canAffordNext ? () => _handleLevelUp(1) : (canAfford100 ? () => _handleInfuseXp(100) : null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: canAffordNext
                                  ? const Color(0xFFB3261E)
                                  : (canAfford100 ? const Color(0xFF7B1FA2) : Colors.white10),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: canAffordNext ? const Color(0xFFFF5252) : Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.water_drop, color: Color(0xFFFF8A80), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  canAffordNext ? '+1 LVL (${unit.xpNeededForNextLevel})' : '+100 XP',
                                  style: TextStyle(
                                    color: canAffordNext || canAfford100 ? Colors.white : Colors.white38,
                                    fontSize: cardWidth * 0.021,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (unit.canPromoteRarity)
                        GestureDetector(
                          onTap: _currentIchor >= (200 * (unit.rarity.index + 1)) ? _handlePromoteRarity : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _currentIchor >= (200 * (unit.rarity.index + 1))
                                  ? const Color(0xFFFF8F00)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _currentIchor >= (200 * (unit.rarity.index + 1))
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  '★ PROMOTE (${200 * (unit.rarity.index + 1)})',
                                  style: TextStyle(
                                    color: _currentIchor >= (200 * (unit.rarity.index + 1)) ? Colors.white : Colors.white38,
                                    fontSize: cardWidth * 0.020,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Progress Bar
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(2.5),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: xpProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              factionColor.withValues(alpha: 0.7),
                              factionColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Center Socket: Hexagonal Affinity Wheel
            // Centered directly within the circular stone socket (y: 52.5% to 70.5%)
            Positioned(
              top: cardHeight * 0.525,
              left: cardWidth * 0.20,
              right: cardWidth * 0.20,
              height: cardHeight * 0.18,
              child: Center(
                child: HexagonalAffinityWheelWidget(
                  activeArchetype: unit.archetype,
                  size: cardHeight * 0.175,
                ),
              ),
            ),

            // 6. Bottom Tier: Core Combat Attributes (Left) & Tactical Formation Trait (Right)
            // Perfectly inset in the lower two framed boxes (y: 72.5% to 92.5%)
            Positioned(
              top: cardHeight * 0.725,
              left: cardWidth * 0.08,
              right: cardWidth * 0.08,
              height: cardHeight * 0.20,
              child: Row(
                children: [
                  // Left Stat Table (HP, ATK, ARMOR, CRIT)
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatRow('HP VITALITY', '${unit.currentHp}/${unit.effectiveMaxHp}', const Color(0xFF81C784)),
                          _buildStatRow('ATTACK', '${unit.attack}', const Color(0xFFFFB300)),
                          _buildStatRow('ARMOR (PRR)', '${unit.defense}', const Color(0xFF42A5F5)),
                          _buildStatRow('INITIATIVE', '${unit.speed}', const Color(0xFF00E5FF)),
                          _buildStatRow('CRIT RATE', '${(unit.critRate * 100).toInt()}%', const Color(0xFFFF5252)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Right Tactical Trait Plate
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: factionColor.withValues(alpha: 0.6), width: 0.9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(unit.isVanguard ? Icons.shield : Icons.auto_awesome, color: factionColor, size: cardWidth * 0.032),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  unit.isVanguard ? 'DEFENSE AEGIS' : 'ARCANUM FOCUS',
                                  style: TextStyle(
                                    color: factionColor,
                                    fontSize: cardWidth * 0.024,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: Text(
                              unit.isVanguard
                                  ? '• Frontline Vanguard absorbs assault.\n• Converts ally Stagger into barriers.\n• Draws enemy melee aggro.'
                                  : '• Sheltered from direct melee.\n• Concentrated area spells & blights.\n• High critical damage bonus.',
                              style: TextStyle(
                                color: const Color(0xFFC5C5D2),
                                fontSize: cardWidth * 0.022,
                                height: 1.25,
                              ),
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7. Coin Button (Bottom Right) to Flip to Arsenal/Equipment Back
            Positioned(
              bottom: cardHeight * 0.015,
              right: cardWidth * 0.025,
              child: GestureDetector(
                onTap: _toggleFlip,
                child: Container(
                  width: cardWidth * 0.085,
                  height: cardWidth * 0.085,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E28),
                    border: Border.all(color: factionColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: factionColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(Icons.flip_camera_android, color: factionColor, size: cardWidth * 0.045),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BACK OF CARD: SKILLS, STANCE & 6-SOCKET ARSENAL
  // ==========================================
  Widget _buildCardBack(double cardWidth, double cardHeight) {
    final factionColor = _getFactionColor();
    final unit = _currentUnit;

    final skills = unit.resolvedSkills;
    final primarySkill = skills.isNotEmpty ? skills.first : null;
    final secondarySkill = skills.length > 1 ? skills[1] : null;
    final ultimateSkill = skills.where((s) => s.isLimitBurst).firstOrNull ?? (skills.length > 2 ? skills[2] : null);

    final equippedRelics = widget.relicService?.getRelicsForUnit(unit.id) ?? const <RelicEntity>[];
    final weaponRelic = equippedRelics.where((r) => r.slot == RelicSlot.weapon).firstOrNull;
    final armorRelic = equippedRelics.where((r) => r.slot == RelicSlot.armor).firstOrNull;
    final offhandRelic = equippedRelics.where((r) => r.slot == RelicSlot.offhand).firstOrNull;
    final bootsRelic = equippedRelics.where((r) => r.slot == RelicSlot.boots).firstOrNull;
    final talismanRelic = equippedRelics.where((r) => r.slot == RelicSlot.talisman).firstOrNull;
    final sigilRelic = equippedRelics.where((r) => r.slot == RelicSlot.sigil).firstOrNull;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: factionColor.withValues(alpha: 0.30),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 1. High-fidelity Iron Backing Frame
            Positioned.fill(
              child: Image.asset(
                'assets/images/UI/character_sheet_back_${_getFactionKey()}.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF14141E),
                ),
              ),
            ),

            // 2. Top Banner: Unit Arsenal (y: 6.5% to 14.5%)
            Positioned(
              top: cardHeight * 0.065,
              left: cardWidth * 0.05,
              right: cardWidth * 0.05,
              height: cardHeight * 0.080,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: cardWidth * 0.09,
                    height: cardWidth * 0.09,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                      border: Border.all(color: factionColor, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Image.asset(
                      _getFactionSealAsset(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(Icons.shield, color: factionColor, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${unit.name.toUpperCase()} • ARSENAL',
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: cardWidth * 0.034,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'SLOT: ${unit.slot.name.toUpperCase()}',
                    style: TextStyle(
                      color: factionColor,
                      fontSize: cardWidth * 0.024,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close Button
                  if (widget.onClose != null)
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Icon(Icons.close, color: Colors.white70, size: cardWidth * 0.04),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Top Tier: Active Skills (Row 1 & Row 2) (y: 16.0% to 39.0%)
            Positioned(
              top: cardHeight * 0.160,
              left: cardWidth * 0.07,
              right: cardWidth * 0.07,
              height: cardHeight * 0.230,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (primarySkill != null)
                    Expanded(child: _buildSkillBar(primarySkill, Icons.gavel, const Color(0xFFFFB300), cardWidth: cardWidth)),
                  if (primarySkill != null && secondarySkill != null)
                    const SizedBox(height: 5),
                  if (secondarySkill != null)
                    Expanded(child: _buildSkillBar(secondarySkill, Icons.colorize, const Color(0xFFFF5252), cardWidth: cardWidth)),
                  if (secondarySkill != null && ultimateSkill != null)
                    const SizedBox(height: 5),
                  if (ultimateSkill != null)
                    Expanded(child: _buildSkillBar(ultimateSkill, Icons.bolt, const Color(0xFFFFD54F), isUltimate: true, cardWidth: cardWidth)),
                ],
              ),
            ),

            // 4. Middle Tier: Formation Stance / Passive Inscription Banner (y: 40.5% to 49.5%)
            Positioned(
              top: cardHeight * 0.405,
              left: cardWidth * 0.07,
              right: cardWidth * 0.07,
              height: cardHeight * 0.090,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDetail = DetailedInspectionItem(
                      type: SelectedDetailType.stance,
                      title: unit.isVanguard ? 'Frontline Bulwark' : 'Backline Spell-Weave',
                      subtitle: 'FORMATION PASSIVE STANCE',
                      description: unit.isVanguard
                          ? 'Absorbs initial enemy burst assaults. When adjacent allies take stagger poise damage, generates radiant shield barriers. Basic melee strikes inflict solar burn.'
                          : 'Completely protected by frontline allies. Channels deep spell focus to enhance critical multi-target burst damage and column pierce.',
                      icon: unit.isVanguard ? Icons.shield : Icons.auto_awesome,
                      themeColor: factionColor,
                      stats: {
                        'Defense': '+25% Plated Armor',
                        'Aggro': 'Primary Target',
                        'Poise Shield': '100 HP per Stagger',
                      },
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedDetail?.type == SelectedDetailType.stance ? factionColor : Colors.white24,
                      width: _selectedDetail?.type == SelectedDetailType.stance ? 1.6 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: factionColor.withValues(alpha: 0.2),
                          border: Border.all(color: factionColor, width: 0.8),
                        ),
                        child: Icon(unit.isVanguard ? Icons.shield : Icons.auto_awesome, color: factionColor, size: cardWidth * 0.035),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.isVanguard ? 'FRONTLINE BULWARK' : 'ARCANUM WEAVE',
                              style: TextStyle(
                                color: factionColor,
                                fontSize: cardWidth * 0.024,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              unit.isVanguard
                                  ? 'Converts stagger into shield barriers. Solar burns attackers.'
                                  : 'Sheltered spell focus; column pierce and high critical damage.',
                              style: TextStyle(color: Colors.white70, fontSize: cardWidth * 0.020),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.info_outline, color: Colors.white38, size: cardWidth * 0.035),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom Tier: 6-Socket Equipment Matrix (Weapon, Shield, Armor, Plinth, Talisman, Crest)
            // Perfectly inset into the 2x3 embossed squares on the back art (y: 52.0% to 92.5%)
            Positioned(
              top: cardHeight * 0.520,
              left: cardWidth * 0.065,
              right: cardWidth * 0.065,
              height: cardHeight * 0.405,
              child: Column(
                children: [
                  // Row 1 (Sockets 1, 2, 3: Weapon, Armor, Off-Hand)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: weaponRelic?.name ?? 'Main Blade',
                            subtitle: 'WEAPON',
                            icon: Icons.colorize,
                            accentColor: weaponRelic?.rarityColor ?? const Color(0xFFFFB300),
                            relic: weaponRelic,
                            defaultLore: 'Forged iron blade tailored to sever sinew and bone.',
                            cardWidth: cardWidth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: armorRelic?.name ?? 'Heavy Plate',
                            subtitle: 'ARMOR',
                            icon: Icons.shield,
                            accentColor: armorRelic?.rarityColor ?? const Color(0xFF81C784),
                            relic: armorRelic,
                            defaultLore: 'Segmented iron plate armor forged to deflect crushing impacts.',
                            cardWidth: cardWidth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: offhandRelic?.name ?? 'Kite Shield',
                            subtitle: 'OFF-HAND',
                            icon: Icons.security,
                            accentColor: offhandRelic?.rarityColor ?? const Color(0xFF42A5F5),
                            relic: offhandRelic,
                            defaultLore: 'Reinforced heavy shield bearing heraldic sigils of warding.',
                            cardWidth: cardWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Row 2 (Sockets 4, 5, 6: Boots, Talisman, Sigil)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: bootsRelic?.name ?? 'War Sabatons',
                            subtitle: 'BOOTS',
                            icon: Icons.directions_walk,
                            accentColor: bootsRelic?.rarityColor ?? const Color(0xFF26C6DA),
                            relic: bootsRelic,
                            defaultLore: 'Hardened iron greaves granting stride and tactical velocity.',
                            cardWidth: cardWidth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: talismanRelic?.name ?? 'Talisman',
                            subtitle: 'TALISMAN',
                            icon: Icons.auto_awesome,
                            accentColor: talismanRelic?.rarityColor ?? const Color(0xFFFFD54F),
                            relic: talismanRelic,
                            defaultLore: 'Sun-warmed amber talisman channeling deadly focus.',
                            cardWidth: cardWidth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: sigilRelic?.name ?? 'Blood Crest',
                            subtitle: 'SIGIL',
                            icon: Icons.token,
                            accentColor: sigilRelic?.rarityColor ?? const Color(0xFFE53935),
                            relic: sigilRelic,
                            defaultLore: 'Skull-embossed cindershell warding the unit against lethal blows.',
                            cardWidth: cardWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 6. Flip Coin Button (Bottom Right) to Flip back to Front
            Positioned(
              bottom: cardHeight * 0.015,
              right: cardWidth * 0.025,
              child: GestureDetector(
                onTap: _toggleFlip,
                child: Container(
                  width: cardWidth * 0.085,
                  height: cardWidth * 0.085,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E28),
                    border: Border.all(color: factionColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: factionColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(Icons.flip_camera_android, color: factionColor, size: cardWidth * 0.045),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SKILL COMPACT BAR IN ARSENAL
  // ==========================================
  Widget _buildSkillBar(SkillEntity skill, IconData defaultIcon, Color defaultColor, {bool isUltimate = false, required double cardWidth}) {
    final bool isSelected = _selectedDetail?.skill?.id == skill.id;
    final color = isUltimate ? const Color(0xFFFFD54F) : defaultColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDetail = DetailedInspectionItem(
            type: SelectedDetailType.skill,
            title: skill.name,
            subtitle: isUltimate ? 'ULTIMATE BURST' : (skill.cooldownTurns > 0 ? '${skill.cooldownTurns}T COOLDOWN' : 'BASIC STRIKE'),
            description: skill.description,
            icon: defaultIcon,
            themeColor: color,
            badgeText: isUltimate ? 'ULTIMATE' : (skill.cooldownTurns > 0 ? '${skill.cooldownTurns}T CD' : 'BASIC'),
            skill: skill,
            stats: {
              'Damage': '${(skill.damageCoefficient * 100).toInt()}% ATK',
              'Target': skill.targetType.name.toUpperCase(),
              if (skill.cooldownTurns > 0) 'Cooldown': '${skill.cooldownTurns} Turns',
              if (skill.appliedStatus != null) 'Affliction': skill.appliedStatus!.type.name.toUpperCase(),
            },
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 0.7),
              ),
              child: Icon(defaultIcon, color: color, size: cardWidth * 0.034),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name.toUpperCase(),
                    style: TextStyle(
                      color: isUltimate ? const Color(0xFFFFD54F) : Colors.white,
                      fontSize: cardWidth * 0.024,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    skill.description,
                    style: TextStyle(color: Colors.white70, fontSize: cardWidth * 0.019),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                isUltimate ? '⚡ ULT' : (skill.cooldownTurns > 0 ? '${skill.cooldownTurns}T' : 'BASIC'),
                style: TextStyle(
                  color: color,
                  fontSize: cardWidth * 0.019,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EQUIPMENT SOCKET SQUARE
  // ==========================================
  Widget _buildEquipmentSocket({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String defaultLore,
    RelicEntity? relic,
    required double cardWidth,
  }) {
    final bool isSelected = _selectedDetail?.title == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDetail = DetailedInspectionItem(
            type: SelectedDetailType.equipment,
            title: relic?.name ?? title,
            subtitle: relic?.slot.name.toUpperCase() ?? subtitle,
            description: relic?.description ?? defaultLore,
            icon: icon,
            themeColor: accentColor,
            relic: relic,
            badgeText: relic != null ? '+${relic.upgradeLevel} TIER' : 'STANDARD',
            stats: relic != null
                ? {
                    if (relic.bonusAttack > 0) 'Attack': '+${relic.bonusAttack}',
                    if (relic.bonusDefense > 0) 'Armor': '+${relic.bonusDefense}',
                    if (relic.bonusHp > 0) 'Health': '+${relic.bonusHp}',
                    if (relic.bonusSpeed > 0) 'Speed': '+${relic.bonusSpeed}',
                    if (relic.bonusCritRate > 0) 'Crit Rate': '+${(relic.bonusCritRate * 100).toInt()}%',
                    'Set Synergy': relic.setType.name.toUpperCase(),
                  }
                : {
                    'Quality': 'Masterwork Forged',
                    'Condition': 'Pristine Iron',
                  },
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white24,
            width: isSelected ? 1.6 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: cardWidth * 0.08,
              height: cardWidth * 0.08,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(color: accentColor, width: 0.8),
              ),
              child: Icon(icon, color: accentColor, size: cardWidth * 0.045),
            ),
            const SizedBox(height: 3),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: cardWidth * 0.020,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: accentColor,
                fontSize: cardWidth * 0.018,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // POP-OUT DETAIL DRAWER (OVERLAY / RIGHT PANEL)
  // ==========================================
  Widget _buildPopOutDetailDrawer({required double maxWidth}) {
    final detail = _selectedDetail;
    if (detail == null) return const SizedBox.shrink();

    return Container(
      width: maxWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: detail.themeColor.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: detail.themeColor.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
          const BoxShadow(color: Colors.black87, blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: detail.themeColor.withValues(alpha: 0.2),
                  border: Border.all(color: detail.themeColor, width: 1.0),
                ),
                child: Icon(detail.icon, color: detail.themeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'serif',
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      detail.subtitle,
                      style: TextStyle(
                        color: detail.themeColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedDetail = null),
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Lore / Description
          Text(
            detail.description,
            style: const TextStyle(
              color: Color(0xFFD0D0DE),
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Stats Grid (if available)
          if (detail.stats != null && detail.stats!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: detail.stats!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          entry.value,
                          style: TextStyle(color: detail.themeColor, fontSize: 9.0, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons
          if (detail.type == SelectedDetailType.equipment)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: detail.themeColor.withValues(alpha: 0.25),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: detail.themeColor, width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Forging & Refitting ${detail.title} in Relic Altar...'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('REFIT / ENHANCE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 8.0,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
