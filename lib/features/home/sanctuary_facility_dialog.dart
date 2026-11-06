import 'package:flutter/material.dart';
import '../../core/audio/global_audio_service.dart';

class SanctuaryDistrictData {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final String catalystName;
  final String catalystType; // 'brimSlag', 'solarIron', 'quicksilver', 'sigils'
  final IconData catalystIcon;
  final Color catalystColor;
  final int maxTier;
  final Map<int, String> tierPerks;
  final Map<int, int> tierIchorCosts;
  final Map<int, int> tierOreCosts;
  final Map<int, int> tierCatalystCosts;

  const SanctuaryDistrictData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.catalystName,
    required this.catalystType,
    required this.catalystIcon,
    required this.catalystColor,
    required this.maxTier,
    required this.tierPerks,
    required this.tierIchorCosts,
    required this.tierOreCosts,
    required this.tierCatalystCosts,
  });
}

class SanctuaryFacilityUpgradeDialog extends StatefulWidget {
  final int totalIchor;
  final int cursedOre;
  final int bloodlineSigils;
  final int brimSlagCores;
  final int solarIron;
  final int quicksilver;
  final int crucibleTier;
  final int forgeTier;
  final int hospiceTier;
  final int spindleTier;
  final String? initialDistrictId;
  final void Function({
    required String facilityId,
    required int newTier,
    required int ichorCost,
    required int oreCost,
    required int reagentCost,
    required String reagentType,
  }) onUpgradeFacility;

  const SanctuaryFacilityUpgradeDialog({
    super.key,
    required this.totalIchor,
    required this.cursedOre,
    required this.bloodlineSigils,
    required this.brimSlagCores,
    required this.solarIron,
    required this.quicksilver,
    required this.crucibleTier,
    required this.forgeTier,
    required this.hospiceTier,
    required this.spindleTier,
    this.initialDistrictId,
    required this.onUpgradeFacility,
  });

  static Future<void> show(
    BuildContext context, {
    required int totalIchor,
    required int cursedOre,
    required int bloodlineSigils,
    required int brimSlagCores,
    required int solarIron,
    required int quicksilver,
    required int crucibleTier,
    required int forgeTier,
    required int hospiceTier,
    required int spindleTier,
    String? initialDistrictId,
    required void Function({
      required String facilityId,
      required int newTier,
      required int ichorCost,
      required int oreCost,
      required int reagentCost,
      required String reagentType,
    }) onUpgradeFacility,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => SanctuaryFacilityUpgradeDialog(
        totalIchor: totalIchor,
        cursedOre: cursedOre,
        bloodlineSigils: bloodlineSigils,
        brimSlagCores: brimSlagCores,
        solarIron: solarIron,
        quicksilver: quicksilver,
        crucibleTier: crucibleTier,
        forgeTier: forgeTier,
        hospiceTier: hospiceTier,
        spindleTier: spindleTier,
        initialDistrictId: initialDistrictId,
        onUpgradeFacility: onUpgradeFacility,
      ),
    );
  }

  @override
  State<SanctuaryFacilityUpgradeDialog> createState() =>
      _SanctuaryFacilityUpgradeDialogState();
}

class _SanctuaryFacilityUpgradeDialogState
    extends State<SanctuaryFacilityUpgradeDialog> {
  late int _ichor;
  late int _ore;
  late int _sigils;
  late int _brimSlag;
  late int _solarIron;
  late int _quicksilver;

  late int _crucibleTier;
  late int _forgeTier;
  late int _hospiceTier;
  late int _spindleTier;

  late String _selectedDistrictId;
  String? _upgradeNotification;

  static const List<SanctuaryDistrictData> districts = [
    SanctuaryDistrictData(
      id: 'crucible',
      name: 'THE GREAT CRUCIBLE',
      subtitle: 'Alchemical Melting Pot & Generational Evolution',
      icon: Icons.bloodtype_outlined,
      themeColor: Color(0xFFFF7043),
      catalystName: 'Brim-Slag Core',
      catalystType: 'brimSlag',
      catalystIcon: Icons.whatshot,
      catalystColor: Color(0xFFFF9100),
      maxTier: 4,
      tierPerks: {
        1: 'Gen 1 & 2 Fusion unlocked. Max Unit Level Cap: Lv. 20.',
        2: 'Gen 3 Fusion unlocked (Max Lv. 30). Trait Grafting Ichor cost discounted by -20%.',
        3: 'Gen 4 & 5 Fusion unlocked (Max Lv. 50). Duplicate Ascension grants +10% extra stat bonus.',
        4: 'Gen 6 Apex Sovereigns unlocked (Max Lv. 60). 100% stat inheritance efficiency.',
      },
      tierIchorCosts: {2: 250, 3: 550, 4: 1200},
      tierOreCosts: {2: 40, 3: 90, 4: 200},
      tierCatalystCosts: {2: 1, 3: 3, 4: 5},
    ),
    SanctuaryDistrictData(
      id: 'forge',
      name: 'THE RELIC FORGE',
      subtitle: 'Enchanted Armory & Plinth Sculptory',
      icon: Icons.build_outlined,
      themeColor: Color(0xFF42A5F5),
      catalystName: 'Solar-Iron',
      catalystType: 'solarIron',
      catalystIcon: Icons.shield_outlined,
      catalystColor: Color(0xFF80D8FF),
      maxTier: 3,
      tierPerks: {
        1: 'Common & Uncommon Relics. Basic Stone Plinths available.',
        2: '4-Piece Set Bonuses unlocked. Cold Iron Plinths (+15% Armor) & Crypt Bone Plinths (+25% Vampiric Siphon).',
        3: 'Obsidian Plinths (+10% ATK) & Sovereign Gold Plinths (+10% All Stats). Relic Reforging ore cost -25%.',
      },
      tierIchorCosts: {2: 200, 3: 500},
      tierOreCosts: {2: 120, 3: 300},
      tierCatalystCosts: {2: 1, 3: 3},
    ),
    SanctuaryDistrictData(
      id: 'hospice',
      name: 'THE HOSPICE GATES',
      subtitle: 'Sanctuary Triage & Summoning Convocation',
      icon: Icons.person_add_alt_1,
      themeColor: Color(0xFFFFD54F),
      catalystName: 'Bloodline Sigil',
      catalystType: 'sigils',
      catalystIcon: Icons.military_tech,
      catalystColor: Color(0xFFFFD54F),
      maxTier: 4,
      tierPerks: {
        1: 'Standard Thrall Convocation. Reserve Roster Capacity: 15 Units.',
        2: 'Reserve Roster Capacity: 25 Units. Faction Convocation (+15% Ash Legion / Crypt Stalkers rate).',
        3: 'Reserve Roster Capacity: 40 Units. Elite Bloodline Rites (+1 guaranteed 3-Star veteran per 10 summons).',
        4: 'Reserve Roster Capacity: 60 Units. Legendary Pilgrims & Commander duplicate rites unlocked.',
      },
      tierIchorCosts: {2: 200, 3: 500, 4: 1000},
      tierOreCosts: {2: 30, 3: 80, 4: 180},
      tierCatalystCosts: {2: 1, 3: 2, 4: 4},
    ),
    SanctuaryDistrictData(
      id: 'spindle',
      name: 'QUICKSILVER SPINDLE',
      subtitle: 'Resonance Beacon & Leyline Focus Reservoir',
      icon: Icons.auto_awesome,
      themeColor: Color(0xFFAB47BC),
      catalystName: 'Quicksilver',
      catalystType: 'quicksilver',
      catalystIcon: Icons.bubble_chart_outlined,
      catalystColor: Color(0xFFCE93D8),
      maxTier: 3,
      tierPerks: {
        1: '4-Card Hand. 3 Max Focus in battle.',
        2: '5 Max Focus. Brigade starts combat with +500 Action Points (faster opening strike).',
        3: '7 Max Focus. Brigade starts combat with +1,500 Action Points. Card redraw cost reduced by 50%.',
      },
      tierIchorCosts: {2: 250, 3: 600},
      tierOreCosts: {2: 50, 3: 120},
      tierCatalystCosts: {2: 1, 3: 3},
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ichor = widget.totalIchor;
    _ore = widget.cursedOre;
    _sigils = widget.bloodlineSigils;
    _brimSlag = widget.brimSlagCores;
    _solarIron = widget.solarIron;
    _quicksilver = widget.quicksilver;

    _crucibleTier = widget.crucibleTier;
    _forgeTier = widget.forgeTier;
    _hospiceTier = widget.hospiceTier;
    _spindleTier = widget.spindleTier;

    _selectedDistrictId = widget.initialDistrictId ?? 'crucible';
  }

  int _getTier(String districtId) {
    switch (districtId) {
      case 'crucible':
        return _crucibleTier;
      case 'forge':
        return _forgeTier;
      case 'hospice':
        return _hospiceTier;
      case 'spindle':
      case 'beacon':
        return _spindleTier;
      default:
        return 1;
    }
  }

  int _getCatalystStock(String catalystType) {
    switch (catalystType) {
      case 'brimSlag':
        return _brimSlag;
      case 'solarIron':
        return _solarIron;
      case 'quicksilver':
        return _quicksilver;
      case 'sigils':
        return _sigils;
      default:
        return 0;
    }
  }

  void _handleUpgrade(SanctuaryDistrictData district) {
    final currentTier = _getTier(district.id);
    if (currentTier >= district.maxTier) return;

    final nextTier = currentTier + 1;
    final ichorCost = district.tierIchorCosts[nextTier] ?? 0;
    final oreCost = district.tierOreCosts[nextTier] ?? 0;
    final catalystCost = district.tierCatalystCosts[nextTier] ?? 0;
    final catalystStock = _getCatalystStock(district.catalystType);

    if (_ichor < ichorCost || _ore < oreCost || catalystStock < catalystCost) {
      return;
    }

    GlobalAudioService().playSfx('Bluezone_BC0297_stone_impact_hammer_015.wav');

    setState(() {
      _ichor -= ichorCost;
      _ore -= oreCost;
      if (district.catalystType == 'brimSlag') _brimSlag -= catalystCost;
      if (district.catalystType == 'solarIron') _solarIron -= catalystCost;
      if (district.catalystType == 'quicksilver') _quicksilver -= catalystCost;
      if (district.catalystType == 'sigils') _sigils -= catalystCost;

      if (district.id == 'crucible') _crucibleTier = nextTier;
      if (district.id == 'forge') _forgeTier = nextTier;
      if (district.id == 'hospice') _hospiceTier = nextTier;
      if (district.id == 'spindle') _spindleTier = nextTier;

      _upgradeNotification = '${district.name} UPGRADED TO TIER ${_toRoman(nextTier)}!';
    });

    widget.onUpgradeFacility(
      facilityId: district.id,
      newTier: nextTier,
      ichorCost: ichorCost,
      oreCost: oreCost,
      reagentCost: catalystCost,
      reagentType: district.catalystType,
    );
  }

  String _toRoman(int num) {
    switch (num) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      default:
        return num.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDistrict = districts.firstWhere(
      (d) => d.id == _selectedDistrictId,
      orElse: () => districts.first,
    );
    final currentTier = _getTier(activeDistrict.id);
    final isMax = currentTier >= activeDistrict.maxTier;
    final nextTier = currentTier + 1;

    final nextIchorCost = isMax ? 0 : (activeDistrict.tierIchorCosts[nextTier] ?? 0);
    final nextOreCost = isMax ? 0 : (activeDistrict.tierOreCosts[nextTier] ?? 0);
    final nextCatalystCost = isMax ? 0 : (activeDistrict.tierCatalystCosts[nextTier] ?? 0);
    final catalystStock = _getCatalystStock(activeDistrict.catalystType);

    final canAfford = !isMax &&
        _ichor >= nextIchorCost &&
        _ore >= nextOreCost &&
        catalystStock >= nextCatalystCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0D15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.65), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 28,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeaderBar(context),

            // Stored Reagents Bar
            _buildReagentsBar(),

            if (_upgradeNotification != null) _buildCelebrationBanner(),

            // Content Area: Left Tab Bar + Right Details Panel
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // District List / Tabs
                  Container(
                    width: 260,
                    decoration: const BoxDecoration(
                      color: Color(0xFF090A10),
                      border: Border(right: BorderSide(color: Colors.white12, width: 1)),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: districts.length,
                      itemBuilder: (ctx, idx) {
                        final d = districts[idx];
                        final tier = _getTier(d.id);
                        final isSelected = d.id == _selectedDistrictId;

                        return InkWell(
                          onTap: () {
                            GlobalAudioService().playSfx('SWSH_Swing 3 Large 03_DDUMAIS_NONE.wav');
                            setState(() {
                              _selectedDistrictId = d.id;
                              _upgradeNotification = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? d.themeColor.withValues(alpha: 0.16) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? d.themeColor : Colors.white10,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: d.themeColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(d.icon, color: d.themeColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.name,
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.black45,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: d.themeColor.withValues(alpha: 0.5), width: 0.8),
                                            ),
                                            child: Text(
                                              'TIER ${_toRoman(tier)}',
                                              style: TextStyle(
                                                color: d.themeColor,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          if (tier >= d.maxTier) ...[
                                            const SizedBox(width: 6),
                                            const Text(
                                              'MAX',
                                              style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // District Detail & Upgrade Actions
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // District Hero Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: activeDistrict.themeColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: activeDistrict.themeColor, width: 1.5),
                                ),
                                child: Icon(activeDistrict.icon, color: activeDistrict.themeColor, size: 32),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeDistrict.name,
                                      style: const TextStyle(
                                        fontFamily: 'serif',
                                        color: Color(0xFFFFD54F),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      activeDistrict.subtitle,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: activeDistrict.themeColor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: activeDistrict.themeColor, width: 1.2),
                                ),
                                child: Text(
                                  'TIER ${_toRoman(currentTier)} / ${_toRoman(activeDistrict.maxTier)}',
                                  style: TextStyle(
                                    color: activeDistrict.themeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),

                          // Tier Progression Flow
                          const Text(
                            'DISTRICT EVOLUTION & PERKS',
                            style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 10),

                          Column(
                            children: List.generate(activeDistrict.maxTier, (idx) {
                              final tierNum = idx + 1;
                              final isCurrent = tierNum == currentTier;
                              final isUnlocked = tierNum <= currentTier;
                              final perkText = activeDistrict.tierPerks[tierNum] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? activeDistrict.themeColor.withValues(alpha: 0.15)
                                      : (isUnlocked ? const Color(0xFF13141F) : const Color(0xFF090A0E)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFFFFD54F)
                                        : (isUnlocked ? activeDistrict.themeColor.withValues(alpha: 0.4) : Colors.white10),
                                    width: isCurrent ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isUnlocked ? Icons.check_circle : Icons.lock_outline,
                                      color: isUnlocked
                                          ? (isCurrent ? const Color(0xFFFFD54F) : activeDistrict.themeColor)
                                          : Colors.white30,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'TIER ${_toRoman(tierNum)}',
                                                style: TextStyle(
                                                  color: isUnlocked ? const Color(0xFFFFD54F) : Colors.white54,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (isCurrent) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE ARCHITECTURE',
                                                    style: TextStyle(color: Color(0xFFFFD54F), fontSize: 8.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            perkText,
                                            style: TextStyle(
                                              color: isUnlocked ? Colors.white : Colors.white54,
                                              fontSize: 11,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),

                          // Upgrade Requirements & Action
                          if (isMax)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF121A16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stars, color: Color(0xFFFFD54F), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'CITADEL DISTRICT MAXIMALLY FORTIFIED',
                                    style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            Text(
                              'UPGRADE TO TIER ${_toRoman(nextTier)} REQUIREMENTS',
                              style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 8),

                            // Cost Row
                            Row(
                              children: [
                                _buildCostItem(
                                  label: 'Crucible Ichor',
                                  cost: nextIchorCost,
                                  stock: _ichor,
                                  icon: Icons.bloodtype,
                                  color: const Color(0xFFFF5252),
                                ),
                                const SizedBox(width: 10),
                                _buildCostItem(
                                  label: 'Cursed Ore',
                                  cost: nextOreCost,
                                  stock: _ore,
                                  icon: Icons.diamond_outlined,
                                  color: const Color(0xFF42A5F5),
                                ),
                                const SizedBox(width: 10),
                                _buildCostItem(
                                  label: activeDistrict.catalystName,
                                  cost: nextCatalystCost,
                                  stock: catalystStock,
                                  icon: activeDistrict.catalystIcon,
                                  color: activeDistrict.catalystColor,
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford ? const Color(0xFFE5A93C) : Colors.white10,
                                  foregroundColor: canAfford ? Colors.black : Colors.white38,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: canAfford ? const Color(0xFFFFD54F) : Colors.white24,
                                      width: 1.2,
                                    ),
                                  ),
                                  elevation: canAfford ? 6 : 0,
                                ),
                                onPressed: canAfford ? () => _handleUpgrade(activeDistrict) : null,
                                icon: const Icon(Icons.shield, size: 18),
                                label: Text(
                                  canAfford
                                      ? 'FORTIFY DISTRICT TO TIER ${_toRoman(nextTier)}'
                                      : 'INSUFFICIENT REAGENTS (HARVEST BOSSES)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildHeaderBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF13141F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFFFFD54F), size: 20),
              SizedBox(width: 10),
              Text(
                'CITADEL SANCTUARY ARCHITECTURE',
                style: TextStyle(
                  fontFamily: 'serif',
                  color: Color(0xFFFFD54F),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 16),
          const SizedBox(width: 8),
          Text(
            _upgradeNotification!,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildReagentsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF090A10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildReagentBadge('Ichor', _ichor, Icons.bloodtype, const Color(0xFFFF5252)),
          _buildReagentBadge('Ore', _ore, Icons.diamond_outlined, const Color(0xFF42A5F5)),
          _buildReagentBadge('Sigils', _sigils, Icons.military_tech, const Color(0xFFFFD54F)),
          _buildReagentBadge('Brim-Slag', _brimSlag, Icons.whatshot, const Color(0xFFFF9100)),
          _buildReagentBadge('Solar-Iron', _solarIron, Icons.shield_outlined, const Color(0xFF80D8FF)),
          _buildReagentBadge('Quicksilver', _quicksilver, Icons.bubble_chart_outlined, const Color(0xFFCE93D8)),
        ],
      ),
    );
  }

  Widget _buildReagentBadge(String label, int count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 9.5),
        ),
      ],
    );
  }

  Widget _buildCostItem({
    required String label,
    required int cost,
    required int stock,
    required IconData icon,
    required Color color,
  }) {
    final hasEnough = stock >= cost;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasEnough ? const Color(0xFF141624) : const Color(0xFF1E1114),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasEnough ? color.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$stock / $cost',
              style: TextStyle(
                color: hasEnough ? color : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
