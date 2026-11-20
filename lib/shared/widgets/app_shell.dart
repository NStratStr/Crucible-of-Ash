import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio/global_audio_service.dart';
import '../../core/combat_math.dart';
import '../../features/campaign/ascension_tier_data.dart';
import '../../features/campaign/blood_altar_dialog.dart';
import '../../features/campaign/campaign_map_generator.dart';
import '../../features/campaign/campaign_map_screen.dart';
import '../../features/campaign/campaign_node.dart';
import '../../features/campaign/defiled_crypt_dialog.dart';
import '../../features/campaign/endgame_gauntlet_dialog.dart';
import '../../features/campaign/linear_campaign_stage.dart';
import '../../features/campaign/rest_haven_dialog.dart';
import '../../features/campaign/safe_teleport_modal.dart';
import '../../features/campaign/watchtower_dialog.dart';
import '../../features/combat/combat_resolution_service.dart';
import '../../features/combat/initiative_tick_manager.dart';
import '../../features/combat_spatial/spatial_battle_screen.dart';
import '../../features/combat_spatial/spatial_combat_engine.dart';
import '../../features/combat_spatial/crucible_skill_tree_dialog.dart';
import '../../features/combat_spatial/crucible_retinue_squad_dialog.dart';
import '../../features/combat_spatial/models/crucible_skill_tree_models.dart';
import '../../features/crucible/crucible_screen.dart';
import '../../features/generals/general_command_service.dart';
import '../../features/generals/general_selection_dialog.dart';
import '../../features/generals/grimoire_manager_dialog.dart';
import '../../features/home/home_screen.dart';
import '../../features/summoning/summoning_screen.dart';
import '../../features/settings/settings_dialog.dart';
import '../../features/persistence/game_state_persistence_service.dart';
import '../../features/relics/relic_forge_screen.dart';
import '../../features/plinths/plinth_service.dart';
import '../../features/plinths/plinth_sculptory_screen.dart';
import '../../features/delves/delve_models.dart';
import '../../features/delves/delve_service.dart';
import '../../features/delves/catacomb_delve_screen.dart';
import '../../features/traits/trait_chiseling_service.dart';
import '../../features/relics/relic_service.dart';
import '../../features/ftue/awakening_dialog.dart';
import '../../features/ftue/ftue_guidance_banner.dart';
import '../../features/ftue/ftue_service.dart';
import '../../features/ftue/ftue_stage.dart';
import '../../features/persistence/cloud_auth_service.dart';
import '../data/starter_brigades.dart';
import '../models/expedition_boon.dart';
import '../models/relic_entity.dart';
import '../models/unit_entity.dart';
import 'hexagonal_affinity_wheel_widget.dart';
import 'pedigree_inspector_dialog.dart';
import 'gothic_header_bar.dart';

class AppShell extends StatefulWidget {
  final bool enableAutoBattle;
  const AppShell({super.key, this.enableAutoBattle = true});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  int _totalIchor = 150;
  int _cursedOre = 50;
  int _bloodlineSigils = 0;
  int _brimSlagCores = 2;
  int _solarIron = 2;
  int _quicksilver = 2;
  int _crucibleTier = 1;
  int _forgeTier = 1;
  int _hospiceTier = 1;
  int _spindleTier = 1;
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
  int _currentAscension = 0;
  int _maxUnlockedAscension = 0;
  final Map<int, int> _completedStagesByChapter = {};
  int get _completedLinearStages => _completedStagesByChapter[_currentChapter] ?? 0;
  bool _isRestoringState = false;
  int _lastLoadedTimestamp = 0;
  final Map<String, int> _stageStars = {};
  final Set<String> _claimedThreeStarStages = {};
  bool _hasCompletedAwakening = false;
  CrucibleSkillTreeState _crucibleSkillTreeState = CrucibleSkillTreeState();

  late InitiativeTickManager _tickManager;
  late CombatResolutionService _combatService;
  late GeneralCommandService _commandService;
  late RelicService _relicService;
  late PlinthService _plinthService;
  late DelveService _delveService;
  late TraitChiselingService _traitChiselingService;
  DelveRoom? _activeDelveRoom;
  late FtueService _ftueService;
  late List<UnitEntity> _inventory;
  late List<CampaignNode> _campaignNodes;
  CampaignNode? _activeNode;
  List<List<UnitEntity>>? _activeEnemyWaves;
  final Set<EndgameTrialType> _clearedGauntletTrials = {};
  EndgameTrialType? _activeGauntletTrial;
  DungeonDifficultyTier _activeGauntletTier = DungeonDifficultyTier.standard;
  Archetype _codexSelectedArchetype = Archetype.juggernaut;
  bool _isInitialized = false;
  bool _isAscensionDialogOpen = false;

  // Dungeon / Catacomb Delve Run Loot Sack (Risk & Reward 100% Extract vs 50% Wipe)
  int _dungeonDelveIchor = 0;
  int _dungeonDelveOre = 0;
  int _dungeonDelveSigils = 0;

  @override
  void initState() {
    super.initState();
    _relicService = RelicService();
    _relicService.addListener(_onRelicServiceChanged);
    _plinthService = PlinthService();
    _delveService = DelveService();
    _traitChiselingService = TraitChiselingService();
    _ftueService = FtueService();
    _resetEncounter(null, BattleModifier.none, false);
    _inventory = [];
    _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);
    GlobalAudioService().playBgm(GlobalAudioService.bgmSanctuary);

    _ftueService.addListener(() {
      if (mounted) setState(() {});
    });

    _loadPersistedState().then((_) async {
      // Ensure tester is automatically signed in and only restore cloud save if strictly newer than local save
      try {
        await CloudAuthService().ensureSignedIn();
        final cloudData = await CloudAuthService().fetchSaveFromCloud();
        if (cloudData != null && mounted && cloudData.lastSavedTimestamp > _lastLoadedTimestamp) {
          _restoreSaveData(cloudData);
          await GameStatePersistenceService.save(cloudData);
        }
      } catch (e) {
        debugPrint('Cloud startup sync skipped: $e');
      }

      // If the player hasn't completed Awakening yet, prompt the Awakening Prologue & selection dialog
      if (mounted && !_hasCompletedAwakening) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasCompletedAwakening) {
            _showAwakeningDialog();
          }
        });
      }
    });
  }

  void _onRelicServiceChanged() {
    if (_isRestoringState || !mounted) return;
    _saveCurrentState();
  }

  void _restoreSaveData(GameSaveData saved) {
    _isRestoringState = true;
    try {
      FtueStage? targetFtueStage;
      if (saved.ftueStageName != null) {
        for (final stage in FtueStage.values) {
          if (stage.name == saved.ftueStageName) {
            targetFtueStage = stage;
            break;
          }
        }
      }

      setState(() {
        _lastLoadedTimestamp = saved.lastSavedTimestamp;
        _totalIchor = saved.totalIchor;
        _cursedOre = saved.cursedOre;
        _bloodlineSigils = saved.bloodlineSigils;
        _brimSlagCores = saved.brimSlagCores;
        _solarIron = saved.solarIron;
        _quicksilver = saved.quicksilver;
        _crucibleTier = saved.crucibleTier;
        if (saved.skillTreeJson != null) {
          _crucibleSkillTreeState.loadFromJson(saved.skillTreeJson!);
        }
        _crucibleSkillTreeState.castleCrucibleTier = _crucibleTier;
        _forgeTier = saved.forgeTier;
        _hospiceTier = saved.hospiceTier;
        _spindleTier = saved.spindleTier;
        _activeGeneralType = saved.activeGeneralType;
        _phylacteryRanks = Map.from(saved.phylacteryRanks);
        _currentChapter = saved.currentChapter;
        _maxUnlockedChapter = saved.maxUnlockedChapter;
        _currentAscension = saved.currentAscension;
        _maxUnlockedAscension = saved.maxUnlockedAscension;
        _completedStagesByChapter.clear();
        if (saved.completedStagesByChapter.isNotEmpty) {
          _completedStagesByChapter.addAll(saved.completedStagesByChapter);
        }
        if (saved.completedLinearStages > (_completedStagesByChapter[saved.currentChapter] ?? 0)) {
          _completedStagesByChapter[saved.currentChapter] = saved.completedLinearStages;
        }
        for (int ch = 1; ch < _maxUnlockedChapter; ch++) {
          if ((_completedStagesByChapter[ch] ?? 0) < 10) {
            _completedStagesByChapter[ch] = 10;
          }
        }
        _stageStars.clear();
        _stageStars.addAll(saved.stageStars);
        _claimedThreeStarStages.clear();
        _claimedThreeStarStages.addAll(saved.claimedThreeStarStages);
        _hasCompletedAwakening = saved.hasCompletedAwakening;
        _clearedGauntletTrials.clear();
        _clearedGauntletTrials.addAll(saved.clearedGauntletTrials);

        // Restore relics before migrating squad IDs so equippedUnitId references stay intact
        _relicService.setAllRelics(saved.relics);

        List<UnitEntity> alliesToRestore = saved.allies;
        if (alliesToRestore.isEmpty) {
          alliesToRestore = [StarterBrigades.createSculptorStarterSquad().first];
        } else {
          alliesToRestore = _migrateToSculptorAndFootmanRetinue(alliesToRestore);
        }

        _tickManager.dispose();
        _commandService.dispose();
        _tickManager = InitiativeTickManager(
          initialAllies: alliesToRestore,
          initialEnemies: StarterBrigades.createCryptStalkersEnemySquad(),
          tickInterval: const Duration(milliseconds: 140),
          onTick: () => _commandService.onSimulationTick(),
        );
        _commandService = GeneralCommandService(
          tickManager: _tickManager,
          generalType: _activeGeneralType,
          initialFocus: (_phylacteryRanks[_activeGeneralType] ?? 1) >= 3 ? 2 : 1,
          maxFocus: _activeGeneralType == GeneralType.vladislav
              ? GeneralCommandService.grimoireMaxFocusCap
              : GeneralCommandService.defaultMaxFocusCap,
          initialPhylacteryRanks: _phylacteryRanks,
          initialCustomGrimoires: saved.customGrimoires,
        );
        _commandService.initializeGrimoire();
        _combatService = CombatResolutionService(
          tickManager: _tickManager,
          commandService: _commandService,
          relicService: _relicService,
        );

        _inventory = List.from(saved.reserveInventory);
        _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);
      });

      if (targetFtueStage == null) {
        final int ch1Cleared = _completedStagesByChapter[1] ?? 0;
        if (!saved.hasCompletedAwakening) {
          targetFtueStage = FtueStage.awakening;
        } else if (ch1Cleared >= 5 || _maxUnlockedChapter > 1) {
          targetFtueStage = FtueStage.completed;
        } else if (ch1Cleared >= 3) {
          targetFtueStage = FtueStage.encounter3;
        } else if (ch1Cleared >= 2) {
          targetFtueStage = FtueStage.crucibleFusion;
        } else if (ch1Cleared >= 1) {
          targetFtueStage = FtueStage.encounter2;
        } else {
          targetFtueStage = FtueStage.encounter1;
        }
      }
      _ftueService.setStage(targetFtueStage);
    } finally {
      _isRestoringState = false;
    }
  }

  List<UnitEntity> _migrateToSculptorAndFootmanRetinue(List<UnitEntity> rawAllies) {
    final List<UnitEntity> result = List.from(rawAllies);
    if (result.isEmpty) {
      result.add(StarterBrigades.createSculptorStarterSquad().first);
    }
    // Slot 0: Always The Ash Sculptor Commander
    final String oldSlot0Id = result[0].id;
    result[0] = result[0].copyWith(
      id: 'ash_sculptor_01',
      name: 'The Ash Sculptor',
      speciesId: 'ash_sculptor',
      customAvatarAsset: 'assets/images/ash_sculptor_idle.png',
    );
    if (oldSlot0Id != 'ash_sculptor_01') {
      _relicService.migrateEquippedUnitId(oldSlot0Id, 'ash_sculptor_01');
    }
    // Slot 1 (if unlocked/present): Iron Footman Vanguard companion
    if (result.length > 1 && result[1].speciesId == 'iron_footman') {
      final String oldSlot1Id = result[1].id;
      result[1] = result[1].copyWith(
        id: 'ash_footman_01',
        name: 'Iron Footman',
        speciesId: 'iron_footman',
        archetype: Archetype.juggernaut,
        customAvatarAsset: 'assets/images/iron_footman_idle.png',
        speed: 90,
      );
      if (oldSlot1Id != 'ash_footman_01') {
        _relicService.migrateEquippedUnitId(oldSlot1Id, 'ash_footman_01');
      }
    }
    // Slot 2: Distinct Grave Duelist companion (heal corrupted duplicate sculptors)
    if (result.length > 2) {
      final u2 = result[2];
      if (u2.speciesId.contains('ash_sculptor') ||
          u2.speciesId.contains('vladislav') ||
          u2.name.contains('Sculptor') ||
          u2.id.contains('sculptor') ||
          u2.id.contains('vladislav') ||
          u2.id == result[0].id) {
        final String oldSlot2Id = u2.id;
        result[2] = result[2].copyWith(
          id: 'ash_duelist_01',
          name: 'Grave Duelist',
          speciesId: 'grave_duelist',
          archetype: Archetype.assassin,
          customAvatarAsset: 'assets/images/grave_duelist.png',
          speed: 125,
        );
        if (oldSlot2Id != 'ash_duelist_01') {
          _relicService.migrateEquippedUnitId(oldSlot2Id, 'ash_duelist_01');
        }
      }
    }
    return result;
  }

  Future<void> _loadPersistedState() async {
    try {
      final saved = await GameStatePersistenceService.load();
      if (saved != null && mounted) {
        _restoreSaveData(saved);
      }
    } catch (e) {
      debugPrint('Error restoring saved state: $e');
    }
  }

  Future<void> _saveCurrentState() async {
    if (_isRestoringState) return;
    try {
      final int nowTs = DateTime.now().millisecondsSinceEpoch;
      _lastLoadedTimestamp = nowTs;
      final data = GameSaveData(
        totalIchor: _totalIchor,
        cursedOre: _cursedOre,
        bloodlineSigils: _bloodlineSigils,
        brimSlagCores: _brimSlagCores,
        solarIron: _solarIron,
        quicksilver: _quicksilver,
        crucibleTier: _crucibleTier,
        forgeTier: _forgeTier,
        hospiceTier: _hospiceTier,
        spindleTier: _spindleTier,
        activeGeneralType: _activeGeneralType,
        phylacteryRanks: _phylacteryRanks,
        currentChapter: _currentChapter,
        maxUnlockedChapter: _maxUnlockedChapter,
        currentAscension: _currentAscension,
        maxUnlockedAscension: _maxUnlockedAscension,
        completedLinearStages: _completedLinearStages,
        completedStagesByChapter: Map.from(_completedStagesByChapter),
        stageStars: _stageStars,
        claimedThreeStarStages: _claimedThreeStarStages,
        hasCompletedAwakening: _hasCompletedAwakening,
        allies: _tickManager.allies,
        reserveInventory: _inventory,
        relics: _relicService.allRelics,
        clearedGauntletTrials: _clearedGauntletTrials,
        customGrimoires: _commandService.allCustomGrimoires,
        skillTreeJson: _crucibleSkillTreeState.toJson(),
        ftueStageName: _ftueService.currentStage.name,
        lastSavedTimestamp: nowTs,
      );
      await GameStatePersistenceService.save(data);

      // Background asynchronous sync to Cloud Firestore
      CloudAuthService().syncSaveToCloud(data);
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  void _resetEncounter([
    List<UnitEntity>? customEnemies,
    BattleModifier battleModifier = BattleModifier.none,
    bool preserveSquad = true,
    List<List<UnitEntity>>? enemyWaves,
  ]) {
    if (enemyWaves != null) {
      _activeEnemyWaves = enemyWaves;
    }
    List<UnitEntity> allies;
    if (preserveSquad && _isInitialized && _tickManager.allies.isNotEmpty) {
      allies = _tickManager.allies.map((u) => u.copyWith(
        currentHp: u.currentHp <= 0 ? (u.maxHp * 0.5).round() : u.currentHp,
        turnMeter: 0.0,
        activeEffects: const [],
      )).toList();
      allies = _migrateToSculptorAndFootmanRetinue(allies);
    } else {
      allies = [StarterBrigades.createSculptorStarterSquad().first];
    }
    final previousTickManager = _isInitialized ? _tickManager : null;
    final previousCommandService = _isInitialized ? _commandService : null;
    _isInitialized = true;
    final enemies = customEnemies ??
        (_activeEnemyWaves != null && _activeEnemyWaves!.isNotEmpty
            ? _activeEnemyWaves!.first
            : StarterBrigades.createCryptStalkersEnemySquad());

    previousTickManager?.dispose();
    previousCommandService?.dispose();

    _tickManager = InitiativeTickManager(
      initialAllies: allies,
      initialEnemies: enemies,
      tickInterval: const Duration(milliseconds: 220),
      onTick: () => _commandService.onSimulationTick(),
    );

    final startingFocus = (_phylacteryRanks[_activeGeneralType] ?? 1) >= 3 ? 2 : 1;

    _commandService = GeneralCommandService(
      tickManager: _tickManager,
      generalType: _activeGeneralType,
      initialFocus: startingFocus,
      maxFocus: _activeGeneralType == GeneralType.vladislav ? GeneralCommandService.grimoireMaxFocusCap : GeneralCommandService.defaultMaxFocusCap,
      initialPhylacteryRanks: _phylacteryRanks,
    );

    if (_activeGeneralType == GeneralType.vladislav) {
      _commandService.initializeGrimoire();
    }

    _combatService = CombatResolutionService(
      tickManager: _tickManager,
      commandService: _commandService,
      relicService: _relicService,
      battleModifier: battleModifier,
      activeBoons: _activeExpeditionBoons,
    );
  }

  void _launchGorgorothBossTrial() {
    final bossEnemies = StarterBrigades.createGorgorothBossEnemies();
    final bossNode = CampaignNode(
      id: 'gorgoroth_boss_arena',
      depth: 10,
      verticalRatio: 0.5,
      type: CampaignNodeType.boss,
      name: 'Boss Arena: Gorgoroth the Flayed',
      description: 'Gorgoroth the Flayed — 2x2 Colossus Boss Trial with Stagger & Break Bar Mechanics',
      nextNodeIds: const [],
      rewardIchor: 1000,
      customBackgroundAsset: 'assets/images/backgrounds/battlefield_ashen_plains.png',
      isCurrent: true,
      isReachable: true,
    );

    // Ensure lead commander is The Ash Sculptor with full HP, and companions are distinct
    final updatedAllies = _tickManager.allies.asMap().entries.map((entry) {
      final idx = entry.key;
      final u = entry.value;
      if (idx == 0) {
        return u.copyWith(
          id: 'ash_sculptor_01',
          name: 'The Ash Sculptor',
          speciesId: 'ash_sculptor',
          customAvatarAsset: 'assets/images/ash_sculptor_idle.png',
          currentHp: u.currentHp <= 0 ? u.maxHp : u.currentHp,
        );
      } else if (idx == 1 && (u.speciesId.contains('ash_sculptor') || u.name.contains('Sculptor'))) {
        return u.copyWith(
          id: 'ash_footman_01',
          name: 'Iron Footman',
          speciesId: 'iron_footman',
          archetype: Archetype.juggernaut,
          customAvatarAsset: 'assets/images/iron_footman_idle.png',
          speed: 90,
          currentHp: u.currentHp <= 0 ? u.maxHp : u.currentHp,
        );
      } else if (idx == 2 && (u.speciesId.contains('ash_sculptor') || u.name.contains('Sculptor'))) {
        return u.copyWith(
          id: 'ash_duelist_01',
          name: 'Grave Duelist',
          speciesId: 'grave_duelist',
          archetype: Archetype.assassin,
          customAvatarAsset: 'assets/images/grave_duelist.png',
          speed: 125,
          currentHp: u.currentHp <= 0 ? u.maxHp : u.currentHp,
        );
      } else if (u.currentHp <= 0) {
        return u.copyWith(currentHp: u.maxHp);
      }
      return u;
    }).toList();
    _tickManager.updateSquads(allies: updatedAllies);

    _activeNode = bossNode;
    _activeEnemyWaves = [bossEnemies];
    _resetEncounter(bossEnemies, BattleModifier.none, true, [bossEnemies]);
    setState(() {
      _currentIndex = 1; // Switch to Boss Arena
    });
  }

  void _launchMvpThreeWaveSkirmish() {
    final waves = StarterBrigades.createMvpThreeWaveSkirmish();
    final allies = StarterBrigades.createAshLegionPlayerSquad();

    _tickManager.dispose();
    _commandService.dispose();

    _tickManager = InitiativeTickManager(
      initialAllies: allies,
      initialEnemies: waves.first,
      tickInterval: const Duration(milliseconds: 220),
      onTick: () => _commandService.onSimulationTick(),
    );

    _commandService = GeneralCommandService(
      tickManager: _tickManager,
      generalType: GeneralType.vladislav,
      initialFocus: 6,
      maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      initialPhylacteryRanks: _phylacteryRanks,
    );
    _commandService.initializeGrimoire();

    _combatService = CombatResolutionService(
      tickManager: _tickManager,
      commandService: _commandService,
      relicService: _relicService,
    );

    _activeEnemyWaves = waves;

    setState(() {
      _currentIndex = 1; // Switch to Tactical Arena
    });
  }

  @override
  void dispose() {
    _tickManager.dispose();
    _commandService.dispose();
    _relicService.removeListener(_onRelicServiceChanged);
    _relicService.dispose();
    _ftueService.dispose();
    super.dispose();
  }

  void _launchLinearCampaignStage(int chapter, int stageNum) {
    final stages = LinearCampaignStage.getStagesForChapter(chapter);
    final stage = stages.firstWhere(
      (s) => s.stageNumber == stageNum,
      orElse: () => stages.first,
    );
    final node = CampaignNode(
      id: 'linear_${stage.stageCode}',
      depth: stage.stageNumber,
      verticalRatio: 0.5,
      type: stage.type,
      name: 'Stage ${stage.stageCode}: ${stage.name}',
      description: stage.description,
      nextNodeIds: const [],
      rewardIchor: stage.rewardIchor,
      rewardOre: stage.rewardOre,
      rewardSigils: stage.rewardSigils,
      customBackgroundAsset: stage.backgroundAsset,
      isCurrent: true,
      isReachable: true,
    );
    if (_currentChapter != chapter) {
      setState(() {
        _currentChapter = chapter;
        _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(chapter);
      });
    }
    _onSelectCampaignNode(node);
  }

  void _handleLaunchFtueStageAction() {
    switch (_ftueService.currentStage) {
      case FtueStage.awakening:
        _showAwakeningDialog();
        break;
      case FtueStage.encounter1:
        _launchLinearCampaignStage(1, 1);
        break;
      case FtueStage.encounter2:
        _launchLinearCampaignStage(1, 2);
        break;
      case FtueStage.crucibleFusion:
        _launchLinearCampaignStage(1, 3);
        break;
      case FtueStage.encounter3:
        _launchLinearCampaignStage(1, 5);
        break;
      case FtueStage.completed:
        _showAwakeningDialog();
        break;
    }
  }

  Future<void> _showAwakeningDialog() async {
    final chosen = await AwakeningDialog.show(
      context,
      initialSelected: CrucibleSkillBranch.wrath,
    );
    if (!mounted || chosen == null) return;

    final bool isInitialAwakening = !_hasCompletedAwakening && _tickManager.allies.length <= 1 && _inventory.isEmpty;
    final sculptorStarter = [StarterBrigades.createSculptorStarterSquad().first];
    setState(() {
      if (isInitialAwakening) {
        _tickManager.updateSquads(allies: sculptorStarter);
        _inventory = [];
      }
      final int prevLevel = _crucibleSkillTreeState.sculptorLevel;
      final int prevXp = _crucibleSkillTreeState.sculptorXp;
      final int prevTotalPoints =
          _crucibleSkillTreeState.availableSkillPoints + _crucibleSkillTreeState.totalPointsSpent;
      _crucibleSkillTreeState.configureStartingDiscipline(chosen, startWithBasics: true);
      if (!isInitialAwakening || prevTotalPoints > 0 || prevLevel > 1 || prevXp > 0) {
        _crucibleSkillTreeState.sculptorLevel = max(1, prevLevel);
        _crucibleSkillTreeState.sculptorXp = prevXp;
        _crucibleSkillTreeState.availableSkillPoints = prevTotalPoints;
      }
      _hasCompletedAwakening = true;
      if (_ftueService.currentStage == FtueStage.awakening) {
        _ftueService.advanceStage();
      }
    });
    _saveCurrentState();

    final discipline = SculptorDisciplineData.allDisciplines.firstWhere((d) => d.branch == chosen);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ash Sculptor initiated into ${discipline.title}! Deploying retinue into battle.'),
        backgroundColor: discipline.themeColor,
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
      if (node.id.startsWith('linear_')) {
        // Linear story campaign stage: fetch curated stage roster (e.g. Stage 1-1 is 1v1 against 1x Feral Ash-Scavenger)
        enemies = StarterBrigades.createEnemiesForStage(
          chapter: _currentChapter,
          stageNumber: node.depth,
          type: node.type,
        );
      } else if (node.type == CampaignNodeType.boss) {
        enemies = StarterBrigades.createChapterBossEnemies(_currentChapter);
      } else if (node.type == CampaignNodeType.elite) {
        enemies = StarterBrigades.createEliteEnemiesForChapter(_currentChapter);
      } else {
        enemies = StarterBrigades.createSkirmishEnemiesForChapter(_currentChapter);
      }

      // Apply Ascension Tier scaling (GDD v2.6 Sec 1)
      if (_currentAscension > 0) {
        final ascData = AscensionTierData.forTier(_currentAscension);
        enemies = enemies.map((e) {
          final scaledMaxHp = (e.maxHp * ascData.enemyHpMultiplier).round();
          final scaledAtk = (e.attack * ascData.enemyDamageMultiplier).round();
          final scaledSpd = (e.speed * ascData.enemySpeedMultiplier).round();
          return e.copyWith(
            maxHp: scaledMaxHp,
            currentHp: scaledMaxHp,
            attack: scaledAtk,
            speed: scaledSpd,
          );
        }).toList();
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
    } else if (node.type == CampaignNodeType.teleportStone) {
      _handleTeleportStoneNode(node);
    }
  }

  void _handleTeleportStoneNode(CampaignNode node) {
    SafeTeleportModal.show(
      context,
      accumulatedIchor: _dungeonDelveIchor,
      accumulatedOre: _dungeonDelveOre,
      accumulatedSigils: _dungeonDelveSigils,
      onConfirmExtraction: () {
        // Safe extraction with 100% of accumulated loot!
        final ichorExtracted = _dungeonDelveIchor;
        final oreExtracted = _dungeonDelveOre;
        final sigilsExtracted = _dungeonDelveSigils;

        setState(() {
          _totalIchor += ichorExtracted;
          _cursedOre += oreExtracted;
          _bloodlineSigils += sigilsExtracted;

          // Reset delve run sack
          _dungeonDelveIchor = 0;
          _dungeonDelveOre = 0;
          _dungeonDelveSigils = 0;

          // Heal squad upon return to Citadel
          final healedSquad = _tickManager.allies.map((u) => u.copyWith(currentHp: u.maxHp)).toList();
          _tickManager.updateSquads(allies: healedSquad);

          // Reset campaign expedition map to fresh incursion
          _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);
          _activeNode = null;
          _currentIndex = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'DUNGEON EXTRACTED! Safely returned with 100% loot (+$ichorExtracted Gold, +$oreExtracted Ore, +$sigilsExtracted Sigils)!',
            ),
            backgroundColor: const Color(0xFF00B4D8),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      onContinueDelve: () {
        _markNodeCompleted(node.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You leave the Teleport Stone behind and press deeper toward the Boss!'),
            backgroundColor: Color(0xFFE5A93C),
          ),
        );
      },
    );
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

  int get _castleUnitLevelCap {
    switch (_crucibleTier) {
      case 1:
        return 20;
      case 2:
        return 30;
      case 3:
        return 50;
      default:
        return 60;
    }
  }

  List<String> _grantBrigadeXp(int amount) {
    final List<String> levelUps = [];
    final int cap = _castleUnitLevelCap;
    final leveled = _tickManager.allies.map((u) {
      final oldLevel = u.level;
      final updated = u.addXp(amount, levelCap: cap);
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
        final updated = u.addXp(reserveXp, levelCap: cap);
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
          content: Text('Blood Tithe accepted: Sacrificed 25% HP for +350 Gold and +2 Focus!'),
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

      final epicRelic = _relicService.forgeRandomRelic(rarity: RelicRarity.epic, chapter: _currentChapter, stageDepth: _completedLinearStages);
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
        final relic = _relicService.forgeRandomRelic(rarity: RelicRarity.rare, chapter: _currentChapter, stageDepth: _completedLinearStages);
        setState(() {
          _totalIchor += 250;
        });
        _markNodeCompleted(node.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tomb desecrated! Plundered ${relic.displayName} & +250 Gold.'),
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
            content: Text('TRAP TRIGGERED! Necrotic Miasma afflicted brigade (-15% HP), but extracted +350 Gold!'),
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

      // Unlock forward nodes (safe for linear_ or gauntlet_ synthetic nodes that are not in _campaignNodes)
      final completed = _campaignNodes.where((n) => n.id == nodeId).firstOrNull;
      if (completed != null) {
        for (final nextId in completed.nextNodeIds) {
          _campaignNodes = _campaignNodes.map((n) {
            if (n.id == nextId) {
              return n.copyWith(isReachable: true);
            }
            return n;
          }).toList();
        }
      }
    });
  }

  void _onCombatVictory() {
    final isLinearStage = _activeNode?.id.startsWith('linear_') == true;
    final String? stageCode = isLinearStage ? _activeNode!.id.replaceFirst('linear_', '') : null;
    final stageNum = _activeNode?.depth ?? 1;

    // Check if this is a first clear or repeat farm run
    final bool isFirstClear = isLinearStage
        ? stageNum > _completedLinearStages
        : (_activeNode == null || !_activeNode!.isVisited);

    // Compute star rating based on casualty count (0 casualties = 3 stars)
    final casualties = _tickManager.allies.where((u) => !u.isAlive).length;
    final int currentStarRating = casualties == 0 ? 3 : (casualties <= 1 ? 2 : 1);

    // 3-Star Mastery logic: Award 1 bonus Bloodline Sigil on the first time 3 stars are achieved!
    bool isThreeStarRewardUnlocked = false;
    if (stageCode != null) {
      final prevBestStars = _stageStars[stageCode] ?? 0;
      if (currentStarRating > prevBestStars) {
        _stageStars[stageCode] = currentStarRating;
      }
      if (currentStarRating == 3 && !_claimedThreeStarStages.contains(stageCode)) {
        _claimedThreeStarStages.add(stageCode);
        isThreeStarRewardUnlocked = true;
      }
    }

    // Economy Balance: Base rewards are full on First Clear or First 3-Star Unlock;
    // Repeat runs suffer diminishing returns (25% Ichor, 20% Ore, 0 Sigils) to prevent infinite boss farming.
    final int baseIchor = _activeNode?.rewardIchor ?? 150;
    final int baseOre = _activeNode?.rewardOre ?? 15;
    final int baseSigils = _activeNode?.rewardSigils ?? 0;

    final int earnedIchor = isFirstClear ? baseIchor : max(15, (baseIchor * 0.25).round());
    final int earnedOre = isFirstClear ? baseOre : max(3, (baseOre * 0.20).round());
    final bool isStage1_1Node = _activeNode?.id == 'linear_1-1' || _activeNode?.name.contains('Ashen Outpost') == true;
    final bool isEliteStageNode = _activeNode?.type == CampaignNodeType.elite;
    // Guarantee at least 1 Bloodline Sigil after Stage 1-1 so the player can immediately perform their first Summon
    final int milestoneSigil = (isFirstClear && isStage1_1Node && !isThreeStarRewardUnlocked)
        ? 1
        : ((isFirstClear && isEliteStageNode && baseSigils == 0) ? 1 : 0);
    // Bloodline Sigils are strictly capped: only granted on First Clear, Stage 1-1/Elite milestones, or 3-Star Mastery unlock
    final int earnedSigils = (isFirstClear ? baseSigils : 0) + milestoneSigil + (isThreeStarRewardUnlocked ? 1 : 0);

    final double stageXpScale = 1.0 + ((_currentChapter - 1) * 0.40) + (max(0, stageNum - 1) * 0.08);
    final int baseXpReward = _activeNode == null
        ? 350
        : (_activeNode!.type == CampaignNodeType.boss
            ? (isFirstClear ? 1000 : 400)
            : (_activeNode!.type == CampaignNodeType.elite ? (isFirstClear ? 500 : 250) : (isFirstClear ? 250 : 120)));
    final int xpReward = (baseXpReward * stageXpScale).round();
    final levelUps = _grantBrigadeXp(xpReward);

    final bool isDelveBattle = _activeDelveRoom != null;
    setState(() {
      if (!isDelveBattle) {
        _totalIchor += earnedIchor;
        _cursedOre += earnedOre;
        _bloodlineSigils += earnedSigils;

        // Track accumulated loot for this delve run
        _dungeonDelveIchor += earnedIchor;
        _dungeonDelveOre += earnedOre;
        _dungeonDelveSigils += earnedSigils;
      }
    });

    if (!isDelveBattle && _activeNode != null) {
      if (isLinearStage) {
        if (stageNum > (_completedStagesByChapter[_currentChapter] ?? 0)) {
          setState(() {
            _completedStagesByChapter[_currentChapter] = stageNum;
          });
        }
      }
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

      final isStage1_1 = _activeNode?.id == 'linear_1-1' || _activeNode?.name.contains('Ashen Outpost') == true;
      final isBossNode = _activeNode?.type == CampaignNodeType.boss;

      // Sculptor XP & Level-Ups -> Skill Points (+1★ per Sculptor level-up)
      // Stage 1-1 first clear gives 300 XP to reach Lv. 2 (+1★) for the Skill Tree tutorial.
      _crucibleSkillTreeState.castleCrucibleTier = _crucibleTier;
      final int sculptorXpGain = (isStage1_1 && isFirstClear) ? max(300, xpReward) : xpReward;
      final int oldSculptorLevel = _crucibleSkillTreeState.sculptorLevel;
      final int sculptorLevelsGained = _crucibleSkillTreeState.addSculptorXp(sculptorXpGain);
      final int earnedSkillPoints = sculptorLevelsGained;
      if (sculptorLevelsGained > 0) {
        levelUps.insert(
          0,
          'Ash Sculptor (Lv. $oldSculptorLevel➔${_crucibleSkillTreeState.sculptorLevel} • +$sculptorLevelsGained★ Skill Point${sculptorLevelsGained > 1 ? "s" : ""}!)',
        );
      }

      if (!isDelveBattle && isBossNode) {
        final nodeName = _activeNode?.name ?? '';
        if (nodeName.contains('Forge') || nodeName.contains('Iron') || nodeName.contains('Colossus') || nodeName.contains('Dreadnought')) {
          _solarIron += 1;
        } else if (nodeName.contains('Archive') || nodeName.contains('Spindle') || nodeName.contains('Delve')) {
          _quicksilver += 1;
        } else {
          _brimSlagCores += 1;
        }
      }

      bool isFirstConquest = false;
      if (_activeGauntletTrial != null) {
        final int catCount = _activeGauntletTier.catalystCount;
        setState(() {
          switch (_activeGauntletTrial!) {
            case EndgameTrialType.worldTitan:
              _solarIron += catCount;
              break;
            case EndgameTrialType.lineageCrypt:
              _brimSlagCores += catCount;
              break;
            case EndgameTrialType.deathlessCrypt:
              _quicksilver += catCount;
              break;
            case EndgameTrialType.abyssalDescent:
            case EndgameTrialType.abyssalDescentII:
            case EndgameTrialType.abyssalDescentIII:
              _bloodlineSigils += catCount;
              break;
          }
        });
        if (!_clearedGauntletTrials.contains(_activeGauntletTrial)) {
          isFirstConquest = true;
          _clearedGauntletTrials.add(_activeGauntletTrial!);
          setState(() {
            _bloodlineSigils += 1;
            _totalIchor += 500;
          });
        }
        _activeGauntletTrial = null;
        _activeGauntletTier = DungeonDifficultyTier.standard;
      }

      // Relic Drops are guaranteed on first clear; on repeat farm runs, chance is 15% (elite) / 30% (boss)
      String? relicDrop;
      final bool shouldDropRelic = isFirstClear || (DateTime.now().millisecond % 100) < (_activeNode?.type == CampaignNodeType.boss ? 30 : 15);
      if (shouldDropRelic) {
        if (_activeNode?.type == CampaignNodeType.elite) {
          // Early elites drop Rare; deeper elites drop Epic
          final dropRarity = (_completedLinearStages <= 5 && _currentChapter == 1) ? RelicRarity.rare : RelicRarity.epic;
          final drop = _relicService.forgeRandomRelic(
            rarity: dropRarity,
            chapter: _currentChapter,
            stageDepth: _completedLinearStages,
          );
          relicDrop = drop.displayName;
        } else if (_activeNode?.type == CampaignNodeType.boss) {
          // Chapter Bosses drop Epic in Chapter 1 or Legendary on Boss Climax
          final dropRarity = (_currentChapter >= 2 || _completedLinearStages >= 9) ? RelicRarity.legendary : RelicRarity.epic;
          final drop = _relicService.forgeRandomRelic(
            rarity: dropRarity,
            chapter: _currentChapter,
            stageDepth: _completedLinearStages,
          );
          relicDrop = drop.displayName;
        }
      }

    // GDD v2.8 Section 1 & 2: Ascension multiplier scaling
    final ascData = _currentAscension > 0 ? AscensionTierData.forTier(_currentAscension) : null;
    final double dropMult = ascData?.resourceDropMultiplier ?? 1.0;
    final int scaledAsh = ((earnedIchor + (isFirstConquest ? 500 : 0)) * dropMult).round();
    final int scaledOre = (earnedOre * dropMult).round();

      if (!isDelveBattle) {
        if (_ftueService.currentStage == FtueStage.encounter1) {
          _ftueService.advanceStage();
        } else if (_ftueService.currentStage == FtueStage.encounter2 &&
            (!isLinearStage || stageNum >= 2)) {
          _ftueService.advanceStage();
        } else if (_ftueService.currentStage == FtueStage.crucibleFusion &&
            (!isLinearStage || stageNum >= 3)) {
          _ftueService.advanceStage();
        } else if (_ftueService.currentStage == FtueStage.encounter3 &&
            (!isLinearStage || stageNum >= 5)) {
          _ftueService.advanceStage();
        }
      }

      final bool isBossClear =
          !isDelveBattle && _activeNode?.type == CampaignNodeType.boss && _currentChapter < 10;
      final bool isFinalBossClear =
          !isDelveBattle && _activeNode?.type == CampaignNodeType.boss && (_currentChapter == 3 || _currentChapter == 10);
      final int nextCh = _currentChapter + 1;
      if (isBossClear && _maxUnlockedChapter < nextCh) {
        setState(() {
          _maxUnlockedChapter = nextCh;
        });
      }

      // Conquering Chapter 3 World Titan or Chapter 10 finale unlocks the next Ascension Tier (A1..A10)
      if (isFinalBossClear && _maxUnlockedAscension < 10) {
        final nextAscension = min(10, _maxUnlockedAscension + 1);
        if (nextAscension > _maxUnlockedAscension) {
          setState(() {
            _maxUnlockedAscension = nextAscension;
          });
        }
      }

      final completedDelveRoom = _activeDelveRoom;
      if (completedDelveRoom != null) {
        final bool isTowerBossRoom = completedDelveRoom.type == DelveRoomType.catacombArchon;
        if (isTowerBossRoom) {
          setState(() {
            _quicksilver += 1;
            _bloodlineSigils += 1;
          });
        }
        _delveService.completeRoom(completedDelveRoom.id);
        _delveService.updateSquadHpAfterBattle(_tickManager.allies);
      }

      _saveCurrentState();

      final bool showFirstSummonNudge =
          completedDelveRoom == null &&
          isStage1_1 &&
          (_tickManager.allies.length + _inventory.length) <= 1 &&
          _bloodlineSigils >= 1;

      if (mounted) {
        final String spoilsText = completedDelveRoom != null
            ? '⚔️ TOWER ROOM CLEARED: +${completedDelveRoom.rewardIchor} Gold • +${completedDelveRoom.rewardOre} Ore Added to Delve Sack'
                '${completedDelveRoom.rewardSigils > 0 ? " • +${completedDelveRoom.rewardSigils} Sigil${completedDelveRoom.rewardSigils > 1 ? 's' : ''}" : ""}'
                '${completedDelveRoom.type == DelveRoomType.catacombArchon ? " • +1 Quicksilver & +1 Sigil" : ""}'
            : '⚔️ VICTORY: +$scaledAsh Gold • +$scaledOre Ore'
                '${earnedSigils > 0 ? " • +$earnedSigils Sigil${earnedSigils > 1 ? 's' : ''}" : ""}'
                '${earnedSkillPoints > 0 ? " • +$earnedSkillPoints★ Skill Point" : ""}'
                '${relicDrop != null ? " • Relic: $relicDrop" : ""}'
                '${purebloodDrop != null ? " • Recruited: ${purebloodDrop.name}" : ""}'
                '${showFirstSummonNudge ? " • ✨ +1 Sigil! Summon your 1st Companion!" : ""}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              spoilsText,
              style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: const Color(0xFF14121B),
            duration: Duration(seconds: showFirstSummonNudge ? 6 : 4),
            behavior: SnackBarBehavior.floating,
            action: showFirstSummonNudge
                ? SnackBarAction(
                    label: 'SUMMON ALLY',
                    textColor: const Color(0xFF69F0AE),
                    onPressed: () {
                      if (mounted) _handleOpenSummoning();
                    },
                  )
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
            ),
          ),
        );
      }

      if (completedDelveRoom != null) {
        setState(() {
          _activeDelveRoom = null;
          _currentIndex = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCatacombDelveSheet();
        });
        return;
      }
      if (isBossClear) {
        _showChapterAscensionDialog(nextCh);
      } else {
        setState(() {
          _currentIndex = 0;
          _activeNode = null;
        });
        if (!showFirstSummonNudge && isStage1_1 && earnedSkillPoints > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openOutOfBattleSkillTree();
          });
        }
      }
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
              _saveCurrentState();
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
    // User requested rule: On death/wipe in a delve, player recovers 50% of accumulated delve loot
    final int consolationAsh = max(25, (_dungeonDelveIchor * 0.50).round());
    final int consolationOre = (_dungeonDelveOre * 0.50).round();
    final int consolationXp = 50;
    _grantBrigadeXp(consolationXp);

    setState(() {
      _totalIchor += consolationAsh;
      _cursedOre += consolationOre;
      // Reset delve sack
      _dungeonDelveIchor = 0;
      _dungeonDelveOre = 0;
      _dungeonDelveSigils = 0;
    });

    if (_activeDelveRoom != null) {
      final consolation = _delveService.wipeRun();
      _totalIchor += consolation['ichor'] ?? 0;
      _cursedOre += consolation['ore'] ?? 0;
      _bloodlineSigils += consolation['sigils'] ?? 0;
      _plinthService.addShards(consolation['plinths'] ?? 0);
      _activeDelveRoom = null;
    }

    if (!mounted) return;
    setState(() {
      final revivedAllies = _tickManager.allies.map((u) => u.copyWith(currentHp: u.maxHp)).toList();
      _tickManager.updateSquads(allies: revivedAllies);
      _activeExpeditionBoons.clear();
      _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(_currentChapter);
      _activeNode = null;
      _currentIndex = 0; // Return to campaign map
    });
    _saveCurrentState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '💀 DEFEAT: Squad revived at camp. Salvaged +$consolationAsh Ash & +$consolationOre Ore.',
          style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.bold, fontSize: 12),
        ),
        backgroundColor: const Color(0xFF1B0F12),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'TRAIN / EQUIP',
          textColor: const Color(0xFFFFD54F),
          onPressed: () {
            if (mounted) _openOutOfBattleRetinueSquad();
          },
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
        ),
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
    UnitEntity? replacementUnit,
  }) {
    if (_totalIchor < ichorCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Gold! Requires $ichorCost Gold, but you have $_totalIchor.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    UnitEntity? updatedUnit;
    bool wasRarityPromotion = false;

    // 1. Check active squad
    final int cap = _castleUnitLevelCap;
    final allyIndex = _tickManager.allies.indexWhere((u) => u.id == unitId);
    if (allyIndex != -1) {
      final ally = _tickManager.allies[allyIndex];
      wasRarityPromotion = replacementUnit != null && replacementUnit.rarity != ally.rarity;
      if (replacementUnit == null && ally.level >= cap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Castle Crucible Tier $_crucibleTier caps units at Lv. $cap — upgrade the Crucible in Sanctuary to unlock higher levels!'),
            backgroundColor: const Color(0xFF4E342E),
          ),
        );
        return;
      }
      final leveled = replacementUnit ?? ally.addXp(xpAmount, levelCap: cap);
      updatedUnit = leveled;

      final newAllies = List<UnitEntity>.from(_tickManager.allies);
      newAllies[allyIndex] = leveled;
      _tickManager.updateSquads(allies: newAllies);
    } else {
      // 2. Check reserve inventory
      final invIndex = _inventory.indexWhere((u) => u.id == unitId);
      if (invIndex != -1) {
        final unit = _inventory[invIndex];
        wasRarityPromotion = replacementUnit != null && replacementUnit.rarity != unit.rarity;
        if (replacementUnit == null && unit.level >= cap) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Castle Crucible Tier $_crucibleTier caps units at Lv. $cap — upgrade the Crucible in Sanctuary to unlock higher levels!'),
              backgroundColor: const Color(0xFF4E342E),
            ),
          );
          return;
        }
        final leveled = replacementUnit ?? unit.addXp(xpAmount, levelCap: cap);
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
            wasRarityPromotion
                ? '★ RARITY CONSECRATED: ${updatedUnit.name} ascended to ${updatedUnit.rarity.displayName.toUpperCase()} (+15% HP/ATK, +12% DEF)!'
                : (updatedUnit.isMaxLevel
                    ? '👑 ${updatedUnit.name} reached MAX LEVEL ${updatedUnit.maxLevel}! 10% Inheritance Unlocked!'
                    : '✦ ${updatedUnit.name} infused with $xpAmount XP (Lv. ${updatedUnit.level}/${updatedUnit.maxLevel})!'),
          ),
          backgroundColor: wasRarityPromotion
              ? Color(updatedUnit.rarity.borderHexColor)
              : (updatedUnit.isMaxLevel ? const Color(0xFFE5A93C) : const Color(0xFF2E7D32)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
        content: Text('Sarcophagus unsealed: Unlocked Crypt Ghoul & +250 Gold!'),
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

  void _updateUnitInRoster(UnitEntity updatedUnit) {
    setState(() {
      final allyIdx = _tickManager.allies.indexWhere((u) => u.id == updatedUnit.id);
      if (allyIdx != -1) {
        final updatedAllies = List<UnitEntity>.from(_tickManager.allies);
        updatedAllies[allyIdx] = updatedUnit;
        _tickManager.updateSquads(allies: updatedAllies);
      }
      final invIdx = _inventory.indexWhere((u) => u.id == updatedUnit.id);
      if (invIdx != -1) {
        _inventory[invIdx] = updatedUnit;
      }
    });
    _saveCurrentState();
  }

  void _openCatacombDelveSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: CatacombDelveScreen(
            delveService: _delveService,
            brigadeSquad: _tickManager.allies,
            relicService: _relicService,
            onLaunchCombat: (room, squadWithHp) {
              Navigator.of(ctx).pop();
              _launchDelveCombat(room, squadWithHp);
            },
            onExtractionConfirmed: ({required ichor, required ore, required sigils, required plinthShards}) {
              setState(() {
                _totalIchor += ichor;
                _cursedOre += ore;
                _bloodlineSigils += sigils;
                _plinthService.addShards(plinthShards);
              });
              _saveCurrentState();
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        );
      },
    );
  }

  void _launchDelveCombat(DelveRoom room, List<UnitEntity> squadWithHp) {
    _activeDelveRoom = room;

    List<UnitEntity> enemies;
    if (room.type == DelveRoomType.catacombArchon) {
      if (room.floor >= 15) {
        enemies = StarterBrigades.createAbyssalDescentTier3Enemies();
      } else if (room.floor >= 10) {
        enemies = StarterBrigades.createWorldTitanEnemies();
      } else {
        enemies = StarterBrigades.createGorgorothBossEnemies();
      }
    } else if (room.type == DelveRoomType.wanderingElite) {
      enemies = StarterBrigades.createEliteEnemiesForChapter(room.floor.clamp(1, 3));
    } else {
      enemies = StarterBrigades.createSkirmishEnemiesForChapter(room.floor.clamp(1, 3));
    }

    // Smooth Tower floor scaling above Floor 1
    if (room.floor > 1) {
      final double floorScale = 1.0 + (room.floor - 1) * 0.16;
      enemies = enemies.map((e) {
        final scaledHp = (e.maxHp * floorScale).round();
        return e.copyWith(
          maxHp: scaledHp,
          currentHp: scaledHp,
          attack: (e.attack * (1.0 + (room.floor - 1) * 0.12)).round(),
          defense: (e.defense * (1.0 + (room.floor - 1) * 0.10)).round(),
        );
      }).toList();
    }

    final delveNode = CampaignNode(
      id: 'delve_${room.id}',
      depth: room.column + 1,
      verticalRatio: 0.5,
      type: room.type == DelveRoomType.catacombArchon
          ? CampaignNodeType.boss
          : (room.type == DelveRoomType.wanderingElite ? CampaignNodeType.elite : CampaignNodeType.skirmish),
      name: 'Delve F${room.floor}: ${room.title}',
      description: room.description,
      nextNodeIds: const [],
      rewardIchor: room.rewardIchor,
      customBackgroundAsset: 'assets/images/backgrounds/battlefield_ashen_plains.png',
      isCurrent: true,
      isReachable: true,
    );

    // Apply persistent squad HP
    final updatedAllies = squadWithHp.map((u) {
      final hp = _delveService.getUnitHp(u);
      return u.copyWith(currentHp: max(1, hp));
    }).toList();
    _tickManager.updateSquads(allies: updatedAllies);

    _activeNode = delveNode;
    _activeEnemyWaves = [enemies];
    _resetEncounter(enemies, BattleModifier.none, true, [enemies]);

    setState(() {
      _currentIndex = 1; // Launch battle view
    });
  }

  void _openPlinthSculptorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: PlinthSculptoryScreen(
            plinthService: _plinthService,
            brigadeUnits: _tickManager.allies,
            totalIchor: _totalIchor,
            onIchorChanged: (val) => setState(() => _totalIchor = val),
            onClose: () => Navigator.of(ctx).pop(),
            forgeTier: _forgeTier,
          ),
        );
      },
    );
  }

  Future<void> _handleOpenEndgameGauntlet() async {
    final selection = await EndgameGauntletDialog.show(
      context,
      activeSquad: _tickManager.allies,
      clearedTrials: _clearedGauntletTrials,
    );
    if (!mounted || selection == null) return;
    final trial = selection.type;
    final tier = selection.tier;
    _activeGauntletTrial = trial;
    _activeGauntletTier = tier;

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

    if (tier != DungeonDifficultyTier.standard) {
      enemies = enemies.map((e) {
        final scaledHp = (e.maxHp * tier.enemyHpMult).round();
        return e.copyWith(
          maxHp: scaledHp,
          currentHp: scaledHp,
          attack: (e.attack * tier.enemyAtkMult).round(),
          defense: (e.defense * tier.enemyDefMult).round(),
        );
      }).toList();
      trialName = '$trialName [${tier.label}]';
      rewardIchor = (rewardIchor * tier.rewardMult).round();
      rewardOre = (rewardOre * tier.rewardMult).round();
      rewardSigils += tier.bonusSigils;
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

  void _upgradeSanctuaryFacility({
    required String facilityId,
    required int newTier,
    required int ichorCost,
    required int oreCost,
    required int reagentCost,
    required String reagentType,
  }) {
    if (_totalIchor < ichorCost || _cursedOre < oreCost) return;
    if (reagentType == 'brimSlag' && _brimSlagCores < reagentCost) return;
    if (reagentType == 'solarIron' && _solarIron < reagentCost) return;
    if (reagentType == 'quicksilver' && _quicksilver < reagentCost) return;
    if (reagentType == 'sigils' && _bloodlineSigils < reagentCost) return;

    setState(() {
      _totalIchor -= ichorCost;
      _cursedOre -= oreCost;
      if (reagentType == 'brimSlag') _brimSlagCores -= reagentCost;
      if (reagentType == 'solarIron') _solarIron -= reagentCost;
      if (reagentType == 'quicksilver') _quicksilver -= reagentCost;
      if (reagentType == 'sigils') _bloodlineSigils -= reagentCost;

      if (facilityId == 'crucible') {
        _crucibleTier = newTier;
        _crucibleSkillTreeState.castleCrucibleTier = newTier;
        final int newCap = _castleUnitLevelCap;
        final updatedAllies = _tickManager.allies.map((u) {
          if (u.speciesId == 'ash_sculptor' && u.maxLevel < newCap) {
            return u.copyWith(maxLevel: newCap);
          }
          return u;
        }).toList();
        _tickManager.updateSquads(allies: updatedAllies);
      }
      if (facilityId == 'forge') _forgeTier = newTier;
      if (facilityId == 'hospice') _hospiceTier = newTier;
      if (facilityId == 'spindle' || facilityId == 'beacon') _spindleTier = newTier;
    });

    _saveCurrentState();
  }

  void _showHomeModal() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogCtx) => HomeScreen(
        totalIchor: _totalIchor,
        cursedOre: _cursedOre,
        bloodlineSigils: _bloodlineSigils,
        brimSlagCores: _brimSlagCores,
        solarIron: _solarIron,
        quicksilver: _quicksilver,
        crucibleTier: _crucibleTier,
        forgeTier: _forgeTier,
        hospiceTier: _hospiceTier,
        spindleTier: _spindleTier,
        onUpgradeFacility: _upgradeSanctuaryFacility,
        activeGeneral: _activeGeneralType,
        currentChapter: _currentChapter,
        currentAscension: _currentAscension,
        onOpenCampaign: () {
          Navigator.of(dialogCtx).pop();
          setState(() => _currentIndex = 0);
        },
        onOpenBattleArena: () {
          Navigator.of(dialogCtx).pop();
          _launchGorgorothBossTrial();
        },
        onOpenCrucible: () {
          Navigator.of(dialogCtx).pop();
          setState(() => _currentIndex = 2);
        },
        onOpenRelicForge: () {
          Navigator.of(dialogCtx).pop();
          setState(() => _currentIndex = 3);
        },
        onOpenBrigadeRoster: () {
          Navigator.of(dialogCtx).pop();
          setState(() => _currentIndex = 4);
        },
        onOpenAffinityCodex: () {
          Navigator.of(dialogCtx).pop();
          setState(() => _currentIndex = 5);
        },
        onOpenEndgameGauntlet: () {
          Navigator.of(dialogCtx).pop();
          _handleOpenEndgameGauntlet();
        },
        onOpenSummoning: () {
          Navigator.of(dialogCtx).pop();
          _handleOpenSummoning();
        },
        onOpenPlinthSculptory: () {
          Navigator.of(dialogCtx).pop();
          _openPlinthSculptorySheet();
        },
        onOpenSkillTree: () {
          Navigator.of(dialogCtx).pop();
          _openOutOfBattleSkillTree();
        },
        onOpenRetinueSquad: () {
          Navigator.of(dialogCtx).pop();
          _openOutOfBattleRetinueSquad();
        },
        unspentSkillPoints: _crucibleSkillTreeState.availableSkillPoints,
        guideFirstSkillUpgrade: _crucibleSkillTreeState.availableSkillPoints > 0 &&
            _crucibleSkillTreeState.allSkills.values.where((s) => s.isUnlocked).length <= 1,
        onOpenCatacombDelves: () {
          Navigator.of(dialogCtx).pop();
          _openCatacombDelveSheet();
        },
        onOpenSettings: () {
          SettingsDialog.show(dialogCtx, onResetSave: _resetToFreshPrologue);
        },
        onCloudDataRestored: () async {
          try {
            final cloudData = await CloudAuthService().fetchSaveFromCloud();
            if (!mounted) return;
            if (cloudData != null) {
              _restoreSaveData(cloudData);
              await GameStatePersistenceService.save(cloudData);
            } else {
              await _saveCurrentState();
            }
          } catch (e) {
            debugPrint('Error applying cloud save on restore: $e');
          }
        },
      ),
    );
  }

  SpatialCombatEngine _createPreviewSpatialEngine() {
    return SpatialCombatEngine(
      initialPlayerEntities: _tickManager.allies,
      initialEnemyEntities: _tickManager.enemies,
      relicService: _relicService,
      commandService: _commandService,
      plinthService: _plinthService,
      skillTreeState: _crucibleSkillTreeState,
    );
  }

  void _openOutOfBattleSkillTree() {
    final previewEngine = _createPreviewSpatialEngine();
    CrucibleSkillTreeDialog.show(context, previewEngine).then((_) {
      _saveCurrentState();
      if (mounted) setState(() {});
    });
  }

  void _openOutOfBattleRetinueSquad() {
    final previewEngine = _createPreviewSpatialEngine();
    CrucibleRetinueSquadDialog.show(
      context,
      engine: previewEngine,
      currentSquadUnits: _tickManager.allies,
      reserveUnits: _inventory,
      relicService: _relicService,
      onSquadUpdated: (updatedSquad, updatedReserves) {
        setState(() {
          _tickManager.updateSquads(allies: updatedSquad);
          _inventory = List.from(updatedReserves);
        });
        _saveCurrentState();
      },
    );
  }

  void _resetToFreshPrologue() {
    _isRestoringState = true;
    try {
      setState(() {
        _crucibleSkillTreeState = CrucibleSkillTreeState();
        _totalIchor = 150;
        _cursedOre = 50;
        _bloodlineSigils = 0;
        _brimSlagCores = 2;
        _solarIron = 2;
        _quicksilver = 2;
        _crucibleTier = 1;
        _forgeTier = 1;
        _hospiceTier = 1;
        _spindleTier = 1;
        _activeGeneralType = GeneralType.vladislav;
        _phylacteryRanks = {
          GeneralType.vladislav: 1,
          GeneralType.valeria: 1,
          GeneralType.malakor: 1,
          GeneralType.morrigan: 1,
        };
        _currentChapter = 1;
        _maxUnlockedChapter = 1;
        _currentAscension = 0;
        _maxUnlockedAscension = 0;
        _completedStagesByChapter.clear();
        _stageStars.clear();
        _claimedThreeStarStages.clear();
        _hasCompletedAwakening = false;
        _clearedGauntletTrials.clear();
        _activeNode = null;
        _activeEnemyWaves = null;
        _activeDelveRoom = null;
        _activeGauntletTrial = null;
        _activeExpeditionBoons.clear();
        _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(1);
        _currentIndex = 0; // Return to Campaign / Home

        final starterSquad = StarterBrigades.createSoloStarterSquad(GeneralType.vladislav);
        _inventory = [];
        _relicService.clearAllRelics();

        _tickManager.dispose();
        _commandService.dispose();
        _tickManager = InitiativeTickManager(
          initialAllies: starterSquad,
          initialEnemies: StarterBrigades.createEnemiesForStage(chapter: 1, stageNumber: 1),
          tickInterval: const Duration(milliseconds: 140),
          onTick: () => _commandService.onSimulationTick(),
        );
        _commandService = GeneralCommandService(
          tickManager: _tickManager,
          generalType: GeneralType.vladislav,
          initialFocus: 1,
          maxFocus: GeneralCommandService.defaultMaxFocusCap,
        );
        _combatService = CombatResolutionService(
          tickManager: _tickManager,
          commandService: _commandService,
          relicService: _relicService,
        );
      });
      _ftueService.setStage(FtueStage.awakening);
    } finally {
      _isRestoringState = false;
    }

    // Dismiss any active HomeScreen modal if open so the Awakening Dialog is front and center
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    _saveCurrentState();
    _showAwakeningDialog();
  }

  void _handleOpenSummoning() {
    final bool isFirstSummon = (_tickManager.allies.length + _inventory.length) <= 1;
    SummoningScreen.showAsModal(
      context: context,
      totalIchor: _totalIchor,
      bloodlineSigils: _bloodlineSigils,
      isFirstSummon: isFirstSummon,
      hospiceTier: _hospiceTier,
      currentReserveCount: _inventory.length,
      onSummonExecuted: (result) {
        setState(() {
          _totalIchor = max(0, _totalIchor - result.ichorSpent);
          _bloodlineSigils = max(0, _bloodlineSigils - result.sigilsSpent);
          final updatedAllies = List<UnitEntity>.from(_tickManager.allies);
          final remaining = <UnitEntity>[];
          final int squadCap = (_hospiceTier >= 2 || _maxUnlockedChapter > 1 || _clearedGauntletTrials.isNotEmpty) ? 3 : 2;
          for (final u in result.summonedUnits) {
            if (updatedAllies.length < squadCap) {
              updatedAllies.add(u);
            } else {
              remaining.add(u);
            }
          }
          _tickManager.updateSquads(allies: updatedAllies);
          _inventory = [..._inventory, ...remaining];
        });
        _saveCurrentState();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlayerUnits = [
      ..._tickManager.allies,
      ..._inventory,
    ];

    // Option 1: Hide global nav bar during battle so tactical arena has 100% immersive focus
    final hideBottomBar = _currentIndex == 1;

    return Scaffold(
      body: SafeArea(
        top: !hideBottomBar,
        bottom: !hideBottomBar,
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
                    onOpenCatacombDelves: _openCatacombDelveSheet,
                    onLaunchGorgorothBoss: _launchGorgorothBossTrial,
                    onLaunchMvpSkirmish: _launchGorgorothBossTrial,
                    currentChapter: _currentChapter,
                    maxUnlockedChapter: _maxUnlockedChapter,
                    currentAscension: _currentAscension,
                    maxUnlockedAscension: _maxUnlockedAscension,
                    onAscensionChanged: (tier) {
                      setState(() {
                        _currentAscension = tier;
                      });
                      _saveCurrentState();
                    },
                    onOpenHome: () => _showHomeModal(),
                    onOpenSummoning: () => _handleOpenSummoning(),
                    onOpenSettings: () => SettingsDialog.show(context, onResetSave: _resetToFreshPrologue),
                    onChapterChanged: (ch) {
                      setState(() {
                        _currentChapter = ch;
                        _campaignNodes = CampaignMapGenerator.generateCampaignForChapter(ch);
                      });
                      _saveCurrentState();
                    },
                    completedLinearStages: _completedLinearStages,
                    stageStars: _stageStars,
                  ),
                  // Tab 1: Tactical Arena (Spatial Battlefield)
                  SpatialBattleScreen(
                    key: ValueKey('${_activeNode?.id ?? "sunder"}_${_currentChapter}_$_currentIndex'),
                    initialPlayerUnits: _tickManager.allies,
                    initialEnemyUnits: _tickManager.enemies,
                    enemyWaves: _activeEnemyWaves,
                    availableRosterUnits: _inventory,
                    commandService: _commandService,
                    onSquadUpdated: (updatedSquad) {
                      setState(() {
                        final prevAllies = List<UnitEntity>.from(_tickManager.allies);
                        final activeIds = updatedSquad.map((u) => u.id).toSet();
                        final droppedFromSquad = prevAllies.where((u) => !activeIds.contains(u.id));
                        _tickManager.updateSquads(allies: updatedSquad);
                        // Sync reserve inventory: remove active units from inventory, add any dropped
                        _inventory.removeWhere((u) => activeIds.contains(u.id));
                        final reserveIds = _inventory.map((u) => u.id).toSet();
                        for (final dropped in droppedFromSquad) {
                          if (!reserveIds.contains(dropped.id)) {
                            _inventory.add(dropped);
                            reserveIds.add(dropped.id);
                          }
                        }
                      });
                      _saveCurrentState();
                    },
                    encounterTitle: _activeNode?.name ?? 'Skirmish Encounter',
                    backdropAsset: _activeNode?.customBackgroundAsset ?? 'assets/images/backgrounds/battlefield_ashen_plains.png',
                    isBossEncounter: _activeNode?.type == CampaignNodeType.boss || _activeNode?.id == 'gorgoroth_boss_arena' || _activeNode == null,
                    maxDeployableUnits: (_hospiceTier >= 2 || _maxUnlockedChapter > 1 || _clearedGauntletTrials.isNotEmpty) ? 3 : 2,
                    spindleTier: _spindleTier,
                    onVictory: () {
                      _onCombatVictory();
                    },
                    onDefeat: () {
                      _onCombatDefeat();
                      setState(() {
                        _currentIndex = 0; // Return to Campaign Map
                      });
                    },
                    relicService: _relicService,
                    plinthService: _plinthService,
                    skillTreeState: _crucibleSkillTreeState,
                    onOpenPlinthSculptory: _openPlinthSculptorySheet,
                    onBackToStandardCombat: () {
                      setState(() {
                        _currentIndex = 0; // Return to Campaign Map
                      });
                    },
                  ),
                  // Tab 2: Crucible Altar
                  CrucibleScreen(
                    availableInventory: allPlayerUnits,
                    totalIchor: _totalIchor,
                    bloodlineSigils: _bloodlineSigils,
                    onIchorChanged: (val) {
                      setState(() => _totalIchor = val);
                      _saveCurrentState();
                    },
                    onSigilsChanged: (val) {
                      setState(() => _bloodlineSigils = val);
                      _saveCurrentState();
                    },
                    onFusionExecuted: _onFusionExecuted,
                    onFusionComplete: _onFusionComplete,
                    onUnitLeveled: (updatedUnit, cost) => _levelUpUnit(
                      unitId: updatedUnit.id,
                      xpAmount: cost,
                      ichorCost: cost,
                      replacementUnit: updatedUnit,
                    ),
                    crucibleTier: _crucibleTier,
                  ),
                  // Tab 3: Relic Forge
                  RelicForgeScreen(
                    relicService: _relicService,
                    brigadeUnits: allPlayerUnits,
                    totalIchor: _totalIchor,
                    cursedOre: _cursedOre,
                    onIchorChanged: (val) {
                      setState(() => _totalIchor = val);
                      _saveCurrentState();
                    },
                    onOreChanged: (val) {
                      setState(() => _cursedOre = val);
                      _saveCurrentState();
                    },
                    currentChapter: _currentChapter,
                    completedLinearStages: _completedLinearStages,
                    forgeTier: _forgeTier,
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
      extendBody: true,
      bottomNavigationBar: hideBottomBar
          ? null
          : Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xEB12121A),
                  border: Border(
                    top: BorderSide(color: Color(0xFF282836), width: 1.2),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex >= 5 ? 0 : _currentIndex + 1,
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: const Color(0xFFFFD54F),
                  unselectedItemColor: const Color(0xFF8E8EA0),
                  selectedFontSize: 10,
                  unselectedFontSize: 9.5,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  onTap: (index) {
                    if (index == 0) {
                      _showHomeModal();
                      return;
                    }
                    if (index == 2) {
                      _launchGorgorothBossTrial();
                      return;
                    }
                    setState(() => _currentIndex = index - 1);
                  },
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home, color: Color(0xFFFFD54F), size: 21),
                      label: 'Sanctuary',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.map, size: 21),
                      label: 'Campaign',
                    ),
                    BottomNavigationBarItem(
                      icon: Image.asset(
                        'assets/images/UI/Crossed Sword Shield Icon Transparent.png',
                        width: 21,
                        height: 21,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 21),
                      ),
                      label: 'Trials',
                    ),
                    BottomNavigationBarItem(
                      icon: Image.asset(
                        'assets/images/UI/Flame Shield icon Transparent.png',
                        width: 21,
                        height: 21,
                        errorBuilder: (_, __, ___) => const Icon(Icons.fireplace, size: 21),
                      ),
                      label: 'Blood Altar',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.auto_awesome, size: 21),
                      label: 'Relic Forge',
                    ),
                    BottomNavigationBarItem(
                      icon: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.people_alt, size: 21, color: Colors.transparent),
                          IgnorePointer(
                            child: Image.asset(
                              'assets/images/UI/Skull Shield Icon Transparent.png',
                              width: 21,
                              height: 21,
                              errorBuilder: (_, __, ___) => const Icon(Icons.people_alt, size: 21),
                            ),
                          ),
                        ],
                      ),
                      label: 'Roster',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  CrucibleSkillBranch _branchForGeneral(GeneralType type) {
    switch (type) {
      case GeneralType.vladislav:
        return CrucibleSkillBranch.resonance;
      case GeneralType.valeria:
        return CrucibleSkillBranch.bastion;
      case GeneralType.malakor:
        return CrucibleSkillBranch.wrath;
      case GeneralType.morrigan:
        return CrucibleSkillBranch.resonance;
    }
  }

  Future<void> _showGeneralSelectionDialog() async {
    final chosen = await GeneralSelectionDialog.show(
      context,
      currentGeneralType: _commandService.activeGeneralType,
      commandService: _commandService,
      bloodlineSigils: _bloodlineSigils,
      onSigilsChanged: (val) {
        setState(() => _bloodlineSigils = val);
        _saveCurrentState();
      },
      onPhylacteryUpgraded: (genType, newRank) {
        setState(() {
          _phylacteryRanks[genType] = newRank;
        });
        _saveCurrentState();
      },
    );
    if (!mounted || chosen == null) return;

    setState(() {
      _activeGeneralType = chosen;
      _commandService.setActiveGeneral(chosen);
      _phylacteryRanks = Map.of(_commandService.allPhylacteryRanks);
      final int prevLevel = _crucibleSkillTreeState.sculptorLevel;
      final int prevXp = _crucibleSkillTreeState.sculptorXp;
      final int earnedPoints = _crucibleSkillTreeState.availableSkillPoints + _crucibleSkillTreeState.totalPointsSpent;
      _crucibleSkillTreeState.configureStartingDiscipline(_branchForGeneral(chosen), startWithBasics: true);
      _crucibleSkillTreeState.sculptorLevel = max(1, prevLevel);
      _crucibleSkillTreeState.sculptorXp = prevXp;
      _crucibleSkillTreeState.availableSkillPoints = earnedPoints;
    });
    _saveCurrentState();
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
      appBar: GothicHeaderBar(
        title: 'Brigade Lineage Roster',
        categoryTag: 'Lineage',
        bloodlineSigils: _bloodlineSigils,
        actions: [
          IconButton(
            tooltip: 'Crucible Skill Tree (${_crucibleSkillTreeState.availableSkillPoints}★)',
            icon: Icon(
              Icons.auto_fix_high,
              size: 20,
              color: _crucibleSkillTreeState.availableSkillPoints > 0
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFF00E5FF),
            ),
            onPressed: _openOutOfBattleSkillTree,
          ),
          IconButton(
            tooltip: 'Retinue Squad (1+2)',
            icon: const Icon(Icons.groups, size: 20, color: Color(0xFF69F0AE)),
            onPressed: _openOutOfBattleRetinueSquad,
          ),
          IconButton(
            tooltip: 'Grimoire Deck Archives',
            icon: const Icon(Icons.auto_stories, size: 20, color: Color(0xFFBA68C8)),
            onPressed: () {
              GrimoireManagerDialog.show(
                context,
                commandService: _commandService,
                bloodlineSigils: _bloodlineSigils,
                onSigilsChanged: (val) {
                  setState(() => _bloodlineSigils = val);
                  _saveCurrentState();
                },
                onPhylacteryUpgraded: (genType, newRank) {
                  setState(() {
                    _phylacteryRanks[genType] = newRank;
                  });
                  _saveCurrentState();
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Deploy MVP Ash Legion (Lord Vladislav)',
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFFE5A93C)),
            onPressed: () async {
              setState(() {
                _activeGeneralType = GeneralType.vladislav;
                _tickManager.dispose();
                _commandService.dispose();
                _tickManager = InitiativeTickManager(
                  initialAllies: StarterBrigades.createAshLegionPlayerSquad(),
                  initialEnemies: StarterBrigades.createCryptStalkersEnemySquad(),
                  tickInterval: const Duration(milliseconds: 140),
                  onTick: () => _commandService.onSimulationTick(),
                );
                _commandService = GeneralCommandService(
                  tickManager: _tickManager,
                  generalType: GeneralType.vladislav,
                  initialFocus: 6,
                  maxFocus: GeneralCommandService.grimoireMaxFocusCap,
                  initialPhylacteryRanks: _phylacteryRanks,
                );
                _commandService.initializeGrimoire();
                _combatService = CombatResolutionService(
                  tickManager: _tickManager,
                  commandService: _commandService,
                  relicService: _relicService,
                );
                _tickManager.start();
              });
              await _saveCurrentState();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('MVP Ash Legion Deployed: Lord Vladislav leading on Frontline!'),
                    backgroundColor: Color(0xFFB3261E),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/images/UI/Main Page HUD background with less people.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Column(
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
                  child: profile.type == GeneralType.vladislav
                      ? ClipOval(
                          child: Image.asset(
                            'assets/images/Crypt Stalkers/lord_vladislav_g1.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.6),
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/lord_vladislav.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.6),
                              errorBuilder: (_, __, ___) => Icon(profile.icon, color: profile.themeColor, size: 20),
                            ),
                          ),
                        )
                      : Icon(profile.icon, color: profile.themeColor, size: 20),
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
                            '$_totalIchor GOLD',
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
                    chiselingService: _traitChiselingService,
                    onUnitUpdated: _updateUnitInRoster,
                    onLevelUp: (updatedUnit, cost) => _levelUpUnit(
                      unitId: updatedUnit.id,
                      xpAmount: cost,
                      ichorCost: cost,
                      replacementUnit: updatedUnit,
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
                                        fit: unit.isFigurineCutout ? BoxFit.contain : BoxFit.cover,
                                        alignment: unit.isFigurineCutout ? Alignment.bottomCenter : Alignment.topCenter,
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
                                  Flexible(
                                    child: Text(
                                      unit.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Color(unit.rarity.borderHexColor).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Color(unit.rarity.borderHexColor),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      unit.rarity.displayName.toUpperCase(),
                                      style: TextStyle(
                                        color: Color(unit.rarity.borderHexColor),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
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
                            if (!unit.isMaxLevel || unit.canPromoteRarity) ...[
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: unit.canPromoteRarity
                                      ? Color(unit.rarity.borderHexColor)
                                      : const Color(0xFFE5A93C),
                                  side: BorderSide(
                                    color: unit.canPromoteRarity
                                        ? Color(unit.rarity.borderHexColor)
                                        : const Color(0xFFE5A93C),
                                    width: 0.8,
                                  ),
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
                                    replacementUnit: updatedUnit,
                                  ),
                                ),
                                child: Text(
                                  unit.canPromoteRarity ? '★ PROMOTE' : 'INFUSE',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                ),
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
        ],
      ),
    );
  }

  Widget _buildCodexView() {
    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: const GothicHeaderBar(
        title: 'Affinity & Command Codex',
        categoryTag: 'Codex',
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
              'RELIC SET SYNERGY MATRIX & EQUIPMENT ROLES',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Units have 4 slots (Weapon, Armor, Talisman, Sigil). Equip two 2-piece sets or one 4-piece set to activate game-changing synergies.',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 8),
            ...RelicSetType.values.map((st) {
              return _buildCodexRelicSetItem(
                RelicEntity.setName(st),
                '${RelicEntity.setBonusDescription(st)}\nRole: ${RelicEntity.setTacticalRole(st)}',
                RelicEntity.setAccentColor(st),
                RelicEntity.setIcon(st),
              );
            }),
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
