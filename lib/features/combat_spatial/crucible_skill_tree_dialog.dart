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
  CrucibleSkillBranch _selectedBranch = CrucibleSkillBranch.wrath;
  String? _selectedSkillId;

  @override
  void initState() {
    super.initState();
    _selectedSkillId = 'ash_cleave';
  }

  Color _getBranchColor(CrucibleSkillBranch b) {
    switch (b) {
      case CrucibleSkillBranch.wrath:
        return const Color(0xFFFF5252); // Crimson / Fire
      case CrucibleSkillBranch.bastion:
        return const Color(0xFF00E5FF); // Cyan / Cold Iron / Shield
      case CrucibleSkillBranch.resonance:
        return const Color(0xFFE040FB); // Amethyst / Blood / Hybrid
      case CrucibleSkillBranch.vitae:
        return const Color(0xFF00E676); // Emerald / Life Vitae
      case CrucibleSkillBranch.calamity:
        return const Color(0xFFFF9100); // Amber / Volcanic Calamity
      case CrucibleSkillBranch.apex:
        return const Color(0xFFFFD54F); // Molten Gold
    }
  }

  String _getBranchTitle(CrucibleSkillBranch b) {
    switch (b) {
      case CrucibleSkillBranch.wrath:
        return 'PATH OF WRATH (ATTACK)';
      case CrucibleSkillBranch.bastion:
        return 'PATH OF BASTION (DEFENSE)';
      case CrucibleSkillBranch.resonance:
        return 'PATH OF RESONANCE (HYBRID)';
      case CrucibleSkillBranch.vitae:
        return 'PATH OF VITAE (HEALING)';
      case CrucibleSkillBranch.calamity:
        return 'PATH OF CALAMITY (AOE)';
      case CrucibleSkillBranch.apex:
        return 'APEX FINISHERS (CROWN)';
    }
  }

  IconData _getBranchIcon(CrucibleSkillBranch b) {
    switch (b) {
      case CrucibleSkillBranch.wrath:
        return Icons.sports_mma;
      case CrucibleSkillBranch.bastion:
        return Icons.security;
      case CrucibleSkillBranch.resonance:
        return Icons.all_inclusive;
      case CrucibleSkillBranch.vitae:
        return Icons.favorite;
      case CrucibleSkillBranch.calamity:
        return Icons.waves;
      case CrucibleSkillBranch.apex:
        return Icons.bolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.engine.skillTreeState;
    final skillsInBranch = state.getSkillsForBranch(_selectedBranch);
    final selectedSkill = _selectedSkillId != null ? state.allSkills[_selectedSkillId] : skillsInBranch.firstOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 860,
        height: 620,
        decoration: BoxDecoration(
          color: const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _getBranchColor(_selectedBranch).withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _getBranchColor(_selectedBranch).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(color: Colors.black87, blurRadius: 24),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(state),

            // 5 Equipped Slots Bar
            _buildEquippedSlotsRow(state),

            // 3-Branch Archetype Tabs + Crown Apex
            _buildBranchTabs(state),

            // Main Body: Branch Pathway & Keystone (Left) + Skill Inspector (Right)
            Expanded(
              child: Row(
                children: [
                  // Left: Branch Skills & Keystone Card
                  Expanded(
                    flex: 5,
                    child: _buildBranchSkillPathway(skillsInBranch, state),
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
      decoration: const BoxDecoration(
        color: Color(0xFF161822),
        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: _getBranchColor(_selectedBranch), size: 20),
          const SizedBox(width: 8),
          const Text(
            'CRUCIBLE ARCHETYPE SKILL GRIMOIRE',
            style: TextStyle(
              fontSize: 13,
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
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F),
              foregroundColor: const Color(0xFFFFD54F),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFFFD54F), width: 0.8),
              ),
            ),
            icon: const Icon(Icons.restart_alt, size: 13, color: Color(0xFFFFD54F)),
            label: const Text(
              'RESPEC (RESET)',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: () {
              setState(() {
                state.respecAllPoints();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Crucible points refunded! Rebuild your archetype freely.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
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
            'ACTIVE TRAY (5 SLOTS):',
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
                            _selectedBranch = skill.branch;
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
                                    '${skill.cinderCost}🔥 • R${skill.rank}',
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

  Widget _buildBranchTabs(CrucibleSkillTreeState state) {
    return Container(
      color: const Color(0xFF141720),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: CrucibleSkillBranch.values.map((branch) {
            final isSelected = branch == _selectedBranch;
            final color = _getBranchColor(branch);
            final pointsSpent = state.getPointsSpentInBranch(branch);

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedBranch = branch;
                  final skills = state.getSkillsForBranch(branch);
                  _selectedSkillId = skills.firstOrNull?.id;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getBranchIcon(branch), size: 14, color: isSelected ? color : Colors.white54),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getBranchTitle(branch),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? color : Colors.white60,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (branch != CrucibleSkillBranch.apex)
                          Text(
                            '$pointsSpent pts invested',
                            style: TextStyle(
                              fontSize: 7.5,
                              color: pointsSpent >= 3 ? const Color(0xFFFFD54F) : Colors.white38,
                              fontWeight: pointsSpent >= 3 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBranchSkillPathway(List<CrucibleSkillNode> skills, CrucibleSkillTreeState state) {
    Widget? keystoneWidget;

    if (_selectedBranch == CrucibleSkillBranch.wrath) {
      final bool isActive = state.isMoltenOverdriveActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'MOLTEN OVERDRIVE (KEYSTONE)',
        summary: 'Slaying any enemy grants the Ash Sculptor +15 Cinders and refunds +2,500 AP tempo.',
        pointsRequired: 3,
        currentPoints: state.wrathPointsSpent,
        isActive: isActive,
        color: const Color(0xFFFF5252),
        icon: Icons.local_fire_department,
      );
    } else if (_selectedBranch == CrucibleSkillBranch.bastion) {
      final bool isActive = state.isSlagFortressActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'SLAG FORTRESS (KEYSTONE)',
        summary: 'While at least 1 minion is alive, all incoming squad damage is reduced by 20% and Aegis shields do not decay.',
        pointsRequired: 3,
        currentPoints: state.bastionPointsSpent,
        isActive: isActive,
        color: const Color(0xFF00E5FF),
        icon: Icons.shield,
      );
    } else if (_selectedBranch == CrucibleSkillBranch.resonance) {
      final bool isActive = state.isCrucibleSymbiosisActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'CRUCIBLE SYMBIOSIS (KEYSTONE)',
        summary: 'Whenever a retinue companion attacks or uses a skill, they channel +3 bonus Cinders to the Sculptor.',
        pointsRequired: 3,
        currentPoints: state.resonancePointsSpent,
        isActive: isActive,
        color: const Color(0xFFE040FB),
        icon: Icons.all_inclusive,
      );
    } else if (_selectedBranch == CrucibleSkillBranch.vitae) {
      final bool isActive = state.isFontOfRebirthActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'FONT OF REBIRTH (KEYSTONE)',
        summary: 'Spending Cinders radiates holy healing to squad (12% Max HP). All overhealing converts directly into Aegis Shield.',
        pointsRequired: 3,
        currentPoints: state.vitaePointsSpent,
        isActive: isActive,
        color: const Color(0xFF00E676),
        icon: Icons.favorite,
      );
    } else if (_selectedBranch == CrucibleSkillBranch.calamity) {
      final bool isActive = state.isSeismicCataclysmActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'SEISMIC CATACLYSM (KEYSTONE)',
        summary: 'All Commander skills hit +1 extra adjacent tile. Striking 3+ enemies on a single cast instantly refunds +20 Cinders & +2,000 AP tempo.',
        pointsRequired: 3,
        currentPoints: state.calamityPointsSpent,
        isActive: isActive,
        color: const Color(0xFFFF9100),
        icon: Icons.filter_hdr,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (keystoneWidget != null) ...[
          keystoneWidget,
          const SizedBox(height: 10),
        ],
        ...skills.map((skill) {
          final isSelected = skill.id == _selectedSkillId;
          final isEquipped = state.equippedSkillIds.contains(skill.id);
          final slotNumber = state.equippedSkillIds.indexOf(skill.id) + 1;
          final isPrereqMet = state.isSkillPrerequisiteMet(skill.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? skill.primaryColor.withValues(alpha: 0.20)
                  : (isPrereqMet ? const Color(0xFF181B26) : const Color(0xFF11131A)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFFD54F)
                    : (isEquipped ? skill.borderColor : (isPrereqMet ? Colors.white12 : Colors.white10)),
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
                      color: isPrereqMet ? skill.primaryColor : const Color(0xFF263238),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPrereqMet ? skill.borderColor : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isPrereqMet ? skill.icon : Icons.lock_outline,
                      color: isPrereqMet ? Colors.white : Colors.white38,
                      size: 20,
                    ),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPrereqMet ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isPrereqMet
                          ? (skill.tier == 1 ? const Color(0xFF1B5E20) : const Color(0xFF0D47A1))
                          : const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      isPrereqMet ? 'TIER ${skill.tier}' : '🔒 TIER ${skill.tier}',
                      style: const TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF263238),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${skill.cinderCost}🔥 • ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s CD',
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
                isPrereqMet ? skill.summary : '🔒 ${state.getPrerequisiteRequirementText(skill.id)}',
                style: TextStyle(
                  fontSize: 9.0,
                  color: isPrereqMet ? Colors.white60 : const Color(0xFFFF8A80),
                  fontWeight: isPrereqMet ? FontWeight.normal : FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildKeystoneCard({
    required String title,
    required String summary,
    required int pointsRequired,
    required int currentPoints,
    required bool isActive,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : const Color(0xFF14121A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? color : Colors.white24,
          width: isActive ? 1.4 : 0.8,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isActive ? color : Colors.white38, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: isActive ? Colors.white : Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isActive ? color : const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isActive ? '⚡ KEYSTONE UNLOCKED' : '🔒 REQUIRES $pointsRequired PTS ($currentPoints/$pointsRequired)',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: isActive ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: isActive ? Colors.white70 : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                      'Cost: ${skill.cinderCost}🔥 • CD: ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s • Branch: ${_getBranchTitle(skill.branch)}',
                      style: TextStyle(fontSize: 9.0, color: skill.borderColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            skill.summary,
            style: const TextStyle(fontSize: 10.5, color: Colors.white70, height: 1.3),
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
                            fontSize: 9.0,
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

          if (!state.isSkillPrerequisiteMet(skill.id)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF371717),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFF5252), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 14, color: Color(0xFFFF5252)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.getPrerequisiteRequirementText(skill.id),
                      style: const TextStyle(fontSize: 8.5, color: Color(0xFFFF8A80), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons: Upgrade Rank & Equip to Slots 1..5
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.canUpgradeSkill(skill.id)
                          ? const Color(0xFFFF6D00)
                          : const Color(0xFF263238),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: state.canUpgradeSkill(skill.id)
                        ? () {
                            setState(() {
                              state.upgradeSkill(skill.id);
                            });
                          }
                        : null,
                    child: Text(
                      !state.isSkillPrerequisiteMet(skill.id)
                          ? '🔒 LOCKED (PREREQUISITES NOT MET)'
                          : (skill.canUpgrade
                              ? 'UPGRADE (1 SP) [Rank ${skill.rank + 1}]'
                              : 'MAX RANK REACHED'),
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
