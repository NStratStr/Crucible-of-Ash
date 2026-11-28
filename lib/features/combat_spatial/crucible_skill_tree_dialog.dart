import 'package:flutter/material.dart';
import 'models/crucible_skill_tree_models.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

enum CrucibleHubTab {
  skillTree,
  unitUpgrades,
}

class CrucibleSkillTreeDialog extends StatefulWidget {
  final SpatialCombatEngine engine;
  final CrucibleHubTab initialTab;

  const CrucibleSkillTreeDialog({
    super.key,
    required this.engine,
    this.initialTab = CrucibleHubTab.skillTree,
  });

  static Future<void> show(
    BuildContext context,
    SpatialCombatEngine engine, {
    CrucibleHubTab initialTab = CrucibleHubTab.skillTree,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrucibleSkillTreeDialog(
        engine: engine,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<CrucibleSkillTreeDialog> createState() => _CrucibleSkillTreeDialogState();
}

class _CrucibleSkillTreeDialogState extends State<CrucibleSkillTreeDialog> {
  late CrucibleHubTab _activeHubTab;
  CrucibleSkillBranch _selectedBranch = CrucibleSkillBranch.wrath;
  String? _selectedSkillId;

  @override
  void initState() {
    super.initState();
    _activeHubTab = widget.initialTab;
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
    final mq = MediaQuery.of(context);
    final bool isPhone = mq.size.width < 640 || mq.size.height < 540;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 6 : 16,
        vertical: isPhone ? 6 : 24,
      ),
      child: Container(
        width: isPhone ? mq.size.width : 860,
        height: isPhone ? mq.size.height : 620,
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
            // Unified Header Bar (Mode Switcher + SP/Gold/Ore Wallet + Respec + Close)
            _buildHeader(state, isPhone: isPhone),

            if (_activeHubTab == CrucibleHubTab.unitUpgrades)
              Expanded(
                child: _buildUnifiedWarbandUpgradesView(isCompact: isPhone),
              )
            else ...[
              // 5 Equipped Slots Bar (compact & scrollable on mobile)
              if (mq.size.height >= 360)
                _buildEquippedSlotsRow(state, isPhone: isPhone),

              if (_isFirstSkillTutorial(state) && mq.size.height >= 500)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10241C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF69F0AE), width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: Color(0xFF69F0AE), size: 15),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Select a glowing skill below and tap [UNLOCK / UPGRADE] to equip your next Skill Slot!',
                          style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Branch Archetype Tabs + Crown Apex
              _buildBranchTabs(state),

              // Main Body: Branch Pathway & Keystone + Skill Inspector
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
                      child: _buildSkillDetailInspector(selectedSkill, state, isCompact: isPhone),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CrucibleSkillTreeState state, {bool isPhone = false}) {
    final engine = widget.engine;
    final bool isSkillsTab = _activeHubTab == CrucibleHubTab.skillTree;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 10 : 16, vertical: isPhone ? 6 : 9),
      decoration: const BoxDecoration(
        color: Color(0xFF161822),
        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unified Mode Pill 1: Commander Skill Tree
                  InkWell(
                    onTap: () => setState(() => _activeHubTab = CrucibleHubTab.skillTree),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isSkillsTab ? const Color(0xFF162B20) : const Color(0xFF10121A),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isSkillsTab ? const Color(0xFF69F0AE) : Colors.white24,
                          width: isSkillsTab ? 1.3 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree_rounded,
                            size: 13,
                            color: isSkillsTab ? const Color(0xFF69F0AE) : Colors.white54,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            state.availableSkillPoints > 0
                                ? 'SKILL TREE (${state.availableSkillPoints}★)'
                                : 'SKILL TREE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isSkillsTab ? const Color(0xFF69F0AE) : Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Unified Mode Pill 2: Commander & Unit Stat Upgrades
                  InkWell(
                    onTap: () => setState(() => _activeHubTab = CrucibleHubTab.unitUpgrades),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: !isSkillsTab ? const Color(0xFF2D1E12) : const Color(0xFF10121A),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: !isSkillsTab ? const Color(0xFFFFAB40) : Colors.white24,
                          width: !isSkillsTab ? 1.3 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 13,
                            color: !isSkillsTab ? const Color(0xFFFFAB40) : Colors.white54,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'UNIT & STAT UPGRADES',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: !isSkillsTab ? const Color(0xFFFFAB40) : Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Shared Currencies: SP + GOLD + ORE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF263238),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '${state.availableSkillPoints} SP',
                          style: const TextStyle(
                            fontSize: 9.2,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFD54F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.45), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, size: 12, color: Color(0xFFFFD54F)),
                        const SizedBox(width: 3),
                        Text(
                          '${engine.unboundAshWallet} GOLD',
                          style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFFFFE082)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0A12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF80CBC4).withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.diamond_outlined, size: 12, color: Color(0xFF80CBC4)),
                        const SizedBox(width: 3),
                        Text(
                          '${engine.distilledVitaeWallet} ORE',
                          style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFF80CBC4)),
                        ),
                      ],
                    ),
                  ),
                  if (isSkillsTab) ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37474F),
                        foregroundColor: const Color(0xFFFFD54F),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(color: Color(0xFFFFD54F), width: 0.8),
                        ),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 12, color: Color(0xFFFFD54F)),
                      label: const Text(
                        'RESPEC',
                        style: TextStyle(fontSize: 8.8, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          engine.respecSkillsWithRefund();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Skill points & invested Gold/Ore refunded!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEquippedSlotsRow(CrucibleSkillTreeState state, {bool isPhone = false}) {
    Widget buildSlotBox(int slotIdx) {
      final skill = state.getSkillInSlot(slotIdx);
      final bool isSelected = skill != null && skill.id == _selectedSkillId;
      final Widget inner = Container(
        width: isPhone ? 108 : null,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
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
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${slotIdx + 1}',
                  style: const TextStyle(fontSize: 8.0, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              if (skill != null) ...[
                _buildSkillVisualIcon(skill, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(fontSize: 8.0, color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${skill.cinderCost}🔥 • R${skill.rank}',
                        style: TextStyle(fontSize: 6.8, color: skill.borderColor),
                      ),
                    ],
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'EMPTY',
                    style: TextStyle(fontSize: 7.5, color: Colors.white24, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      );
      return isPhone ? inner : Expanded(child: inner);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 10 : 16, vertical: isPhone ? 5 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E14),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(
            isPhone ? 'TRAY:' : 'ACTIVE TRAY (5 SLOTS):',
            style: const TextStyle(
              fontSize: 9.0,
              fontWeight: FontWeight.w900,
              color: Colors.white60,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isPhone
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: List.generate(5, buildSlotBox)),
                  )
                : Row(children: List.generate(5, buildSlotBox)),
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
                  Flexible(
                    child: Text(
                      skill.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isPrereqMet ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isPrereqMet
                          ? (skill.tier == 1 ? const Color(0xFF1B5E20) : const Color(0xFF0D47A1))
                          : const Color(0xFFB71C1C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      isPrereqMet ? 'T${skill.tier}' : '🔒T${skill.tier}',
                      style: const TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        skill.isPassive
                            ? 'PASSIVE'
                            : '${skill.cinderCost}🔥•${skill.effectiveCooldownSeconds.toStringAsFixed(0)}s',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8.0,
                          color: skill.isPassive ? const Color(0xFFCE93D8) : const Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: skill.rank >= skill.maxRank ? const Color(0xFF00C853) : const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'R${skill.rank}/${skill.maxRank}',
                      style: const TextStyle(fontSize: 8.2, color: Colors.white, fontWeight: FontWeight.w900),
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

  Widget _buildSkillDetailInspector(CrucibleSkillNode? skill, CrucibleSkillTreeState state, {bool isCompact = false}) {
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
    final nextEmptySlot = state.equippedSkillIds.indexWhere((id) => id.isEmpty);

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      color: const Color(0xFF13151F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable Detail + Rank Progression Area (prevents bottom overflow on portrait & landscape phones!)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: isCompact ? 38 : 48,
                        height: isCompact ? 38 : 48,
                        decoration: BoxDecoration(
                          color: skill.iconAsset != null ? Colors.transparent : skill.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                          border: skill.iconAsset != null ? null : Border.all(color: skill.borderColor, width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: _buildSkillVisualIcon(skill, size: isCompact ? 36 : 46),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skill.name,
                              style: TextStyle(fontSize: isCompact ? 12.5 : 14, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
                              skill.isPassive
                                  ? 'PASSIVE • Max Rank ${skill.maxRank} • ${_getBranchTitle(skill.branch)}'
                                  : 'Cost: ${skill.cinderCost}🔥 • CD: ${skill.effectiveCooldownSeconds.toStringAsFixed(1)}s • ${_getBranchTitle(skill.branch)}',
                              style: TextStyle(fontSize: 8.8, color: skill.borderColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 6 : 12),
                  Text(
                    skill.summary,
                    style: TextStyle(fontSize: isCompact ? 9.5 : 10.5, color: Colors.white70, height: 1.28),
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
                  const Text(
                    'UPGRADE TIERS (RANK PROGRESSION):',
                    style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 5),
                  ...List.generate(skill.rankDescriptions.length, (idx) {
                    final tierNum = idx + 1;
                    final isCurrent = skill.rank == tierNum;
                    final isUnlocked = skill.rank >= tierNum;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: EdgeInsets.all(isCompact ? 6 : 8),
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
                                fontSize: 8.8,
                                color: isUnlocked ? Colors.white : Colors.white38,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (!state.isSkillPrerequisiteMet(skill.id))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF371717),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFF5252), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 13, color: Color(0xFFFF5252)),
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
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Pinned Action Buttons: Unlock/Upgrade (requires SP + Gold + Ore, auto-equips into next empty slot!) & Slot Picker 1..5
          Builder(
            builder: (context) {
              final engine = widget.engine;
              final int goldCost = engine.getSkillGoldCost(skill);
              final int oreCost = engine.getSkillOreCost(skill);
              final bool canAffordAll = engine.canAffordSkillWithResources(skill.id);
              final String costLabel = oreCost > 0
                  ? '1★ SP • $goldCost GOLD • $oreCost ORE'
                  : '1★ SP • $goldCost GOLD';

              String buttonLabel;
              if (!state.isSkillPrerequisiteMet(skill.id)) {
                buttonLabel = '🔒 LOCKED (CHECK REQUIREMENTS)';
              } else if (!skill.canUpgrade) {
                buttonLabel = 'MAX RANK REACHED';
              } else if (state.availableSkillPoints <= 0) {
                buttonLabel = 'NEED 1★ SP ($costLabel)';
              } else if (engine.unboundAshWallet < goldCost || engine.distilledVitaeWallet < oreCost) {
                buttonLabel = 'NEED RESOURCES ($costLabel)';
              } else if (!skill.isUnlocked) {
                buttonLabel = 'UNLOCK ($costLabel)';
              } else {
                buttonLabel = 'RANK ${skill.rank + 1} ($costLabel)';
              }

              return SizedBox(
                width: double.infinity,
                height: isCompact ? 34 : 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAffordAll
                        ? const Color(0xFFFF6D00)
                        : const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: canAffordAll
                      ? () {
                          setState(() {
                            final bool wasLocked = !skill.isUnlocked;
                            engine.upgradeSkillWithResources(skill.id);
                            if (wasLocked && !skill.isPassive && !state.equippedSkillIds.contains(skill.id)) {
                              final openIdx = state.equippedSkillIds.indexWhere((id) => id.isEmpty);
                              if (openIdx != -1) {
                                state.equipSkill(openIdx, skill.id);
                              }
                            }
                          });
                        }
                      : null,
                  child: Text(
                    buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          // Equip to Slots 1..5
          Builder(
            builder: (context) {
              final bool promptEquip = skill.isUnlocked && !isEquipped && nextEmptySlot != -1;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: isCompact ? 4 : 6),
                decoration: BoxDecoration(
                  color: promptEquip ? const Color(0xFF10241C) : const Color(0xFF181B26),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: promptEquip ? const Color(0xFF69F0AE) : Colors.white12,
                    width: promptEquip ? 1.4 : 1.0,
                  ),
                ),
                child: skill.isPassive
                    ? const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Color(0xFFCE93D8), size: 13),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PASSIVE UPGRADE • ALWAYS ACTIVE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFCE93D8),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              !skill.isUnlocked
                                  ? 'UNLOCK TO EQUIP'
                                  : (isEquipped ? 'SLOT $currentSlot (TAP TO MOVE):' : 'EQUIP TO SLOT:'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: promptEquip ? const Color(0xFF69F0AE) : Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (slotIdx) {
                              final isThisSlot = isEquipped && (currentSlot - 1) == slotIdx;
                              final isSuggestedSlot = promptEquip && slotIdx == nextEmptySlot;
                              return Padding(
                                padding: EdgeInsets.only(left: slotIdx == 0 ? 0 : 4),
                                child: InkWell(
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
                                ),
                              );
                            }),
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

  Widget _buildUnifiedWarbandUpgradesView({bool isCompact = false}) {
    final engine = widget.engine;
    final sculptor = engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;
    final minions = engine.playerUnits.where((u) => !u.isAshSculptor && u.id != 'ash_sculptor').toList();
    final bool canAscend = engine.unboundAshWallet >= SpatialCombatEngine.sculptorAscendGoldCost &&
        engine.distilledVitaeWallet >= SpatialCombatEngine.sculptorAscendOreCost;

    return ListView(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      children: [
        if (sculptor != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1622),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF6D00), width: 1.2),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    sculptor.assetPath,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.shield, color: Color(0xFFFF6D00), size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THE ASH SCULPTOR (COMMANDER FURNACE)',
                        style: TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HP ${sculptor.hp}/${sculptor.maxHp}  •  ATK ${sculptor.attack}  •  ARM ${sculptor.armor}  •  SPD ${sculptor.speed}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Permanent Commander Stat Ascension: +200 Max HP & +30 ATK. (Upgrade Commander Skills in the [SKILL TREE] tab.)',
                        style: TextStyle(color: Colors.white60, fontSize: 8.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.whatshot, size: 14),
                  label: const Text(
                    'ASCEND\n(200 GOLD • 20 ORE)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAscend ? const Color(0xFFFF6D00) : const Color(0xFF2E241E),
                    foregroundColor: canAscend ? Colors.white : Colors.white38,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: canAscend
                      ? () {
                          setState(() {
                            engine.upgradeSculptorFurnace();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'DEPLOYED RETINUE COMPANIONS (PERMANENT STAT REFORGING)',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        if (minions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161822),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No Retinue Companions currently in active squad. Use [SQUAD] on the Staging Dock to assign companions.',
              style: TextStyle(color: Colors.white60, fontSize: 10.5),
            ),
          )
        else
          ...minions.map(_buildCompanionUpgradeCard),
      ],
    );
  }

  Widget _buildCompanionUpgradeCard(CombatUnitState minion) {
    final engine = widget.engine;
    final bool canUpgrade = engine.unboundAshWallet >= SpatialCombatEngine.minionUpgradeGoldCost &&
        engine.distilledVitaeWallet >= SpatialCombatEngine.minionUpgradeOreCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF181622),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  minion.assetPath,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white, size: 26),
                ),
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
                            minion.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'LV. ${minion.level}',
                            style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'HP ${minion.hp}/${minion.maxHp}  •  ATK ${minion.attack}  •  ARM ${minion.armor}  •  SPD ${minion.speed}',
                      style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.upgrade, size: 14),
                label: const Text(
                  'REFORGE\n(120 GOLD • 8 ORE)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canUpgrade ? const Color(0xFFFF6D00) : const Color(0xFF2E241E),
                  foregroundColor: canUpgrade ? Colors.white : Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: canUpgrade
                    ? () {
                        setState(() {
                          engine.upgradeMinion(minion.id);
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '🛡️ Aura: ${minion.retinuePassiveName} (${minion.retinuePassiveSummary})',
                style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 8.8, fontWeight: FontWeight.bold),
              ),
              Text(
                '★ Signature (3T): ${minion.signatureSkillName} (${minion.signatureShortEffect})',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 8.8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
