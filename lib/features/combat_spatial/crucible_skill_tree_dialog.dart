import 'package:flutter/material.dart';
import 'models/crucible_skill_tree_models.dart';
import 'spatial_combat_engine.dart';
import 'dialogs/crucible_debug_sandbox_dialog.dart';

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
    final state = widget.engine.skillTreeState;
    final unlocked = state.allSkills.values.where((s) => s.isUnlocked).toList();
    final visibleBranches = state.visibleBranchesForActiveClass;
    if (state.availableSkillPoints > 0 && unlocked.length <= 1 && unlocked.isNotEmpty) {
      _selectedBranch = visibleBranches.contains(unlocked.first.branch)
          ? unlocked.first.branch
          : visibleBranches.first;
      final branchSkills = state.getSkillsForBranch(_selectedBranch);
      final nextUnlockable = branchSkills.where((s) => !s.isUnlocked && state.canUpgradeSkill(s.id)).firstOrNull;
      _selectedSkillId = nextUnlockable?.id ?? unlocked.first.id;
    } else {
      if (!visibleBranches.contains(_selectedBranch) && visibleBranches.isNotEmpty) {
        _selectedBranch = visibleBranches.first;
      }
      final branchSkills = state.getSkillsForBranch(_selectedBranch);
      _selectedSkillId = unlocked.isNotEmpty ? unlocked.first.id : (branchSkills.firstOrNull?.id ?? 'ash_cleave');
    }
  }

  bool _isFirstSkillTutorial(CrucibleSkillTreeState state) {
    return state.availableSkillPoints > 0 &&
        state.allSkills.values.where((s) => s.isUnlocked).length <= 1;
  }

  Color _getBranchColor(CrucibleSkillBranch b) {
    switch (b) {
      case CrucibleSkillBranch.wrath:
        return const Color(0xFFFF5252); // Crimson / Fire
      case CrucibleSkillBranch.bastion:
        return const Color(0xFF00E5FF); // Cyan / Cold Iron / Shield
      case CrucibleSkillBranch.resonance:
        return const Color(0xFFE040FB); // Amethyst / Sanguine Drain
      case CrucibleSkillBranch.miasma:
        return const Color(0xFF69F0AE); // Virulent Emerald / Plague AoE
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
        return 'WRATH (ATK)';
      case CrucibleSkillBranch.bastion:
        return 'BASTION (DEF)';
      case CrucibleSkillBranch.resonance:
        return 'SANGUINE (DRAIN)';
      case CrucibleSkillBranch.miasma:
        return 'MIASMA (AOE)';
      case CrucibleSkillBranch.vitae:
        return 'VITAE (HEAL)';
      case CrucibleSkillBranch.calamity:
        return 'CALAMITY (AOE)';
      case CrucibleSkillBranch.apex:
        return 'APEX (ULT)';
    }
  }

  IconData _getBranchIcon(CrucibleSkillBranch b) {
    switch (b) {
      case CrucibleSkillBranch.wrath:
        return Icons.sports_mma;
      case CrucibleSkillBranch.bastion:
        return Icons.security;
      case CrucibleSkillBranch.resonance:
        return Icons.bloodtype;
      case CrucibleSkillBranch.miasma:
        return Icons.coronavirus;
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

            if (_isFirstSkillTutorial(state))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10241C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF69F0AE), width: 1.2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Color(0xFF69F0AE), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TUTORIAL: Select a glowing skill below and click [UPGRADE (1 SP)] on the right to unlock & equip your 2nd Skill Slot!',
                        style: TextStyle(
                          color: Color(0xFF69F0AE),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 3-Branch Archetype Tabs + Crown Apex
            _buildBranchTabs(state),

            // Main Body: Branch Pathway & Keystone + Skill Inspector (responsive for mobile)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isCompact = constraints.maxWidth < 640;
                  if (isCompact) {
                    return Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildBranchSkillPathway(skillsInBranch, state),
                        ),
                        Container(height: 1, color: Colors.white12),
                        Expanded(
                          flex: 4,
                          child: _buildSkillDetailInspector(selectedSkill, state),
                        ),
                      ],
                    );
                  }
                  return Row(
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
                  );
                },
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
          Icon(Icons.account_tree, color: _getBranchColor(_selectedBranch), size: 18),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'CRUCIBLE ARCHETYPE SKILL GRIMOIRE',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD54F),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1A222D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45), width: 1),
            ),
            child: Text(
              'LV.${state.sculptorLevel} (${state.sculptorXp}/${state.xpToNextLevel} XP) • CASTLE T${state.castleCrucibleTier}',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Colors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF263238),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 13),
                const SizedBox(width: 4),
                Text(
                  'SP: ${state.availableSkillPoints}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF37474F),
              foregroundColor: const Color(0xFFFFD54F),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFFFD54F), width: 0.8),
              ),
            ),
            icon: const Icon(Icons.restart_alt, size: 13, color: Color(0xFFFFD54F)),
            label: const Text(
              'RESPEC',
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
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF261D12),
              foregroundColor: const Color(0xFFFFD54F),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFFFFD54F), width: 0.8),
              ),
            ),
            icon: const Icon(Icons.build_circle, size: 13, color: Color(0xFFFFD54F)),
            label: const Text(
              'DEV TOOLS',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: () {
              CrucibleDebugSandboxDialog.show(
                context,
                engine: widget.engine,
                onStateChanged: () => setState(() {}),
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
                            _buildSkillVisualIcon(skill, size: 22),
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
          children: state.visibleBranchesForActiveClass.map((branch) {
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

  Widget _buildSkillVisualIcon(CrucibleSkillNode skill, {double size = 24, bool isLocked = false}) {
    if (skill.iconAsset != null) {
      return Opacity(
        opacity: isLocked ? 0.35 : 1.0,
        child: Image.asset(
          skill.iconAsset!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            isLocked ? Icons.lock_outline : skill.icon,
            color: isLocked ? Colors.white38 : Colors.white,
            size: size * 0.65,
          ),
        ),
      );
    }
    return Icon(
      isLocked ? Icons.lock_outline : skill.icon,
      color: isLocked ? Colors.white38 : Colors.white,
      size: size * 0.65,
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
        iconAsset: 'assets/images/icons/skills/icon_keystone_anvil_sunder.png',
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
        iconAsset: 'assets/images/icons/skills/icon_keystone_unyielding_strata.png',
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
        iconAsset: 'assets/images/icons/skills/icon_keystone_resonant_crucible.png',
      );
    } else if (_selectedBranch == CrucibleSkillBranch.miasma) {
      final bool isActive = state.isPlagueContagionActive;
      keystoneWidget = _buildKeystoneCard(
        title: 'PLAGUE CONTAGION (KEYSTONE)',
        summary: 'AoE & Blight skills inflict +1 extra Bleed & Poison on every hit enemy. Hitting 2+ foes on a single cast refunds +15 Cinders & heals 8% Max HP.',
        pointsRequired: 3,
        currentPoints: state.miasmaPointsSpent,
        isActive: isActive,
        color: const Color(0xFF69F0AE),
        icon: Icons.coronavirus,
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
        iconAsset: 'assets/images/icons/skills/icon_keystone_font_rebirth.png',
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

    int? lastTier;
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
          final isTutorialTarget = _isFirstSkillTutorial(state) && !skill.isUnlocked && state.canUpgradeSkill(skill.id);
          final bool showTierHeader = lastTier != skill.tier;
          lastTier = skill.tier;
          final prereqNode = skill.prerequisiteSkillId != null ? state.allSkills[skill.prerequisiteSkillId] : null;
          final int minPrereqRank = skill.tier <= 2 ? 1 : 2;
          final bool prereqNodeMet = prereqNode != null && prereqNode.rank >= minPrereqRank;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTierHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        skill.tier == 1
                            ? 'TIER 1 • FOUNDATION & PASSIVES'
                            : (skill.tier == 2
                                ? 'TIER 2 • SPECIALIZATION'
                                : (skill.tier == 3 ? 'TIER 3 • MASTERY' : 'TIER 4 • APEX CROWN')),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider(color: Colors.white12, height: 1)),
                    ],
                  ),
                ),
              if (prereqNode != null)
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right,
                        size: 14,
                        color: prereqNodeMet ? const Color(0xFF69F0AE) : const Color(0xFFFFB74D),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Path from ${prereqNode.name} (Rank $minPrereqRank+)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: prereqNodeMet ? const Color(0xFF69F0AE) : const Color(0xFFFFB74D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? skill.primaryColor.withValues(alpha: 0.20)
                      : (isTutorialTarget
                          ? const Color(0xFF13261E)
                          : (isPrereqMet ? const Color(0xFF181B26) : const Color(0xFF11131A))),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD54F)
                        : (isTutorialTarget
                        ? const Color(0xFF69F0AE)
                        : (isEquipped ? skill.borderColor : (isPrereqMet ? Colors.white12 : Colors.white10))),
                width: (isSelected || isTutorialTarget) ? 1.6 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: skill.iconAsset != null
                          ? Colors.transparent
                          : (isPrereqMet ? skill.primaryColor : const Color(0xFF263238)),
                      borderRadius: BorderRadius.circular(6),
                      border: skill.iconAsset != null
                          ? null
                          : Border.all(
                              color: isPrereqMet ? skill.borderColor : Colors.white24,
                              width: 1,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: _buildSkillVisualIcon(skill, size: 38, isLocked: !isPrereqMet),
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
                      skill.isPassive
                          ? 'PASSIVE • ALWAYS ACTIVE'
                          : '${skill.cinderCost}🔥 • ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s CD',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: skill.isPassive ? const Color(0xFFCE93D8) : const Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                      ),
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
                  fontSize: 9.5,
                  color: isPrereqMet ? Colors.white60 : const Color(0xFFFF8A80),
                  fontWeight: isPrereqMet ? FontWeight.normal : FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              ),
            ),
            ),
            ],
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
    String? iconAsset,
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
          if (iconAsset != null)
            Opacity(
              opacity: isActive ? 1.0 : 0.45,
              child: Image.asset(iconAsset, width: 34, height: 34, fit: BoxFit.contain),
            )
          else
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: skill.iconAsset != null ? Colors.transparent : skill.primaryColor,
                  borderRadius: BorderRadius.circular(6),
                  border: skill.iconAsset != null ? null : Border.all(color: skill.borderColor, width: 1.2),
                ),
                alignment: Alignment.center,
                child: _buildSkillVisualIcon(skill, size: 46),
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
                      skill.isPassive
                          ? 'PASSIVE UPGRADE • Max Rank ${skill.maxRank} • Branch: ${_getBranchTitle(skill.branch)}'
                          : 'Cost: ${skill.cinderCost}🔥 • CD: ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s • Branch: ${_getBranchTitle(skill.branch)}',
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
                          : (!skill.isUnlocked
                              ? 'UNLOCK SKILL (1 SP)'
                              : (skill.canUpgrade
                                  ? 'UPGRADE (1 SP) [Rank ${skill.rank + 1}]'
                                  : 'MAX RANK REACHED')),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Equip to Slots 1..5
          Builder(
            builder: (context) {
              final nextEmptySlot = state.equippedSkillIds.indexWhere((id) => id.isEmpty);
              final bool promptEquip = skill.isUnlocked && !isEquipped && nextEmptySlot != -1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: promptEquip ? const Color(0xFF10241C) : const Color(0xFF181B26),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: promptEquip ? const Color(0xFF69F0AE) : Colors.white12,
                    width: promptEquip ? 1.4 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (promptEquip)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          'STEP 2: Tap Slot [${nextEmptySlot + 1}] to load ${skill.name} onto your Active Tray!',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF69F0AE),
                          ),
                        ),
                      ),
                    if (skill.isPassive)
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFFCE93D8), size: 13),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PASSIVE UPGRADE • ALWAYS ACTIVE (NO BAR SLOT NEEDED)',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFCE93D8),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Text(
                            !skill.isUnlocked
                                ? 'UNLOCK SKILL FIRST'
                                : (isEquipped ? 'EQUIPPED IN SLOT $currentSlot' : 'LOAD INTO BAR SLOT:'),
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              color: promptEquip ? const Color(0xFF69F0AE) : Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 4,
                            children: List.generate(5, (slotIdx) {
                              final isThisSlot = isEquipped && (currentSlot - 1) == slotIdx;
                              final isSuggestedSlot = promptEquip && slotIdx == nextEmptySlot;
                              return InkWell(
                                onTap: skill.isUnlocked
                                    ? () {
                                        setState(() {
                                          state.equipSkill(slotIdx, skill.id);
                                        });
                                      }
                                    : null,
                                child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isThisSlot
                                      ? const Color(0xFFFFD54F)
                                      : (isSuggestedSlot ? const Color(0xFF00E676) : const Color(0xFF263238)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (isThisSlot || isSuggestedSlot) ? Colors.black : Colors.white24,
                                    width: isSuggestedSlot ? 1.5 : 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${slotIdx + 1}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: (isThisSlot || isSuggestedSlot)
                                        ? Colors.black
                                        : (skill.isUnlocked ? Colors.white : Colors.white30),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
