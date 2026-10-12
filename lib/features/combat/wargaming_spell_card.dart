import 'package:flutter/material.dart';
import '../generals/general_command_service.dart';

/// GDD v2.8 / Collectible Wargaming Card System
/// Heavy, mechanical dark-iron borders, visible rivets, fine cross-hatching,
/// and cel-shaded lighting matching physical wargaming components.
///
/// Features:
/// - Circular metallic socket in top-left with glowing amber Focus Cost
/// - Weathered gothic lettering in an iron banner plaque
/// - Centered dynamic ability/spell artwork
/// - Recessed dark stone plaque with hand-drawn rules text
class WargamingSpellCard extends StatelessWidget {
  final GeneralOrderDefinition order;
  final int effectiveCost;
  final bool canAfford;
  final bool isUnlocked;
  final Color themeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;
  final bool isCompact;
  final double? width;
  final double? height;

  const WargamingSpellCard({
    super.key,
    required this.order,
    required this.effectiveCost,
    required this.canAfford,
    required this.isUnlocked,
    required this.themeColor,
    this.onTap,
    this.onLockedTap,
    this.isCompact = true,
    this.width,
    this.height,
  });

  static String resolveSpellAsset(GeneralOrderDefinition order) {
    final nameLower = order.name.toLowerCase();
    final idLower = order.id.toLowerCase();
    if (nameLower.contains('siphon') || idLower.contains('siphon')) {
      return 'assets/images/Spells/Sanguine Siphon.jpg';
    }
    if (nameLower.contains('reviv') || idLower.contains('reviv')) {
      return 'assets/images/Spells/Sanguine Revival.jpg';
    }
    if (nameLower.contains('armour') || nameLower.contains('armor') || nameLower.contains('ward') || nameLower.contains('bulwark')) {
      return 'assets/images/Spells/Ash Armour.jpg';
    }
    if (nameLower.contains('sun') || nameLower.contains('flame') || nameLower.contains('solar') || nameLower.contains('stand')) {
      return 'assets/images/Spells/SunBurst Spell frame image.png';
    }
    // Rend Flesh, Soul Shatter, Cleave, Execute, and physical/dark orders
    if (nameLower.contains('rend') || nameLower.contains('shatter') || nameLower.contains('cleave') || nameLower.contains('exsanguin') || nameLower.contains('feast') || nameLower.contains('execute')) {
      return 'assets/images/Spells/Soul Shatter.jpg';
    }
    return 'assets/images/Spells/Soul Shatter.jpg';
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactSlipCard();
    }
    return _buildCollectibleTrayCard();
  }

  /// Compact Tuning Slip Card for the bottom carousel dock
  Widget _buildCompactSlipCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isUnlocked ? (canAfford ? onTap : null) : onLockedTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: height ?? 68,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: !isUnlocked
                  ? const [Color(0xFF14141A), Color(0xFF0E0E14)]
                  : (canAfford
                      ? const [Color(0xFF2A2634), Color(0xFF15141D)]
                      : const [Color(0xFF1C1A22), Color(0xFF100F15)]),
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: !isUnlocked
                  ? const Color(0xFF383844)
                  : (canAfford ? themeColor : const Color(0xFF424254)),
              width: (!isUnlocked || !canAfford) ? 1.0 : 1.6,
            ),
            boxShadow: (isUnlocked && canAfford)
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Corner Rivets (Physical Wargaming Aesthetic)
              const Positioned(top: 1, left: 1, child: _RivetDot()),
              const Positioned(top: 1, right: 1, child: _RivetDot()),
              const Positioned(bottom: 1, left: 1, child: _RivetDot()),
              const Positioned(bottom: 1, right: 1, child: _RivetDot()),

              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row: Circular Metallic Socket (Cost) + Order Name
                  Row(
                    children: [
                      // Circular Metallic Socket with glowing amber Focus Cost
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: !isUnlocked
                                ? const [Color(0xFF2A2A38), Color(0xFF121218)]
                                : (canAfford
                                    ? const [Color(0xFFFFD54F), Color(0xFFB26A00)]
                                    : const [Color(0xFF37474F), Color(0xFF1A2327)]),
                          ),
                          border: Border.all(
                            color: !isUnlocked
                                ? const Color(0xFF455A64)
                                : (canAfford ? const Color(0xFFFFE082) : const Color(0xFF546E7A)),
                            width: 1.2,
                          ),
                          boxShadow: (isUnlocked && canAfford)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            !isUnlocked ? 'RANK ${order.requiredPhylacteryRank}' : '$effectiveCost',
                            style: TextStyle(
                              color: !isUnlocked
                                  ? const Color(0xFFE5A93C)
                                  : (canAfford ? Colors.black : Colors.white60),
                              fontSize: !isUnlocked ? 6.5 : 9.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Order Name Plaque
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F14).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFF373748), width: 0.7),
                          ),
                          child: Text(
                            order.name.toUpperCase(),
                            style: TextStyle(
                              color: !isUnlocked
                                  ? Colors.white38
                                  : (canAfford ? Colors.white : Colors.white70),
                              fontSize: 8.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Order / Magic Icon
                      Icon(
                        !isUnlocked ? Icons.lock : (order.icon ?? Icons.auto_awesome),
                        size: 13,
                        color: !isUnlocked
                            ? Colors.white30
                            : (canAfford ? themeColor : Colors.white38),
                      ),
                    ],
                  ),

                  // Description Plaque: Recessed dark stone
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF262634), width: 0.6),
                    ),
                    child: Text(
                      order.description,
                      style: TextStyle(
                        color: !isUnlocked ? Colors.white24 : Colors.white70,
                        fontSize: 7.2,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  /// Full Physical Wargaming Collectible Tray Card (Used for Drag Feedback & High-Res Inspection)
  Widget _buildCollectibleTrayCard() {
    final double cardW = width ?? 110.0;
    final double cardH = height ?? 160.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isUnlocked ? (canAfford ? onTap : null) : onLockedTap,
      child: Container(
        width: cardW,
        height: cardH,
        decoration: BoxDecoration(
          color: const Color(0xFF101016),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (canAfford ? const Color(0xFFD4AF37) : const Color(0xFF383644)).withValues(alpha: canAfford ? 0.75 : 0.5),
            width: canAfford ? 1.2 : 0.8,
          ),
          boxShadow: [
            if (canAfford)
              BoxShadow(
                color: themeColor.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              // 1. Base dark obsidian fill
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F0F14),
                ),
              ),

              // 2. Wargaming Dark-Iron Riveted Frame Tablet (Transparent PNG without white margin)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Spells/wargaming_card_frame.png',
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/Spells/Spell frame template.jpg',
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // 3. Magic Spell Artwork placed directly over the center window
              Positioned(
                left: cardW * 0.190,
                top: cardH * 0.218,
                width: cardW * 0.620,
                height: cardH * 0.328,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFF1E1E28), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.asset(
                      resolveSpellAsset(order),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E1E28),
                        child: Center(
                          child: Icon(
                            order.icon ?? Icons.auto_awesome,
                            size: cardW * 0.25,
                            color: themeColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Circular Metallic Focus Socket (top-left)
              Positioned(
                top: cardH * 0.035,
                left: cardW * 0.052,
                child: Container(
                  width: cardW * 0.17,
                  height: cardW * 0.17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: !isUnlocked
                          ? const [Color(0xFF2A2A38), Color(0xFF121218)]
                          : (canAfford
                              ? const [Color(0xFFFFD54F), Color(0xFFE65100)]
                              : const [Color(0xFF37474F), Color(0xFF1A2327)]),
                    ),
                    border: Border.all(
                      color: !isUnlocked
                          ? const Color(0xFF455A64)
                          : (canAfford ? const Color(0xFFFFE082) : const Color(0xFF546E7A)),
                      width: 1.0,
                    ),
                    boxShadow: (isUnlocked && canAfford)
                        ? const [
                            BoxShadow(color: Color(0xFFFFD54F), blurRadius: 5),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      !isUnlocked ? 'RANK ${order.requiredPhylacteryRank}' : '$effectiveCost',
                      style: TextStyle(
                        color: !isUnlocked
                            ? const Color(0xFFE5A93C)
                            : (canAfford ? Colors.black : Colors.white70),
                        fontSize: !isUnlocked ? (cardW * 0.055) : (cardW * 0.095),
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Header Plaque: Spell Name
              Positioned(
                top: cardH * 0.052,
                left: cardW * 0.23,
                right: cardW * 0.18,
                height: cardH * 0.075,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      order.name.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFFFE082),
                        fontSize: cardW * 0.085,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
                        ],
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // 6. Recessed Stone Plaque: Rules Description
              Positioned(
                left: cardW * 0.11,
                right: cardW * 0.11,
                top: cardH * 0.585,
                bottom: cardH * 0.080,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      order.description,
                      style: TextStyle(
                        color: const Color(0xFFF0F0F5),
                        fontSize: (cardW * 0.080).clamp(7.0, 11.5),
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 2.5, offset: Offset(0.5, 0.5)),
                        ],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RivetDot extends StatelessWidget {
  const _RivetDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF8E8EA0),
        border: Border.all(color: Colors.black, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.white24, blurRadius: 1),
        ],
      ),
    );
  }
}
