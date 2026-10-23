import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../features/campaign/campaign_node.dart';
import '../../features/generals/general_command_service.dart';
import '../../features/generals/general_selection_dialog.dart';
import '../../features/generals/grimoire_manager_dialog.dart';
import '../../shared/models/unit_entity.dart';

/// Interactive Pre-Battle Deployment & Strategy Modal.
/// Allows the player to inspect enemy lineup & 3-Star objectives,
/// review and swap active squad members from reserve,
/// customize their General Commander and Grimoire loadout,
/// and engage directly into the battle arena.
class PreBattleDeploymentDialog extends StatefulWidget {
  final CampaignNode? node;
  final List<UnitEntity> activeSquad;
  final List<UnitEntity> reserveInventory;
  final List<UnitEntity> enemyUnits;
  final GeneralCommandService commandService;
  final int bloodlineSigils;
  final ValueChanged<List<UnitEntity>> onSquadUpdated;
  final ValueChanged<List<UnitEntity>> onEngageBattle;

  const PreBattleDeploymentDialog({
    super.key,
    required this.node,
    required this.activeSquad,
    required this.reserveInventory,
    required this.enemyUnits,
    required this.commandService,
    required this.bloodlineSigils,
    required this.onSquadUpdated,
    required this.onEngageBattle,
  });

  static Future<void> show(
    BuildContext context, {
    required CampaignNode? node,
    required List<UnitEntity> activeSquad,
    required List<UnitEntity> reserveInventory,
    required List<UnitEntity> enemyUnits,
    required GeneralCommandService commandService,
    required int bloodlineSigils,
    required ValueChanged<List<UnitEntity>> onSquadUpdated,
    required ValueChanged<List<UnitEntity>> onEngageBattle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101016),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFFE5A93C), width: 1.5),
      ),
      builder: (ctx) => PreBattleDeploymentDialog(
        node: node,
        activeSquad: activeSquad,
        reserveInventory: reserveInventory,
        enemyUnits: enemyUnits,
        commandService: commandService,
        bloodlineSigils: bloodlineSigils,
        onSquadUpdated: onSquadUpdated,
        onEngageBattle: onEngageBattle,
      ),
    );
  }

  @override
  State<PreBattleDeploymentDialog> createState() => _PreBattleDeploymentDialogState();
}

class _PreBattleDeploymentDialogState extends State<PreBattleDeploymentDialog> {
  late List<UnitEntity> _currentSquad;
  late List<UnitEntity> _reserves;
  Archetype? _filterArchetype;
  String? _filterFaction;
  bool _filterCommandersOnly = false;

  @override
  void initState() {
    super.initState();
    _currentSquad = List<UnitEntity>.from(widget.activeSquad);
    final activeIds = _currentSquad.map((u) => u.id).toSet();
    _reserves = widget.reserveInventory.where((u) => !activeIds.contains(u.id)).toList();
  }

  void _swapUnit(UnitEntity incoming, UnitEntity outgoing) {
    setState(() {
      final replacedIncoming = incoming.copyWith(slot: outgoing.slot);
      _reserves.removeWhere((u) => u.id == incoming.id);
      _reserves.removeWhere((u) => u.id == outgoing.id);
      _reserves.insert(0, outgoing);

      final idx = _currentSquad.indexWhere((u) => u.id == outgoing.id);
      if (idx != -1) {
        _currentSquad[idx] = replacedIncoming;
      }
    });
    widget.onSquadUpdated(_currentSquad);
  }

  Color _getArchetypeColor(Archetype arc) {
    switch (arc) {
      case Archetype.juggernaut:
        return const Color(0xFFC62828);
      case Archetype.assassin:
        return const Color(0xFF6A1B9A);
      case Archetype.marksman:
        return const Color(0xFF2E7D32);
      case Archetype.skirmisher:
        return const Color(0xFFE65100);
      case Archetype.support:
        return const Color(0xFF00838F);
      case Archetype.occultist:
        return const Color(0xFF4527A0);
    }
  }

  void _openSwapSheetForSlot(UnitEntity activeUnit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFFE5A93C), width: 1.2),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filteredReserves = _reserves.where((u) {
              if (_filterCommandersOnly && !u.isCommander) return false;
              if (_filterArchetype != null && u.archetype != _filterArchetype) return false;
              if (_filterFaction != null && u.factionName != _filterFaction) return false;
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: Color(0xFFE5A93C), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SWAP ${activeUnit.name.toUpperCase()} (SLOT ${activeUnit.slot.name.toUpperCase()})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Filter bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('👑 CMD', _filterCommandersOnly, () {
                          setSheetState(() => _filterCommandersOnly = !_filterCommandersOnly);
                        }),
                        const SizedBox(width: 6),
                        _filterChip('ALL ROLES', _filterArchetype == null && !_filterCommandersOnly, () {
                          setSheetState(() {
                            _filterArchetype = null;
                            _filterCommandersOnly = false;
                          });
                        }),
                        const SizedBox(width: 4),
                        _filterChip('🛡️ JUG', _filterArchetype == Archetype.juggernaut, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.juggernaut ? null : Archetype.juggernaut);
                        }),
                        const SizedBox(width: 4),
                        _filterChip('🗡️ ASN', _filterArchetype == Archetype.assassin, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.assassin ? null : Archetype.assassin);
                        }),
                        const SizedBox(width: 4),
                        _filterChip('🏹 MRK', _filterArchetype == Archetype.marksman, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.marksman ? null : Archetype.marksman);
                        }),
                        const SizedBox(width: 4),
                        _filterChip('🦅 SKR', _filterArchetype == Archetype.skirmisher, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.skirmisher ? null : Archetype.skirmisher);
                        }),
                        const SizedBox(width: 4),
                        _filterChip('💚 SUP', _filterArchetype == Archetype.support, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.support ? null : Archetype.support);
                        }),
                        const SizedBox(width: 4),
                        _filterChip('🔮 OCC', _filterArchetype == Archetype.occultist, () {
                          setSheetState(() => _filterArchetype = _filterArchetype == Archetype.occultist ? null : Archetype.occultist);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredReserves.isEmpty
                        ? const Center(
                            child: Text(
                              'NO RESERVE CHAMPIONS MATCH CRITERIA',
                              style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 11),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredReserves.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final candidate = filteredReserves[idx];
                              return ListTile(
                                tileColor: const Color(0xFF101016),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: _getArchetypeColor(candidate.archetype).withValues(alpha: 0.5)),
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    candidate.effectiveAvatarAsset,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white38),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      candidate.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'G${candidate.generation}',
                                        style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${candidate.archetype.name.toUpperCase()} • ${candidate.factionName} • HP ${candidate.maxHp} • ATK ${candidate.attack}',
                                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB3261E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    _swapUnit(candidate, activeUnit);
                                  },
                                  child: const Text('DEPLOY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF333344)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.node?.name ?? 'TACTICAL ENGAGEMENT';
    final profile = widget.commandService.currentProfile;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFE5A93C), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'WAR COUNCIL • PRE-BATTLE PREPARATION',
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Encounter 3-Star Objectives & Enemy Lineup Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A2A3A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.star, color: Color(0xFFFFD54F), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  '3-STAR BATTLE OBJECTIVES',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'ENEMIES (${widget.enemyUnits.length})',
                              style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '⭐ Clear Encounter: Defeat all enemy cohorts.\n'
                          '⭐⭐ Battle Readiness: Win with 4+ allied champions standing.\n'
                          '⭐⭐⭐ Lord Commander Safeguard: Finish without your Commander falling.',
                          style: TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.4),
                        ),
                        if (widget.enemyUnits.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: widget.enemyUnits.take(5).map((e) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB3261E).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.6)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.dangerous, color: Color(0xFFEF5350), size: 10),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${e.name} (${e.archetype.name.substring(0, 3).toUpperCase()})',
                                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Commander & Grimoire Deck Bar
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: profile.themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: profile.themeColor, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: profile.themeColor.withValues(alpha: 0.3),
                          child: Icon(profile.icon, color: profile.themeColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              Text(
                                'AURA: ${profile.auraName} • ${widget.commandService.getActiveGrimoireDeck().length} GRIMOIRE SPELLS',
                                style: TextStyle(color: profile.themeColor, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: profile.themeColor,
                            side: BorderSide(color: profile.themeColor),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            GeneralSelectionDialog.show(
                              context,
                              currentGeneralType: widget.commandService.activeGeneralType,
                              commandService: widget.commandService,
                              bloodlineSigils: widget.bloodlineSigils,
                            ).then((_) => setState(() {}));
                          },
                          child: const Text('GENERAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBA68C8),
                            side: const BorderSide(color: Color(0xFFBA68C8)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            GrimoireManagerDialog.show(
                              context,
                              commandService: widget.commandService,
                              bloodlineSigils: widget.bloodlineSigils,
                            ).then((_) => setState(() {}));
                          },
                          child: const Text('SPELLS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Active 5-Champion Deployment Slots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE BRIGADE (TAP SLOT TO SWAP FROM ROSTER)',
                        style: TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      Text(
                        'RESERVES: ${_reserves.length}',
                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._currentSquad.map((unit) {
                    final isVanguard = unit.isVanguard;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isVanguard ? const Color(0xFFB3261E).withValues(alpha: 0.7) : const Color(0xFF1976D2).withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              unit.effectiveAvatarAsset,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white38),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      unit.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        'G${unit.generation}',
                                        style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _getArchetypeColor(unit.archetype).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        unit.archetype.name.substring(0, 3).toUpperCase(),
                                        style: TextStyle(color: _getArchetypeColor(unit.archetype), fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SLOT: ${unit.slot.name.toUpperCase()} • HP: ${unit.maxHp} • ATK: ${unit.attack} • DEF: ${unit.defense}',
                                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B2B38),
                              foregroundColor: const Color(0xFFE5A93C),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.swap_horiz, size: 14),
                            label: const Text('SWAP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            onPressed: () => _openSwapSheetForSlot(unit),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Engage Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'ENTER BATTLEFIELD (DEPLOY)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onEngageBattle(_currentSquad);
              },
            ),
          ),
        ],
      ),
    );
  }
}
