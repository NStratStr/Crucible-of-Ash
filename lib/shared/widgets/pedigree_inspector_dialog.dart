import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../features/relics/relic_service.dart';
import '../models/relic_entity.dart';
import '../models/skill_entity.dart';
import '../models/trait_entity.dart';
import '../models/unit_entity.dart';
import 'gothic_card_frame_widget.dart';
import 'gothic_character_sheet_card.dart';
import 'hexagonal_affinity_wheel_widget.dart';

class PedigreeInspectorDialog extends StatefulWidget {
  final UnitEntity unit;
  final bool isEnemy;
  final RelicService? relicService;
  final int totalIchor;
  final void Function(UnitEntity updatedUnit, int ichorCost)? onLevelUp;
  final bool initialShowCharacterSheet;

  const PedigreeInspectorDialog({
    super.key,
    required this.unit,
    this.isEnemy = false,
    this.relicService,
    this.totalIchor = 0,
    this.onLevelUp,
    this.initialShowCharacterSheet = false,
  });

  static Future<void> show(
    BuildContext context,
    UnitEntity unit, {
    bool isEnemy = false,
    RelicService? relicService,
    int totalIchor = 0,
    void Function(UnitEntity updatedUnit, int ichorCost)? onLevelUp,
    bool initialShowCharacterSheet = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PedigreeInspectorDialog(
        unit: unit,
        isEnemy: isEnemy,
        relicService: relicService,
        totalIchor: totalIchor,
        onLevelUp: onLevelUp,
        initialShowCharacterSheet: initialShowCharacterSheet,
      ),
    );
  }

  @override
  State<PedigreeInspectorDialog> createState() => _PedigreeInspectorDialogState();
}

class _PedigreeInspectorDialogState extends State<PedigreeInspectorDialog> {
  late UnitEntity _currentUnit;
  late int _currentIchor;
  late bool _showCharacterSheet;

  @override
  void initState() {
    super.initState();
    _currentUnit = widget.unit;
    _currentIchor = widget.totalIchor;
    _showCharacterSheet = widget.initialShowCharacterSheet;
  }

  void _handleLevelUp({int levels = 1}) {
    final ichorCost = _currentUnit.ichorCostForNextLevel;
    if (_currentIchor < ichorCost) return;
    final updated = _currentUnit.levelUp(levels: levels);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= ichorCost;
    });
    widget.onLevelUp?.call(updated, ichorCost);
  }

  void _handleMaxLevel() {
    final ichorCost = _currentUnit.ichorCostForMaxLevel;
    final xpNeeded = _currentUnit.xpNeededForMaxLevel;
    if (_currentIchor < ichorCost) return;
    final updated = _currentUnit.addXp(xpNeeded);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= ichorCost;
    });
    widget.onLevelUp?.call(updated, ichorCost);
  }

  void _handleInfuseXp(int xp) {
    final ichorCost = UnitEntity.xpToIchorCost(xp);
    if (_currentIchor < ichorCost) return;
    final updated = _currentUnit.addXp(xp);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= ichorCost;
    });
    widget.onLevelUp?.call(updated, ichorCost);
  }

  void _handlePromoteRarity() {
    if (!_currentUnit.canPromoteRarity) return;
    final cost = _currentUnit.rarityPromotionIchorCost;
    if (_currentIchor < cost) return;
    final updated = _currentUnit.promoteRarity();
    setState(() {
      _currentUnit = updated;
      _currentIchor -= cost;
    });
    widget.onLevelUp?.call(updated, cost);
  }

  void _handleSculptPlinth(PlinthMaterial material, int cost) {
    if (_currentUnit.plinthMaterial == material) return;
    if (_currentIchor < cost) return;
    final updated = _currentUnit.copyWith(plinthMaterial: material);
    setState(() {
      _currentUnit = updated;
      _currentIchor -= cost;
    });
    widget.onLevelUp?.call(updated, cost);
  }

  String _getPlinthPassiveDescription(PlinthMaterial material) {
    switch (material) {
      case PlinthMaterial.slate:
        return 'Standard Crypt Slate (Balanced Baseline)';
      case PlinthMaterial.iron:
        return '+15% Armor & Frontline Fortitude';
      case PlinthMaterial.bone:
        return '+25% Vampiric Siphon on Strike';
      case PlinthMaterial.obsidian:
        return '+10% Attack Power & Piercing Impact';
      case PlinthMaterial.gold:
        return '+10% All Combat Attributes (Sovereign Pedestal)';
    }
  }

  Widget _buildInfusionButton({
    required String label,
    required int cost,
    required VoidCallback? onPressed,
    bool isHighlight = false,
  }) {
    final bool canAfford = onPressed != null;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isHighlight
            ? (canAfford ? const Color(0xFF7B1FA2) : const Color(0xFF2B2B36))
            : (canAfford ? const Color(0xFFB3261E) : const Color(0xFF2B2B36)),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF1E1E24),
        disabledForegroundColor: Colors.white30,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: canAfford
                ? (isHighlight ? const Color(0xFFBA68C8) : const Color(0xFFE57373))
                : Colors.transparent,
            width: 0.8,
          ),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop,
                size: 9,
                color: canAfford ? const Color(0xFFEF5350) : Colors.white30,
              ),
              const SizedBox(width: 2),
              Text(
                '$cost Ichor',
                style: TextStyle(
                  fontSize: 8.5,
                  color: canAfford ? Colors.white70 : Colors.white30,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getArchetypeColor(Archetype type) {
    switch (type) {
      case Archetype.juggernaut:
        return const Color(0xFFC62828); // Crimson
      case Archetype.assassin:
        return const Color(0xFF6A1B9A); // Shadow Purple
      case Archetype.marksman:
        return const Color(0xFF2E7D32); // Emerald
      case Archetype.skirmisher:
        return const Color(0xFFE65100); // Amber Orange
      case Archetype.support:
        return const Color(0xFF00838F); // Azure Teal
      case Archetype.occultist:
        return const Color(0xFF4527A0); // Void Indigo
    }
  }

  IconData _getArchetypeIcon(Archetype type) {
    switch (type) {
      case Archetype.juggernaut:
        return Icons.shield;
      case Archetype.assassin:
        return Icons.colorize;
      case Archetype.marksman:
        return Icons.gps_fixed;
      case Archetype.skirmisher:
        return Icons.air;
      case Archetype.support:
        return Icons.healing;
      case Archetype.occultist:
        return Icons.auto_awesome;
    }
  }

  String _getGenerationTitle(int gen) {
    switch (gen) {
      case 1:
        return 'GEN 1 • FERAL THRALL';
      case 2:
        return 'GEN 2 • CHIMERIC HEIR';
      case 3:
        return 'GEN 3 • CRUCIBLE-BORN';
      case 4:
        return 'GEN 4 • PUREBLOOD SOVEREIGN';
      default:
        return 'GEN $gen • DESCENDANT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _currentUnit;
    final isEnemy = widget.isEnemy;
    final bool isBoss = isEnemy && (unit.isBoss || unit.level >= 20 || unit.name.toLowerCase().contains('titan'));
    final relicService = widget.relicService;
    final themeColor = _getArchetypeColor(unit.archetype);
    final prey = CombatMath.getPreyArchetype(unit.archetype);
    final predator = CombatMath.getPredatorArchetype(unit.archetype);

    final equippedRelics = relicService?.getRelicsForUnit(unit.id) ?? const <RelicEntity>[];
    final relicBonuses = relicService?.calculateBonuses(unit.id) ?? const UnitRelicBonuses();

    if (_showCharacterSheet) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          child: GothicCharacterSheetCard(
            unit: unit,
            relicService: relicService,
            totalIchor: _currentIchor,
            onLevelUp: (updated, cost) {
              setState(() {
                _currentUnit = updated;
                _currentIchor -= cost;
              });
              widget.onLevelUp?.call(updated, cost);
            },
            onClose: () => Navigator.pop(context),
            onToggleClassicCodex: () {
              setState(() {
                _showCharacterSheet = false;
              });
            },
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isBoss
              ? const Color(0xFFFF1744)
              : (isEnemy ? const Color(0xFFB3261E) : const Color(0xFF2E7D32)),
          width: isBoss ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isBoss ? const Color(0xFFB71C1C) : themeColor).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isBoss ? const Color(0xFFFF5252) : themeColor, width: 1.5),
                  ),
                  child: Icon(isBoss ? Icons.dangerous : _getArchetypeIcon(unit.archetype), color: isBoss ? const Color(0xFFFF5252) : themeColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              unit.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isBoss)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB71C1C).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.dangerous, size: 10, color: Color(0xFFFFD54F)),
                                  SizedBox(width: 3),
                                  Text(
                                    '☠ PRIMORDIAL BOSS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEnemy
                                    ? const Color(0xFFB3261E).withValues(alpha: 0.25)
                                    : const Color(0xFF2E7D32).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isEnemy ? const Color(0xFFB3261E) : const Color(0xFF2E7D32),
                                ),
                              ),
                              child: Text(
                                isEnemy ? 'ENEMY' : 'ALLY',
                                style: TextStyle(
                                  color: isEnemy ? const Color(0xFFEF5350) : const Color(0xFF81C784),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isBoss
                            ? 'TITANIC LEVEL ${unit.level} • APEX WORLD BEHEMOTH'
                            : _getGenerationTitle(unit.generation),
                        style: TextStyle(
                          color: isBoss ? const Color(0xFFFF8A80) : const Color(0xFFE5A93C),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              unit.isVanguard ? '⚔ FRONTLINE VANGUARD' : '🔮 BACKLINE ARCANUM',
                              style: TextStyle(
                                color: unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              unit.isVanguard ? 'Absorbs Assault (+25% Arm)' : 'Sheltered (Spell Focus)',
                              style: const TextStyle(color: Color(0xFFC5C5D2), fontSize: 9.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Formation Slot: ${unit.slot.name.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                // Character Sheet Parchment Switcher
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showCharacterSheet = !_showCharacterSheet;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: _showCharacterSheet ? const Color(0xFFE5A93C) : const Color(0xFF1E1E28),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _showCharacterSheet ? Colors.white : const Color(0xFFE5A93C),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.style,
                          size: 13,
                          color: _showCharacterSheet ? Colors.black : const Color(0xFFE5A93C),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showCharacterSheet ? 'CLASSIC CODEX' : 'FACTION CARD',
                          style: TextStyle(
                            color: _showCharacterSheet ? Colors.black : const Color(0xFFE5A93C),
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2B2B36), height: 1),

          // Scrollable Content (Classic Codex Fallback)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
                    children: [
                      // Section 0: Grand Portrait Card
                      Center(
                        child: GothicCardFrameWidget(
                          unit: unit,
                          width: 210,
                          height: 280,
                          showStats: false,
                        ),
                      ),
                      const SizedBox(height: 14),

                // Section 0.5: Generational Progression / Boss Combat Vitals
                if (isBoss)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0B0B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF5252),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.dangerous,
                                  color: Color(0xFFFF5252),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'TITANIC COMBAT HEALTH',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${unit.currentHp} / ${unit.maxHp} HP',
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (unit.currentHp / unit.maxHp).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFF2B2B36),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC62828)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Phase 1: Primordial Awakened (${((unit.currentHp / unit.maxHp) * 100).toInt()}%)',
                              style: const TextStyle(
                                color: Color(0xFFFF8A80),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'COLOSSUS DREAD ENGINE',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: unit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF2B2B36),
                      width: unit.isMaxLevel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                unit.isMaxLevel ? Icons.stars : Icons.military_tech,
                                color: unit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF64B5F6),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LEVEL PROGRESSION',
                                style: TextStyle(
                                  color: unit.isMaxLevel ? const Color(0xFFE5A93C) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            unit.isMaxLevel ? 'MAX LEVEL' : 'Lv. ${unit.level}/${unit.maxLevel}',
                            style: TextStyle(
                              color: unit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF64B5F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: unit.xpProgressRatio,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF2B2B36),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF1976D2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            unit.isMaxLevel
                                ? 'Full 10% Parental Stat Transfer Unlocked!'
                                : '${unit.currentXp} / ${unit.xpToNextLevel} XP',
                            style: TextStyle(
                              color: unit.isMaxLevel ? const Color(0xFF81C784) : const Color(0xFF8E8EA0),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            unit.isMaxLevel ? '10% INHERITANCE' : '5% (PREMATURE)',
                            style: TextStyle(
                              color: unit.isMaxLevel ? const Color(0xFFE5A93C) : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (!isEnemy && widget.onLevelUp != null && !unit.isMaxLevel) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFF2B2B36), height: 1),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.water_drop, color: Color(0xFFB3261E), size: 13),
                                SizedBox(width: 4),
                                Text(
                                  'BLOODLINE INFUSION',
                                  style: TextStyle(
                                    color: Color(0xFFE5A93C),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Available: $_currentIchor Ichor',
                              style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfusionButton(
                                label: '+1 LEVEL',
                                cost: unit.ichorCostForNextLevel,
                                onPressed: _currentIchor >= unit.ichorCostForNextLevel
                                    ? () => _handleLevelUp(levels: 1)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildInfusionButton(
                                label: 'MAX LEVEL',
                                cost: unit.ichorCostForMaxLevel,
                                isHighlight: true,
                                onPressed: _currentIchor >= unit.ichorCostForMaxLevel
                                    ? () => _handleMaxLevel()
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildInfusionButton(
                                label: '+100 XP',
                                cost: UnitEntity.xpToIchorCost(min(100, unit.xpNeededForNextLevel)),
                                onPressed: _currentIchor >= UnitEntity.xpToIchorCost(min(100, unit.xpNeededForNextLevel))
                                    ? () => _handleInfuseXp(min(100, unit.xpNeededForNextLevel))
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isEnemy && widget.onLevelUp != null && unit.isMaxLevel && unit.canPromoteRarity) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFF2B2B36), height: 1),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: _buildInfusionButton(
                            label: '★ CONSECRATE RARITY (${unit.rarityLabel.toUpperCase()} ➔ ${unit.nextRarityLabel.toUpperCase()} • +8% STATS)',
                            cost: unit.rarityPromotionIchorCost,
                            isHighlight: true,
                            onPressed: _currentIchor >= unit.rarityPromotionIchorCost
                                ? _handlePromoteRarity
                                : null,
                          ),
                        ),
                      ],
                      if (!isEnemy && widget.onLevelUp != null) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFF2B2B36), height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.layers, color: Color(0xFFE5A93C), size: 13),
                                SizedBox(width: 4),
                                Text(
                                  'CONSECRATE PLINTH PEDESTAL',
                                  style: TextStyle(
                                    color: Color(0xFFE5A93C),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              unit.plinthMaterial.name.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _getPlinthPassiveDescription(unit.plinthMaterial),
                          style: const TextStyle(color: Color(0xFF81C784), fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in [
                              (PlinthMaterial.iron, 'IRON (+15% ARM)', 150),
                              (PlinthMaterial.bone, 'BONE (+25% SIPHON)', 200),
                              (PlinthMaterial.obsidian, 'OBSIDIAN (+10% ATK)', 200),
                              (PlinthMaterial.gold, 'GOLD (+10% ALL)', 350),
                            ])
                              InkWell(
                                onTap: (unit.plinthMaterial != entry.$1 && _currentIchor >= entry.$3)
                                    ? () => _handleSculptPlinth(entry.$1, entry.$3)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: unit.plinthMaterial == entry.$1
                                        ? const Color(0xFFE5A93C).withValues(alpha: 0.25)
                                        : const Color(0xFF22222C),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: unit.plinthMaterial == entry.$1
                                          ? const Color(0xFFFFD54F)
                                          : (_currentIchor >= entry.$3 ? Colors.white24 : Colors.white10),
                                      width: unit.plinthMaterial == entry.$1 ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    unit.plinthMaterial == entry.$1
                                        ? '✓ ${entry.$2}'
                                        : '${entry.$2} (${entry.$3} Ichor)',
                                    style: TextStyle(
                                      color: unit.plinthMaterial == entry.$1
                                          ? const Color(0xFFFFD54F)
                                          : (_currentIchor >= entry.$3 ? Colors.white70 : Colors.white30),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Section 1: Affinity Wheel Matchup
                _buildSectionHeader('HEXAGONAL AFFINITY MATCHUP', Icons.sync_alt),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B2B36)),
                  ),
                  child: Column(
                    children: [
                      HexagonalAffinityWheelWidget(
                        activeArchetype: unit.archetype,
                        size: 190,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_upward, size: 14, color: Color(0xFF81C784)),
                                SizedBox(width: 4),
                                Text(
                                  'PREY (+30% DMG)',
                                  style: TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${prey.name.toUpperCase()} role',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: const Color(0xFF2B2B36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_downward, size: 14, color: Color(0xFFE57373)),
                                SizedBox(width: 4),
                                Text(
                                  'PREDATOR (-25% DMG)',
                                  style: TextStyle(
                                    color: Color(0xFFE57373),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${predator.name.toUpperCase()} role',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

                if (isBoss) ...[
                  const SizedBox(height: 14),
                  _buildSectionHeader('PRIMORDIAL BOSS DREAD MECHANICS', Icons.warning_amber_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0E12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.65), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBossMechanicRow(
                          icon: Icons.shield,
                          title: 'COLOSSAL FORTITUDE',
                          desc: 'Immune to Stun, Sleep, and Turn Meter pushback.',
                          accentColor: const Color(0xFFFF8A80),
                        ),
                        const SizedBox(height: 8),
                        _buildBossMechanicRow(
                          icon: Icons.flash_on,
                          title: 'TECTONIC CLEAVE',
                          desc: 'Strikes multiple units simultaneously with devastating area damage.',
                          accentColor: const Color(0xFFFFD54F),
                        ),
                        const SizedBox(height: 8),
                        _buildBossMechanicRow(
                          icon: Icons.bloodtype,
                          title: 'BLOOD TITHE SURGE',
                          desc: 'Taking critical damage accelerates Boss Ultimate Limit Gauge by 15%.',
                          accentColor: const Color(0xFFFF5252),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Section 2: Core Combat Attributes
                _buildSectionHeader('COMBAT ATTRIBUTES', Icons.bar_chart),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B2B36)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatCell(
                            'HP VITALITY',
                            '${unit.currentHp} / ${unit.effectiveMaxHp}',
                            unit.reviveCount > 0 ? const Color(0xFFFFB74D) : Colors.greenAccent,
                          ),
                          _buildStatCell(
                            'ATTACK POWER',
                            '${unit.attack}${relicBonuses.bonusAttack > 0 ? " (+${relicBonuses.bonusAttack})" : ""}',
                            Colors.redAccent,
                          ),
                          _buildStatCell(
                            'ARMOR (PRR)',
                            '${unit.armor} (${(CombatMath.calculatePrr(unit.armor) * 100).toStringAsFixed(1)}%)',
                            Colors.blueAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell(
                            'RESIST (ERR)',
                            '${unit.resist} (${(CombatMath.calculateErr(unit.resist) * 100).toStringAsFixed(1)}%)',
                            const Color(0xFF80CBC4),
                          ),
                          _buildStatCell(
                            'EFFECTIVE HP',
                            '${unit.ehp.round()} EHP',
                            const Color(0xFFCE93D8),
                          ),
                          _buildStatCell(
                            'INITIATIVE SPEED',
                            '${unit.speed}${relicBonuses.bonusSpeed > 0 ? " (+${relicBonuses.bonusSpeed})" : ""}',
                            Colors.amberAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell(
                            'CRIT CHANCE',
                            '${((unit.critRate + relicBonuses.bonusCritRate) * 100).toInt()}%',
                            Colors.purpleAccent,
                          ),
                          _buildStatCell(
                            'CRIT DAMAGE',
                            '${((unit.critDamage + relicBonuses.bonusCritDamage) * 100).toInt()}%',
                            Colors.orangeAccent,
                          ),
                          _buildStatCell(
                            'TURN METER',
                            '${unit.turnMeter.toInt()}%',
                            Colors.cyanAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell(
                            'SOUL FRACTURE',
                            unit.reviveCount > 0
                                ? '-${(100 - pow(0.80, unit.reviveCount) * 100).round()}% Max HP'
                                : 'NONE (Pristine)',
                            unit.reviveCount > 0 ? const Color(0xFFEF5350) : const Color(0xFF81C784),
                          ),
                          _buildStatCell(
                            'TACTICAL ROLE',
                            unit.isVanguard ? 'VANGUARD (FRONT)' : 'ARCANUM (REAR)',
                            unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                          ),
                          _buildStatCell(
                            'FACTION BLOOD',
                            unit.factionName,
                            const Color(0xFFB39DDB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell(
                            'PLINTH MATERIAL',
                            unit.plinthMaterialTitle,
                            Color(unit.plinthRimBorderColorValue),
                          ),
                          _buildStatCell(
                            'BASE COMPOSITION',
                            unit.plinthMaterial == PlinthMaterial.gold
                                ? '+10% All Core Stats'
                                : (unit.plinthMaterial == PlinthMaterial.obsidian
                                    ? '+10% Crit Multiplier'
                                    : (unit.plinthMaterial == PlinthMaterial.bone
                                        ? '+5% Sanguine Siphon'
                                        : (unit.plinthMaterial == PlinthMaterial.iron
                                            ? '+15% Plated Armor'
                                            : 'Standard Ashen Slate'))),
                            const Color(0xFFE5A93C),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 2.2: Tactical Formation Strategy & Direct Battle Benefits
                _buildSectionHeader('FORMATION STRATEGY & TACTICAL BONUS', Icons.shield_outlined),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: unit.isVanguard ? const Color(0xFFFFD54F).withValues(alpha: 0.6) : const Color(0xFF80D8FF).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          unit.isVanguard ? Icons.shield : Icons.auto_awesome,
                          color: unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  unit.isVanguard ? 'FRONTLINE VANGUARD (DEFENSE AEGIS)' : 'BACKLINE ARCANUM (TACTICAL FOCUS)',
                                  style: TextStyle(
                                    color: unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF)).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    unit.isVanguard ? 'SLOTS 1-3' : 'SLOTS 4-6',
                                    style: TextStyle(
                                      color: unit.isVanguard ? const Color(0xFFFFD54F) : const Color(0xFF80D8FF),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              unit.isVanguard
                                  ? '\u2022 Draws Aggro: Enemy single-target attacks prioritize frontline units first, keeping rear casters safe.\n\u2022 Iron Aegis Synergy: Under General Valeria, gains +25% Armor and reflects 15% physical damage back to attackers.\n\u2022 Direct Clash: Absorbs boss cleaves and melee strikes to guard the backline.'
                                  : '\u2022 Sheltered Position: Completely shielded from enemy single-target strikes while frontline allies stand.\n\u2022 Tactical Focus: Ideal for casting devastating area-of-effect spells, heavy artillery archery, healing, and debilitating blights.\n\u2022 Threat Evasion: Enemy standard AI cannot bypass the vanguard to strike rear units unless specific dive-bomb aerial traits are triggered.',
                              style: const TextStyle(
                                color: Color(0xFFC5C5D2),
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 3: Status Effects (if any)
                if (unit.activeEffects.isNotEmpty) ...[
                  _buildSectionHeader('ACTIVE AFFLICTIONS & WARDS', Icons.warning_amber),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: unit.activeEffects.map((eff) {
                      Color effColor = Colors.grey;
                      IconData effIcon = Icons.circle;
                      if (eff.type == StatusEffectType.bleed) {
                        effColor = const Color(0xFFE53935);
                        effIcon = Icons.water_drop;
                      } else if (eff.type == StatusEffectType.blight) {
                        effColor = const Color(0xFF43A047);
                        effIcon = Icons.bubble_chart;
                      } else if (eff.type == StatusEffectType.stun) {
                        effColor = const Color(0xFFFFB300);
                        effIcon = Icons.flash_on;
                      } else if (eff.type == StatusEffectType.defenseUp) {
                        effColor = const Color(0xFF1E88E5);
                        effIcon = Icons.shield;
                      } else if (eff.type == StatusEffectType.speedUp) {
                        effColor = const Color(0xFF00ACC1);
                        effIcon = Icons.speed;
                      } else if (eff.type == StatusEffectType.burn) {
                        effColor = const Color(0xFFFF6D00);
                        effIcon = Icons.local_fire_department;
                      } else if (eff.type == StatusEffectType.freeze) {
                        effColor = const Color(0xFF00E5FF);
                        effIcon = Icons.ac_unit;
                      } else if (eff.type == StatusEffectType.vulnerable) {
                        effColor = const Color(0xFFFF4081);
                        effIcon = Icons.broken_image;
                      } else if (eff.type == StatusEffectType.shield) {
                        effColor = const Color(0xFFFFD54F);
                        effIcon = Icons.security;
                      } else if (eff.type == StatusEffectType.invulnerable) {
                        effColor = const Color(0xFFFFF59D);
                        effIcon = Icons.shield_outlined;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: effColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: effColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(effIcon, size: 12, color: effColor),
                            const SizedBox(width: 4),
                            Text(
                              '${eff.type.name.toUpperCase()} (${eff.durationTurns} turns)',
                              style: TextStyle(
                                color: effColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Section 4: Skills Arsenal
                _buildSectionHeader('ABILITY ARSENAL & LIMIT BURST', Icons.bolt),
                const SizedBox(height: 8),
                Column(
                  children: unit.resolvedSkills.map((skill) {
                    final bool isUlt = skill.isLimitBurst;
                    final Color skillColor = isUlt ? const Color(0xFFE5A93C) : const Color(0xFF42A5F5);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181820),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUlt ? const Color(0xFFE5A93C).withValues(alpha: 0.6) : const Color(0xFF2B2B36),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: skillColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isUlt ? Icons.star : (skill.cooldownTurns > 0 ? Icons.auto_awesome : Icons.sports_martial_arts),
                              size: 18,
                              color: skillColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      skill.name,
                                      style: TextStyle(
                                        color: skillColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A2A38),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        isUlt
                                            ? 'LIMIT BURST'
                                            : (skill.cooldownTurns > 0 ? '${skill.cooldownTurns}T CD' : 'BASIC'),
                                        style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  skill.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (skill.damageCoefficient > 0)
                                      Text(
                                        'Multiplier: ${skill.damageCoefficient}x ATK • ',
                                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9),
                                      ),
                                    Text(
                                      'Target: ${skill.targetType.name}',
                                      style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Section 5: Equipped Relics & Synergies
                _buildSectionHeader('EQUIPPED RELICS & ACTIVE SYNERGY', Icons.security),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B2B36)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (equippedRelics.isEmpty)
                        const Text(
                          'No relics slotted. Visit the Relic Forge to equip weapons and armor.',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                        )
                      else ...[
                        ...equippedRelics.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(r.slotIcon, size: 14, color: r.rarityColor),
                                const SizedBox(width: 8),
                                Text(
                                  '${r.slot.name.toUpperCase()}: ',
                                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  r.name,
                                  style: TextStyle(color: r.rarityColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (relicBonuses.activeSetBonuses.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Divider(color: Color(0xFF2B2B36), height: 1),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.flash_on, size: 14, color: Color(0xFF81C784)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'SET SYNERGY: ${relicBonuses.activeSetBonuses.map((s) => RelicEntity.setName(s)).join(", ")}',
                                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 6: Ancestral Lineage & Traits
                _buildSectionHeader('ANCESTRAL PEDIGREE & TRAITS', Icons.account_tree),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B2B36)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Native Trait
                      () {
                        final nativeTrait = TraitEntity.getTrait(unit.nativeTraitId);
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: nativeTrait.themeColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: nativeTrait.themeColor.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(nativeTrait.icon, size: 14, color: nativeTrait.themeColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'NATIVE: ${nativeTrait.name.toUpperCase()}',
                                    style: TextStyle(
                                      color: nativeTrait.themeColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                nativeTrait.description,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      }(),
                      const SizedBox(height: 8),

                      // Grafted Trait Socket
                      () {
                        if (unit.graftedTraitId != null) {
                          final graftedTrait = TraitEntity.getTrait(unit.graftedTraitId!);
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF81C784).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.6)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(graftedTrait.icon, size: 14, color: const Color(0xFF81C784)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'GRAFTED: ${graftedTrait.name.toUpperCase()}',
                                      style: const TextStyle(
                                        color: Color(0xFF81C784),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  graftedTrait.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131318),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 14, color: Colors.white38),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'GRAFT SOCKET EMPTY • Fuse in Crucible to bind a progenitor\'s trait',
                                    style: TextStyle(color: Colors.white38, fontSize: 9.5, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }(),
                      const SizedBox(height: 10),
                      if (unit.isPureblood) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3E0A0A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF1744).withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PUREBLOOD SOVEREIGNTY ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Compounded across 4 generations. Bestows +15% Pureblood resonance across all attributes with level cap extended to Lv. 50.',
                                      style: TextStyle(color: Colors.white70, fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(color: Color(0xFF2B2B36), height: 1),
                      const SizedBox(height: 8),
                      if (unit.verifiedLineageTags.isNotEmpty) ...[
                        const Text(
                          'VERIFIED LINEAGE BLOODLINES',
                          style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: unit.verifiedLineageTags.map((tag) {
                            final Color badgeColor = tag == 'Beastline'
                                ? const Color(0xFFFB8C00)
                                : (tag == 'Deathless'
                                    ? const Color(0xFF7E57C2)
                                    : const Color(0xFFE5A93C));
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tag == 'Beastline'
                                        ? Icons.pets
                                        : (tag == 'Deathless' ? Icons.brightness_3 : Icons.shield),
                                    size: 10,
                                    color: badgeColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag.toUpperCase(),
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Text(
                        'BLOODLINE PROGENITORS',
                        style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (unit.lineageAncestors.isEmpty)
                        const Text(
                          'Primordial Stock (First Generation Feral Thrall)',
                          style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: unit.lineageAncestors.map((ancestor) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.subdirectory_arrow_right, size: 12, color: Color(0xFFE5A93C)),
                                  const SizedBox(width: 4),
                                  Text(
                                    ancestor,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFB3261E)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE5A93C),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildBossMechanicRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: accentColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFFC5C5D2),
                  fontSize: 9.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
