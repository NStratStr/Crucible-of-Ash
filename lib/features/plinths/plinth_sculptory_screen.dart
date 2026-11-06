import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/gothic_header_bar.dart';
import 'plinth_models.dart';
import 'plinth_service.dart';

class PlinthSculptoryScreen extends StatefulWidget {
  final PlinthService plinthService;
  final List<UnitEntity> brigadeUnits;
  final int totalIchor;
  final ValueChanged<int>? onIchorChanged;
  final VoidCallback? onClose;

  const PlinthSculptoryScreen({
    super.key,
    required this.plinthService,
    required this.brigadeUnits,
    required this.totalIchor,
    this.onIchorChanged,
    this.onClose,
  });

  @override
  State<PlinthSculptoryScreen> createState() => _PlinthSculptoryScreenState();
}

class _PlinthSculptoryScreenState extends State<PlinthSculptoryScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedPlinthId;
  int _selectedUnitIndex = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _selectedPlinthId = widget.plinthService.activeMasterPlinthId;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    widget.plinthService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.plinthService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  UnitEntity? get _showcaseUnit {
    if (widget.brigadeUnits.isEmpty) return null;
    return widget.brigadeUnits[_selectedUnitIndex % widget.brigadeUnits.length];
  }

  PlinthDefinition get _selectedPlinth {
    return PlinthDefinition.allPlinths.firstWhere(
      (p) => p.id == _selectedPlinthId,
      orElse: () => PlinthDefinition.allPlinths.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plinth = _selectedPlinth;
    final currentTier = widget.plinthService.getTier(plinth.id);
    final socketedCore = widget.plinthService.getSocketedCore(plinth.id);
    final bool isMaster = widget.plinthService.activeMasterPlinthId == plinth.id;
    final showcaseUnit = _showcaseUnit;

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background atmospheric pedestal vault
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.3),
                  radius: 1.3,
                  colors: [
                    Color(0xFF0F1B2B),
                    Color(0xFF090D14),
                    Color(0xFF05070B),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                GothicHeaderBar(
                  title: 'PLINTH SCULPTORY',
                  categoryTag: 'PEDESTAL RUNES',
                  actions: [
                    // Plinth Shards Currency Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1A24),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 1.0),
                        boxShadow: const [
                          BoxShadow(color: Color(0x3300E5FF), blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.foundation, size: 14, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.plinthService.petrifiedPlinths} SHARDS',
                            style: const TextStyle(
                              color: Color(0xFF80D8FF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ichor Currency Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF24150E),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFFF9100).withValues(alpha: 0.6), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop, size: 14, color: Color(0xFFFF5252)),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.totalIchor} ICHOR',
                            style: const TextStyle(
                              color: Color(0xFFFFAB91),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onClose != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Exit Sculptory',
                        onPressed: widget.onClose,
                      ),
                    ],
                  ],
                ),

                // Main Sculptory Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Central 3D/Tabletop Pedestal Showcase
                        _buildPedestalShowcase(
                          plinth: plinth,
                          tier: currentTier,
                          socketedCore: socketedCore,
                          showcaseUnit: showcaseUnit,
                          isMaster: isMaster,
                        ),
                        const SizedBox(height: 16),

                        // 2. Plinth Archetype Selection Carousel
                        _buildPlinthSelectorRow(),
                        const SizedBox(height: 16),

                        // 3. Plinth Tier Upgrade & Action Bar
                        _buildPlinthActionControls(plinth: plinth, currentTier: currentTier, isMaster: isMaster),
                        const SizedBox(height: 20),

                        // 4. Socketed Titan Boss Cores Workshop Tray
                        _buildTitanCoresWorkshop(plinth: plinth, socketedCore: socketedCore),
                        const SizedBox(height: 20),

                        // 5. Active Combat Bonuses Summary Card
                        _buildActiveBonusesCard(plinth: plinth, currentTier: currentTier, socketedCore: socketedCore),
                        const SizedBox(height: 16),
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

  /// Central 3D/Tabletop Pedestal Showcase
  Widget _buildPedestalShowcase({
    required PlinthDefinition plinth,
    required int tier,
    required TitanBossCore? socketedCore,
    required UnitEntity? showcaseUnit,
    required bool isMaster,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulse = _pulseController.value;
        final glowColor = plinth.primaryColor.withValues(alpha: 0.25 + 0.25 * pulse);

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                plinth.primaryColor.withValues(alpha: 0.12),
                const Color(0xFF10141E),
                const Color(0xFF080A10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMaster ? const Color(0xFFFFD54F) : plinth.primaryColor.withValues(alpha: 0.6),
              width: isMaster ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isMaster ? const Color(0x66FFD54F) : glowColor,
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // Plinth Name & Master Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(plinth.icon, color: plinth.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    plinth.name.toUpperCase(),
                    style: TextStyle(
                      color: plinth.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: plinth.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: plinth.primaryColor, width: 0.8),
                    ),
                    child: Text(
                      'TIER $tier',
                      style: TextStyle(
                        color: plinth.primaryColor,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (isMaster) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Color(0x66FFD54F), blurRadius: 4)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 10, color: Colors.black),
                          SizedBox(width: 2),
                          Text(
                            'ACTIVE MASTER',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                plinth.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),

              // Hero Miniature Standing Atop Pedestal
              GestureDetector(
                onTap: () {
                  if (widget.brigadeUnits.isNotEmpty) {
                    setState(() {
                      _selectedUnitIndex = (_selectedUnitIndex + 1) % widget.brigadeUnits.length;
                    });
                  }
                },
                child: Column(
                  children: [
                    if (showcaseUnit != null) ...[
                      // Avatar miniature with soft pedestal shadow
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Base glow oval
                          Container(
                            width: 110,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: plinth.primaryColor.withValues(alpha: 0.35),
                              boxShadow: [
                                BoxShadow(
                                  color: plinth.primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // Hero Avatar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              showcaseUnit.customAvatarAsset ?? 'assets/images/flayed_butcher.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 70, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${showcaseUnit.name} (LVL ${showcaseUnit.level})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        '(Tap unit to rotate showcase hero)',
                        style: TextStyle(color: Colors.white38, fontSize: 8.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // The Physical Carved Plinth Slab
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      plinth.primaryColor.withValues(alpha: 0.30),
                      const Color(0xFF1E2433),
                      const Color(0xFF0F121A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: plinth.primaryColor.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: plinth.primaryColor.withValues(alpha: 0.35), blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(plinth.baseRuneSymbol, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'CARVED PEDESTAL • TIER $tier',
                        style: TextStyle(
                          color: plinth.primaryColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(plinth.baseRuneSymbol, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Socket Receptacle Indicator
              GestureDetector(
                onTap: () => _openSocketModal(plinth),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: socketedCore != null
                        ? socketedCore.accentColor.withValues(alpha: 0.15)
                        : const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: socketedCore != null ? socketedCore.accentColor : Colors.white24,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        socketedCore != null ? socketedCore.icon : Icons.circle_outlined,
                        size: 14,
                        color: socketedCore != null ? socketedCore.accentColor : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        socketedCore != null
                            ? 'SOCKETED: ${socketedCore.name.toUpperCase()}'
                            : 'EMPTY SOCKET • TAP TO SLOT TITAN CORE',
                        style: TextStyle(
                          color: socketedCore != null ? socketedCore.accentColor : Colors.white70,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (socketedCore != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              widget.plinthService.socketCore(plinth.id, null);
                            });
                          },
                          child: const Icon(Icons.cancel, size: 13, color: Colors.white54),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Plinth Archetype Selector Row
  Widget _buildPlinthSelectorRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT PLINTH ARCHETYPE:',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PlinthDefinition.allPlinths.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = PlinthDefinition.allPlinths[index];
              final bool isSelected = item.id == _selectedPlinthId;
              final bool isMaster = widget.plinthService.activeMasterPlinthId == item.id;
              final itemTier = widget.plinthService.getTier(item.id);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPlinthId = item.id;
                  });
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? item.primaryColor.withValues(alpha: 0.18)
                        : const Color(0xFF10131E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? item.primaryColor : (isMaster ? const Color(0xFFFFD54F) : const Color(0xFF262C3E)),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: item.primaryColor.withValues(alpha: 0.3), blurRadius: 6)]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(item.icon, size: 16, color: item.primaryColor),
                          if (isMaster)
                            const Icon(Icons.star, size: 13, color: Color(0xFFFFD54F))
                          else
                            Text('T$itemTier', style: TextStyle(fontSize: 9, color: item.primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        item.name.replaceFirst(' Plinth', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Plinth Tier Upgrade & Action Controls
  Widget _buildPlinthActionControls({
    required PlinthDefinition plinth,
    required int currentTier,
    required bool isMaster,
  }) {
    final bool canUpgrade = widget.plinthService.canUpgrade(plinth.id, widget.totalIchor);
    final shardCost = widget.plinthService.getUpgradeShardCost(plinth.id);
    final ichorCost = widget.plinthService.getUpgradeIchorCost(plinth.id);

    return Row(
      children: [
        // Equip Master Plinth Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isMaster
                ? null
                : () {
                    setState(() {
                      widget.plinthService.setActiveMasterPlinth(plinth.id);
                    });
                  },
            icon: Icon(isMaster ? Icons.check_circle : Icons.star_border, size: 16),
            label: Text(
              isMaster ? 'ACTIVE MASTER' : 'SET AS MASTER',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.8),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isMaster ? const Color(0xFF1B5E20) : const Color(0xFFFFD54F),
              foregroundColor: isMaster ? Colors.white : Colors.black,
              disabledBackgroundColor: const Color(0xFF1B5E20),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Upgrade Tier Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (currentTier >= 3 || !canUpgrade)
                ? null
                : () {
                    widget.plinthService.upgradePlinth(
                      plinth.id,
                      availableIchor: widget.totalIchor,
                      onDeductIchor: (cost) {
                        widget.onIchorChanged?.call(widget.totalIchor - cost);
                      },
                    );
                    setState(() {});
                  },
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: Text(
              currentTier >= 3
                  ? 'MAX TIER III'
                  : 'UPGRADE TIER ${currentTier + 1} ($shardCost 🪨 + $ichorCost 🔥)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 0.6),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF262C3E),
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }

  /// Titan Cores Workshop Tray
  Widget _buildTitanCoresWorkshop({
    required PlinthDefinition plinth,
    required TitanBossCore? socketedCore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SOCKETABLE TITAN BOSS CORES:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.8),
            ),
            Text(
              '${widget.plinthService.unlockedCores.length} HARVESTED CORES',
              style: const TextStyle(fontSize: 8.5, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Grid of Titan Cores
        ...TitanBossCore.allCores.map((core) {
          final bool isUnlocked = widget.plinthService.unlockedCores.contains(core.id);
          final bool isCurrentSocketed = socketedCore?.id == core.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrentSocketed
                  ? core.accentColor.withValues(alpha: 0.16)
                  : const Color(0xFF10131E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentSocketed ? core.accentColor : (isUnlocked ? const Color(0xFF2E354A) : Colors.white12),
                width: isCurrentSocketed ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: core.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: core.accentColor.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Icon(core.icon, color: core.accentColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            core.name,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: core.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              core.bossOrigin.toUpperCase(),
                              style: TextStyle(color: core.accentColor, fontSize: 7.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${core.passiveTitle}: ${core.passiveDescription}',
                        style: const TextStyle(color: Colors.white70, fontSize: 9.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Socket / Eject Button
                ElevatedButton(
                  onPressed: !isUnlocked
                      ? null
                      : () {
                          setState(() {
                            if (isCurrentSocketed) {
                              widget.plinthService.socketCore(plinth.id, null);
                            } else {
                              widget.plinthService.socketCore(plinth.id, core.id);
                            }
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentSocketed ? const Color(0xFFB71C1C) : core.accentColor,
                    foregroundColor: isCurrentSocketed ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    isCurrentSocketed ? 'EJECT' : 'SLOT CORE',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Active Combat Bonuses Summary Card
  Widget _buildActiveBonusesCard({
    required PlinthDefinition plinth,
    required int currentTier,
    required TitanBossCore? socketedCore,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F121C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF23283A), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00E5FF)),
              SizedBox(width: 6),
              Text(
                'ACTIVE BATTLE BONUSES & SYNERGY EFFECT:',
                style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• ${plinth.name} (Tier $currentTier): ${plinth.description}',
            style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.3),
          ),
          if (socketedCore != null) ...[
            const SizedBox(height: 4),
            Text(
              '• Socketed Core (${socketedCore.name}): ${socketedCore.passiveDescription}',
              style: TextStyle(color: socketedCore.accentColor, fontSize: 10, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  void _openSocketModal(PlinthDefinition plinth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF262C3E), width: 1.2),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SLOT TITAN CORE INTO ${plinth.name.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              ...TitanBossCore.allCores.map((c) {
                return ListTile(
                  leading: Icon(c.icon, color: c.accentColor),
                  title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  subtitle: Text(c.passiveTitle, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        widget.plinthService.socketCore(plinth.id, c.id);
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: c.accentColor, foregroundColor: Colors.black),
                    child: const Text('SLOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
