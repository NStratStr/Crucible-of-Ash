import 'package:flutter/material.dart';
import '../../shared/models/relic_entity.dart';
import '../../shared/models/unit_entity.dart';
import 'relic_service.dart';

class RelicForgeScreen extends StatefulWidget {
  final RelicService relicService;
  final List<UnitEntity> brigadeUnits;
  final int totalIchor;
  final ValueChanged<int>? onIchorChanged;

  const RelicForgeScreen({
    super.key,
    required this.relicService,
    required this.brigadeUnits,
    required this.totalIchor,
    this.onIchorChanged,
  });

  @override
  State<RelicForgeScreen> createState() => _RelicForgeScreenState();
}

class _RelicForgeScreenState extends State<RelicForgeScreen> {
  String? _selectedUnitId;
  RelicSlot? _slotFilter;

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
    const int forgeCost = 150;
    if (widget.totalIchor < forgeCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient Ichor! Requires 150 Ichor to forge a Relic.'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      return;
    }

    widget.onIchorChanged?.call(widget.totalIchor - forgeCost);
    final forged = widget.relicService.forgeRandomRelic();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Forged ${forged.name} (${forged.rarity.name.toUpperCase()})!'),
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
      if (_slotFilter == null) return true;
      return r.slot == _slotFilter;
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
              color: const Color(0xFFB3261E).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB3261E)),
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
                    fontSize: 11,
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
                        'Transmute Ichor into rare armaments with 2-piece and 4-piece set synergies.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _forgeNewRelic,
                  icon: const Icon(Icons.fireplace, size: 16),
                  label: const Text('FORGE (150)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    child: Center(
                      child: Text(
                        unit.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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

          const SizedBox(height: 6),

          // Unequipped Relics List
          Expanded(
            child: unequipped.isEmpty
                ? Center(
                    child: Text(
                      'No unequipped ${_slotFilter?.name.toUpperCase() ?? ""} relics in inventory.\nForge more using Ichor above!',
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
                slot.name.substring(0, 3).toUpperCase(),
                style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasRelic ? relic.name : 'EMPTY',
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
            GestureDetector(
              onTap: () => widget.relicService.unequipRelic(relic.id),
              child: const Text('REMOVE', style: TextStyle(color: Color(0xFFEF5350), fontSize: 8, fontWeight: FontWeight.bold)),
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
                    Text(
                      relic.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
