import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../features/relics/relic_service.dart';
import '../models/relic_entity.dart';
import '../models/skill_entity.dart';
import '../models/unit_entity.dart';

class PedigreeInspectorDialog extends StatelessWidget {
  final UnitEntity unit;
  final bool isEnemy;
  final RelicService? relicService;

  const PedigreeInspectorDialog({
    super.key,
    required this.unit,
    this.isEnemy = false,
    this.relicService,
  });

  static Future<void> show(
    BuildContext context,
    UnitEntity unit, {
    bool isEnemy = false,
    RelicService? relicService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PedigreeInspectorDialog(
        unit: unit,
        isEnemy: isEnemy,
        relicService: relicService,
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
    final themeColor = _getArchetypeColor(unit.archetype);
    final prey = CombatMath.getPreyArchetype(unit.archetype);
    final predator = CombatMath.getPredatorArchetype(unit.archetype);

    final equippedRelics = relicService?.getRelicsForUnit(unit.id) ?? const <RelicEntity>[];
    final relicBonuses = relicService?.calculateBonuses(unit.id) ?? const UnitRelicBonuses();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: const Color(0xFFB3261E), width: 1.5),
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
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: themeColor, width: 1.5),
                  ),
                  child: Icon(_getArchetypeIcon(unit.archetype), color: themeColor, size: 28),
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
                        _getGenerationTitle(unit.generation),
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Formation: ${unit.isVanguard ? "Frontline Vanguard" : "Backline Arcanum"} • Slot: ${unit.slot.name.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10),
                      ),
                    ],
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

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                  child: Row(
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
                ),

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
                          _buildStatCell('HP VITALITY', '${unit.currentHp} / ${unit.maxHp}', Colors.greenAccent),
                          _buildStatCell('ATTACK POWER', '${unit.attack}${relicBonuses.bonusAttack > 0 ? " (+${relicBonuses.bonusAttack})" : ""}', Colors.redAccent),
                          _buildStatCell('ARMOR DEFENSE', '${unit.defense}${relicBonuses.bonusDefense > 0 ? " (+${relicBonuses.bonusDefense})" : ""}', Colors.blueAccent),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell('INITIATIVE SPEED', '${unit.speed}${relicBonuses.bonusSpeed > 0 ? " (+${relicBonuses.bonusSpeed})" : ""}', Colors.amberAccent),
                          _buildStatCell('CRIT CHANCE', '${((unit.critRate + relicBonuses.bonusCritRate) * 100).toInt()}%', Colors.purpleAccent),
                          _buildStatCell('CRIT DAMAGE', '${((unit.critDamage + relicBonuses.bonusCritDamage) * 100).toInt()}%', Colors.orangeAccent),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCell('TURN METER', '${unit.turnMeter.toInt()}%', Colors.cyanAccent),
                          _buildStatCell('ULTIMATE GAUGE', '${unit.ultimateCharge.toInt()}%', const Color(0xFFE5A93C)),
                          _buildStatCell('LEVEL CAP', 'Lv. ${unit.level} / ${unit.maxLevel}', Colors.white70),
                        ],
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
                      Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 14, color: Color(0xFFE5A93C)),
                          const SizedBox(width: 6),
                          const Text(
                            'NATIVE TRAIT: ',
                            style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            unit.nativeTraitId.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 14, color: Color(0xFF81C784)),
                          const SizedBox(width: 6),
                          const Text(
                            'GRAFTED TRAIT: ',
                            style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            unit.graftedTraitId != null
                                ? unit.graftedTraitId!.replaceAll('_', ' ').toUpperCase()
                                : 'NONE (SOCKET AVAILABLE IN CRUCIBLE)',
                            style: TextStyle(
                              color: unit.graftedTraitId != null ? const Color(0xFF81C784) : Colors.white30,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFF2B2B36), height: 1),
                      const SizedBox(height: 8),
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
}
