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
    final double cardW = width ?? 140.0;
    final double cardH = height ?? 200.0;

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        color: const Color(0xFF13131B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF616175), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: (canAfford ? const Color(0xFFFFD54F) : const Color(0xFFB3261E)).withValues(alpha: 0.55),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // Frame Asset Overlay (if available) or procedural iron plate
            Positioned.fill(
              child: Image.asset(
                'assets/images/Spells/SunBurst Spell frame image.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF20202C), Color(0xFF0F0F16)],
                    ),
                  ),
                ),
              ),
            ),

            // Inner Card Layout
            Padding(
              padding: const EdgeInsets.all(7.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Banner Iron Plaque: Name & Socket
                  Row(
                    children: [
                      // Glowing Amber Focus Socket
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFE65100)],
                          ),
                          border: Border.all(color: Colors.white70, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFFFD54F), blurRadius: 8),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$effectiveCost',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Iron Banner Plaque with Gothic Typography
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181822).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
                          ),
                          child: Text(
                            order.name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Centered Ability Illustration
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Center(
                        child: order.name.toLowerCase().contains('sun') ||
                                order.name.toLowerCase().contains('iron') ||
                                order.name.toLowerCase().contains('stand')
                            ? Image.asset(
                                'assets/images/Spells/Sunburst - Tier 1 Spell no text.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  order.icon ?? Icons.flash_on,
                                  size: 42,
                                  color: const Color(0xFFFFD54F),
                                ),
                              )
                            : Image.asset(
                                'assets/images/Spells/Vitae Erution - Tier 1 no txt.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  order.icon ?? Icons.bloodtype,
                                  size: 42,
                                  color: const Color(0xFFFF1744),
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Bottom Text Window: Recessed Dark Stone Plaque
                  Container(
                    padding: const EdgeInsets.all(5.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E14).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF3D3D52), width: 1.0),
                    ),
                    child: Text(
                      order.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.0,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
