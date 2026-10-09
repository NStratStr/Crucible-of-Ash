import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../features/campaign/blood_altar_dialog.dart';
import '../../features/campaign/campaign_map_generator.dart';
import '../../features/campaign/campaign_map_screen.dart';
import '../../features/campaign/campaign_node.dart';
import '../../features/campaign/defiled_crypt_dialog.dart';
import '../../features/campaign/endgame_gauntlet_dialog.dart';
import '../../features/campaign/rest_haven_dialog.dart';
import '../../features/campaign/watchtower_dialog.dart';
import '../../features/combat/battle_screen.dart';
import '../../features/combat/combat_resolution_service.dart';
import '../../features/combat/initiative_tick_manager.dart';
import '../../features/crucible/crucible_screen.dart';
import '../../features/generals/general_command_service.dart';
import '../../features/generals/general_selection_dialog.dart';
import '../../features/persistence/game_state_persistence_service.dart';
import '../../features/relics/relic_forge_screen.dart';
import '../../features/relics/relic_service.dart';
import '../../features/ftue/awakening_dialog.dart';
import '../../features/ftue/ftue_guidance_banner.dart';
import '../../features/ftue/ftue_service.dart';
import '../../features/ftue/ftue_stage.dart';
import '../data/starter_brigades.dart';
import '../models/expedition_boon.dart';
import '../models/relic_entity.dart';
import '../models/unit_entity.dart';
import 'hexagonal_affinity_wheel_widget.dart';
import 'pedigree_inspector_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  int _totalIchor = 450;
  int _cursedOre = 75;
  int _bloodlineSigils = 2;
  final Set<ExpeditionBoon> _activeExpeditionBoons = {};
  GeneralType _activeGeneralType = GeneralType.vladislav;
  Map<GeneralType, int> _phylacteryRanks = {
    GeneralType.vladislav: 1,
    GeneralType.valeria: 1,
    GeneralType.malakor: 1,
    GeneralType.morrigan: 1,
  };
  int _currentChapter = 1;
  int _maxUnlockedChapter = 1;

  late InitiativeTickManager _tickManager;
  late CombatResolutionService _combatService;
  late GeneralCommandService _commandService;
  late RelicService _relicService;
  late FtueService _ftueService;
  late List<UnitEntity> _inventory;
  late List<CampaignNode> _campaignNodes;
  CampaignNode? _activeNode;
  final Set<EndgameTrialType> _clearedGauntletTrials = {};
  EndgameTrialType? _activeGauntletTrial;
  Archetype _codexSelectedArchetype = Archetype.juggernaut;
  bool _isInitialized = false;
  bool _isAscensionDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _relicService = RelicService();
    _ftueService = FtueService();
    _resetEncounter(null, BattleModifier.none, false);
    _inventory = StarterBrigades.createReserveInventory();
    _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);

    // Equip starter weapon to lead frontliner
    if (_tickManager.allies.isNotEmpty && _relicService.unequippedRelics.isNotEmpty) {
      _relicService.equipRelic(
        relicId: _relicService.unequippedRelics.first.id,
        unitId: _tickManager.allies.first.id,
      );
    }

    _ftueService.addListener(() {
      if (mounted) setState(() {});
    });

    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      final saved = await GameStatePersistenceService.load();
      if (saved != null && mounted) {
        setState(() {
          _totalIchor = saved.totalIchor;
          _cursedOre = saved.cursedOre;
          _bloodlineSigils = saved.bloodlineSigils;
          _activeGeneralType = saved.activeGeneralType;
          _phylacteryRanks = Map.from(saved.phylacteryRanks);
          _currentChapter = saved.currentChapter;
          _maxUnlockedChapter = saved.maxUnlockedChapter;
          _clearedGauntletTrials.clear();
          _clearedGauntletTrials.addAll(saved.clearedGauntletTrials);

          if (saved.allies.isNotEmpty) {
            _tickManager.dispose();
            _commandService.dispose();
            _tickManager = InitiativeTickManager(
              initialAllies: saved.allies,
              initialEnemies: StarterBrigades.createTutorialEnemies(),
              tickInterval: const Duration(milliseconds: 140),
            );
            _commandService = GeneralCommandService(
              tickManager: _tickManager,
              generalType: _activeGeneralType,
              initialFocus: (_phylacteryRanks[_activeGeneralType] ?? 1) >= 3 ? 2 : 1,
              initialPhylacteryRanks: _phylacteryRanks,
            );
            _combatService = CombatResolutionService(
              tickManager: _tickManager,
              commandService: _commandService,
              relicService: _relicService,
            );
            _tickManager.start();
          }

          if (saved.reserveInventory.isNotEmpty) {
            _inventory = saved.reserveInventory;
          }

          if (saved.relics.isNotEmpty) {
            _relicService.setAllRelics(saved.relics);
          }
        });
      }
    } catch (e) {
      debugPrint('Error restoring saved state: $e');
    }
  }

  Future<void> _saveCurrentState() async {
    try {
      final data = GameSaveData(
        totalIchor: _totalIchor,
        cursedOre: _cursedOre,
        bloodlineSigils: _bloodlineSigils,
        activeGeneralType: _activeGeneralType,
        phylacteryRanks: _phylacteryRanks,
        currentChapter: _currentChapter,
        maxUnlockedChapter: _maxUnlockedChapter,
        allies: _tickManager.allies,
        reserveInventory: _inventory,
        relics: _relicService.allRelics,
        clearedGauntletTrials: _clearedGauntletTrials,
        lastSavedTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await GameStatePersistenceService.save(data);
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  void _resetEncounter([
    List<UnitEntity>? customEnemies,
    BattleModifier battleModifier = BattleModifier.none,
    bool preserveSquad = true,
  ]) {
    List<UnitEntity> allies;
    if (preserveSquad && _isInitialized && _tickManager.allies.isNotEmpty) {
      allies = _tickManager.allies.map((u) => u.copyWith(
        currentHp: u.currentHp <= 0 ? (u.maxHp * 0.5).round() : u.currentHp,
        turnMeter: 0.0,
        activeEffects: const [],
      )).toList();
    } else {
      allies = StarterBrigades.createPlayerSquad();
    }
    _isInitialized = true;
    final enemies = customEnemies ?? StarterBrigades.createTutorialEnemies();

    _tickManager = InitiativeTickManager(
      initialAllies: allies,
      initialEnemies: enemies,
      tickInterval: const Duration(milliseconds: 140),
    );

    final startingFocus = (_phylacteryRanks[_activeGeneralType] ?? 1) >= 3 ? 2 : 1;

    _commandService = GeneralCommandService(
      tickManager: _tickManager,
      generalType: _activeGeneralType,
      initialFocus: startingFocus,
      initialPhylacteryRanks: _phylacteryRanks,
    );

    _combatService = CombatResolutionService(
      tickManager: _tickManager,
      commandService: _commandService,
      relicService: _relicService,
      battleModifier: battleModifier,
      activeBoons: _activeExpeditionBoons,
    );

    _tickManager.start();
  }

  @override
  void dispose() {
    _tickManager.dispose();
    _commandService.dispose();
    _relicService.dispose();
    _ftueService.dispose();
    super.dispose();
  }

  void _launchFtueEncounter(int step) {
    List<UnitEntity> enemies;
    String name;
    String desc;
    int ichorReward;

    switch (step) {
      case 1:
        enemies = StarterBrigades.createFtueEncounter1Enemies();
        name = 'Screen 2: The Ashlands (Tutorial Skirmish)';
        desc = 'Tutorial skirmish teaching Speed ticks and Vanguard/Arcanum layout.';
        ichorReward = 150;
        break;
      case 2:
        enemies = StarterBrigades.createFtueEncounter2Enemies();
        name = 'Screen 3: Ironwatch Outpost (Affinity Check)';
        desc = 'Affinity trial teaching the 6-role Hex Wheel and Commander Focus.';
        ichorReward = 200;
        break;
      case 3:
      default:
        enemies = StarterBrigades.createFtueGatekeeperEnemies();
        name = 'Screen 5: The Ashen Gatekeeper Colossus';
        desc = 'Gatekeeper boss battle to unleash your newly evolved Gen 2 Cerberus Spawn!';
        ichorReward = 500;
        break;
    }

    final ftueNode = CampaignNode(
      id: 'ftue_node_$step',
      depth: step,
      verticalRatio: 0.5,
      type: step == 3 ? CampaignNodeType.boss : CampaignNodeType.skirmish,
      name: name,
      description: desc,
      nextNodeIds: const [],
      rewardIchor: ichorReward,
      isCurrent: true,
      isReachable: true,
    );

    setState(() {
      _activeNode = ftueNode;
      _resetEncounter(enemies);
      _currentIndex = 1; // Switch to Battle Arena
    });
  }

  void _handleLaunchFtueStageAction() {
    switch (_ftueService.currentStage) {
      case FtueStage.awakening:
        _showAwakeningDialog();
        break;
      case FtueStage.encounter1:
        _launchFtueEncounter(1);
        break;
      case FtueStage.encounter2:
        _launchFtueEncounter(2);
        break;
      case FtueStage.crucibleFusion:
        setState(() => _currentIndex = 2); // Switch to Crucible Altar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The Crucible awaits! Select Feral War-Hound Alpha and Beta to fuse Gen 2 Cerberus Spawn.'),
            backgroundColor: Color(0xFFB3261E),
          ),
        );
        break;
      case FtueStage.encounter3:
        _launchFtueEncounter(3);
        break;
      case FtueStage.completed:
        _showAwakeningDialog();
        break;
    }
  }

  Future<void> _showAwakeningDialog() async {
    final chosen = await AwakeningDialog.show(
      context,
      initialSelected: _activeGeneralType,
    );
    if (!mounted || chosen == null) return;

    setState(() {
      _activeGeneralType = chosen;
      _commandService.setActiveGeneral(chosen);
      if (_ftueService.currentStage == FtueStage.awakening) {
        _ftueService.advanceStage();
      }
    });

    final profile = _commandService.currentProfile;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Covenant sealed with ${profile.name}! Starter brigade bound under ${profile.auraName}.'),
        backgroundColor: profile.themeColor,
      ),
    );
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
        enemies = StarterBrigades.createChapterBossEnemies(_currentChapter);
      } else if (node.type == CampaignNodeType.elite) {
        enemies = StarterBrigades.createEliteEnemiesForChapter(_currentChapter);
      } else {
        enemies = StarterBrigades.createSkirmishEnemiesForChapter(_currentChapter);
      }

      // If all allies were fallen, revive squad before entering next battle
      if (_tickManager.allies.every((u) => !u.isAlive)) {
        final revived = _tickManager.allies.map((u) => u.copyWith(currentHp: u.maxHp)).toList();
        _tickManager.updateSquads(allies: revived);
      }

      _resetEncounter(enemies, BattleModifier.none, true);
      setState(() {
        _currentIndex = 1; // Switch to Combat Arena
      });
    } else if (node.type == CampaignNodeType.altar) {
      _handleBloodAltarNode(node);
    } else if (node.type == CampaignNodeType.crypt) {
      _handleDefiledCryptNode(node);
    } else if (node.type == CampaignNodeType.restHaven) {
      _handleRestHavenNode(node);
    } else if (node.type == CampaignNodeType.watchtower) {
      _handleWatchtowerNode(node);
    }
  }

  void _handleRestHavenNode(CampaignNode node) {
    RestHavenDialog.show(
      context: context,
      node: node,
      onHealSquad: _healSquad,
      relicService: _relicService,
      onGrantXp: () => _grantBrigadeXp(400),
      onDismiss: () => _markNodeCompleted(node.id),
    );
  }

  void _handleWatchtowerNode(CampaignNode node) {
    WatchtowerDialog.show(
      context: context,
      node: node,
      relicService: _relicService,
      commandService: _commandService,
      onGainIchor: (amount) => setState(() => _totalIchor += amount),
      onGainOre: (amount) => setState(() => _cursedOre += amount),
      onScoutForwardNodes: _scoutForwardCampaignNodes,
      onDismiss: () => _markNodeCompleted(node.id),
    );
  }

  void _scoutForwardCampaignNodes() {
    setState(() {
      _campaignNodes = _campaignNodes.map((n) {
        if (!n.isVisited) {
          return n.copyWith(isScouted: true);
        }
        return n;
      }).toList();
    });
  }

  List<String> _grantBrigadeXp(int amount) {
    final List<String> levelUps = [];
    final leveled = _tickManager.allies.map((u) {
      final oldLevel = u.level;
      final updated = u.addXp(amount);
      if (updated.level > oldLevel) {
        levelUps.add('${updated.name} (Lv. $oldLevel➔${updated.level})');
      }
      return updated;
    }).toList();
    _tickManager.updateSquads(allies: leveled);

    // Award 50% training XP to reserve thralls in inventory so they progress towards max level
    final reserveXp = (amount * 0.5).round();
    if (reserveXp > 0 && _inventory.isNotEmpty) {
      _inventory = _inventory.map((u) {
        final oldLevel = u.level;
        final updated = u.addXp(reserveXp);
        if (updated.level > oldLevel) {
          levelUps.add('${updated.name} [Reserve] (Lv. $oldLevel➔${updated.level})');
        }
        return updated;
      }).toList();
    }

    return levelUps;
  }

  Future<void> _handleBloodAltarNode(CampaignNode node) async {
    final livingAllies = _tickManager.allies.where((u) => u.isAlive).toList();
    final choice = await BloodAltarDialog.show(context, squadLivingCount: livingAllies.length);

    if (!mounted || choice == null) return;

    if (choice == BloodAltarChoice.bloodTithe) {
      final sacrificedAllies = _tickManager.allies.map((u) {
        if (!u.isAlive) return u;
        final sacrifice = max(1, (u.currentHp * 0.25).round());
        return u.copyWith(currentHp: max(1, u.currentHp - sacrifice));
      }).toList();

      _tickManager.updateSquads(allies: sacrificedAllies);

      setState(() {
        _totalIchor += 350;
      });
      _commandService.grantFocus(2);
      _markNodeCompleted(node.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood Tithe accepted: Sacrificed 25% HP for +350 Ichor and +2 Focus!'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
    } else if (choice == BloodAltarChoice.sanguineOffering) {
      final sacrificedAllies = _tickManager.allies.map((u) {
        if (!u.isAlive) return u;
        final sacrifice = max(1, (u.currentHp * 0.40).round());
        return u.copyWith(currentHp: max(1, u.currentHp - sacrifice));
      }).toList();

      _tickManager.updateSquads(allies: sacrificedAllies);

      final epicRelic = _relicService.forgeRandomRelic(rarity: RelicRarity.epic);
      _markNodeCompleted(node.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offering forged: Sacrificed 40% HP to manifest ${epicRelic.name}!'),
          backgroundColor: const Color(0xFFAB47BC),
        ),
      );
    } else if (choice == BloodAltarChoice.covenantBlessing) {
      final sacrificedAllies = _tickManager.allies.map((u) {
        if (!u.isAlive) return u;
        final sacrifice = max(1, (u.currentHp * 0.30).round());
        return u.copyWith(currentHp: max(1, u.currentHp - sacrifice));
      }).toList();

      _tickManager.updateSquads(allies: sacrificedAllies);

      setState(() {
        _activeExpeditionBoons.add(ExpeditionBoon.sanguineCovenant);
      });
      _combatService = CombatResolutionService(
        tickManager: _tickManager,
        commandService: _commandService,
        relicService: _relicService,
        battleModifier: _combatService.battleModifier,
        activeBoons: _activeExpeditionBoons,
      );
      _markNodeCompleted(node.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Covenant Sealed: Sacrificed 30% HP for permanent +15% Attack & +25% Crit DMG this expedition!'),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
    } else {
      _markNodeCompleted(node.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You departed the altar untouched by the dark entity.'),
          backgroundColor: Color(0xFF424242),
        ),
      );
    }
  }

  Future<void> _handleDefiledCryptNode(CampaignNode node) async {
    final choice = await DefiledCryptDialog.show(context);
    if (!mounted || choice == null) return;

    if (choice == DefiledCryptChoice.desecrateTomb) {
      final isSuccess = Random().nextDouble() < 0.60;
      if (isSuccess) {
        final relic = _relicService.forgeRandomRelic(rarity: RelicRarity.rare);
        setState(() {
          _totalIchor += 250;
        });
        _markNodeCompleted(node.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tomb desecrated! Plundered ${relic.displayName} & +250 Ichor.'),
            backgroundColor: const Color(0xFFFFB300),
          ),
        );
      } else {
        // 40% Necrotic Miasma Trap trigger: Afflict brigade (-15% current HP)
        final afflictedAllies = _tickManager.allies.map((u) {
          if (!u.isAlive) return u;
          final hpLoss = (u.currentHp * 0.15).round();
          return u.copyWith(currentHp: max(1, u.currentHp - hpLoss));
        }).toList();

        _tickManager.updateSquads(allies: afflictedAllies);

        setState(() {
          _totalIchor += 350;
        });
        _markNodeCompleted(node.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TRAP TRIGGERED! Necrotic Miasma afflicted brigade (-15% HP), but extracted +350 Ichor!'),
            backgroundColor: Color(0xFFB3261E),
          ),
        );
      }
      _saveCurrentState();
    } else if (choice == DefiledCryptChoice.rebindThrall) {
      _unlockCryptThrall();
      _markNodeCompleted(node.id);
      _saveCurrentState();
    } else if (choice == DefiledCryptChoice.purifyTomb) {
      final healed = _tickManager.allies.map((u) {
        if (!u.isAlive) return u;
        final heal = (u.maxHp * 0.40).round();
        return u.copyWith(currentHp: min(u.maxHp, u.currentHp + heal));
      }).toList();

      _tickManager.updateSquads(allies: healed);
      _markNodeCompleted(node.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purification rites performed: Restored 40% squad HP!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _saveCurrentState();
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
    final reward = _activeNode?.rewardIchor ?? 150;
    final oreReward = _activeNode?.rewardOre ?? 15;
    final sigilsReward = _activeNode?.rewardSigils ?? 0;
    final xpReward = _activeNode == null
        ? 350
        : (_activeNode!.type == CampaignNodeType.boss
            ? 1000
            : (_activeNode!.type == CampaignNodeType.elite ? 500 : 250));
    final levelUps = _grantBrigadeXp(xpReward);

    setState(() {
      _totalIchor += reward;
      _cursedOre += oreReward;
      _bloodlineSigils += sigilsReward;
    });
    if (_activeNode != null) {
      _markNodeCompleted(_activeNode!.id);
    }

      UnitEntity? purebloodDrop;
      if (_activeNode?.name.contains('Tomb of the Deathless') == true) {
        purebloodDrop = StarterBrigades.createDeathlessCryptReward();
        setState(() {
          _inventory.insert(0, purebloodDrop!);
        });
      } else if (_activeNode?.name.contains('Lineage Crypt') == true) {
        purebloodDrop = StarterBrigades.createPurebloodCryptReward();
        setState(() {
          _inventory.insert(0, purebloodDrop!);
        });
      }

      final captured = _captureThrallAfterBattle(scoutedAffinities: _activeNode?.scoutedAffinities);

      bool isFirstConquest = false;
      if (_activeGauntletTrial != null) {
        if (!_clearedGauntletTrials.contains(_activeGauntletTrial)) {
          isFirstConquest = true;
          _clearedGauntletTrials.add(_activeGauntletTrial!);
          setState(() {
            _bloodlineSigils += 1;
            _totalIchor += 500;
          });
        }
        _activeGauntletTrial = null;
      }

      String extraReward = '';
      if (levelUps.isNotEmpty) {
        extraReward += ' • LEVEL UP: ${levelUps.join(", ")}';
      }
      if (isFirstConquest) {
        extraReward += ' • FIRST CONQUEST BONUS (+1 Sigil, +500 Ichor)';
      }
      if (sigilsReward > 0) {
        extraReward += ' • +$sigilsReward Sigil(s)';
      }
      if (purebloodDrop != null) {
        extraReward += ' • PINNACLE LINEAGE: ${purebloodDrop.name} (PUREBLOOD GEN 4)!';
      }
      if (_activeNode?.type == CampaignNodeType.elite) {
        final drop = _relicService.forgeRandomRelic(rarity: RelicRarity.epic);
        extraReward += ' • Dropped ${drop.displayName}!';
      } else if (_activeNode?.type == CampaignNodeType.boss) {
        final drop = _relicService.forgeRandomRelic(rarity: RelicRarity.legendary);
        extraReward += ' • LEGENDARY DROP: ${drop.displayName}!';
      }

      if (_ftueService.currentStage == FtueStage.encounter1) {
        _ftueService.advanceStage();
      } else if (_ftueService.currentStage == FtueStage.encounter2) {
        _ftueService.advanceStage();
      } else if (_ftueService.currentStage == FtueStage.encounter3) {
        _ftueService.advanceStage();
      }

      if (_activeNode?.type == CampaignNodeType.boss && _currentChapter < 3) {
        final nextCh = _currentChapter + 1;
        if (_maxUnlockedChapter < nextCh) {
          setState(() {
            _maxUnlockedChapter = nextCh;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showChapterAscensionDialog(nextCh);
          }
        });
      } else {
        setState(() {
          _currentIndex = 0;
          _activeNode = null;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EXPEDITION VICTORY! +$reward Ichor, +$oreReward Ore, +$xpReward XP • Bound ${captured.name} (${captured.archetype.name.toUpperCase()})$extraReward'),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 4),
        ),
      );
      _saveCurrentState();
  }

  void _showChapterAscensionDialog(int nextChapter) {
    if (_isAscensionDialogOpen) return;
    _isAscensionDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5A93C), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Color(0xFFE5A93C), size: 24),
            const SizedBox(width: 8),
            Text(
              'CHAPTER $_currentChapter CONQUERED!',
              style: const TextStyle(
                color: Color(0xFFE5A93C),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The primordial guardian of ${CampaignMapScreen.chapterTitle(_currentChapter)} has fallen! The seal dissolves into ashen dust.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111114),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB3261E).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_circle_right_outlined, color: Color(0xFFB3261E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'UNLOCKED: ${CampaignMapScreen.chapterTitle(nextChapter)}',
                      style: const TextStyle(
                        color: Color(0xFFEF5350),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _isAscensionDialogOpen = false;
              setState(() {
                _currentIndex = 0; // Return to Campaign Map
                _activeNode = null;
              });
            },
            child: const Text('REMAIN HERE', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.explore, size: 16),
            label: Text('ASCEND TO CHAPTER $nextChapter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _isAscensionDialogOpen = false;
              setState(() {
                _currentChapter = nextChapter;
                _activeExpeditionBoons.clear();
                _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(nextChapter);
                _currentIndex = 0; // Return to Campaign Map
                _activeNode = null;
              });
            },
          ),
        ],
      ),
    ).then((_) {
      _isAscensionDialogOpen = false;
    });
  }

  void _onCombatDefeat() {
    _activeGauntletTrial = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.dangerous, color: Color(0xFFEF5350), size: 24),
            SizedBox(width: 8),
            Text(
              'BRIGADE VANQUISHED',
              style: TextStyle(
                color: Color(0xFFEF5350),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All bloodline vessels have fallen in battle. The shadows claim your expedition in ${CampaignMapScreen.chapterTitle(_currentChapter)}.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111114),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB3261E).withValues(alpha: 0.5)),
              ),
              child: const Text(
                'Your vessels retreat to the Ashen Encampment to mend mortal wounds. Regroup, refine armaments, and begin a new descent.',
                style: TextStyle(color: Color(0xFFE5A93C), fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('RETURN TO CAMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                final revivedAllies = _tickManager.allies.map((u) => u.copyWith(currentHp: u.maxHp)).toList();
                _tickManager.updateSquads(allies: revivedAllies);
                _activeExpeditionBoons.clear();
                _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);
                _activeNode = null;
                _currentIndex = 0; // Return to campaign map
              });
            },
          ),
        ],
      ),
    );
  }

  void _showDeployThrallDialog(UnitEntity reserveThrall) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFFE5A93C), width: 1.5),
      ),
      builder: (ctx) {
        final activeAllies = _tickManager.allies;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Color(0xFFE5A93C), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DEPLOY ${reserveThrall.name.toUpperCase()} TO BRIGADE',
                      style: const TextStyle(
                        color: Color(0xFFE5A93C),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose an active squad position to replace. The displaced vessel will return to your reserve inventory.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
              ),
              const SizedBox(height: 12),
              ...activeAllies.map((activeUnit) {
                final isVanguard = activeUnit.isVanguard;
                final slotLabel = activeUnit.slot.name.toUpperCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111114),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVanguard ? const Color(0xFFB3261E).withValues(alpha: 0.6) : const Color(0xFF1976D2).withValues(alpha: 0.6),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVanguard ? const Color(0xFFB3261E).withValues(alpha: 0.3) : const Color(0xFF1976D2).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVanguard ? 'VAN ($slotLabel)' : 'ARC ($slotLabel)',
                        style: TextStyle(
                          color: isVanguard ? const Color(0xFFEF5350) : const Color(0xFF64B5F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    title: Text(
                      activeUnit.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text(
                      'G${activeUnit.generation} ${activeUnit.archetype.name.toUpperCase()} • HP: ${activeUnit.currentHp}/${activeUnit.maxHp} • ATK: ${activeUnit.attack}',
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
                        Navigator.pop(ctx);
                        _deployThrallToSlot(reserveThrall, activeUnit);
                      },
                      child: const Text('REPLACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

  void _deployThrallToSlot(UnitEntity incomingThrall, UnitEntity outgoingUnit) {
    setState(() {
      final deployedThrall = incomingThrall.copyWith(slot: outgoingUnit.slot);
      _inventory.removeWhere((u) => u.id == incomingThrall.id);
      _inventory.insert(0, outgoingUnit);

      final newAllies = _tickManager.allies.map((u) {
        if (u.id == outgoingUnit.id) return deployedThrall;
        return u;
      }).toList();

      _tickManager.updateSquads(allies: newAllies);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vessel Deployed: Bound ${incomingThrall.name} to ${outgoingUnit.slot.name.toUpperCase()} (Replaced ${outgoingUnit.name})!'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
    );
    _saveCurrentState();
  }

  void _levelUpUnit({
    required String unitId,
    required int xpAmount,
    required int ichorCost,
  }) {
    if (_totalIchor < ichorCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Ichor! Requires $ichorCost Ichor, but you have $_totalIchor.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    UnitEntity? updatedUnit;

    // 1. Check active squad
    final allyIndex = _tickManager.allies.indexWhere((u) => u.id == unitId);
    if (allyIndex != -1) {
      final ally = _tickManager.allies[allyIndex];
      final leveled = ally.addXp(xpAmount);
      updatedUnit = leveled;

      final newAllies = List<UnitEntity>.from(_tickManager.allies);
      newAllies[allyIndex] = leveled;
      _tickManager.updateSquads(allies: newAllies);
    } else {
      // 2. Check reserve inventory
      final invIndex = _inventory.indexWhere((u) => u.id == unitId);
      if (invIndex != -1) {
        final unit = _inventory[invIndex];
        final leveled = unit.addXp(xpAmount);
        updatedUnit = leveled;

        _inventory[invIndex] = leveled;
      }
    }

    if (updatedUnit != null) {
      setState(() {
        _totalIchor -= ichorCost;
      });
      _saveCurrentState();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedUnit.isMaxLevel
                ? '👑 ${updatedUnit.name} reached MAX LEVEL ${updatedUnit.maxLevel}! 10% Inheritance Unlocked!'
                : '✦ ${updatedUnit.name} infused with $xpAmount XP (Lv. ${updatedUnit.level}/${updatedUnit.maxLevel})!',
          ),
          backgroundColor: updatedUnit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  UnitEntity _captureThrallAfterBattle({List<Archetype>? scoutedAffinities}) {
    Archetype? targetRole;
    if (scoutedAffinities != null && scoutedAffinities.isNotEmpty) {
      targetRole = scoutedAffinities[DateTime.now().millisecond % scoutedAffinities.length];
    }
    final newThrall = StarterBrigades.createCapturedThrall(archetype: targetRole);

    setState(() {
      _inventory.insert(0, newThrall);
    });
    return newThrall;
  }

  void _healSquad() {
    final healed = _tickManager.allies.map((u) {
      if (!u.isAlive) {
        return u.copyWith(currentHp: max(1, (u.maxHp * 0.40).round()));
      }
      final heal = (u.maxHp * 0.40).round();
      return u.copyWith(currentHp: min(u.maxHp, u.currentHp + heal));
    }).toList();
    _tickManager.updateSquads(allies: healed);
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

  void _onFusionExecuted(UnitEntity child, List<String> sacrificedParentIds) {
    setState(() {
      final activeAllies = List<UnitEntity>.from(_tickManager.allies);
      int replacedIndex = -1;

      // Check if one of the sacrificed parents was in the active squad
      for (int i = 0; i < activeAllies.length; i++) {
        if (sacrificedParentIds.contains(activeAllies[i].id)) {
          if (replacedIndex == -1) {
            replacedIndex = i; // Place child in this active slot
          }
        }
      }

      if (replacedIndex != -1) {
        final slot = activeAllies[replacedIndex].slot;
        final placedChild = child.copyWith(slot: slot);
        activeAllies[replacedIndex] = placedChild;

        // If both parents were fielded in the active brigade, replace the second
        for (int i = 0; i < activeAllies.length; i++) {
          if (i != replacedIndex && sacrificedParentIds.contains(activeAllies[i].id)) {
            final replacement = _inventory.firstWhere(
              (u) => !sacrificedParentIds.contains(u.id) && !activeAllies.any((a) => a.id == u.id),
              orElse: () => StarterBrigades.createPlayerSquad().first,
            );
            activeAllies[i] = replacement.copyWith(slot: activeAllies[i].slot);
          }
        }
        _tickManager.updateSquads(allies: activeAllies);
      } else {
        _inventory.insert(0, child);
      }

      // Remove sacrificed parents from inventory
      _inventory.removeWhere((u) => sacrificedParentIds.contains(u.id));
    });

    if (_ftueService.currentStage == FtueStage.crucibleFusion) {
      _ftueService.advanceStage();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          child.isPureblood
              ? '👑 PUREBLOOD CONSECRATION: ${child.name} has ascended!'
              : 'Transmutation complete: ${child.name} forged in the Crucible!',
        ),
        backgroundColor: child.isPureblood ? const Color(0xFFFF8F00) : const Color(0xFFB3261E),
      ),
    );
    _saveCurrentState();
  }

  void _onFusionComplete(UnitEntity child) {
    setState(() {
      _inventory.insert(0, child);
    });

    if (_ftueService.currentStage == FtueStage.crucibleFusion) {
      _ftueService.advanceStage();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transmutation complete: ${child.name} added to Roster!'),
        backgroundColor: const Color(0xFFB3261E),
      ),
    );
    _saveCurrentState();
  }

  Future<void> _handleOpenEndgameGauntlet() async {
    final trial = await EndgameGauntletDialog.show(
      context,
      activeSquad: _tickManager.allies,
      clearedTrials: _clearedGauntletTrials,
    );
    if (!mounted || trial == null) return;
    _activeGauntletTrial = trial;

    List<UnitEntity> enemies;
    String trialName;
    int rewardIchor;
    int rewardOre;
    int rewardSigils;
    BattleModifier modifier;
    switch (trial) {
      case EndgameTrialType.worldTitan:
        enemies = StarterBrigades.createWorldTitanEnemies();
        trialName = 'The Ashen World Titan';
        rewardIchor = 2000;
        rewardOre = 150;
        rewardSigils = 3;
        modifier = BattleModifier.titanicFury;
        break;
      case EndgameTrialType.lineageCrypt:
        enemies = StarterBrigades.createLineageCryptEnemies();
        trialName = 'Lineage Crypt: Den of Fangs';
        rewardIchor = 800;
        rewardOre = 60;
        rewardSigils = 1;
        modifier = BattleModifier.bloodMoon;
        break;
      case EndgameTrialType.deathlessCrypt:
        enemies = StarterBrigades.createDeathlessCryptEnemies();
        trialName = 'Lineage Crypt: Tomb of the Deathless';
        rewardIchor = 900;
        rewardOre = 75;
        rewardSigils = 2;
        modifier = BattleModifier.corrosiveMiasma;
        break;
      case EndgameTrialType.abyssalDescent:
        enemies = StarterBrigades.createAbyssalDescentEnemies();
        trialName = 'Abyssal Descent: Torment I';
        rewardIchor = 1200;
        rewardOre = 90;
        rewardSigils = 2;
        modifier = BattleModifier.corrosiveMiasma;
        break;
      case EndgameTrialType.abyssalDescentII:
        enemies = StarterBrigades.createAbyssalDescentTier2Enemies();
        trialName = 'Abyssal Descent: Torment II';
        rewardIchor = 1600;
        rewardOre = 120;
        rewardSigils = 2;
        modifier = BattleModifier.voidCorruption;
        break;
      case EndgameTrialType.abyssalDescentIII:
        enemies = StarterBrigades.createAbyssalDescentTier3Enemies();
        trialName = 'Abyssal Descent: Torment III';
        rewardIchor = 2500;
        rewardOre = 180;
        rewardSigils = 3;
        modifier = BattleModifier.abyssalEclipse;
        break;
    }

    final gauntletNode = CampaignNode(
      id: 'gauntlet_${DateTime.now().millisecondsSinceEpoch}',
      depth: 4,
      verticalRatio: 0.5,
      type: CampaignNodeType.boss,
      name: trialName,
      description: 'High-stakes Endgame Gauntlet trial.',
      nextNodeIds: const [],
      rewardIchor: rewardIchor,
      rewardOre: rewardOre,
      rewardSigils: rewardSigils,
      isCurrent: true,
      isReachable: true,
    );

    setState(() {
      _activeNode = gauntletNode;
      _resetEncounter(enemies, modifier);
      _currentIndex = 1; // Switch to Battle Arena
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Engaged $trialName! The Gauntlet awakens.'),
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
      body: SafeArea(
        child: Column(
          children: [
            if (_currentIndex != 1)
              FtueGuidanceBanner(
                ftueService: _ftueService,
                onLaunchStageAction: _handleLaunchFtueStageAction,
                onReplayAwakening: _showAwakeningDialog,
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  // Tab 0: Campaign Map
                  CampaignMapScreen(
                    nodes: _campaignNodes,
                    onSelectNode: _onSelectCampaignNode,
                    totalIchor: _totalIchor,
                    cursedOre: _cursedOre,
                    bloodlineSigils: _bloodlineSigils,
                    activeBoons: _activeExpeditionBoons,
                    onOpenEndgameGauntlet: _handleOpenEndgameGauntlet,
                    currentChapter: _currentChapter,
                    maxUnlockedChapter: _maxUnlockedChapter,
                    onChapterChanged: (ch) => setState(() {
                      _currentChapter = ch;
                      _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(ch);
                    }),
                  ),
                  // Tab 1: Tactical Arena
                  BattleScreen(
                    key: ValueKey(_tickManager),
                    tickManager: _tickManager,
                    combatService: _combatService,
                    commandService: _commandService,
                    relicService: _relicService,
                    bloodlineSigils: _bloodlineSigils,
                    onSigilsChanged: (val) => setState(() => _bloodlineSigils = val),
                    onResetEncounter: () => setState(_resetEncounter),
                    onVictory: _onCombatVictory,
                    onDefeat: _onCombatDefeat,
                  ),
                  // Tab 2: Crucible Altar
                  CrucibleScreen(
                    availableInventory: allPlayerUnits,
                    totalIchor: _totalIchor,
                    bloodlineSigils: _bloodlineSigils,
                    onIchorChanged: (val) => setState(() => _totalIchor = val),
                    onSigilsChanged: (val) => setState(() => _bloodlineSigils = val),
                    onFusionExecuted: _onFusionExecuted,
                    onFusionComplete: _onFusionComplete,
                    onUnitLeveled: (updatedUnit, cost) => _levelUpUnit(
                      unitId: updatedUnit.id,
                      xpAmount: cost,
                      ichorCost: cost,
                    ),
                  ),
                  // Tab 3: Relic Forge
                  RelicForgeScreen(
                    relicService: _relicService,
                    brigadeUnits: allPlayerUnits,
                    totalIchor: _totalIchor,
                    cursedOre: _cursedOre,
                    onIchorChanged: (val) => setState(() => _totalIchor = val),
                    onOreChanged: (val) => setState(() => _cursedOre = val),
                  ),
                  // Tab 4: Brigade Roster
                  _buildRosterScreen(allPlayerUnits),
                  // Tab 5: Codices
                  _buildCodexView(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF14141B),
        selectedItemColor: const Color(0xFFB3261E),
        unselectedItemColor: const Color(0xFF8E8EA0),
        selectedFontSize: 10,
        unselectedFontSize: 9,
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
            icon: Icon(Icons.auto_awesome),
            label: 'Relic Forge',
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

  Future<void> _showGeneralSelectionDialog() async {
    final chosen = await GeneralSelectionDialog.show(
      context,
      currentGeneralType: _commandService.activeGeneralType,
      commandService: _commandService,
      bloodlineSigils: _bloodlineSigils,
      onSigilsChanged: (val) => setState(() => _bloodlineSigils = val),
    );
    if (!mounted || chosen == null) return;

    setState(() {
      _activeGeneralType = chosen;
      _commandService.setActiveGeneral(chosen);
      _phylacteryRanks = Map.of(_commandService.allPhylacteryRanks);
    });
    final profile = _commandService.currentProfile;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${profile.name} took command of the Brigade!'),
        backgroundColor: profile.themeColor,
      ),
    );
  }

  Widget _buildRosterScreen(List<UnitEntity> allUnits) {
    final profile = _commandService.currentProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181820),
        title: const Text(
          'YOUR LINEAGE ROSTER',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Save Lineage Progress',
            icon: const Icon(Icons.save_outlined, size: 20, color: Color(0xFF81C784)),
            onPressed: () async {
              await _saveCurrentState();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Progression saved: Brigade roster, lineage, and currencies secured!'),
                    backgroundColor: Color(0xFF1B5E20),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Commander Bar
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: profile.themeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: profile.themeColor, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: profile.themeColor.withValues(alpha: 0.3),
                  child: Icon(profile.icon, color: profile.themeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${profile.title}',
                            style: TextStyle(color: profile.themeColor, fontSize: 9.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AURA: ${profile.auraName} — ${profile.auraDescription}',
                        style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _showGeneralSelectionDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: profile.themeColor),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('SWITCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'THRALLS & PROGENITORS (${allUnits.length})',
                          style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3261E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE57373), width: 0.8),
                          ),
                          child: Text(
                            '$_totalIchor ICHOR',
                            style: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'TAP UNIT TO INSPECT PEDIGREE',
                      style: TextStyle(color: Color(0xFFE5A93C), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 3), // Switch to Relic Forge
                  child: const Text(
                    'OPEN FORGE ➔',
                    style: TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              itemCount: allUnits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final unit = allUnits[index];
                final inActiveSquad = _tickManager.allies.any((u) => u.id == unit.id);
                final relics = _relicService.getRelicsForUnit(unit.id);

                return InkWell(
                  onTap: () => PedigreeInspectorDialog.show(
                    context,
                    unit,
                    relicService: _relicService,
                    totalIchor: _totalIchor,
                    onLevelUp: (updatedUnit, cost) => _levelUpUnit(
                      unitId: updatedUnit.id,
                      xpAmount: cost,
                      ichorCost: cost,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
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
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                  bottom: Radius.circular(4),
                                ),
                                border: Border.all(
                                  color: inActiveSquad
                                      ? const Color(0xFFB3261E)
                                      : (unit.isPureblood
                                          ? const Color(0xFFFF5252)
                                          : _getArchetypeColor(unit.archetype).withValues(alpha: 0.7)),
                                  width: unit.isPureblood || inActiveSquad ? 1.6 : 1.2,
                                ),
                                boxShadow: [
                                  if (unit.isPureblood)
                                    BoxShadow(
                                      color: const Color(0xFFFF1744).withValues(alpha: 0.45),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  const BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.3),
                                  radius: 0.85,
                                  colors: [
                                    _getArchetypeColor(unit.archetype).withValues(alpha: 0.35),
                                    const Color(0xFF13131A),
                                    const Color(0xFF09090D),
                                  ],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(11),
                                  bottom: Radius.circular(3),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        unit.effectiveAvatarAsset,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFF2B2B36),
                                          child: const Icon(Icons.shield, color: Colors.white24, size: 24),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: const [0.0, 0.65, 1.0],
                                            colors: [
                                              Colors.black.withValues(alpha: 0.1),
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.75),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE5A93C), width: 0.8),
                              ),
                              child: Text(
                                'G${unit.generation}',
                                style: const TextStyle(
                                  color: Color(0xFFE5A93C),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Native: ${unit.nativeTraitId.replaceAll('_', ' ').toUpperCase()}'
                                      '${unit.graftedTraitId != null ? ' • Grafted: ${unit.graftedTraitId!.replaceAll('_', ' ').toUpperCase()}' : ''}',
                                      style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (relics.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: const Color(0xFF2E7D32), width: 0.8),
                                      ),
                                      child: Text(
                                        '${relics.length} RELIC${relics.length > 1 ? "S" : ""}',
                                        style: const TextStyle(color: Color(0xFF81C784), fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!unit.isMaxLevel) ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE5A93C),
                                  side: const BorderSide(color: Color(0xFFE5A93C), width: 0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => PedigreeInspectorDialog.show(
                                  context,
                                  unit,
                                  relicService: _relicService,
                                  totalIchor: _totalIchor,
                                  onLevelUp: (updatedUnit, cost) => _levelUpUnit(
                                    unitId: updatedUnit.id,
                                    xpAmount: cost,
                                    ichorCost: cost,
                                  ),
                                ),
                                child: const Text('INFUSE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (!inActiveSquad)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB3261E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showDeployThrallDialog(unit),
                                child: const Text('DEPLOY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                              )
                            else
                              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                          ],
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

  Widget _buildCodexView() {
    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181820),
        title: const Text(
          'HEXAGONAL AFFINITY & COMMAND CODEX',
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
            const SizedBox(height: 16),
            HexagonalAffinityWheelWidget(
              activeArchetype: _codexSelectedArchetype,
              onSelectArchetype: (archetype) {
                setState(() => _codexSelectedArchetype = archetype);
              },
            ),
            const SizedBox(height: 16),
            _buildCodexItem(Archetype.juggernaut, 'Crushes Assassins (+30%). Weak to Occultist rot (-25%).'),
            _buildCodexItem(Archetype.assassin, 'Guts Marksmen (+30%). Weak to Juggernaut armor (-25%).'),
            _buildCodexItem(Archetype.marksman, 'Shoots down Skirmishers (+30%). Weak to Assassin burst (-25%).'),
            _buildCodexItem(Archetype.skirmisher, 'Dives onto Supports (+30%). Weak to Marksmen fire (-25%).'),
            _buildCodexItem(Archetype.support, 'Purges Occultists (+30%). Weak to Skirmisher dives (-25%).'),
            _buildCodexItem(Archetype.occultist, 'Melts Juggernauts (+30%). Weak to Support wards (-25%).'),
            const SizedBox(height: 16),
            const Text(
              'COMMANDERS & BATTLEFIELD AURAS',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...GeneralProfile.allGenerals.map((g) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF181820),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: g.themeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: g.themeColor.withValues(alpha: 0.25),
                      child: Icon(g.icon, color: g.themeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(g.title, style: TextStyle(color: g.themeColor, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Aura: ${g.auraName} — ${g.auraDescription}', style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                          const SizedBox(height: 4),
                          Text(
                            'Orders: ${g.orders.map((o) => "${o.name} (${o.focusCost}F)").join(" • ")}',
                            style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'RELIC SET SYNERGY MATRIX (SPEC 9.2)',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildCodexRelicSetItem('Bloodleech (2-Piece)', '+15% Lifesteal on all physical and skill strikes.', const Color(0xFFE53935), Icons.water_drop),
            _buildCodexRelicSetItem('Ironclad (2-Piece)', '+20% Armor defense (+25 flat Defense bonus).', const Color(0xFF1E88E5), Icons.shield),
            _buildCodexRelicSetItem('Tempest (2-Piece)', '+12 Speed initiative acceleration.', const Color(0xFF00ACC1), Icons.air),
            _buildCodexRelicSetItem('Shadowstalker (2-Piece)', '+15% Critical Strike Rate, +10 Speed.', const Color(0xFF8E24AA), Icons.flash_on),
            _buildCodexRelicSetItem('Executioner (4-Piece)', '+30% Critical Damage, +10% Critical Strike Rate.', const Color(0xFFFFB300), Icons.colorize),
            _buildCodexRelicSetItem('Blightweaver (4-Piece)', '+15% ATK (+20 flat); all strikes inflict 3-turn Blight; +30% DMG vs Blighted.', const Color(0xFF43A047), Icons.bubble_chart),
            _buildCodexRelicSetItem('Dreadnought (4-Piece)', '+30% Maximum HP (+150 flat); reflects 20% incoming damage back to attacker.', const Color(0xFF78909C), Icons.security),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181820),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2B2B36)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMBAT MITIGATION & TICK ENGINE (SPEC 4)',
                    style: TextStyle(color: Color(0xFFE5A93C), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Mitigation Multiplier = 1000 / (1000 + 3.5 * Defender Defense)\n'
                    '• Turn-Meter Delta = (Speed / 100) * 10 per tick\n'
                    '• Glancing Blow: 25% chance on Disadvantage (-30% DMG, cannot crit, debuffs fail)\n'
                    '• Command Focus: 500 damage dealt or taken = 1 Focus point (cap 3)',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.45),
                  ),
                ],
              ),
            ),
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
    final isSelected = archetype == _codexSelectedArchetype;
    return InkWell(
      onTap: () {
        setState(() => _codexSelectedArchetype = archetype);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF231C14) : const Color(0xFF181820),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF2B2B36),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected ? const Color(0xFFE5A93C).withValues(alpha: 0.25) : const Color(0xFF2B2B36),
              child: Text(
                archetype.name.substring(0, 3).toUpperCase(),
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFFE5A93C),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
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
                        archetype.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFE5A93C) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '• SELECTED ON WHEEL',
                          style: TextStyle(color: Color(0xFFE5A93C), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  Text(description, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodexRelicSetItem(String title, String effect, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  effect,
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getArchetypeColor(Archetype type) {
    switch (type) {
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
}
