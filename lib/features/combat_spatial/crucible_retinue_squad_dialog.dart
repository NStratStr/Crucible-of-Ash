import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/data/starter_brigades.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';
import '../../features/relics/relic_service.dart';

class CrucibleRetinueSquadDialog extends StatefulWidget {
  final SpatialCombatEngine engine;
  final List<UnitEntity> currentSquadUnits;
  final List<UnitEntity> reserveUnits;
  final RelicService? relicService;
  final Function(List<UnitEntity> updatedSquad, List<UnitEntity> updatedReserves) onSquadUpdated;

  const CrucibleRetinueSquadDialog({
    super.key,
    required this.engine,
    required this.currentSquadUnits,
    required this.reserveUnits,
    this.relicService,
    required this.onSquadUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required SpatialCombatEngine engine,
    required List<UnitEntity> currentSquadUnits,
    required List<UnitEntity> reserveUnits,
    RelicService? relicService,
    required Function(List<UnitEntity> updatedSquad, List<UnitEntity> updatedReserves) onSquadUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CrucibleRetinueSquadDialog(
        engine: engine,
        currentSquadUnits: currentSquadUnits,
        reserveUnits: reserveUnits,
        relicService: relicService,
        onSquadUpdated: onSquadUpdated,
      ),
    );
  }

  @override
  State<CrucibleRetinueSquadDialog> createState() => _CrucibleRetinueSquadDialogState();
}

class _CrucibleRetinueSquadDialogState extends State<CrucibleRetinueSquadDialog> {
  int _selectedCompanionSlot = 1; // 1 = Companion Slot 1, 2 = Companion Slot 2
  late List<UnitEntity> _squad;
  late List<UnitEntity> _reserves;

  @override
  void initState() {
    super.initState();
    _squad = List.from(widget.currentSquadUnits);
    _reserves = List.from(widget.reserveUnits);

    // Ensure all 8 archetype sculpted minions exist in reserves or squad
    final activeSpecies = _squad.map((u) => u.speciesId).toSet();
    final reserveSpecies = _reserves.map((u) => u.speciesId).toSet();
    for (final defMinion in StarterBrigades.createReserveInventory()) {
      if (!activeSpecies.contains(defMinion.speciesId) && !reserveSpecies.contains(defMinion.speciesId)) {
        _reserves.add(defMinion);
      }
    }
  }

  String _getMinionPassiveTitle(String speciesId) {
    if (speciesId.contains('footman')) return '🛡️ Bulwark Oath';
    if (speciesId.contains('duelist')) return '🗡️ Stalker Edge';
    if (speciesId.contains('reaver')) return '🔥 Reaver Ferocity';
    if (speciesId.contains('sentinel')) return '🪨 Grave Carapace';
    if (speciesId.contains('scribe')) return '🩸 Vitae Bond';
    if (speciesId.contains('chanter')) return '⏳ Temporal Weft';
    if (speciesId.contains('medicus')) return '✨ Aura of Vitality';
    if (speciesId.contains('arbalest')) return '🎯 Siege Resonator';
    return '⚔️ Retinue Synergy';
  }

  String _getMinionPassiveDescription(String speciesId) {
    if (speciesId.contains('footman')) return 'Sculptor gains +25 Armor and takes 15% reduced damage from all sources.';
    if (speciesId.contains('duelist')) return 'Sculptor gains +15% Critical Chance and channels +4 Cinders on crits.';
    if (speciesId.contains('reaver')) return 'Sculptor gains +20% Attack and channels +8 Cinders on enemy takedowns.';
    if (speciesId.contains('sentinel')) return 'Sculptor gains +35% Barrier Strength and Stagger Immunity.';
    if (speciesId.contains('scribe')) return 'Sculptor gains +18% Lifesteal and channels +2 Cinders on bleed ticks.';
    if (speciesId.contains('chanter')) return 'Sculptor gains -20% Skill Cooldowns and +2,000 AP tempo.';
    if (speciesId.contains('medicus')) return 'Sculptor gains +25% Healing Power and +3% Max HP regen per tick.';
    if (speciesId.contains('arbalest')) return 'Sculptor gains +25% AoE Damage and +1 AoE splash radius.';
    return 'Synergy bond granted to the Ash Sculptor commander.';
  }

  void _deployMinionIntoTargetSlot(UnitEntity incomingMinion) {
    if (_selectedCompanionSlot < 1) return;

    // Check if minion is already deployed in this slot
    if (_selectedCompanionSlot < _squad.length && _squad[_selectedCompanionSlot].speciesId == incomingMinion.speciesId) {
      return;
    }

    setState(() {
      UnitEntity? outgoingEntity;
      String? outgoingUnitId;

      if (_selectedCompanionSlot < _squad.length) {
        outgoingEntity = _squad[_selectedCompanionSlot];
        outgoingUnitId = outgoingEntity.id;
        _squad[_selectedCompanionSlot] = incomingMinion;
      } else {
        _squad.add(incomingMinion);
      }

      // Remove incoming minion from reserves
      _reserves.removeWhere((u) => u.speciesId == incomingMinion.speciesId || u.id == incomingMinion.id);

      // Add outgoing minion back to reserves if not already there
      if (outgoingEntity != null && !_reserves.any((u) => u.speciesId == outgoingEntity!.speciesId)) {
        _reserves.add(outgoingEntity);
      }

      // Sync combat engine player units directly and reliably
      widget.engine.setRetinueCompanion(_selectedCompanionSlot, incomingMinion, relicService: widget.relicService);

      widget.onSquadUpdated(_squad, _reserves);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLandscapeMobile = screenHeight < 550;

    // Gather all 8 archetype minion candidates (combining squad + reserves)
    final Map<String, UnitEntity> allMinionCatalog = {};
    for (final u in StarterBrigades.createReserveInventory()) {
      allMinionCatalog[u.speciesId] = u;
    }
    for (final u in _reserves) {
      allMinionCatalog[u.speciesId] = u;
    }
    for (final u in _squad) {
      if (!u.id.contains('sculptor') && !u.speciesId.contains('sculptor')) {
        allMinionCatalog[u.speciesId] = u;
      }
    }

    final minionList = allMinionCatalog.values.toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscapeMobile ? 12 : 16,
        vertical: isLandscapeMobile ? 8 : 20,
      ),
      child: Container(
        width: isLandscapeMobile ? screenWidth * 0.94 : 860,
        height: isLandscapeMobile ? screenHeight * 0.92 : 620,
        decoration: BoxDecoration(
          color: const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(color: Colors.black87, blurRadius: 24),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(isLandscapeMobile),

            // Active Squad Formation Tray (Slot 0: Commander, Slot 1: Companion A, Slot 2: Companion B)
            _buildActiveSquadFormationRow(isLandscapeMobile),

            // Roster of All 8 Sculpted Minions (Grid / Carousel)
            Expanded(
              child: _buildMinionRosterGrid(minionList, isLandscapeMobile),
            ),

            // Footer Action Bar
            _buildFooter(isLandscapeMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLandscapeMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscapeMobile ? 6 : 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161822),
        borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_add_rounded, color: Color(0xFF00E5FF), size: 18),
          const SizedBox(width: 8),
          const Text(
            'CRUCIBLE RETINUE SQUAD BUILDER',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF00E5FF),
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2838),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 0.8),
            ),
            child: Text(
              'DEPLOYED: ${widget.engine.playerUnits.length}/3 UNITS',
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF80D8FF), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSquadFormationRow(bool isLandscapeMobile) {
    final sculptor = widget.engine.playerUnits.where((u) => u.isAshSculptor).firstOrNull;
    final companion1 = _squad.length > 1 ? _squad[1] : null;
    final companion2 = _squad.length > 2 ? _squad[2] : null;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscapeMobile ? 4 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E14),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // Slot 0: Commander
          Expanded(
            child: _buildSlotCard(
              title: 'SLOT 1 • COMMANDER',
              unitName: sculptor?.name ?? 'The Ash Sculptor',
              roleText: 'CRUCIBLE COMMANDER',
              assetPath: sculptor?.customAssetPath ?? 'assets/images/ash_sculptor_idle.png',
              passiveText: 'Channels Cinders & executes Crucible Grimoire Skills.',
              isSelectedSlot: false,
              isCommander: true,
              onTap: null,
            ),
          ),
          const SizedBox(width: 8),

          // Slot 1: Companion A
          Expanded(
            child: _buildSlotCard(
              title: 'SLOT 2 • RETINUE COMPANION A',
              unitName: companion1?.name ?? 'EMPTY SLOT',
              roleText: companion1 != null ? companion1.archetype.name.toUpperCase() : 'SELECT BELOW',
              assetPath: companion1?.customAvatarAsset ?? 'assets/images/iron_footman_idle.png',
              passiveText: companion1 != null
                  ? _getMinionPassiveTitle(companion1.speciesId)
                  : 'Tap below to assign a minion.',
              isSelectedSlot: _selectedCompanionSlot == 1,
              isCommander: false,
              onTap: () {
                setState(() {
                  _selectedCompanionSlot = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 8),

          // Slot 2: Companion B
          Expanded(
            child: _buildSlotCard(
              title: 'SLOT 3 • RETINUE COMPANION B',
              unitName: companion2?.name ?? 'EMPTY SLOT',
              roleText: companion2 != null ? companion2.archetype.name.toUpperCase() : 'SELECT BELOW',
              assetPath: companion2?.customAvatarAsset ?? 'assets/images/grave_duelist.png',
              passiveText: companion2 != null
                  ? _getMinionPassiveTitle(companion2.speciesId)
                  : 'Tap below to assign a minion.',
              isSelectedSlot: _selectedCompanionSlot == 2,
              isCommander: false,
              onTap: () {
                setState(() {
                  _selectedCompanionSlot = 2;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard({
    required String title,
    required String unitName,
    required String roleText,
    required String assetPath,
    required String passiveText,
    required bool isSelectedSlot,
    required bool isCommander,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelectedSlot
              ? const Color(0xFF1A2838)
              : (isCommander ? const Color(0xFF1E1814) : const Color(0xFF141720)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelectedSlot
                ? const Color(0xFF00E5FF)
                : (isCommander ? const Color(0xFFFFD54F).withValues(alpha: 0.6) : Colors.white24),
            width: isSelectedSlot ? 1.8 : 1.0,
          ),
          boxShadow: isSelectedSlot
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.8),
                color: Colors.black54,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white38, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.bold,
                            color: isSelectedSlot ? const Color(0xFF00E5FF) : Colors.white54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelectedSlot)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'SWAPPING',
                            style: TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    unitName.toUpperCase(),
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    passiveText,
                    style: const TextStyle(fontSize: 7.5, color: Color(0xFFFFD54F)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinionRosterGrid(List<UnitEntity> minions, bool isLandscapeMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AVAILABLE ARCHETYPE MINIONS (TAP TO ASSIGN TO SLOT $_selectedCompanionSlot):',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD54F),
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                'Currently editing: Retinue Companion Slot $_selectedCompanionSlot',
                style: const TextStyle(fontSize: 8.5, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isLandscapeMobile ? 4 : 2,
                childAspectRatio: isLandscapeMobile ? 2.4 : 3.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: minions.length,
              itemBuilder: (context, idx) {
                final minion = minions[idx];
                final bool isDeployedInSlot1 = _squad.length > 1 && _squad[1].speciesId == minion.speciesId;
                final bool isDeployedInSlot2 = _squad.length > 2 && _squad[2].speciesId == minion.speciesId;
                final bool isDeployed = isDeployedInSlot1 || isDeployedInSlot2;

                return InkWell(
                  onTap: () {
                    _deployMinionIntoTargetSlot(minion);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDeployed
                          ? const Color(0xFF13201E)
                          : const Color(0xFF181B26),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDeployed
                            ? const Color(0xFF00E676)
                            : Colors.white24,
                        width: isDeployed ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Minion Image
                        Container(
                          width: 34,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.black54,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.asset(
                              minion.customAvatarAsset ?? 'assets/images/iron_footman_idle.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Minion Meta & Sculptor Passive
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      minion.name,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isDeployed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        isDeployedInSlot1 ? 'SLOT 2' : 'SLOT 3',
                                        style: const TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                'HP ${minion.maxHp} • ATK ${minion.attack} • DEF ${minion.defense} • SPD ${minion.speed}',
                                style: const TextStyle(fontSize: 7.5, color: Colors.white54),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF261D12),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 0.6),
                                ),
                                child: Text(
                                  _getMinionPassiveTitle(minion.speciesId) + ': ' + _getMinionPassiveDescription(minion.speciesId),
                                  style: const TextStyle(fontSize: 7.0, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
        ],
      ),
    );
  }

  Widget _buildFooter(bool isLandscapeMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscapeMobile ? 6 : 8),
      decoration: const BoxDecoration(
        color: Color(0xFF141720),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFFD54F), size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Retinue minions automatically grant active passive powers to the Ash Sculptor.',
              style: TextStyle(fontSize: 8.5, color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(Icons.check, size: 14, color: Colors.black),
            label: const Text(
              'CONFIRM SQUAD & RETURN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              widget.engine.updateRetinueSquad(_squad, relicService: widget.relicService);
              widget.onSquadUpdated(_squad, _reserves);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
