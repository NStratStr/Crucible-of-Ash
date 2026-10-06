import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../features/campaign/campaign_map_generator.dart';
import '../../features/campaign/campaign_map_screen.dart';
import '../../features/campaign/campaign_node.dart';
import '../../features/combat/battle_screen.dart';
import '../../features/combat/combat_resolution_service.dart';
import '../../features/combat/initiative_tick_manager.dart';
import '../../features/crucible/crucible_screen.dart';
import '../../features/generals/general_command_service.dart';
import '../data/starter_brigades.dart';
import '../models/unit_entity.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  int _totalIchor = 450;

  late InitiativeTickManager _tickManager;
  late CombatResolutionService _combatService;
  late GeneralCommandService _commandService;
  late List<UnitEntity> _inventory;
  late List<CampaignNode> _campaignNodes;
  CampaignNode? _activeNode;

  @override
  void initState() {
    super.initState();
    _resetEncounter();
    _inventory = StarterBrigades.createReserveInventory();
    _campaignNodes = CampaignMapGenerator.generateCuratedCampaign();
  }

  void _resetEncounter([List<UnitEntity>? customEnemies]) {
    final allies = StarterBrigades.createPlayerSquad();
    final enemies = customEnemies ?? StarterBrigades.createTutorialEnemies();

    _tickManager = InitiativeTickManager(
      initialAllies: allies,
      initialEnemies: enemies,
      tickInterval: const Duration(milliseconds: 140),
    );

    _combatService = CombatResolutionService(tickManager: _tickManager);

    _commandService = GeneralCommandService(
      tickManager: _tickManager,
      generalId: 'vladislav_01',
      generalName: 'Lord Vladislav',
      initialFocus: 1,
    );

    _tickManager.start();
  }

  @override
  void dispose() {
    _tickManager.dispose();
    _commandService.dispose();
    super.dispose();
  }

  void _onSelectCampaignNode(CampaignNode node) {
    setState(() {
      _activeNode = node;
    });

    if (node.type == CampaignNodeType.skirmish ||
        node.type == CampaignNodeType.elite ||
        node.type == CampaignNodeType.boss) {
      List<UnitEntity> enemies;
      if (node.type == CampaignNodeType.boss) {
        enemies = StarterBrigades.createBossEnemies();
      } else if (node.type == CampaignNodeType.elite) {
        enemies = StarterBrigades.createEliteEnemies();
      } else {
        enemies = StarterBrigades.createTutorialEnemies();
      }

      _resetEncounter(enemies);
      setState(() {
        _currentIndex = 1; // Switch to Combat Arena
      });
    } else if (node.type == CampaignNodeType.altar) {
      // Switch to Crucible Altar
      setState(() {
        _totalIchor += node.rewardIchor;
        _markNodeCompleted(node.id);
        _currentIndex = 2; // Switch to Altar
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Altar of Blood awakened! +${node.rewardIchor} Ichor granted.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } else if (node.type == CampaignNodeType.restHaven) {
      // Heal squad
      _healSquad();
      _markNodeCompleted(node.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Haven reached: Squad restored to full vitality!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else if (node.type == CampaignNodeType.crypt) {
      // Crypt discovery: grants a rare thrall
      _unlockCryptThrall();
      _markNodeCompleted(node.id);
    }
  }

  void _markNodeCompleted(String nodeId) {
    setState(() {
      _campaignNodes = _campaignNodes.map((n) {
        if (n.id == nodeId) {
          return n.copyWith(isVisited: true, isCurrent: false);
        }
        return n;
      }).toList();

      // Unlock forward nodes
      final completed = _campaignNodes.firstWhere((n) => n.id == nodeId);
      for (final nextId in completed.nextNodeIds) {
        _campaignNodes = _campaignNodes.map((n) {
          if (n.id == nextId) {
            return n.copyWith(isReachable: true);
          }
          return n;
        }).toList();
      }
    });
  }

  void _onCombatVictory() {
    if (_activeNode != null) {
      final reward = _activeNode!.rewardIchor;
      setState(() {
        _totalIchor += reward;
      });
      _markNodeCompleted(_activeNode!.id);
      _captureThrallAfterBattle();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EXPEDITION VICTORY! +$reward Ichor and a captured Thrall bound to Roster!'),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _captureThrallAfterBattle() {
    final newThrall = UnitEntity(
      id: 'captured_thrall_${DateTime.now().millisecondsSinceEpoch}',
      speciesId: 'feral_hound',
      name: 'Captured War-Hound',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 10,
      currentHp: 750,
      maxHp: 750,
      attack: 140,
      defense: 110,
      speed: 105,
      nativeTraitId: 'rend_flesh',
      lineageAncestors: const [],
    );

    setState(() {
      _inventory.insert(0, newThrall);
    });
  }

  void _healSquad() {
    // Restores squad HP
    final healed = _tickManager.allies.map((u) => u.copyWith(currentHp: u.maxHp)).toList();
    _tickManager.consumeTurn(
      retainedOverflow: true,
      updatedAllies: healed,
      autoResume: false,
    );
  }

  void _unlockCryptThrall() {
    final cryptGhoul = UnitEntity(
      id: 'crypt_ghoul_${DateTime.now().millisecondsSinceEpoch}',
      speciesId: 'decayed_ghoul',
      name: 'Crypt Sarcophagus Ghoul',
      generation: 1,
      archetype: Archetype.assassin,
      slot: FormationSlot.front2,
      level: 10,
      maxLevel: 10,
      currentHp: 650,
      maxHp: 650,
      attack: 160,
      defense: 90,
      speed: 118,
      nativeTraitId: 'shadow_strike',
      lineageAncestors: const [],
    );

    setState(() {
      _inventory.insert(0, cryptGhoul);
      _totalIchor += 250;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sarcophagus unsealed: Unlocked Crypt Ghoul & +250 Ichor!'),
        backgroundColor: Color(0xFFB3261E),
      ),
    );
  }

  void _onFusionComplete(UnitEntity child) {
    setState(() {
      _inventory.insert(0, child);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transmutation complete: ${child.name} added to Roster!'),
        backgroundColor: const Color(0xFFB3261E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlayerUnits = [
      ..._tickManager.allies,
      ..._inventory,
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Campaign Map
          CampaignMapScreen(
            nodes: _campaignNodes,
            onSelectNode: _onSelectCampaignNode,
            totalIchor: _totalIchor,
          ),
          // Tab 1: Tactical Arena
          BattleScreen(
            key: ValueKey(_tickManager),
            tickManager: _tickManager,
            combatService: _combatService,
            commandService: _commandService,
            onResetEncounter: () => setState(_resetEncounter),
            onVictory: _onCombatVictory,
          ),
          // Tab 2: Crucible Altar
          CrucibleScreen(
            availableInventory: allPlayerUnits,
            onFusionComplete: _onFusionComplete,
          ),
          // Tab 3: Brigade Roster
          _buildRosterScreen(allPlayerUnits),
          // Tab 4: Codices
          _buildCodexView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF14141B),
        selectedItemColor: const Color(0xFFB3261E),
        unselectedItemColor: const Color(0xFF8E8EA0),
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Campaign Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Battle Arena',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fireplace),
            label: 'Crucible Altar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt),
            label: 'Brigade Roster',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Affinity Codex',
          ),
        ],
      ),
    );
  }

  Widget _buildRosterScreen(List<UnitEntity> allUnits) {
    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181820),
        title: const Text(
          'YOUR LINEAGE ROSTER',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: allUnits.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final unit = allUnits[index];
          final inActiveSquad = _tickManager.allies.any((u) => u.id == unit.id);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181820),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: inActiveSquad ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
                width: inActiveSquad ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2B2B36),
                  child: Text(
                    'G${unit.generation}',
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            unit.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: inActiveSquad
                                  ? const Color(0xFFB3261E).withValues(alpha: 0.25)
                                  : const Color(0xFF424242),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              inActiveSquad ? 'ACTIVE BRIGADE' : 'RESERVE THRALL',
                              style: TextStyle(
                                color: inActiveSquad ? const Color(0xFFEF5350) : Colors.white60,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lv. ${unit.level}/${unit.maxLevel} • ATK: ${unit.attack} • DEF: ${unit.defense} • HP: ${unit.maxHp} • SPD: ${unit.speed}',
                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Native: ${unit.nativeTraitId.replaceAll('_', ' ').toUpperCase()}'
                        '${unit.graftedTraitId != null ? ' • Grafted: ${unit.graftedTraitId!.replaceAll('_', ' ').toUpperCase()}' : ''}',
                        style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCodexView() {
    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181820),
        title: const Text(
          'HEXAGONAL AFFINITY CODEX',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF181820),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2B2B36)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE 6-NODE DIRECTIONAL WHEEL',
                    style: TextStyle(
                      color: Color(0xFFE5A93C),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Clockwise +1: STRONG (+30% DMG, +15% Hit)\n'
                    'Counter-Clockwise -1: WEAK (-25% DMG, 25% Glancing Blow)\n'
                    'Opposites & Others: NEUTRAL (1.00x multiplier)',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildCodexItem(Archetype.juggernaut, 'Crushes Assassins (+30%). Weak to Occultist rot (-25%).'),
            _buildCodexItem(Archetype.assassin, 'Guts Marksmen (+30%). Weak to Juggernaut armor (-25%).'),
            _buildCodexItem(Archetype.marksman, 'Shoots down Skirmishers (+30%). Weak to Assassin burst (-25%).'),
            _buildCodexItem(Archetype.skirmisher, 'Dives onto Supports (+30%). Weak to Marksmen fire (-25%).'),
            _buildCodexItem(Archetype.support, 'Purges Occultists (+30%). Weak to Skirmisher dives (-25%).'),
            _buildCodexItem(Archetype.occultist, 'Melts Juggernauts (+30%). Weak to Support wards (-25%).'),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('RESTART TUTORIAL ENCOUNTER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B36),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _resetEncounter();
                    _currentIndex = 1;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodexItem(Archetype archetype, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2B2B36)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2B2B36),
            child: Text(
              archetype.name.substring(0, 3).toUpperCase(),
              style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archetype.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(description, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
