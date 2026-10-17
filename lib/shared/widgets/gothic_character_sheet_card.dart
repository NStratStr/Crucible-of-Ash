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

  const GothicCharacterSheetCard({
    super.key,
    required this.unit,
    this.relicService,
    this.totalIchor = 0,
    this.onLevelUp,
    this.onClose,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final bool canShowDrawerSideBySide = screenWidth >= 880 && _selectedDetail != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: _buildCardBack(),
                        )
                      : _buildCardFront(),
                );
              },
            ),

            // Pop-out Inspection Drawer (Right Side on Wide Screens)
            if (canShowDrawerSideBySide) ...[
              const SizedBox(width: 16),
              _buildPopOutDetailDrawer(isSidePanel: true),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FRONT OF CARD: VITALS, DIORAMA, PROGRESS, STATS
  // ==========================================
  Widget _buildCardFront() {
    final factionColor = _getFactionColor();
    final unit = _currentUnit;
    const double cardWidth = 380;
    const double cardHeight = 620;

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

            // 2. Top Header Seal & Name Plate
            Positioned(
              top: 14,
              left: 18,
              right: 18,
              height: 58,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Faction Coin Seal
                  Container(
                    width: 38,
                    height: 38,
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
                    padding: const EdgeInsets.all(5),
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
                            fontSize: 13.5,
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
                          'GEN ${unit.generation} • ${unit.archetype.name.toUpperCase()} • ${unit.factionName.toUpperCase()}',
                          style: TextStyle(
                            color: factionColor,
                            fontSize: 8.5,
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
                        child: const Icon(Icons.close, color: Colors.white70, size: 15),
                      ),
                    )
                  else
                    const SizedBox(width: 24),
                ],
              ),
            ),

            // 3. Mini-Diorama Arch Chamber (Unit Figure on Pedestal)
            Positioned(
              top: 76,
              left: 100,
              right: 100,
              height: 168,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Unit Cutout Figure
                  Positioned(
                    bottom: 8,
                    child: SizedBox(
                      width: 140,
                      height: 155,
                      child: Image.asset(
                        unit.effectiveAvatarAsset,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white38, size: 64),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Middle Tier: Level Progression & Bloodline Infusion Bar
            Positioned(
              top: 254,
              left: 48,
              right: 48,
              height: 48,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
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
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Quick Infusion Pill Button
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
                                    fontSize: 8.0,
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
            Positioned(
              top: 310,
              left: 90,
              right: 90,
              height: 140,
              child: Center(
                child: HexagonalAffinityWheelWidget(
                  activeArchetype: unit.archetype,
                  size: 132,
                ),
              ),
            ),

            // 6. Bottom Tier: Core Combat Attributes (Left) & Tactical Formation Trait (Right)
            Positioned(
              bottom: 30,
              left: 36,
              right: 36,
              height: 120,
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
                              Icon(unit.isVanguard ? Icons.shield : Icons.auto_awesome, color: factionColor, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  unit.isVanguard ? 'DEFENSE AEGIS' : 'ARCANUM FOCUS',
                                  style: TextStyle(
                                    color: factionColor,
                                    fontSize: 8.5,
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
                              style: const TextStyle(
                                color: Color(0xFFC5C5D2),
                                fontSize: 8.0,
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
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleFlip,
                child: Container(
                  width: 32,
                  height: 32,
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
                  child: Icon(Icons.flip_camera_android, color: factionColor, size: 16),
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
  Widget _buildCardBack() {
    final factionColor = _getFactionColor();
    final unit = _currentUnit;
    const double cardWidth = 380;
    const double cardHeight = 620;

    final skills = unit.resolvedSkills;
    final primarySkill = skills.isNotEmpty ? skills.first : null;
    final secondarySkill = skills.length > 1 ? skills[1] : null;
    final ultimateSkill = skills.where((s) => s.isLimitBurst).firstOrNull ?? (skills.length > 2 ? skills[2] : null);

    final equippedRelics = widget.relicService?.getRelicsForUnit(unit.id) ?? const <RelicEntity>[];
    final weaponRelic = equippedRelics.where((r) => r.slot == RelicSlot.weapon).firstOrNull;
    final armorRelic = equippedRelics.where((r) => r.slot == RelicSlot.armor).firstOrNull;
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

            // 2. Top Banner: Unit Arsenal
            Positioned(
              top: 18,
              left: 20,
              right: 20,
              height: 48,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                      border: Border.all(color: factionColor, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(4),
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
                        fontSize: 12.5,
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
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Top Tier: Active Skills (Row 1 & Row 2)
            Positioned(
              top: 76,
              left: 32,
              right: 32,
              height: 140,
              child: Column(
                children: [
                  if (primarySkill != null)
                    _buildSkillBar(primarySkill, Icons.gavel, const Color(0xFFFFB300)),
                  const SizedBox(height: 6),
                  if (secondarySkill != null)
                    _buildSkillBar(secondarySkill, Icons.colorize, const Color(0xFFFF5252)),
                  const SizedBox(height: 6),
                  if (ultimateSkill != null)
                    _buildSkillBar(ultimateSkill, Icons.bolt, const Color(0xFFFFD54F), isUltimate: true),
                ],
              ),
            ),

            // 4. Middle Tier: Formation Stance / Passive Inscription Banner
            Positioned(
              top: 228,
              left: 32,
              right: 32,
              height: 52,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: factionColor.withValues(alpha: 0.2),
                          border: Border.all(color: factionColor, width: 0.8),
                        ),
                        child: Icon(unit.isVanguard ? Icons.shield : Icons.auto_awesome, color: factionColor, size: 14),
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
                                fontSize: 9.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              unit.isVanguard
                                  ? 'Converts stagger into shield barriers. Solar burns attackers.'
                                  : 'Sheltered spell focus; column pierce and high critical damage.',
                              style: const TextStyle(color: Colors.white70, fontSize: 7.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.info_outline, color: Colors.white38, size: 13),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom Tier: 6-Socket Equipment Matrix (Weapon, Shield, Armor, Plinth, Talisman, Crest)
            Positioned(
              bottom: 24,
              left: 28,
              right: 28,
              height: 280,
              child: Column(
                children: [
                  // Row 1 (Sockets 1, 2, 3)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: weaponRelic?.name ?? 'Main Hand',
                            subtitle: 'WEAPON',
                            icon: Icons.colorize,
                            accentColor: weaponRelic?.rarityColor ?? const Color(0xFFFFB300),
                            relic: weaponRelic,
                            defaultLore: 'Forged iron blade with jagged edges tailored to sever sinew.',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: 'Shield / Ward',
                            subtitle: 'OFF-HAND',
                            icon: Icons.shield,
                            accentColor: const Color(0xFF42A5F5),
                            defaultLore: 'Reinforced heavy kite shield bearing heraldic sigils of warding.',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: armorRelic?.name ?? 'Heavy Plate',
                            subtitle: 'ARMOR',
                            icon: Icons.security,
                            accentColor: armorRelic?.rarityColor ?? const Color(0xFF81C784),
                            relic: armorRelic,
                            defaultLore: 'Segmented iron plate armor forged to deflect crushing impacts.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Row 2 (Sockets 4, 5, 6)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: unit.plinthMaterialTitle.split(' ').first,
                            subtitle: 'PLINTH',
                            icon: Icons.view_in_ar,
                            accentColor: const Color(0xFFB0BEC5),
                            defaultLore: 'Imbued cold iron pedestal conferring permanent armor and poise stability.',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: talismanRelic?.name ?? 'Talisman',
                            subtitle: 'AMULET',
                            icon: Icons.circle,
                            accentColor: talismanRelic?.rarityColor ?? const Color(0xFFFFD54F),
                            relic: talismanRelic,
                            defaultLore: 'Sun-warmed amber talisman channeling restorative radiant focus.',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildEquipmentSocket(
                            title: sigilRelic?.name ?? 'Blood Crest',
                            subtitle: 'SIGIL',
                            icon: Icons.dangerous,
                            accentColor: sigilRelic?.rarityColor ?? const Color(0xFFE53935),
                            relic: sigilRelic,
                            defaultLore: 'Skull-embossed cindershell warding the unit against lethal execution.',
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
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleFlip,
                child: Container(
                  width: 32,
                  height: 32,
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
                  child: Icon(Icons.flip_camera_android, color: factionColor, size: 16),
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
  Widget _buildSkillBar(SkillEntity skill, IconData defaultIcon, Color defaultColor, {bool isUltimate = false}) {
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 0.7),
              ),
              child: Icon(defaultIcon, color: color, size: 14),
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
                      fontSize: 9.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    skill.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 7.5),
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
                  fontSize: 7.5,
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
        padding: const EdgeInsets.all(5),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(color: accentColor, width: 0.8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(height: 3),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 7.5,
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
                fontSize: 6.5,
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
  // POP-OUT DETAIL DRAWER (RIGHT PANEL)
  // ==========================================
  Widget _buildPopOutDetailDrawer({required bool isSidePanel}) {
    final detail = _selectedDetail;
    if (detail == null) return const SizedBox.shrink();

    return Container(
      width: isSidePanel ? 320 : double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: detail.themeColor.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: detail.themeColor.withValues(alpha: 0.25),
            blurRadius: 16,
          ),
          const BoxShadow(color: Colors.black87, blurRadius: 10),
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
                      style: TextStyle(
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
              fontSize: 10,
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
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
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
