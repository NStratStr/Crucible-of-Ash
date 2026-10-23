import 'package:flutter/material.dart';
import '../../shared/models/relic_entity.dart';
import '../../shared/models/unit_entity.dart';
import 'relic_service.dart';

class RelicForgeScreen extends StatefulWidget {
  final RelicService relicService;
  final List<UnitEntity> brigadeUnits;
  final int totalIchor;
  final int cursedOre;
  final ValueChanged<int>? onIchorChanged;
  final ValueChanged<int>? onOreChanged;
  final int currentChapter;
  final int completedLinearStages;

  const RelicForgeScreen({
    super.key,
    required this.relicService,
    required this.brigadeUnits,
    required this.totalIchor,
    this.cursedOre = 0,
    this.onIchorChanged,
    this.onOreChanged,
    this.currentChapter = 1,
    this.completedLinearStages = 0,
  });

  @override
  State<RelicForgeScreen> createState() => _RelicForgeScreenState();
}

class _RelicForgeScreenState extends State<RelicForgeScreen> {
  String? _selectedUnitId;
  RelicSlot? _slotFilter;
  RelicSetType? _setTypeFilter;

  @override
  void initState() {
    super.initState();
    if (widget.brigadeUnits.isNotEmpty) {
      _selectedUnitId = widget.brigadeUnits.first.id;
    }
    widget.relicService.addListener(_onRelicUpdate);
  }

  @override
  void dispose() {
    widget.relicService.removeListener(_onRelicUpdate);
    super.dispose();
  }

  void _onRelicUpdate() {
    if (mounted) setState(() {});
  }

  void _forgeNewRelic() {
    const int ichorCost = 100;
    const int oreCost = 25;
    if (widget.totalIchor < ichorCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Ichor! Requires 100 Ichor to forge a Relic.'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }
    if (widget.cursedOre < oreCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Cursed Ore! Requires 25 Cursed Ore from expedition skirmishes.'),
          backgroundColor: Color(0xFF00695C),
        ),
      );
      return;
    }

    widget.onIchorChanged?.call(widget.totalIchor - ichorCost);
    widget.onOreChanged?.call(widget.cursedOre - oreCost);
    final forged = widget.relicService.forgeRandomRelic(
      chapter: widget.currentChapter,
      stageDepth: widget.completedLinearStages + 1,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Forged ${forged.name} (${forged.rarity.name.toUpperCase()})! Spent 100 Ichor & 25 Ore.'),
        backgroundColor: forged.rarityColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedUnit = widget.brigadeUnits.firstWhere(
      (u) => u.id == _selectedUnitId,
      orElse: () => widget.brigadeUnits.first,
    );

    final equippedRelics = widget.relicService.getRelicsForUnit(selectedUnit.id);
    final bonuses = widget.relicService.calculateBonuses(selectedUnit.id);
    final unequipped = widget.relicService.unequippedRelics.where((r) {
      if (_slotFilter != null && r.slot != _slotFilter) return false;
      if (_setTypeFilter != null && r.setType != _setTypeFilter) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181820),
        title: const Text(
          'THE RELIC FORGE & ARMORY',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF181820),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2B2B36)),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop, color: Color(0xFFEF5350), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${widget.totalIchor} ICHOR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${widget.cursedOre} ORE',
                  style: const TextStyle(
                    color: Color(0xFF80CBC4),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Forge Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF181820),
              border: Border(bottom: BorderSide(color: Color(0xFF2B2B36))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANVIL OF BLOOD & OBSIDIAN',
                        style: TextStyle(color: Color(0xFFE5A93C), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Transmute Ichor & Cursed Ore into rare armaments with 2-piece and 4-piece set synergies.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _forgeNewRelic,
                  icon: const Icon(Icons.fireplace, size: 16),
                  label: const Text('FORGE (100 / 25)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Hero Selector Carousel
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.brigadeUnits.length,
              itemBuilder: (context, index) {
                final unit = widget.brigadeUnits[index];
                final isSelected = unit.id == _selectedUnitId;

                return GestureDetector(
                  onTap: () => setState(() => _selectedUnitId = unit.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFB3261E).withValues(alpha: 0.25) : const Color(0xFF1E1E26),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE5A93C) : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(unit.effectiveAvatarAsset, fit: BoxFit.cover),
                          ),
                        ),
                        Text(
                          unit.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Equipped Relic Slots (4 Slots: Weapon, Armor, Talisman, Sigil)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: RelicSlot.values.map((slot) {
                final relic = equippedRelics.where((r) => r.slot == slot).firstOrNull;
                return Expanded(
                  child: _buildEquipmentSlotCard(slot: slot, relic: relic, unitId: selectedUnit.id),
                );
              }).toList(),
            ),
          ),

          // Active Set Bonuses Banner
          if (bonuses.activeSetBonuses.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2E7D32), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, size: 14, color: Color(0xFF81C784)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ACTIVE SYNERGY: ${bonuses.activeSetBonuses.map((s) => RelicEntity.setName(s)).join(" • ")} '
                      '(${bonuses.activeSetBonuses.map((s) => RelicEntity.setBonusDescription(s)).join("; ")})',
                      style: const TextStyle(color: Color(0xFF81C784), fontSize: 9.5, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Slot Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('ALL SLOTS', null),
                ...RelicSlot.values.map((s) => _buildFilterChip(s.name.toUpperCase(), s)),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Set Synergy Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildSetFilterChip('ALL SETS', null, const Color(0xFFB3261E)),
                _buildSetFilterChip('BLOOD (2)', RelicSetType.bloodleech, const Color(0xFFEF5350)),
                _buildSetFilterChip('IRON (2)', RelicSetType.ironclad, const Color(0xFF90A4AE)),
                _buildSetFilterChip('TEMP (2)', RelicSetType.tempest, const Color(0xFF29B6F6)),
                _buildSetFilterChip('SHADOW (2)', RelicSetType.shadowstalker, const Color(0xFFFFB300)),
                _buildSetFilterChip('EXEC (4)', RelicSetType.executioner, const Color(0xFFAB47BC)),
                _buildSetFilterChip('BLIGHT (4)', RelicSetType.blightweaver, const Color(0xFF66BB6A)),
                _buildSetFilterChip('DREAD (4)', RelicSetType.dreadnought, const Color(0xFF7E57C2)),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Unequipped Relics List
          Expanded(
            child: unequipped.isEmpty
                ? Center(
                    child: Text(
                      'No unequipped ${_slotFilter != null ? _slotFilter!.name.toUpperCase() : ""} ${_setTypeFilter != null ? RelicEntity.setName(_setTypeFilter!) : ""} relics in inventory.\nForge more using Ichor above!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: unequipped.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final relic = unequipped[index];
                      return _buildInventoryRelicCard(relic: relic, targetUnitId: selectedUnit.id);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _refineRelic(RelicEntity relic) {
    final maxTier = RelicEntity.maxRefinementTierForChapter(widget.currentChapter);
    if (!relic.canUpgradeForChapter(widget.currentChapter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refinement capped at +\! Conquer Chapter \ World Titan to promote the realm and unlock higher refinement.',
          ),
          backgroundColor: const Color(0xFFE5A93C),
        ),
      );
      return;
    }

    final cost = relic.upgradeCostIchor;
    const int oreCost = 15;
    if (widget.totalIchor < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Ichor! Refinement requires $cost Ichor.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }
    if (widget.cursedOre < oreCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Cursed Ore! Refinement requires 15 Cursed Ore.'),
          backgroundColor: Color(0xFF00695C),
        ),
      );
      return;
    }

    widget.onIchorChanged?.call(widget.totalIchor - cost);
    widget.onOreChanged?.call(widget.cursedOre - oreCost);
    final upgraded = widget.relicService.upgradeRelic(relic.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refined to ${upgraded.displayName}! Attributes increased by +25%.'),
        backgroundColor: upgraded.rarityColor,
      ),
    );
  }

  Widget _buildEquipmentSlotCard({
    required RelicSlot slot,
    required RelicEntity? relic,
    required String unitId,
  }) {
    final bool hasRelic = relic != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasRelic ? relic.rarityColor : const Color(0xFF2B2B36),
          width: hasRelic ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(slot == RelicSlot.weapon
                  ? Icons.colorize
                  : (slot == RelicSlot.armor
                      ? Icons.shield
                      : (slot == RelicSlot.talisman ? Icons.auto_awesome : Icons.token)),
                  size: 14,
                  color: hasRelic ? relic.rarityColor : Colors.white38),
              Text(
                hasRelic && relic.upgradeLevel > 0
                    ? '+${relic.upgradeLevel}'
                    : slot.name.substring(0, 3).toUpperCase(),
                style: TextStyle(
                  color: hasRelic && relic.upgradeLevel > 0 ? const Color(0xFFE5A93C) : const Color(0xFF8E8EA0),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasRelic ? relic.displayName : 'EMPTY',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasRelic ? Colors.white : Colors.white30,
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 4),
          if (hasRelic)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (relic.canUpgrade)
                  GestureDetector(
                    onTap: () => _refineRelic(relic),
                    child: const Text('REFINE',
                        style: TextStyle(color: Color(0xFFE5A93C), fontSize: 7.5, fontWeight: FontWeight.bold)),
                  ),
                GestureDetector(
                  onTap: () => widget.relicService.unequipRelic(relic.id),
                  child: const Text('REMOVE',
                      style: TextStyle(color: Color(0xFFEF5350), fontSize: 7.5, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          else
            const Text('UNSLOTTED', style: TextStyle(color: Colors.white24, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, RelicSlot? slot) {
    final bool isSelected = _slotFilter == slot;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _slotFilter = slot),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB3261E) : const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetFilterChip(String label, RelicSetType? setType, Color accentColor) {
    final bool isSelected = _setTypeFilter == setType;

    return GestureDetector(
      onTap: () => setState(() => _setTypeFilter = setType),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.25) : const Color(0xFF1E1E26),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accentColor : Colors.white60,
              fontSize: 8.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryRelicCard({
    required RelicEntity relic,
    required String targetUnitId,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: relic.rarityColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: relic.rarityColor.withValues(alpha: 0.2),
            child: Icon(relic.slotIcon, color: relic.rarityColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        relic.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: relic.rarityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        relic.rarity.name.toUpperCase(),
                        style: TextStyle(color: relic.rarityColor, fontSize: 7.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (relic.upgradeLevel > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFE5A93C), width: 0.5),
                        ),
                        child: Text(
                          '+${relic.upgradeLevel}',
                          style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 7.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Set: ${RelicEntity.setName(relic.setType)} (${RelicEntity.setBonusDescription(relic.setType)})',
                  style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelicStats(relic),
                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  widget.relicService.equipRelic(relicId: relic.id, unitId: targetUnitId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B36),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('EQUIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              if (relic.canUpgradeForChapter(widget.currentChapter)) ...[
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () => _refineRelic(relic),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5A93C), width: 1),
                    foregroundColor: const Color(0xFFE5A93C),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    'REFINE (${relic.upgradeCostIchor}I)',
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelicStats(RelicEntity r) {
    final List<String> parts = [];
    if (r.bonusAttack > 0) parts.add('+${r.bonusAttack} ATK');
    if (r.bonusDefense > 0) parts.add('+${r.bonusDefense} DEF');
    if (r.bonusHp > 0) parts.add('+${r.bonusHp} HP');
    if (r.bonusSpeed > 0) parts.add('+${r.bonusSpeed} SPD');
    if (r.bonusCritRate > 0) parts.add('+${(r.bonusCritRate * 100).toInt()}% CRIT');
    return parts.isEmpty ? 'Pristine vessel' : parts.join(' • ');
  }
}
