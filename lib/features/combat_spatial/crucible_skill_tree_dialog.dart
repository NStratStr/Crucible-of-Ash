import 'package:flutter/material.dart';
import 'models/crucible_skill_tree_models.dart';
import 'spatial_combat_engine.dart';
import '../generals/general_command_service.dart';

class CrucibleSkillTreeDialog extends StatefulWidget {
  final SpatialCombatEngine engine;

  const CrucibleSkillTreeDialog({
    super.key,
    required this.engine,
  });

  static Future<void> show(BuildContext context, SpatialCombatEngine engine) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrucibleSkillTreeDialog(engine: engine),
    );
  }

  @override
  State<CrucibleSkillTreeDialog> createState() => _CrucibleSkillTreeDialogState();
}

class _CrucibleSkillTreeDialogState extends State<CrucibleSkillTreeDialog> {
  CrucibleSkillDiscipline _selectedDiscipline = CrucibleSkillDiscipline.ash;
  String? _selectedSkillId;

  @override
  void initState() {
    super.initState();
    // Default selected discipline to active general's primary discipline
    final gen = widget.engine.activeGeneralType;
    switch (gen) {
      case GeneralType.valeria:
        _selectedDiscipline = CrucibleSkillDiscipline.iron;
        _selectedSkillId = 'iron_slam';
        break;
      case GeneralType.vladislav:
        _selectedDiscipline = CrucibleSkillDiscipline.sanguine;
        _selectedSkillId = 'sanguine_rend';
        break;
      case GeneralType.morrigan:
        _selectedDiscipline = CrucibleSkillDiscipline.mire;
        _selectedSkillId = 'mire_touch';
        break;
      case GeneralType.malakor:
        _selectedDiscipline = CrucibleSkillDiscipline.ash;
        _selectedSkillId = 'ash_cleave';
        break;
    }
  }

  Color _getDisciplineColor(CrucibleSkillDiscipline d) {
    switch (d) {
      case CrucibleSkillDiscipline.ash:
        return const Color(0xFFFF6D00);
      case CrucibleSkillDiscipline.iron:
        return const Color(0xFFFFD54F);
      case CrucibleSkillDiscipline.sanguine:
        return const Color(0xFFFF1744);
      case CrucibleSkillDiscipline.mire:
        return const Color(0xFF00E676);
    }
  }

  String _getDisciplineTitle(CrucibleSkillDiscipline d) {
    switch (d) {
      case CrucibleSkillDiscipline.ash:
        return 'ASH & PYRE';
      case CrucibleSkillDiscipline.iron:
        return 'COLD IRON';
      case CrucibleSkillDiscipline.sanguine:
        return 'SANGUINE TITHE';
      case CrucibleSkillDiscipline.mire:
        return 'MIRE OCCULT';
    }
  }

  IconData _getDisciplineIcon(CrucibleSkillDiscipline d) {
    switch (d) {
      case CrucibleSkillDiscipline.ash:
        return Icons.local_fire_department;
      case CrucibleSkillDiscipline.iron:
        return Icons.shield;
      case CrucibleSkillDiscipline.sanguine:
        return Icons.bloodtype;
      case CrucibleSkillDiscipline.mire:
        return Icons.eco;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.engine.skillTreeState;
    final skillsInDiscipline = state.getSkillsForDiscipline(_selectedDiscipline);
    final selectedSkill = _selectedSkillId != null ? state.allSkills[_selectedSkillId] : skillsInDiscipline.firstOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 820,
        height: 600,
        decoration: BoxDecoration(
          color: const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _getDisciplineColor(_selectedDiscipline).withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(state),

            // 5 Equipped Slots Bar
            _buildEquippedSlotsRow(state),

            // Discipline Tabs
            _buildDisciplineTabs(),

            // Main Body: Skill Tree Pathway (Left) + Skill Inspector (Right)
            Expanded(
              child: Row(
                children: [
                  // Left: Discipline Skills Pathway
                  Expanded(
                    flex: 5,
                    child: _buildSkillTreeGrid(skillsInDiscipline, state),
                  ),

                  // Divider
                  Container(width: 1, color: Colors.white12),

                  // Right: Skill Detail Inspector & Upgrade / Equip Panel
                  Expanded(
                    flex: 4,
                    child: _buildSkillDetailInspector(selectedSkill, state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CrucibleSkillTreeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: _getDisciplineColor(_selectedDiscipline), size: 20),
          const SizedBox(width: 8),
          const Text(
            'CRUCIBLE SKILL GRIMOIRE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD54F),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 14),
                const SizedBox(width: 5),
                Text(
                  'SKILL POINTS: ${state.availableSkillPoints}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedSlotsRow(CrucibleSkillTreeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E14),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Text(
            'ACTIVE LOADOUT (5 SKILLS):',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white60,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(5, (slotIdx) {
                final skill = state.getSkillInSlot(slotIdx);
                final bool isSelected = skill != null && skill.id == _selectedSkillId;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: skill != null ? skill.primaryColor.withValues(alpha: 0.15) : const Color(0xFF1A1C24),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD54F)
                            : (skill != null ? skill.borderColor.withValues(alpha: 0.6) : Colors.white12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (skill != null) {
                          setState(() {
                            _selectedSkillId = skill.id;
                            _selectedDiscipline = skill.discipline;
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${slotIdx + 1}',
                              style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (skill != null) ...[
                            Icon(skill.icon, size: 13, color: skill.borderColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    skill.name,
                                    style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${skill.cinderCost}🔥 • Rank ${skill.rank}',
                                    style: TextStyle(fontSize: 7.0, color: skill.borderColor),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            const Expanded(
                              child: Text(
                                'EMPTY',
                                style: TextStyle(fontSize: 8.0, color: Colors.white24, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineTabs() {
    return Container(
      color: const Color(0xFF141720),
      child: Row(
        children: CrucibleSkillDiscipline.values.map((disc) {
          final isSelected = disc == _selectedDiscipline;
          final color = _getDisciplineColor(disc);

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDiscipline = disc;
                  final skills = widget.engine.skillTreeState.getSkillsForDiscipline(disc);
                  _selectedSkillId = skills.firstOrNull?.id;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? color : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getDisciplineIcon(disc), size: 14, color: isSelected ? color : Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      _getDisciplineTitle(disc),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? color : Colors.white60,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillTreeGrid(List<CrucibleSkillNode> skills, CrucibleSkillTreeState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        final isSelected = skill.id == _selectedSkillId;
        final isEquipped = state.equippedSkillIds.contains(skill.id);
        final slotNumber = state.equippedSkillIds.indexOf(skill.id) + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? skill.primaryColor.withValues(alpha: 0.20) : const Color(0xFF181B26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD54F)
                  : (isEquipped ? skill.borderColor : Colors.white12),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            onTap: () {
              setState(() {
                _selectedSkillId = skill.id;
              });
            },
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: skill.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: skill.borderColor, width: 1),
                  ),
                  child: Icon(skill.icon, color: Colors.white, size: 20),
                ),
                if (isEquipped)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD54F),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$slotNumber',
                        style: const TextStyle(fontSize: 8.0, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${skill.cinderCost} Cinders',
                    style: const TextStyle(fontSize: 8.5, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: skill.rank >= skill.maxRank ? const Color(0xFF00C853) : const Color(0xFF37474F),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Rank ${skill.rank}/${skill.maxRank}',
                    style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              skill.summary,
              style: const TextStyle(fontSize: 9.5, color: Colors.white60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkillDetailInspector(CrucibleSkillNode? skill, CrucibleSkillTreeState state) {
    if (skill == null) {
      return const Center(
        child: Text(
          'Select a skill to inspect its upgrades and equip it into your active 5-slot loadout.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isEquipped = state.equippedSkillIds.contains(skill.id);
    final currentSlot = state.equippedSkillIds.indexOf(skill.id) + 1;

    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF13151F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill Title & Cost
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: skill.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: skill.borderColor, width: 1.2),
                ),
                child: Icon(skill.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      'Cost: ${skill.cinderCost} Cinders • Discipline: ${_getDisciplineTitle(skill.discipline)}',
                      style: TextStyle(fontSize: 9.5, color: skill.borderColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            skill.summary,
            style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
          ),

          const SizedBox(height: 14),
          const Text(
            'UPGRADE TIERS (RANK PROGRESSION):',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),

          // Upgrade Ranks List
          Expanded(
            child: ListView.builder(
              itemCount: skill.rankDescriptions.length,
              itemBuilder: (context, idx) {
                final tierNum = idx + 1;
                final isCurrent = skill.rank == tierNum;
                final isUnlocked = skill.rank >= tierNum;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? skill.primaryColor.withValues(alpha: 0.15)
                        : (isUnlocked ? const Color(0xFF1A1D28) : const Color(0xFF12141A)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCurrent ? skill.borderColor : (isUnlocked ? Colors.white24 : Colors.white10),
                      width: isCurrent ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isUnlocked ? Icons.check_circle : Icons.lock_outline,
                        size: 13,
                        color: isUnlocked ? const Color(0xFF00E676) : Colors.white24,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          skill.rankDescriptions[idx],
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isUnlocked ? Colors.white : Colors.white38,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Action Buttons: Upgrade Rank & Equip to Slots 1..5
          Row(
            children: [
              // Upgrade Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: skill.canUpgrade && state.availableSkillPoints > 0
                          ? const Color(0xFFFF6D00)
                          : const Color(0xFF263238),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: skill.canUpgrade && state.availableSkillPoints > 0
                        ? () {
                            setState(() {
                              state.upgradeSkill(skill.id);
                            });
                          }
                        : null,
                    child: Text(
                      skill.canUpgrade
                          ? 'UPGRADE (1 SP) [Rank ${skill.rank + 1}]'
                          : 'MAX RANK REACHED',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Equip to Slots 1..5
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF181B26),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Text(
                  isEquipped ? 'EQUIPPED IN SLOT $currentSlot' : 'EQUIP TO SLOT:',
                  style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const Spacer(),
                Wrap(
                  spacing: 4,
                  children: List.generate(5, (slotIdx) {
                    final isThisSlot = isEquipped && (currentSlot - 1) == slotIdx;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          state.equipSkill(slotIdx, skill.id);
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isThisSlot ? const Color(0xFFFFD54F) : const Color(0xFF263238),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: isThisSlot ? Colors.black : Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${slotIdx + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isThisSlot ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
