import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/data/starter_brigades.dart';
import '../../core/combat_math.dart';
import '../../shared/utils/platform_fullscreen.dart';
import '../settings/settings_service.dart';
import '../relics/relic_service.dart';
import '../generals/general_command_service.dart';
import '../plinths/plinth_service.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';
import 'models/crucible_skill_tree_models.dart';
import 'crucible_skill_tree_dialog.dart';
import 'crucible_sanctuary_upgrade_dialog.dart';
import 'crucible_retinue_squad_dialog.dart';
import 'dialogs/crucible_debug_sandbox_dialog.dart';
import 'rank_and_rite_2d_battlefield.dart';
import '../../shared/widgets/sprite_sheet_animation.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
import '../../shared/widgets/gothic_character_sheet_card.dart';
import '../../shared/widgets/gothic_header_bar.dart';

part 'widgets/spatial_battle_vfx_painters.dart';

/// Experimental Spatial Combat Simulation Screen (GDD v3.2 Extension)
/// Features:
/// - 3-Row x 5-Column Isometric/Tactical battlefield plane
/// - Multi-Node Footprints (1x1 standard, 1x2 horizontal behemoths like Gorgoroth)
/// - Geometric Skill Vectors & Live Telegraph Shading (T-Cleaves, Crosses, Row Scythes)
/// - Tactical Plinth Triage: Drag-and-drop repositioning during 30% bullet-time
class SpatialBattleScreen extends StatefulWidget {
  final VoidCallback? onBackToStandardCombat;
  final VoidCallback? onVictory;
  final VoidCallback? onDefeat;
  final List<dynamic>? initialPlayerUnits; // UnitEntity or CombatUnitState
  final List<dynamic>? initialEnemyUnits;
  final List<List<UnitEntity>>? enemyWaves;
  final List<UnitEntity>? availableRosterUnits; // Reserve pool for tactical substitutions
  final ValueChanged<List<UnitEntity>>? onSquadUpdated;
  final String? encounterTitle;
  final String? backdropAsset;
  final bool isBossEncounter;
  final RelicService? relicService;
  final GeneralCommandService? commandService;
  final PlinthService? plinthService;
  final CrucibleSkillTreeState? skillTreeState;
  final VoidCallback? onOpenPlinthSculptory;
  final int maxDeployableUnits;
  final int spindleTier;

  const SpatialBattleScreen({
    super.key,
    this.onBackToStandardCombat,
    this.onVictory,
    this.onDefeat,
    this.initialPlayerUnits,
    this.initialEnemyUnits,
    this.enemyWaves,
    this.availableRosterUnits,
    this.onSquadUpdated,
    this.encounterTitle,
    this.backdropAsset,
    this.isBossEncounter = false,
    this.relicService,
    this.commandService,
    this.plinthService,
    this.skillTreeState,
    this.onOpenPlinthSculptory,
    this.maxDeployableUnits = 2,
    this.spindleTier = 1,
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> with TickerProviderStateMixin {
  Set<String> _computeProjectedSecondaryTargetEnemyIds() {
    final Set<String> secondaryIds = {};
    final hovered = _hoveredSkillNode;
    if (hovered != null) {
      if (hovered.branch == CrucibleSkillBranch.bastion ||
          hovered.branch == CrucibleSkillBranch.vitae) {
        return secondaryIds;
      }
      final act = hovered.actionType.toLowerCase();
      final bool isFullAoeSkill = hovered.branch == CrucibleSkillBranch.calamity ||
          act.contains('barrage') ||
          act.contains('whirlwind') ||
          act.contains('pyre') ||
          act.contains('nova') ||
          act.contains('vortex') ||
          act.contains('wrath') ||
          act.contains('cataclysm') ||
          act.contains('exsanguination') ||
          act.contains('spore');
      if (isFullAoeSkill) {
        for (final enemy in _engine.enemyUnits.where((e) => e.isAlive)) {
          if (enemy.id != _selectedEnemyUnitId) {
            secondaryIds.add(enemy.id);
          }
        }
        return secondaryIds;
      }
    }

    final actingAlly = _engine.activeActingUnit ??
        (_selectedUnitId != null ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull : null) ??
        _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;
    if (actingAlly == null) return secondaryIds;

    final targetEnemy = _selectedEnemyUnitId != null
        ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
        : _getSmartDefaultTarget();
    if (targetEnemy == null || targetEnemy.occupiedNodes.isEmpty) return secondaryIds;

    final primaryCol = targetEnemy.occupiedNodes.first.column;
    final primaryRow = targetEnemy.occupiedNodes.first.row;

    final bool isSculptor = actingAlly.isAshSculptor || actingAlly.id == 'ash_sculptor';
    final bool hasRowCleave = isSculptor ||
        actingAlly.activeStance == StanceType.holdTheLine ||
        actingAlly.id.contains('vladislav') ||
        actingAlly.signatureSkillName.toLowerCase().contains('cleave') ||
        actingAlly.signatureSkillName.toLowerCase().contains('slash') ||
        actingAlly.archetype == UnitArchetype.vanguardMelee;

    final bool hasColumnPierce = actingAlly.archetype == UnitArchetype.backlineCaster ||
        actingAlly.signatureSkillName.toLowerCase().contains('pierc') ||
        actingAlly.signatureSkillName.toLowerCase().contains('skewer') ||
        actingAlly.signatureSkillName.toLowerCase().contains('bolt');

    for (final enemy in _engine.enemyUnits.where((e) => e.isAlive && e.id != targetEnemy.id)) {
      for (final node in enemy.occupiedNodes) {
        if (hasRowCleave && node.row == primaryRow && (node.column - primaryCol).abs() == 1) {
          secondaryIds.add(enemy.id);
        } else if (hasColumnPierce && node.column == primaryCol && node.row > primaryRow) {
          secondaryIds.add(enemy.id);
        }
      }
    }
    return secondaryIds;
  }

  void _openUnitInspectorDialog(CombatUnitState unit) {
    UnitEntity? entity = _currentSquadUnits.where((u) => u.id == unit.id).firstOrNull ??
        _reserveUnits.where((u) => u.id == unit.id).firstOrNull;

    if (entity == null) {
      Archetype mappedRole;
      switch (unit.archetype) {
        case UnitArchetype.vanguardMelee:
          mappedRole = Archetype.juggernaut;
          break;
        case UnitArchetype.reachMidline:
          mappedRole = Archetype.assassin;
          break;
        case UnitArchetype.backlineCaster:
          mappedRole = Archetype.occultist;
          break;
        case UnitArchetype.colossusBehemoth:
          mappedRole = Archetype.juggernaut;
          break;
      }
      entity = UnitEntity(
        id: unit.id,
        speciesId: unit.templateId,
        name: unit.name,
        generation: 1,
        archetype: mappedRole,
        slot: FormationSlot.front1,
        level: unit.level,
        maxLevel: 30,
        currentHp: unit.hp,
        maxHp: unit.maxHp,
        attack: unit.attack,
        defense: unit.armor,
        speed: unit.speed,
        nativeTraitId: unit.nativeTraitId ?? 'iron_will',
        graftedTraitId: unit.graftedTraitId,
        lineageAncestors: const [],
        customAvatarAsset: unit.customAssetPath,
      );
    }

    final bool wasRunning = _engine.isRunning;
    if (wasRunning) {
      _engine.isRunning = false;
    }

    _playSfx('sfx_card.wav');

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: GothicCharacterSheetCard(
          unit: entity!,
          relicService: widget.relicService,
          totalIchor: 0,
          onClose: () => Navigator.of(dialogCtx).pop(),
          onToggleClassicCodex: () {
            Navigator.of(dialogCtx).pop();
            PedigreeInspectorDialog.show(
              context,
              entity!,
              isEnemy: !unit.isPlayer,
              relicService: widget.relicService,
              initialShowCharacterSheet: false,
            );
          },
        ),
      ),
    ).then((_) {
      if (mounted && wasRunning && !_engine.isTurnExecutionPaused) {
        setState(() {
          _engine.isRunning = true;
        });
      }
    });
  }
  late SpatialCombatEngine _engine;
  List<UnitEntity> _currentSquadUnits = [];
  List<UnitEntity> _reserveUnits = [];
  Ticker? _frameTicker;
  Duration _lastFrameElapsed = Duration.zero;
  final ValueNotifier<int> _visualFrameTick = ValueNotifier<int>(0);
  String? _selectedUnitId;
  String? _selectedEnemyUnitId;
  String? _hoveredEnemyUnitId;
  String? _draggedUnitId;
  String? _selectedUltimateUnitId;
  String? _draggedUltimateUnitId;
  int? _hoveredTileGRow;
  int? _hoveredTileCol;
  bool _showAllTrajectories = false;
  bool _isZenMode = false;
  bool _is2DGridView = true;
  int? _hovered2DRow;
  bool? _isHovered2DPlayerSide;
  double _tickAccumulator = 0.0;
  double _dashPhase = 0.0;

  // Visual Combat Feedback & VFX State
  String? _lastHandledEventId;
  final List<SpatialActionEvent> _actionEventQueue = [];
  bool _isActionSequenceRunning = false;
  int _activeAttackSequenceId = 0;
  String? _attackingUnitId;
  String? _attackingSkillName;
  bool _attackingIsSignatureSkill = false;
  final Map<String, String> _activeImpactSlashUnits = {};
  final Map<String, int> _visualUnitHp = {};
  final Map<String, int> _lastCommittedUnitHp = {};
  final Set<String> _visualAliveOverrideIds = {};
  bool _holdEndOfBattleOverlay = false;
  final Map<String, Offset> _lastKnown2DUnitOffsets = {};
  int? _activeFireBarrageMs;
  String _fireBarrageAssetPath = 'assets/images/Spells/meteor storm.png';
  List<Alignment> _fireBarrageTargetAlignments = [];
  List<String> _fireBarrageTargetIds = [];
  bool? _timelineExpandedOverride;
  CrucibleSkillNode? _hoveredSkillNode;
  String? _activeSynergyBannerText;
  Color _activeSynergyBannerColor = const Color(0xFFFFD54F);
  String? _damagedUnitId;
  final Set<String> _damagedUnitIds = {};
  final Set<String> _recoilingUnitIds = {};
  String? _lungingUnitId;
  double _lungeTargetDeltaY = 0.0;
  String? _activeSkillName;
  String? _activeSkillCasterName;
  CombatUnitState? _activeSkillCaster;
  bool _isPlayerSkillBanner = false;
  CombatUnitState? _activeUltimateUnit; // Active Ultimate Burst Cinematic Cut-in
  CombatUnitState? _activeSignatureUnit; // Active Signature Skill Spotlight Cut-in
  final Map<String, String> _unitFloatingPops = {};
  final List<_FloatingCombatText> _floatingPops = [];
  final List<Timer> _animTimers = [];
  final List<_CombatVfx> _activeVfx = [];
  final List<_GroundShockwaveRipple> _groundRipples = [];
  Offset _screenShakeOffset = Offset.zero;
  double _shakeIntensity = 0.0;
  double _shakeRemainingSec = 0.0;
  double _shakeDurationSec = 0.14;
  double _shakePhase = 0.0;
  bool _enableScreenShake = true; // Accessible motion comfort toggle
  double _battlefieldCameraZoom = 1.0;
  double _cameraZoomPeak = 1.0;
  double _cameraZoomRemainingSec = 0.0;
  double _cameraZoomDurationSec = 0.25;
  bool _isSlowMoFinisher = false;

  // Option 3: Interactive Forge Strike Tactile Finisher
  bool _isForgeStrikeActive = false;
  double _forgeStrikeProgress = 0.0;
  Timer? _forgeStrikeTimer;
  bool _forgeStrikeHit = false;
  bool _forgeStrikeIsPerfect = false;
  CombatUnitState? _forgeStrikeUnit;
  CombatUnitState? _forgeStrikeTarget;
  String _forgeStrikeActionType = 'cataclysmic_pyre';
  bool _wasRunningBeforeForgeStrike = false;

  // Ambient Dark Fantasy Combat Audio
  AudioPlayer? _bgmPlayer;
  final List<AudioPlayer> _sfxPlayers = [];
  int _sfxIndex = 0;
  static const int _maxSfxPlayers = 8;
  bool _isMuted = false;
  bool _isLogDrawerVisible = false;
  bool _hasBossEnraged = false;
  bool _wasBossStaggered = false;
  EncounterPhase _lastObservedPhase = EncounterPhase.standard;

  late final FocusNode _battlefieldFocusNode;

  /// Resolves generic SFX names to visceral acoustic assets
  static String _resolveSfx(String sfxName) {
    switch (sfxName) {
      case 'sfx_block.wav':
        return 'WEAPArmr_Metal Shield Block Hits_JSE_MW.wav';
      case 'sfx_slash.wav':
        return 'SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav';
      case 'sfx_hit.wav':
        return 'WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav';
      case 'sfx_spell.wav':
        return 'Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav';
      case 'sfx_card.wav':
        return 'SWSH_Swing 3 Large 03_DDUMAIS_NONE.wav';
      case 'sfx_summon.wav':
        return 'CHAINMvmt_InsJ_Chains_Metal_Movement_Distant_Moderate_02-01.wav';
      case 'sfx_crit.wav':
        return 'GOREBone_Bone Breaks Celery 01_JSE_GMP.wav';
      case 'sfx_blood.wav':
        return 'GORESplt_Gore Splatter 01_JSE_GMP.wav';
      case 'sfx_smite.wav':
      case 'sfx_hammer.wav':
        return 'Bluezone_BC0297_stone_impact_hammer_015.wav';
      case 'sfx_shatter.wav':
        return 'WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav';
      case 'sfx_enrage.wav':
        return 'Dinosaur Growl 3_Mono.wav';
      default:
        return sfxName;
    }
  }

  @override
  void initState() {
    super.initState();
    _battlefieldFocusNode = FocusNode();
    SpriteSheetAnimation.precache('assets/animations/ash_sculptor_attack_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/ash_sculptor_defend_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/ash_sculptor_idle_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/blood_scribe_idle_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/valeria_slash_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/iron_footman_idle_sheet.png');
    SpriteSheetAnimation.precache('assets/images/Spells/meteor storm.png');
    SpriteSheetAnimation.precache('assets/images/Spells/vortex of molten.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/ironclad warden idle.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/ironclad warden attack.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/ironclad warden skill.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/blood alchemist idle.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/blood alchemist attack animation.png');
    SpriteSheetAnimation.precache('assets/images/Ash sculpter/blood alchemist skill cast.png');
    final players = widget.initialPlayerUnits?.whereType<UnitEntity>().toList();
    final enemies = widget.initialEnemyUnits?.whereType<UnitEntity>().toList();

    _currentSquadUnits = players != null ? List<UnitEntity>.from(players) : [];
    _reserveUnits = widget.availableRosterUnits != null
        ? List<UnitEntity>.from(widget.availableRosterUnits!)
        : [];

    _engine = SpatialCombatEngine(
      initialPlayerEntities: players,
      initialEnemyEntities: enemies,
      enemyWaves: widget.enemyWaves,
      title: widget.encounterTitle,
      isBossEncounter: widget.isBossEncounter,
      relicService: widget.relicService,
      commandService: widget.commandService,
      plinthService: widget.plinthService,
      skillTreeState: widget.skillTreeState,
      maxDeployableUnits: widget.maxDeployableUnits,
      spindleTier: widget.spindleTier,
    );
    _engine.isActionPauseEnabled = true;
    for (final u in [..._engine.playerUnits, ..._engine.enemyUnits]) {
      _visualUnitHp[u.id] = u.hp;
      _lastCommittedUnitHp[u.id] = u.hp;
    }
    _precacheActiveUnitSheets();
    _engine.addListener(_onEngineUpdate);
    _startLoop();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (kIsWeb) {
        AudioCache.instance.prefix = '';
      }
      final settings = SettingsService();
      _isMuted = !settings.bgmEnabled && !settings.sfxEnabled;
      _bgmPlayer = AudioPlayer();
      _sfxPlayers.clear();
      for (int i = 0; i < _maxSfxPlayers; i++) {
        final player = AudioPlayer();
        if (!kIsWeb) {
          await player.setPlayerMode(PlayerMode.lowLatency);
        }
        _sfxPlayers.add(player);
      }
      
      // Stop loop event spam on Windows native backend
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      final bgmVol = _isMuted ? 0.0 : (settings.bgmVolume * 0.45);
      await _bgmPlayer!.setVolume(bgmVol);
      for (final player in _sfxPlayers) {
        await player.setVolume(settings.sfxVolume * 0.70);
      }
      if (settings.bgmEnabled) {
        await _bgmPlayer!.play(AssetSource('audio/combat_bgm_ambient.mp3'));
      }
    } catch (e) {
      debugPrint('Error starting combat audio: $e');
    }
  }

  void _playSfx(String sfxName, {double volumeMultiplier = 0.70}) {
    final settings = SettingsService();
    if (_isMuted || !settings.sfxEnabled || _sfxPlayers.isEmpty) return;
    try {
      final resolved = _resolveSfx(sfxName);
      final player = _sfxPlayers[_sfxIndex];
      _sfxIndex = (_sfxIndex + 1) % _sfxPlayers.length;

      final vol = (settings.sfxVolume * volumeMultiplier).clamp(0.0, 1.0);
      player.setVolume(vol).catchError((_) {});
      player.play(AssetSource('audio/$resolved')).catchError((_) {
        // Silently ignore audio playback errors on web (404s/codecs)
      });
    } catch (_) {
      // Silently ignore
    }
  }

  void _toggleMute() {
    final settings = SettingsService();
    final newMuted = !_isMuted;
    setState(() {
      _isMuted = newMuted;
    });
    settings.setBgmEnabled(!newMuted);
    settings.setSfxEnabled(!newMuted);
    if (newMuted) {
      _bgmPlayer?.setVolume(0.0).catchError((_) {});
      _bgmPlayer?.pause().catchError((_) {});
      for (final p in _sfxPlayers) {
        p.setVolume(0.0).catchError((_) {});
        p.stop().catchError((_) {});
      }
    } else {
      _bgmPlayer?.setVolume(settings.bgmVolume * 0.45).catchError((_) {});
      if (_bgmPlayer?.state == PlayerState.paused) {
        _bgmPlayer?.resume().catchError((_) {});
      } else if (_bgmPlayer?.state != PlayerState.playing) {
        _bgmPlayer?.play(AssetSource('audio/combat_bgm_ambient.mp3')).catchError((_) {});
      }
      for (final p in _sfxPlayers) {
        p.setVolume(settings.sfxVolume * 0.70).catchError((_) {});
      }
    }
  }

  void _onEngineUpdate() {
    if (!mounted) return;

    // GDD Sec 7.1: Ashen Reckoning Phase Transition Tracking
    final currentPhase = _engine.currentPhase;
    if (currentPhase != _lastObservedPhase) {
      _lastObservedPhase = currentPhase;
      if (currentPhase == EncounterPhase.warningChime) {
        _playSfx('sfx_block.wav');
        _activeSynergyBannerText = '⚠️ WARNING CHIME: 15s TO ASHEN RECKONING!';
        _activeSynergyBannerColor = const Color(0xFFFFD54F);
      } else if (currentPhase == EncounterPhase.ashenReckoning) {
        _playSfx('sfx_spell.wav');
        _triggerScreenShake(intensity: 3.5);
        _activeSynergyBannerText = '🔥 THE ASHEN RECKONING HAS BEGUN! (2.0x Dmg / -50% Heals)';
        _activeSynergyBannerColor = const Color(0xFFFF5252);
      } else if (currentPhase == EncounterPhase.terminalCollapse) {
        _playSfx('sfx_slash.wav');
        _triggerScreenShake(intensity: 4.5);
        _activeSynergyBannerText = '💀 TERMINAL COLLAPSE! (True Dmg / Revives Disabled)';
        _activeSynergyBannerColor = const Color(0xFFE040FB);
      }
    }

    // Boss Enrage Check: When boss drops under 50% HP, trigger Enrage Roar & Arena Shake!
    final boss = _engine.enemyUnits.where((u) => (u.id == 'gorgoroth_boss' || u.footprint != UnitFootprint.single1x1) && u.isAlive).firstOrNull;
    if (boss != null && !_hasBossEnraged && boss.hp <= (boss.maxHp * 0.50)) {
      _hasBossEnraged = true;
      _playSfx('Dinosaur Growl 3_Mono.wav');
      _triggerScreenShake(intensity: 4.0);
      _activeSynergyBannerText = '🔥 ' + boss.name.toUpperCase() + ' ENTERS ASHEN ENRAGE!';
      _activeSynergyBannerColor = const Color(0xFFFF3D00);
      Timer(const Duration(milliseconds: 2200), () {
        if (mounted && _activeSynergyBannerText != null && _activeSynergyBannerText!.contains('ASHEN ENRAGE')) {
          setState(() {
            _activeSynergyBannerText = null;
          });
        }
      });
    }

    // Boss Stagger / Break Bar audio and shake transition
    if (boss != null) {
      if (boss.isStaggered && !_wasBossStaggered) {
        _wasBossStaggered = true;
        _playSfx('Bluezone_BC0297_stone_impact_hammer_015.wav');
        _playSfx('WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav');
        _triggerScreenShake(intensity: 4.0);
      } else if (!boss.isStaggered && _wasBossStaggered) {
        _wasBossStaggered = false;
        _playSfx('WEAPArmr_Metal Shield Block Hits_JSE_MW.wav');
      }
    }

    // Check if a new combat action event was dispatched
    final event = _engine.activeActionEvent;
    final bool isNewEvent = event != null && event.id != _lastHandledEventId;

    final Set<String> deferredIds = {};
    if (isNewEvent && !_isDotEvent(event)) {
      deferredIds.add(event.targetId);
      deferredIds.addAll(event.secondaryTargetHits.keys);
      if (event.isHeal || event.healAmount > 0) {
        deferredIds.add(event.healTargetId ?? event.attackerId);
      }
    }

    for (final u in [..._engine.playerUnits, ..._engine.enemyUnits]) {
      if (!_visualUnitHp.containsKey(u.id)) {
        _visualUnitHp[u.id] = u.hp;
        _lastCommittedUnitHp[u.id] = u.hp;
      } else if (deferredIds.contains(u.id)) {
        final int heldHp = _lastCommittedUnitHp[u.id] ?? u.hp;
        _visualUnitHp[u.id] = heldHp;
        if (heldHp > 0 && !u.isAlive) {
          _visualAliveOverrideIds.add(u.id);
        }
      } else if (!_isActionSequenceRunning && _actionEventQueue.isEmpty && !isNewEvent) {
        _visualUnitHp[u.id] = u.hp;
        _lastCommittedUnitHp[u.id] = u.hp;
        _visualAliveOverrideIds.remove(u.id);
      }
    }

    if (isNewEvent) {
      _lastHandledEventId = event.id;
      if (_isDotEvent(event)) {
        _triggerLightweightDotPop(event);
      } else {
        if (_engine.isVictory || _engine.isDefeat) {
          _holdEndOfBattleOverlay = true;
        }
        _enqueueCombatEvent(event);
      }
    }

    if (!_isActionSequenceRunning && _actionEventQueue.isEmpty && !isNewEvent && !_isSlowMoFinisher) {
      _visualAliveOverrideIds.clear();
      _holdEndOfBattleOverlay = false;
    }

    setState(() {});
  }

  bool _isDotEvent(SpatialActionEvent e) {
    return e.attackerId.startsWith('status_') ||
        e.skillName == 'Hemorrhage' ||
        e.skillName == 'Caustic Toxin' ||
        e.skillName == 'Ignition';
  }

  void _triggerLightweightDotPop(SpatialActionEvent event) {
    final allUnits = [..._engine.playerUnits, ..._engine.enemyUnits];
    final target = allUnits.where((u) => u.id == event.targetId).firstOrNull;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    if (target != null) {
      _visualUnitHp[target.id] = target.hp;
      _lastCommittedUnitHp[target.id] = target.hp;
      if (!target.isAlive) {
        _visualAliveOverrideIds.remove(target.id);
      }
    }

    final bool isBleed = event.skillName == 'Hemorrhage';
    final bool isPoison = event.skillName == 'Caustic Toxin';
    final String prefix = isBleed ? '🩸' : (isPoison ? '☠️' : '🔥');
    final Color popColor = isBleed
        ? const Color(0xFFFF3D00)
        : (isPoison ? const Color(0xFF69F0AE) : const Color(0xFFFF9100));
    final Color borderColor = isBleed
        ? const Color(0xFFDD2C00)
        : (isPoison ? const Color(0xFF00C853) : const Color(0xFFE65100));

    final int existingCount = _floatingPops.where((p) => p.unitId == event.targetId && !p.isExpired).length;
    final double drift = (existingCount % 2 == 1 ? -1.0 : 1.0) * (8.0 + existingCount * 6.0);

    _floatingPops.add(_FloatingCombatText(
      id: 'dot_${event.id}_$nowMs',
      unitId: event.targetId,
      text: '$prefix -${event.damage}',
      color: popColor,
      borderColor: borderColor,
      fontSize: 10.5,
      isCrit: false,
      createdMs: nowMs,
      durationMs: _scaledMs(1400),
      horizontalDrift: drift,
    ));

    if (_engine.activeActionEvent?.id == event.id && _actionEventQueue.isEmpty && !_isActionSequenceRunning) {
      Future.microtask(() {
        if (mounted && _engine.activeActionEvent?.id == event.id) {
          _engine.clearActiveAction();
        }
      });
    }
  }

  Offset _getUnitCenterIsometricOffset(CombatUnitState unit, {double tileWidth = 152.0, double tileHeight = 76.0}) {
    if (unit.occupiedNodes.isEmpty) return const Offset(100, 100);

    const int numGRows = 7;
    final double originX = (numGRows - 1) * (tileWidth * 0.5);
    final double originY = 0.0;

    if (unit.occupiedNodes.length > 1) {
      double sumCol = 0;
      double sumGRow = 0;
      for (final n in unit.occupiedNodes) {
        sumCol += n.column;
        sumGRow += unit.isPlayer ? (n.row + 4) : (2 - n.row);
      }
      final double midCol = sumCol / unit.occupiedNodes.length;
      final double midGRow = sumGRow / unit.occupiedNodes.length;
      final double screenX = originX + (midCol - midGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
      final double screenY = originY + (midCol + midGRow) * (tileHeight * 0.5) + (tileHeight * 0.35);
      return Offset(screenX, screenY);
    }

    final anchor = unit.occupiedNodes.first;
    final int col = anchor.column;
    final int localRow = anchor.row;
    final int gRow = unit.isPlayer ? (localRow + 4) : (2 - localRow);

    final double screenX = originX + (col - gRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
    final double screenY = originY + (col + gRow) * (tileHeight * 0.5) + (tileHeight * 0.35);
    return Offset(screenX, screenY);
  }

  void _precacheActiveUnitSheets() {
    for (final u in [..._engine.playerUnits, ..._engine.enemyUnits]) {
      final animSet = _resolveUnitAnimSet(u);
      if (animSet != null) {
        SpriteSheetAnimation.precache(animSet.idleSheet);
        SpriteSheetAnimation.precache(animSet.attackSheet);
        SpriteSheetAnimation.precache(animSet.skillSheet);
      }
    }
  }

  _UnitAnimSet? _resolveUnitAnimSet(CombatUnitState unit) {
    if (unit.isAshSculptor || unit.id == 'ash_sculptor') return null;
    final key = '${unit.id.toLowerCase()}_${unit.templateId.toLowerCase()}_${unit.assetPath.toLowerCase()}';
    if (key.contains('gorgoroth') || key.contains('chapter_titan')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/gorgoroth_idle_sheet.png',
        attackSheet: 'assets/animations/units/gorgoroth_attack_sheet.png',
        skillSheet: 'assets/animations/units/gorgoroth_skill_sheet.png',
      );
    }
    if (key.contains('ashen_huskarl') || key.contains('huskarl') || key.contains('rotting_husk')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/ashen_huskarl_idle_sheet.png',
        attackSheet: 'assets/animations/units/ashen_huskarl_attack_sheet.png',
        skillSheet: 'assets/animations/units/ashen_huskarl_skill_sheet.png',
      );
    }
    if (key.contains('ashfire_skirmisher') || key.contains('pyre_zealot')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/ashfire_skirmisher_idle_sheet.png',
        attackSheet: 'assets/animations/units/ashfire_skirmisher_attack_sheet.png',
        skillSheet: 'assets/animations/units/ashfire_skirmisher_skill_sheet.png',
      );
    }
    if (key.contains('pyre_sentry')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/pyre_sentry_idle_sheet.png',
        attackSheet: 'assets/animations/units/pyre_sentry_attack_sheet.png',
        skillSheet: 'assets/animations/units/pyre_sentry_skill_sheet.png',
      );
    }
    if (key.contains('blood_initiate') || key.contains('cinder_witch')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/blood_initiate_idle_sheet.png',
        attackSheet: 'assets/animations/units/blood_initiate_attack_sheet.png',
        skillSheet: 'assets/animations/units/blood_initiate_skill_sheet.png',
      );
    }
    if (key.contains('flayed_butcher')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/flayed_butcher_idle_sheet.png',
        attackSheet: 'assets/animations/units/flayed_butcher_attack_sheet.png',
        skillSheet: 'assets/animations/units/flayed_butcher_skill_sheet.png',
      );
    }
    if (key.contains('grave_ghoul') || key.contains('decayed_ghoul')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/grave_ghoul_idle_sheet.png',
        attackSheet: 'assets/animations/units/grave_ghoul_attack_sheet.png',
        skillSheet: 'assets/animations/units/grave_ghoul_skill_sheet.png',
      );
    }
    if (key.contains('grave_duelist') || key.contains('duelist')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/grave_duelist_idle_sheet.png',
        attackSheet: 'assets/animations/units/grave_duelist_attack_sheet.png',
        skillSheet: 'assets/animations/units/grave_duelist_skill_sheet.png',
      );
    }
    if (key.contains('marksman_base') || key.contains('iron_arbalest') || key.contains('arbalest')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/iron_arbalest_idle_sheet.png',
        attackSheet: 'assets/animations/units/iron_arbalest_attack_sheet.png',
        skillSheet: 'assets/animations/units/iron_arbalest_skill_sheet.png',
      );
    }
    if (key.contains('sun_scorched_cleric') || key.contains('cleric') || key.contains('sun_smith')) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/sun_scorched_cleric_idle_sheet.png',
        attackSheet: 'assets/animations/units/sun_scorched_cleric_attack_sheet.png',
        skillSheet: 'assets/animations/units/sun_scorched_cleric_skill_sheet.png',
      );
    }
    if (key.contains('feral_warhound') || key.contains('warhound') || (key.contains('hound') && !key.contains('cerberus'))) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/units/feral_warhound_idle_sheet.png',
        attackSheet: 'assets/animations/units/feral_warhound_attack_sheet.png',
        skillSheet: 'assets/animations/units/feral_warhound_skill_sheet.png',
      );
    }
    if (unit.isPlayer && (key.contains('iron_footman') || key.contains('footman') || key.contains('tombstone_sentinel'))) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/iron_footman_idle_sheet.png',
        attackSheet: 'assets/animations/units/iron_footman_attack_sheet.png',
        skillSheet: 'assets/animations/units/iron_footman_skill_sheet.png',
      );
    }
    if (key.contains('blood_scribe') || (key.contains('scribe') && !key.contains('grave_ripper'))) {
      return const _UnitAnimSet(
        idleSheet: 'assets/animations/blood_scribe_idle_sheet.png',
        attackSheet: 'assets/animations/units/blood_scribe_attack_sheet.png',
        skillSheet: 'assets/animations/units/blood_scribe_skill_sheet.png',
      );
    }
    return null;
  }

  bool _isNativelyLeftFacingSprite(String assetPath) {
    final p = assetPath.toLowerCase();
    return p.contains('blood_initiate') ||
        p.contains('grave_ghoul') ||
        p.contains('flayed_butcher') ||
        p.contains('ashfire_skirmisher') ||
        p.contains('pyre_sentry_arbalest') ||
        p.contains('ashen_huskarl') ||
        p.contains('gorgoroth_the_flayed') ||
        p.contains('sanguine_flayer') ||
        p.contains('tombstone sentinel') ||
        p.contains('magma_golem') ||
        p.contains('gorgoroth');
  }

  bool _shouldMirrorUnitSprite(CombatUnitState unit) {
    // Ash Sculptor is always on the player side and natively faces right
    if (unit.isAshSculptor || unit.id == 'ash_sculptor') return false;
    final bool nativelyLeft = _isNativelyLeftFacingSprite(unit.assetPath);
    // Player units (left side) face right (+X); Enemy units (right side) face left (-X).
    return unit.isPlayer ? nativelyLeft : !nativelyLeft;
  }

  int _hitStopRemainingMs = 0;

  void _triggerHitStop({int durationMs = 70}) {
    _hitStopRemainingMs = max(_hitStopRemainingMs, durationMs);
  }

  int _scaledMs(int ms) {
    final speed = _engine.combatPacingSpeed.clamp(1.0, 2.0);
    return (ms / speed).round();
  }

  void _triggerCameraImpactZoom({double zoomScale = 1.05, int durationMs = 260}) {
    if (!mounted) return;
    _cameraZoomPeak = zoomScale;
    _cameraZoomDurationSec = max(0.08, _scaledMs(durationMs) / 1000.0);
    _cameraZoomRemainingSec = _cameraZoomDurationSec;
  }

  void _triggerScreenShake({double intensity = 4.0, int durationMs = 150}) {
    if (!_enableScreenShake) return;
    _shakeIntensity = max(_shakeIntensity, intensity.clamp(0.0, 6.0));
    _shakeDurationSec = max(0.08, durationMs / 1000.0);
    _shakeRemainingSec = _shakeDurationSec;
  }

  void _enqueueCombatEvent(SpatialActionEvent event) {
    _actionEventQueue.add(event);
    _drainNextCombatEvent();
  }

  void _drainNextCombatEvent() {
    if (_isActionSequenceRunning || _actionEventQueue.isEmpty) return;
    _isActionSequenceRunning = true;
    final nextEvent = _actionEventQueue.removeAt(0);
    _triggerVisualCombatSequence(nextEvent);
  }

  void _triggerVisualCombatSequence(SpatialActionEvent event) {
    // Locate caster and target units to calculate real isometric trajectory points
    final allUnits = [..._engine.playerUnits, ..._engine.enemyUnits];
    final caster = allUnits.where((u) => u.id == event.attackerId).firstOrNull;
    final target = allUnits.where((u) => u.id == event.targetId).firstOrNull;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final targetOffset = target != null ? _getUnitCenterIsometricOffset(target) : const Offset(280, 200);
    final casterOffset = caster != null ? _getUnitCenterIsometricOffset(caster) : Offset(targetOffset.dx, targetOffset.dy + 80);

    final bool isUltimate = event.id.startsWith('ult_');
    final bool isSignature = event.isSignatureSkill;
    final bool hasNamedSkill = event.skillName.isNotEmpty &&
        !event.isAssistStrike &&
        !event.isWallSplat &&
        !event.isUnitCollision &&
        !event.skillName.toLowerCase().contains('basic strike') &&
        !event.skillName.toLowerCase().contains('attack');

    // Stage 1 Announcement Banner Duration:
    // Brief, punchy skill/ultimate herald that scales with combat speed.
    int bannerDurationMs = 0;
    if (isUltimate && caster != null && caster.isPlayer) {
      bannerDurationMs = _scaledMs(360);
    } else if (isSignature && caster != null) {
      bannerDurationMs = _scaledMs(260);
    } else if (hasNamedSkill) {
      bannerDurationMs = _scaledMs(170);
    }

    void executePhysicalImpact() {
      if (!mounted) return;

      final int seqId = ++_activeAttackSequenceId;
      final String impactSkillName = event.skillName;

      // 1. Clear any active cut-in banner so the battlefield and damage numbers are completely unblocked!
      setState(() {
        _activeUltimateUnit = null;
        _activeSignatureUnit = null;
        _activeSkillName = null;
        _activeSkillCaster = null;
        _activeSkillCasterName = null;
      });

      final impactNowMs = DateTime.now().millisecondsSinceEpoch;

      // Determine VFX visual flavor based on attack type & crit
      String vfxType = 'slash';
      Color primaryColor = const Color(0xFFFF5252);
      Color secondaryColor = const Color(0xFFFF8A80);
      int durationMs = 560;

      if (event.isAssistStrike) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFF00E5FF);
        durationMs = 620;
        _playSfx('SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav');
      } else if (event.isWallSplat) {
        vfxType = 'heavy_slam';
        primaryColor = const Color(0xFFFF9100);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 680;
        _playSfx('WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav');
      } else if (event.isUnitCollision) {
        vfxType = 'heavy_slam';
        primaryColor = const Color(0xFFFF5252);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 620;
        _playSfx('Heavy Body Crunch 02.wav');
      } else if (event.skillName.contains('Cold Iron Slam') || event.skillName.contains('Sundering') || event.skillName.contains('Bulwark') || event.skillName.contains('Bastion')) {
        vfxType = 'heavy_slam';
        primaryColor = event.skillName.contains('Sundering Brand') ? const Color(0xFFFF6D00) : const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 650;
        _playSfx('Bluezone_BC0297_stone_impact_hammer_015.wav');
      } else if (event.skillName.contains('Fire Barrage') ||
          event.skillName.contains('Vortex') ||
          event.skillName.contains('Maelstrom') ||
          event.skillName.contains('Catacomb')) {
        final bool useMoltenVortex = event.skillName.contains('Vortex') || event.skillName.contains('Maelstrom') || event.skillName.contains('Catacomb');
        vfxType = 'heavy_slam';
        primaryColor = useMoltenVortex ? const Color(0xFFFF3D00) : const Color(0xFFFF6D00);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 700;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
        _playSfx('WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav');
        final hitIds = <String>{event.targetId, ...event.secondaryTargetHits.keys};
        final alignments = <Alignment>[];
        for (final hitId in hitIds) {
          final hitUnit = _engine.enemyUnits.where((e) => e.id == hitId).firstOrNull;
          if (hitUnit != null && hitUnit.occupiedNodes.isNotEmpty) {
            double avgRow = 0;
            double avgCol = 0;
            for (final n in hitUnit.occupiedNodes) {
              avgRow += n.row;
              avgCol += n.column;
            }
            avgRow /= hitUnit.occupiedNodes.length;
            avgCol /= hitUnit.occupiedNodes.length;
            alignments.add(Alignment(
              (0.16 + avgRow * 0.28).clamp(0.10, 0.85),
              (-0.22 + avgCol * 0.28).clamp(-0.35, 0.45),
            ));
          }
        }
        _fireBarrageAssetPath = useMoltenVortex
            ? 'assets/images/Spells/vortex of molten.png'
            : 'assets/images/Spells/meteor storm.png';
        _fireBarrageTargetIds = hitIds.toList();
        _fireBarrageTargetAlignments = alignments.isNotEmpty
            ? alignments
            : const [Alignment(0.38, 0.05)];
        _activeFireBarrageMs = impactNowMs;
        final int clearDelayMs = 950 + ((_fireBarrageTargetAlignments.length - 1).clamp(0, 6) * 140) + 100;
        Timer(Duration(milliseconds: clearDelayMs), () {
          if (mounted && _activeFireBarrageMs == impactNowMs) {
            setState(() {
              _activeFireBarrageMs = null;
              _fireBarrageTargetIds = [];
            });
          }
        });
      } else if (event.skillName.contains('Forge Cleave') || event.skillName.contains('Whirlwind') || event.skillName.contains('Pyre')) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFF5722);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 580;
        _playSfx('WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav');
      } else if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova') || event.skillName.contains('Evisceration') || event.skillName.contains('Crimson Dread')) {
        vfxType = 'bloodnova';
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFFD50000);
        durationMs = 700;
        _playSfx('GORESplt_Gore Splatter 01_JSE_GMP.wav');
      } else if (event.skillName.contains('Sovereign Cleave') || event.skillName.contains('Vanguard Cleave')) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 600;
        _playSfx('WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav');
      } else if (event.skillName.contains('Deadeye Execution') || event.skillName.contains('Siege-Breaker') || event.skillName.contains('Phantom Riposte')) {
        vfxType = 'slash';
        primaryColor = const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 560;
        _playSfx('SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav');
      } else if (event.skillName.contains('Celestial Surge')) {
        vfxType = 'shockwave';
        primaryColor = const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 680;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
      } else if (event.skillName.contains('Siphon Rend') || event.skillName.contains('Crimson Brand') || event.skillName.contains('Sanguine Siphon') || event.skillName.contains('Flensing') || event.bleedStacks > 0) {
        vfxType = 'bloodsiphon';
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFF880E4F);
        durationMs = 640;
        _playSfx('GORESplt_Gore Splatter 01_JSE_GMP.wav');
      } else if (event.skillName.contains('Corrosive') || event.skillName.contains('Miasmic')) {
        vfxType = 'shockwave';
        primaryColor = const Color(0xFF69F0AE);
        secondaryColor = const Color(0xFFAB47BC);
        durationMs = 620;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
      } else if (event.skillName.contains('Smite') || event.skillName.contains('SHATTERS')) {
        vfxType = 'heavy_slam';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFF00E5FF);
        durationMs = 650;
        _playSfx('Bluezone_BC0297_stone_impact_hammer_015.wav');
      } else if (event.skillName.contains('Arrow') || event.skillName.contains('Shot') || event.skillName.contains('Archer') || event.skillName.contains('Arbalest') || (caster != null && caster.name.contains('Arbalest'))) {
        vfxType = 'arrow';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFFFF8A80);
        durationMs = 480;
        _playSfx('Bluezone_BC0261_mountain_dweller_tool_axe_whoosh_impact_003.wav');
      } else if (event.skillName.contains('Sun') || event.skillName.contains('Orb') || event.skillName.contains('Cinder') || event.skillName.contains('Bolt') || (caster != null && caster.archetype == UnitArchetype.backlineCaster)) {
        vfxType = 'firebolt';
        primaryColor = event.isPlayerAttacker ? const Color(0xFFFF9100) : const Color(0xFFFF3D00);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 540;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
      } else if (event.isHeal || event.skillName.contains('Phalanx')) {
        vfxType = 'heal_pulse';
        primaryColor = const Color(0xFF69F0AE);
        secondaryColor = const Color(0xFF00E5FF);
        durationMs = 650;
        _playSfx('WEAPArmr_Metal Shield Block Hits_JSE_MW.wav');
      } else if (event.isCrit) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 620;
        _playSfx('GOREBone_Bone Breaks Celery 01_JSE_GMP.wav');
      } else {
        _playSfx('WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav');
      }

      final int scaledVfxDurationMs = _scaledMs(durationMs);
      final bool isTravelVfx = vfxType == 'arrow' || vfxType == 'firebolt' || vfxType == 'beam' || vfxType == 'bloodsiphon';

      final newVfx = _CombatVfx(
        id: 'vfx_${event.id}_$impactNowMs',
        startOffset: casterOffset,
        targetOffset: targetOffset,
        sourceUnitId: event.attackerId,
        targetUnitId: event.targetId,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        type: vfxType,
        durationMs: scaledVfxDurationMs,
        createdMs: impactNowMs,
      );

      // Spawn secondary target impact flashes/shockwaves for AOE / Cleave hits
      final List<_CombatVfx> secondaryVfxList = [];
      if (event.secondaryTargetHits.isNotEmpty) {
        event.secondaryTargetHits.forEach((secId, secDmg) {
          final secUnit = allUnits.where((u) => u.id == secId).firstOrNull;
          if (secUnit != null) {
            final secOffset = _getUnitCenterIsometricOffset(secUnit);
            secondaryVfxList.add(_CombatVfx(
              id: 'vfx_${event.id}_sec_${secId}_$impactNowMs',
              startOffset: targetOffset,
              targetOffset: secOffset,
              sourceUnitId: event.targetId,
              targetUnitId: secId,
              primaryColor: primaryColor.withValues(alpha: 0.9),
              secondaryColor: secondaryColor.withValues(alpha: 0.8),
              type: vfxType == 'beam' ? 'shockwave' : vfxType,
              durationMs: (scaledVfxDurationMs * 0.85).round(),
              createdMs: impactNowMs,
            ));
          }
        });
      }

      // Trigger short Tactical Synergy Callout Banners
      String? synergyText;
      Color synergyColor = const Color(0xFFFFD54F);
      final bool isBloodnova = event.skillName.contains('Bloodnova') || (event.skillName.contains('Vitae Eruption'));
      if (isBloodnova) {
        synergyText = '🩸 BLEED DETONATION!';
        synergyColor = const Color(0xFFFF1744);
      } else if (event.skillName.contains('Phalanx') || event.skillName.contains('Intercept')) {
        synergyText = '🛡️ VANGUARD INTERCEPT!';
        synergyColor = const Color(0xFF00E5FF);
      } else if (event.isCrit && event.bleedStacks > 0) {
        synergyText = '🩸 FLANKING CRIT EXPLOIT!';
        synergyColor = const Color(0xFFFF9100);
      } else if (event.skillName.contains('Shatter') || event.skillName.contains('SHATTERS')) {
        synergyText = '⚡ AEGIS SHATTER!';
        synergyColor = const Color(0xFFFFD54F);
      }

      if (synergyText != null) {
        _activeSynergyBannerText = synergyText;
        _activeSynergyBannerColor = synergyColor;
        Timer(const Duration(milliseconds: 1400), () {
          if (mounted && _activeSynergyBannerText == synergyText) {
            setState(() {
              _activeSynergyBannerText = null;
            });
          }
        });
      }

      // Option 1: Visceral Hit Feedback - Camera Hit-Shake, Impact Hit-Stop & Ground Ripple Shockwaves
      final bool isBossStrike = event.attackerId == 'gorgoroth_boss';
      final bool isSculptorStrike = event.attackerId == 'ash_sculptor' || event.skillName.contains('Cinder') || event.skillName.contains('Sundering') || event.skillName.contains('Bastion') || event.skillName.contains('Pyre') || event.skillName.contains('Cataclysmic');
      final bool isApexStrike = event.skillName.contains('Cataclysmic') || event.skillName.contains('Pyre');
      final bool isHeavyImpact = event.isCrit || isBossStrike || isUltimate || isBloodnova || isSculptorStrike || hasNamedSkill || event.skillName.contains('Smite') || event.secondaryTargetHits.length >= 2;
      final int impactDelayMs = _scaledMs((isUltimate || isSignature) ? 380 : 320);

      // Compute directional lane angle so attacker steps naturally toward the target's row/lane
      double targetLaneDeltaY = -4.0;
      if (caster != null && target != null && caster.occupiedNodes.isNotEmpty && target.occupiedNodes.isNotEmpty) {
        final int cLane = caster.occupiedNodes.first.column;
        final int tLane = target.occupiedNodes.first.column;
        targetLaneDeltaY = ((tLane - cLane) * 14.0).clamp(-22.0, 22.0) - 3.0;
      }

      // Start attacker windup + traveling spell/projectile animation effects FIRST before damage is revealed
      setState(() {
        if (isTravelVfx) {
          _activeVfx.add(newVfx);
        }
        _attackingUnitId = event.attackerId;
        _lungingUnitId = event.attackerId;
        _lungeTargetDeltaY = targetLaneDeltaY;
        _attackingSkillName = impactSkillName;
        _attackingIsSignatureSkill = isSignature || isUltimate || impactSkillName.startsWith('★') || (isBossStrike && hasNamedSkill);
      });

      // Smoothly return attacker from forward strike lunge shortly after impact so it never freezes mid-step
      final tLungeReturn = Timer(Duration(milliseconds: impactDelayMs + _scaledMs(125)), () {
        if (mounted && _activeAttackSequenceId == seqId) {
          setState(() {
            _lungingUnitId = null;
            _lungeTargetDeltaY = 0.0;
          });
        }
      });
      _animTimers.add(tLungeReturn);

      final List<String> impactCreatedVfxIds = [];

      // Trigger hit-flash, shockwaves, visual HP commit, death burst, and damage numbers at the strike impact frame
      final tImpact = Timer(Duration(milliseconds: impactDelayMs), () {
        if (!mounted) return;
        final int popNowMs = DateTime.now().millisecondsSinceEpoch;
        final liveUnits = [..._engine.playerUnits, ..._engine.enemyUnits];

        // Motion Comfort: Normal attacks and minion swings NEVER shake or zoom the camera.
        // Only monumental Apex Pyre / Forge Strike finishers trigger a controlled micro-bump.
        if (isApexStrike && _enableScreenShake) {
          _triggerScreenShake(intensity: event.isCrit ? 4.5 : 3.0);
        }

        if (isHeavyImpact) {
          _triggerHitStop(durationMs: isApexStrike ? 85 : (isUltimate ? 60 : 30));
          if (isApexStrike) {
            _triggerCameraImpactZoom(
              zoomScale: 1.05,
              durationMs: 300,
            );
          }
          _groundRipples.add(_GroundShockwaveRipple(
            id: 'ripple_${event.id}_$popNowMs',
            origin: targetOffset,
            targetUnitId: event.targetId,
            color: (isBossStrike || isBloodnova || event.bleedStacks > 0)
                ? const Color(0xFFFF1744)
                : (event.isHolyOrMagic || event.skillName.contains('Solar') || event.skillName.contains('Dawnbound') || event.skillName.contains('Brand'))
                    ? const Color(0xFFFFD54F)
                    : (event.isCrit ? const Color(0xFFFF9100) : const Color(0xFF00E5FF)),
            maxRadius: isUltimate ? 160.0 : (isBossStrike ? 140.0 : (isBloodnova ? 130.0 : 100.0)),
            createdMs: popNowMs,
            durationMs: _scaledMs(650),
          ));
        }

        // Visceral Thematic Death Bursts & Ragdoll Dissolves on Unit Defeat
        if (target != null && !target.isAlive) {
          final isBoss = target.id == 'gorgoroth_boss' || target.footprint != UnitFootprint.single1x1;
          final String deathType = isBoss
              ? 'death_boss'
              : (target.bleedStacks > 0
                  ? 'death_bleed'
                  : (event.isHolyOrMagic ? 'death_solar' : 'death_kinetic'));
          final Color deathColor = isBoss
              ? const Color(0xFFFF3D00)
              : (deathType == 'death_bleed'
                  ? const Color(0xFFFF1744)
                  : (deathType == 'death_solar' ? const Color(0xFFFFD54F) : const Color(0xFF90A4AE)));
          final deathVfxId = 'death_${target.id}_$popNowMs';
          impactCreatedVfxIds.add(deathVfxId);
          _activeVfx.add(_CombatVfx(
            id: deathVfxId,
            startOffset: targetOffset,
            targetOffset: targetOffset,
            sourceUnitId: target.id,
            targetUnitId: target.id,
            primaryColor: deathColor,
            secondaryColor: isBoss ? const Color(0xFFFFD54F) : Colors.white70,
            type: deathType,
            durationMs: _scaledMs(isBoss ? 1100 : 700),
            createdMs: popNowMs,
          ));

          if (isBoss) {
            _triggerScreenShake(intensity: 14.0);
            _triggerHitStop(durationMs: 250);
            _triggerCameraImpactZoom(zoomScale: 1.15, durationMs: 1000);
          }
        }

        // Check if this attack was a lethal finisher against the last enemy in wave/battle
        final bool isLethalFinisher = target != null && !target.isPlayer && !target.isAlive && _engine.enemyUnits.where((u) => u.isAlive).isEmpty;
        if (isLethalFinisher) {
          _isSlowMoFinisher = true;
          _triggerCameraImpactZoom(zoomScale: 1.09, durationMs: 900);
          _playSfx('sfx_victory.wav');
          final slowMoTimer = Timer(Duration(milliseconds: _scaledMs(900)), () {
            if (mounted) {
              setState(() {
                _isSlowMoFinisher = false;
              });
            }
          });
          _animTimers.add(slowMoTimer);
        }

        final bool isEnemyTargetWithLifesteal = event.isHeal &&
            event.healAmount == 0 &&
            event.damage > 0 &&
            target != null &&
            caster != null &&
            target.isPlayer != caster.isPlayer;

        setState(() {
          if (!isTravelVfx) {
            _activeVfx.add(_CombatVfx(
              id: newVfx.id,
              startOffset: newVfx.startOffset,
              targetOffset: newVfx.targetOffset,
              sourceUnitId: newVfx.sourceUnitId,
              targetUnitId: newVfx.targetUnitId,
              primaryColor: newVfx.primaryColor,
              secondaryColor: newVfx.secondaryColor,
              type: newVfx.type,
              durationMs: newVfx.durationMs,
              createdMs: popNowMs,
            ));
            impactCreatedVfxIds.add(newVfx.id);
          }
          for (final secVfx in secondaryVfxList) {
            _activeVfx.add(_CombatVfx(
              id: secVfx.id,
              startOffset: secVfx.startOffset,
              targetOffset: secVfx.targetOffset,
              sourceUnitId: secVfx.sourceUnitId,
              targetUnitId: secVfx.targetUnitId,
              primaryColor: secVfx.primaryColor,
              secondaryColor: secVfx.secondaryColor,
              type: secVfx.type,
              durationMs: secVfx.durationMs,
              createdMs: popNowMs,
            ));
            impactCreatedVfxIds.add(secVfx.id);
          }

          _damagedUnitId = event.targetId;
          _damagedUnitIds.clear();
          _damagedUnitIds.add(event.targetId);
          _recoilingUnitIds
            ..clear()
            ..add(event.targetId)
            ..addAll(event.secondaryTargetHits.keys);
          if (event.secondaryTargetHits.isNotEmpty) {
            _damagedUnitIds.addAll(event.secondaryTargetHits.keys);
          }

          // Commit deferred visual HP for primary target, secondary targets, and healed unit
          void commitUnitVisualHp(String uid) {
            final matched = liveUnits.where((u) => u.id == uid).firstOrNull;
            if (matched != null) {
              _visualUnitHp[uid] = matched.hp;
              _lastCommittedUnitHp[uid] = matched.hp;
            }
            _visualAliveOverrideIds.remove(uid);
          }

          commitUnitVisualHp(event.targetId);
          for (final secId in event.secondaryTargetHits.keys) {
            commitUnitVisualHp(secId);
          }
          final int effectiveHeal = event.healAmount > 0
              ? event.healAmount
              : (isEnemyTargetWithLifesteal ? (event.damage * 0.4).round() : 0);
          if (event.isHeal || effectiveHeal > 0) {
            commitUnitVisualHp(event.healTargetId ?? event.attackerId);
          }

          // Trigger independent 9-frame slash/shield sheet on impacted targets
          // Exclude offensive Shield Bash / Shield Slam strikes so stunned enemies show a hit slash, not a defensive shield!
          if (!event.isHeal || isEnemyTargetWithLifesteal) {
            final bool isDefensiveShieldSkill = !impactSkillName.contains('Bash') &&
                !impactSkillName.contains('Slam') &&
                (impactSkillName.contains('Aegis') ||
                    impactSkillName.contains('Phalanx') ||
                    impactSkillName.contains('Bulwark') ||
                    impactSkillName.contains('Bastion') ||
                    impactSkillName.contains('Block'));
            final String slashSheet = isDefensiveShieldSkill
                ? 'assets/animations/vfx/fire_shield_sheet.png'
                : 'assets/animations/vfx/crimson_slash_sheet.png';
            final Set<String> slashIds = {event.targetId, ...event.secondaryTargetHits.keys};
            for (final sid in slashIds) {
              _activeImpactSlashUnits[sid] = slashSheet;
            }
            final tSlashClear = Timer(Duration(milliseconds: _scaledMs(520)), () {
              if (mounted) {
                setState(() {
                  for (final sid in slashIds) {
                    if (_activeImpactSlashUnits[sid] == slashSheet) {
                      _activeImpactSlashUnits.remove(sid);
                    }
                  }
                });
              }
            });
            _animTimers.add(tSlashClear);
          }

          // Construct distinct styled floating pop
          String popText;
          Color popColor;
          Color popBorder;
          double popSize = 11.5;
          bool isCrit = event.isCrit || (target?.isStaggered == true);

          if (event.isHeal && !isEnemyTargetWithLifesteal) {
            if (event.skillName == 'Phalanx Intercept' || event.skillName == 'Unbreakable Phalanx') {
              popText = '+60 🛡️ AEGIS';
              popColor = const Color(0xFF80D8FF);
              popBorder = const Color(0xFF00E5FF);
            } else if (event.skillName == 'Stoke the Embers') {
              popText = '+15 🔥 CINDERS';
              popColor = const Color(0xFFFFD54F);
              popBorder = const Color(0xFFFFC107);
            } else {
              final int shownHeal = event.healAmount > 0 ? event.healAmount : event.damage;
              popText = '+${shownHeal > 0 ? shownHeal : "HEAL"} 💚';
              popColor = const Color(0xFF69F0AE);
              popBorder = const Color(0xFF00E676);
            }
          } else {
            if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova')) {
              popText = '🩸 -${event.damage} BLOODNOVA!';
              popColor = const Color(0xFFFF1744);
              popBorder = const Color(0xFF880E4F);
              popSize = 13.5;
            } else if (event.skillName.contains('Sanguine Siphon') || event.skillName.contains('Siphon Rend')) {
              popText = '🩸 -${event.damage}';
              popColor = const Color(0xFFFF5252);
              popBorder = const Color(0xFFB71C1C);
              popSize = 12.5;
            } else if (isCrit) {
              popText = (target?.isStaggered == true) ? '⚡ -${event.damage} CORE CRIT!' : '💥 -${event.damage} CRIT!';
              popColor = const Color(0xFFFFD54F);
              popBorder = const Color(0xFFFF9100);
              popSize = 15.5;
            } else if (event.bleedStacks > 0) {
              popText = '🩸 -${event.damage} BLEED';
              popColor = const Color(0xFFFF3D00);
              popBorder = const Color(0xFFDD2C00);
              popSize = 12.0;
            } else {
              popText = '-${event.damage}';
              popColor = const Color(0xFFFF8A80);
              popBorder = const Color(0xFFD50000);
            }
          }

          _unitFloatingPops[event.targetId] = popText;

          // Allow natural stacking by not wiping existing active pops immediately
          final int existingCount = _floatingPops.where((p) => p.unitId == event.targetId && !p.isExpired).length;
          final double drift = (existingCount % 2 == 1 ? -1.0 : 1.0) * (existingCount * 8.0);

          _floatingPops.add(_FloatingCombatText(
            id: 'pop_${event.id}_$popNowMs',
            unitId: event.targetId,
            text: popText,
            color: popColor,
            borderColor: popBorder,
            fontSize: popSize,
            isCrit: isCrit,
            createdMs: popNowMs,
            durationMs: isCrit ? 2200 : 1750,
            horizontalDrift: drift,
          ));

          // Spawn a separate green heal pop & rising pulse over the actual healed unit!
          if (effectiveHeal > 0) {
            final String healedUnitId = event.healTargetId ?? event.attackerId;
            final healedUnit = liveUnits.where((u) => u.id == healedUnitId).firstOrNull;
            if (healedUnit != null) {
              final healVfxId = 'heal_${event.id}_$popNowMs';
              impactCreatedVfxIds.add(healVfxId);
              _activeVfx.add(_CombatVfx(
                id: healVfxId,
                startOffset: _getUnitCenterIsometricOffset(healedUnit),
                targetOffset: _getUnitCenterIsometricOffset(healedUnit),
                sourceUnitId: healedUnitId,
                targetUnitId: healedUnitId,
                primaryColor: const Color(0xFF69F0AE),
                secondaryColor: const Color(0xFFFFD54F),
                type: 'heal_pulse',
                durationMs: _scaledMs(650),
                createdMs: popNowMs,
              ));
            }
            _floatingPops.add(_FloatingCombatText(
              id: 'pop_heal_${event.id}_$popNowMs',
              unitId: healedUnitId,
              text: '+$effectiveHeal 💚',
              color: const Color(0xFF69F0AE),
              borderColor: const Color(0xFF00E676),
              fontSize: 12.0,
              isCrit: false,
              createdMs: popNowMs,
              durationMs: 1750,
              horizontalDrift: -10.0,
            ));
          }

          // If attacker procced a Crucible Grafted Trait, display a glowing purple/gold floating proc callout on the attacker!
          if (event.graftedTraitProc != null && event.attackerId != event.targetId) {
            final graftText = '🧬 ${event.graftedTraitProc ?? ''}';
            _unitFloatingPops[event.attackerId] = graftText;
            _floatingPops.add(_FloatingCombatText(
              id: 'pop_graft_${event.id}_$popNowMs',
              unitId: event.attackerId,
              text: graftText,
              color: const Color(0xFFEA80FC),
              borderColor: const Color(0xFFD500F9),
              fontSize: 10.5,
              isCrit: false,
              createdMs: popNowMs,
              durationMs: 1900,
              horizontalDrift: 12.0,
            ));
          }

          // Push floating popups for all secondary targets hit by multi-target / AOE spells
          if (event.secondaryTargetHits.isNotEmpty) {
            event.secondaryTargetHits.forEach((secId, secDmg) {
              final isSecBlood = event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova');
              final secText = secDmg > 0
                  ? (isSecBlood ? '🩸 -$secDmg' : '-$secDmg')
                  : (isSecBlood ? '🩸 - SPLASH' : '- CLEAVE');
              _unitFloatingPops[secId] = secText;
              final int existingSecCount = _floatingPops.where((p) => p.unitId == secId && !p.isExpired).length;
              final double secDrift = (existingSecCount % 2 == 1 ? -1.0 : 1.0) * (10.0 + existingSecCount * 9.0);
              _floatingPops.add(_FloatingCombatText(
                id: 'pop_${event.id}_${secId}_$popNowMs',
                unitId: secId,
                text: secText,
                color: isSecBlood ? const Color(0xFFFF5252) : const Color(0xFFFF8A80),
                borderColor: isSecBlood ? const Color(0xFF880E4F) : const Color(0xFFD50000),
                fontSize: 11.5,
                isCrit: false,
                createdMs: popNowMs,
                durationMs: 1800,
                horizontalDrift: secDrift,
              ));
            });
          }
        });

        // Reveal Victory / Defeat banner only after the lethal strike & death burst register
        if (_holdEndOfBattleOverlay && (_engine.isVictory || _engine.isDefeat)) {
          final tEndReveal = Timer(Duration(milliseconds: _scaledMs(isLethalFinisher ? 800 : 500)), () {
            if (mounted) {
              setState(() {
                _holdEndOfBattleOverlay = false;
              });
            }
          });
          _animTimers.add(tEndReveal);
        }

        // Fast visceral hit-flash reset (110ms normal, 150ms crit) so character art stays crisp,
        // while knockback recoil eases back smoothly over 240ms!
        final tFlash = Timer(Duration(milliseconds: _scaledMs(event.isCrit ? 150 : 110)), () {
          if (mounted && _activeAttackSequenceId == seqId) {
            setState(() {
              _damagedUnitId = null;
              _damagedUnitIds.clear();
            });
          }
        });
        _animTimers.add(tFlash);

        final tRecoil = Timer(Duration(milliseconds: _scaledMs(240)), () {
          if (mounted && _activeAttackSequenceId == seqId) {
            setState(() {
              _recoilingUnitIds.clear();
            });
          }
        });
        _animTimers.add(tRecoil);
      });
      _animTimers.add(tImpact);

      // Clean up VFX after its duration
      final tVfx = Timer(Duration(milliseconds: impactDelayMs + scaledVfxDurationMs + 100), () {
        if (mounted) {
          setState(() {
            _activeVfx.removeWhere((v) =>
                v.id == newVfx.id ||
                secondaryVfxList.any((s) => s.id == v.id) ||
                impactCreatedVfxIds.contains(v.id));
            _floatingPops.removeWhere((p) => p.isExpired);
            _groundRipples.removeWhere((r) => r.isExpired);
          });
        }
      });
      _animTimers.add(tVfx);

      // Reset attack sprite-sheet state & unit banner pop after playback
      final t1 = Timer(Duration(milliseconds: _scaledMs(920)), () {
        if (mounted && _activeAttackSequenceId == seqId) {
          setState(() {
            _attackingUnitId = null;
            _attackingSkillName = null;
            _attackingIsSignatureSkill = false;
            _unitFloatingPops.remove(event.targetId);
            if (event.secondaryTargetHits.isNotEmpty) {
              for (final sId in event.secondaryTargetHits.keys) {
                _unitFloatingPops.remove(sId);
              }
            }
          });
        }
      });
      _animTimers.add(t1);

      // Conclude action sequence smoothly and advance to next event without dead air
      final int animRestMs = _scaledMs(
        (isUltimate || isSignature) ? 760 : (event.isAssistStrike || event.isKnockback ? 580 : 630),
      );
      final t2 = Timer(Duration(milliseconds: animRestMs), () {
        if (mounted) {
          _isActionSequenceRunning = false;
          if (_actionEventQueue.isNotEmpty) {
            final tNext = Timer(Duration(milliseconds: _scaledMs(24)), () {
              if (mounted) _drainNextCombatEvent();
            });
            _animTimers.add(tNext);
          } else {
            _engine.clearActiveAction();
          }
        }
      });
      _animTimers.add(t2);
    }

    // STAGE 1: Display Banner first if skill is an Ultimate, Signature, or Named Spell
    if (bannerDurationMs > 0) {
      setState(() {
        if (isUltimate && caster != null && caster.isPlayer) {
          _activeUltimateUnit = caster;
          _playSfx('sfx_spell.wav');
        } else if (isSignature && caster != null) {
          _activeSignatureUnit = caster;
          _activeSkillName = event.skillName;
          _playSfx('sfx_spell.wav');
        } else {
          _activeSkillName = event.skillName;
          _activeSkillCasterName = event.attackerName;
          _activeSkillCaster = caster;
          _isPlayerSkillBanner = event.isPlayerAttacker;
          _playSfx('sfx_spell.wav');
        }
        // Channeling invocation rune under caster's plinth during announcement
        _activeVfx.add(_CombatVfx(
          id: 'vfx_${event.id}_rune_$nowMs',
          startOffset: casterOffset,
          targetOffset: casterOffset,
          sourceUnitId: event.attackerId,
          targetUnitId: event.attackerId,
          primaryColor: const Color(0xFFFFD54F),
          secondaryColor: const Color(0xFF00E5FF),
          type: 'rune_invocation',
          durationMs: bannerDurationMs,
          createdMs: nowMs,
        ));
      });

      // Once banner has been displayed, dismiss it and trigger the full-screen unobstructed attack animation!
      final bannerTimer = Timer(Duration(milliseconds: bannerDurationMs), () {
        executePhysicalImpact();
      });
      _animTimers.add(bannerTimer);
    } else {
      executePhysicalImpact();
    }
  }

  void _startLoop() {
    _frameTicker?.dispose();
    _lastFrameElapsed = Duration.zero;
    _frameTicker = createTicker(_onFrameTick)..start();
  }

  void _onFrameTick(Duration elapsed) {
    if (!mounted) return;
    try {
      final double rawDt = _lastFrameElapsed == Duration.zero
          ? (1.0 / 60.0)
          : (elapsed - _lastFrameElapsed).inMicroseconds / 1000000.0;
      _lastFrameElapsed = elapsed;
      final double dt = rawDt.clamp(0.0, 0.05);

      bool needsVisualRepaint = false;

      final hasVisibleTrajectory = _selectedUnitId != null ||
          _draggedUnitId != null ||
          _selectedEnemyUnitId != null ||
          _showAllTrajectories ||
          _engine.enemyUnits.any((e) => e.isAlive && e.pendingIntent != null);
      if (hasVisibleTrajectory) {
        _dashPhase = (_dashPhase + dt * 0.85) % 1.0;
        needsVisualRepaint = true;
      }

      // Smooth continuous damped screen shake
      if (_shakeRemainingSec > 0.0) {
        _shakeRemainingSec = max(0.0, _shakeRemainingSec - dt);
        if (_shakeRemainingSec == 0.0) {
          _screenShakeOffset = Offset.zero;
          _shakeIntensity = 0.0;
        } else {
          _shakePhase += dt * 75.0;
          final double decay = (_shakeRemainingSec / _shakeDurationSec).clamp(0.0, 1.0);
          final double amp = _shakeIntensity * decay * decay;
          _screenShakeOffset = Offset(sin(_shakePhase) * amp, cos(_shakePhase * 1.3) * amp * 0.65);
        }
        needsVisualRepaint = true;
      }

      // Smooth continuous camera impact zoom curve
      if (_cameraZoomRemainingSec > 0.0) {
        _cameraZoomRemainingSec = max(0.0, _cameraZoomRemainingSec - dt);
        if (_cameraZoomRemainingSec == 0.0) {
          _battlefieldCameraZoom = 1.0;
        } else {
          final double t = 1.0 - (_cameraZoomRemainingSec / _cameraZoomDurationSec).clamp(0.0, 1.0);
          // Quick punch in (first 20%), smooth ease-out return
          final double envelope = t < 0.2 ? (t / 0.2) : (1.0 - ((t - 0.2) / 0.8));
          _battlefieldCameraZoom = 1.0 + (_cameraZoomPeak - 1.0) * Curves.easeOut.transform(envelope.clamp(0.0, 1.0));
        }
        needsVisualRepaint = true;
      }

      // Keep active floating pops, ripples, and VFX animating smoothly at 60fps
      if (_floatingPops.isNotEmpty) {
        _floatingPops.removeWhere((p) => p.isExpired);
        needsVisualRepaint = true;
      }
      if (_groundRipples.isNotEmpty) {
        _groundRipples.removeWhere((r) => r.isExpired);
        needsVisualRepaint = true;
      }
      if (_activeVfx.isNotEmpty) {
        needsVisualRepaint = true;
      }

      bool engineNotifiedThisFrame = false;
      if (_engine.isRunning) {
        if (_hitStopRemainingMs > 0) {
          _hitStopRemainingMs = max(0, _hitStopRemainingMs - (dt * 1000.0).round());
          _tickAccumulator = 0.0;
        } else if (_engine.isActionPauseEnabled && _engine.activeActionEvent != null) {
          _engine.skillTreeState.updateCooldowns(dt * _engine.combatPacingSpeed);
          _tickAccumulator = 0.0;
        } else {
          _tickAccumulator += dt * SpatialCombatEngine.ticksPerSecond * _engine.simulationSpeed;
          while (_tickAccumulator >= 1.0) {
            _tickAccumulator -= 1.0;
            _engine.stepTick();
            engineNotifiedThisFrame = true;
            if (_engine.isActionPauseEnabled && _engine.activeActionEvent != null) {
              _tickAccumulator = 0.0;
              break;
            }
          }
        }
      }

      if (needsVisualRepaint && !engineNotifiedThisFrame) {
        _visualFrameTick.value++;
      }
    } catch (e, st) {
      debugPrint('Combat frame tick error: $e\n$st');
    }
  }

  @override
  void dispose() {
    _forgeStrikeTimer?.cancel();
    _battlefieldFocusNode.dispose();
    _frameTicker?.dispose();
    _visualFrameTick.dispose();
    for (final t in _animTimers) {
      t.cancel();
    }
    _animTimers.clear();
    _engine.removeListener(_onEngineUpdate);
    final bgm = _bgmPlayer;
    final sfxList = List<AudioPlayer>.from(_sfxPlayers);
    _bgmPlayer = null;
    _sfxPlayers.clear();
    try {
      bgm?.stop().then((_) => bgm.dispose()).catchError((_) {});
      for (final sfx in sfxList) {
        sfx.stop().then((_) => sfx.dispose()).catchError((_) {});
      }
    } catch (_) {}
    super.dispose();
  }

  void _restartCombatEncounter() {
    for (final t in _animTimers) {
      t.cancel();
    }
    _animTimers.clear();
    _actionEventQueue.clear();
    _activeVfx.clear();
    _floatingPops.clear();
    _unitFloatingPops.clear();
    _damagedUnitIds.clear();
    _isActionSequenceRunning = false;
    _shakeRemainingSec = 0.0;
    _shakeIntensity = 0.0;
    _screenShakeOffset = Offset.zero;
    _cameraZoomRemainingSec = 0.0;
    _battlefieldCameraZoom = 1.0;
    _attackingUnitId = null;
    _attackingSkillName = null;
    _damagedUnitId = null;
    _activeSkillName = null;
    _activeAttackSequenceId++;
    _activeImpactSlashUnits.clear();
    _visualUnitHp.clear();
    _lastCommittedUnitHp.clear();
    _visualAliveOverrideIds.clear();
    _holdEndOfBattleOverlay = false;
    _lastKnown2DUnitOffsets.clear();
    _recoilingUnitIds.clear();
    _lungingUnitId = null;
    _lungeTargetDeltaY = 0.0;
    _hasBossEnraged = false;
    _wasBossStaggered = false;

    final players = widget.initialPlayerUnits?.whereType<UnitEntity>().toList();
    final enemies = widget.initialEnemyUnits?.whereType<UnitEntity>().toList();

    _engine.removeListener(_onEngineUpdate);
    _engine = SpatialCombatEngine(
      initialPlayerEntities: players,
      initialEnemyEntities: enemies,
      enemyWaves: widget.enemyWaves,
      title: widget.encounterTitle,
      isBossEncounter: widget.isBossEncounter,
      relicService: widget.relicService,
      commandService: widget.commandService,
      plinthService: widget.plinthService,
      skillTreeState: widget.skillTreeState,
      maxDeployableUnits: widget.maxDeployableUnits,
      spindleTier: widget.spindleTier,
    );
    _engine.isActionPauseEnabled = true;
    for (final u in [..._engine.playerUnits, ..._engine.enemyUnits]) {
      _visualUnitHp[u.id] = u.hp;
      _lastCommittedUnitHp[u.id] = u.hp;
    }
    _precacheActiveUnitSheets();
    _engine.addListener(_onEngineUpdate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gorgoroth = _engine.enemyUnits
        .where((u) =>
            u.id == 'gorgoroth_boss' ||
            u.archetype == UnitArchetype.colossusBehemoth ||
            u.footprint != UnitFootprint.single1x1)
        .firstOrNull;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isLandscapeMobile = screenHeight < 550;

    return Focus(
      focusNode: _battlefieldFocusNode,
      autofocus: true,
      onKeyEvent: _handleBattleKeyEvent,
      child: Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: isLandscapeMobile
          ? null
          : GothicHeaderBar(
              title: widget.encounterTitle ?? _engine.encounterTitle,
              categoryTag: 'Battle',
              leading: widget.onBackToStandardCombat != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD54F), size: 20),
                      onPressed: widget.onBackToStandardCombat,
                      tooltip: 'Return to Standard Arena',
                    )
                  : null,
        actions: [
          // Simulation Speed Multiplier Toggle (1.0x -> 1.5x -> 2.0x)
          GestureDetector(
            onTap: () {
              setState(() {
                _engine.cycleCombatSpeed();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: _engine.combatPacingSpeed > 1.0
                    ? const Color(0xFFFF9100).withValues(alpha: 0.25)
                    : const Color(0xFF1E1E28),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _engine.combatPacingSpeed > 1.0
                      ? const Color(0xFFFF9100)
                      : const Color(0xFF38384E),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _engine.combatPacingSpeed > 1.0 ? Icons.fast_forward : Icons.speed,
                    color: _engine.combatPacingSpeed > 1.0
                        ? const Color(0xFFFFB74D)
                        : Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${_engine.combatPacingSpeed.toStringAsFixed(1)}×',
                    style: TextStyle(
                      color: _engine.combatPacingSpeed > 1.0
                          ? const Color(0xFFFFD54F)
                          : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Ambient Audio Mute Toggle
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: _isMuted ? Colors.white38 : const Color(0xFFFFD54F),
              size: 20,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            tooltip: _isMuted ? 'Unmute' : 'Mute',
            onPressed: _toggleMute,
          ),
          const SizedBox(width: 2),
          // Motion Comfort: Screen Shake Toggle
          IconButton(
            icon: Icon(
              _enableScreenShake ? Icons.vibration : Icons.motion_photos_off,
              color: _enableScreenShake ? const Color(0xFFFFD54F) : Colors.white38,
              size: 19,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            tooltip: _enableScreenShake
                ? 'Screen Shake: ON (Tap for Motion Comfort)'
                : 'Screen Shake: OFF (Camera Locked)',
            onPressed: () {
              setState(() {
                _enableScreenShake = !_enableScreenShake;
              });
            },
          ),
          const SizedBox(width: 4),
          // Play / Pause Simulation
          IconButton(
            icon: Icon(
              _engine.isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _engine.isRunning ? const Color(0xFFFFD54F) : const Color(0xFF81C784),
              size: 22,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            tooltip: _engine.isRunning ? 'Pause' : 'Play',
            onPressed: () {
              setState(() {
                if (_engine.isPreBattlePhase) {
                  _engine.startBattle();
                } else {
                  _engine.isRunning = !_engine.isRunning;
                }
              });
            },
          ),
          const SizedBox(width: 4),
          // Zen / HUD Collapse Toggle
          IconButton(
            icon: Icon(
              _isZenMode ? Icons.visibility_off : Icons.visibility,
              color: _isZenMode ? const Color(0xFFFF9100) : Colors.white70,
              size: 20,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            tooltip: _isZenMode ? 'Show Tactical HUD' : 'Zen View (Max Battlefield)',
            onPressed: () {
              setState(() {
                _isZenMode = !_isZenMode;
              });
            },
          ),
          const SizedBox(width: 4),
          // Browser / Device Fullscreen Toggle
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Color(0xFF00E5FF), size: 22),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            tooltip: 'Toggle Fullscreen Mode',
            onPressed: () {
              PlatformFullscreen.toggleFullscreen();
            },
          ),
          // Subtle Dev / Debug Menu (Restart always available; Step/T135/Trial Switchers behind kDebugMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            tooltip: 'Combat Diagnostics',
            color: const Color(0xFF161622),
            onSelected: (val) {
              if (val == 'step' && kDebugMode) {
                if (_engine.isPreBattlePhase) _engine.isPreBattlePhase = false;
                _engine.stepTick();
              } else if (val == 't135' && kDebugMode) {
                if (_engine.isPreBattlePhase) _engine.isPreBattlePhase = false;
                final bool prevActionPause = _engine.isActionPauseEnabled;
                _engine.isActionPauseEnabled = false;
                _engine.clearActiveAction();
                int guard = 0;
                while (_engine.currentTick < 135 && guard < 300 && !_engine.isVictory && !_engine.isDefeat) {
                  _engine.stepTick();
                  guard++;
                }
                _engine.isActionPauseEnabled = prevActionPause;
              } else if (val == 'restart') {
                _restartCombatEncounter();
              } else if (val == 'boss_gorgoroth' && kDebugMode) {
                _playSfx('sfx_slash.wav');
                setState(() {
                  _engine.switchBossTrial('gorgoroth');
                });
              } else if (val == 'boss_malakor' && kDebugMode) {
                _playSfx('sfx_block.wav');
                setState(() {
                  _engine.switchBossTrial('malakor');
                });
              } else if (val == 'boss_morvath' && kDebugMode) {
                _playSfx('sfx_spell.wav');
                setState(() {
                  _engine.switchBossTrial('morvath');
                });
              }
            },
            itemBuilder: (context) => [
              if (kDebugMode) ...[
                const PopupMenuItem(
                  value: 'step',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Icons.skip_next, size: 16, color: Colors.white70),
                      SizedBox(width: 8),
                      Text('Step 1 Tick', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 't135',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Icons.fast_forward, size: 16, color: Color(0xFFFFD54F)),
                      SizedBox(width: 8),
                      Text('Fast-Forward T135', style: TextStyle(fontSize: 12, color: Color(0xFFFFD54F))),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'restart',
                height: 32,
                child: Row(
                  children: [
                    Icon(Icons.replay, size: 16, color: Color(0xFFFF5252)),
                    SizedBox(width: 8),
                    Text('Restart Battle', style: TextStyle(fontSize: 12, color: Color(0xFFFF8A80))),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'boss_gorgoroth',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Icons.shield, size: 16, color: Color(0xFF00E5FF)),
                      SizedBox(width: 8),
                      Text('Trial: Gorgoroth the Flayed', style: TextStyle(fontSize: 12, color: Color(0xFF80D8FF))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'boss_malakor',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Icons.electric_bolt, size: 16, color: Color(0xFFFFD54F)),
                      SizedBox(width: 8),
                      Text('Trial: Malakor the Unbroken', style: TextStyle(fontSize: 12, color: Color(0xFFFFE082))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'boss_morvath',
                  height: 32,
                  child: Row(
                    children: [
                      Icon(Icons.coronavirus, size: 16, color: Color(0xFF69F0AE)),
                      SizedBox(width: 8),
                      Text('Trial: Morvath the Defiler', style: TextStyle(fontSize: 12, color: Color(0xFFA7FFEB))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: !isLandscapeMobile,
        bottom: !isLandscapeMobile,
        child: Column(
          children: [
            // Top HUD: Status Banner, Focus Bar & Boss Telemetry (hidden in Zen mode)
            if (!_isZenMode)
              RepaintBoundary(
                child: _buildTopStatusRibbon(gorgoroth, isLandscapeMobile: isLandscapeMobile),
              ),

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: ValueListenableBuilder<int>(
                valueListenable: _visualFrameTick,
                builder: (context, _, child) => Transform.scale(
                  scale: _battlefieldCameraZoom,
                  child: Transform.translate(
                    offset: _screenShakeOffset,
                    child: child,
                  ),
                ),
                child: RepaintBoundary(
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                  // Atmospheric Multi-Layer Parallax Battlefield Arena Backdrop
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1: Distant Sky & Atmosphere
                        Image.asset(
                          'assets/images/backgrounds/sky parallax.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            widget.backdropAsset ?? 'assets/images/backgrounds/battlefield_ashen_plains.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Layer 2: Distant Ruined Gothic Citadel & Ash Peaks
                        Image.asset(
                          'assets/images/backgrounds/mountain parallax.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                        // Layer 3: Foreground Battlefield Field (Cleanly seated in backdrop)
                        Image.asset(
                          'assets/images/backgrounds/foreground parallax.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    ),
                  ),

                  // Dynamic Cinematic Vignette, Threat Pulse & Atmospheric Embers Layer
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Builder(
                        builder: (context) {
                          final bool isCriticalThreat = _engine.isAshenReckoning;
                          final sculptor = _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;
                          final bool isCommanderLowHp = sculptor != null && sculptor.maxHp > 0 && (sculptor.hp / sculptor.maxHp) < 0.25;

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Base Radial Shadow Vignette
                              Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 1.15,
                                    colors: [
                                      Colors.transparent,
                                      const Color(0xFF06070B).withValues(alpha: 0.35),
                                      const Color(0xFF030406).withValues(alpha: 0.78),
                                    ],
                                  ),
                                ),
                              ),
                              // 2. Scorched Earth Bottom Molten Warmth Reflection
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 180,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        (isCriticalThreat
                                            ? const Color(0xFF4A0E17)
                                            : const Color(0xFF2E150B)).withValues(alpha: 0.40),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 3. Dynamic Threat Heartbeat Glow on Critical HP / Ashen Reckoning
                              if (isCriticalThreat || isCommanderLowHp)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFFF1744).withValues(
                                        alpha: 0.25 + 0.15 * sin(DateTime.now().millisecondsSinceEpoch / 280.0).abs(),
                                      ),
                                      width: 4.0,
                                    ),
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.95,
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFFFF1744).withValues(alpha: 0.12),
                                      ],
                                    ),
                                  ),
                                ),
                              // 4. Drifting Battlefield Ash Flecks & Glowing Embers
                              CustomPaint(
                                painter: _AtmosphericBattlefieldEmbersPainter(
                                  timestampMs: DateTime.now().millisecondsSinceEpoch,
                                  isEnraged: isCriticalThreat,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Battlefield Arena Plane: Supports clean 2D Landscape Lanes or 2.5D Isometric Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double availW = constraints.maxWidth;
                      final double availH = constraints.maxHeight;

                      // Dynamically calculate optimal tile dimensions for 3 Ranks x 3 Lanes
                      // Total board has 6 ranks + clash buffer (~6.5 tile widths) and 3 lanes (3 tile heights).
                      // Option 1: Expanded battlefield scale filling the arena grandly
                      final double target2DWidth = (availW / 6.4).clamp(84.0, 190.0);
                      final double target2DHeight = (availH / 3.3).clamp(68.0, 135.0);

                      final bool isDesktop = availW >= 700;
                      final double tileWidth = isDesktop ? 170.0 : 118.0;
                      final double tileHeight = isDesktop ? 85.0 : 59.0;

                      final double tile2DWidth = target2DWidth;
                      final double tile2DHeight = target2DHeight;

                      return Align(
                        alignment: isDesktop ? Alignment.bottomCenter : Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20.0 : 6.0,
                              vertical: 0.0,
                            ),
                            child: _is2DGridView
                                ? RankAndRite2DBattlefield(
                                    engine: _engine,
                                    selectedUnitId: _selectedUnitId,
                                    selectedEnemyUnitId: _selectedEnemyUnitId,
                                    secondaryTargetEnemyIds: _computeProjectedSecondaryTargetEnemyIds(),
                                    draggedUnitId: _draggedUnitId,
                                    selectedCardId: null,
                                    draggedUltimateUnitId: _draggedUltimateUnitId,
                                    selectedUltimateUnitId: _selectedUltimateUnitId,
                                    hoveredTileCol: _hoveredTileCol,
                                    hoveredTileRow: _hovered2DRow,
                                    isHoveredPlayerSide: _isHovered2DPlayerSide,
                                    tileWidth: tile2DWidth,
                                    tileHeight: tile2DHeight,
                                    onSelectPlayerUnit: (id) {
                                      setState(() {
                                        _selectedUnitId = (_selectedUnitId == id) ? null : id;
                                      });
                                    },
                                    onSelectEnemyUnit: (id) {
                                      setState(() {
                                        _selectedEnemyUnitId = (_selectedEnemyUnitId == id) ? null : id;
                                        _engine.focusedEnemyUnitId = _selectedEnemyUnitId;
                                        _selectedUnitId = null;
                                      });
                                    },
                                    onDragStartUnit: (id) {
                                      setState(() {
                                        _draggedUnitId = id;
                                      });
                                    },
                                    onDragEndUnit: () {
                                      setState(() {
                                        _draggedUnitId = null;
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onMovePlayerUnit: (id, col, row) {
                                      _engine.movePlayerUnit(id, col, row);
                                      setState(() {
                                        _selectedUnitId = null;
                                        _draggedUnitId = null;
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onCastCard: (cardId, {targetUnit, targetCol, targetRow}) {
                                      _engine.castCard(cardId, targetUnit: targetUnit, targetCol: targetCol, targetRow: targetRow);
                                      setState(() {
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onCastUltimate: (ultId, {targetUnit, targetCol, targetRow}) {
                                      _engine.castUltimate(ultId, targetUnit: targetUnit, targetCol: targetCol, targetRow: targetRow);
                                      setState(() {
                                        _draggedUltimateUnitId = null;
                                        _selectedUltimateUnitId = null;
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onTileHover: (col, row, isPlayer) {
                                      setState(() {
                                        _hoveredTileCol = col;
                                        _hovered2DRow = row;
                                        _isHovered2DPlayerSide = isPlayer;
                                      });
                                    },
                                    onClearHover: () {
                                      setState(() {
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onLongPressUnit: (unit) {
                                      _openUnitInspectorDialog(unit);
                                    },
                                    buildUnitMiniature: (unit, {required double tileWidth, required double tileHeight, required double colGap, bool isSelected = false}) {
                                      return _buildUnitMiniatureWidget(
                                        unit,
                                        tileWidth: tileWidth,
                                        tileHeight: tileHeight,
                                        colGap: colGap,
                                        isSelected: isSelected,
                                      );
                                    },
                                    visualAliveOverrideIds: _visualAliveOverrideIds,
                                    buildVfxOverlay: (resolveUnitCenter2D) {
                                      for (final u in [..._engine.playerUnits, ..._engine.enemyUnits]) {
                                        _lastKnown2DUnitOffsets[u.id] = resolveUnitCenter2D(u);
                                      }
                                      return RepaintBoundary(
                                        child: ValueListenableBuilder<int>(
                                          valueListenable: _visualFrameTick,
                                          builder: (context, _, __) {
                                            if (_activeVfx.isEmpty && _groundRipples.isEmpty && _activeFireBarrageMs == null) {
                                              return const SizedBox.shrink();
                                            }
                                            final int nowMs = DateTime.now().millisecondsSinceEpoch;
                                            final allUnits = [..._engine.playerUnits, ..._engine.enemyUnits];
                                            Offset? resolveById(String? unitId) {
                                              if (unitId == null) return null;
                                              final u = allUnits.where((x) => x.id == unitId).firstOrNull;
                                              if (u != null) {
                                                final pt = resolveUnitCenter2D(u);
                                                _lastKnown2DUnitOffsets[u.id] = pt;
                                                return pt;
                                              }
                                              return _lastKnown2DUnitOffsets[unitId];
                                            }
                                            final List<_CombatVfx> vfx2D = [];
                                            for (final vfx in _activeVfx) {
                                              final startPt = resolveById(vfx.sourceUnitId);
                                              final targetPt = resolveById(vfx.targetUnitId);
                                              if (startPt == null && targetPt == null) continue;
                                              final Offset effectiveStart = startPt ?? Offset(targetPt!.dx, targetPt.dy + 40);
                                              final Offset effectiveTarget = targetPt ?? effectiveStart;
                                              vfx2D.add(vfx.copyWithOffsets(effectiveStart, effectiveTarget));
                                            }
                                            final List<_GroundShockwaveRipple> ripples2D = [];
                                            for (final r in _groundRipples) {
                                              final originPt = resolveById(r.targetUnitId);
                                              if (originPt == null) continue;
                                              ripples2D.add(r.copyWithOrigin(originPt));
                                            }
                                            final List<Offset> barrageOffsets2D = [];
                                            if (_activeFireBarrageMs != null) {
                                              for (final tid in _fireBarrageTargetIds) {
                                                final pt = resolveById(tid);
                                                if (pt != null) barrageOffsets2D.add(pt);
                                              }
                                            }
                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                if (ripples2D.isNotEmpty)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: _GroundShockwaveRipplePainter(
                                                        ripples: ripples2D,
                                                        currentTimestampMs: nowMs,
                                                      ),
                                                    ),
                                                  ),
                                                if (vfx2D.isNotEmpty)
                                                  Positioned.fill(
                                                    child: CustomPaint(
                                                      painter: _CombatVfxOverlayPainter(
                                                        effects: vfx2D,
                                                        currentTimestampMs: nowMs,
                                                      ),
                                                    ),
                                                  ),
                                                if (_activeFireBarrageMs != null && barrageOffsets2D.isNotEmpty)
                                                  Positioned.fill(
                                                    child: _StaggeredMeteorBarrage(
                                                      key: ValueKey('fire_barrage_2d_$_activeFireBarrageMs'),
                                                      targetOffsets: barrageOffsets2D,
                                                      assetPath: _fireBarrageAssetPath,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  )
                                : _buildUnifiedIsometricBattlefield(
                                    tileWidth: tileWidth,
                                    tileHeight: tileHeight,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),

                  // AoE Fire Barrage fallback for 2.5D Isometric mode (2D mode renders directly inside buildVfxOverlay at exact unit centers!)
                  if (_activeFireBarrageMs != null && !_is2DGridView)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _StaggeredMeteorBarrage(
                          key: ValueKey('fire_barrage_$_activeFireBarrageMs'),
                          targetAlignments: _fireBarrageTargetAlignments,
                          assetPath: _fireBarrageAssetPath,
                        ),
                      ),
                    ),

// Layer 3 moved to backdrop so it never obscures bottom row tiles

                  // Floating Tactical Prompt & Unit Combat Triad Overlays (Non-shifting Stack overlays!)
                  // Hidden on landscape mobile so it doesn't block the battlefield view!
                  if (!_isZenMode && !isLandscapeMobile &&
                      (_engine.lastBannerMessage != null ||
                          _draggedUnitId != null ||
                          _selectedUnitId != null ||
                          _selectedEnemyUnitId != null ||
                          _engine.isPreBattlePhase))
                    Positioned(
                      top: 6,
                      left: 12,
                      right: 12,
                      child: IgnorePointer(
                        ignoring: _selectedUnitId == null && _selectedEnemyUnitId == null,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: _buildTacticalPromptBanner(),
                          ),
                        ),
                      ),
                    ),

// Floating top triad strip removed to keep arena clean & cinematic

                  // Floating Live Skill Invocation Banner (does not push or resize the battlefield)
                  if (_activeSkillName != null && _activeSignatureUnit == null)
                    Positioned(
                      top: (_draggedUnitId != null || _selectedUnitId != null || _selectedEnemyUnitId != null) ? 80 : 38,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                        child: _buildSkillCutInBanner(),
                      ),
                    ),

                  // Tactical Synergy Combo Banner Overlay
                  if (_activeSynergyBannerText != null)
                    Positioned(
                      top: 18,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0E0E18).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _activeSynergyBannerColor, width: 1.4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _activeSynergyBannerColor.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 1.5,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _activeSynergyBannerText!,
                                  style: TextStyle(
                                    color: _activeSynergyBannerColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // In-Combat Ultimate Burst or Signature Skill Dramatic Cut-In Overlay
                  if (_activeUltimateUnit != null)
                    _buildUltimateCinematicOverlay(_activeUltimateUnit!),
                  if (_activeSignatureUnit != null && _activeUltimateUnit == null)
                    _buildSignatureSkillCinematicBanner(_activeSignatureUnit!, _activeSkillName ?? _activeSignatureUnit!.signatureSkillName),

                  // Slow-Motion Lethal Finisher Crimson Vignette Filter
                  if (_isSlowMoFinisher)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.95,
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFF1744).withValues(alpha: 0.35),
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              stops: const [0.35, 0.75, 1.0],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '⚔️ DECISIVE BLOW ⚔️',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                shadows: [
                                  Shadow(color: Color(0xFFFF1744), blurRadius: 18),
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Victory / Defeat Tactical Overlay Banner
                  if ((_engine.isVictory || _engine.isDefeat) && !_holdEndOfBattleOverlay)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 440),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14141E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _engine.isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF1744),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_engine.isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF1744)).withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _engine.isVictory ? Icons.emoji_events : Icons.heart_broken,
                                    color: _engine.isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                                    size: 36,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _engine.isVictory
                                        ? '${widget.encounterTitle ?? _engine.encounterTitle} CONQUERED'.toUpperCase()
                                        : 'RESONANCE SEVERED',
                                    style: TextStyle(
                                      color: _engine.isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _engine.isVictory
                                        ? 'The enemy regiment has collapsed into inert slag and bone.'
                                        : 'All constructs have fallen. Your neural tether dissipates into the miasma.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                                  ),

                                  // Star Rating & Instant Sweep Unlock (GDD §7.3)
                                  if (_engine.isVictory) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(3, (i) {
                                        final filled = i < _engine.starRating;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: Icon(
                                            filled ? Icons.star : Icons.star_border,
                                            color: filled ? const Color(0xFFFFD54F) : Colors.white24,
                                            size: 22,
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _engine.isFlawlessClear
                                          ? '🌟 3-STAR FLAWLESS CLEAR! INSTANT EXTRACTION UNLOCKED'
                                          : '${_engine.starRating}-STAR CLEAR (${_engine.casualtiesCount} Casualties)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _engine.isFlawlessClear ? const Color(0xFFFFE082) : Colors.white70,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                      ),
                                    ),

                                    // Loot & Currencies Reagents (GDD §7.1)
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0C0C14),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3)),
                                      ),
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.center,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          // Gold
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${_engine.rewardUnboundAsh} Gold',
                                                style: const TextStyle(color: Color(0xFFFFE082), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          // Cursed Ore
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.diamond_outlined, color: Color(0xFF26A69A), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${max(5, _engine.rewardDistilledVitae ~/ 4)} Ore',
                                                style: const TextStyle(color: Color(0xFF80CBC4), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (_engine.rewardBossReagent != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.whatshot, color: Color(0xFFFF9100), size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _engine.rewardBossReagent!,
                                                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Turn/Cycle Summary & Combat Statistics Dashboard (GDD §7 & Post-Battle Performance)
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0E18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.query_stats, color: Color(0xFF00E5FF), size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'BATTLE PERFORMANCE & TURN STATS',
                                                  style: TextStyle(
                                                    color: Color(0xFF80D8FF),
                                                    fontSize: 9.0,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.6,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'CYCLES: ${(_engine.currentTick / 30).toStringAsFixed(1)}s (${_engine.currentTick} TICKS)',
                                              style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF161828),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('TOTAL DAMAGE', style: TextStyle(color: Colors.white54, fontSize: 7.5, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      '${_engine.totalDamageDealt}',
                                                      style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF161828),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('DAMAGE TAKEN', style: TextStyle(color: Colors.white54, fontSize: 7.5, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      '${_engine.totalDamageTaken}',
                                                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF161828),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('SYNERGIES & BREAKS', style: TextStyle(color: Colors.white54, fontSize: 7.5, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      '🩸 ${_engine.bleedDetonationsCount} • 🔥 ${_engine.solarIgnitionsCount} • 🛑 ${_engine.interruptsCount} • 🎳 ${_engine.collisionsCount + _engine.wallSplatsCount} • ⚔️ ${_engine.chainAssistsCount}',
                                                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9.5, fontWeight: FontWeight.w900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Unit Breakdown
                                        ..._engine.playerUnits.map((u) {
                                          final dealt = _engine.unitDamageDealt[u.id] ?? 0;
                                          final shareRatio = _engine.totalDamageDealt > 0 ? (dealt / _engine.totalDamageDealt).clamp(0.0, 1.0) : 0.0;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 70,
                                                  child: Text(
                                                    u.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.white70, fontSize: 8.0, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(2),
                                                    child: LinearProgressIndicator(
                                                      value: shareRatio,
                                                      backgroundColor: const Color(0xFF26283A),
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                                                      minHeight: 4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$dealt DMG (${(shareRatio * 100).toStringAsFixed(0)}%) • HP ${u.hp}/${u.maxHp}',
                                                  style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 7.5, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      _buildGothicActionButton(
                                        icon: Icons.refresh,
                                        label: 'REPLAY',
                                        onPressed: _restartCombatEncounter,
                                        gradientColors: const [Color(0xFF262C38), Color(0xFF181C24)],
                                        borderColor: const Color(0xFFFFD54F).withValues(alpha: 0.7),
                                        textColor: const Color(0xFFFFE082),
                                        glowColor: const Color(0x33FFD54F),
                                      ),
                                      if (_engine.isVictory) ...[
                                        _buildGothicActionButton(
                                          icon: Icons.account_tree_rounded,
                                          label: _engine.skillTreeState.availableSkillPoints > 0
                                              ? 'SKILL TREE (${_engine.skillTreeState.availableSkillPoints}★)'
                                              : 'SKILL TREE',
                                          onPressed: () {
                                            CrucibleSkillTreeDialog.show(context, _engine).then((_) {
                                              setState(() {});
                                            });
                                          },
                                          gradientColors: const [Color(0xFF00695C), Color(0xFF004D40)],
                                          borderColor: const Color(0xFF69F0AE),
                                          textColor: const Color(0xFFE0F2F1),
                                          glowColor: const Color(0x5500E676),
                                        ),
                                        _buildGothicActionButton(
                                          icon: Icons.auto_fix_high,
                                          label: 'SQUAD & STAT UPGRADES',
                                          onPressed: () {
                                            CrucibleSanctuaryUpgradeDialog.show(context, _engine).then((_) {
                                              setState(() {});
                                            });
                                          },
                                          gradientColors: const [Color(0xFFE65100), Color(0xFFBF360C)],
                                          borderColor: const Color(0xFFFFAB40),
                                          textColor: Colors.white,
                                          glowColor: const Color(0x66FF6D00),
                                        ),
                                      ],
                                      if (_engine.isVictory && widget.onVictory != null)
                                        _buildGothicActionButton(
                                          icon: Icons.arrow_forward,
                                          label: 'CLAIM VICTORY & ADVANCE',
                                          onPressed: () {
                                            _playSfx('sfx_victory.wav');
                                            widget.onVictory!();
                                          },
                                          gradientColors: const [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                                          borderColor: const Color(0xFFFFD54F),
                                          textColor: const Color(0xFFFFF9C4),
                                          glowColor: const Color(0x6600E676),
                                        )
                                      else if (_engine.isDefeat && widget.onDefeat != null)
                                        _buildGothicActionButton(
                                          icon: Icons.home,
                                          label: 'RETURN TO CAMP',
                                          onPressed: widget.onDefeat,
                                          gradientColors: const [Color(0xFFC62828), Color(0xFF880E16)],
                                          borderColor: const Color(0xFFFF8A80),
                                          textColor: Colors.white,
                                          glowColor: const Color(0x66FF1744),
                                        )
                                      else if (widget.onBackToStandardCombat != null)
                                        _buildGothicActionButton(
                                          icon: Icons.exit_to_app,
                                          label: 'EXIT TO HUB',
                                          onPressed: widget.onBackToStandardCombat,
                                          gradientColors: const [Color(0xFF21212B), Color(0xFF16161F)],
                                          borderColor: Colors.white24,
                                          textColor: Colors.white70,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Option 3: Interactive Forge Strike Tactile Finisher Overlay
                  if (_isForgeStrikeActive)
                    Positioned.fill(
                      child: _buildForgeStrikeOverlay(),
                    ),
                ],
              ),
              ),
              ),
            ),

            // Option 1: Clean Turn-Based Hero HUD
            // Pre-Battle Staging Reserve Dock (Deployment Phase) vs Live Turn Action Tray & Pacing Bar
            if (_engine.isPreBattlePhase)
              Transform.translate(
                offset: const Offset(0, -10.0),
                child: _buildPreBattleStagingDock(isLandscapeMobile: isLandscapeMobile),
              )
            else ...[
              // Always-visible Crucible Commander Cinders Tray during active interval combat
              if (_engine.playerUnits.isNotEmpty)
                _buildSculptorCommanderTray(
                  _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull ??
                      _engine.playerUnits.first,
                  isLandscapeMobile: isLandscapeMobile,
                )
              else
                _buildCombatPacingStatusTray(isLandscapeMobile: isLandscapeMobile),
            ],

            // Slide-up Combat Chronicle Log Drawer (On-demand inspection overlay)
            if (_isLogDrawerVisible)
              _buildLogDrawerOverlay(isLandscapeMobile: isLandscapeMobile),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildGothicActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    Color glowColor = Colors.transparent,
    double fontSize = 10.5,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: borderColor, width: 1.3),
          boxShadow: glowColor != Colors.transparent
              ? [
                  BoxShadow(color: glowColor, blurRadius: 10, spreadRadius: 0.5),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                ]
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 0.6,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBossBreakBarHud(CombatUnitState boss, {bool isLandscapeMobile = false}) {
    final double hpRatio = boss.maxHp > 0 ? (boss.hp / boss.maxHp).clamp(0.0, 1.0) : 0.0;
    final double staggerRatio = boss.staggerFraction;
    final bool isStaggered = boss.isStaggered;

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLandscapeMobile ? 2 : 5),
      decoration: BoxDecoration(
        color: isStaggered ? const Color(0xFF261D00) : const Color(0xFF140C10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFFFF5252).withValues(alpha: 0.6),
          width: isStaggered ? 1.5 : 1.0,
        ),
        boxShadow: isStaggered
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFFF8A80)),
              const SizedBox(width: 5),
              Text(
                boss.name.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFFFE082),
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              if (boss.isSlagCarapaceActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E2723),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFFFB74D), width: 0.6),
                  ),
                  child: const Text(
                    'CARAPACE ACTIVE',
                    style: TextStyle(fontSize: 7.5, color: Color(0xFFFFCC80), fontWeight: FontWeight.bold),
                  ),
                )
              else if (boss.hasKineticBastion)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF372F15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFFFD54F), width: 0.6),
                  ),
                  child: const Text(
                    'KINETIC BASTION (+80 ARMOR)',
                    style: TextStyle(fontSize: 7.5, color: Color(0xFFFFE082), fontWeight: FontWeight.bold),
                  ),
                )
              else if (boss.isNecroticMireActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3820),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFF69F0AE), width: 0.6),
                  ),
                  child: const Text(
                    'NECROTIC MIRE ACTIVE',
                    style: TextStyle(fontSize: 7.5, color: Color(0xFFA7FFEB), fontWeight: FontWeight.bold),
                  ),
                ),
              const Spacer(),
              if (isStaggered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [BoxShadow(color: Color(0xFFFFAB00), blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on, size: 11, color: Colors.black),
                      const SizedBox(width: 2),
                      Text(
                        'CORE EXPOSED (${(boss.staggerDurationTicks / 30.0).toStringAsFixed(1)}s) • +50% VULNERABILITY',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'HP: ${boss.hp}/${boss.maxHp} (${(hpRatio * 100).toInt()}%)',
                  style: const TextStyle(
                    color: Color(0xFFFFCDD2),
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // Boss HP Bar with Segmented Quarter Ticks
          Stack(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0A0E),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24, width: 0.6),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hpRatio,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFFE53935), Color(0xFFFF5252)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Boss HP 25%, 50%, 75% notches
              ...[0.25, 0.50, 0.75].map((notch) => Positioned(
                left: null,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment(notch * 2 - 1, 0),
                  child: Container(
                    width: 1.2,
                    height: 7,
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 4),
          // Boss Break / Stagger Bar (Gorgoroth)
          if (boss.hasBreakBar) ...[
            Row(
              children: [
                Text(
                  isStaggered ? '⚡ STAGGERED' : 'BREAK BAR',
                  style: TextStyle(
                    color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF80D8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 7.8,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF080D14),
                          borderRadius: BorderRadius.circular(2.5),
                          border: Border.all(
                            color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                            width: isStaggered ? 0.9 : 0.6,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: isStaggered ? 1.0 : staggerRatio,
                        child: Container(
                          height: 5.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isStaggered
                                  ? [const Color(0xFFFFEA00), const Color(0xFFFF9100)]
                                  : [const Color(0xFF00B0FF), const Color(0xFF00E5FF)],
                            ),
                            borderRadius: BorderRadius.circular(2.5),
                            boxShadow: [
                              BoxShadow(
                                color: (isStaggered ? const Color(0xFFFFD600) : const Color(0xFF00E5FF)).withValues(alpha: 0.5),
                                blurRadius: isStaggered ? 6 : 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Stagger 25%, 50%, 75% tick notches
                      ...[0.25, 0.50, 0.75].map((notch) => Align(
                        alignment: Alignment(notch * 2 - 1, 0),
                        child: Container(
                          width: 1.0,
                          height: 5.5,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isStaggered ? 'SHATTERED' : '${boss.stagger}/${boss.maxStagger}',
                  style: TextStyle(
                    color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF80D8FF),
                    fontSize: 7.8,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ] else if (boss.hasKineticBastion) ...[
            // Malakor Kinetic Bastion Charge Bar
            Row(
              children: [
                const Icon(Icons.electric_bolt, size: 10, color: Color(0xFFFFD54F)),
                const SizedBox(width: 3),
                const Text(
                  'KINETIC BASTION',
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 7.5,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: List.generate(boss.maxKineticBastionCharges, (index) {
                      final bool isFilled = index < boss.kineticBastionCharges;
                      return Expanded(
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: isFilled ? const Color(0xFFFF9100) : Colors.black45,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: isFilled ? const Color(0xFFFFD54F) : Colors.white24,
                              width: 0.6,
                            ),
                            boxShadow: isFilled
                                ? [const BoxShadow(color: Color(0x66FF9100), blurRadius: 4)]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${boss.kineticBastionCharges}/${boss.maxKineticBastionCharges}',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 7.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else if (boss.isNecroticMireActive) ...[
            // Morvath Necrotic Mire Corruption Bar
            Row(
              children: [
                const Icon(Icons.coronavirus, size: 10, color: Color(0xFF69F0AE)),
                const SizedBox(width: 3),
                const Text(
                  'NECROTIC MIRE',
                  style: TextStyle(
                    color: Color(0xFF69F0AE),
                    fontWeight: FontWeight.w900,
                    fontSize: 7.5,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: const Color(0xFF69F0AE), width: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_engine.necroticMireNodes.length} FOULED TILES',
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 7.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopStatusRibbon(CombatUnitState? boss, {bool isLandscapeMobile = false}) {
    // Collect next impending turns sorted by closeness to 10,000 AP threshold
    final allLivingUnits = [..._engine.playerUnits, ..._engine.enemyUnits].where((u) => u.isAlive).toList();
    allLivingUnits.sort((a, b) {
      final aTicksLeft = ((SpatialCombatEngine.tickThreshold - a.currentAp) / max(1, a.speed)).clamp(0.0, 999.0);
      final bTicksLeft = ((SpatialCombatEngine.tickThreshold - b.currentAp) / max(1, b.speed)).clamp(0.0, 999.0);
      return aTicksLeft.compareTo(bTicksLeft);
    });

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLandscapeMobile ? 1 : 5),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(bottom: BorderSide(color: Color(0xFF282838), width: 1.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Ashen Reckoning Phase Clock Pill (GDD Sec 7.1)
                _buildAshenReckoningPill(),
                const SizedBox(width: 8),

                // 2. Top-Bar Crucible Skill Tree Shortcut (Always accessible)
                GestureDetector(
                  onTap: () {
                    _playSfx('sfx_card.wav');
                    CrucibleSkillTreeDialog.show(context, _engine).then((_) {
                      setState(() {});
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14241B), Color(0xFF0F1A13)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.85),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.25),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_tree_rounded, color: Color(0xFF69F0AE), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _engine.skillTreeState.availableSkillPoints > 0
                              ? 'SKILLS (${_engine.skillTreeState.availableSkillPoints}★)'
                              : 'SKILLS',
                          style: const TextStyle(
                            color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w900,
                            fontSize: 9.0,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Active Retinue Passives & Wave Indicator Ribbon
                if (_engine.activeRetinuePassiveLabels.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF231D14), Color(0xFF17120C)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups,
                          color: Color(0xFFFFD54F),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'RETINUE: ${_engine.activeRetinuePassiveLabels.join(" • ")}',
                          style: const TextStyle(
                            color: Color(0xFFFFE082),
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_engine.totalWaves > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF381014), Color(0xFF22090C)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF5252), width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.waves, color: Color(0xFFFF8A80), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'WAVE ${_engine.currentWaveIndex}/${_engine.totalWaves}',
                          style: const TextStyle(
                            color: Color(0xFFFF8A80),
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),

                // 6. Crucible Dev Sandbox Button
                if (kDebugMode)
                  GestureDetector(
                    onTap: () {
                      CrucibleDebugSandboxDialog.show(
                        context,
                        engine: _engine,
                        onStateChanged: () => setState(() {}),
                        onUnlockAllUnits: _debugUnlockAllRetinueUnits,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2C2410), Color(0xFF1B1608)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.8), width: 1.0),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.build_circle, color: Color(0xFFFFD54F), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'DEV TOOLS',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.w900,
                              fontSize: 8.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 2d. Ashen Reckoning Soft Enrage Status (GDD §6.3)
                if (_engine.isAshenReckoning) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF1744)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Color(0xFFFF1744), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'ASHEN RECKONING (DMG x2.0)',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(width: 12),

                // 3. Boss Telegraph Execution Warning Badge
                if (boss != null && boss.pendingIntent != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF1744)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${boss.pendingIntent!.skillName.toUpperCase()} IN ${boss.pendingIntent!.triggerTick - _engine.currentTick} TICKS',
                          style: const TextStyle(
                            color: Color(0xFFFF8A80),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),

          if (boss != null && boss.isAlive && (boss.hasBreakBar || boss.hasKineticBastion || boss.isNecroticMireActive)) ...[
            const SizedBox(height: 4),
            _buildBossBreakBarHud(boss, isLandscapeMobile: isLandscapeMobile),
          ],

          // 4. Live Initiative Action Timeline (Auto-collapsed on <550px mobile landscape, 1-tap expandable)
          if (!(_timelineExpandedOverride ?? !isLandscapeMobile))
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => setState(() => _timelineExpandedOverride = true),
                child: Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14121A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 10, color: Color(0xFFFFD54F)),
                      SizedBox(width: 4),
                      Text('SHOW TIMELINE', style: TextStyle(fontSize: 7.5, color: Color(0xFFFFD54F), fontWeight: FontWeight.w900)),
                      SizedBox(width: 2),
                      Icon(Icons.expand_more, size: 12, color: Color(0xFFFFD54F)),
                    ],
                  ),
                ),
              ),
            )
          else
          Container(
            height: 34,
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14121A), Color(0xFF0C0A10)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF2C2836), width: 0.9),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _timelineExpandedOverride = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1826),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFFFD54F)),
                        SizedBox(width: 4),
                        Text(
                          'TIMELINE',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.expand_less, size: 12, color: Color(0xFFFFD54F)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allLivingUnits.take(7).length,
                    separatorBuilder: (context, _) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(Icons.chevron_right_rounded, size: 13, color: Color(0xFF4A4458)),
                    ),
                    itemBuilder: (context, idx) {
                      final u = allLivingUnits[idx];
                      final isAlly = u.isPlayer;
                      final isSelected = (_selectedUnitId == u.id) || (_selectedEnemyUnitId == u.id);
                      final isActingNext = idx == 0;
                      final apRatio = (u.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
                      final apPercent = (apRatio * 100).toInt();

                      return Tooltip(
                        message: '${u.name} • ${isAlly ? "Ally" : "Enemy"}\nHP: ${u.hp}/${u.maxHp} • AP: $apPercent% • SPD: ${u.speed}',
                        waitDuration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              if (isAlly) {
                                _selectedUnitId = u.id;
                                _selectedEnemyUnitId = null;
                              } else {
                                _selectedEnemyUnitId = u.id;
                                _selectedUnitId = null;
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? (isAlly
                                        ? [const Color(0xFF1E3A24), const Color(0xFF142618)]
                                        : [const Color(0xFF4A1A1E), const Color(0xFF2C1014)])
                                    : (isAlly
                                        ? [const Color(0xFF141F18), const Color(0xFF0E1611)]
                                        : [const Color(0xFF241416), const Color(0xFF170D0E)]),
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFD54F)
                                    : (isActingNext
                                        ? (isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80))
                                        : (isAlly ? const Color(0xFF2E7D32) : const Color(0xFF7F1D1D))),
                                width: isSelected ? 1.5 : (isActingNext ? 1.3 : 0.8),
                              ),
                              boxShadow: isActingNext
                                  ? [
                                      BoxShadow(
                                        color: (isAlly ? const Color(0xFF4CAF50) : const Color(0xFFFF5252)).withValues(alpha: 0.45),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Chamfered Miniature Portrait
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3.5),
                                    color: Colors.black54,
                                    border: Border.all(
                                      color: isActingNext
                                          ? const Color(0xFFFFD54F)
                                          : (isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80)),
                                      width: isActingNext ? 1.1 : 0.7,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(
                                    u.assetPath,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    errorBuilder: (_, __, ___) => Icon(
                                      isAlly ? Icons.shield : Icons.security,
                                      size: 11,
                                      color: isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),

                                // Name and AP Gauge
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isActingNext)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 2.5),
                                            child: Icon(Icons.flash_on, size: 9, color: Color(0xFFFFD54F)),
                                          ),
                                        Text(
                                          u.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 7.8,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                            color: isSelected
                                                ? const Color(0xFFFFD54F)
                                                : (isAlly ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 1.5),
                                    // Mini AP progress bar
                                    Container(
                                      width: 34,
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: apRatio,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isActingNext
                                                ? const Color(0xFFFFD54F)
                                                : (isAlly ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
                                            borderRadius: BorderRadius.circular(1),
                                            boxShadow: isActingNext
                                                ? [
                                                    const BoxShadow(
                                                      color: Color(0xFFFFD54F),
                                                      blurRadius: 3,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$apPercent%',
                                  style: TextStyle(
                                    fontSize: 7.2,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    color: isActingNext
                                        ? const Color(0xFFFFD54F)
                                        : (isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// Builds the unified 2.5D Isometric Battlefield Board (Image 2 style)
  /// An authentic continuous angled terrain plane where Enemy Rows and Player Rows
  /// form a single unbroken isometric grid meeting seamlessly along the neutral clash line.
  Widget _buildUnifiedIsometricBattlefield({
    required double tileWidth,
    required double tileHeight,
  }) {
    // Continuous coordinate system:
    // Global Row Index gRow (0..6):
    // gRow 0 = Enemy Backline (Enemy Row 2)
    // gRow 1 = Enemy Midline (Enemy Row 1)
    // gRow 2 = Enemy Frontline (Enemy Row 0)
    // gRow 3 = Neutral Clash Line / Buffer
    // gRow 4 = Player Frontline (Player Row 0)
    // gRow 5 = Player Midline (Player Row 1)
    // gRow 6 = Player Backline (Player Row 2)
    const int numCols = 5;
    const int numGRows = 7;

    // Board bounding dimensions in isometric space:
    // Isometric formula:
    // px = (col - gRow) * (tileWidth / 2)
    // py = (col + gRow) * (tileHeight / 2)
    // Range of (col - gRow): min = 0 - 6 = -6, max = 4 - 0 = +4 -> spread 10 half-widths.
    // Center offset ensures all coordinates are >= 0 inside the canvas.
    final double originX = (numGRows - 1) * (tileWidth * 0.5);
    final double originY = 0.0;
    final double boardTotalWidth = originX + (numCols - 1) * (tileWidth * 0.5) + tileWidth;
    final double boardTotalHeight = (numCols - 1 + numGRows - 1) * (tileHeight * 0.5) + tileHeight + 20.0;

    // Collect all cells to render sorted by isometric depth (gRow + col)
    // This guarantees back-to-front painter order so foreground units/tiles draw over background.
    final List<_IsometricCellData> allCells = [];

    for (int gRow = 0; gRow < numGRows; gRow++) {
      for (int col = 0; col < numCols; col++) {
        final bool isClashLine = (gRow == 3);
        final bool isPlayerSquad = (gRow > 3);
        final int localRow = isPlayerSquad ? (gRow - 4) : (2 - gRow);

        allCells.add(_IsometricCellData(
          gRow: gRow,
          col: col,
          localRow: localRow,
          isClashLine: isClashLine,
          isPlayerSquad: isPlayerSquad,
          depth: gRow + col,
          screenX: originX + (col - gRow) * (tileWidth * 0.5),
          screenY: originY + (col + gRow) * (tileHeight * 0.5),
        ));
      }
    }

    allCells.sort((a, b) => a.depth.compareTo(b.depth));

    // Dynamic Attack & Threat Trajectory Resolution:
    // Collects translucent trajectory lines for:
    // 1) Selected or picked-up (dragged) player unit + secondary cleave/pierce branches
    // 2) All living player units when "ALL VECTORS" toggle is active
    // 3) Clicked/inspected enemy unit basic attack vector
    // 4) Live winding-up enemy telegraphed attacks (2.0s countdown threat vectors)
    final List<_TrajectoryData> trajectories = [];
    final String? inspectedUnitId = _draggedUnitId ?? _selectedUnitId;

    void addPlayerUnitTrajectory(CombatUnitState unit, {required bool isPrimaryInspected}) {
      if (!unit.isAlive) return;
      final bool isHoveringPlayerCell = (isPrimaryInspected &&
          _draggedUnitId == unit.id &&
          _hoveredTileCol != null &&
          _hoveredTileGRow != null &&
          _hoveredTileGRow! > 3);
      if (unit.occupiedNodes.isEmpty && !isHoveringPlayerCell) return;

      final int srcCol = isHoveringPlayerCell ? _hoveredTileCol! : unit.occupiedNodes.first.column;
      final int srcGRow = isHoveringPlayerCell ? _hoveredTileGRow! : (4 + unit.occupiedNodes.first.row);
      final int srcLocalRow = srcGRow - 4;

      final double srcX = originX + (srcCol - srcGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
      final double srcY = originY + (srcCol + srcGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
      final Offset sourceOffset = Offset(srcX, srcY);

      final target = _engine.resolveProjectedTarget(unit, simulatedCol: srcCol);
      if (target != null && target.occupiedNodes.isNotEmpty) {
        final Offset targetOffset = _getUnitCenterIsometricOffset(target, tileWidth: tileWidth, tileHeight: tileHeight);

        // Clean Target Color & Damage Estimate (no row-stance nerfs or flank clutter)
        const Color trajColor = Color(0xFF00E5FF);
        final int estDmg = (unit.attack * (1.0 - (target.armor / 100.0).clamp(0.0, 0.75))).round();
        final baseSkillDesc = _getUnitBasicAttackDescription(unit, srcCol, srcLocalRow);
        const String prefix = '🎯 TARGET';
        final skillDesc = '$baseSkillDesc [~$estDmg DMG]';

        trajectories.add(_TrajectoryData(
          sourceOffset: sourceOffset,
          targetOffset: targetOffset,
          skillName: skillDesc,
          targetName: target.name,
          color: trajColor,
          showLabel: isPrimaryInspected || _engine.isPreBattlePhase,
          labelPrefix: prefix,
        ));

        // Add secondary cleave or column-pierce trajectory branches when inspecting unit
        if (isPrimaryInspected) {
          final secondaries = _engine.resolveSecondaryProjectedTargets(
            unit,
            simulatedCol: srcCol,
            simulatedRow: srcLocalRow,
          );
          for (final sec in secondaries) {
            if (sec.occupiedNodes.isEmpty) continue;
            final secNode = sec.occupiedNodes.first;
            final int secGRow = 2 - secNode.row;
            final double secX = originX + (secNode.column - secGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
            final double secY = originY + (secNode.column + secGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
            
            // Secondary cleave/pierce typically strikes for 50%-75% of primary hit
            final int secEstDmg = (estDmg * 0.60).round();
            trajectories.add(_TrajectoryData(
              sourceOffset: sourceOffset,
              targetOffset: Offset(secX, secY),
              skillName: 'CLEAVE [~$secEstDmg DMG]',
              targetName: sec.name,
              color: trajColor.withValues(alpha: 0.85),
              isSecondary: true,
              showLabel: true,
              labelPrefix: '⚡',
            ));
          }
        }
      }
    }

    if (_showAllTrajectories || _engine.isPreBattlePhase) {
      for (final u in _engine.playerUnits.where((u) => u.isAlive && u.occupiedNodes.isNotEmpty)) {
        addPlayerUnitTrajectory(u, isPrimaryInspected: u.id == inspectedUnitId || _engine.isPreBattlePhase);
      }
    } else if (inspectedUnitId != null) {
      final unit = _engine.playerUnits.where((u) => u.id == inspectedUnitId && u.isAlive).firstOrNull;
      if (unit != null) {
        addPlayerUnitTrajectory(unit, isPrimaryInspected: true);
      }
    }

    // Hovered Enemy Unit Trajectory (shows who an enemy aims at only while hovering it)
    if (_hoveredEnemyUnitId != null) {
      final enemy = _engine.enemyUnits.where((u) => u.id == _hoveredEnemyUnitId && u.isAlive).firstOrNull;
      if (enemy != null && enemy.occupiedNodes.isNotEmpty && enemy.pendingIntent == null) {
        final Offset enemyCenter = _getUnitCenterIsometricOffset(enemy, tileWidth: tileWidth, tileHeight: tileHeight);
        final double srcX = enemyCenter.dx;
        final double srcY = enemyCenter.dy;

        final targetAlly = _engine.resolveProjectedTarget(enemy, simulatedCol: enemy.occupiedNodes.first.column);
        if (targetAlly != null && targetAlly.occupiedNodes.isNotEmpty) {
          final aNode = targetAlly.occupiedNodes.first;
          final int aGRow = 4 + aNode.row;
          final double tgtX = originX + (aNode.column - aGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
          final double tgtY = originY + (aNode.column + aGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
          final String enemySkill = enemy.id == 'pyre_zealot'
              ? 'Pyre Skewer (2.0s Windup)'
              : (enemy.id == 'cinder_witch' ? 'Cinder Orb (2.0s Windup)' : 'Titanic Crush');

          trajectories.add(_TrajectoryData(
            sourceOffset: Offset(srcX, srcY),
            targetOffset: Offset(tgtX, tgtY),
            skillName: enemySkill,
            targetName: targetAlly.name,
            color: const Color(0xFFFF5252),
            showLabel: true,
          ));
        }
      }
    }

    // Active Live Enemy Telegraph Windups (2.0s Threat Vectors)
    for (final enemy in _engine.enemyUnits.where((u) => u.isAlive && u.pendingIntent != null)) {
      if (enemy.occupiedNodes.isEmpty) continue;
      final intent = enemy.pendingIntent!;
      final Offset sourceOffset = _getUnitCenterIsometricOffset(enemy, tileWidth: tileWidth, tileHeight: tileHeight);

      final int remTicks = max(0, intent.triggerTick - _engine.currentTick);
      final String remSec = (remTicks / 30.0).toStringAsFixed(1);

      for (int i = 0; i < min(3, intent.targetNodes.length); i++) {
        final tNode = intent.targetNodes[i];
        final int tgtGRow = 4 + tNode.row;
        final double tgtX = originX + (tNode.column - tgtGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
        final double tgtY = originY + (tNode.column + tgtGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
        final occupantAlly = _engine.playerUnits
            .where((u) => u.isAlive && u.occupies(tNode.column, tNode.row))
            .firstOrNull;

        trajectories.add(_TrajectoryData(
          sourceOffset: sourceOffset,
          targetOffset: Offset(tgtX, tgtY),
          skillName: '⚠️ ${intent.skillName} (${remSec}s)',
          targetName: occupantAlly?.name ?? 'COL ${tNode.column + 1}',
          color: const Color(0xFFFF1744),
          isSecondary: i > 0,
          showLabel: i == 0,
        ));
      }
    }

    // 5) Turn-Triage Movement & Evasion Arc Trajectory (when dragging a player unit)
    if (_draggedUnitId != null &&
        _hoveredTileCol != null &&
        _hoveredTileGRow != null &&
        _hoveredTileGRow! > 3) {
      final draggedUnit = _engine.playerUnits.where((u) => u.id == _draggedUnitId && u.isAlive).firstOrNull;
      if (draggedUnit != null && draggedUnit.occupiedNodes.isNotEmpty) {
        final originNode = draggedUnit.occupiedNodes.first;
        final int originCol = originNode.column;
        final int originGRow = 4 + originNode.row;
        final double srcX = originX + (originCol - originGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
        final double srcY = originY + (originCol + originGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);

        final int targetCol = _hoveredTileCol!;
        final int targetGRow = _hoveredTileGRow!;
        final int targetLocalRow = targetGRow - 4;
        final double tgtX = originX + (targetCol - targetGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
        final double tgtY = originY + (targetCol + targetGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);

        // Movement validity checks
        final occupantAlly = _engine.playerUnits
            .where((u) => u.isAlive && u.id != draggedUnit.id && u.occupies(targetCol, targetLocalRow))
            .firstOrNull;
        final bool canEnterOrSwap = occupantAlly == null || !occupantAlly.isDisplacementImmune;
        final bool isValidMove = canEnterOrSwap &&
            draggedUnit.canMoveTo(targetCol, targetLocalRow, ignoreApCost: _engine.isPreBattlePhase);

        // Danger evasion detection
        final bool originInDanger = draggedUnit.occupiedNodes.any((n) =>
            _engine.activeTelegraphedNodes.any((tn) => tn.column == n.column && tn.row == n.row));
        final bool targetInDanger =
            _engine.activeTelegraphedNodes.any((tn) => tn.column == targetCol && tn.row == targetLocalRow);

        Color pathColor;
        String skillLabel;
        String targetDesc;
        String iconPrefix;

        if (!isValidMove) {
          pathColor = const Color(0xFFFF1744); // Crimson for invalid/out-of-range
          skillLabel = 'OUT OF RANGE';
          targetDesc = 'Max ${draggedUnit.moveRange} Tile';
          iconPrefix = '⛔';
        } else if (originInDanger && !targetInDanger) {
          pathColor = const Color(0xFF00E676); // Emerald Green for successful evasion!
          skillLabel = 'EVADING DANGER!';
          targetDesc = _engine.isPreBattlePhase ? '0 AP Safe Footing' : 'Safe Footing (50% AP)';
          iconPrefix = '🛡️';
        } else if (occupantAlly != null) {
          pathColor = const Color(0xFFFFD54F); // Amber for formation swap
          skillLabel = 'FORMATION SWAP';
          targetDesc = 'Swap with ${occupantAlly.name}';
          iconPrefix = '⇄';
        } else {
          pathColor = const Color(0xFF00E5FF); // Cyan for clean tactical move
          skillLabel = 'REPOSITION';
          targetDesc = _engine.isPreBattlePhase ? 'Free Deploy' : 'Move (50% AP)';
          iconPrefix = '⚡';
        }

        trajectories.add(_TrajectoryData(
          sourceOffset: Offset(srcX, srcY),
          targetOffset: Offset(tgtX, tgtY),
          skillName: skillLabel,
          targetName: targetDesc,
          color: pathColor,
          showLabel: true,
          isArcPath: true,
          labelPrefix: iconPrefix,
        ));
      }
    }

    return SizedBox(
      width: boardTotalWidth,
      height: boardTotalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...allCells.map((cell) {
            if (cell.isClashLine) {
              return Positioned(
                left: cell.screenX,
                top: cell.screenY,
                width: tileWidth,
                height: tileHeight,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    if (details.data.startsWith('card:')) {
                      if (_hoveredTileGRow != cell.gRow || _hoveredTileCol != cell.col) {
                        setState(() {
                          _hoveredTileGRow = cell.gRow;
                          _hoveredTileCol = cell.col;
                        });
                      }
                      return true;
                    }
                    return false;
                  },
                  onLeave: (_) {
                    if (_hoveredTileGRow == cell.gRow && _hoveredTileCol == cell.col) {
                      setState(() {
                        _hoveredTileGRow = null;
                        _hoveredTileCol = null;
                      });
                    }
                  },
                  onAcceptWithDetails: (details) {
                    final data = details.data;
                    if (data.startsWith('card:')) {
                      final cardId = data.replaceFirst('card:', '');
                      _engine.castCard(cardId, targetCol: cell.col, targetRow: 0);
                      setState(() {
                        _hoveredTileGRow = null;
                        _hoveredTileCol = null;
                      });
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return _buildClashLineTile(cell.col, tileWidth: tileWidth, tileHeight: tileHeight);
                  },
                ),
              );
            }

            return Positioned(
              left: cell.screenX,
              top: cell.screenY,
              width: tileWidth,
              height: tileHeight,
              child: _buildIsometricGridCell(
                cell.col,
                cell.localRow,
                gRow: cell.gRow,
                isPlayerSquad: cell.isPlayerSquad,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
              ),
            );
          }),

          // Centered Multi-Tile / Behemoth Unit Layer (Generic for any 2x2, 1x2, 2x1, or multi-node unit)
          // Dynamically computes bounding box center from unit.occupiedNodes for seamless targeting & visual positioning.
          ...[..._engine.enemyUnits, ..._engine.playerUnits].where((u) => u.isAlive && (u.occupiedNodes.length > 1 || u.footprint != UnitFootprint.single1x1)).map((multiUnit) {
            final double spanWidth = tileWidth * (multiUnit.footprint == UnitFootprint.quadColossus2x2 ? 2.2 : (multiUnit.occupiedNodes.length > 2 ? 2.0 : 1.6));
            final double spanHeight = tileHeight * (multiUnit.footprint == UnitFootprint.quadColossus2x2 ? 2.0 : 1.5);

            final centerOffset = _getUnitCenterIsometricOffset(multiUnit, tileWidth: tileWidth, tileHeight: tileHeight);
            final double screenLeft = centerOffset.dx - (spanWidth * 0.5);
            final double screenTop = centerOffset.dy - spanHeight + (tileHeight * 0.45);

            final bool isSelected = multiUnit.isPlayer ? (_selectedUnitId == multiUnit.id) : (_selectedEnemyUnitId == multiUnit.id);
            final targetAnchor = multiUnit.occupiedNodes.isNotEmpty ? multiUnit.occupiedNodes.first : const GridNode(column: 1, row: 0);

            return Positioned(
              left: screenLeft,
              top: screenTop,
              width: spanWidth,
              height: spanHeight,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  final data = details.data;
                  if (data.startsWith('card:')) {
                    final cardId = data.replaceFirst('card:', '');
                    final card = _engine.hand.where((c) => c.id == cardId).firstOrNull;
                    if (card == null) return false;
                    if (card.id == 'phalanx_intercept') return multiUnit.isPlayer;
                    if (card.id == 'stoke_the_embers') return true;
                    return !multiUnit.isPlayer;
                  } else if (data.startsWith('ultimate:')) {
                    final unitId = data.replaceFirst('ultimate:', '');
                    final ultUnit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
                    final isSupportUlt = unitId == 'iron_footman' ||
                        (ultUnit != null && (ultUnit.templateId.contains('medicus') || ultUnit.templateId.contains('priestess') || ultUnit.templateId.contains('alchemist')));
                    return isSupportUlt ? multiUnit.isPlayer : !multiUnit.isPlayer;
                  } else if (data.startsWith('unit:')) {
                    final unitId = data.replaceFirst('unit:', '');
                    final draggedUnit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
                    return multiUnit.isPlayer &&
                        draggedUnit != null &&
                        draggedUnit.id != multiUnit.id &&
                        !multiUnit.isDisplacementImmune &&
                        targetAnchor.column >= 0 &&
                        targetAnchor.column <= 2 &&
                        targetAnchor.row >= 0 &&
                        targetAnchor.row <= 2;
                  }
                  return false;
                },
                onAcceptWithDetails: (details) {
                  final data = details.data;
                  if (data.startsWith('card:')) {
                    final cardId = data.replaceFirst('card:', '');
                    _engine.castCard(cardId, targetUnit: multiUnit, targetCol: targetAnchor.column, targetRow: targetAnchor.row);
                    setState(() {
                      _hoveredTileGRow = null;
                      _hoveredTileCol = null;
                    });
                  } else if (data.startsWith('ultimate:')) {
                    final unitId = data.replaceFirst('ultimate:', '');
                    _engine.castUltimate(unitId, targetUnit: multiUnit, targetCol: targetAnchor.column, targetRow: targetAnchor.row);
                    setState(() {
                      _draggedUltimateUnitId = null;
                      _selectedUltimateUnitId = null;
                      _hoveredTileGRow = null;
                      _hoveredTileCol = null;
                    });
                  } else if (data.startsWith('unit:')) {
                    final unitId = data.replaceFirst('unit:', '');
                    _engine.movePlayerUnit(unitId, targetAnchor.column, targetAnchor.row);
                    setState(() {
                      _selectedUnitId = unitId;
                      _draggedUnitId = null;
                      _hoveredTileGRow = null;
                      _hoveredTileCol = null;
                    });
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final bool isDropCandidate = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: isDropCandidate
                        ? BoxDecoration(
                            border: Border.all(color: const Color(0xFFFFD54F), width: 2.0),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          )
                        : null,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          if (multiUnit.isPlayer) {
                            _selectedUnitId = (_selectedUnitId == multiUnit.id) ? null : multiUnit.id;
                            _selectedEnemyUnitId = null;
                          } else {
                            _selectedEnemyUnitId = (_selectedEnemyUnitId == multiUnit.id) ? null : multiUnit.id;
                            _selectedUnitId = null;
                          }
                        });
                      },
                      child: Center(
                        child: multiUnit.isPlayer
                            ? Draggable<String>(
                                data: 'unit:${multiUnit.id}',
                                maxSimultaneousDrags: 1,
                                onDragStarted: () {
                                  setState(() {
                                    _draggedUnitId = multiUnit.id;
                                    _selectedUnitId = multiUnit.id;
                                    _selectedEnemyUnitId = null;
                                  });
                                  if (!_engine.isPreBattlePhase) {
                                    _engine.setBulletTime(true);
                                  }
                                },
                                onDragEnd: (_) {
                                  setState(() {
                                    _draggedUnitId = null;
                                  });
                                  if (!_engine.isPreBattlePhase) {
                                    _engine.setBulletTime(false);
                                  }
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _buildUnitMiniatureWidget(
                                    multiUnit,
                                    tileWidth: tileWidth,
                                    tileHeight: tileHeight,
                                    colGap: 0.0,
                                    isDragging: true,
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildUnitMiniatureWidget(
                                    multiUnit,
                                    tileWidth: tileWidth,
                                    tileHeight: tileHeight,
                                    colGap: 0.0,
                                  ),
                                ),
                                child: _buildUnitMiniatureWidget(
                                  multiUnit,
                                  tileWidth: tileWidth,
                                  tileHeight: tileHeight,
                                  colGap: 0.0,
                                  isSelected: isSelected || isDropCandidate,
                                ),
                              )
                            : MouseRegion(
                                onEnter: (_) {
                                  if (_hoveredEnemyUnitId != multiUnit.id) {
                                    setState(() => _hoveredEnemyUnitId = multiUnit.id);
                                  }
                                },
                                onExit: (_) {
                                  if (_hoveredEnemyUnitId == multiUnit.id) {
                                    setState(() => _hoveredEnemyUnitId = null);
                                  }
                                },
                                child: _buildUnitMiniatureWidget(
                                  multiUnit,
                                  tileWidth: tileWidth,
                                  tileHeight: tileHeight,
                                  colGap: 0.0,
                                  isSelected: isSelected || isDropCandidate,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // Attack & Threat Trajectory Overlay Layer (Translucent lines for inspected units & enemy telegraphs)
          if (trajectories.isNotEmpty)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _visualFrameTick,
                    builder: (context, _, __) => CustomPaint(
                      painter: _AttackTrajectoryOverlayPainter(
                        trajectories: trajectories,
                        dashPhase: _dashPhase,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Ground Shockwave Ripple Painter Layer (Expanding concentric isometric shockwaves)
          if (_groundRipples.isNotEmpty)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _visualFrameTick,
                    builder: (context, _, __) => CustomPaint(
                      painter: _GroundShockwaveRipplePainter(
                        ripples: _groundRipples,
                        currentTimestampMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Dynamic Kinetic Combat VFX Overlay Layer (Slashes, Beams, Shockwaves)
          if (_activeVfx.isNotEmpty)
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _visualFrameTick,
                    builder: (context, _, __) => CustomPaint(
                      painter: _CombatVfxOverlayPainter(
                        effects: _activeVfx,
                        currentTimestampMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClashLineTile(int col, {required double tileWidth, required double tileHeight}) {
    return CustomPaint(
      painter: IsometricDiamondTilePainter(
        fillColor: const Color(0xFFFFD54F).withValues(alpha: 0.05),
        borderColor: const Color(0xFFFFD54F).withValues(alpha: 0.35),
        borderWidth: 1.0,
        hasGlow: false,
      ),
      child: Center(
        child: Icon(
          Icons.swap_vert_rounded,
          color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
          size: 16,
        ),
      ),
    );
  }

  /// Calculates affected global grid cells when an Ultimate mini-slate is dragged over targetGRow, targetCol
  List<({int gRow, int col})> _getUltimateAffectedGridCells(String unitId, int targetGRow, int targetCol) {
    final List<({int gRow, int col})> cells = [];
    final unit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
    final pattern = unit?.ultimatePattern ?? TargetPattern.singleTarget;

    switch (pattern) {
      case TargetPattern.piercingColumnSkewer:
        // Skewers entire enemy column (gRow 0, 1, 2 at targetCol)
        for (int gr = 0; gr <= 2; gr++) {
          cells.add((gRow: gr, col: targetCol));
        }
        break;

      case TargetPattern.horizontalRowScythe:
        // If ally protective buff (e.g. Iron Footman), targets player Frontline (gRow 4, all 5 cols)
        if (unitId == 'iron_footman' || unit?.archetype == UnitArchetype.vanguardMelee && targetGRow >= 4) {
          for (int gc = 0; gc < 5; gc++) {
            cells.add((gRow: 4, col: gc));
          }
        } else {
          // Offensive row scythe across enemy frontline (gRow 2, all 5 cols)
          for (int gc = 0; gc < 5; gc++) {
            cells.add((gRow: targetGRow <= 2 ? targetGRow : 2, col: gc));
          }
        }
        break;

      case TargetPattern.stAshlarCross:
        // Cross pattern centered on target
        cells.add((gRow: targetGRow, col: targetCol));
        const deltas = [(0, 1), (0, -1), (1, 0), (-1, 0)];
        for (final (dRow, dCol) in deltas) {
          final nr = targetGRow + dRow;
          final nc = targetCol + dCol;
          if (nr >= 0 && nr < 7 && nc >= 0 && nc < 5) {
            cells.add((gRow: nr, col: nc));
          }
        }
        break;

      case TargetPattern.tShapedCleave:
        // T-cleave: target cell + adjacent horizontal tiles + tile behind/forward
        cells.add((gRow: targetGRow, col: targetCol));
        for (final dc in [-1, 1]) {
          final nc = targetCol + dc;
          if (nc >= 0 && nc < 5) cells.add((gRow: targetGRow, col: nc));
        }
        final nr = targetGRow > 3 ? targetGRow - 1 : targetGRow + 1;
        if (nr >= 0 && nr < 7) cells.add((gRow: nr, col: targetCol));
        break;

      case TargetPattern.singleTarget:
      default:
        cells.add((gRow: targetGRow, col: targetCol));
        break;
    }
    return cells;
  }

  /// Calculates dynamic skill description for unit basic action based on physical depth/archetype
  String _getUnitBasicAttackDescription(CombatUnitState unit, int simulatedCol, int simulatedRow) {
    if (unit.isAshSculptor) {
      return 'Cinder Cleave (+Cinders)';
    }
    final key = '${unit.id.toLowerCase()}_${unit.templateId.toLowerCase()}_${unit.name.toLowerCase()}';
    if (key.contains('arbalest') || key.contains('marksman') || key.contains('archer')) {
      return 'Armor-Piercing Bolt (-12 Armor)';
    }
    if (key.contains('duelist') || key.contains('sanguine_blade') || key.contains('flayer')) {
      return 'Flensing Thrust (Crit & Bleed)';
    }
    if (key.contains('warhound') || key.contains('hound') || key.contains('cerberus')) {
      return 'Rending Bite (Bleed & Execute)';
    }
    if (key.contains('cleric') || key.contains('alchemist') || key.contains('medicus') || key.contains('sun_smith')) {
      return 'Radiant Sear (+Turn Mend)';
    }
    if (key.contains('scribe') || key.contains('sorcerer') || key.contains('cinder_witch') || key.contains('blood_initiate')) {
      return 'Sanguine Bolt (+Cinders)';
    }
    if (key.contains('footman') || key.contains('sentinel') || key.contains('juggernaut')) {
      return 'Shield Bash (-12 Armor & Aegis)';
    }
    if (unit.archetype == UnitArchetype.reachMidline) {
      return 'Skirmish Thrust (Bleed)';
    }
    if (unit.archetype == UnitArchetype.backlineCaster) {
      return 'Arcane Bolt';
    }
    return 'Vanguard Strike';
  }

  /// Calculates predicted phantom damage or buff for a unit given the hovered Ultimate
  String? _getPhantomUltimateEffect(CombatUnitState unit, String ultUnitId, int targetGRow, int targetCol) {
    if (!unit.isAlive) return null;

    final ultUnit = _engine.playerUnits.where((u) => u.id == ultUnitId && u.isAlive).firstOrNull;
    if (ultUnit == null) return null;

    final affected = _getUltimateAffectedGridCells(ultUnitId, targetGRow, targetCol);
    bool isUnitHit = false;
    for (final node in unit.occupiedNodes) {
      final int unitGRow = unit.isPlayer ? (4 + node.row) : (2 - node.row);
      if (affected.any((c) => c.gRow == unitGRow && c.col == node.column)) {
        isUnitHit = true;
        break;
      }
    }

    if (!isUnitHit) return null;

    if (ultUnitId == 'iron_footman') {
      if (unit.isPlayer && unit.occupiedNodes.any((n) => n.row == 0)) {
        return '+60 🛡️ AEGIS';
      }
      return null;
    }

    if (unit.isPlayer) {
      if (ultUnit.archetype == UnitArchetype.vanguardMelee && unit.occupiedNodes.any((n) => n.row == 0)) {
        return '+25 🛡️ ARMOR';
      }
      if (ultUnit.archetype == UnitArchetype.backlineCaster) {
        return '+60 ❤️ HEAL';
      }
      return null;
    }

    // Offensive Ultimates targeting enemies:
    int rawDmg = (ultUnit.effectiveAttack * 2.2).round();
    if (ultUnitId == 'lady_valeria') {
      rawDmg = 240;
    } else if (ultUnitId == 'sanguine_blade') {
      rawDmg = 280 + (unit.bleedStacks * 35);
    } else if (ultUnitId == 'sun_smith') {
      rawDmg = 180;
    }

    final projectedDmg = (rawDmg * (1.0 - (unit.armor / 100).clamp(0.0, 0.75))).round();
    return '⚡ -$projectedDmg APEX';
  }

  Widget _buildIsometricGridCell(
    int col,
    int row, {
    required int gRow,
    required bool isPlayerSquad,
    required double tileWidth,
    required double tileHeight,
  }) {
    const double colGap = 0.0;
    final squad = isPlayerSquad ? _engine.playerUnits : _engine.enemyUnits;
    final occupant = squad.where((u) => u.isAlive && u.occupies(col, row)).firstOrNull;

    // Check if this node is inside ANY enemy telegraph intent (Gorgoroth, Pyre Zealot, Cinder Witch)
    // Puts a light red tinge on affected grids so players can move or protect constructs
    final isTelegraphed = isPlayerSquad &&
        _engine.activeTelegraphedNodes.any((n) => n.column == col && n.row == row);

    SpatialTelegraphIntent? activeIntentOnCell;
    if (isTelegraphed) {
      for (final enemy in _engine.enemyUnits.where((u) => u.isAlive && u.pendingIntent != null)) {
        if (enemy.pendingIntent!.targetNodes.any((n) => n.column == col && n.row == row)) {
          activeIntentOnCell = enemy.pendingIntent;
          break;
        }
      }
    }

    // Multi-node behemoth anchor check: Gorgoroth occupies 2 tiles; render model only on anchor node (col 1, row 0)
    final bool isAnchorCell = occupant == null ||
        (occupant.occupiedNodes.first.column == col && occupant.occupiedNodes.first.row == row);
    final bool isBossSecondaryNode = occupant != null && !isAnchorCell;

    // Movement & Formation Swap validation for selected unit
    final selectedUnit = _selectedUnitId != null
        ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull
        : null;
    final int deployedCount = _engine.playerUnits.where((u) => u.isAlive && u.occupiedNodes.isNotEmpty).length;
    final bool canSelectedRelocate = selectedUnit != null &&
        !selectedUnit.isDisplacementImmune &&
        col >= 0 &&
        col <= 2 &&
        row >= 0 &&
        row <= 2 &&
        !selectedUnit.occupies(col, row);
    final bool isReachable = isPlayerSquad &&
        canSelectedRelocate &&
        occupant == null &&
        (selectedUnit.occupiedNodes.isNotEmpty || deployedCount < _engine.maxDeployableUnits);
    final bool isSwappable = isPlayerSquad &&
        canSelectedRelocate &&
        occupant != null &&
        occupant.id != selectedUnit.id &&
        !occupant.isDisplacementImmune;

    final bool isSelected = (isPlayerSquad && _selectedUnitId != null && occupant?.id == _selectedUnitId) ||
        (!isPlayerSquad && _selectedEnemyUnitId != null && occupant?.id == _selectedEnemyUnitId);

    // Tactical Ultimate AOE Highlight Overlay calculation:
    final activeUltimateUnitId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
    bool isSpellAoeAffected = false;
    if (activeUltimateUnitId != null && _hoveredTileGRow != null && _hoveredTileCol != null) {
      final affectedList = _getUltimateAffectedGridCells(activeUltimateUnitId, _hoveredTileGRow!, _hoveredTileCol!);
      isSpellAoeAffected = affectedList.any((c) => c.gRow == gRow && c.col == col);
    }

    // Ghost / X-Ray Mode:
    // If a unit is standing in front of another occupied unit or reachable tile along isometric depth,
    // or if a unit behind is selected, give the foreground unit subtle ghost transparency (0.42 opacity)
    // so background units like the ghoul are never obscured!
    bool isOccluding = false;
    if (occupant != null && !isSelected) {
      if (isPlayerSquad) {
        if (_selectedUnitId != null) {
          final sel = _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull;
          if (sel != null && sel.occupiedNodes.isNotEmpty && sel.occupiedNodes.first.row > row && sel.occupiedNodes.first.column == col) {
            isOccluding = true;
          }
        }
      } else {
        if (row < 2) {
          final hasUnitBehind = _engine.enemyUnits.any((u) => u.isAlive && u.id != occupant.id && u.occupies(col, row + 1));
          if (hasUnitBehind) {
            isOccluding = true;
          }
        }
      }
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.startsWith('ultimate:')) {
          if (_hoveredTileGRow != gRow || _hoveredTileCol != col) {
            setState(() {
              _hoveredTileGRow = gRow;
              _hoveredTileCol = col;
            });
          }
          final unitId = data.replaceFirst('ultimate:', '');
          final ultUnit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
          final isSupportUlt = unitId == 'iron_footman' ||
              (ultUnit != null && (ultUnit.templateId.contains('medicus') || ultUnit.templateId.contains('priestess') || ultUnit.templateId.contains('alchemist')));
          if (isSupportUlt) return isPlayerSquad;
          return !isPlayerSquad; // Valeria, Sanguine, Sun-Smith, and offensive roster ultimates target enemy grid/units
        } else if (data.startsWith('card:')) {
          if (_hoveredTileGRow != gRow || _hoveredTileCol != col) {
            setState(() {
              _hoveredTileGRow = gRow;
              _hoveredTileCol = col;
            });
          }
          final cardId = data.replaceFirst('card:', '');
          final card = _engine.hand.where((c) => c.id == cardId).firstOrNull;
          if (card == null) return false;
          // Buff cards target living allies
          if (card.id == 'phalanx_intercept') {
            return isPlayerSquad && occupant != null;
          }
          // Stoke the embers can be dropped anywhere
          if (card.id == 'stoke_the_embers') return true;
          // Offensive spells can target living enemies OR empty enemy tiles if it's an AoE/splash spell
          final isAoeOrSplash = card.pattern != TargetPattern.singleTarget || card.id == 'searing_brand';
          if (isAoeOrSplash) {
            return !isPlayerSquad; // Can target any tile on enemy squad, empty or occupied
          }
          return !isPlayerSquad && occupant != null;
        } else {
          // Unit movement & formation swap triage: allow if in player squad, unoccupied or swappable ally, and within unit moveRange
          if (_hoveredTileGRow != gRow || _hoveredTileCol != col) {
            setState(() {
              _hoveredTileGRow = gRow;
              _hoveredTileCol = col;
            });
          }
          final unitId = data.replaceFirst('unit:', '');
          final unit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
          if (unit == null) return false;
          final bool canEnterOrSwap = occupant == null || (occupant.id != unit.id && !occupant.isDisplacementImmune);
          final int deployedCount = _engine.playerUnits.where((u) => u.isAlive && u.occupiedNodes.isNotEmpty).length;
          final bool withinCap = unit.occupiedNodes.isNotEmpty || occupant != null || deployedCount < _engine.maxDeployableUnits;
          return isPlayerSquad && canEnterOrSwap && withinCap && col >= 0 && col <= 2 && row >= 0 && row <= 2 && !unit.occupies(col, row);
        }
      },
      onLeave: (_) {
        if (_hoveredTileGRow == gRow && _hoveredTileCol == col) {
          setState(() {
            _hoveredTileGRow = null;
            _hoveredTileCol = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.startsWith('ultimate:')) {
          final unitId = data.replaceFirst('ultimate:', '');
          _engine.castUltimate(unitId, targetUnit: occupant, targetCol: col, targetRow: row);
          setState(() {
            _draggedUltimateUnitId = null;
            _selectedUltimateUnitId = null;
            _hoveredTileGRow = null;
            _hoveredTileCol = null;
          });
        } else if (data.startsWith('card:')) {
          final cardId = data.replaceFirst('card:', '');
          _engine.castCard(cardId, targetUnit: occupant, targetCol: col, targetRow: row);
          setState(() {
            _hoveredTileGRow = null;
            _hoveredTileCol = null;
          });
        } else {
          final unitId = data.replaceFirst('unit:', '');
          _engine.movePlayerUnit(unitId, col, row);
          setState(() {
            _selectedUnitId = unitId; // Keep unit selected so updated trajectory line displays!
            _hoveredTileGRow = null;
            _hoveredTileCol = null;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool isDropCandidate = candidateData.isNotEmpty;

        final Color fillColor = isSpellAoeAffected
            ? const Color(0xFFFFD54F).withValues(alpha: 0.28)
            : (isTelegraphed
                ? const Color(0xFFFF1744).withValues(alpha: 0.35)
                : (isDropCandidate
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.28)
                    : (isReachable
                        ? const Color(0xFF00E676).withValues(alpha: 0.25)
                        : (isSwappable
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                            : (isBossSecondaryNode
                                ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                                : (isPlayerSquad
                                    ? const Color(0xFF304FFE).withValues(alpha: 0.12)
                                    : const Color(0xFFFF1744).withValues(alpha: 0.10)))))));

        final Color borderColor = isSpellAoeAffected
            ? const Color(0xFFFFD54F).withValues(alpha: 0.95)
            : (isTelegraphed
                ? const Color(0xFFFF1744).withValues(alpha: 0.90)
                : (isDropCandidate
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.85)
                    : (isReachable
                        ? const Color(0xFF00E676).withValues(alpha: 0.85)
                        : (isSwappable
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.70)
                            : (isSelected
                                ? const Color(0xFFFFD54F)
                                : (isBossSecondaryNode
                                    ? const Color(0xFFFF8A80).withValues(alpha: 0.35)
                                    : (isPlayerSquad
                                        ? const Color(0xFF82B1FF).withValues(alpha: 0.38)
                                        : const Color(0xFFFF8A80).withValues(alpha: 0.32))))))));

        final bool isNecroticMire = isPlayerSquad && _engine.necroticMireNodes.any((n) => n.column == col && n.row == row);
        final bool hasGlow = isSpellAoeAffected || isTelegraphed || isSelected || isDropCandidate || isReachable || isSwappable || isNecroticMire;
        final Color glowColor = isNecroticMire
            ? const Color(0xFF00E676)
            : (isSpellAoeAffected
                ? const Color(0xFFFFD54F)
                : (isTelegraphed
                    ? const Color(0xFFFF1744)
                    : (isReachable
                        ? const Color(0xFF00E676)
                        : (isDropCandidate || isSwappable ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F)))));

        return SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: CustomPaint(
            painter: IsometricDiamondTilePainter(
              fillColor: fillColor,
              borderColor: borderColor,
              borderWidth: hasGlow ? 2.0 : 1.1,
              hasGlow: hasGlow,
              glowColor: glowColor,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Necrotic Mire Corrupted Ground Glow & Floating Badge
                if (isNecroticMire) ...[
                  Center(
                    child: Container(
                      width: tileWidth * 0.70,
                      height: tileHeight * 0.70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.45),
                        boxShadow: const [
                          BoxShadow(color: Color(0x6600E676), blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xEE1B5E20),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF69F0AE), width: 0.8),
                        ),
                        child: const Text(
                          '☣️ MIASMA (-15)',
                          style: TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF69F0AE),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // Glowing Arcane Spell Magic Circle Projection (when targeted by Ultimate AOE)
                if (isSpellAoeAffected)
                  Center(
                    child: Opacity(
                      opacity: 0.65,
                      child: Image.asset(
                        'assets/images/Spells/Attack_spell_magic_circle.png',
                        width: tileWidth * 0.90,
                        height: tileHeight * 0.90,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                // Turn-Triage Ghost Preview: Translucent silhouette & pulsing base when hovered during unit drag
                if (isPlayerSquad &&
                    _draggedUnitId != null &&
                    _hoveredTileGRow == gRow &&
                    _hoveredTileCol == col)
                  Builder(
                    builder: (context) {
                      final dragged = _engine.playerUnits.where((u) => u.id == _draggedUnitId && u.isAlive).firstOrNull;
                      if (dragged == null) return const SizedBox.shrink();
                      final bool canMove = dragged.canMoveTo(col, row, ignoreApCost: _engine.isPreBattlePhase);
                      if (!canMove) return const SizedBox.shrink();

                      final bool originInDanger = dragged.occupiedNodes.any((n) =>
                          _engine.activeTelegraphedNodes.any((tn) => tn.column == n.column && tn.row == n.row));
                      final bool targetInDanger = _engine.activeTelegraphedNodes.any((tn) => tn.column == col && tn.row == row);
                      final Color ghostAuraColor = (originInDanger && !targetInDanger)
                          ? const Color(0xFF00E676)
                          : (occupant != null ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF));

                      return Center(
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Pulsing Plinth Placement Aura
                            Container(
                              width: tileWidth * 0.72,
                              height: tileHeight * 0.72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: ghostAuraColor.withValues(alpha: 0.9), width: 1.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: ghostAuraColor.withValues(alpha: 0.55),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            // Translucent Ghost Silhouette of unit
                            Opacity(
                              opacity: 0.52,
                              child: Image.asset(
                                dragged.assetPath,
                                height: tileHeight * 1.35,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: ghostAuraColor, size: 28),
                              ),
                            ),
                            // Action Tag Pill
                            Positioned(
                              top: -12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xEE0B1019),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: ghostAuraColor, width: 1.0),
                                ),
                                child: Text(
                                  originInDanger && !targetInDanger
                                      ? '🛡️ SAFE FOOTING'
                                      : (occupant != null ? '⇄ SWAP' : (_engine.isPreBattlePhase ? 'DEPLOY' : '50% AP')),
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                    color: ghostAuraColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Reachable Movement Indicator / Move Button for Empty Cells
                if (isReachable)
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final movedUnitId = selectedUnit.id;
                        _engine.movePlayerUnit(movedUnitId, col, row);
                        setState(() {
                          _selectedUnitId = movedUnitId;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_run, color: Color(0xFF00E676), size: 14),
                            const SizedBox(width: 2),
                            Text(
                              _engine.isPreBattlePhase ? 'DEPLOY' : 'MOVE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00E676).withValues(alpha: 0.95),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Secondary Behemoth Footprint Marker (2x2 extension of Gorgoroth)
                if (isBossSecondaryNode)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFFF8A80),
                        size: 14,
                      ),
                    ),
                  ),

                // Multi-Node Secondary Cell Tap Handler: forward card/spell directly to the occupying unit
                if (occupant != null && (occupant.occupiedNodes.length > 1 || occupant.footprint != UnitFootprint.single1x1))
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          if (isPlayerSquad) {
                            _selectedUnitId = (_selectedUnitId == occupant.id) ? null : occupant.id;
                            _selectedEnemyUnitId = null;
                          } else {
                            _selectedEnemyUnitId = (_selectedEnemyUnitId == occupant.id) ? null : occupant.id;
                            _selectedUnitId = null;
                          }
                        });
                      },
                    ),
                  ),

                // Empty Tile Tap Handler (fallback when no unit on cell)
                if (occupant == null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (isPlayerSquad && selectedUnit != null) {
                          if (selectedUnit.canMoveTo(col, row, ignoreApCost: _engine.isPreBattlePhase)) {
                            final movedId = selectedUnit.id;
                            _engine.movePlayerUnit(movedId, col, row);
                            setState(() => _selectedUnitId = movedId);
                          } else {
                            setState(() {
                              _engine.lastBannerMessage =
                                  '⚠️ ${selectedUnit.name} can only move ${selectedUnit.moveRange} tile(s)!';
                            });
                          }
                        }
                      },
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, left: 3),
                          child: Text(
                            '${col + 1},$row',
                            style: TextStyle(
                              fontSize: 8.0,
                              color: isTelegraphed
                                  ? const Color(0xFFFF8A80)
                                  : (isReachable ? const Color(0xFF00E676) : Colors.white12),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Occupant Miniature (Rendered on Anchor node for 1x1 units; Behemoths render centered on the board overlay)
                if (occupant != null && isAnchorCell && occupant.occupiedNodes.length <= 1 && occupant.footprint == UnitFootprint.single1x1)
                  Builder(
                    builder: (context) {
                      final activeUltId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
                      String? phantomEffect;
                      if (activeUltId != null && (_hoveredTileGRow != null || _selectedUltimateUnitId != null)) {
                        phantomEffect = _getPhantomUltimateEffect(occupant, activeUltId, _hoveredTileGRow ?? gRow, _hoveredTileCol ?? col);
                      }

                      return Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isOccluding ? 0.38 : 1.0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isPlayerSquad) {
                                setState(() {
                                  _selectedUnitId = (_selectedUnitId == occupant.id) ? null : occupant.id;
                                  _selectedEnemyUnitId = null;
                                });
                              } else {
                                setState(() {
                                  _selectedEnemyUnitId = (_selectedEnemyUnitId == occupant.id) ? null : occupant.id;
                                  _selectedUnitId = null;
                                });
                              }
                            },
                            child: isPlayerSquad
                                ? Draggable<String>(
                                    data: 'unit:${occupant.id}',
                                    maxSimultaneousDrags: 1,
                                    onDragStarted: () {
                                      setState(() {
                                        _draggedUnitId = occupant.id;
                                        _selectedUnitId = occupant.id;
                                        _selectedEnemyUnitId = null;
                                      });
                                      if (!_engine.isPreBattlePhase) {
                                        _engine.setBulletTime(true);
                                      }
                                    },
                                    onDragEnd: (_) {
                                      setState(() {
                                        _draggedUnitId = null;
                                      });
                                      if (!_engine.isPreBattlePhase) {
                                        _engine.setBulletTime(false);
                                      }
                                    },
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: _buildUnitMiniatureWidget(
                                        occupant,
                                        tileWidth: tileWidth,
                                        tileHeight: tileHeight,
                                        colGap: colGap,
                                        isDragging: true,
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: _buildUnitMiniatureWidget(
                                        occupant,
                                        tileWidth: tileWidth,
                                        tileHeight: tileHeight,
                                        colGap: colGap,
                                      ),
                                    ),
                                    child: _buildUnitMiniatureWidget(
                                      occupant,
                                      tileWidth: tileWidth,
                                      tileHeight: tileHeight,
                                      colGap: colGap,
                                      isSelected: isSelected,
                                      phantomEffect: phantomEffect,
                                    ),
                                  )
                                : MouseRegion(
                                    onEnter: (_) {
                                      if (_hoveredEnemyUnitId != occupant.id) {
                                        setState(() => _hoveredEnemyUnitId = occupant.id);
                                      }
                                    },
                                    onExit: (_) {
                                      if (_hoveredEnemyUnitId == occupant.id) {
                                        setState(() => _hoveredEnemyUnitId = null);
                                      }
                                    },
                                    child: _buildUnitMiniatureWidget(
                                      occupant,
                                      tileWidth: tileWidth,
                                      tileHeight: tileHeight,
                                      colGap: colGap,
                                      isSelected: isSelected,
                                      phantomEffect: phantomEffect,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),

                // Tactical Formation Swap Pill on occupied allied tiles
                if (isSwappable)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final movedId = selectedUnit.id;
                          _engine.movePlayerUnit(movedId, col, row);
                          setState(() {
                            _selectedUnitId = movedId;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xEE071E26),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            '⇄ SWAP',
                            style: TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00E5FF),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Live Windup Countdown & Progress Bar for Telegraphed Enemy Strikes
                if (isTelegraphed)
                  Positioned(
                    bottom: 2,
                    right: 4,
                    left: 4,
                    child: activeIntentOnCell != null
                        ? Builder(
                            builder: (context) {
                              final intent = activeIntentOnCell!;
                              final remTicks = max(0, intent.triggerTick - _engine.currentTick);
                              final remSec = (remTicks / 30.0).toStringAsFixed(1);
                              final progress = (1.0 - (remTicks / max(1, intent.totalWindupTicks))).clamp(0.0, 1.0);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xDD3E0810),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: const Color(0xFFFF5252), width: 0.8),
                                    ),
                                    child: Text(
                                      '⚠️ ${remSec}s',
                                      style: const TextStyle(
                                        fontSize: 7.0,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFF8A80),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF1744),
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(Icons.close, color: Color(0xFFFF5252), size: 14),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTacticalPromptBanner() {
    String message = _engine.lastBannerMessage ?? '';
    Color themeColor = const Color(0xFFFFD54F);
    IconData icon = Icons.info_outline;

    if (_engine.isPreBattlePhase) {
      if (_draggedUnitId != null) {
        final unit = _engine.playerUnits.where((u) => u.id == _draggedUnitId && u.isAlive).firstOrNull;
        final name = unit?.name.toUpperCase() ?? 'UNIT';
        message = '📍 DEPLOYING $name: Drop onto any blue glowing tile on your 3x5 grid! (Or drop on another unit to [⇄ SWAP])';
        themeColor = const Color(0xFF00E5FF);
        icon = Icons.touch_app;
      } else if (_selectedUnitId != null) {
        final unit = _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull;
        if (unit != null) {
          final isPlaced = unit.occupiedNodes.isNotEmpty;
          message = isPlaced
              ? '🎯 PRE-BATTLE: Drag or click any glowing tile to reposition/swap ${unit.name.toUpperCase()} • Drag to bottom dock to bench!'
              : '📍 BENCH UNIT: Drag ${unit.name.toUpperCase()} from the reserve dock onto any grid tile to deploy!';
          themeColor = const Color(0xFF00E5FF);
          icon = Icons.gps_fixed;
        }
      } else if (_selectedEnemyUnitId != null) {
        final enemy = _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull;
        if (enemy != null) {
          return _buildSelectedEnemyInspectionBanner(enemy);
        }
      } else {
        final unplacedCount = _engine.playerUnits.where((u) => u.isAlive && u.occupiedNodes.isEmpty).length;
        final bool isFirstFight = _engine.skillTreeState.allSkills.values.where((s) => s.isUnlocked).length <= 1 && _engine.skillTreeState.availableSkillPoints == 0;
        if (unplacedCount > 0) {
          message = '🛡️ PRE-BATTLE: Drag units from the Reserve Dock into place on the grid, then tap [ENGAGE BATTLE]!';
        } else if (_engine.skillTreeState.availableSkillPoints > 0) {
          message = '✨ SKILL POINT READY (+${_engine.skillTreeState.availableSkillPoints}★): Open [SKILL TREE] below (or [SKILLS] above) to unlock a new Skill Slot before engaging!';
        } else if (isFirstFight) {
          message = '📘 FIRST BATTLE GUIDE: Hover Skill Slot [1] below to read Siphon Rend, drag your hero to position, then tap [ENGAGE BATTLE]!';
        } else {
          message = '🛡️ SQUAD READY: Drag units across lanes to position, hover Skill Slots below for tooltips, or tap [ENGAGE BATTLE]!';
        }
        themeColor = _engine.skillTreeState.availableSkillPoints > 0 ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F);
        icon = _engine.skillTreeState.availableSkillPoints > 0 ? Icons.auto_fix_high : Icons.touch_app;
      }
    } else if (_draggedUltimateUnitId != null || _selectedUltimateUnitId != null) {
      final ultUnitId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
      final unit = _engine.playerUnits.where((u) => u.id == ultUnitId && u.isAlive).firstOrNull;
      if (unit != null) {
        final ultName = unit.ultimateTitle;
        message = '⚡ ULTIMATE ARMED: ${unit.name.toUpperCase()} [$ultName] • Drop on grid target to unleash!';
        themeColor = const Color(0xFFFFD54F);
        icon = Icons.bolt;
      }
    } else if (_draggedUnitId != null) {
      final unit = _engine.playerUnits.where((u) => u.id == _draggedUnitId && u.isAlive).firstOrNull;
      if (unit != null) {
        final apPct = (unit.currentAp / SpatialCombatEngine.tickThreshold * 100).round();
        final bool originInDanger = unit.occupiedNodes.any((n) =>
            _engine.activeTelegraphedNodes.any((tn) => tn.column == n.column && tn.row == n.row));

        if (_hoveredTileCol != null && _hoveredTileGRow != null && _hoveredTileGRow! > 3) {
          final targetCol = _hoveredTileCol!;
          final targetRow = _hoveredTileGRow! - 4;
          final bool hoveredInDanger = _engine.activeTelegraphedNodes.any((tn) => tn.column == targetCol && tn.row == targetRow);
          final bool canMove = unit.canMoveTo(targetCol, targetRow, ignoreApCost: _engine.isPreBattlePhase);

          if (originInDanger && !hoveredInDanger && canMove) {
            message = '🛡️ TURN-TRIAGE: EVADING DANGER ZONE! Drop to secure safe footing (${_engine.isPreBattlePhase ? "Free Deploy" : "Costs 50% AP"})';
            themeColor = const Color(0xFF00E676);
            icon = Icons.verified_user;
          } else if (hoveredInDanger && canMove) {
            message = '⚠️ WARNING: Target tile is inside an active enemy strike zone!';
            themeColor = const Color(0xFFFF5252);
            icon = Icons.warning_amber_rounded;
          } else if (canMove) {
            final occupantAlly = _engine.playerUnits.where((u) => u.isAlive && u.id != unit.id && u.occupies(targetCol, targetRow)).firstOrNull;
            if (occupantAlly != null) {
              message = '⇄ FORMATION SWAP: Drop on ${occupantAlly.name.toUpperCase()} to swap positions (${_engine.isPreBattlePhase ? "Free Deploy" : "Costs 50% AP"})';
              themeColor = const Color(0xFFFFD54F);
              icon = Icons.swap_horiz;
            } else {
              message = '⚡ REPOSITIONING: Drop on tile ($targetCol, $targetRow) (${_engine.isPreBattlePhase ? "Free Deploy" : "Costs 50% AP"})';
              themeColor = const Color(0xFF00E5FF);
              icon = Icons.directions_run;
            }
          } else {
            message = '⛔ OUT OF RANGE: ${unit.name.toUpperCase()} can only move ${unit.moveRange} tile(s)!';
            themeColor = const Color(0xFFFF5252);
            icon = Icons.block;
          }
        } else {
          if (originInDanger) {
            message = '🚨 DANGER: ${unit.name.toUpperCase()} is targeted by an incoming strike! Drag to a safe tile to EVADE!';
            themeColor = const Color(0xFFFF5252);
            icon = Icons.crisis_alert;
          } else {
            message = '🔄 TURN-TRIAGE: Dragging ${unit.name.toUpperCase()} (AP: $apPct%) • Drop on adjacent tile (${_engine.isPreBattlePhase ? "Free Deploy" : "Costs 50% AP"})';
            themeColor = const Color(0xFF00E5FF);
            icon = Icons.open_with;
          }
        }
      }
    } else if (_selectedUnitId != null) {
      final unit = _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull;
      if (unit != null) {
        final apPct = (unit.currentAp / SpatialCombatEngine.tickThreshold * 100).round();
        if (unit.canAffordMovement) {
          message = '⚔️ ${unit.name.toUpperCase()} (AP: $apPct%): Drag to an open tile or tap [SHIFT] to reposition (Costs 50% AP).';
          themeColor = const Color(0xFF00E676);
          icon = Icons.directions_run;
        } else {
          message = '⚠️ ${unit.name.toUpperCase()} (AP: $apPct%): Needs 50% AP to reposition!';
          themeColor = const Color(0xFFFF9100);
          icon = Icons.hourglass_top;
        }
      }
    } else if (_selectedEnemyUnitId != null) {
      final enemy = _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull;
      if (enemy != null) {
        return _buildSelectedEnemyInspectionBanner(enemy);
      }
    } else if (message.isEmpty && _engine.isRunning) {
      final sculptor = _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;
      final bool isFirstFight = _engine.skillTreeState.allSkills.values.where((s) => s.isUnlocked).length <= 1;
      final bool hasReadySkill = sculptor != null &&
          _engine.skillTreeState.equippedSkillIds.any((id) {
            if (id.isEmpty) return false;
            final node = _engine.skillTreeState.allSkills[id];
            return node != null && sculptor.crucibleCinders >= node.cinderCost && _engine.skillTreeState.getCooldownRemaining(id) <= 0.01;
          });
      if (_engine.skillTreeState.availableSkillPoints > 0) {
        message = '💡 +${_engine.skillTreeState.availableSkillPoints}★ SKILL POINT READY: Open [SKILLS] above (or [TREE] below) to unlock new Skill Slots & Ranks!';
        themeColor = const Color(0xFF69F0AE);
        icon = Icons.auto_fix_high;
      } else if (hasReadySkill && _engine.currentTick < 480) {
        message = isFirstFight
            ? '📘 STEP 2 — CAST YOUR SKILL: Click glowing [SIPHON REND] below (or press 1) to deal damage, heal, and generate Cinders (🔥)!'
            : '💡 SKILL READY: Tap a glowing Skill Slot below (or press 1–5) to cast — hover any slot for details!';
        themeColor = const Color(0xFFFFD54F);
        icon = Icons.flash_on;
      } else if (_engine.currentTick < 300) {
        message = isFirstFight
            ? '📘 STEP 1 — AUTO-STRIKES & CINDERS: Your hero attacks automatically to build Cinders (🔥). Drag your hero to dodge or click an enemy to inspect!'
            : '💡 COMBAT TIP: Basic strikes build Cinders (0–100) for Skills. Click any enemy to inspect its target, or drag allies to reposition.';
        themeColor = const Color(0xFF00E5FF);
        icon = Icons.lightbulb_outline;
      }
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101018).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: themeColor.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: themeColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedUnitId != null || _selectedEnemyUnitId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedUnitId = null;
                  _selectedEnemyUnitId = null;
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, color: Colors.white70, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillCutInBanner() {
    final Color themeColor = _isPlayerSkillBanner ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);
    final caster = _activeSkillCaster;
    final String? assetPath = caster?.assetPath;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: themeColor, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.50),
              blurRadius: 16,
              spreadRadius: 1.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Caster Miniature Portrait Thumbnail (if available)
            if (assetPath != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(color: themeColor.withValues(alpha: 0.4), blurRadius: 6),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Icon(
                    _isPlayerSkillBanner ? Icons.shield : Icons.security,
                    color: themeColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Arcane Rotating Magic Circle Glyph
            Image.asset(
              _isPlayerSkillBanner
                  ? 'assets/images/Spells/Support_spell_magic_circle.png'
                  : 'assets/images/Spells/Attack_spell_magic_circle.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => Icon(
                _isPlayerSkillBanner ? Icons.auto_awesome : Icons.warning_rounded,
                color: themeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),

            // Caster Name Badge
            Text(
              _activeSkillCasterName?.toUpperCase() ?? 'CONSTRUCT',
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),

            // Skill Name Banner with Glowing Text
            Text(
              _activeSkillName?.toUpperCase() ?? 'ATTACK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
                shadows: [
                  Shadow(color: themeColor.withValues(alpha: 0.8), blurRadius: 8),
                  const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dramatic In-Combat Ultimate Burst Cut-In Overlay
  Widget _buildUltimateCinematicOverlay(CombatUnitState unit) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true, // Visual cut-in must not swallow underlying clicks
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                const Color(0xFF2E1A0A).withValues(alpha: 0.88),
                const Color(0xFF0F0B06).withValues(alpha: 0.94),
                Colors.black.withValues(alpha: 0.97),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // 1. Radiant Background Arcane Spell Circles
              Center(
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset(
                    'assets/images/Spells/Support_spell_magic_circle.png',
                    width: 380,
                    height: 380,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // 2. High-energy Gold / Crimson Diagonal Slash Banner Backing
              Center(
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFFB8860B).withValues(alpha: 0.25),
                        const Color(0xFFFFD54F).withValues(alpha: 0.40),
                        const Color(0xFFB8860B).withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.75),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Main Center Cut-In Content: Hero Portrait Miniature + Title Banner
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero Miniature Portrait Frame with Golden Halo
                      Container(
                        width: 140,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD54F),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.9),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              unit.assetPath,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Color(0xFFFFD54F),
                                size: 64,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                color: Colors.black.withValues(alpha: 0.75),
                                child: Text(
                                  unit.name.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                    letterSpacing: 0.8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Ultimate Header & Description
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "⚡ ULTIMATE BURST ⚡" Header Pip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFFF5252),
                                  width: 1.2,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'APEX ULTIMATE BURST',
                                    style: TextStyle(
                                      color: Color(0xFFFFE082),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Ultimate Name
                            Text(
                              unit.ultimateTitle.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFD54F),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Battle Cry Chant
                            Text(
                              unit.battleChant,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Ultimate Flavor & Tactical Effect
                            Text(
                              unit.ultimateDescription,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dramatic In-Combat Signature Skill Spotlight Cut-In Banner (Pauses all AP generation while watching skill)
  Widget _buildSignatureSkillCinematicBanner(CombatUnitState unit, String skillName) {
    final Color accentColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);
    return Positioned(
      top: 18,
      left: 24,
      right: 24,
      child: IgnorePointer(
        ignoring: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF141022).withValues(alpha: 0.96),
                    const Color(0xFF281838).withValues(alpha: 0.96),
                    const Color(0xFF141022).withValues(alpha: 0.96),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.55),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor, width: 1.4),
                      color: Colors.black54,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      unit.assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => Icon(Icons.stars_rounded, color: accentColor, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_filled, color: accentColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '★ SIGNATURE SKILL UNLEASHED • AP TIME-FREEZE ★',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unit.name.toUpperCase()} — ${skillName.replaceAll('★ ', '').toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unit.battleChant,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unit.signatureSkillDescription,
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // =========================================================================
  // TACTICAL HEALTH BAR, STATUS BADGES & INSPECTION TOOLTIP HELPERS
  // =========================================================================

  List<UnitStatusBadgeData> _getUnitStatusBadges(CombatUnitState unit) {
    final list = <UnitStatusBadgeData>[];

    // 1. Bleed
    if (unit.bleedStacks > 0) {
      list.add(UnitStatusBadgeData(
        id: 'bleed',
        name: 'Bleed',
        icon: '🩸',
        summary: 'x${unit.bleedStacks}',
        detail: 'Bleed (x${unit.bleedStacks}): Sanguine hemorrhage. Suffers bleed damage on its next action.',
        color: const Color(0xFFFF5252),
        bg: const Color(0xFF38080E),
        isBuff: false,
      ));
    }

    // 2. Poison
    if (unit.poisonStacks > 0) {
      final penalty = (unit.poisonStacks * 2).clamp(0, 40);
      list.add(UnitStatusBadgeData(
        id: 'poison',
        name: 'Poison',
        icon: '🧪',
        summary: 'x${unit.poisonStacks}',
        detail: 'Poison (x${unit.poisonStacks}): Necrotic rot. -$penalty% ATK & SPD; takes true damage over time.',
        color: const Color(0xFF69F0AE),
        bg: const Color(0xFF072412),
        isBuff: false,
      ));
    }

    // 3. Burn
    if (unit.burnDuration > 0) {
      final sec = (unit.burnDuration / 30.0).toStringAsFixed(1);
      list.add(UnitStatusBadgeData(
        id: 'burn',
        name: 'Burn',
        icon: '🔥',
        summary: '${sec}s',
        detail: 'Burn (${sec}s): Scorching embers. Searing periodic fire damage.',
        color: const Color(0xFFFF9100),
        bg: const Color(0xFF2C1400),
        isBuff: false,
      ));
    }

    // 4. Freeze
    if (unit.freezeDuration > 0) {
      final sec = (unit.freezeDuration / 30.0).toStringAsFixed(1);
      list.add(UnitStatusBadgeData(
        id: 'freeze',
        name: 'Freeze',
        icon: '❄️',
        summary: '${sec}s',
        detail: 'Freeze (${sec}s): Solid permafrost. Incapacitated; physical strikes shatter for +15% max HP bonus damage.',
        color: const Color(0xFF80D8FF),
        bg: const Color(0xFF0A2230),
        isBuff: false,
      ));
    }

    // 5. Stun
    if (unit.stunDuration > 0) {
      final sec = (unit.stunDuration / 30.0).toStringAsFixed(1);
      list.add(UnitStatusBadgeData(
        id: 'stun',
        name: 'Stun',
        icon: '⚡',
        summary: '${sec}s',
        detail: 'Stun (${sec}s): Concussed. Action Points and Turn Meter are completely frozen.',
        color: const Color(0xFFFFD54F),
        bg: const Color(0xFF292005),
        isBuff: false,
      ));
    }

    // 6. Vulnerable
    if (unit.vulnerableDuration > 0) {
      final sec = (unit.vulnerableDuration / 30.0).toStringAsFixed(1);
      list.add(UnitStatusBadgeData(
        id: 'vulnerable',
        name: 'Vulnerable',
        icon: '🎯',
        summary: '+25%',
        detail: 'Vulnerable (${sec}s): Defenses breached. Takes +25% increased damage from all attacks.',
        color: const Color(0xFFEA80FC),
        bg: const Color(0xFF280B2E),
        isBuff: false,
      ));
    }

    // 7. Haste
    if (unit.hasteDuration > 0) {
      final sec = (unit.hasteDuration / 30.0).toStringAsFixed(1);
      list.add(UnitStatusBadgeData(
        id: 'haste',
        name: 'Haste',
        icon: '💨',
        summary: '+35%',
        detail: 'Haste (${sec}s): Kinetic velocity. +35% AP accumulation speed.',
        color: const Color(0xFF00E5FF),
        bg: const Color(0xFF03222B),
        isBuff: true,
      ));
    }

    // 8. Aegis Shield
    if (unit.aegisShield > 0) {
      list.add(UnitStatusBadgeData(
        id: 'aegis',
        name: 'Aegis Shield',
        icon: '🛡️',
        summary: '${unit.aegisShield}',
        detail: 'Aegis Barrier: Radiant kinetic ward absorbs the next ${unit.aegisShield} damage before HP is harmed.',
        color: const Color(0xFF00E5FF),
        bg: const Color(0xFF00222D),
        isBuff: true,
      ));
    }

    // 9. Armor
    if (unit.armor > 0) {
      list.add(UnitStatusBadgeData(
        id: 'armor',
        name: 'Armor Plating',
        icon: '🛡️',
        summary: '${unit.armor}',
        detail: 'Armor (${unit.armor}): Physical plating directly mitigating incoming basic attacks and skills.',
        color: const Color(0xFFB0BEC5),
        bg: const Color(0xFF1E272C),
        isBuff: true,
      ));
    }

    // 10. Stagger (Boss)
    if (unit.isStaggered) {
      list.add(const UnitStatusBadgeData(
        id: 'stagger',
        name: 'Staggered',
        icon: '💥',
        summary: 'BROKEN',
        detail: 'Staggered: Break bar shattered! Unit is immobilized and suffers 150% critical damage.',
        color: Color(0xFFFFD54F),
        bg: Color(0xFF332600),
        isBuff: false,
      ));
    }

    // 11. Slag Carapace (Boss)
    if (unit.isSlagCarapaceActive) {
      list.add(const UnitStatusBadgeData(
        id: 'carapace',
        name: 'Slag Carapace',
        icon: '🌋',
        summary: 'CARAPACE',
        detail: 'Slag Carapace: Molten volcanic coating significantly reducing non-critical strikes.',
        color: Color(0xFFFF7043),
        bg: Color(0xFF331408),
        isBuff: true,
      ));
    }

    // 12. Kinetic Bastion
    if (unit.isKineticBastionActive && unit.kineticBastionCharges > 0) {
      list.add(UnitStatusBadgeData(
        id: 'kinetic',
        name: 'Kinetic Bastion',
        icon: '⚡',
        summary: '${unit.kineticBastionCharges}',
        detail: 'Kinetic Bastion (${unit.kineticBastionCharges}/${unit.maxKineticBastionCharges}): Stored kinetic charges for counter-strike.',
        color: const Color(0xFFFFD54F),
        bg: const Color(0xFF2C2405),
        isBuff: true,
      ));
    }

    // 13. Petrified Plinth
    if (unit.isPetrifiedPlinth) {
      list.add(UnitStatusBadgeData(
        id: 'plinth',
        name: 'Petrified Plinth',
        icon: '🪨',
        summary: '${unit.plinthDurability}/3',
        detail: 'Petrified Plinth: Downed unit petrified into solid stone (${unit.plinthDurability}/3 hits remaining to shatter).',
        color: const Color(0xFF90A4AE),
        bg: const Color(0xFF1C2429),
        isBuff: false,
      ));
    }

    return list;
  }

  InlineSpan _buildUnitTooltipSpan(CombatUnitState unit) {
    final bool isEnemy = !unit.isPlayer;
    final factionColor = isEnemy ? const Color(0xFFFF5252) : const Color(0xFF69F0AE);
    final int hpPercent = unit.maxHp > 0 ? ((unit.hp / unit.maxHp) * 100).round() : 0;
    final int apPercent = ((unit.currentAp / SpatialCombatEngine.tickThreshold) * 100).round().clamp(0, 100);
    final int killDmg = unit.hp;
    final int totalEhp = unit.ehp.round();

    final badges = _getUnitStatusBadges(unit);

    return TextSpan(
      children: [
        // 1. Header
        TextSpan(
          text: '${unit.name.toUpperCase()}\n',
          style: TextStyle(
            color: factionColor,
            fontWeight: FontWeight.w900,
            fontSize: 12.0,
            letterSpacing: 0.6,
          ),
        ),
        TextSpan(
          text: '${isEnemy ? "Enemy" : "Allied"} ${unit.archetype.name} • Lv.${unit.level} • ${unit.currentDepth.name.toUpperCase()} ROW\n',
          style: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const TextSpan(text: '────────────────────────────\n', style: TextStyle(color: Colors.white24, fontSize: 8)),

        // 2. Kill Assessment / Health Status
        if (isEnemy) ...[
          TextSpan(
            text: '🎯 DAMAGE NEEDED TO KILL: $killDmg Direct HP\n',
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
            ),
          ),
          TextSpan(
            text: '   • Current HP: ${unit.hp} / ${unit.maxHp} ($hpPercent%)\n'
                '   • Armor Plating: ${unit.armor} (Total EHP: $totalEhp)\n'
                '${unit.aegisShield > 0 ? "   • Aegis Barrier: ${unit.aegisShield} damage absorption\n" : ""}',
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 9.5,
              height: 1.35,
            ),
          ),
        ] else ...[
          TextSpan(
            text: '💚 VITAL STATUS: ${unit.hp} / ${unit.maxHp} HP ($hpPercent%)\n',
            style: const TextStyle(
              color: Color(0xFF69F0AE),
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
            ),
          ),
          TextSpan(
            text: '   • Armor: ${unit.armor} / ${unit.maxArmor}\n'
                '${unit.aegisShield > 0 ? "   • Aegis Shield: ${unit.aegisShield}\n" : ""}',
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 9.5,
              height: 1.35,
            ),
          ),
        ],

        // 3. Combat Stats
        TextSpan(
          text: '⚔️ Attack: ${unit.effectiveAttack}  •  ⚡ Speed: ${unit.effectiveSpeed}  •  ⏱️ Turn Meter: $apPercent%\n',
          style: const TextStyle(
            color: Color(0xFF81D4FA),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),

        // 4. Status Effects
        const TextSpan(text: '────────────────────────────\n', style: TextStyle(color: Colors.white24, fontSize: 8)),
        if (badges.isEmpty) ...[
          const TextSpan(
            text: '✨ Status: Normal (No active afflictions or buffs)\n',
            style: TextStyle(color: Colors.white70, fontSize: 9.0, fontStyle: FontStyle.italic),
          ),
        ] else ...[
          const TextSpan(
            text: 'ACTIVE BUFFS & DEBUFFS:\n',
            style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 9.5),
          ),
          for (final b in badges)
            TextSpan(
              text: '${b.icon} ${b.detail}\n',
              style: TextStyle(
                color: b.color,
                fontSize: 9.0,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],

        // 5. Intent (if enemy)
        if (!unit.isPlayer && unit.pendingIntent != null) ...[
          const TextSpan(text: '────────────────────────────\n', style: TextStyle(color: Colors.white24, fontSize: 8)),
          TextSpan(
            text: '⚔️ INCOMING SKILL: ${unit.pendingIntent!.skillName.toUpperCase()}\n'
                '   Striking in ${((unit.pendingIntent!.triggerTick - _engine.currentTick).clamp(0, 9999) / 30.0).toStringAsFixed(1)}s '
                '(${unit.pendingIntent!.targetSummary})\n',
            style: const TextStyle(
              color: Color(0xFFFF8A80),
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverheadStatusBadgesRow(List<UnitStatusBadgeData> badges) {
    final displayBadges = badges.take(5).toList();
    final overflowBadges = badges.skip(5).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0810).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in displayBadges)
            Tooltip(
              message: '[${b.isBuff ? "BUFF" : "DEBUFF"}] ${b.name.toUpperCase()}: ${b.detail}',
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0B14).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: b.color, width: 1.0),
                boxShadow: [
                  BoxShadow(color: b.color.withValues(alpha: 0.35), blurRadius: 6),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: b.bg.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(3.5),
                  border: Border.all(
                    color: b.isBuff ? const Color(0xFF00E676).withValues(alpha: 0.85) : const Color(0xFFFF5252).withValues(alpha: 0.9),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(color: b.color.withValues(alpha: 0.35), blurRadius: 3),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.icon, style: const TextStyle(fontSize: 8.5)),
                    const SizedBox(width: 2.0),
                    Text(
                      b.summary,
                      style: TextStyle(
                        color: b.color,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (overflowBadges.isNotEmpty)
            Tooltip(
              message: overflowBadges.map((b) => '• [${b.isBuff ? "BUFF" : "DEBUFF"}] ${b.name}: ${b.detail}').join('\n'),
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0B14).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
              ),
              child: Container(
                margin: const EdgeInsets.only(left: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1728),
                  borderRadius: BorderRadius.circular(3.5),
                  border: Border.all(color: Colors.white38, width: 0.8),
                ),
                child: Text(
                  '+${overflowBadges.length}',
                  style: const TextStyle(fontSize: 7.0, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverheadHealthBar(
    CombatUnitState unit, {
    required bool isBoss,
    required double tileWidth,
    required bool isSelected,
  }) {
    final int displayHp = _visualUnitHp[unit.id] ?? unit.hp;
    final bool visuallyPetrified = unit.isPetrifiedPlinth && !_visualAliveOverrideIds.contains(unit.id);
    final bool visuallyDowned = unit.isDowned && !_visualAliveOverrideIds.contains(unit.id);
    final double hpRatio = unit.maxHp > 0 ? (displayHp / unit.maxHp).clamp(0.0, 1.0) : 0.0;
    final double apRatio = (unit.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
    final double barWidth = isBoss ? 144.0 : (tileWidth * 1.05).clamp(96.0, 122.0);
    final bool isEnemy = !unit.isPlayer;
    final bool isReadyToAct = apRatio >= 1.0;

    String hpLabel;
    if (visuallyPetrified) {
      hpLabel = '🪨 ${unit.plinthDurability}/3';
    } else if (visuallyDowned) {
      hpLabel = '💀 DOWNED';
    } else if (isEnemy) {
      final String shieldTag = unit.aegisShield > 0 ? ' +${unit.aegisShield}🛡️' : '';
      if (unit.armor > 0) {
        hpLabel = '🎯 $displayHp$shieldTag [🛡️${unit.armor}]';
      } else {
        hpLabel = '🎯 $displayHp/${unit.maxHp}$shieldTag';
      }
    } else {
      final String shieldTag = unit.aegisShield > 0 ? ' +${unit.aegisShield}🛡️' : '';
      if (unit.armor > 0) {
        hpLabel = '💚 $displayHp$shieldTag [🛡️${unit.armor}]';
      } else {
        hpLabel = '💚 $displayHp/${unit.maxHp}$shieldTag';
      }
    }

    return Container(
      width: barWidth,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0912).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD54F)
              : (isEnemy
                  ? const Color(0xFFFF5252).withValues(alpha: 0.85)
                  : const Color(0xFF00E676).withValues(alpha: 0.85)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFFD54F).withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.8),
            blurRadius: isSelected ? 8 : 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Main HP & Armor Bar with Segment Notches (25%, 50%, 75%)
          Container(
            height: isBoss ? 15.0 : 13.0,
            decoration: BoxDecoration(
              color: const Color(0xFF1C0E12),
              borderRadius: BorderRadius.circular(2.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ghost Damage Trail (eases down smoothly from previous HP% so big hits read crisply)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: hpRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECB3).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),

                // Health Bar Gradient Fill
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: hpRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEnemy
                            ? [const Color(0xFF7F0000), const Color(0xFFC62828), const Color(0xFFFF5252)]
                            : [const Color(0xFF004D20), const Color(0xFF00A844), const Color(0xFF69F0AE)],
                      ),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),

                // Aegis Shield Overlay Bar (Distinct luminous cyan-blue bar across top edge of HP bar)
                if (unit.aegisShield > 0)
                  Align(
                    alignment: Alignment.topLeft,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (unit.aegisShield / max(1, unit.maxHp)).clamp(0.08, 1.0),
                      child: Container(
                        height: isBoss ? 5.5 : 4.5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF80D8FF), Color(0xFFE1F5FE)],
                          ),
                          borderRadius: BorderRadius.circular(2.0),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 0.6),
                          boxShadow: const [
                            BoxShadow(color: Color(0xCC00E5FF), blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Tactical Segment Notches (Quarter-HP damage dividers: 25%, 50%, 75%)
                for (final notch in [0.25, 0.50, 0.75])
                  Align(
                    alignment: Alignment(notch * 2 - 1, 0),
                    child: Container(
                      width: 1.0,
                      height: double.infinity,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),

                // Numerical Health & Armor Text with High-Contrast Dual Shadows
                Center(
                  child: Text(
                    hpLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isBoss ? 9.5 : 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      fontFamily: 'monospace',
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, -1)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 1.5),

          // 2. AP Turn Meter (Action Readiness Gauge with 50% Reposition Notch)
          Container(
            height: 3.5,
            decoration: BoxDecoration(
              color: const Color(0xFF141018),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: Stack(
              children: [
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 115),
                  curve: Curves.linear,
                  alignment: Alignment.centerLeft,
                  widthFactor: apRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isReadyToAct
                            ? [const Color(0xFFFFD54F), const Color(0xFFFFF9C4)]
                            : [const Color(0xFFFF8F00), const Color(0xFFFFD54F)],
                      ),
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: isReadyToAct
                          ? const [BoxShadow(color: Color(0xFFFFD54F), blurRadius: 5, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                ),
                // 50% Reposition Threshold Notch
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 1.0,
                    height: double.infinity,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEnemyInspectionBanner(CombatUnitState enemy) {
    final double hpRatio = enemy.maxHp > 0 ? (enemy.hp / enemy.maxHp).clamp(0.0, 1.0) : 0.0;
    final int apPct = (enemy.currentAp / SpatialCombatEngine.tickThreshold * 100).round().clamp(0, 100);
    final badges = _getUnitStatusBadges(enemy);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF160B0E).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.85), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x33FF1744), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.radar, color: Color(0xFFFF5252), size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TARGET: ${enemy.name.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFFF8A80),
                  fontWeight: FontWeight.w900,
                  fontSize: 11.0,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${enemy.archetype.name} • Row ${enemy.currentDepth.name.toUpperCase()} • ${enemy.effectiveSpeed} SPD ($apPct% TM)',
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF230D12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.5), width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🎯 ${enemy.hp} HP TO KILL',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.0,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        '${enemy.hp} / ${enemy.maxHp} HP  •  🛡️ ${enemy.armor} ARMOR',
                        style: const TextStyle(
                          color: Color(0xFFFFCCBC),
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 5,
                      color: Colors.black45,
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpRatio,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFB71C1C), Color(0xFFFF1744)],
                                ),
                              ),
                            ),
                          ),
                          if (enemy.armor > 0)
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (enemy.armor / max(1, enemy.maxHp)).clamp(0.0, 1.0),
                              child: Container(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          if (badges.isNotEmpty) ...[
            _buildOverheadStatusBadgesRow(badges),
            const SizedBox(width: 8),
          ],

          GestureDetector(
            onTap: () {
              setState(() {
                _selectedEnemyUnitId = null;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitMiniatureWidget(
    CombatUnitState unit, {
    required double tileWidth,
    required double tileHeight,
    required double colGap,
    bool isDragging = false,
    bool isSelected = false,
    String? phantomEffect,
  }) {
    final bool isBoss = unit.occupiedNodes.length > 1 || unit.footprint != UnitFootprint.single1x1;
    final bool visuallyDowned = unit.isDowned && !_visualAliveOverrideIds.contains(unit.id);
    final Color factionColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isLunging = _lungingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id || _damagedUnitIds.contains(unit.id);
    final bool isRecoiling = isDamaged || _recoilingUnitIds.contains(unit.id);
    final String? floatingPop = _unitFloatingPops[unit.id];

    // Directional strike lunge angled toward target lane, followed by smooth ease-out recovery
    final double lungeY = _is2DGridView
        ? (isLunging ? _lungeTargetDeltaY : 0.0)
        : (isLunging ? (unit.isPlayer ? -14.0 : 14.0) : 0.0);
    final double lungeX = _is2DGridView && isLunging ? (unit.isPlayer ? 26.0 : -26.0) : 0.0;
    // Decoupled smooth knockback recoil when absorbing a hit
    final double hitRecoilX = isRecoiling ? (unit.isPlayer ? -18.0 : 18.0) : 0.0;
    final double hitShakeY = isRecoiling ? -4.5 : 0.0;

    // Normalization multipliers:
    // Valeria's sprite fills 100% of her canvas, whereas Footman, Ghoul, Sanguine Blade have
    // transparent padding. We scale Valeria to 0.88 so her physical figure matches the 1:1 footprint of the others!
    double unitScaleMultiplier = 1.0;
    final path = unit.assetPath.toLowerCase();
    if (unit.isAshSculptor || unit.id == 'ash_sculptor' || path.contains('ash_sculptor')) {
      unitScaleMultiplier = 1.18; // Heroic commander scale
    } else if (unit.id == 'lady_valeria' || path.contains('valeria')) {
      unitScaleMultiplier = 0.95; // Crisp full-bleed canvas
    } else if (path.contains('ghoul')) {
      unitScaleMultiplier = 1.15; // Low crouch
    } else if (path.contains('alchemist')) {
      // 2752x1536 wide canvas with narrow 31% center content; scale up so figure matches standard height!
      unitScaleMultiplier = 1.65;
    } else if (path.contains('sentinel') || path.contains('juggernaut') || path.contains('inquisitor') || path.contains('footman')) {
      unitScaleMultiplier = 1.10;
    } else if (path.contains('sanguine_flayer') || path.contains('blade') || path.contains('scourge') || path.contains('vladislav')) {
      unitScaleMultiplier = 1.05;
    } else if (path.contains('sun_smith') || path.contains('scribe') || path.contains('priestess')) {
      unitScaleMultiplier = 1.10;
    } else if (path.contains('cinder_witch') || path.contains('blood_initiate') || path.contains('sorcerer') || path.contains('archon') || path.contains('matron')) {
      unitScaleMultiplier = 1.15;
    } else if (path.contains('warhound') || path.contains('golem')) {
      unitScaleMultiplier = 1.15;
    }

    final double bossSpanWidth = isBoss ? (tileWidth * 2.3) : tileWidth;
    final double baseWidth = isBoss ? bossSpanWidth * 0.70 : (tileWidth - 12) * unitScaleMultiplier;
    final double baseHeight = isBoss ? 38 : (16 * unitScaleMultiplier);
    // Units scale dynamically with tile size for commanding visual presence
    // Elegant Grand battlefield stage proportions:
    // Slightly enlarged characters stand handsomely grounded on their plinths with heroic presence!
    final double modelWidth = (isBoss ? bossSpanWidth * 1.15 : tileWidth * 1.08 * unitScaleMultiplier).clamp(52.0, 300.0);
    final double modelHeight = (isBoss
        ? (tileHeight * 2.9).clamp(160.0, 320.0)
        : (tileHeight * 1.62 * unitScaleMultiplier).clamp(58.0, 175.0));

    return SizedBox(
      width: isBoss ? bossSpanWidth : tileWidth,
      height: isBoss ? modelHeight : tileHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedScale(
            scale: isLunging ? 1.08 : (isRecoiling ? 0.94 : 1.0),
            duration: Duration(milliseconds: isLunging ? 135 : 210),
            curve: isLunging ? Curves.easeOutBack : Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: Duration(milliseconds: isLunging ? 140 : 230),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(hitRecoilX + lungeX, lungeY + hitShakeY, 0),
              child: SizedBox(
              width: isBoss ? bossSpanWidth : tileWidth,
              height: isBoss ? modelHeight : tileHeight,
              child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. Tabletop Miniature Carved Runic Plinth
            // In 2D Grid view, rank_and_rite_2d_battlefield owns and renders the grounded stone base,
            // so we suppress this duplicate plinth when _is2DGridView is true to avoid double stacked circles.
            if (!_is2DGridView)
              Positioned(
                bottom: 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Beveled Plinth Ring & Deep Contact Shadow
                    Container(
                      width: baseWidth,
                      height: baseHeight + (_is2DGridView ? 4 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.elliptical(baseWidth / 2, (baseHeight + (_is2DGridView ? 4 : 0)) / 2)),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.15),
                          radius: 0.9,
                          colors: unit.isDowned
                              ? [
                                  const Color(0xFF546E7A).withValues(alpha: 0.50),
                                  const Color(0xFF263238),
                                  Colors.transparent,
                                ]
                              : [
                                  (unit.isAshSculptor || unit.id == 'ash_sculptor')
                                      ? const Color(0xFF4A3414).withValues(alpha: 0.85)
                                      : (unit.isPlayer ? const Color(0xFF142938).withValues(alpha: 0.85) : const Color(0xFF381418).withValues(alpha: 0.85)),
                                  const Color(0xFF0C0A10).withValues(alpha: 0.95),
                                  Colors.transparent,
                                ],
                        ),
                        border: Border.all(
                          color: unit.isDowned
                              ? const Color(0xFF90A4AE).withValues(alpha: 0.6)
                              : ((unit.isAshSculptor || unit.id == 'ash_sculptor')
                                  ? const Color(0xFFFFD54F)
                                  : factionColor.withValues(alpha: isSelected || isAttacking ? 0.95 : 0.75)),
                          width: isSelected || isAttacking ? 2.0 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: unit.isDowned
                                ? const Color(0xFF37474F).withValues(alpha: 0.4)
                                : ((unit.isAshSculptor || unit.id == 'ash_sculptor')
                                    ? const Color(0xFFFFD54F).withValues(alpha: isSelected || isAttacking ? 0.65 : 0.35)
                                    : factionColor.withValues(alpha: isSelected || isAttacking ? 0.65 : 0.25)),
                            blurRadius: isSelected || isAttacking ? 12 : 6,
                            spreadRadius: isSelected || isAttacking ? 2 : 0,
                          ),
                          if (unit.aegisShield > 0)
                            const BoxShadow(
                              color: Color(0xCC00E5FF),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                        ],
                      ),
                    ),
                    // Inner Concentric Carved Stone Lip
                    Container(
                      width: baseWidth * 0.78,
                      height: (baseHeight + (_is2DGridView ? 4 : 0)) * 0.65,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.elliptical(baseWidth * 0.39, (baseHeight + (_is2DGridView ? 4 : 0)) * 0.325)),
                        border: Border.all(
                          color: (unit.isAshSculptor || unit.id == 'ash_sculptor')
                              ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
                              : factionColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1b. Ground plinth in rank_and_rite_2d_battlefield cleanly handles active unit rim/glow.
            // Redundant second yellow circle removed per user request for visual clarity.

            // 2. Character Model Miniature Cutout (Stands proudly upright on diamond plinth)
            Positioned(
              bottom: visuallyDowned ? 2 : 6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: visuallyDowned ? 0.68 : 1.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: visuallyDowned ? 0.94 : 1.0,
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    width: modelWidth,
                    height: modelHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Main Character Sprite (with side-aware facing mirror + Stone Petrification / Hit-Flash color filter)
                        Positioned.fill(
                          child: Transform.flip(
                            flipX: _shouldMirrorUnitSprite(unit),
                            child: ColorFiltered(
                          colorFilter: visuallyDowned
                              ? const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 10,
                                  0.2126, 0.7152, 0.0722, 0, 10,
                                  0.2126, 0.7152, 0.0722, 0, 14,
                                  0,      0,      0,      0.82, 0,
                                ]) // GDD §3.6 / §4.3: True petrified grey stone plinth
                              : (isDamaged
                                  ? ColorFilter.mode(
                                      (floatingPop != null && floatingPop.contains('CRIT'))
                                          ? const Color(0xEEFFFFFF) // Blinding white crit flash
                                          : const Color(0xDDFF5722), // Fiery molten impact flash
                                      BlendMode.srcATop,
                                    )
                                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst)),
                          child: (isAttacking && (unit.isAshSculptor || unit.id == 'ash_sculptor' || unit.assetPath.toLowerCase().contains('ash_sculptor')))
                              ? (_engine.skillTreeState.activeClass == SculptorClassArchetype.ironcladWarden
                                  ? OverflowBox(
                                      maxWidth: modelHeight * 1.5,
                                      maxHeight: modelHeight,
                                      alignment: Alignment.bottomCenter,
                                      child: SpriteSheetAnimation(
                                        assetPath: (_attackingSkillName != null &&
                                                _attackingSkillName!.isNotEmpty &&
                                                _attackingSkillName != 'Basic Attack' &&
                                                _attackingSkillName != 'Attack')
                                            ? 'assets/images/Ash sculpter/ironclad warden skill.png'
                                            : 'assets/images/Ash sculpter/ironclad warden attack.png',
                                        columns: 3,
                                        rows: 2,
                                        totalFrames: 6,
                                        duration: Duration(milliseconds: _scaledMs(750)),
                                        loop: false,
                                        fit: BoxFit.contain,
                                        fallback: Image.asset(unit.assetPath, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
                                      ),
                                    )
                                  : (_engine.skillTreeState.activeClass == SculptorClassArchetype.bloodAlchemist
                                      ? OverflowBox(
                                          maxWidth: modelHeight * 1.5,
                                          maxHeight: modelHeight,
                                          alignment: Alignment.bottomCenter,
                                          child: SpriteSheetAnimation(
                                            assetPath: (_attackingSkillName != null &&
                                                    _attackingSkillName!.isNotEmpty &&
                                                    _attackingSkillName != 'Basic Attack' &&
                                                    _attackingSkillName != 'Attack')
                                                ? 'assets/images/Ash sculpter/blood alchemist skill cast.png'
                                                : 'assets/images/Ash sculpter/blood alchemist attack animation.png',
                                            columns: 4,
                                            rows: 3,
                                            totalFrames: 12,
                                            duration: Duration(milliseconds: _scaledMs(1050)),
                                            loop: false,
                                            fit: BoxFit.contain,
                                            fallback: Image.asset(unit.assetPath, fit: BoxFit.contain, alignment: Alignment.bottomCenter),
                                          ),
                                        )
                                      : (_attackingSkillName == 'Obsidian Bastion'
                                          ? SpriteSheetAnimation(
                                              assetPath: 'assets/animations/ash_sculptor_defend_sheet.png',
                                              columns: 3,
                                              rows: 2,
                                              totalFrames: 6,
                                              duration: Duration(milliseconds: _scaledMs(850)),
                                              loop: false,
                                              fit: BoxFit.contain,
                                              fallback: Image.asset(
                                                'assets/images/ash_sculptor_shield_burst.png',
                                                fit: BoxFit.contain,
                                                alignment: Alignment.bottomCenter,
                                              ),
                                            )
                                          : OverflowBox(
                                              maxWidth: modelHeight * 1.5,
                                              maxHeight: modelHeight,
                                              alignment: Alignment.bottomCenter,
                                              child: SpriteSheetAnimation(
                                                assetPath: 'assets/animations/ash_sculptor_attack_sheet.png',
                                                columns: 3,
                                                rows: 2,
                                                totalFrames: 6,
                                                duration: Duration(milliseconds: _scaledMs(900)),
                                                loop: false,
                                                fit: BoxFit.contain,
                                                fallback: Image.asset(
                                                  unit.assetPath,
                                                  fit: BoxFit.contain,
                                                  alignment: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ))))
                              : (isDamaged &&
                                      _engine.skillTreeState.activeClass == SculptorClassArchetype.forgeBerserker &&
                                      (unit.isAshSculptor || unit.id == 'ash_sculptor' || unit.assetPath.toLowerCase().contains('ash_sculptor')))
                                  ? SpriteSheetAnimation(
                                      assetPath: 'assets/animations/ash_sculptor_defend_sheet.png',
                                      columns: 3,
                                      rows: 2,
                                      totalFrames: 6,
                                      duration: Duration(milliseconds: _scaledMs(650)),
                                      loop: false,
                                      fit: BoxFit.contain,
                                      fallback: Image.asset(
                                        'assets/images/ash_sculptor_hit.png',
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                      ),
                                    )
                                  : (isAttacking && (unit.id == 'lady_valeria' || unit.assetPath.toLowerCase().contains('valeria')))
                                  ? SpriteSheetAnimation(
                                      assetPath: 'assets/animations/valeria_slash_sheet.png',
                                      columns: 3,
                                      rows: 2,
                                      totalFrames: 6,
                                      duration: Duration(milliseconds: _scaledMs(1050)),
                                      loop: false,
                                      fit: BoxFit.contain,
                                      fallback: Image.asset(
                                        unit.assetPath,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                      ),
                                    )
                              : (unit.isPlayer &&
                                      !visuallyDowned &&
                                      (unit.isAshSculptor ||
                                          unit.id == 'ash_sculptor' ||
                                          unit.templateId == 'ash_sculptor' ||
                                          unit.templateId.contains('sculptor') ||
                                          unit.name.contains('Sculptor') ||
                                          unit.assetPath.toLowerCase().contains('ash_sculptor') ||
                                          unit.assetPath.toLowerCase().contains('sculptor')))
                                  ? (_engine.skillTreeState.activeClass == SculptorClassArchetype.ironcladWarden
                                      ? SpriteSheetAnimation(
                                          assetPath: 'assets/images/Ash sculpter/ironclad warden idle.png',
                                          columns: 3,
                                          rows: 2,
                                          totalFrames: 6,
                                          duration: const Duration(milliseconds: 2400),
                                          loop: true,
                                          fit: BoxFit.contain,
                                          fallback: Image.asset(
                                            'assets/images/ash_sculptor_idle.png',
                                            fit: BoxFit.contain,
                                            alignment: Alignment.bottomCenter,
                                          ),
                                        )
                                      : (_engine.skillTreeState.activeClass == SculptorClassArchetype.bloodAlchemist
                                          ? SpriteSheetAnimation(
                                              assetPath: 'assets/images/Ash sculpter/blood alchemist idle.png',
                                              columns: 4,
                                              rows: 3,
                                              totalFrames: 12,
                                              duration: const Duration(milliseconds: 2400),
                                              loop: true,
                                              fit: BoxFit.contain,
                                              fallback: Image.asset(
                                                'assets/images/ash_sculptor_idle.png',
                                                fit: BoxFit.contain,
                                                alignment: Alignment.bottomCenter,
                                              ),
                                            )
                                          : SpriteSheetAnimation(
                                              assetPath: 'assets/animations/ash_sculptor_idle_sheet.png',
                                              columns: 3,
                                              rows: 2,
                                              totalFrames: 6,
                                              duration: const Duration(milliseconds: 2400),
                                              loop: true,
                                              fit: BoxFit.contain,
                                              fallback: Image.asset(
                                                'assets/images/ash_sculptor_idle.png',
                                                fit: BoxFit.contain,
                                                alignment: Alignment.bottomCenter,
                                              ),
                                            )))
                              : _buildResolvedUnitSprite(
                                  unit,
                                  isAttacking: isAttacking,
                                  visuallyDowned: visuallyDowned,
                                  isDragging: isDragging,
                                  isBoss: isBoss,
                                  modelWidth: modelWidth,
                                  modelHeight: modelHeight,
                                  factionColor: factionColor,
                                ),
                            ),
                          ),
                        ),

                        // Hit Impact Highlight Glow so players immediately see who took each damage number
                        if (isDamaged)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFFF5252).withValues(alpha: 0.45),
                                      const Color(0xFFFF9100).withValues(alpha: 0.22),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Ash Dissolve Floating Embers for Downed / Inert Vessels
                        if (unit.isDowned)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _AshEmbersDissolvePainter(
                                  timestampMs: DateTime.now().millisecondsSinceEpoch,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Status Badges & Selected Unit Indicator (Positioned dynamically above the head of any model)
            // Overhead badges removed to keep hero art completely unobstructed
            // (Floating damage/effect pops are rendered in the non-recoiling overlay sibling below.)

            // 4b. Tactical Spell Drag Hover: Phantom Damage & Effect Indicator Badge
            if (phantomEffect != null && floatingPop == null)
              Positioned(
                bottom: modelHeight + 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140D04).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: phantomEffect.contains('ARMOR')
                          ? const Color(0xFF00E5FF)
                          : (phantomEffect.contains('FOCUS') ? const Color(0xFFFFD54F) : const Color(0xFFFFB300)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        phantomEffect.contains('ARMOR')
                            ? Icons.shield
                            : (phantomEffect.contains('FOCUS') ? Icons.bolt : Icons.flash_on),
                        color: const Color(0xFFFFD54F),
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        phantomEffect,
                        style: const TextStyle(
                          color: Color(0xFFFFE082),
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Overhead Tactical Health & Status HUD Cluster (Expanded Health Bar, Status Badges & Tooltip)
            Positioned(
              bottom: modelHeight + 6,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (unit.isPlayer) {
                    setState(() {
                      _selectedUnitId = (_selectedUnitId == unit.id) ? null : unit.id;
                      _selectedEnemyUnitId = null;
                    });
                  } else {
                    setState(() {
                      _selectedEnemyUnitId = (_selectedEnemyUnitId == unit.id) ? null : unit.id;
                      _selectedUnitId = null;
                    });
                  }
                },
                child: Tooltip(
                  preferBelow: false,
                  verticalOffset: 12,
                  waitDuration: Duration.zero,
                  showDuration: const Duration(seconds: 6),
                  triggerMode: TooltipTriggerMode.tap,
                  richMessage: _buildUnitTooltipSpan(unit),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0B12).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF1744))
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Overhead Target Reticle (for primary focused enemy & cleave targets)
                      if (!unit.isPlayer && unit.isAlive) ...[
                        Builder(
                          builder: (context) {
                            final bool isExplicitTarget = _selectedEnemyUnitId == unit.id;
                            final bool isDefaultTarget = _selectedEnemyUnitId == null && _getSmartDefaultTarget()?.id == unit.id;
                            final bool isCleaveSecondary = _computeProjectedSecondaryTargetEnemyIds().contains(unit.id);

                            if (isExplicitTarget || isDefaultTarget) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 2.5),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isExplicitTarget
                                        ? [const Color(0xFF4A0E17), const Color(0xFF28070D)]
                                        : [const Color(0xFF2A1519), const Color(0xFF1B0B0E)],
                                  ),
                                  borderRadius: BorderRadius.circular(3.5),
                                  border: Border.all(
                                    color: isExplicitTarget ? const Color(0xFFFF1744) : const Color(0xFFFF5252).withValues(alpha: 0.7),
                                    width: isExplicitTarget ? 1.2 : 0.8,
                                  ),
                                  boxShadow: isExplicitTarget
                                      ? [
                                          const BoxShadow(color: Color(0x88FF1744), blurRadius: 7, spreadRadius: 1),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.gps_fixed,
                                      size: 9.5,
                                      color: isExplicitTarget ? const Color(0xFFFF5252) : const Color(0xFFFF8A80),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isExplicitTarget ? 'FOCUS TARGET' : 'TARGET',
                                      style: TextStyle(
                                        fontSize: 7.0,
                                        fontWeight: FontWeight.w900,
                                        color: isExplicitTarget ? const Color(0xFFFFCDD2) : Colors.white70,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (isCleaveSecondary) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 2.5),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF381B08),
                                  borderRadius: BorderRadius.circular(3.5),
                                  border: Border.all(color: const Color(0xFFFF9100), width: 0.9),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x66FF9100), blurRadius: 5),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.call_split, size: 9, color: Color(0xFFFFB74D)),
                                    SizedBox(width: 2.5),
                                    Text(
                                      'CLEAVE SPLASH',
                                      style: TextStyle(
                                        fontSize: 6.8,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFFE0B2),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],

                      // Overhead Intent Badge (Enemy)
                      if (!unit.isPlayer && unit.pendingIntent != null && unit.isAlive) ...[
                        Builder(
                          builder: (context) {
                            final intent = unit.pendingIntent!;
                            final remTicks = (intent.triggerTick - _engine.currentTick).clamp(0, 9999);
                            final remSec = (remTicks / 30.0).toStringAsFixed(1);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xEE380B13),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFF1744), width: 1.0),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x66FF1744), blurRadius: 6, spreadRadius: 1),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⚔️', style: TextStyle(fontSize: 8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${intent.skillName.toUpperCase()} (${remSec}s)',
                                    style: const TextStyle(
                                      fontSize: 7.0,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF8A80),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      // Buff & Debuff Badges Strip
                      Builder(
                        builder: (context) {
                          final badges = _getUnitStatusBadges(unit);
                          if (badges.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2.5),
                            child: _buildOverheadStatusBadgesRow(badges),
                          );
                        },
                      ),

                      // Prominent Tactical Health & AP Bar
                      _buildOverheadHealthBar(
                        unit,
                        isBoss: isBoss,
                        tileWidth: tileWidth,
                        isSelected: isSelected ||
                            (!unit.isPlayer && _selectedEnemyUnitId == unit.id) ||
                            (unit.isPlayer && _selectedUnitId == unit.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Aegis Shield Cast Burst (Centered directly on unit torso during live combat; suppressed in pre-battle)
            if (!_engine.isPreBattlePhase && unit.aegisShield > 0)
              Positioned(
                bottom: visuallyDowned ? 2 : 6,
                width: modelWidth,
                height: modelHeight,
                child: IgnorePointer(
                  child: Builder(
                    builder: (context) {
                      final nowMs = DateTime.now().millisecondsSinceEpoch;
                      final isInitialCasting = unit.shieldAppliedMs > 0 && (nowMs - unit.shieldAppliedMs) < 700;
                      if (!isInitialCasting) return const SizedBox.shrink();

                      final double shieldSize = (modelHeight * 0.95).clamp(72.0, 165.0);
                      return Center(
                        child: OverflowBox(
                          maxWidth: shieldSize,
                          maxHeight: shieldSize,
                          child: SpriteSheetAnimation(
                            assetPath: 'assets/animations/vfx/fire_shield_sheet.png',
                            columns: 3,
                            rows: 3,
                            totalFrames: 9,
                            duration: const Duration(milliseconds: 650),
                            loop: false,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (_activeImpactSlashUnits.containsKey(unit.id))
              Positioned(
                bottom: visuallyDowned ? 2 : 6,
                width: modelWidth,
                height: modelHeight,
                child: IgnorePointer(
                  child: Center(
                    child: OverflowBox(
                      maxWidth: isBoss ? bossSpanWidth * 1.35 : modelWidth * 1.45,
                      maxHeight: isBoss ? modelHeight * 1.25 : modelHeight * 1.35,
                      child: SpriteSheetAnimation(
                        assetPath: _activeImpactSlashUnits[unit.id]!,
                        columns: 3,
                        rows: 3,
                        totalFrames: 9,
                        duration: Duration(milliseconds: _scaledMs(520)),
                        loop: false,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
          ),
          // 4. Non-recoiling Floating Damage / Effect Pop Text (60fps via _visualFrameTick)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _visualFrameTick,
                  builder: (context, _, __) {
                    final activePops = _floatingPops.where((p) => p.unitId == unit.id && !p.isExpired).toList();
                    if (activePops.isEmpty && floatingPop == null) {
                      return const SizedBox.shrink();
                    }
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        ...activePops.map((pop) {
                          final t = pop.progress;
                          final double smoothT = sin(t * 3.14159 / 2);
                          final double riseY = smoothT * 56.0;
                          final double driftX = pop.horizontalDrift * smoothT;
                          final double opacity = t < 0.65 ? 1.0 : (1.0 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0);
                          final double scale = pop.isCrit
                              ? (t < 0.12 ? 1.0 + (t / 0.12) * 0.45 : 1.45 - ((t - 0.12) * 0.35)).clamp(1.10, 1.45)
                              : (t < 0.12 ? 0.90 + (t / 0.12) * 0.25 : 1.15 - ((t - 0.12) * 0.15)).clamp(1.0, 1.15);

                          return Positioned(
                            bottom: modelHeight + 38 + riseY,
                            child: Transform.translate(
                              offset: Offset(driftX, 0),
                              child: Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: pop.isCrit ? 9 : 6.5,
                                    vertical: pop.isCrit ? 3.5 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0A10).withValues(alpha: 0.96),
                                    borderRadius: BorderRadius.circular(pop.isCrit ? 5 : 3.5),
                                    border: Border.all(
                                      color: pop.borderColor,
                                      width: pop.isCrit ? 2.0 : 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: pop.borderColor.withValues(alpha: pop.isCrit ? 0.75 : 0.45),
                                        blurRadius: pop.isCrit ? 12 : 6,
                                        spreadRadius: pop.isCrit ? 2.0 : 0.5,
                                      ),
                                      const BoxShadow(
                                        color: Colors.black87,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    pop.text,
                                    style: TextStyle(
                                      color: pop.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: pop.fontSize,
                                      letterSpacing: pop.isCrit ? 0.9 : 0.4,
                                      fontFamily: 'monospace',
                                      shadows: [
                                        const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                                        if (pop.isCrit)
                                          Shadow(color: pop.borderColor, blurRadius: 8, offset: Offset.zero),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ),
                          );
                        }),
                        if (activePops.isEmpty && floatingPop != null)
                          Positioned(
                            bottom: modelHeight + 36,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: floatingPop.contains('ARMOR')
                                      ? const Color(0xFF00E5FF)
                                      : (floatingPop.contains('FOCUS') ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, blurRadius: 6),
                                ],
                              ),
                              child: Text(
                                floatingPop,
                                style: TextStyle(
                                  color: floatingPop.contains('ARMOR')
                                      ? const Color(0xFF00E5FF)
                                      : (floatingPop.contains('FOCUS') ? const Color(0xFFFFD54F) : const Color(0xFFFF5252)),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _debugUnlockAllRetinueUnits() {
    final activeSpecies = _currentSquadUnits.map((u) => u.speciesId).toSet();
    final reserveSpecies = _reserveUnits.map((u) => u.speciesId).toSet();
    final List<UnitEntity> updatedSquad = List.from(_currentSquadUnits);
    final List<UnitEntity> updatedReserves = List.from(_reserveUnits);
    for (final unit in StarterBrigades.createReserveInventory()) {
      if (!activeSpecies.contains(unit.speciesId) && !reserveSpecies.contains(unit.speciesId)) {
        if (updatedSquad.length < 3) {
          updatedSquad.add(unit);
          activeSpecies.add(unit.speciesId);
        } else {
          updatedReserves.add(unit);
          reserveSpecies.add(unit.speciesId);
        }
      }
    }
    _engine.updateRetinueSquad(updatedSquad, relicService: widget.relicService);
    _engine.lastBannerMessage = '👥 DEV: ALL RETINUE UNITS UNLOCKED!';
    setState(() {
      _currentSquadUnits = updatedSquad;
      _reserveUnits = updatedReserves;
    });
    widget.onSquadUpdated?.call(List<UnitEntity>.unmodifiable(_currentSquadUnits));
  }

  void _openRosterSwapSheet(CombatUnitState? targetUnit) {
    CrucibleRetinueSquadDialog.show(
      context,
      engine: _engine,
      currentSquadUnits: _currentSquadUnits,
      reserveUnits: _reserveUnits,
      relicService: widget.relicService,
      onSquadUpdated: (updatedSquad, updatedReserves) {
        _engine.updateRetinueSquad(updatedSquad, relicService: widget.relicService);
        setState(() {
          _currentSquadUnits = updatedSquad;
          _reserveUnits = updatedReserves;
        });
        widget.onSquadUpdated?.call(List<UnitEntity>.unmodifiable(_currentSquadUnits));
      },
    );
  }

  Widget _buildPresetChip({
    required String label,
    required Color accentColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8.0,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreBattleStagingDock({bool isLandscapeMobile = false}) {
    final livingAllies = _engine.playerUnits.where((u) => u.isAlive).toList();
    final int deployedCount = livingAllies.where((u) => u.occupiedNodes.isNotEmpty).length;
    final int totalCount = livingAllies.length;
    final double dockHeight = isLandscapeMobile ? 48.0 : 78.0;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.startsWith('unit:'),
      onAcceptWithDetails: (details) {
        final unitId = details.data.replaceFirst('unit:', '');
        _engine.undeployUnitToBench(unitId);
        setState(() {
          _selectedUnitId = null;
          _draggedUnitId = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final bool isBenchDropTarget = candidateData.isNotEmpty;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLandscapeMobile ? 3 : 6),
          decoration: BoxDecoration(
            color: isBenchDropTarget
                ? const Color(0xFF1B2A38)
                : const Color(0xFF0F111A),
            border: Border(
              top: BorderSide(
                color: isBenchDropTarget ? const Color(0xFF00E5FF) : const Color(0xFF2A2D3D),
                width: isBenchDropTarget ? 2.0 : 1.2,
              ),
            ),
            boxShadow: isBenchDropTarget
                ? [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Controls Row
              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_work_rounded, color: Color(0xFF00E5FF), size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'RESERVE SQUAD ($deployedCount/${_engine.maxDeployableUnits} MAX • $totalCount OWNED)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Color(0xFF00E5FF),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Actions: Clear to Bench / Auto-Fill
                  GestureDetector(
                    onTap: () {
                      _playSfx('sfx_block.wav');
                      setState(() {
                        _engine.clearAllUnitsToBench();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.undo_rounded, size: 10, color: Colors.white70),
                          SizedBox(width: 3),
                          Text('BENCH ALL', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      _playSfx('sfx_card.wav');
                      setState(() {
                        _engine.autoDeployAllFromBench();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 10, color: Color(0xFF80D8FF)),
                          SizedBox(width: 3),
                          Text('AUTO-DEPLOY', style: TextStyle(fontSize: 8, color: Color(0xFF80D8FF), fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _playSfx('sfx_card.wav');
                        CrucibleRetinueSquadDialog.show(
                          context,
                          engine: _engine,
                          currentSquadUnits: _currentSquadUnits,
                          reserveUnits: _reserveUnits,
                          relicService: widget.relicService,
                          onSquadUpdated: (updatedSquad, updatedReserves) {
                            _engine.updateRetinueSquad(updatedSquad, relicService: widget.relicService);
                            setState(() {
                              _currentSquadUnits = updatedSquad;
                              _reserveUnits = updatedReserves;
                            });
                            widget.onSquadUpdated?.call(List<UnitEntity>.unmodifiable(_currentSquadUnits));
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_add_rounded,
                              size: 11,
                              color: Color(0xFF00E5FF),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '👥 CHOOSE SQUAD',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      _playSfx('sfx_card.wav');
                      CrucibleSkillTreeDialog.show(context, _engine).then((_) {
                        setState(() {});
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162B20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.85),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF69F0AE).withValues(alpha: 0.25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_tree_rounded, size: 11, color: Color(0xFF69F0AE)),
                          const SizedBox(width: 3),
                          Text(
                            _engine.skillTreeState.availableSkillPoints > 0
                                ? 'SKILL TREE (${_engine.skillTreeState.availableSkillPoints}★)'
                                : 'SKILL TREE',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF69F0AE),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        _playSfx('sfx_card.wav');
                        CrucibleDebugSandboxDialog.show(
                          context,
                          engine: _engine,
                          onStateChanged: () => setState(() {}),
                          onUnlockAllUnits: _debugUnlockAllRetinueUnits,
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.build_circle, size: 11, color: Color(0xFFFFD54F)),
                            SizedBox(width: 3),
                            Text(
                              'DEV SANDBOX',
                              style: TextStyle(
                                fontSize: 8,
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _playSfx('sfx_spell.wav');
                      setState(() {
                        _engine.startBattle();
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 15),
                    label: const Text(
                      'ENGAGE BATTLE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      elevation: 3,
                      shadowColor: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              // Active Retinue Passives & Companion Signature Strategy Strip
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF262A3B), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 11, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 5),
                    const Text(
                      'RETINUE SYNERGY:',
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...livingAllies.where((u) => !u.isAshSculptor && u.occupiedNodes.isNotEmpty).map((comp) {
                              return Tooltip(
                                message: '${comp.name}\nPassive: ${comp.retinuePassiveName} (${comp.retinuePassiveSummary})\nSignature: ${comp.signatureSkillName} — ${comp.signatureSkillDescription}',
                                child: Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F2333),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.45), width: 0.7),
                                  ),
                                  child: Text(
                                    '${comp.retinuePassiveName.toUpperCase()} • ★ ${comp.signatureSkillName}',
                                    style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFFFFECB3)),
                                  ),
                                ),
                              );
                            }),
                            if (livingAllies.where((u) => !u.isAshSculptor && u.occupiedNodes.isNotEmpty).isEmpty)
                              const Text(
                                'Deploy companions to activate Retinue Passives & Signature Skills • Frontline blocks column attacks',
                                style: TextStyle(fontSize: 7.5, color: Colors.white54, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_engine.isBossEncounterFlag) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'BOSS:',
                        style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      _buildPresetChip(
                        label: '🗿 GORGOROTH',
                        accentColor: const Color(0xFF00E5FF),
                        tooltip: 'Switch to Gorgoroth the Flayed (Stagger & Break Bar)',
                        onTap: () {
                          _playSfx('sfx_slash.wav');
                          setState(() {
                            _engine.switchBossTrial('gorgoroth');
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildPresetChip(
                        label: '🛡️ MALAKOR',
                        accentColor: const Color(0xFFFFD54F),
                        tooltip: 'Switch to Malakor the Unbroken (Kinetic Bastion & Counter-Tremor)',
                        onTap: () {
                          _playSfx('sfx_block.wav');
                          setState(() {
                            _engine.switchBossTrial('malakor');
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildPresetChip(
                        label: '☣️ MORVATH',
                        accentColor: const Color(0xFF69F0AE),
                        tooltip: 'Switch to Morvath the Defiler (Necrotic Mire & Plague Feast)',
                        onTap: () {
                          _playSfx('sfx_spell.wav');
                          setState(() {
                            _engine.switchBossTrial('morvath');
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Unit Cards Horizontal Carousel + Add Reinforcement Slot
              SizedBox(
                height: dockHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: livingAllies.length + ((livingAllies.length < _engine.maxDeployableUnits && _reserveUnits.isNotEmpty) ? 1 : 0),
                  separatorBuilder: (context, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index < livingAllies.length) {
                      final unit = livingAllies[index];
                      return _buildPreBattleBenchUnitCard(unit, isLandscapeMobile: isLandscapeMobile);
                    }
                    // Plus Card: Open Squad Slot (up to 5 max)
                    return _buildAddHeroBenchCard(isLandscapeMobile: isLandscapeMobile);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Open squad slot "+" card to add a hero from the reserve roster
  Widget _buildAddHeroBenchCard({bool isLandscapeMobile = false}) {
    return GestureDetector(
      onTap: () {
        _playSfx('sfx_card.wav');
        _openRosterSwapSheet(null);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isLandscapeMobile ? 110 : 125,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1520),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF00E5FF),
                size: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '+ ASSIGN ALLY',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00E5FF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${_engine.playerUnits.length}/${_engine.maxDeployableUnits} DEPLOYED',
              style: const TextStyle(
                fontSize: 6.5,
                color: Colors.white54,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual unit card in the Pre-Battle Staging Dock
  Widget _buildPreBattleBenchUnitCard(CombatUnitState unit, {bool isLandscapeMobile = false}) {
    final bool isPlaced = unit.occupiedNodes.isNotEmpty;
    final bool isSelected = _selectedUnitId == unit.id;

    final String placementText = isPlaced
        ? 'COL ${unit.occupiedNodes.first.column + 1} • ${unit.currentDepth == RowDepth.front ? "FRONT" : (unit.currentDepth == RowDepth.mid ? "MID" : "BACK")}'
        : 'DRAG TO GRID';

    final Color statusColor = isPlaced ? const Color(0xFF00E676) : const Color(0xFFFFD54F);

    final Widget cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: isLandscapeMobile ? 120 : 138,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E2838)
            : (isPlaced ? const Color(0xFF131722) : const Color(0xFF1E1A14)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF00E5FF)
              : (isPlaced ? const Color(0xFF2C3E50) : const Color(0xFFFFD54F).withValues(alpha: 0.8)),
          width: isSelected ? 1.8 : (isPlaced ? 1.0 : 1.4),
        ),
        boxShadow: isSelected || !isPlaced
            ? [
                BoxShadow(
                  color: (isSelected ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F)).withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Unit Portrait & Archetype Indicator
          Stack(
            children: [
              Container(
                width: isLandscapeMobile ? 26 : 40,
                height: isLandscapeMobile ? 36 : 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 0.8),
                  color: Colors.black54,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    unit.assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white38, size: 20),
                  ),
                ),
              ),
              // Deployed Checkmark / Unplaced Pulse
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                  child: Icon(
                    isPlaced ? Icons.check : Icons.arrow_upward,
                    size: 8,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),

          // Unit Meta
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: isLandscapeMobile ? 8.0 : 8.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  unit.isAshSculptor
                      ? 'Sovereign Commander'
                      : '${unit.retinuePassiveName} • ★ ${unit.signatureSkillName}',
                  style: const TextStyle(
                    fontSize: 6.8,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFE082),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    Text(
                      'Lv.${unit.level}',
                      style: const TextStyle(fontSize: 6.5, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'HP ${unit.maxHp}',
                      style: const TextStyle(fontSize: 6.5, color: Color(0xFF81C784), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ATK ${unit.attack}',
                      style: const TextStyle(fontSize: 6.5, color: Color(0xFFFF8A80), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 0.5),
                        ),
                        child: Text(
                          placementText,
                          style: TextStyle(
                            fontSize: 6.5,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_reserveUnits.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          _playSfx('sfx_card.wav');
                          _openRosterSwapSheet(unit);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A93C).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.8), width: 0.6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz, size: 8, color: Color(0xFFFFD54F)),
                              SizedBox(width: 1.5),
                              Text(
                                'SWAP',
                                style: TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFD54F),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Draggable<String>(
      data: 'unit:${unit.id}',
      maxSimultaneousDrags: 1,
      rootOverlay: false,
      onDragStarted: () {
        setState(() {
          _draggedUnitId = unit.id;
          _selectedUnitId = unit.id;
          _selectedEnemyUnitId = null;
        });
      },
      onDragEnd: (_) {
        if (!mounted) return;
        setState(() {
          _draggedUnitId = null;
          _hoveredTileGRow = null;
          _hoveredTileCol = null;
        });
      },
      onDraggableCanceled: (_, __) {
        if (!mounted) return;
        setState(() {
          _draggedUnitId = null;
          _hoveredTileGRow = null;
          _hoveredTileCol = null;
        });
      },
      feedback: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: _buildUnitMiniatureWidget(
            unit,
            tileWidth: 88,
            tileHeight: 64,
            colGap: 0,
            isDragging: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardWidget,
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedUnitId = (_selectedUnitId == unit.id) ? null : unit.id;
            _selectedEnemyUnitId = null;
          });
        },
        onLongPress: () {
          _openUnitInspectorDialog(unit);
        },
        child: cardWidget,
      ),
    );
  }

  CombatUnitState? _getSmartDefaultTarget() {
    final livingEnemies = _engine.enemyUnits.where((e) => e.isAlive).toList();
    if (livingEnemies.isEmpty) return null;

    // Priority 1: An enemy currently winding up a dangerous telegraphed strike (interrupt target!)
    final telegraphed = livingEnemies.where((e) => e.pendingIntent != null).firstOrNull;
    if (telegraphed != null) return telegraphed;

    // Priority 2: An enemy with 0 armor (staggered and ripe for lethal damage)
    final staggered = livingEnemies.where((e) => e.maxArmor > 0 && e.armor <= 0).firstOrNull;
    if (staggered != null) return staggered;

    // Priority 3: Lowest absolute current HP target
    livingEnemies.sort((a, b) => a.hp.compareTo(b.hp));
    return livingEnemies.first;
  }

  void _cycleNextEnemyTarget() {
    final livingEnemies = _engine.enemyUnits.where((e) => e.isAlive).toList();
    if (livingEnemies.isEmpty) return;

    if (_selectedEnemyUnitId == null) {
      setState(() {
        _selectedEnemyUnitId = livingEnemies.first.id;
        _engine.focusedEnemyUnitId = _selectedEnemyUnitId;
      });
      return;
    }

    final currentIndex = livingEnemies.indexWhere((e) => e.id == _selectedEnemyUnitId);
    final nextIndex = (currentIndex + 1) % livingEnemies.length;
    setState(() {
      _selectedEnemyUnitId = livingEnemies[nextIndex].id;
      _engine.focusedEnemyUnitId = _selectedEnemyUnitId;
    });
  }

  void _executeHotkeyedAction(String actionType) {
    if (_engine.isPreBattlePhase || _engine.isVictory || _engine.isDefeat || _isForgeStrikeActive) {
      return;
    }
    final unit = _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull ??
        _engine.activeActingUnit;
    if (unit == null || !unit.isAlive) return;
    final explicitTarget = _selectedEnemyUnitId != null
        ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
        : _getSmartDefaultTarget();

    if (unit.isAshSculptor || unit.id == 'ash_sculptor') {
      int? slotIdx;
      if (actionType == 'slot1') slotIdx = 0;
      if (actionType == 'slot2') slotIdx = 1;
      if (actionType == 'slot3') slotIdx = 2;
      if (actionType == 'slot4') slotIdx = 3;
      if (actionType == 'slot5') slotIdx = 4;

      if (slotIdx != null) {
        final skill = _engine.skillTreeState.getSkillInSlot(slotIdx);
        final bool isGenerator = skill != null && skill.cinderCost == 0;
        if (skill == null) return;
        if (!isGenerator && unit.crucibleCinders < skill.cinderCost) {
          setState(() {
            _engine.lastBannerMessage = '🔥 Need ${skill.cinderCost} Cinders for ${skill.name} (have ${unit.crucibleCinders}) — use Slot [1] to build Cinders!';
          });
          return;
        }
        if (skill.cinderCost >= 80 || skill.actionType.contains('cataclysmic') || skill.actionType.contains('pyre') || skill.actionType.contains('wrath') || skill.actionType.contains('exsanguination') || skill.actionType.contains('spore')) {
          _startForgeStrikeFinisher(unit, explicitTarget, actionType: skill.actionType);
        } else {
          setState(() {
            _engine.executeUnitAction(unit, isReposition: false, explicitTarget: explicitTarget, actionType: skill.actionType);
          });
        }
        return;
      }

      final skill = _engine.skillTreeState.allSkills[actionType] ??
          _engine.skillTreeState.allSkills.values.where((s) => s.actionType == actionType).firstOrNull;
      if (skill != null) {
        final bool isGenerator = skill.cinderCost == 0;
        if (!isGenerator && unit.crucibleCinders < skill.cinderCost) return;
        if (skill.cinderCost >= 80 || skill.actionType.contains('cataclysmic') || skill.actionType.contains('pyre') || skill.actionType.contains('wrath') || skill.actionType.contains('exsanguination') || skill.actionType.contains('spore')) {
          _startForgeStrikeFinisher(unit, explicitTarget, actionType: skill.actionType);
        } else {
          setState(() {
            _engine.executeUnitAction(unit, isReposition: false, explicitTarget: explicitTarget, actionType: skill.actionType);
          });
        }
        return;
      }
      return;
    }

    if (actionType == 'signature' && !unit.isSignatureReady) return;
    if (actionType == 'ultimate' && !unit.isUltimateReady) return;

    setState(() {
      _engine.executeUnitAction(
        unit,
        isReposition: false,
        explicitTarget: explicitTarget,
        actionType: actionType,
      );
    });
  }

  KeyEventResult _handleBattleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Keys '1' to '5': Equipped Skill Slots 1 to 5
    if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
      _executeHotkeyedAction('slot1');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
      _executeHotkeyedAction('slot2');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
      _executeHotkeyedAction('slot3');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
      _executeHotkeyedAction('slot4');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
      _executeHotkeyedAction('slot5');
      return KeyEventResult.handled;
    }

    // Key 'K': Open Crucible Skill Tree
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      CrucibleSkillTreeDialog.show(context, _engine).then((_) {
        setState(() {});
      });
      return KeyEventResult.handled;
    }

    // Key 'U': Open Crucible Reforging Sanctuary & Upgrades
    if (event.logicalKey == LogicalKeyboardKey.keyU) {
      CrucibleSanctuaryUpgradeDialog.show(context, _engine).then((_) {
        setState(() {});
      });
      return KeyEventResult.handled;
    }

    // Key 'Tab': Cycle Enemy Target
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _cycleNextEnemyTarget();
      return KeyEventResult.handled;
    }

    // Spacebar: Confirm / Fire Basic Attack
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _executeHotkeyedAction('slot1');
      return KeyEventResult.handled;
    }

    // Key 'T': Cycle Combat Pacing Speed (1.0x -> 1.5x -> 2.0x)
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      setState(() {
        _engine.cycleCombatSpeed();
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Crucible Commander System: Sculptor Commander Action Tray
  Widget _buildSculptorCommanderTray(CombatUnitState unit, {bool isLandscapeMobile = false}) {
    final explicitTarget = _selectedEnemyUnitId != null
        ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
        : _getSmartDefaultTarget();

    final disc = SculptorDisciplineVisuals.forGeneral(_engine.activeGeneralType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 650;
        final bool isApexReady = unit.crucibleCinders >= 80;

        Widget buildCinderMeter() {
          final int curCinders = unit.crucibleCinders;
          final double ratio = (curCinders / 100.0).clamp(0.0, 1.0);
          final bool isApexReady = curCinders >= 80;

          return Container(
            height: isNarrow ? 18 : 22,
            constraints: BoxConstraints(
              minWidth: isNarrow ? 110 : 160,
              maxWidth: isNarrow ? 150 : 220,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF140C0A),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isApexReady ? const Color(0xFFFFD54F) : const Color(0xFFFF6D00).withValues(alpha: 0.9),
                width: isApexReady ? 1.6 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isApexReady
                      ? const Color(0xFFFFD54F).withValues(alpha: 0.5)
                      : const Color(0xFFFF5722).withValues(alpha: 0.3),
                  blurRadius: isApexReady ? 10 : 6,
                  spreadRadius: isApexReady ? 1 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Background track
                  Container(color: const Color(0xFF180F0D)),

                  // Animated Molten Flame Fill
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF880E4F),
                            Color(0xFFD84315),
                            Color(0xFFFF6D00),
                            Color(0xFFFFD54F),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Threshold notches (25, 30, 45, 80)
                  ...[0.25, 0.30, 0.45, 0.80].map((notch) => Align(
                    alignment: Alignment(notch * 2 - 1, 0),
                    child: Container(
                      width: 1.5,
                      height: double.infinity,
                      color: ratio >= notch
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white24,
                    ),
                  )),

                  // Center Label
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: isNarrow ? 11 : 13,
                          color: isApexReady ? const Color(0xFFFFD54F) : const Color(0xFFFFAB40),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$curCinders / 100 CINDERS',
                          style: TextStyle(
                            fontSize: isNarrow ? 8.0 : 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.6,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildActionButton({
          required String title,
          required String subtitle,
          required IconData icon,
          String? iconAsset,
          String? hotkeyLabel,
          CrucibleSkillNode? skill,
          required Color activeColor,
          required Color borderColor,
          required bool isEnabled,
          required double progress,
          required bool isGenerator,
          required bool isFinisher,
          required double cooldownRemaining,
          required VoidCallback? onPressed,
          required String tooltipMessage,
        }) {
          final double slotSize = isNarrow ? 50.0 : 58.0;
          final int cinderYield = (skill?.rank ?? 1) >= 3 ? 26 : ((skill?.rank ?? 1) == 2 ? 22 : 18);

          final richTooltipSpan = skill != null
              ? TextSpan(
                  children: [
                    TextSpan(
                      text: '${skill.name.toUpperCase()}\n',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    TextSpan(
                      text: 'TIER ${skill.tier} • RANK ${skill.rank}/${skill.maxRank} • ${isGenerator ? "CINDER GENERATOR" : (isFinisher ? "APEX FINISHER" : "DISCIPLINE SKILL")}\n',
                      style: TextStyle(
                        color: borderColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Cost: ${isGenerator ? "0 (Yields +$cinderYield🔥)" : "${skill.cinderCost}🔥"} • CD: ${skill.cooldownSeconds.toStringAsFixed(1)}s${hotkeyLabel != null ? " • Key [$hotkeyLabel]" : ""}\n\n',
                      style: const TextStyle(
                        color: Color(0xFFFFCC80),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: skill.currentRankDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                )
              : null;

          return MouseRegion(
            onEnter: skill == null
                ? null
                : (_) {
                    if (_hoveredSkillNode?.id != skill.id) {
                      setState(() => _hoveredSkillNode = skill);
                    }
                  },
            onExit: skill == null
                ? null
                : (_) {
                    if (_hoveredSkillNode?.id == skill.id) {
                      setState(() => _hoveredSkillNode = null);
                    }
                  },
            child: Tooltip(
            preferBelow: false,
            verticalOffset: 14,
            waitDuration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B1824), Color(0xFF100E17)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: borderColor.withValues(alpha: 0.9), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                const BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            richMessage: richTooltipSpan,
            message: richTooltipSpan == null ? tooltipMessage : null,
            child: InkWell(
              onTap: isEnabled ? onPressed : null,
              onTapDown: skill == null
                  ? null
                  : (_) {
                      if (_hoveredSkillNode?.id != skill.id) {
                        setState(() => _hoveredSkillNode = skill);
                      }
                    },
              onTapUp: skill == null
                  ? null
                  : (_) {
                      if (_hoveredSkillNode?.id == skill.id) {
                        setState(() => _hoveredSkillNode = null);
                      }
                    },
              onTapCancel: skill == null
                  ? null
                  : () {
                      if (_hoveredSkillNode?.id == skill.id) {
                        setState(() => _hoveredSkillNode = null);
                      }
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: slotSize,
                height: slotSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF131118),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled
                        ? (isFinisher ? const Color(0xFFFFD54F) : borderColor)
                        : (progress > 0 ? borderColor.withValues(alpha: 0.45) : Colors.white12),
                    width: isEnabled ? (isFinisher ? 2.0 : 1.6) : 1.0,
                  ),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: (isFinisher ? const Color(0xFFFFD54F) : activeColor).withValues(alpha: 0.55),
                            blurRadius: isFinisher ? 12 : 8,
                            spreadRadius: isFinisher ? 1.5 : 0.5,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      // 1. Vertical Molten "Building-Up" Fuel Fill
                      if (progress > 0)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: progress,
                            widthFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    activeColor.withValues(alpha: isEnabled ? 0.50 : 0.25),
                                    activeColor.withValues(alpha: isEnabled ? 0.22 : 0.08),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 2. Glowing Molten Meniscus Line at current charge level
                      if (progress > 0 && progress < 1.0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: (progress * slotSize) - 1.5,
                          child: Container(
                            height: 2.0,
                            decoration: BoxDecoration(
                              color: borderColor.withValues(alpha: 0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: borderColor.withValues(alpha: 0.9),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 3. Centered Skill Icon
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : (progress > 0.4 ? 0.65 : 0.35),
                            child: iconAsset != null
                                ? Image.asset(
                                    iconAsset,
                                    width: slotSize - 14,
                                    height: slotSize - 14,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Icon(
                                      icon,
                                      size: isNarrow ? 22 : 26,
                                      color: isEnabled ? Colors.white : Colors.white38,
                                    ),
                                  )
                                : Icon(
                                    icon,
                                    size: isNarrow ? 22 : 26,
                                    color: isEnabled ? Colors.white : Colors.white38,
                                  ),
                          ),
                        ),
                      ),

                      // 4. Keycap Hotkey Badge (Top-Left)
                      if (hotkeyLabel != null)
                        Positioned(
                          top: 3,
                          left: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0C14).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: isEnabled
                                    ? (isFinisher ? const Color(0xFFFFD54F) : borderColor.withValues(alpha: 0.9))
                                    : Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              hotkeyLabel,
                              style: TextStyle(
                                fontSize: isNarrow ? 7.5 : 8.5,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: isEnabled
                                    ? (isFinisher ? const Color(0xFFFFD54F) : Colors.white)
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),

                      // 5. Compact Cinder Cost / Yield Badge (Bottom-Center)
                      if (cooldownRemaining <= 0.0)
                        Positioned(
                          bottom: 2,
                          left: 3,
                          right: 3,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                isGenerator ? '+$cinderYield🔥' : '${skill?.cinderCost ?? 0}🔥',
                                style: TextStyle(
                                  fontSize: isNarrow ? 7.0 : 8.0,
                                  fontWeight: FontWeight.w900,
                                  color: isGenerator
                                      ? const Color(0xFF69F0AE)
                                      : (isEnabled ? const Color(0xFFFFD54F) : const Color(0xFFFFAB40).withValues(alpha: 0.75)),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 4. Subtle Shimmer / Radiant Overlay for Ready State
                      if (isEnabled)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 5. Cooldown Dark Veil & Timer
                      if (cooldownRemaining > 0)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.65),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D0A14).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFFF8A80).withValues(alpha: 0.6), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 9, color: Color(0xFFFF8A80)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${cooldownRemaining.toStringAsFixed(1)}s',
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFFF8A80),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          );
        }

        final companions = _engine.playerUnits.where((u) => !u.isAshSculptor && u.id != 'ash_sculptor' && u.isAlive).toList();

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 12, vertical: isNarrow ? 5 : 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1926),
            border: Border(
              top: BorderSide(
                color: isApexReady ? const Color(0xFFFFD54F) : disc.primaryColor,
                width: isApexReady ? 2.0 : 1.5,
              ),
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.6), width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: (isApexReady ? const Color(0xFFFFD54F) : disc.primaryColor).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Status Row: Avatar + Discipline Name + Cinder Gauge + Target + Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        unit.assetPath,
                        width: isNarrow ? 22 : 28,
                        height: isNarrow ? 22 : 28,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFFFFD54F), size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: disc.primaryColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'COMMANDER',
                        style: TextStyle(fontSize: 7.0, color: Colors.black, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      disc.title,
                      style: TextStyle(
                        color: disc.primaryColor,
                        fontSize: isNarrow ? 9.5 : 11.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Sculptor Level & XP: Leveling up grants +1★ Skill Point! Higher levels + Great Crucible (Castle) upgrades unlock Tier 2/3/Apex skills.',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141E2B),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 0.8),
                        ),
                        child: Text(
                          'LV.${_engine.skillTreeState.sculptorLevel} (${_engine.skillTreeState.sculptorXp}/${_engine.skillTreeState.xpToNextLevel} XP)',
                          style: const TextStyle(
                            fontSize: 8.0,
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    buildCinderMeter(),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141824),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Text(
                        '⚔️ AUTO +4🔥 ${(unit.currentAp / 100.0).clamp(0.0, 100.0).round()}%',
                        style: const TextStyle(
                          fontSize: 7.5,
                          color: Color(0xFF80D8FF),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_engine.isBulwarkOathActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A20),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.6), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.shield, size: 9, color: Color(0xFF81C784)),
                            SizedBox(width: 2),
                            Text(
                              'BULWARK (+25 ARM, -15% DMG)',
                              style: TextStyle(fontSize: 7.2, color: Color(0xFFC8E6C9), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    if (_engine.isStalkerKeenEdgeActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2E1B20), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFF8A80).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.flash_on, size: 9, color: Color(0xFFFF8A80)), SizedBox(width: 2), Text("STALKER (+15% CRIT, +4🔥)", style: TextStyle(fontSize: 7.2, color: Color(0xFFFFCDD2), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isBloodhoundFrenzyActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF3E2010), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.whatshot, size: 9, color: Color(0xFFFFB74D)), SizedBox(width: 2), Text('FRENZY (+25% <50% HP, +BLEED)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFFE0B2), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isVitaeBondActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2E1224), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFF48FB1).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.water_drop, size: 9, color: Color(0xFFF48FB1)), SizedBox(width: 2), Text('VITAE (+18% LEECH, +3🔥)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFCE4EC), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isAuraOfVitalityActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF102E20), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.favorite, size: 9, color: Color(0xFF69F0AE)), SizedBox(width: 2), Text('CENSER (+8% TURN HEAL, +20% WARD)', style: TextStyle(fontSize: 7.2, color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isSiegeResonatorActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF3E1A10), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.filter_hdr, size: 9, color: Color(0xFFFF7043)), SizedBox(width: 2), Text('SIEGE (+20% SKILL DMG, -ARMOR)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFFEBE5), fontWeight: FontWeight.bold))]),
                      ),
                    const Spacer(),
                    if (explicitTarget != null && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E1E24),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.6), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed, size: 9, color: Color(0xFFFF8A80)),
                            const SizedBox(width: 3),
                            Text(
                              explicitTarget.name,
                              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 8.0, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    InkWell(
                      onTap: () {
                        CrucibleSkillTreeDialog.show(context, _engine).then((_) {
                          setState(() {});
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E2822), Color(0xFF141D17)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.8), width: 1.0),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF69F0AE).withValues(alpha: 0.2), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.account_tree, size: 9.5, color: Color(0xFF69F0AE)),
                            SizedBox(width: 3),
                            Text(
                              'TREE',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8.0, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        CrucibleSanctuaryUpgradeDialog.show(context, _engine).then((_) {
                          setState(() {});
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E241E), Color(0xFF1E1712)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFAB40).withValues(alpha: 0.85), width: 1.0),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFFAB40).withValues(alpha: 0.2), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_fix_high, size: 9.5, color: Color(0xFFFFAB40)),
                            SizedBox(width: 3),
                            Text(
                              'UPGRADE',
                              style: TextStyle(color: Color(0xFFFFAB40), fontSize: 8.0, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isLogDrawerVisible = !_isLogDrawerVisible;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: _isLogDrawerVisible ? const Color(0xFF37474F) : const Color(0xFF1D1F2C),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _isLogDrawerVisible ? const Color(0xFF80D8FF) : Colors.white24, width: 0.9),
                        ),
                        child: const Text(
                          'LOG',
                          style: TextStyle(color: Colors.white70, fontSize: 8.0, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Retinue Command Sub-Bar: Direct orders for player companions
              if (companions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141622),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF263238),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'RETINUE',
                          style: TextStyle(fontSize: 7.0, color: Color(0xFF80D8FF), fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: companions.map((comp) {
                              final bool isSigReady = comp.signatureCooldown <= 0;
                              return Tooltip(
                                message: '${comp.name}\nPassive: ${comp.retinuePassiveName} (${comp.retinuePassiveSummary})\nSignature: ${comp.signatureSkillName} — ${comp.signatureSkillDescription}',
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.0),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1D1B28), Color(0xFF12101A)],
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: isSigReady ? const Color(0xFFFFD54F) : Colors.white12,
                                      width: isSigReady ? 1.2 : 0.8,
                                    ),
                                    boxShadow: isSigReady
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: Image.asset(
                                          comp.assetPath,
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: Colors.white70),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${comp.name} • ${comp.retinuePassiveName}',
                                            style: const TextStyle(fontSize: 7.6, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '★ ${comp.signatureSkillName}',
                                            style: TextStyle(
                                              fontSize: 6.8,
                                              fontWeight: FontWeight.w600,
                                              color: isSigReady ? const Color(0xFFFFD54F) : Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: isSigReady
                                          ? () {
                                              setState(() {
                                                _engine.executeCompanionSignature(comp.id, explicitTarget: explicitTarget);
                                                _playSfx('WEAPArmr_Metal Shield Block Hits_JSE_MW.wav');
                                                final bannerText = '⚡ ${comp.name.toUpperCase()}: ${comp.signatureSkillName.toUpperCase()} PRIMED!';
                                                _unitFloatingPops[comp.id] = bannerText;
                                                _floatingPops.add(_FloatingCombatText(
                                                  id: 'pop_order_${comp.id}_${DateTime.now().millisecondsSinceEpoch}',
                                                  unitId: comp.id,
                                                  text: bannerText,
                                                  color: const Color(0xFFFFD54F),
                                                  borderColor: const Color(0xFFFF9100),
                                                  fontSize: 10.5,
                                                  isCrit: true,
                                                  createdMs: DateTime.now().millisecondsSinceEpoch,
                                                  durationMs: 1600,
                                                  horizontalDrift: 0.0,
                                                ));
                                              });
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(3),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          gradient: isSigReady
                                              ? const LinearGradient(
                                                  colors: [Color(0xFFFF6D00), Color(0xFFD84315)],
                                                )
                                              : null,
                                          color: isSigReady ? null : const Color(0xFF263238),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(
                                            color: isSigReady ? const Color(0xFFFFD54F) : Colors.white12,
                                            width: 0.8,
                                          ),
                                          boxShadow: isSigReady
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF6D00).withValues(alpha: 0.5),
                                                    blurRadius: 5,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isSigReady) ...[
                                              const Icon(Icons.flash_on, size: 9, color: Color(0xFFFFE082)),
                                              const SizedBox(width: 2),
                                            ],
                                            Text(
                                              isSigReady ? 'ORDER' : '${comp.signatureCooldown}T CD',
                                              style: TextStyle(
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.w900,
                                                color: isSigReady ? const Color(0xFFFFE082) : Colors.white38,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons Row: 5 Square Iconic Keybound Skill Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (slotIdx) {
                  final skill = _engine.skillTreeState.getSkillInSlot(slotIdx);
                  final double slotSize = isNarrow ? 50.0 : 58.0;
                  if (skill == null) {
                    return Padding(
                      padding: EdgeInsets.only(right: slotIdx < 4 ? 8.0 : 0.0),
                      child: Tooltip(
                        preferBelow: false,
                        message: 'Slot ${slotIdx + 1} Empty — Unlock skills in [SKILL TREE]',
                        child: Container(
                          width: slotSize,
                          height: slotSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0D14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10, width: 1.0),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 3,
                                left: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14121A),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.white12, width: 0.8),
                                  ),
                                  child: Text(
                                    '${slotIdx + 1}',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 7.5 : 8.5,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.lock_outline, size: 18, color: Colors.white12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final bool isFinisher = skill.cinderCost >= 80;
                  final bool isGenerator = skill.cinderCost == 0;
                  final int cinderYield = skill.rank >= 3 ? 26 : (skill.rank == 2 ? 22 : 18);
                  final double cdRemaining = _engine.skillTreeState.getCooldownRemaining(skill.id);
                  final bool isOnCooldown = cdRemaining > 0.0;
                  final bool isEnabled = !isOnCooldown && (isGenerator || (unit.crucibleCinders >= skill.cinderCost));
                  final double progress = isGenerator
                      ? 1.0
                      : (unit.crucibleCinders / max(1, skill.cinderCost)).clamp(0.0, 1.0);

                  final String subtitleText = isOnCooldown
                      ? '${cdRemaining.toStringAsFixed(1)}s CD'
                      : (isGenerator
                          ? '+$cinderYield🔥'
                          : '${skill.cinderCost}🔥');

                  return Padding(
                    padding: EdgeInsets.only(right: slotIdx < 4 ? 8.0 : 0.0),
                    child: buildActionButton(
                      skill: skill,
                      title: skill.name.toUpperCase(),
                      subtitle: subtitleText,
                      icon: skill.icon,
                      iconAsset: skill.iconAsset,
                      hotkeyLabel: '${slotIdx + 1}',
                      activeColor: isFinisher
                          ? (isEnabled ? skill.primaryColor : const Color(0xFF3E2723))
                          : skill.primaryColor,
                      borderColor: isFinisher
                          ? (isEnabled ? skill.borderColor : Colors.white24)
                          : skill.borderColor,
                      isEnabled: isEnabled,
                      progress: progress,
                      isGenerator: isGenerator,
                      isFinisher: isFinisher,
                      cooldownRemaining: cdRemaining,
                      tooltipMessage: '${skill.name} (Rank ${skill.rank}/${skill.maxRank}): ${skill.currentRankDescription}',
                      onPressed: () {
                        if (isFinisher) {
                          _startForgeStrikeFinisher(unit, explicitTarget, actionType: skill.actionType);
                        } else {
                          setState(() {
                            _engine.executeUnitAction(
                              unit,
                              isReposition: false,
                              explicitTarget: explicitTarget,
                              actionType: skill.actionType,
                            );
                          });
                        }
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }


  /// Option 1: Sleek Combat Pacing & Flow Bar (Active during non-player turns & tick progression)
  Widget _buildCombatPacingStatusTray({bool isLandscapeMobile = false}) {
    final actingEnemy = _engine.enemyUnits.where((u) => u.isAlive && u.id == _attackingUnitId).firstOrNull;
    final nextReadyUnit = [..._engine.playerUnits, ..._engine.enemyUnits]
        .where((u) => u.isAlive)
        .toList()
      ..sort((a, b) => b.currentAp.compareTo(a.currentAp));
    final nextUnit = nextReadyUnit.firstOrNull;

    return Container(
      height: isLandscapeMobile ? 42.0 : 46.0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101018).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: const Color(0xFFFFD54F).withValues(alpha: 0.35), width: 1.2),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.6), width: 1.0),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Left: Battle Phase / Turn Status
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: actingEnemy != null ? const Color(0xFF38151A) : const Color(0xFF17202A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: actingEnemy != null ? const Color(0xFFFF5252) : const Color(0xFF00E5FF),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    actingEnemy != null ? Icons.sports_mma : Icons.hourglass_top,
                    size: 13,
                    color: actingEnemy != null ? const Color(0xFFFF8A80) : const Color(0xFF80D8FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        actingEnemy != null
                            ? '⚔️ ENEMY TURN: ${actingEnemy.name.toUpperCase()}'
                            : (nextUnit != null
                                ? '⏳ INITIATIVE ADVANCING (Next: ${nextUnit.name})'
                                : '⚔️ BATTLE IN PROGRESS'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: actingEnemy != null ? const Color(0xFFFF8A80) : const Color(0xFFFFD54F),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        nextUnit != null
                            ? '${nextUnit.name}: ${nextUnit.currentAp} / 10,000 TM (${((nextUnit.currentAp / 10000) * 100).toInt()}%)'
                            : 'Synchronizing discrete 30 Hz ticks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 8.0, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Controls: Speed Toggle, Auto-Battle Toggle, Battle Log
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Combat Pacing Speed Button
              InkWell(
                onTap: () {
                  setState(() {
                    _engine.cycleCombatSpeed();
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, size: 12, color: Color(0xFFFFD54F)),
                      const SizedBox(width: 4),
                      Text(
                        '${_engine.combatPacingSpeed.toStringAsFixed(1)}x',
                        style: const TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Color(0xFFFFD54F)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Auto-Battle Toggle Button
              InkWell(
                onTap: () {
                  setState(() {
                    _engine.isAutoBattleMode = !_engine.isAutoBattleMode;
                    if (_engine.isAutoBattleMode && _engine.isTurnExecutionPaused) {
                      _engine.isTurnExecutionPaused = false;
                      _engine.isRunning = true;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _engine.isAutoBattleMode ? const Color(0xFF1B5E20) : const Color(0xFF1B1B2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _engine.isAutoBattleMode ? const Color(0xFF00E676) : Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _engine.isAutoBattleMode ? Icons.smart_toy : Icons.smart_toy_outlined,
                        size: 12,
                        color: _engine.isAutoBattleMode ? Colors.white : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _engine.isAutoBattleMode ? 'AUTO ON' : 'AUTO',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: _engine.isAutoBattleMode ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Slide-up Combat Log Toggle Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isLogDrawerVisible = !_isLogDrawerVisible;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isLogDrawerVisible ? const Color(0xFF2C1E10) : const Color(0xFF1B1B2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isLogDrawerVisible ? const Color(0xFFFFB74D) : Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 12,
                        color: _isLogDrawerVisible ? const Color(0xFFFFB74D) : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LOG',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: _isLogDrawerVisible ? const Color(0xFFFFB74D) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Option 1: On-Demand Slide-Up Battle Chronicle Log Overlay
  Widget _buildLogDrawerOverlay({bool isLandscapeMobile = false}) {
    return Container(
      height: isLandscapeMobile ? 100 : 130,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xF00A0A14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 1.0),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 14, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF141422),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, size: 12, color: Color(0xFFFFD54F)),
                    SizedBox(width: 5),
                    Text(
                      'COMBAT CHRONICLE (30 Hz DISCRETE)',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _isLogDrawerVisible = false),
                  child: const Icon(Icons.close, size: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: _engine.combatLogs.length,
              itemBuilder: (context, idx) {
                final log = _engine.combatLogs[_engine.combatLogs.length - 1 - idx];
                final isCrit = log.contains('CRITICAL') || log.contains('SHATTERS') || log.contains('CRIT');
                final isTelegraph = log.contains('TELEGRAPH') || log.contains('⚠️');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isCrit
                          ? const Color(0xFFFFD54F)
                          : (isTelegraph ? const Color(0xFFFF5252) : Colors.white70),
                      fontFamily: 'monospace',
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

  Widget _buildAshenReckoningPill() {
    final phase = _engine.currentPhase;
    Color badgeColor = const Color(0xFF80D8FF);
    IconData icon = Icons.timer_outlined;
    String label = 'STANDARD (${_engine.phaseFormattedTime})';

    switch (phase) {
      case EncounterPhase.standard:
        badgeColor = const Color(0xFF80D8FF);
        icon = Icons.timer_outlined;
        label = 'STANDARD (${_engine.phaseFormattedTime})';
        break;
      case EncounterPhase.warningChime:
        badgeColor = const Color(0xFFFFD54F);
        icon = Icons.alarm;
        label = 'WARNING (${_engine.phaseFormattedTime})';
        break;
      case EncounterPhase.ashenReckoning:
        badgeColor = const Color(0xFFFF5252);
        icon = Icons.local_fire_department;
        label = 'RECKONING 2.0x (${_engine.phaseFormattedTime})';
        break;
      case EncounterPhase.terminalCollapse:
        badgeColor = const Color(0xFFE040FB);
        icon = Icons.dangerous;
        label = 'COLLAPSE (${_engine.phaseFormattedTime})';
        break;
      case EncounterPhase.hardCapWipe:
        badgeColor = const Color(0xFFFF1744);
        icon = Icons.sentiment_very_dissatisfied;
        label = 'SUDDEN DEATH';
        break;
    }

    return Tooltip(
      message: 'The Ashen Reckoning (GDD §7.1):\n• Standard Pacing\n• 1:15 Warning Chime\n• 1:30 Ashen Reckoning (2.0x Dmg / -50% Heals)\n• 1:45 Terminal Collapse (15/s True Dmg / No Revives)\n• 2:00 Sudden Death (Highest EHP Wins)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.7), width: 1.2),
          boxShadow: phase == EncounterPhase.ashenReckoning || phase == EncounterPhase.terminalCollapse
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: badgeColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: badgeColor,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // OPTION 3: INTERACTIVE FORGE STRIKE TACTILE FINISHER
  // =========================================================================

  void _startForgeStrikeFinisher(CombatUnitState unit, CombatUnitState? explicitTarget, {String actionType = 'cataclysmic_pyre'}) {
    if (_engine.isAutoBattleMode) {
      _engine.executeUnitAction(
        unit,
        isReposition: false,
        explicitTarget: explicitTarget,
        actionType: '${actionType}_crit',
      );
      return;
    }

    setState(() {
      _forgeStrikeActionType = actionType;
      _wasRunningBeforeForgeStrike = _engine.isRunning;
      _engine.isRunning = false;
      _isForgeStrikeActive = true;
      _forgeStrikeProgress = 0.0;
      _forgeStrikeHit = false;
      _forgeStrikeIsPerfect = false;
      _forgeStrikeUnit = unit;
      _forgeStrikeTarget = explicitTarget;
    });

    const int totalSteps = 60;
    const int stepDurationMs = 16; // ~1000ms total
    int currentStep = 0;

    _forgeStrikeTimer?.cancel();
    _forgeStrikeTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final progress = currentStep / totalSteps;
      if (progress >= 1.0) {
        timer.cancel();
        if (!_forgeStrikeHit) {
          _resolveForgeStrike(isManualTap: false);
        }
      } else {
        setState(() {
          _forgeStrikeProgress = progress;
        });
      }
    });
  }

  void _resolveForgeStrike({required bool isManualTap}) {
    if (_forgeStrikeHit) return;
    _forgeStrikeTimer?.cancel();

    // Sweet spot: 0.58 to 0.88 progress (anvil ring alignment!)
    final bool isPerfect = isManualTap && (_forgeStrikeProgress >= 0.58 && _forgeStrikeProgress <= 0.88);

    setState(() {
      _forgeStrikeHit = true;
      _forgeStrikeIsPerfect = isPerfect;
    });

    if (isPerfect) {
      _triggerScreenShake(intensity: 4.5);
    } else {
      _triggerScreenShake(intensity: 3.0);
    }

    Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _isForgeStrikeActive = false;
        _engine.isRunning = _wasRunningBeforeForgeStrike;
      });
      if (_forgeStrikeUnit != null) {
        _engine.executeUnitAction(
          _forgeStrikeUnit!,
          isReposition: false,
          explicitTarget: _forgeStrikeTarget,
          actionType: isPerfect ? '${_forgeStrikeActionType}_crit' : _forgeStrikeActionType,
        );
      }
    });
  }

  Widget _buildForgeStrikeOverlay() {
    final bool inSweetSpot = _forgeStrikeProgress >= 0.58 && _forgeStrikeProgress <= 0.88;
    // Ring scales from 210px down to 80px
    final double ringSize = (210.0 - (_forgeStrikeProgress * 130.0)).clamp(80.0, 220.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_forgeStrikeHit) {
          _resolveForgeStrike(isManualTap: true);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xDD210A04),
              Color(0xF4080302),
            ],
            radius: 0.95,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fireplace, color: Color(0xFFFFD54F), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'CRUCIBLE FORGE STRIKE'.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(color: Color(0xFFFF6D00), blurRadius: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap when the molten ring collapses into the runic anvil!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tactile Anvil Target Beat
                  SizedBox(
                    width: 230,
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Static Outer Runering
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF6D00).withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // Golden Sweet Spot Anvil Ring (Impact Target Zone)
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: inSweetSpot ? const Color(0xFFFFFF00) : const Color(0xFFFFD54F),
                              width: inSweetSpot ? 4.5 : 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (inSweetSpot ? const Color(0xFFFFD700) : const Color(0xFFFF8F00)).withValues(alpha: 0.5),
                                blurRadius: inSweetSpot ? 24 : 10,
                                spreadRadius: inSweetSpot ? 4 : 1,
                              ),
                            ],
                          ),
                        ),

                        // Contracting Molten Ring
                        Container(
                          width: ringSize,
                          height: ringSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: inSweetSpot
                                  ? const Color(0xFFFFF59D)
                                  : (_forgeStrikeHit ? const Color(0xFFFFAB91) : const Color(0xFFFF3D00)),
                              width: inSweetSpot ? 4.5 : 3.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (inSweetSpot ? const Color(0xFFFFF176) : const Color(0xFFFF3D00)).withValues(alpha: 0.6),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),

                        // Center Anvil Sigil Icon
                        Icon(
                          Icons.shield,
                          size: 44,
                          color: inSweetSpot ? const Color(0xFFFFFF8D) : const Color(0xFFFFD54F),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hit Feedback / Banner
                  if (_forgeStrikeHit) ...[
                    Text(
                      _forgeStrikeIsPerfect ? '⚡ PERFECT FORGE! (350% CRIT) ⚡' : '🔥 FORGE STRIKE (250% ATK) 🔥',
                      style: TextStyle(
                        color: _forgeStrikeIsPerfect ? const Color(0xFFFFF59D) : const Color(0xFFFF9E80),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: _forgeStrikeIsPerfect ? const Color(0xFFFFD700) : const Color(0xFFFF3D00),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Tactile Strike Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on, color: Colors.black, size: 20),
                        label: const Text(
                          'STRIKE THE ANVIL NOW!',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: inSweetSpot ? const Color(0xFFFFF176) : const Color(0xFFFF8F00),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: inSweetSpot ? Colors.white : const Color(0xFFFFD54F),
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: () {
                          if (!_forgeStrikeHit) {
                            _resolveForgeStrike(isManualTap: true);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolvedUnitSprite(
    CombatUnitState unit, {
    required bool isAttacking,
    required bool visuallyDowned,
    required bool isDragging,
    required bool isBoss,
    required double modelWidth,
    required double modelHeight,
    required Color factionColor,
  }) {
    final fallbackImg = Image.asset(
      unit.assetPath,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        unit.isPlayer ? Icons.shield : Icons.security,
        color: factionColor,
        size: isBoss ? 48 : 36,
      ),
    );

    final animSet = !visuallyDowned ? _resolveUnitAnimSet(unit) : null;
    if (animSet != null) {
      if (isAttacking) {
        final bool useSkill = _attackingIsSignatureSkill;
        final String sheetPath = useSkill ? animSet.skillSheet : animSet.attackSheet;
        return OverflowBox(
          maxWidth: modelWidth * (isBoss ? 1.32 : 1.42),
          maxHeight: modelHeight * 1.16,
          alignment: Alignment.bottomCenter,
          child: SpriteSheetAnimation(
            key: ValueKey('unit_act_${unit.id}_${_activeAttackSequenceId}_$useSkill'),
            assetPath: sheetPath,
            columns: animSet.columns,
            rows: animSet.rows,
            totalFrames: animSet.totalFrames,
            duration: Duration(milliseconds: _scaledMs(useSkill ? 840 : 720)),
            loop: false,
            fit: BoxFit.contain,
            fallback: fallbackImg,
          ),
        );
      }
      final int staggerMs = (unit.id.hashCode.abs() % 5) * 110;
      return SpriteSheetAnimation(
        key: ValueKey('unit_idle_${unit.id}_${animSet.idleSheet}'),
        assetPath: animSet.idleSheet,
        columns: animSet.columns,
        rows: animSet.rows,
        totalFrames: animSet.totalFrames,
        duration: Duration(milliseconds: 2200 + staggerMs),
        loop: true,
        fit: BoxFit.contain,
        fallback: fallbackImg,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _visualFrameTick,
      builder: (context, _, child) {
        if (visuallyDowned || isDragging) return child!;
        final double phase = (DateTime.now().millisecondsSinceEpoch / 460.0) + (unit.id.hashCode % 17) * 0.45;
        final double breath = sin(phase);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1.0 - breath * 0.008, 1.0 + breath * 0.017, 1.0),
          child: child,
        );
      },
      child: fallbackImg,
    );
  }
}

class _UnitAnimSet {
  static const int defaultColumns = 3;
  static const int defaultRows = 2;
  static const int defaultTotalFrames = 6;

  final String idleSheet;
  final String attackSheet;
  final String skillSheet;

  int get columns => defaultColumns;
  int get rows => defaultRows;
  int get totalFrames => defaultTotalFrames;

  const _UnitAnimSet({
    required this.idleSheet,
    required this.attackSheet,
    required this.skillSheet,
  });
}
