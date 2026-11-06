import 'package:flutter/material.dart';

/// Uniform Gothic Header AppBar for all screens in Crucible of Ash.
/// Provides:
/// - Consistent dark obsidian background (#12121A) with subtle bottom border (#282836).
/// - Styled embossed title with category tag (e.g. [CITADEL], [ARMORY], [RITUAL], [BATTLE]).
/// - Optional leading widget (e.g. Back button or Chapter navigator).
/// - Optional Tri-Currency cluster (Ichor, Cursed Ore, Bloodline Sigils).
/// - Optional custom right-side actions.
class GothicHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? categoryTag;
  final Widget? leading;
  final int? totalIchor;
  final int? cursedOre;
  final int? bloodlineSigils;
  final List<Widget>? actions;
  final double height;
  final bool centerTitle;

  const GothicHeaderBar({
    super.key,
    required this.title,
    this.categoryTag,
    this.leading,
    this.totalIchor,
    this.cursedOre,
    this.bloodlineSigils,
    this.actions,
    this.height = 48.0,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF282836), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: NavigationToolbar(
        leading: leading,
        middle: _buildTitle(context),
        trailing: _buildTrailing(context),
        centerMiddle: centerTitle,
        middleSpacing: 8.0,
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (categoryTag != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFB3261E).withAlpha(45),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFB3261E).withAlpha(150), width: 1.0),
            ),
            child: Text(
              categoryTag!.toUpperCase(),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF8A80),
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
        Flexible(
          child: Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: 1.4,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (totalIchor != null || cursedOre != null || bloodlineSigils != null)
          _buildCurrencyCluster(),
        ...?actions,
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCurrencyCluster() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF181822),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E2E40), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalIchor != null) ...[
            const Icon(Icons.water_drop, color: Color(0xFFEF5350), size: 12),
            const SizedBox(width: 3),
            Text(
              '$totalIchor',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 10.0,
              ),
            ),
          ],
          if (cursedOre != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.diamond_outlined, color: Color(0xFF80CBC4), size: 12),
            const SizedBox(width: 3),
            Text(
              '$cursedOre',
              style: const TextStyle(
                color: Color(0xFF80CBC4),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 10.0,
              ),
            ),
          ],
          if (bloodlineSigils != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 12),
            const SizedBox(width: 3),
            Text(
              '$bloodlineSigils',
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 10.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
