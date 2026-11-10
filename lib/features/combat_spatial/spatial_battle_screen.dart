import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/models/unit_entity.dart';
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
import 'rank_and_rite_2d_battlefield.dart';
import '../../shared/widgets/sprite_sheet_animation.dart';
import '../../shared/widgets/pedigree_inspector_dialog.dart';
import '../../shared/widgets/gothic_character_sheet_card.dart';
import '../../shared/widgets/gothic_header_bar.dart';

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
  final VoidCallback? onOpenPlinthSculptory;

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
    this.onOpenPlinthSculptory,
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> {
  Set<String> _computeProjectedSecondaryTargetEnemyIds() {
    final Set<String> secondaryIds = {};
    final actingAlly = _engine.activeActingUnit ??
        (_selectedUnitId != null ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull : null);
    if (actingAlly == null) return secondaryIds;

    final targetEnemy = _selectedEnemyUnitId != null
        ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
        : _getSmartDefaultTarget();
    if (targetEnemy == null || targetEnemy.occupiedNodes.isEmpty) return secondaryIds;

    final primaryCol = targetEnemy.occupiedNodes.first.column;
    final primaryRow = targetEnemy.occupiedNodes.first.row;

    final bool hasRowCleave = actingAlly.activeStance == StanceType.holdTheLine ||
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
  late final SpatialCombatEngine _engine;
  List<UnitEntity> _currentSquadUnits = [];
  List<UnitEntity> _reserveUnits = [];
  Timer? _loopTimer;
  String? _selectedUnitId;
  String? _selectedEnemyUnitId;
  String? _draggedUnitId;
  String? _selectedCardId;
  String? _hoveredCardId;
  SpatialCombatCard? _draggedCard;
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
  String? _attackingUnitId;
  String? _activeSynergyBannerText;
  Color _activeSynergyBannerColor = const Color(0xFFFFD54F);
  String? _damagedUnitId;
  final Set<String> _damagedUnitIds = {};
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
  final List<_ActiveCombatSpriteVfx> _activeSpriteVfx = [];
  Offset _screenShakeOffset = Offset.zero;
  double _shakeIntensity = 0.0;
  double _battlefieldCameraZoom = 1.0;
  bool _isSlowMoFinisher = false;

  // Option 3: Interactive Forge Strike Tactile Finisher
  bool _isForgeStrikeActive = false;
  double _forgeStrikeProgress = 0.0;
  Timer? _forgeStrikeTimer;
  bool _forgeStrikeHit = false;
  bool _forgeStrikeIsPerfect = false;
  CombatUnitState? _forgeStrikeUnit;
  CombatUnitState? _forgeStrikeTarget;

  // Ambient Dark Fantasy Combat Audio
  AudioPlayer? _bgmPlayer;
  final List<AudioPlayer> _sfxPlayers = [];
  int _sfxIndex = 0;
  static const int _maxSfxPlayers = 4;
  bool _isMuted = false;
  bool _isDockCollapsed = false;
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
    SpriteSheetAnimation.precache('assets/animations/valeria_slash_sheet.png');
    SpriteSheetAnimation.precache('assets/animations/iron_footman_idle_sheet.png');
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
    );
    _engine.isActionPauseEnabled = true;
    _engine.addListener(_onEngineUpdate);
    _startLoop();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final settings = SettingsService();
      _isMuted = !settings.bgmEnabled;
      _bgmPlayer = AudioPlayer();
      _sfxPlayers.clear();
      for (int i = 0; i < _maxSfxPlayers; i++) {
        _sfxPlayers.add(AudioPlayer());
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
      player.setVolume(vol).then((_) {
        player.play(AssetSource('audio/$resolved'));
      }).catchError((e) {
        debugPrint('Error playing SFX $resolved: $e');
      });
    } catch (e) {
      debugPrint('Error playing SFX $sfxName: $e');
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
      _bgmPlayer?.pause();
      _bgmPlayer?.setVolume(0.0);
    } else {
      _bgmPlayer?.setVolume(settings.bgmVolume * 0.45);
      _bgmPlayer?.resume();
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
        _triggerScreenShake(intensity: 8.0);
        _activeSynergyBannerText = '🔥 THE ASHEN RECKONING HAS BEGUN! (2.0x Dmg / -50% Heals)';
        _activeSynergyBannerColor = const Color(0xFFFF5252);
      } else if (currentPhase == EncounterPhase.terminalCollapse) {
        _playSfx('sfx_slash.wav');
        _triggerScreenShake(intensity: 14.0);
        _activeSynergyBannerText = '💀 TERMINAL COLLAPSE! (True Dmg / Revives Disabled)';
        _activeSynergyBannerColor = const Color(0xFFE040FB);
      }
    }

    // Boss Enrage Check: When boss drops under 50% HP, trigger Enrage Roar & Arena Shake!
    final boss = _engine.enemyUnits.where((u) => (u.id == 'gorgoroth_boss' || u.footprint != UnitFootprint.single1x1) && u.isAlive).firstOrNull;
    if (boss != null && !_hasBossEnraged && boss.hp <= (boss.maxHp * 0.50)) {
      _hasBossEnraged = true;
      _playSfx('Dinosaur Growl 3_Mono.wav');
      _triggerScreenShake(intensity: 12.0);
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
        _triggerScreenShake(intensity: 10.0);
      } else if (!boss.isStaggered && _wasBossStaggered) {
        _wasBossStaggered = false;
        _playSfx('WEAPArmr_Metal Shield Block Hits_JSE_MW.wav');
      }
    }

    // Check if a new combat action event was dispatched
    final event = _engine.activeActionEvent;
    if (event != null && event.id != _lastHandledEventId) {
      _lastHandledEventId = event.id;
      _enqueueCombatEvent(event);
    }

    setState(() {});
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

  int _hitStopRemainingMs = 0;

  void _triggerHitStop({int durationMs = 70}) {
    _hitStopRemainingMs = max(_hitStopRemainingMs, durationMs);
  }

  void _triggerCameraImpactZoom({double zoomScale = 1.05, int durationMs = 280}) {
    if (!mounted) return;
    setState(() {
      _battlefieldCameraZoom = zoomScale;
    });
    final t = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) {
        setState(() {
          _battlefieldCameraZoom = 1.0;
        });
      }
    });
    _animTimers.add(t);
  }

  void _triggerScreenShake({double intensity = 6.0}) {
    _shakeIntensity = intensity;
    const int stepCount = 6;
    const int stepMs = 35;

    for (int i = 0; i <= stepCount; i++) {
      final t = Timer(Duration(milliseconds: i * stepMs), () {
        if (!mounted) return;
        setState(() {
          if (i == stepCount) {
            _screenShakeOffset = Offset.zero;
            _shakeIntensity = 0.0;
          } else {
            final double decay = 1.0 - (i / stepCount);
            final double sign = (i % 2 == 0) ? 1.0 : -1.0;
            final double offsetX = sign * _shakeIntensity * decay * (i % 3 == 0 ? 0.7 : 1.0);
            final double offsetY = -sign * _shakeIntensity * decay * 0.65;
            _screenShakeOffset = Offset(offsetX, offsetY);
          }
        });
      });
      _animTimers.add(t);
    }
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
    // Display skill/ultimate herald first, then completely dissolve before playing attack animations & damage numbers!
    int bannerDurationMs = 0;
    if (isUltimate && caster != null && caster.isPlayer) {
      bannerDurationMs = 950;
    } else if (isSignature && caster != null) {
      bannerDurationMs = 750;
    } else if (hasNamedSkill) {
      bannerDurationMs = 650;
    }

    void executePhysicalImpact() {
      if (!mounted) return;

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
      int durationMs = 1100;

      if (event.isAssistStrike) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFF00E5FF);
        durationMs = 1450;
        _playSfx('SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav');
      } else if (event.isWallSplat) {
        vfxType = 'shatter';
        primaryColor = const Color(0xFFFF9100);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 1200;
        _playSfx('WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav');
      } else if (event.isUnitCollision) {
        vfxType = 'shockwave';
        primaryColor = const Color(0xFFFF5252);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 1100;
        _playSfx('Heavy Body Crunch 02.wav');
      } else if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova') || event.skillName.contains('Evisceration') || event.skillName.contains('Crimson Dread')) {
        vfxType = 'bloodnova';
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFFD50000);
        durationMs = 1450;
        _playSfx('GORESplt_Gore Splatter 01_JSE_GMP.wav');
      } else if (event.skillName.contains('Sovereign Cleave') || event.skillName.contains('Vanguard Cleave')) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 1300;
        _playSfx('WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav');
      } else if (event.skillName.contains('Deadeye Execution') || event.skillName.contains('Siege-Breaker') || event.skillName.contains('Phantom Riposte')) {
        vfxType = 'slash';
        primaryColor = const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFFFF1744);
        durationMs = 1200;
        _playSfx('SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav');
      } else if (event.skillName.contains('Celestial Surge')) {
        vfxType = 'shockwave';
        primaryColor = const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 1350;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
      } else if (event.skillName.contains('Sanguine Siphon') || event.skillName.contains('Flensing') || event.bleedStacks > 0) {
        vfxType = 'bloodsiphon';
        primaryColor = const Color(0xFFFF5252);
        secondaryColor = const Color(0xFF880E4F);
        durationMs = 1200;
        _playSfx('GORESplt_Gore Splatter 01_JSE_GMP.wav');
      } else if (event.skillName.contains('Smite') || event.skillName.contains('SHATTERS')) {
        vfxType = 'shatter';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFF00E5FF);
        durationMs = 1350;
        _playSfx('Bluezone_BC0297_stone_impact_hammer_015.wav');
      } else if (event.skillName.contains('Arrow') || event.skillName.contains('Shot') || event.skillName.contains('Archer') || event.skillName.contains('Arbalest') || (caster != null && caster.name.contains('Arbalest'))) {
        vfxType = 'arrow';
        primaryColor = const Color(0xFFFFD54F);
        secondaryColor = const Color(0xFFFF8A80);
        durationMs = 950;
        _playSfx('Bluezone_BC0261_mountain_dweller_tool_axe_whoosh_impact_003.wav');
      } else if (event.skillName.contains('Sun') || event.skillName.contains('Orb') || event.skillName.contains('Cinder') || event.skillName.contains('Bolt') || (caster != null && caster.archetype == UnitArchetype.backlineCaster)) {
        vfxType = 'firebolt';
        primaryColor = event.isPlayerAttacker ? const Color(0xFFFF9100) : const Color(0xFFFF3D00);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 1100;
        _playSfx('Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav');
      } else if (event.isHeal || event.skillName.contains('Phalanx')) {
        vfxType = 'shockwave';
        primaryColor = const Color(0xFF00E5FF);
        secondaryColor = const Color(0xFF80D8FF);
        durationMs = 1200;
        _playSfx('WEAPArmr_Metal Shield Block Hits_JSE_MW.wav');
      } else if (event.isCrit) {
        vfxType = 'slash';
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFFFFD54F);
        durationMs = 1300;
        _playSfx('GOREBone_Bone Breaks Celery 01_JSE_GMP.wav');
      } else {
        _playSfx('WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav');
      }

      final newVfx = _CombatVfx(
        id: 'vfx_${event.id}_$impactNowMs',
        startOffset: casterOffset,
        targetOffset: targetOffset,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        type: vfxType,
        durationMs: durationMs,
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
              primaryColor: primaryColor.withValues(alpha: 0.9),
              secondaryColor: secondaryColor.withValues(alpha: 0.8),
              type: vfxType == 'beam' ? 'shockwave' : vfxType,
              durationMs: (durationMs * 0.85).round(),
              createdMs: impactNowMs,
            ));
          }
        });
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

        _activeVfx.add(_CombatVfx(
          id: 'death_${target.id}_$impactNowMs',
          startOffset: targetOffset,
          targetOffset: targetOffset,
          primaryColor: deathColor,
          secondaryColor: isBoss ? const Color(0xFFFFD54F) : Colors.white70,
          type: deathType,
          durationMs: isBoss ? 1200 : 750,
          createdMs: impactNowMs,
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
        final slowMoTimer = Timer(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _isSlowMoFinisher = false;
            });
          }
        });
        _animTimers.add(slowMoTimer);
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
      final bool isHeavyImpact = event.isCrit || isBossStrike || isUltimate || isBloodnova || isSculptorStrike || event.skillName.contains('Smite') || event.secondaryTargetHits.length >= 2;

      final double shakeIntensity = isApexStrike
          ? (event.isCrit ? 24.0 : 18.0)
          : (event.isCrit
              ? 16.0
              : (isSculptorStrike
                  ? 12.0
                  : (isBossStrike ? 10.0 : 6.0)));
      _triggerScreenShake(intensity: shakeIntensity);

      if (isHeavyImpact) {
        _triggerHitStop(durationMs: isApexStrike ? 140 : (isUltimate ? 120 : (isSculptorStrike ? 85 : 70)));
        _triggerCameraImpactZoom(
          zoomScale: isApexStrike ? 1.18 : (isUltimate ? 1.14 : (isSculptorStrike ? 1.08 : 1.04)),
          durationMs: isApexStrike ? 650 : (isUltimate ? 600 : 280),
        );
        _groundRipples.add(_GroundShockwaveRipple(
          id: 'ripple_${event.id}_$impactNowMs',
          origin: targetOffset,
          color: (isBossStrike || isBloodnova || event.bleedStacks > 0)
              ? const Color(0xFFFF1744)
              : (event.isHolyOrMagic || event.skillName.contains('Solar') || event.skillName.contains('Dawnbound') || event.skillName.contains('Brand'))
                  ? const Color(0xFFFFD54F)
                  : (event.isCrit ? const Color(0xFFFF9100) : const Color(0xFF00E5FF)),
          maxRadius: isUltimate ? 160.0 : (isBossStrike ? 140.0 : (isBloodnova ? 130.0 : 100.0)),
          createdMs: impactNowMs,
          durationMs: 650,
        ));
      }

      setState(() {
        _activeVfx.add(newVfx);
        _activeVfx.addAll(secondaryVfxList);
        _attackingUnitId = event.attackerId;
        _damagedUnitId = event.targetId;
        _damagedUnitIds.clear();
        _damagedUnitIds.add(event.targetId);
        if (event.secondaryTargetHits.isNotEmpty) {
          _damagedUnitIds.addAll(event.secondaryTargetHits.keys);
        }

        // Construct distinct styled floating pop
        String popText;
        Color popColor;
        Color popBorder;
        double popSize = 11.0;
        bool isCrit = event.isCrit || (target?.isStaggered == true);

        if (event.isHeal) {
          if (event.skillName == 'Phalanx Intercept' || event.skillName == 'Unbreakable Phalanx') {
            popText = '+60 🛡️ AEGIS';
            popColor = const Color(0xFF80D8FF);
            popBorder = const Color(0xFF00E5FF);
          } else if (event.skillName == 'Stoke the Embers') {
            popText = '+2 ⚡ FOCUS';
            popColor = const Color(0xFFFFD54F);
            popBorder = const Color(0xFFFFC107);
          } else {
            popText = '+HEAL';
            popColor = const Color(0xFF69F0AE);
            popBorder = const Color(0xFF00E676);
          }
        } else {
          if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova')) {
            popText = '🩸 -${event.damage} BLOODNOVA!';
            popColor = const Color(0xFFFF1744);
            popBorder = const Color(0xFF880E4F);
            popSize = 13.0;
          } else if (event.skillName.contains('Sanguine Siphon')) {
            popText = '🩸 -${event.damage} (DRAIN +3🩸)';
            popColor = const Color(0xFFFF5252);
            popBorder = const Color(0xFFB71C1C);
            popSize = 12.0;
          } else if (isCrit) {
            popText = (target?.isStaggered == true) ? '⚡ -${event.damage} CORE CRIT!' : '★ -${event.damage} CRIT!';
            popColor = const Color(0xFFFFD54F);
            popBorder = const Color(0xFFFF9100);
            popSize = 14.5;
          } else if (event.bleedStacks > 0) {
            popText = '🩸 -${event.damage} (+${event.bleedStacks} Bleed)';
            popColor = const Color(0xFFFF3D00);
            popBorder = const Color(0xFFDD2C00);
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
          id: 'pop_${event.id}_$impactNowMs',
          unitId: event.targetId,
          text: popText,
          color: popColor,
          borderColor: popBorder,
          fontSize: popSize,
          isCrit: isCrit,
          createdMs: impactNowMs,
          durationMs: isCrit ? 2200 : 1750,
          horizontalDrift: drift,
        ));

        // If attacker procced a Crucible Grafted Trait, display a glowing purple/gold floating proc callout on the attacker!
        if (event.graftedTraitProc != null && event.attackerId != event.targetId) {
          final graftText = '🧬 ${event.graftedTraitProc ?? ''}';
          _unitFloatingPops[event.attackerId] = graftText;
          _floatingPops.add(_FloatingCombatText(
            id: 'pop_graft_${event.id}_$impactNowMs',
            unitId: event.attackerId,
            text: graftText,
            color: const Color(0xFFEA80FC),
            borderColor: const Color(0xFFD500F9),
            fontSize: 10.5,
            isCrit: false,
            createdMs: impactNowMs,
            durationMs: 1900,
            horizontalDrift: 12.0,
          ));
        }

        // Push floating popups for all secondary targets hit by multi-target / AOE spells
        if (event.secondaryTargetHits.isNotEmpty) {
          int secIndex = 0;
          event.secondaryTargetHits.forEach((secId, secDmg) {
            final isSecBlood = event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova');
            final secText = isSecBlood ? '🩸 - SPLASH' : '- CLEAVE';
            _unitFloatingPops[secId] = secText;
            secIndex++;
            _floatingPops.add(_FloatingCombatText(
              id: 'pop_${event.id}_${secId}_$impactNowMs',
              unitId: secId,
              text: secText,
              color: isSecBlood ? const Color(0xFFFF5252) : const Color(0xFFFF8A80),
              borderColor: isSecBlood ? const Color(0xFF880E4F) : const Color(0xFFD50000),
              fontSize: 11.5,
              isCrit: false,
              createdMs: impactNowMs,
              durationMs: 1800,
              horizontalDrift: (secIndex % 2 == 0 ? 10.0 : -10.0),
            ));
          });
        }
      });

      // Clean up VFX after its duration
      final tVfx = Timer(Duration(milliseconds: durationMs + 50), () {
        if (mounted) {
          setState(() {
            _activeVfx.removeWhere((v) => v.id == newVfx.id || secondaryVfxList.any((s) => s.id == v.id));
            _floatingPops.removeWhere((p) => p.isExpired);
            _groundRipples.removeWhere((r) => r.isExpired);
          });
        }
      });
      _animTimers.add(tVfx);

      // Reset visual lunge & floating pops after 1400ms
      final t1 = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _attackingUnitId = null;
            _damagedUnitId = null;
            _damagedUnitIds.clear();
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

      // Conclude action sequence and advance to next event
      final int animRestMs = (isUltimate || isSignature) ? 1500 : (event.isAssistStrike || event.isKnockback ? 950 : 1200);
      final t2 = Timer(Duration(milliseconds: animRestMs), () {
        if (mounted) {
          _isActionSequenceRunning = false;
          if (_actionEventQueue.isNotEmpty) {
            // 100ms staging gap between consecutive actions so attacks don't abruptly cut each other off
            final tNext = Timer(const Duration(milliseconds: 100), () {
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
    _loopTimer?.cancel();
    // Paced loop: ~50ms per tick (~20 ticks/sec default), scaled genuinely by simulationSpeed (0.3x in bullet-time)
    const baseIntervalMs = 75;
    _loopTimer = Timer.periodic(const Duration(milliseconds: baseIntervalMs), (timer) {
      if (!mounted) return;
      final hasVisibleTrajectory = _selectedUnitId != null ||
          _draggedUnitId != null ||
          _selectedEnemyUnitId != null ||
          _showAllTrajectories ||
          _engine.enemyUnits.any((e) => e.isAlive && e.pendingIntent != null);
      if (hasVisibleTrajectory) {
        _dashPhase = (_dashPhase + 0.06) % 1.0;
      }
      if (_engine.isRunning) {
        if (_hitStopRemainingMs > 0) {
          _hitStopRemainingMs = max(0, _hitStopRemainingMs - baseIntervalMs);
          _tickAccumulator = 0.0;
        } else if (_engine.isActionPauseEnabled && _engine.activeActionEvent != null) {
          // Pause all AP generation and tick accumulation while watching a skill/attack in action!
          _tickAccumulator = 0.0;
        } else {
          _tickAccumulator += _engine.simulationSpeed;
          while (_tickAccumulator >= 1.0) {
            _tickAccumulator -= 1.0;
            _engine.stepTick();
            if (_engine.isActionPauseEnabled && _engine.activeActionEvent != null) {
              _tickAccumulator = 0.0;
              break;
            }
          }
        }
      } else if (hasVisibleTrajectory) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _forgeStrikeTimer?.cancel();
    _battlefieldFocusNode.dispose();
    _loopTimer?.cancel();
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
    _attackingUnitId = null;
    _damagedUnitId = null;
    _activeSkillName = null;
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
    );
    _engine.isActionPauseEnabled = true;
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
          // Subtle Dev / Debug Menu (tucks away T135 & Step Tick to reduce visual noise)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
            padding: EdgeInsets.zero,
            tooltip: 'Combat Diagnostics',
            color: const Color(0xFF161622),
            onSelected: (val) {
              if (val == 'step') {
                if (_engine.isPreBattlePhase) _engine.isPreBattlePhase = false;
                _engine.stepTick();
              } else if (val == 't135') {
                if (_engine.isPreBattlePhase) _engine.isPreBattlePhase = false;
                while (_engine.currentTick < 135) {
                  _engine.stepTick();
                }
              } else if (val == 'restart') {
                _restartCombatEncounter();
              } else if (val == 'boss_gorgoroth') {
                _playSfx('sfx_slash.wav');
                setState(() {
                  _engine.switchBossTrial('gorgoroth');
                });
              } else if (val == 'boss_malakor') {
                _playSfx('sfx_block.wav');
                setState(() {
                  _engine.switchBossTrial('malakor');
                });
              } else if (val == 'boss_morvath') {
                _playSfx('sfx_spell.wav');
                setState(() {
                  _engine.switchBossTrial('morvath');
                });
              } else if (val == 'plinth_sculptory') {
                if (widget.onOpenPlinthSculptory != null) {
                  widget.onOpenPlinthSculptory!();
                }
              }
            },
            itemBuilder: (context) => [
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
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'plinth_sculptory',
                height: 32,
                child: Row(
                  children: [
                    Icon(Icons.foundation, size: 16, color: Color(0xFF00E5FF)),
                    SizedBox(width: 8),
                    Text('Plinth Sculptory', style: TextStyle(fontSize: 12, color: Color(0xFF80D8FF))),
                  ],
                ),
              ),
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
            if (!_isZenMode) _buildTopStatusRibbon(gorgoroth, isLandscapeMobile: isLandscapeMobile),

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: Transform.scale(
                scale: _battlefieldCameraZoom,
                child: Transform.translate(
                  offset: _screenShakeOffset,
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                  // Atmospheric Multi-Layer Parallax Battlefield Arena Backdrop
                  Positioned.fill(
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

                  // Subtle Atmospheric Vignette Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF06070B).withValues(alpha: 0.35),
                            const Color(0xFF030406).withValues(alpha: 0.70),
                          ],
                        ),
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
                                    selectedCardId: _selectedCardId,
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
                                        _selectedEnemyUnitId = null;
                                        _selectedCardId = null;
                                      });
                                    },
                                    onSelectEnemyUnit: (id) {
                                      setState(() {
                                        _selectedEnemyUnitId = (_selectedEnemyUnitId == id) ? null : id;
                                        _selectedUnitId = null;
                                        _selectedCardId = null;
                                      });
                                    },
                                    onMovePlayerUnit: (id, col, row) {
                                      _engine.movePlayerUnit(id, col, row);
                                      setState(() {
                                        _selectedUnitId = id;
                                        _hoveredTileCol = null;
                                        _hovered2DRow = null;
                                        _isHovered2DPlayerSide = null;
                                      });
                                    },
                                    onCastCard: (cardId, {targetUnit, targetCol, targetRow}) {
                                      _engine.castCard(cardId, targetUnit: targetUnit, targetCol: targetCol, targetRow: targetRow);
                                      setState(() {
                                        _draggedCard = null;
                                        _selectedCardId = null;
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

// Layer 3 moved to backdrop so it never obscures bottom row tiles

                  // Floating Tactical Prompt & Unit Combat Triad Overlays (Non-shifting Stack overlays!)
                  // Hidden on landscape mobile so it doesn't block the battlefield view!
                  if (!_isZenMode && !isLandscapeMobile &&
                      (_engine.lastBannerMessage != null ||
                          _draggedUnitId != null ||
                          _selectedCardId != null ||
                          _selectedUnitId != null ||
                          _selectedEnemyUnitId != null ||
                          _engine.isPreBattlePhase))
                    Positioned(
                      top: 6,
                      left: 12,
                      right: 12,
                      child: IgnorePointer(
                        ignoring: _selectedCardId == null && _selectedUnitId == null && _selectedEnemyUnitId == null,
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

                  // Pulled-Up Spell Card Inspector & Cast HUD (Floating just above the dock)
                  if (_selectedCardId != null || _hoveredCardId != null)
                    _buildPulledUpCardOverlay(isLandscapeMobile: isLandscapeMobile),

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
                  if (_engine.isVictory || _engine.isDefeat)
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
                                          // Unbound Ash
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.blur_on, color: Color(0xFFB0BEC5), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${_engine.rewardUnboundAsh} Ash',
                                                style: const TextStyle(color: Color(0xFFECEFF1), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          // Distilled Vitae
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.opacity, color: Color(0xFFE53935), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${_engine.rewardDistilledVitae} Vitae',
                                                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          // Petrified Plinths
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.foundation, color: Color(0xFF00E5FF), size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+${_engine.rewardPetrifiedPlinths} Plinths',
                                                style: const TextStyle(color: Color(0xFF80D8FF), fontSize: 10, fontWeight: FontWeight.bold),
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
                                                      '🩸  • 🔥  • 🛑  • 🎳  • ⚔️ ',
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
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _engine.setupSunderAtAshenGate();
                                          });
                                        },
                                        icon: const Icon(Icons.refresh, size: 14),
                                        label: const Text('REPLAY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFFD54F),
                                          side: const BorderSide(color: Color(0xFFFFD54F)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      if (_engine.isVictory)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.auto_fix_high, size: 14, color: Colors.white),
                                          label: const Text(
                                            'UPGRADE SQUAD & SCULPTOR',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFF6D00),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            elevation: 4,
                                          ),
                                          onPressed: () {
                                            CrucibleSanctuaryUpgradeDialog.show(context, _engine).then((_) {
                                              setState(() {});
                                            });
                                          },
                                        ),
                                      if (_engine.isVictory && widget.onVictory != null)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                                          label: const Text(
                                            'CLAIM VICTORY & ADVANCE',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1B5E20),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            elevation: 4,
                                          ),
                                          onPressed: () {
                                            _playSfx('sfx_victory.wav');
                                            widget.onVictory!();
                                          },
                                        )
                                      else if (_engine.isDefeat && widget.onDefeat != null)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.home, size: 14, color: Colors.white),
                                          label: const Text('RETURN TO CAMP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFB3261E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          onPressed: widget.onDefeat,
                                        )
                                      else if (widget.onBackToStandardCombat != null)
                                        OutlinedButton(
                                          onPressed: widget.onBackToStandardCombat,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white70,
                                            side: const BorderSide(color: Colors.white24),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          child: const Text('EXIT TO HUB', style: TextStyle(fontSize: 10.5)),
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
          // Boss HP Bar
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(2.5),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hpRatio,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                    ),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Boss Break / Stagger Bar (Gorgoroth)
          if (boss.hasBreakBar) ...[
            Row(
              children: [
                Text(
                  isStaggered ? '⚡ STAGGERED' : 'BREAK BAR',
                  style: TextStyle(
                    color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF80D8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 7.5,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF00E5FF).withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: isStaggered ? 1.0 : staggerRatio,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isStaggered
                                  ? [const Color(0xFFFFD600), const Color(0xFFFF9100)]
                                  : [const Color(0xFF00E5FF), const Color(0xFF40C4FF)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isStaggered ? 'SHATTERED' : '${boss.stagger}/${boss.maxStagger}',
                  style: TextStyle(
                    color: isStaggered ? const Color(0xFFFFD600) : const Color(0xFF80D8FF),
                    fontSize: 7.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
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
    final double focusProgress = ((_engine.currentTick % 40) / 40.0).clamp(0.0, 1.0);

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
                // 1. Top Bar Crucible Cinders Fuel Gauge (Replacing legacy Team Vitae)
                Builder(
                  builder: (context) {
                    final sculptor = _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull;
                    final int cinders = sculptor?.crucibleCinders ?? 0;
                    final double cinderRatio = (cinders / 100.0).clamp(0.0, 1.0);
                    final bool isApexReady = cinders >= 80;

                    return Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF190E0B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isApexReady ? const Color(0xFFFFD54F) : const Color(0xFFFF6D00).withValues(alpha: 0.85),
                          width: isApexReady ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isApexReady
                                ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
                                : const Color(0xFFFF5722).withValues(alpha: 0.25),
                            blurRadius: isApexReady ? 8 : 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: isApexReady ? const Color(0xFFFFD54F) : const Color(0xFFFF7043),
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'CINDERS: $cinders/100',
                            style: TextStyle(
                              color: isApexReady ? const Color(0xFFFFE082) : const Color(0xFFFFAB91),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 65,
                            height: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(color: Colors.white12),
                                  FractionallySizedBox(
                                    widthFactor: cinderRatio,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFD84315), Color(0xFFFF6D00), Color(0xFFFFD54F)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Ashen Reckoning Phase Clock Pill (GDD Sec 7.1)
                _buildAshenReckoningPill(),
                const SizedBox(width: 8),

                // 1c. 2D / 2.5D View Mode Toggle
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _is2DGridView = !_is2DGridView;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _is2DGridView
                          ? const Color(0xFF7C4DFF).withValues(alpha: 0.3)
                          : const Color(0xFF263238),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _is2DGridView ? const Color(0xFFB388FF) : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _is2DGridView ? Icons.view_column : Icons.layers,
                          color: _is2DGridView ? const Color(0xFFD1C4E9) : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _is2DGridView ? '2D LANES' : '2.5D ISO',
                          style: TextStyle(
                            color: _is2DGridView ? const Color(0xFFD1C4E9) : Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Simulation Speed (Cycle 1.0X -> 1.5X -> 2.0X Turbo)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _engine.cycleCombatSpeed();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _engine.combatPacingSpeed > 1.0
                          ? const Color(0xFFFF9100).withValues(alpha: 0.25)
                          : const Color(0xFF282836),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _engine.combatPacingSpeed > 1.0
                            ? const Color(0xFFFF9100)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _engine.combatPacingSpeed > 1.0 ? Icons.fast_forward : Icons.speed,
                          color: _engine.combatPacingSpeed > 1.0
                              ? const Color(0xFFFF9100)
                              : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _engine.isBulletTime
                              ? '30% SLOW'
                              : '${_engine.combatPacingSpeed.toStringAsFixed(1)}×',
                          style: TextStyle(
                            color: _engine.combatPacingSpeed > 1.0
                                ? const Color(0xFFFF9100)
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2b. Active Commander Aura & Wave Indicator Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _engine.isValeriaInFrontline
                        ? const Color(0xFFFFD54F).withValues(alpha: 0.15)
                        : const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _engine.isValeriaInFrontline ? const Color(0xFFFFD54F) : const Color(0xFFB388FF),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _engine.isValeriaInFrontline ? Icons.shield : Icons.auto_fix_high,
                        color: _engine.isValeriaInFrontline ? const Color(0xFFFFD54F) : const Color(0xFFB388FF),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _engine.commandService != null
                            ? 'AURA: ${_engine.activeCommanderAuraLabel.split(" (").first.toUpperCase()}'
                            : (_engine.isValeriaInFrontline ? 'BASTION (+25 ARMOR)' : 'REARGUARD (+20% WARD)'),
                        style: TextStyle(
                          color: _engine.isValeriaInFrontline ? const Color(0xFFFFE082) : const Color(0xFFD1C4E9),
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
                      color: const Color(0xFFFF5252).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF5252), width: 0.9),
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

                // 2c. Tactical Attack Trajectory Lines Overlay Toggle ("ALL VECTORS")
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllTrajectories = !_showAllTrajectories;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _showAllTrajectories
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
                          : const Color(0xFF282836),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _showAllTrajectories ? const Color(0xFF00E5FF) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showAllTrajectories ? Icons.visibility : Icons.visibility_outlined,
                          color: _showAllTrajectories ? const Color(0xFF00E5FF) : Colors.white70,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showAllTrajectories ? 'VECTORS: ON' : 'ALL VECTORS',
                          style: TextStyle(
                            color: _showAllTrajectories ? const Color(0xFF00E5FF) : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            letterSpacing: 0.4,
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

          if (boss != null && boss.isAlive && boss.hasBreakBar) ...[
            const SizedBox(height: 4),
            _buildBossBreakBarHud(boss, isLandscapeMobile: isLandscapeMobile),
          ],

          // 4. Live Initiative Action Timeline (ATB Sequence Preview)
          if (!isLandscapeMobile)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 13, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 4),
                    Text(
                      'INITIATIVE',
                      style: TextStyle(
                        fontSize: isLandscapeMobile ? 7.5 : 8.5,
                        color: const Color(0xFFFFD54F),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allLivingUnits.take(7).length,
                    separatorBuilder: (context, _) => const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.white24),
                    itemBuilder: (context, idx) {
                      final u = allLivingUnits[idx];
                      final isAlly = u.isPlayer;
                      final isSelected = (_selectedUnitId == u.id) || (_selectedEnemyUnitId == u.id);
                      final isActingNext = idx == 0;
                      final apRatio = (u.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
                      final apPercent = (apRatio * 100).toInt();

                      return GestureDetector(
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
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isAlly ? const Color(0xFF1E3A24) : const Color(0xFF4A1A1E))
                                : (isAlly ? const Color(0xFF121E16) : const Color(0xFF221114)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFD54F)
                                  : (isActingNext
                                      ? (isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80))
                                      : (isAlly ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
                              width: isSelected || isActingNext ? 1.4 : 0.8,
                            ),
                            boxShadow: isActingNext
                                ? [
                                    BoxShadow(
                                      color: (isAlly ? const Color(0xFF4CAF50) : const Color(0xFFFF5252)).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Circular Unit Avatar
                              Container(
                                width: isLandscapeMobile ? 16 : 20,
                                height: isLandscapeMobile ? 16 : 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black45,
                                  border: Border.all(
                                    color: isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
                                    width: 0.8,
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

                              // Name and AP Badge
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActingNext)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 2.0),
                                          child: Icon(Icons.flash_on, size: 9, color: Color(0xFFFFD54F)),
                                        ),
                                      Text(
                                        u.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: isLandscapeMobile ? 7.0 : 8.0,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected
                                              ? const Color(0xFFFFD54F)
                                              : (isAlly ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Mini AP progress bar
                                  Container(
                                    width: 32,
                                    height: 2,
                                    margin: const EdgeInsets.only(top: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
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
                                  fontSize: 7.0,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: isActingNext
                                      ? const Color(0xFFFFD54F)
                                      : (isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80)),
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

      // Vanguard in Backline converts basic attack to Braced Bulwark on allies ahead
      if (srcLocalRow == 2 && unit.archetype == UnitArchetype.vanguardMelee) {
        final allyAhead = _engine.playerUnits
            .where((u) => u.isAlive && u.id != unit.id && u.occupiedNodes.any((n) => n.column == srcCol && n.row < 2))
            .firstOrNull;
        if (allyAhead != null && allyAhead.occupiedNodes.isNotEmpty) {
          final allyNode = allyAhead.occupiedNodes.first;
          final int allyGRow = 4 + allyNode.row;
          final double tgtX = originX + (allyNode.column - allyGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
          final double tgtY = originY + (allyNode.column + allyGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
          trajectories.add(_TrajectoryData(
            sourceOffset: sourceOffset,
            targetOffset: Offset(tgtX, tgtY),
            skillName: 'Braced Bulwark (+25🛡️ Armor)',
            targetName: allyAhead.name,
            color: const Color(0xFFFFD54F),
            showLabel: isPrimaryInspected,
          ));
          return;
        }
      }

      final target = _engine.resolveProjectedTarget(unit, simulatedCol: srcCol);
      if (target != null && target.occupiedNodes.isNotEmpty) {
        final Offset targetOffset = _getUnitCenterIsometricOffset(target, tileWidth: tileWidth, tileHeight: tileHeight);

        // Flank detection: Midliner or off-column angle against uncovered target
        final bool isFlanking = (unit.archetype == UnitArchetype.reachMidline || srcCol != target.occupiedNodes.first.column) &&
            !_engine.isCoveredByVanguard(target, trajectory: AttackTrajectory.flanking);

        // Adaptive Posture Color & Damage Estimate
        Color trajColor = const Color(0xFF00E5FF);
        double mult = 1.0;
        if (isFlanking) {
          trajColor = const Color(0xFFB388FF); // Violet Flank Attack
          mult = 1.20; // +20% Flank Crit Bonus
        } else if (unit.archetype == UnitArchetype.vanguardMelee && srcLocalRow == 1) {
          trajColor = const Color(0xFFFFB74D); // Midline Advancing Tremor (60%)
          mult = 0.60;
        } else if (unit.archetype == UnitArchetype.vanguardMelee && srcLocalRow == 0 && unit.hasStanceBonusReady) {
          mult = 1.35;
        } else if (unit.id == 'sanguine_blade' && (unit.hasStanceBonusReady || target.bleedStacks > 0)) {
          mult = 1.40;
        } else if (unit.archetype == UnitArchetype.backlineCaster && srcLocalRow == 0) {
          trajColor = const Color(0xFFFF9100); // Point-Blank Panic Discharge
          mult = 0.85;
        }

        final int estDmg = (unit.attack * mult * (1.0 - (target.armor / 100.0).clamp(0.0, 0.75))).round();
        final baseSkillDesc = _getUnitBasicAttackDescription(unit, srcCol, srcLocalRow);
        final String prefix = isFlanking ? '⚡ FLANK (+20% CRIT)' : '🎯 TARGET';
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

    // Vanguard Protective Cover Cords (Row 0 Vanguard protects Column Allies in Row 1 & Row 2)
    final vanguardRow0 = _engine.playerUnits.where(
      (u) => u.isAlive && u.archetype == UnitArchetype.vanguardMelee && u.occupiedNodes.any((n) => n.row == 0),
    );
    for (final vg in vanguardRow0) {
      final vgNode = vg.occupiedNodes.firstWhere((n) => n.row == 0);
      final int vgCol = vgNode.column;
      final int vgGRow = 4 + 0;
      final double vgX = originX + (vgCol - vgGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
      final double vgY = originY + (vgCol + vgGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
      final Offset vgOffset = Offset(vgX, vgY);

      final coveredAllies = _engine.playerUnits.where(
        (u) => u.isAlive && u.id != vg.id && u.occupiedNodes.any((n) => n.column == vgCol && n.row > 0),
      );
      for (final ally in coveredAllies) {
        final aNode = ally.occupiedNodes.firstWhere((n) => n.column == vgCol && n.row > 0);
        final int aGRow = 4 + aNode.row;
        final double aX = originX + (aNode.column - aGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
        final double aY = originY + (aNode.column + aGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
        final Offset allyOffset = Offset(aX, aY);

        trajectories.add(_TrajectoryData(
          sourceOffset: vgOffset,
          targetOffset: allyOffset,
          skillName: 'Vanguard Aegis',
          targetName: ally.name,
          color: const Color(0xFF00E5FF),
          isCoverCord: true,
          showLabel: true,
          labelPrefix: '🛡️ COVER -25%',
        ));
      }
    }

    // Inspected Enemy Unit Trajectory (when player clicks an enemy to see who it targets)
    if (_selectedEnemyUnitId != null) {
      final enemy = _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull;
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
                        _draggedCard = null;
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
                  }
                  return false;
                },
                onAcceptWithDetails: (details) {
                  final data = details.data;
                  if (data.startsWith('card:')) {
                    final cardId = data.replaceFirst('card:', '');
                    _engine.castCard(cardId, targetUnit: multiUnit, targetCol: targetAnchor.column, targetRow: targetAnchor.row);
                    setState(() {
                      _draggedCard = null;
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
                        if (_draggedCard != null) {
                          _engine.castCard(_draggedCard!.id, targetUnit: multiUnit, targetCol: targetAnchor.column, targetRow: targetAnchor.row);
                          setState(() => _draggedCard = null);
                        } else if (_selectedCardId != null) {
                          final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                          if (card != null) {
                            if (card.id == 'phalanx_intercept' && !multiUnit.isPlayer) {
                              setState(() => _engine.lastBannerMessage = '⚠️ Phalanx Intercept only targets allies!');
                              return;
                            }
                            if (card.id != 'phalanx_intercept' && card.id != 'stoke_the_embers' && multiUnit.isPlayer) {
                              setState(() => _engine.lastBannerMessage = '⚠️ ${card.name} only targets enemies!');
                              return;
                            }
                            _playSfx('sfx_card.wav');
                            _engine.castCard(card.id, targetUnit: multiUnit, targetCol: targetAnchor.column, targetRow: targetAnchor.row);
                            setState(() {
                              _selectedCardId = null;
                              _hoveredTileGRow = null;
                              _hoveredTileCol = null;
                            });
                          }
                        } else {
                          setState(() {
                            if (multiUnit.isPlayer) {
                              _selectedUnitId = (_selectedUnitId == multiUnit.id) ? null : multiUnit.id;
                              _selectedEnemyUnitId = null;
                            } else {
                              _selectedEnemyUnitId = (_selectedEnemyUnitId == multiUnit.id) ? null : multiUnit.id;
                              _selectedUnitId = null;
                            }
                            _selectedCardId = null;
                          });
                        }
                      },
                      child: Center(
                        child: _buildUnitMiniatureWidget(
                          multiUnit,
                          tileWidth: tileWidth,
                          tileHeight: tileHeight,
                          colGap: 0.0,
                          isSelected: isSelected || isDropCandidate,
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
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AttackTrajectoryOverlayPainter(
                    trajectories: trajectories,
                    dashPhase: _dashPhase,
                  ),
                ),
              ),
            ),

          // Ground Shockwave Ripple Painter Layer (Expanding concentric isometric shockwaves)
          if (_groundRipples.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GroundShockwaveRipplePainter(
                    ripples: _groundRipples,
                    currentTimestampMs: DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
              ),
            ),

          // Dynamic Kinetic Combat VFX Overlay Layer (Slashes, Beams, Shockwaves)
          if (_activeVfx.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CombatVfxOverlayPainter(
                    effects: _activeVfx,
                    currentTimestampMs: DateTime.now().millisecondsSinceEpoch,
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

  /// Calculates all global row and col coordinates affected by a spell card when hovered over targetGRow, targetCol
  List<({int gRow, int col})> _getSpellAffectedGridCells(SpatialCombatCard card, int targetGRow, int targetCol) {
    final List<({int gRow, int col})> cells = [];

    if (card.id == 'phalanx_intercept') {
      // Single ally target
      cells.add((gRow: targetGRow, col: targetCol));
    } else if (card.id == 'smite_the_calcified') {
      // Single enemy focus blast (hits anchor and colossus footprint)
      cells.add((gRow: targetGRow, col: targetCol));
      // If targeting Gorgoroth, cover his entire 2x2 footprint
      final boss = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull;
      if (boss != null) {
        // Enemy rows: gRow 0 = Row 2, gRow 1 = Row 1, gRow 2 = Row 0
        final int localRow = targetGRow > 3 ? (targetGRow - 4) : (2 - targetGRow);
        if (targetGRow < 3 && boss.occupies(targetCol, localRow)) {
          // Add Gorgoroth's entire footprint in global coordinates
          // Gorgoroth occupies: col 1,2 and row 0,1 -> gRow 1,2 and col 1,2
          for (int gr = 1; gr <= 2; gr++) {
            for (int gc = 1; gc <= 2; gc++) {
              if (!cells.any((c) => c.gRow == gr && c.col == gc)) {
                cells.add((gRow: gr, col: gc));
              }
            }
          }
        }
      }
    } else if (card.id == 'searing_brand' || card.pattern == TargetPattern.stAshlarCross) {
      // Cross pattern: center + top, bottom, left, right adjacent tiles
      cells.add((gRow: targetGRow, col: targetCol));
      // Cardinal neighbors
      const deltas = [(0, 1), (0, -1), (1, 0), (-1, 0)];
      for (final (dRow, dCol) in deltas) {
        final nr = targetGRow + dRow;
        final nc = targetCol + dCol;
        if (nr >= 0 && nr < 7 && nc >= 0 && nc < 5) {
          cells.add((gRow: nr, col: nc));
        }
      }
    } else if (card.id == 'sun_ashlar_wrath') {
      // Full radiant barrage across all enemy tiles (gRow 0, 1, 2)
      for (int gr = 0; gr <= 2; gr++) {
        for (int gc = 0; gc < 5; gc++) {
          cells.add((gRow: gr, col: gc));
        }
      }
    } else if (card.id == 'stoke_the_embers') {
      // Buffs team focus; illuminates player side (gRow 4, 5, 6)
      for (int gr = 4; gr <= 6; gr++) {
        for (int gc = 0; gc < 5; gc++) {
          cells.add((gRow: gr, col: gc));
        }
      }
    } else {
      // Default single target
      cells.add((gRow: targetGRow, col: targetCol));
    }

    return cells;
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
    if (unit.id == 'sanguine_blade') {
      return 'Flensing Thrust (Crit & Bleed)';
    }
    if (unit.templateId == 'iron_arbalest' || unit.name.toLowerCase().contains('arbalest')) {
      return simulatedRow == 2 ? 'Armor-Piercing Bolt (Crit)' : 'Heavy Crossbow Volley';
    }
    if (unit.templateId == 'grave_duelist' || unit.name.toLowerCase().contains('duelist')) {
      return 'Dueling Thrust (Bleed & Crit)';
    }
    if (unit.archetype == UnitArchetype.reachMidline) {
      return 'Skirmish Thrust (Reach Impact)';
    }
    if (unit.id == 'sun_smith' || unit.archetype == UnitArchetype.backlineCaster) {
      return simulatedRow == 2 ? 'Aetheric Piercing Beam (+1 Focus)' : 'Arcane Bolt Volley';
    }
    if (unit.archetype == UnitArchetype.vanguardMelee) {
      if (simulatedRow == 0) {
        return unit.id == 'lady_valeria'
            ? 'Sunbrand Slash (100% Impact)'
            : (unit.id == 'iron_footman' ? 'Shield Bash (100% + Stun)' : 'Vanguard Cleave (100% Impact)');
      } else if (simulatedRow == 1) {
        return 'Shockwave Tremor (60% Dmg + Poise)';
      } else {
        return 'Braced Bulwark (+25 Column Armor)';
      }
    }
    return 'Basic Strike';
  }

  /// Calculates predicted phantom damage or effect for a unit given the hovered spell
  String? _getPhantomUnitEffect(CombatUnitState unit, SpatialCombatCard card, int targetGRow, int targetCol) {
    if (!unit.isAlive) return null;

    if (card.id == 'phalanx_intercept') {
      if (unit.isPlayer) {
        final localRow = targetGRow > 3 ? (targetGRow - 4) : (2 - targetGRow);
        if (targetGRow > 3 && unit.occupies(targetCol, localRow)) {
          return '+35 🛡️ ARMOR';
        }
      }
      return null;
    }

    if (card.id == 'stoke_the_embers') {
      if (unit.isPlayer && unit.id == 'lady_valeria') {
        return '+2 ⚡ FOCUS';
      }
      return null;
    }

    // Offensive cards targeting enemies:
    if (unit.isPlayer) return null;

    final affected = _getSpellAffectedGridCells(card, targetGRow, targetCol);
    // Check if any occupied node of this unit matches an affected cell
    bool isUnitHit = false;
    for (final node in unit.occupiedNodes) {
      // Enemy unit row 0 = gRow 2, row 1 = gRow 1, row 2 = gRow 0
      final int unitGRow = 2 - node.row;
      if (affected.any((c) => c.gRow == unitGRow && c.col == node.column)) {
        isUnitHit = true;
        break;
      }
    }

    if (!isUnitHit) return null;

    if (card.id == 'smite_the_calcified') {
      final rawDmg = (74 * 2.5).round(); // 185 damage
      final projectedDmg = (rawDmg * (1.0 - (unit.armor / 100).clamp(0.0, 0.75))).round();
      if (unit.isSlagCarapaceActive) {
        return '💥 -$projectedDmg (SHATTER!)';
      }
      return '💥 -$projectedDmg CRIT';
    } else if (card.id == 'searing_brand') {
      // Direct target takes 105, splash takes 45
      final localRow = targetGRow > 3 ? (targetGRow - 4) : (2 - targetGRow);
      final bool isDirectTarget = unit.occupies(targetCol, localRow);
      final rawDmg = isDirectTarget ? 105 : 45;
      final projectedDmg = (rawDmg * (1.0 - (unit.armor / 100).clamp(0.0, 0.75))).round();
      return isDirectTarget ? '🔥 -$projectedDmg DMG' : '⚡ -$projectedDmg SPLASH';
    } else if (card.id == 'sun_ashlar_wrath') {
      final projectedDmg = (110 * (1.0 - (unit.armor / 100).clamp(0.0, 0.75))).round();
      return '☀️ -$projectedDmg RADIANT';
    }

    return null;
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
    final bool isReachable = isPlayerSquad &&
        selectedUnit != null &&
        occupant == null &&
        selectedUnit.canMoveTo(col, row, ignoreApCost: _engine.isPreBattlePhase);
    final bool isSwappable = isPlayerSquad &&
        selectedUnit != null &&
        occupant != null &&
        occupant.id != selectedUnit.id &&
        !occupant.isDisplacementImmune &&
        selectedUnit.canMoveTo(col, row, ignoreApCost: _engine.isPreBattlePhase);

    final bool isSelected = (isPlayerSquad && _selectedUnitId != null && occupant?.id == _selectedUnitId) ||
        (!isPlayerSquad && _selectedEnemyUnitId != null && occupant?.id == _selectedEnemyUnitId);

    // Tactical Spell & Ultimate AOE Highlight Overlay calculation:
    final activeCard = _draggedCard ??
        (_hoveredCardId != null ? _engine.hand.where((c) => c.id == _hoveredCardId).firstOrNull : null) ??
        (_selectedCardId != null ? _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull : null);
    final activeUltimateUnitId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
    bool isSpellAoeAffected = false;
    if (activeUltimateUnitId != null && _hoveredTileGRow != null && _hoveredTileCol != null) {
      final affectedList = _getUltimateAffectedGridCells(activeUltimateUnitId, _hoveredTileGRow!, _hoveredTileCol!);
      isSpellAoeAffected = affectedList.any((c) => c.gRow == gRow && c.col == col);
    } else if (activeCard != null) {
      if (_hoveredTileGRow != null && _hoveredTileCol != null) {
        final affectedList = _getSpellAffectedGridCells(activeCard, _hoveredTileGRow!, _hoveredTileCol!);
        isSpellAoeAffected = affectedList.any((c) => c.gRow == gRow && c.col == col);
      } else if (_selectedCardId != null || _hoveredCardId != null) {
        // If card is hovered or selected by click, preview AOE / valid target tiles
        if (activeCard.id == 'sun_ashlar_wrath') {
          isSpellAoeAffected = !isPlayerSquad;
        } else if (activeCard.id == 'stoke_the_embers') {
          isSpellAoeAffected = isPlayerSquad;
        } else if (activeCard.id == 'phalanx_intercept') {
          isSpellAoeAffected = isPlayerSquad && occupant != null;
        } else if (activeCard.id == 'searing_brand' || activeCard.pattern != TargetPattern.singleTarget) {
          isSpellAoeAffected = !isPlayerSquad; // Can target any tile on enemy squad, empty or occupied
        } else {
          isSpellAoeAffected = !isPlayerSquad && occupant != null;
        }
      }
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
          return isPlayerSquad && canEnterOrSwap && unit.canMoveTo(col, row, ignoreApCost: _engine.isPreBattlePhase);
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
            _draggedCard = null;
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
                // Glowing Arcane Spell Magic Circle Projection (when targeted by Card or Ultimate AOE)
                if (isSpellAoeAffected)
                  Center(
                    child: Opacity(
                      opacity: 0.65,
                      child: Image.asset(
                        activeCard != null && (activeCard.id == 'phalanx_intercept' || activeCard.id == 'stoke_the_embers')
                            ? 'assets/images/Spells/Support_spell_magic_circle.png'
                            : (activeCard != null && activeCard.id == 'revive_vitae'
                                ? 'assets/images/Spells/Heal_spell_magic_circle.png'
                                : 'assets/images/Spells/Attack_spell_magic_circle.png'),
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
                        if (_selectedCardId != null) {
                          final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                          if (card != null) {
                            if (card.id == 'phalanx_intercept' && !isPlayerSquad) {
                              setState(() => _engine.lastBannerMessage = '⚠️ Phalanx Intercept only targets allies!');
                              return;
                            }
                            if (card.id != 'phalanx_intercept' && card.id != 'stoke_the_embers' && isPlayerSquad) {
                              setState(() => _engine.lastBannerMessage = '⚠️ ${card.name} only targets enemies!');
                              return;
                            }
                            _playSfx('sfx_card.wav');
                            _engine.castCard(card.id, targetUnit: occupant, targetCol: col, targetRow: row);
                            setState(() {
                              _selectedCardId = null;
                              _hoveredTileGRow = null;
                              _hoveredTileCol = null;
                            });
                            return;
                          }
                        }
                        setState(() {
                          if (isPlayerSquad) {
                            _selectedUnitId = (_selectedUnitId == occupant.id) ? null : occupant.id;
                            _selectedEnemyUnitId = null;
                          } else {
                            _selectedEnemyUnitId = (_selectedEnemyUnitId == occupant.id) ? null : occupant.id;
                            _selectedUnitId = null;
                          }
                          _selectedCardId = null;
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
                        } else if (_selectedCardId != null) {
                          // Cast clicked card on target tile if applicable
                          final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                          if (card != null) {
                            if (card.id == 'stoke_the_embers') {
                              _engine.castCard(card.id, targetCol: col, targetRow: row);
                              setState(() => _selectedCardId = null);
                            } else if (!isPlayerSquad) {
                              // Offensive or ground splash spells (Searing Brand, Wrath of Ashlar, Sun-King Cataclysm)
                              _engine.castCard(card.id, targetCol: col, targetRow: row);
                              setState(() => _selectedCardId = null);
                            } else {
                              setState(() {
                                _engine.lastBannerMessage = '⚠️ ${card.name} must target enemy ground or units!';
                              });
                            }
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
                      final activeCard = _draggedCard ?? (_selectedCardId != null ? _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull : null);
                      final activeUltId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
                      String? phantomEffect;
                      if (activeUltId != null && (_hoveredTileGRow != null || _selectedUltimateUnitId != null)) {
                        phantomEffect = _getPhantomUltimateEffect(occupant, activeUltId, _hoveredTileGRow ?? gRow, _hoveredTileCol ?? col);
                      } else if (activeCard != null && (_hoveredTileGRow != null || _selectedCardId != null)) {
                        phantomEffect = _getPhantomUnitEffect(occupant, activeCard, _hoveredTileGRow ?? gRow, _hoveredTileCol ?? col);
                      }

                      return Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isOccluding ? 0.38 : 1.0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_selectedCardId != null) {
                                // Cast currently selected card onto clicked unit!
                                final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                                if (card != null) {
                                  if (card.id == 'phalanx_intercept' && !isPlayerSquad) {
                                    setState(() {
                                      _engine.lastBannerMessage = '⚠️ Phalanx Intercept only targets allies!';
                                    });
                                    return;
                                  }
                                  if (card.id != 'phalanx_intercept' && card.id != 'stoke_the_embers' && isPlayerSquad) {
                                    setState(() {
                                      _engine.lastBannerMessage = '⚠️ ${card.name} only targets enemies!';
                                    });
                                    return;
                                  }
                                  _playSfx('sfx_card.wav');
                                  _engine.castCard(card.id, targetUnit: occupant, targetCol: col, targetRow: row);
                                  setState(() {
                                    _selectedCardId = null;
                                    _hoveredTileGRow = null;
                                    _hoveredTileCol = null;
                                  });
                                  return;
                                }
                              }

                              if (isPlayerSquad) {
                                setState(() {
                                  _selectedUnitId = (_selectedUnitId == occupant.id) ? null : occupant.id;
                                  _selectedEnemyUnitId = null;
                                  _selectedCardId = null; // deselect card
                                });
                              } else {
                                // Clicked enemy unit: Cast dragged card OR inspect enemy trajectory
                                if (_draggedCard != null) {
                                  _engine.castCard(_draggedCard!.id, targetUnit: occupant);
                                  setState(() => _draggedCard = null);
                                } else {
                                  setState(() {
                                    _selectedEnemyUnitId = (_selectedEnemyUnitId == occupant.id) ? null : occupant.id;
                                    _selectedUnitId = null;
                                    _selectedCardId = null;
                                  });
                                }
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
                                        _selectedCardId = null;
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
                                : _buildUnitMiniatureWidget(
                                    occupant,
                                    tileWidth: tileWidth,
                                    tileHeight: tileHeight,
                                    colGap: colGap,
                                    isSelected: isSelected,
                                    phantomEffect: phantomEffect,
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
          message = '👁️ ENEMY SCOUTING: Inspecting ${enemy.name.toUpperCase()} — crimson line shows its initial target column!';
          themeColor = const Color(0xFFFF5252);
          icon = Icons.radar;
        }
      } else {
        final unplacedCount = _engine.playerUnits.where((u) => u.isAlive && u.occupiedNodes.isEmpty).length;
        if (unplacedCount > 0) {
          message = '🛡️ PRE-BATTLE: Drag units from the Reserve Dock into place on the grid, then tap [ENGAGE BATTLE]!';
        } else {
          message = '🛡️ SQUAD READY: Drag units to rearrange formation, or tap [ENGAGE BATTLE] in the Reserve Dock to begin!';
        }
        themeColor = const Color(0xFFFFD54F);
        icon = Icons.touch_app;
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
    } else if (_selectedCardId != null) {
      final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
      if (card != null) {
        message = '✨ ${card.name.toUpperCase()} ARMED: Click a target node or enemy on the grid to cast!';
        themeColor = const Color(0xFF00E5FF);
        icon = Icons.auto_awesome;
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
        final posture = unit.postureLabel;
        if (unit.canAffordMovement) {
          message = '⚔️ ${unit.name.toUpperCase()} [$posture] (AP: $apPct%): Click glowing [MOVE] or [⇄ SWAP] tile (Costs 50% AP)!';
          themeColor = const Color(0xFF00E676);
          icon = Icons.directions_run;
        } else {
          message = '⚠️ ${unit.name.toUpperCase()} [$posture] (AP: $apPct%): Needs 50% AP to reposition!';
          themeColor = const Color(0xFFFF9100);
          icon = Icons.hourglass_top;
        }
      }
    } else if (_selectedEnemyUnitId != null) {
      final enemy = _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull;
      if (enemy != null) {
        message = '👁️ THREAT VECTOR: ${enemy.name.toUpperCase()} (${enemy.hp}/${enemy.maxHp} HP • ${enemy.armor} Armor) — crimson line shows target!';
        themeColor = const Color(0xFFFF5252);
        icon = Icons.radar;
      }
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
          Icon(icon, color: themeColor, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedCardId != null || _selectedUnitId != null || _selectedEnemyUnitId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCardId = null;
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

  /// Compact 3-Part Unit Combat Triad Inspector Strip (Basic Action & Posture • Stance Mastery • Ultimate Burst)
  Widget _buildUnitCombatTriadStrip() {
    final String? allyId = _draggedUnitId ?? _selectedUnitId;
    final CombatUnitState? unit = allyId != null
        ? _engine.playerUnits.where((u) => u.id == allyId && u.isAlive).firstOrNull
        : (_selectedEnemyUnitId != null
            ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
            : null);

    if (unit == null || unit.occupiedNodes.isEmpty) return const SizedBox.shrink();

    // Simulated row/col if currently dragging a player unit over a player tile
    final bool isHoveringPlayerCell = (unit.isPlayer &&
        _draggedUnitId == unit.id &&
        _hoveredTileCol != null &&
        _hoveredTileGRow != null &&
        _hoveredTileGRow! > 3);

    final int simCol = isHoveringPlayerCell ? _hoveredTileCol! : unit.occupiedNodes.first.column;
    final int simRow = isHoveringPlayerCell ? (_hoveredTileGRow! - 4) : unit.occupiedNodes.first.row;

    final String basicDesc = _getUnitBasicAttackDescription(unit, simCol, simRow);
    final String rowLabel = simRow == 0 ? 'FRONT ROW' : (simRow == 1 ? 'MID ROW' : 'BACK ROW');

    String stanceTitle = 'Inherent Trait';
    String stanceDetail = 'Standard combat readiness';
    Color stanceColor = const Color(0xFF80D8FF);

    switch (unit.activeStance) {
      case StanceType.holdTheLine:
        stanceTitle = 'Hold the Line';
        stanceDetail = unit.hasStanceBonusReady
            ? '⚡ READY: +30% Armor, Cleave & -1500 AP!'
            : (simRow == 0
                ? 'Frontline (${unit.consecutiveTurnsStationary}/2 turns to Cleave)'
                : 'Move to Frontline to charge');
        stanceColor = const Color(0xFFFFD54F);
        break;
      case StanceType.flankingMomentum:
        stanceTitle = 'Flanking Momentum';
        stanceDetail = unit.hasStanceBonusReady
            ? '⚡ READY: +40% Crit, +4 Bleed & +3000 AP!'
            : 'Reposition or hit Bleeding foe for Crit + AP refund';
        stanceColor = const Color(0xFFFF5252);
        break;
      case StanceType.aethericAlignment:
        stanceTitle = 'Aetheric Alignment';
        stanceDetail = simRow == 2
            ? '⚡ ACTIVE: Column Pierce & +1 Focus on cast!'
            : '⚠️ Stand in Back Row for Column Pierce';
        stanceColor = const Color(0xFF00E5FF);
        break;
      case StanceType.sanctifiedHearth:
        stanceTitle = 'Sanctified Hearth';
        stanceDetail = 'Adjacent allies regen 3% HP/s & cleanse';
        stanceColor = const Color(0xFF00E676);
        break;
      case StanceType.none:
        stanceTitle = unit.isPlayer ? 'Combat Posture' : 'Hostile Construct';
        stanceDetail = unit.pendingIntent != null
            ? 'Winding up ${unit.pendingIntent!.skillName}!'
            : 'HP ${unit.hp}/${unit.maxHp} • Armor ${unit.armor}';
        stanceColor = const Color(0xFFFF8A80);
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF141522).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: unit.isPlayer ? const Color(0xFF00E5FF).withValues(alpha: 0.45) : const Color(0xFFFF5252).withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Unit Name & Row Depth Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: unit.isPlayer ? const Color(0xFF1A2938) : const Color(0xFF381A1E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: unit.isPlayer ? const Color(0xFF00E5FF) : const Color(0xFFFF5252),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${unit.name.toUpperCase()} • $rowLabel (COL ${simCol + 1})',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: unit.isPlayer ? const Color(0xFF80D8FF) : const Color(0xFFFF8A80),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Character Sheet Inspect Quick Action Button
            GestureDetector(
              onTap: () {
                _openUnitInspectorDialog(unit);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E342E), Color(0xFF2E1C14)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55FFD54F), blurRadius: 4),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📜', style: TextStyle(fontSize: 9.5)),
                    SizedBox(width: 3),
                    Text(
                      'SHEET',
                      style: TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD54F),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 1. Basic Attack Action Badge / RPG Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D2538), Color(0xFF143750)],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),
                boxShadow: const [
                  BoxShadow(color: Color(0x3300E5FF), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_mma, size: 12, color: Color(0xFF80D8FF)),
                  const SizedBox(width: 4),
                  Text(
                    'BASIC ATTACK: $basicDesc',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 1b. Distinct Signature Skill Attack Button / Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: unit.isSignatureReady
                      ? [const Color(0xFF381C08), const Color(0xFF6B3B0A)]
                      : [const Color(0xFF221A16), const Color(0xFF30241E)],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: unit.isSignatureReady ? const Color(0xFFFFD54F) : const Color(0xFF6E5630),
                  width: unit.isSignatureReady ? 1.2 : 0.8,
                ),
                boxShadow: unit.isSignatureReady
                    ? const [
                        BoxShadow(color: Color(0x66FFD54F), blurRadius: 6, spreadRadius: 0.5),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: unit.isSignatureReady ? const Color(0xFFFFD54F) : const Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit.isSignatureReady
                        ? '★ SKILL READY: ${unit.signatureSkillName.toUpperCase()}'
                        : 'SKILL: ${unit.signatureSkillName.toUpperCase()} (${unit.signatureCooldown} turns)',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: unit.isSignatureReady ? const Color(0xFFFFD54F) : const Color(0xFFFFCC80),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // 1c. Crucible Grafted Trait Badge (if present)
            if (unit.graftedTraitDisplayName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF311B92).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFEA80FC), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.biotech, size: 11, color: Color(0xFFEA80FC)),
                    const SizedBox(width: 3),
                    Text(
                      'GRAFT: ${unit.graftedTraitDisplayName}',
                      style: const TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF3E5F5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],

            // 2. Stance Mastery (Passive Positional Trait)
            Icon(Icons.shield_moon, size: 12, color: stanceColor),
            const SizedBox(width: 4),
            Text(
              '$stanceTitle: $stanceDetail',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: stanceColor,
              ),
            ),

            // 3. Ultimate Burst (Manual)
            if (unit.isPlayer) ...[
              const SizedBox(width: 12),
              const Icon(Icons.bolt, size: 13, color: Color(0xFFFFD54F)),
              const SizedBox(width: 3),
              Text(
                'ULT: ${unit.ultimateTitle} (${unit.ultimateGauge}%)',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: unit.isUltimateReady ? const Color(0xFFFFD54F) : Colors.white70,
                ),
              ),
              if (unit.isUltimateReady && !_engine.isPreBattlePhase) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    _engine.castUltimate(unit.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      '⚡ UNLEASH',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ],

            // 4. Tactical Synergy Indicator
            Builder(
              builder: (context) {
                final enemies = _engine.enemyUnits.where((u) => u.isAlive);
                final anyBleeding = enemies.any((u) => u.hasBleed);
                final totalBleed = enemies.fold<int>(0, (sum, u) => sum + u.bleedStacks);

                if (_selectedCardId == 'vitae_eruption' && anyBleeding) {
                  return Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A000E),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF1744), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop, size: 10, color: Color(0xFFFF1744)),
                        const SizedBox(width: 3),
                        Text(
                          '🩸 BLOODNOVA SYNERGY: +${totalBleed * 20} DETONATION DMG ($totalBleed BLEED STACKS)',
                          style: const TextStyle(
                            fontSize: 8.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF8A80),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (_selectedCardId == 'sanguine_siphon' && unit.hasBleed) {
                  return Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF381016),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF5252), width: 1.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.healing, size: 10, color: Color(0xFFFF5252)),
                        SizedBox(width: 3),
                        Text(
                          '🩸 LEECH SYNERGY: STACKS VULNERABILITY & RESTORES HP',
                          style: TextStyle(
                            fontSize: 8.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF8A80),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (unit.hasBleed && unit.isPlayer == false) {
                  return Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF261014),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: Text(
                      '🩸 VULNERABLE: ${unit.bleedStacks} BLEED STACKS',
                      style: const TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF8A80),
                      ),
                    ),
                  );
                } else if (unit.isPlayer && unit.isAlive) {
                  final isUnderTelegraph = _engine.activeTelegraphedNodes.any((n) => unit.occupies(n.column, n.row));
                  if (isUnderTelegraph) {
                    return Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A000E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFF1744), width: 1.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFFF1744)),
                          SizedBox(width: 3),
                          Text(
                            '⚠️ DANGER: IN STRIKE ZONE! REPOSITION OR INTERRUPT',
                            style: TextStyle(
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF8A80),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
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
    final double hpRatio = unit.maxHp > 0 ? (unit.hp / unit.maxHp).clamp(0.0, 1.0) : 0.0;
    final double apRatio = (unit.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
    final Color factionColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id || _damagedUnitIds.contains(unit.id);
    final String? floatingPop = _unitFloatingPops[unit.id];

    // Subtle forward step during attack so the sprite animation plays cleanly in the open clash space
    // without crossing over or hiding behind the enemy squad!
    final double lungeY = _is2DGridView ? (isAttacking ? -4.0 : 0.0) : (isAttacking ? (unit.isPlayer ? -14.0 : 14.0) : 0.0);
    final double lungeX = _is2DGridView && isAttacking ? (unit.isPlayer ? 22.0 : -22.0) : 0.0;
    // Directional knockback recoil when taking a hit (pushed backward away from enemy strike)
    final double hitRecoilX = isDamaged ? (unit.isPlayer ? -20.0 : 20.0) : 0.0;
    final double hitShakeY = isDamaged ? -6.0 : 0.0;

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(hitRecoilX + lungeX, lungeY + hitShakeY, 0),
      child: SizedBox(
        width: isBoss ? bossSpanWidth : tileWidth,
        height: isBoss ? modelHeight : tileHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. Tabletop 2.5D Contact Drop Shadow & Soft Ground Glow
            Positioned(
              bottom: 2,
              child: Container(
                width: baseWidth,
                height: baseHeight + (_is2DGridView ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(baseWidth / 2, baseHeight / 2)),
                  gradient: RadialGradient(
                    colors: unit.isDowned
                        ? [
                            const Color(0xFF78909C).withValues(alpha: 0.50), // Cold stone inert plinth
                            const Color(0xFF263238),
                            Colors.transparent,
                          ]
                        : [
                            factionColor.withValues(alpha: isSelected || isAttacking ? 0.75 : 0.35),
                            Colors.black87,
                            Colors.transparent,
                          ],
                  ),
                  border: unit.isDowned
                      ? Border.all(color: const Color(0xFF90A4AE).withValues(alpha: 0.6), width: 1.0)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: unit.isDowned
                          ? const Color(0xFF37474F).withValues(alpha: 0.5)
                          : factionColor.withValues(alpha: isSelected || isAttacking ? 0.6 : 0.2),
                      blurRadius: isSelected || isAttacking ? 8 : 4,
                    ),
                    if (unit.aegisShield > 0)
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.70),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                  ],
                ),
              ),
            ),

            // 1b. Ground plinth in rank_and_rite_2d_battlefield cleanly handles active unit rim/glow.
            // Redundant second yellow circle removed per user request for visual clarity.

            // 2. Character Model Miniature Cutout (Stands proudly upright on diamond plinth)
            Positioned(
              bottom: unit.isDowned ? 2 : 6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: unit.isDowned ? 0.68 : 1.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: unit.isDowned ? 0.94 : 1.0,
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    width: modelWidth,
                    height: modelHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Main Character Sprite (with Stone Petrification / Hit-Flash color filter)
                        Positioned.fill(
                          child: ColorFiltered(
                          colorFilter: unit.isDowned
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
                              ? (_activeSkillName == 'Obsidian Bastion'
                                  ? SpriteSheetAnimation(
                                      assetPath: 'assets/animations/ash_sculptor_defend_sheet.png',
                                      columns: 3,
                                      rows: 2,
                                      totalFrames: 6,
                                      duration: const Duration(milliseconds: 850),
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
                                        duration: const Duration(milliseconds: 900),
                                        loop: false,
                                        fit: BoxFit.contain,
                                        fallback: Image.asset(
                                          unit.assetPath,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ))
                              : (isDamaged && (unit.isAshSculptor || unit.id == 'ash_sculptor' || unit.assetPath.toLowerCase().contains('ash_sculptor')))
                                  ? SpriteSheetAnimation(
                                      assetPath: 'assets/animations/ash_sculptor_defend_sheet.png',
                                      columns: 3,
                                      rows: 2,
                                      totalFrames: 6,
                                      duration: const Duration(milliseconds: 650),
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
                                      duration: const Duration(milliseconds: 1400),
                                      loop: false,
                                      fit: BoxFit.contain,
                                      fallback: Image.asset(
                                        unit.assetPath,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                      ),
                                    )
                              : (unit.isPlayer &&
                                      !unit.isDowned &&
                                      (unit.id.contains('footman') ||
                                          unit.id.contains('tombstone_sentinel') ||
                                          unit.templateId.contains('footman') ||
                                          unit.templateId.contains('tombstone_sentinel') ||
                                          unit.assetPath.toLowerCase().contains('iron_footman')))
                                  ? SpriteSheetAnimation(
                                      assetPath: 'assets/animations/iron_footman_idle_sheet.png',
                                      columns: 3,
                                      rows: 2,
                                      totalFrames: 6,
                                      duration: Duration(milliseconds: isAttacking ? 1200 : 2600),
                                      loop: true,
                                      fit: BoxFit.contain,
                                      fallback: Image.asset(
                                        'assets/images/iron_footman_idle.png',
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                      ),
                                    )
                              : Image.asset(
                                  unit.assetPath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  filterQuality: FilterQuality.medium,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      unit.isPlayer ? Icons.shield : Icons.security,
                                      color: factionColor,
                                      size: isBoss ? 48 : 36,
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

            // 2b. Overhead Enemy Intent Telegraph Badge (Suggestion 2)
            if (!unit.isPlayer && unit.pendingIntent != null && unit.isAlive)
              Positioned(
                top: isBoss ? -34 : -28,
                child: Builder(
                  builder: (context) {
                    final intent = unit.pendingIntent!;
                    final remTicks = (intent.triggerTick - _engine.currentTick).clamp(0, 9999);
                    final remSec = (remTicks / 30.0).toStringAsFixed(1);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
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
                          const SizedBox(width: 2),
                          Text(
                            '${intent.skillName.toUpperCase()} (${remSec}s)',
                            style: const TextStyle(
                              fontSize: 6.5,
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
              ),

            // 3. Status Badges & Selected Unit Indicator (Positioned dynamically above the head of any model)
            // Overhead badges removed to keep hero art completely unobstructed
            // 4. Floating Damage / Effect Pop Text (Live execution with graceful smooth ascent & gentle drift)
            ..._floatingPops.where((p) => p.unitId == unit.id && !p.isExpired).map((pop) {
              final t = pop.progress;
              // Smooth decelerating cubic ascent: rises up to 48 pixels slowly
              final double smoothT = sin(t * 3.14159 / 2);
              final double riseY = smoothT * 48.0;
              // Gentle horizontal drift
              final double driftX = pop.horizontalDrift * smoothT;
              // Opacity curve: visible for first 60%, gentle fade out to 0
              final double opacity = t < 0.60 ? 1.0 : (1.0 - ((t - 0.60) / 0.40)).clamp(0.0, 1.0);
              // Scale bounce on entry
              final double scale = pop.isCrit
                  ? (t < 0.15 ? 1.0 + (t / 0.15) * 0.28 : 1.28 - ((t - 0.15) * 0.20)).clamp(1.0, 1.28)
                  : (t < 0.15 ? 0.85 + (t / 0.15) * 0.15 : 1.0);

              return Positioned(
                bottom: modelHeight + 14 + riseY,
                left: driftX != 0 ? driftX : null,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: pop.isCrit ? 8 : 6,
                        vertical: pop.isCrit ? 3 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0C14).withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: pop.borderColor,
                          width: pop.isCrit ? 1.8 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pop.borderColor.withValues(alpha: pop.isCrit ? 0.65 : 0.40),
                            blurRadius: pop.isCrit ? 10 : 5,
                            spreadRadius: pop.isCrit ? 1.5 : 0.5,
                          ),
                        ],
                      ),
                      child: Text(
                        pop.text,
                        style: TextStyle(
                          color: pop.color,
                          fontWeight: FontWeight.w900,
                          fontSize: pop.fontSize,
                          letterSpacing: pop.isCrit ? 0.8 : 0.4,
                          fontFamily: 'monospace',
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (!_floatingPops.any((p) => p.unitId == unit.id && !p.isExpired) && floatingPop != null)
              Positioned(
                bottom: modelHeight + 14,
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

            // 4b. Tactical Spell Drag Hover: Phantom Damage & Effect Indicator Badge
            if (phantomEffect != null && floatingPop == null)
              Positioned(
                bottom: modelHeight + 16,
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

            // 5. Sleek Compact Tactical Health & AP Meters
            Positioned(
              bottom: 2,
              child: SizedBox(
                width: isBoss ? 56.0 : 36.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sleek 2.5px HP & Armor Bar
                    Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(1.5),
                        border: Border.all(color: Colors.white12, width: 0.3),
                      ),
                      child: Stack(
                        children: [
                          // Base HP: Pure emerald green for player squad, pure vivid crimson/garnet for enemies
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: unit.isPlayer ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                          // Proportional White/Cyan Armor Overlay
                          if (unit.armor > 0)
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (unit.armor / max(1, unit.maxHp)).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(1),
                                  border: Border.all(color: const Color(0xFF00E5FF), width: 0.4),
                                ),
                              ),
                            ),
                          // Aegis Barrier Overlay (Sleek Cyan Bar)
                          if (unit.aegisShield > 0)
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (unit.aegisShield / max(1, unit.maxHp)).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x9900E5FF), blurRadius: 3),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    // AP Turn Meter (1.5px)
                    Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: apRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Aegis Shield Cast Burst (Brief 650ms impact pulse when barrier applied; never encases or hides unit!)
            if (unit.aegisShield > 0)
              Positioned(
                bottom: 4,
                child: IgnorePointer(
                  child: Builder(
                    builder: (context) {
                      final nowMs = DateTime.now().millisecondsSinceEpoch;
                      final isInitialCasting = unit.shieldAppliedMs > 0 && (nowMs - unit.shieldAppliedMs) < 700;
                      if (!isInitialCasting) return const SizedBox.shrink();

                      return SizedBox(
                        width: (modelWidth * 1.15).clamp(80.0, 180.0),
                        height: (modelHeight * 1.15).clamp(80.0, 180.0),
                        child: SpriteSheetAnimation(
                          assetPath: 'assets/animations/vfx/fire_shield_sheet.png',
                          columns: 3,
                          rows: 3,
                          totalFrames: 9,
                          duration: const Duration(milliseconds: 650),
                          loop: false,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
              ),

            if (isDamaged && (floatingPop == null || !floatingPop.contains('+')))
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: isBoss ? bossSpanWidth * 1.8 : tileWidth * 2.3,
                      height: isBoss ? (tileHeight * 3.4) : (tileHeight * 2.9),
                      child: SpriteSheetAnimation(
                        assetPath: (_activeSkillName != null && (_activeSkillName!.contains('Slash') || _activeSkillName!.contains('Lacerat') || _activeSkillName!.contains('Flayer') || _activeSkillName!.contains('Cleave') || _activeSkillName!.contains('Blade') || _activeSkillName!.contains('Crit') || _activeSkillName!.contains('Bleed')))
                            ? 'assets/animations/vfx/crimson_slash_sheet.png'
                            : ((_activeSkillName != null && (_activeSkillName!.contains('Aegis') || _activeSkillName!.contains('Shield') || _activeSkillName!.contains('Phalanx') || _activeSkillName!.contains('Bulwark') || _activeSkillName!.contains('Block')))
                                ? 'assets/animations/vfx/fire_shield_sheet.png'
                                : 'assets/animations/vfx/crimson_slash_sheet.png'),
                        columns: 3,
                        rows: 3,
                        totalFrames: 9,
                        duration: const Duration(milliseconds: 650),
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
    );
  }

  /// Pre-Battle Staging Reserve Dock:
  /// Displays units ready for placement with portraits, roles, stats, and drag-and-drop handles.
  
  Color _getRosterArchetypeColor(Archetype arc) {
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

  void _openRosterSwapSheet(CombatUnitState? targetUnit) {
    if (_reserveUnits.isEmpty) return;
    Archetype? filterArchetype;
    bool filterCommandersOnly = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101016),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFFE5A93C), width: 1.2),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final activeIds = _engine.playerUnits.map((u) => u.id).toSet();
            final availableCandidates = _reserveUnits.where((u) => !activeIds.contains(u.id)).toList();

            final filteredReserves = availableCandidates.where((u) {
              if (filterCommandersOnly && !u.isCommander) return false;
              if (filterArchetype != null && u.archetype != filterArchetype) return false;
              return true;
            }).toList();

            final String headerTitle = targetUnit != null
                ? 'SWAP OUT: ${targetUnit.name.toUpperCase()}'
                : (_engine.playerUnits.length < 5
                    ? 'DEPLOY REINFORCEMENT (${_engine.playerUnits.length}/5 IN SQUAD)'
                    : 'SELECT RESERVE CHAMPION TO SWAP');

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Color(0xFFFFD54F), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              headerTitle,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Filter Role Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRosterFilterChip('👑 COMMANDERS', filterCommandersOnly, () {
                            setSheetState(() {
                              filterCommandersOnly = !filterCommandersOnly;
                            });
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('ALL ROLES', filterArchetype == null && !filterCommandersOnly, () {
                            setSheetState(() {
                              filterArchetype = null;
                              filterCommandersOnly = false;
                            });
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('JUGGERNAUT', filterArchetype == Archetype.juggernaut, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.juggernaut ? null : Archetype.juggernaut);
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('ASSASSIN', filterArchetype == Archetype.assassin, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.assassin ? null : Archetype.assassin);
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('MARKSMAN', filterArchetype == Archetype.marksman, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.marksman ? null : Archetype.marksman);
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('SKIRMISHER', filterArchetype == Archetype.skirmisher, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.skirmisher ? null : Archetype.skirmisher);
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('SUPPORT', filterArchetype == Archetype.support, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.support ? null : Archetype.support);
                          }),
                          const SizedBox(width: 4),
                          _buildRosterFilterChip('OCCULTIST', filterArchetype == Archetype.occultist, () {
                            setSheetState(() => filterArchetype = filterArchetype == Archetype.occultist ? null : Archetype.occultist);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // List of Available Reserve Champions
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
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (ctx, idx) {
                                final candidate = filteredReserves[idx];
                                final arcColor = _getRosterArchetypeColor(candidate.archetype);

                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14141E),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: arcColor.withValues(alpha: 0.5), width: 0.8),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.asset(
                                          candidate.effectiveAvatarAsset,
                                          width: 38,
                                          height: 38,
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
                                                  candidate.name,
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
                                                    'G${candidate.generation}',
                                                    style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 8.0, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: arcColor.withValues(alpha: 0.25),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Text(
                                                    candidate.archetype.name.substring(0, 3).toUpperCase(),
                                                    style: TextStyle(color: arcColor, fontSize: 8.0, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'HP ${candidate.maxHp} • ATK ${candidate.attack} • DEF ${candidate.defense} • SPD ${candidate.speed}',
                                              style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9.0),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (targetUnit == null && _engine.playerUnits.length < 5)
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFFB3261E),
                                          foregroundColor: (targetUnit == null && _engine.playerUnits.length < 5)
                                              ? Colors.black
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(sheetCtx);
                                          _executeUnitSubstitution(targetUnit, candidate);
                                        },
                                        child: Text(
                                          (targetUnit == null && _engine.playerUnits.length < 5) ? '+ ADD UNIT' : 'SWAP',
                                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRosterFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF333344), width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _executeUnitSubstitution(CombatUnitState? outgoingUnit, UnitEntity incomingUnit) {
    // If outgoingUnit is null AND we have open squad slots (under max 5), ADD the unit to the squad
    if (outgoingUnit == null && _engine.playerUnits.length < 5) {
      if (_engine.playerUnits.any((u) => u.id == incomingUnit.id)) return;

      _currentSquadUnits.add(incomingUnit);
      _reserveUnits.removeWhere((u) => u.id == incomingUnit.id);

      final success = _engine.addPlayerUnitFromReserve(incomingUnit, relicService: widget.relicService);
      if (success) {
        _playSfx('sfx_summon.wav');
        widget.onSquadUpdated?.call(List<UnitEntity>.unmodifiable(_currentSquadUnits));
        setState(() {
          _selectedUnitId = incomingUnit.id;
        });
      }
      return;
    }

    final outgoingId = outgoingUnit?.id ?? _engine.playerUnits.firstOrNull?.id;
    if (outgoingId == null) return;

    // 1. Locate replaced entity in _currentSquadUnits (if present)
    final squadIdx = _currentSquadUnits.indexWhere((u) => u.id == outgoingId);
    UnitEntity? replacedEntity;
    if (squadIdx != -1) {
      replacedEntity = _currentSquadUnits[squadIdx];
      _currentSquadUnits[squadIdx] = incomingUnit;
    } else {
      _currentSquadUnits.add(incomingUnit);
    }

    // 2. Update reserve list
    _reserveUnits.removeWhere((u) => u.id == incomingUnit.id);
    if (replacedEntity != null && !_reserveUnits.any((u) => u.id == replacedEntity!.id)) {
      _reserveUnits.add(replacedEntity);
    }

    // 3. Update engine playerUnits
    final success = _engine.swapPlayerUnit(outgoingId, incomingUnit, relicService: widget.relicService);
    if (success) {
      _playSfx('sfx_summon.wav');
      // 4. Notify parent shell to persist updated squad
      widget.onSquadUpdated?.call(List<UnitEntity>.unmodifiable(_currentSquadUnits));
      setState(() {
        _selectedUnitId = incomingUnit.id;
      });
    }
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
                            'RESERVE SQUAD ($deployedCount/$totalCount DEPLOYED)',
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
                  if (_reserveUnits.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _playSfx('sfx_card.wav');
                        // If we have open slots (<5 units in squad), tapping the button opens the deployment sheet to ADD a unit
                        if (_engine.playerUnits.length < 5) {
                          _openRosterSwapSheet(null);
                        } else {
                          final target = _selectedUnitId != null
                              ? _engine.playerUnits.where((u) => u.id == _selectedUnitId).firstOrNull
                              : _engine.playerUnits.firstOrNull;
                          _openRosterSwapSheet(target);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _engine.playerUnits.length < 5
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
                              : const Color(0xFFE5A93C).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: _engine.playerUnits.length < 5
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.8)
                                : const Color(0xFFE5A93C).withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _engine.playerUnits.length < 5 ? Icons.person_add_rounded : Icons.swap_horiz_rounded,
                              size: 11,
                              color: _engine.playerUnits.length < 5 ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _engine.playerUnits.length < 5 ? '+ ADD TO SQUAD' : 'ROSTER SWAP',
                              style: TextStyle(
                                fontSize: 8,
                                color: _engine.playerUnits.length < 5 ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      CrucibleSanctuaryUpgradeDialog.show(context, _engine).then((_) {
                        setState(() {});
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E241E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFFAB40).withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.auto_fix_high, size: 11, color: Color(0xFFFFAB40)),
                          SizedBox(width: 3),
                          Text(
                            'UPGRADES',
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFFFFAB40),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
              // Tactical Formation Presets & Synergy Metrics Strip
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 0.7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 10, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 3),
                          Text(
                            'COVER: ${_engine.coveredAlliesCount}',
                            style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB388FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.4), width: 0.7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on, size: 10, color: Color(0xFFB388FF)),
                          const SizedBox(width: 3),
                          Text(
                            'FLANK: ${_engine.flankingAlliesCount}',
                            style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.w900, color: Color(0xFFB388FF), fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'PRESETS:',
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white54, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 5),
                    _buildPresetChip(
                      label: '🛡️ BASTION',
                      accentColor: const Color(0xFF00E5FF),
                      tooltip: 'Frontline Vanguards provide -25% cover to backline',
                      onTap: () {
                        _playSfx('sfx_block.wav');
                        setState(() {
                          _engine.applyFormationPreset('bastion');
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildPresetChip(
                      label: '⚔️ FLANK',
                      accentColor: const Color(0xFFB388FF),
                      tooltip: 'Wings deployed for +20% Flank Crits',
                      onTap: () {
                        _playSfx('sfx_card.wav');
                        setState(() {
                          _engine.applyFormationPreset('flank');
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildPresetChip(
                      label: '💥 PUNCH',
                      accentColor: const Color(0xFFFFB74D),
                      tooltip: 'Concentrated Center Column 2 Penetration',
                      onTap: () {
                        _playSfx('sfx_slash.wav');
                        setState(() {
                          _engine.applyFormationPreset('punch');
                        });
                      },
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
                  itemCount: livingAllies.length + ((livingAllies.length < 5 && _reserveUnits.isNotEmpty) ? 1 : 0),
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
              '+ ADD HERO',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00E5FF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${_engine.playerUnits.length}/5 DEPLOYED',
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
                  unit.archetype == UnitArchetype.vanguardMelee
                      ? 'Vanguard'
                      : (unit.archetype == UnitArchetype.reachMidline ? 'Skirmisher' : 'Caster'),
                  style: TextStyle(
                    fontSize: 7.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
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
      onDragStarted: () {
        setState(() {
          _draggedUnitId = unit.id;
          _selectedUnitId = unit.id;
          _selectedEnemyUnitId = null;
          _selectedCardId = null;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggedUnitId = null;
          _hoveredTileGRow = null;
          _hoveredTileCol = null;
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: _buildUnitMiniatureWidget(
          unit,
          tileWidth: 88,
          tileHeight: 64,
          colGap: 0,
          isDragging: true,
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
            _selectedCardId = null;
          });
        },
        onLongPress: () {
          _openUnitInspectorDialog(unit);
        },
        child: cardWidget,
      ),
    );
  }

  Widget _buildTacticalHandDock({bool isLandscapeMobile = false}) {
    final double dockHeight = isLandscapeMobile ? 54.0 : 78.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscapeMobile ? 3 : 6),
      decoration: const BoxDecoration(
        color: Color(0xFF14141E),
        border: Border(top: BorderSide(color: Color(0xFF282838), width: 1.5)),
      ),
      child: Row(
        children: [
          // Dynamic Burn Pit: Drag or Tap card here to exhaust for +1 Focus
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data.startsWith('card:'),
            onAcceptWithDetails: (details) {
              final cardId = details.data.replaceFirst('card:', '');
              _engine.burnCard(cardId);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return GestureDetector(
                onTap: () {
                  if (_engine.hand.isNotEmpty) {
                    _engine.burnCard(_engine.hand.first.id);
                  }
                },
                child: Container(
                  width: isLandscapeMobile ? 58 : 72,
                  height: dockHeight,
                  decoration: BoxDecoration(
                    color: isHovered ? const Color(0xFFFF5252).withValues(alpha: 0.35) : const Color(0xFF221115),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHovered ? const Color(0xFFFF5252) : const Color(0xFFB3261E),
                      width: isHovered ? 2.0 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: isHovered ? const Color(0xFFFF5252) : const Color(0xFFB3261E),
                        size: isLandscapeMobile ? 18 : 24,
                      ),
                      if (!isLandscapeMobile) const SizedBox(height: 2),
                      Text(
                        'BURN PIT',
                        style: TextStyle(
                          fontSize: isLandscapeMobile ? 7.5 : 8.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF8A80),
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '+1 FOCUS',
                        style: TextStyle(fontSize: isLandscapeMobile ? 6.5 : 7.5, color: const Color(0xFFFFD54F)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Grimoire Redraw Button (1 Focus cost to cycle hand)
          GestureDetector(
            onTap: () {
              if (_engine.isPreBattlePhase) {
                setState(() {
                  _engine.lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle first!';
                });
                return;
              }
              if (_engine.focus < 1) {
                setState(() {
                  _engine.lastBannerMessage = '⚠️ NEED 1 FOCUS TO REDRAW GRIMOIRE!';
                });
                return;
              }
              _playSfx('sfx_card.wav');
              _engine.redrawHand();
              setState(() {
                _selectedCardId = null;
                _hoveredCardId = null;
              });
            },
            child: Container(
              width: isLandscapeMobile ? 54 : 66,
              height: dockHeight,
              decoration: BoxDecoration(
                color: _engine.focus >= 1 ? const Color(0xFF142434) : const Color(0xFF181C22),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _engine.focus >= 1 ? const Color(0xFF00E5FF) : Colors.white24,
                  width: _engine.focus >= 1 ? 1.2 : 0.8,
                ),
                boxShadow: _engine.focus >= 1
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    color: _engine.focus >= 1 ? const Color(0xFF00E5FF) : Colors.white38,
                    size: isLandscapeMobile ? 18 : 22,
                  ),
                  if (!isLandscapeMobile) const SizedBox(height: 2),
                  Text(
                    'REDRAW',
                    style: TextStyle(
                      fontSize: isLandscapeMobile ? 7.5 : 8.5,
                      fontWeight: FontWeight.w900,
                      color: _engine.focus >= 1 ? const Color(0xFF80D8FF) : Colors.white38,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '1 FOCUS',
                    style: TextStyle(
                      fontSize: isLandscapeMobile ? 6.5 : 7.0,
                      fontWeight: FontWeight.bold,
                      color: _engine.focus >= 1 ? const Color(0xFFFFD54F) : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Cards in Hand
          Expanded(
            child: SizedBox(
              height: dockHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _engine.hand.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final card = _engine.hand[idx];
                  final canAfford = _engine.focus >= card.focusCost;

                    final isCardSelected = _selectedCardId == card.id;

                    return MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          _hoveredCardId = card.id;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          if (_hoveredCardId == card.id) {
                            _hoveredCardId = null;
                          }
                        });
                      },
                      child: Draggable<String>(
                        data: 'card:${card.id}',
                        onDragStarted: () {
                          setState(() {
                            _draggedCard = card;
                            _selectedCardId = null;
                            _hoveredCardId = null;
                          });
                          _engine.setBulletTime(true);
                        },
                        onDragEnd: (_) {
                          setState(() {
                            _draggedCard = null;
                            _hoveredTileGRow = null;
                            _hoveredTileCol = null;
                          });
                          _engine.setBulletTime(false);
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildCardTile(card, canAfford, isFeedback: true, isLandscapeMobile: isLandscapeMobile),
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!canAfford) {
                              setState(() {
                                _engine.lastBannerMessage =
                                    '⚠️ NEED ${card.focusCost} FOCUS (HAVE ${_engine.focus})';
                              });
                              return;
                            }

                            // If card is non-targeted (Stoke the Embers or Wrath of Ashlar), cast immediately!
                            if (card.id == 'stoke_the_embers' || card.id == 'sun_ashlar_wrath') {
                              if (_engine.isPreBattlePhase) {
                                setState(() {
                                  _engine.lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle before casting spells!';
                                });
                                return;
                              }
                              _playSfx('sfx_card.wav');
                              _engine.castCard(card.id);
                              setState(() {
                                _selectedCardId = null;
                              });
                              return;
                            }

                            // If unit is already selected, cast immediately on it!
                            if (card.id == 'phalanx_intercept') {
                              if (_engine.isPreBattlePhase) {
                                setState(() {
                                  _engine.lastBannerMessage = '⚠️ DEPLOYMENT PHASE: Initiate battle before casting spells!';
                                });
                                return;
                              }
                              final targetAlly = _selectedUnitId != null
                                  ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull
                                  : _engine.playerUnits.where((u) => u.isAlive).firstOrNull;
                              if (targetAlly != null) {
                                _playSfx('sfx_card.wav');
                                _engine.castCard(card.id, targetUnit: targetAlly);
                                setState(() {
                                  _selectedCardId = null;
                                });
                                return;
                              }
                            }

                            // Otherwise, toggle card selection for pull-up inspection & click-to-target
                            setState(() {
                              if (_selectedCardId == card.id) {
                                // Double tap on armed card auto-targets primary enemy / Gorgoroth!
                                if (!_engine.isPreBattlePhase) {
                                  final boss = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
                                      _engine.enemyUnits.where((u) => u.isAlive).firstOrNull;
                                  if (boss != null) {
                                    _playSfx('sfx_card.wav');
                                    _engine.castCard(card.id, targetUnit: boss);
                                    _selectedCardId = null;
                                    return;
                                  }
                                }
                                _selectedCardId = null;
                              } else {
                                _playSfx('sfx_card.wav');
                                _selectedCardId = card.id;
                                if (_engine.isPreBattlePhase) {
                                  _engine.lastBannerMessage = '🔍 ${card.name.toUpperCase()} (PULLED UP): Reviewing spell details. Start battle to cast!';
                                } else {
                                  _engine.lastBannerMessage = '✨ ${card.name.toUpperCase()} ARMED: Tap an enemy node or tap CAST SPELL!';
                                }
                              }
                            });
                          },
                          child: _buildCardTile(
                            card,
                            canAfford,
                            isSelected: isCardSelected,
                            isHovered: _hoveredCardId == card.id,
                            isLandscapeMobile: isLandscapeMobile,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildCardTile(
      SpatialCombatCard card,
      bool canAfford, {
      bool isFeedback = false,
      bool isSelected = false,
      bool isHovered = false,
      bool isPulledUp = false,
      bool isLandscapeMobile = false,
    }) {
      final double cardW = isPulledUp
          ? (isLandscapeMobile ? 120.0 : 155.0)
          : (isFeedback ? 85.0 : (isLandscapeMobile ? 68.0 : 78.0));
      final double cardH = isPulledUp
          ? (isLandscapeMobile ? 165.0 : 215.0)
          : (isFeedback ? 120.0 : (isLandscapeMobile ? 62.0 : 76.0));

      final Color borderColor = isSelected || isPulledUp
          ? const Color(0xFFFFD54F)
          : (isHovered
              ? const Color(0xFF00E5FF)
              : (canAfford ? const Color(0xFFD4AF37) : const Color(0xFF383848)));

      return Container(
        width: cardW,
        height: cardH,
        decoration: BoxDecoration(
          color: const Color(0xFF101016),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: isSelected || isFeedback ? 2.0 : 1.0,
          ),
          boxShadow: isFeedback || isSelected
              ? [
                  BoxShadow(
                    color: (isSelected ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF)).withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 1. Dark backing fill
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0D0D14),
              ),
            ),

            // 2. Wargaming Physical Dark-Iron Riveted Frame
            Positioned.fill(
              child: Image.asset(
                'assets/images/Spells/wargaming_card_frame.png',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/Spells/Spell frame template.jpg',
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 3. Central Spell Artwork with BlendMode.multiply to knockout white backgrounds seamlessly!
            Positioned(
              left: cardW * 0.190,
              top: cardH * 0.20,
              width: cardW * 0.620,
              height: cardH * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: const Color(0xFF282838), width: 0.8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.asset(
                    card.assetPath,
                    fit: BoxFit.cover,
                    color: const Color(0xFF202028),
                    colorBlendMode: BlendMode.multiply, // Eliminates white JPG backing!
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF161622),
                      child: const Center(
                        child: Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFFD54F)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Circular Metallic Focus Socket (top-left)
            Positioned(
              top: cardH * 0.04,
              left: cardW * 0.06,
              child: Container(
                width: cardW * 0.22,
                height: cardW * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: canAfford
                        ? const [Color(0xFFFFD54F), Color(0xFFE65100)]
                        : const [Color(0xFF37474F), Color(0xFF1A2327)],
                  ),
                  border: Border.all(
                    color: canAfford ? const Color(0xFFFFE082) : const Color(0xFF546E7A),
                    width: 0.8,
                  ),
                  boxShadow: canAfford
                      ? const [BoxShadow(color: Color(0xFFFFD54F), blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${card.focusCost}',
                    style: TextStyle(
                      color: canAfford ? Colors.black : Colors.white70,
                      fontSize: cardW * 0.12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),

            // 5. Header Plaque: Spell Name
            Positioned(
              top: cardH * 0.05,
              left: cardW * 0.28,
              right: cardW * 0.10,
              height: cardH * 0.12,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    card.name.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0.5, 0.5)),
                      ],
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // 6. Recessed Stone Plaque: Rules Description
            Positioned(
              left: cardW * 0.10,
              right: cardW * 0.10,
              top: cardH * 0.58,
              bottom: cardH * 0.08,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    card.description,
                    style: TextStyle(
                      color: const Color(0xFFF0F0F5),
                      fontSize: isPulledUp ? (isLandscapeMobile ? 9.5 : 11.5) : (cardW * 0.09).clamp(6.0, 9.0),
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 2.0, offset: Offset(0.5, 0.5)),
                      ],
                    ),
                    maxLines: isPulledUp ? 5 : 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildPulledUpCardOverlay({bool isLandscapeMobile = false}) {
    final activeId = _selectedCardId ?? _hoveredCardId;
    if (activeId == null) return const SizedBox.shrink();

    final card = _engine.hand.where((c) => c.id == activeId).firstOrNull;
    if (card == null) return const SizedBox.shrink();

    final canAfford = _engine.focus >= card.focusCost;
    final isArmed = _selectedCardId == card.id;

    // Pattern label helper
    String patternLabel;
    IconData patternIcon;
    switch (card.pattern) {
      case TargetPattern.singleTarget:
        patternLabel = 'SINGLE TARGET';
        patternIcon = Icons.adjust;
        break;
      case TargetPattern.stAshlarCross:
        patternLabel = 'CROSS SPLASH (1 TILE)';
        patternIcon = Icons.flare;
        break;
      case TargetPattern.piercingColumnSkewer:
        patternLabel = 'COLUMN PIERCING';
        patternIcon = Icons.view_column;
        break;
      case TargetPattern.horizontalRowScythe:
        patternLabel = 'ENTIRE ROW';
        patternIcon = Icons.table_rows;
        break;
      case TargetPattern.tShapedCleave:
        patternLabel = 'T-SHAPED CLEAVE';
        patternIcon = Icons.call_split;
        break;
      case TargetPattern.reachMidToFront:
        patternLabel = 'REACH ATTACK';
        patternIcon = Icons.arrow_upward;
        break;
      case TargetPattern.flankShadowLeap:
        patternLabel = 'FLANK SHADOW LEAP';
        patternIcon = Icons.flight_takeoff;
        break;
    }

    return Positioned(
      bottom: isLandscapeMobile ? 12 : 18,
      right: isLandscapeMobile ? 12 : 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLandscapeMobile ? 320 : 380,
          ),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF101018).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isArmed ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isArmed ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF)).withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Card Title & Dismiss Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(patternIcon, size: 14, color: isArmed ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF)),
                      const SizedBox(width: 6),
                      Text(
                        isArmed ? 'SPELL ARMED & PULLED UP' : 'SPELL DETAILS',
                        style: TextStyle(
                          color: isArmed ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCardId = null;
                        _hoveredCardId = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close, size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Body: Enlarged Card Art + Descriptive Meta
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enlarged Card Tile (Pulled-up wargaming frame)
                  _buildCardTile(
                    card,
                    canAfford,
                    isSelected: isArmed,
                    isPulledUp: true,
                    isLandscapeMobile: isLandscapeMobile,
                  ),
                  const SizedBox(width: 10),

                  // Metadata Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFFFE082),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1D2A),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.white24, width: 0.6),
                          ),
                          child: Text(
                            patternLabel,
                            style: const TextStyle(
                              color: Color(0xFF80D8FF),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          card.description,
                          style: const TextStyle(
                            color: Color(0xFFECEFF1),
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 14),
                            const SizedBox(width: 3),
                            Text(
                              'COST: ${card.focusCost} FOCUS',
                              style: TextStyle(
                                color: canAfford ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action Bar
              if (_engine.isPreBattlePhase)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B1D0E),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                  ),
                  child: const Center(
                    child: Text(
                      '⚠️ DEPLOYMENT: Initiate battle to unleash spells',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: Text(
                          canAfford ? 'CAST SPELL' : 'NEED ${card.focusCost} FOCUS',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? const Color(0xFFB8860B) : Colors.white10,
                          foregroundColor: canAfford ? Colors.black : Colors.white38,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: canAfford
                            ? () {
                                _playSfx('sfx_card.wav');
                                if (card.id == 'stoke_the_embers' || card.id == 'sun_ashlar_wrath') {
                                  _engine.castCard(card.id);
                                  setState(() {
                                    _selectedCardId = null;
                                  });
                                  return;
                                }
                                if (card.id == 'phalanx_intercept') {
                                  final targetAlly = _selectedUnitId != null
                                      ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull
                                      : _engine.playerUnits.where((u) => u.isAlive).firstOrNull;
                                  if (targetAlly != null) {
                                    _engine.castCard(card.id, targetUnit: targetAlly);
                                    setState(() {
                                      _selectedCardId = null;
                                    });
                                    return;
                                  }
                                }
                                final targetEnemy = _engine.enemyUnits.where((u) => u.isAlive).firstOrNull;
                                if (targetEnemy != null) {
                                  _engine.castCard(card.id, targetUnit: targetEnemy);
                                  setState(() {
                                    _selectedCardId = null;
                                  });
                                }
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedCardId = null;
                          _hoveredCardId = null;
                        });
                      },
                      child: const Text('DISMISS', style: TextStyle(fontSize: 9.5)),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
      });
      return;
    }

    final currentIndex = livingEnemies.indexWhere((e) => e.id == _selectedEnemyUnitId);
    final nextIndex = (currentIndex + 1) % livingEnemies.length;
    setState(() {
      _selectedEnemyUnitId = livingEnemies[nextIndex].id;
    });
  }

  void _executeHotkeyedAction(String actionType) {
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
        if (skill == null || (!isGenerator && unit.crucibleCinders < skill.cinderCost)) return;
        if (skill.cinderCost >= 80 || skill.actionType.contains('cataclysmic') || skill.actionType.contains('pyre') || skill.actionType.contains('wrath') || skill.actionType.contains('exsanguination') || skill.actionType.contains('spore')) {
          _startForgeStrikeFinisher(unit, explicitTarget);
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
          _startForgeStrikeFinisher(unit, explicitTarget);
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
          final double buttonHeight = isNarrow ? 44.0 : 50.0;

          return Tooltip(
            preferBelow: false,
            message: tooltipMessage,
            child: InkWell(
              onTap: isEnabled ? onPressed : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF131118),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isEnabled
                        ? (isFinisher ? const Color(0xFFFFD54F) : borderColor)
                        : (progress > 0 ? borderColor.withValues(alpha: 0.45) : Colors.white12),
                    width: isEnabled ? (isFinisher ? 1.8 : 1.3) : 0.8,
                  ),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: (isFinisher ? const Color(0xFFFFD54F) : activeColor).withValues(alpha: 0.45),
                            blurRadius: isFinisher ? 10 : 6,
                            spreadRadius: isFinisher ? 1 : 0,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
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
                                    activeColor.withValues(alpha: isEnabled ? 0.90 : 0.45),
                                    activeColor.withValues(alpha: isEnabled ? 0.70 : 0.20),
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
                          bottom: (progress * buttonHeight) - 1.5,
                          child: Container(
                            height: 2.0,
                            decoration: BoxDecoration(
                              color: borderColor.withValues(alpha: 0.85),
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

                      // 3. Button Content: Icon + Title + Subtitle
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 4, vertical: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: isNarrow ? 11 : 13,
                                    color: isEnabled
                                        ? Colors.white
                                        : (progress > 0.4 ? Colors.white70 : Colors.white38),
                                  ),
                                  const SizedBox(width: 2.5),
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: isNarrow ? 7.8 : 9.0,
                                        fontWeight: FontWeight.w900,
                                        color: isEnabled
                                            ? Colors.white
                                            : (progress > 0.4 ? Colors.white.withValues(alpha: 0.85) : Colors.white38),
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: isNarrow ? 6.2 : 7.2,
                                  color: isEnabled
                                      ? (isFinisher ? const Color(0xFFFFD54F) : Colors.white)
                                      : (progress > 0 ? const Color(0xFFFFCC80) : Colors.white24),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
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
                        '⚔️ AUTO +6🔥 ${(unit.currentAp / 100.0).clamp(0.0, 100.0).round()}%',
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.flash_on, size: 9, color: Color(0xFFFF8A80)), SizedBox(width: 2), Text('STALKER (+15% CRIT, +4🔥)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFFCDD2), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isReaverFerocityActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF3E2010), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.whatshot, size: 9, color: Color(0xFFFFB74D)), SizedBox(width: 2), Text('REAVER (+20% ATK, +8🔥)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFFE0B2), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isGraveCarapaceActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF10282E), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF4DD0E1).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.shield, size: 9, color: Color(0xFF4DD0E1)), SizedBox(width: 2), Text('SENTINEL (+35% AEGIS)', style: TextStyle(fontSize: 7.2, color: Color(0xFFE0F7FA), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isAuraOfVitalityActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF102E20), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.favorite, size: 9, color: Color(0xFF69F0AE)), SizedBox(width: 2), Text('MEDICUS (+25% HEAL, +3% REGEN)', style: TextStyle(fontSize: 7.2, color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold))]),
                      ),
                    if (_engine.isSiegeResonatorActive && !isNarrow)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF3E1A10), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.6), width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.filter_hdr, size: 9, color: Color(0xFFFF7043)), SizedBox(width: 2), Text('ARBALEST (+25% AOE)', style: TextStyle(fontSize: 7.2, color: Color(0xFFFFEBE5), fontWeight: FontWeight.bold))]),
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
                        setState(() {
                          _engine.cycleCombatSpeed();
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232538),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), width: 0.8),
                        ),
                        child: Text(
                          '${_engine.combatPacingSpeed.toStringAsFixed(1)}x',
                          style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 8.0, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        CrucibleSkillTreeDialog.show(context, _engine).then((_) {
                          setState(() {});
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF282A3E),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.8), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.account_tree, size: 9, color: Color(0xFFFFD54F)),
                            SizedBox(width: 3),
                            Text(
                              'TREE',
                              style: TextStyle(color: Color(0xFFFFD54F), fontSize: 8.0, fontWeight: FontWeight.w900),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E241E),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFAB40).withValues(alpha: 0.8), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_fix_high, size: 9, color: Color(0xFFFFAB40)),
                            SizedBox(width: 3),
                            Text(
                              'UPGRADE',
                              style: TextStyle(color: Color(0xFFFFAB40), fontSize: 8.0, fontWeight: FontWeight.w900),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _isLogDrawerVisible ? const Color(0xFF37474F) : const Color(0xFF232538),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Text(
                          'LOG',
                          style: TextStyle(color: Colors.white70, fontSize: 8.0, fontWeight: FontWeight.w900),
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
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2C),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSigReady ? const Color(0xFFFFD54F) : Colors.white10,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.asset(
                                        comp.assetPath,
                                        width: 18,
                                        height: 18,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 14, color: Colors.white70),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          comp.name,
                                          style: const TextStyle(fontSize: 7.5, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          comp.signatureSkillName,
                                          style: TextStyle(
                                            fontSize: 6.5,
                                            color: isSigReady ? const Color(0xFFFFD54F) : Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 5),
                                    SizedBox(
                                      height: 19,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSigReady ? const Color(0xFFFF6D00) : const Color(0xFF263238),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                        ),
                                        onPressed: isSigReady
                                            ? () {
                                                setState(() {
                                                  _engine.executeCompanionSignature(comp.id, explicitTarget: explicitTarget);
                                                });
                                              }
                                            : null,
                                        child: Text(
                                          isSigReady ? 'ORDER' : '${comp.signatureCooldown} CD',
                                          style: const TextStyle(fontSize: 7.0, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons Row: 5 Active Cinder Disciplined Commander Abilities
              Row(
                children: List.generate(5, (slotIdx) {
                  final skill = _engine.skillTreeState.getSkillInSlot(slotIdx);
                  if (skill == null) return const SizedBox.shrink();

                  final bool isFinisher = skill.cinderCost >= 80;
                  final bool isGenerator = skill.cinderCost == 0;
                  final int cinderYield = skill.rank >= 3 ? 10 : (skill.rank == 2 ? 8 : 6);
                  final double cdRemaining = _engine.skillTreeState.getCooldownRemaining(skill.id);
                  final bool isOnCooldown = cdRemaining > 0.0;
                  final bool isEnabled = !isOnCooldown && (isGenerator || (unit.crucibleCinders >= skill.cinderCost));
                  final double progress = isGenerator
                      ? 1.0
                      : (unit.crucibleCinders / max(1, skill.cinderCost)).clamp(0.0, 1.0);

                  final String subtitleText = isOnCooldown
                      ? '${cdRemaining.toStringAsFixed(1)}s CD'
                      : (isGenerator
                          ? '+$cinderYield🔥 • STRIKE'
                          : (isEnabled
                              ? '${skill.cinderCost}🔥 • READY'
                              : '${unit.crucibleCinders}/${skill.cinderCost}🔥 ${(progress * 100).toInt()}%'));

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: slotIdx < 4 ? 3.0 : 0.0),
                      child: buildActionButton(
                        title: isNarrow && skill.name.length > 7
                            ? '${skill.name.substring(0, 6)}.'
                            : skill.name.toUpperCase(),
                        subtitle: subtitleText,
                        icon: skill.icon,
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
                            _startForgeStrikeFinisher(unit, explicitTarget);
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

  Widget _buildTurnActionDecisionTray(CombatUnitState unit, {bool isLandscapeMobile = false}) {
    final sculptor = _engine.playerUnits.where((u) => u.isAshSculptor || u.id == 'ash_sculptor').firstOrNull ?? unit;
    return _buildSculptorCommanderTray(sculptor, isLandscapeMobile: isLandscapeMobile);
  }

  // Legacy manual unit tray (retired in Crucible Commander mode)
  Widget _buildLegacyUnitTurnTrayUnused(CombatUnitState unit, {bool isLandscapeMobile = false}) {

    final int curCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 0;
    final int curRow = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.row : 0;
    final explicitTarget = _selectedEnemyUnitId != null
        ? _engine.enemyUnits.where((u) => u.id == _selectedEnemyUnitId && u.isAlive).firstOrNull
        : _getSmartDefaultTarget();

    // Helper: Action 1 - Basic Attack
    Widget buildBasicButton({required bool isNarrow}) {
      return Tooltip(
        preferBelow: false,
        verticalOffset: 28,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 4),
        triggerMode: TooltipTriggerMode.tap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1014),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
        ),
        richMessage: TextSpan(
          children: [
            const TextSpan(
              text: '⚔️ BASIC ATTACK\n',
              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF8A80), fontSize: 11),
            ),
            TextSpan(
              text: 'Deals 100% Attack (${unit.effectiveAttack} DMG) to frontline/column target.\nCharges +15% Ultimate Gauge.',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        child: SizedBox(
          height: isNarrow ? 40 : null,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 6, vertical: isNarrow ? 2 : 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFFFF8A80), width: 1.2),
              ),
            ),
            onPressed: () {
              setState(() {
                _engine.executeUnitAction(
                  unit,
                  isReposition: false,
                  explicitTarget: explicitTarget,
                  actionType: 'basic',
                );
              });
            },
            child: isNarrow
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_mma, size: 11, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            'BASIC',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
                      SizedBox(height: 1),
                      Text(
                        '100% TM',
                        style: TextStyle(fontSize: 6.5, color: Color(0xFFFFCDD2), fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_mma, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '⚔️ [1] BASIC ATTACK\n(STRIKE)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, height: 1.15),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    // Helper: Action 2 - Signature Skill
    Widget buildSignatureButton({required bool isNarrow}) {
      return Tooltip(
        preferBelow: false,
        verticalOffset: 28,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 4),
        triggerMode: TooltipTriggerMode.tap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1026),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEA80FC), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
        ),
        richMessage: TextSpan(
          children: [
            TextSpan(
              text: '★ [2] ${unit.signatureSkillName.toUpperCase()}\n',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA80FC), fontSize: 11),
            ),
            TextSpan(
              text: '${unit.signatureSkillDescription}\nCooldown: 2 Turns (Charges +25% Ultimate Gauge)',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        child: SizedBox(
          height: isNarrow ? 40 : null,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: unit.isSignatureReady ? const Color(0xFF7B1FA2) : const Color(0xFF2C253B),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 6, vertical: isNarrow ? 2 : 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: unit.isSignatureReady ? const Color(0xFFEA80FC) : Colors.white24,
                  width: 1.2,
                ),
              ),
            ),
            onPressed: unit.isSignatureReady
                ? () {
                    setState(() {
                      _engine.executeUnitAction(
                        unit,
                        isReposition: false,
                        explicitTarget: explicitTarget,
                        actionType: 'signature',
                      );
                    });
                  }
                : null,
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(unit.isSignatureReady ? Icons.auto_awesome : Icons.timer, size: 11, color: Colors.white),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              unit.signatureSkillName.toUpperCase(),
                              style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.w900, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        unit.isSignatureReady ? 'READY' : '${unit.signatureCooldown}T CD',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: unit.isSignatureReady ? const Color(0xFFE1BEE7) : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(unit.isSignatureReady ? Icons.auto_awesome : Icons.timer, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        unit.isSignatureReady
                            ? '★ ${unit.signatureSkillName.toUpperCase()}\n(READY!)'
                            : '★ ${unit.signatureSkillName.toUpperCase()}\n(${unit.signatureCooldown} Turns CD)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          color: unit.isSignatureReady ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    // Helper: Action 3 - Ultimate Ability
    Widget buildUltimateButton({required bool isNarrow}) {
      return Tooltip(
        preferBelow: false,
        verticalOffset: 28,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 4),
        triggerMode: TooltipTriggerMode.tap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF262010),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
        ),
        richMessage: TextSpan(
          children: [
            TextSpan(
              text: '⚡ ${unit.ultimateTitle.toUpperCase()}\n',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD54F), fontSize: 11),
            ),
            TextSpan(
              text: '${unit.ultimateDescription}\nCooldown: 3 Turns (Skill-based cooldown, ready at battle opening)',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        child: SizedBox(
          height: isNarrow ? 40 : null,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: unit.isUltimateReady ? const Color(0xFFFFD54F) : const Color(0xFF262C38),
              foregroundColor: unit.isUltimateReady ? Colors.black : Colors.white54,
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 6, vertical: isNarrow ? 2 : 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: unit.isUltimateReady ? const Color(0xFFFFE082) : Colors.white24,
                  width: 1.2,
                ),
              ),
            ),
            onPressed: unit.isUltimateReady
                ? () {
                    setState(() {
                      _engine.executeUnitAction(
                        unit,
                        isReposition: false,
                        explicitTarget: explicitTarget,
                        actionType: 'ultimate',
                      );
                    });
                  }
                : null,
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(unit.isUltimateReady ? Icons.bolt : Icons.hourglass_top,
                              size: 11, color: unit.isUltimateReady ? Colors.black : Colors.white38),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              unit.ultimateTitle.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w900,
                                color: unit.isUltimateReady ? Colors.black : Colors.white54,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        unit.isUltimateReady ? 'READY' : '${unit.ultimateCooldown}T CD',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: unit.isUltimateReady ? const Color(0xFF3E2723) : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(unit.isUltimateReady ? Icons.bolt : Icons.hourglass_top, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        unit.isUltimateReady
                            ? '⚡ [3] ${unit.ultimateTitle.toUpperCase()}\n(READY!)'
                            : '⚡ [3] ${unit.ultimateTitle.toUpperCase()}\n(${unit.ultimateCooldown} Turns CD)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          color: unit.isUltimateReady ? const Color(0xFF212121) : Colors.white54,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    // Helper: Action 4 - Shift / Reposition
    Widget buildShiftButton({required bool isNarrow}) {
      return PopupMenuButton<String>(
        tooltip: 'Shift 1 tile along rank or column',
        color: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
        onSelected: (dir) {
          int targetCol = curCol;
          int targetRow = curRow;
          if (dir == 'front' && curRow > 0) targetRow--;
          if (dir == 'back' && curRow < 2) targetRow++;
          if (dir == 'left' && curCol > 0) targetCol--;
          if (dir == 'right' && curCol < 4) targetCol++;

          setState(() {
            _engine.executeUnitAction(
              unit,
              isReposition: true,
              shiftCol: targetCol,
              shiftRow: targetRow,
            );
          });
        },
        itemBuilder: (context) => [
          if (curRow > 0)
            const PopupMenuItem(
              value: 'front',
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 8),
                  Text('Advance to Frontline', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (curRow < 2)
            const PopupMenuItem(
              value: 'back',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 8),
                  Text('Fall Back 1 Rank', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (curCol > 0)
            const PopupMenuItem(
              value: 'left',
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 8),
                  Text('Shift Left (Col)', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (curCol < 4)
            const PopupMenuItem(
              value: 'right',
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 8),
                  Text('Shift Right (Col)', style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
        ],
        child: Container(
          height: isNarrow ? 40 : null,
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 2 : 4, vertical: isNarrow ? 2 : 8),
          decoration: BoxDecoration(
            color: const Color(0xFF006064),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Color(0xFFE0F7FA), size: 12),
                  const SizedBox(width: 2),
                  Text(
                    'SHIFT',
                    style: TextStyle(fontSize: isNarrow ? 8.5 : 9.5, fontWeight: FontWeight.w900, color: const Color(0xFFE0F7FA)),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '25% TM',
                style: TextStyle(fontSize: isNarrow ? 6.5 : 7.5, color: const Color(0xFF80DEEA), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 10, vertical: isNarrow ? 5 : 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1926),
            border: Border(
              top: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.6), width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tier 1: Hero Header & Target Bar (Ultra-clean, 20px)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              unit.assetPath,
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFFFFD54F), size: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'TURN READY',
                              style: TextStyle(fontSize: 7.0, color: Colors.black, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              unit.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const Spacer(),
                          if (explicitTarget != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3E1E24),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.6), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.gps_fixed, size: 8, color: Color(0xFFFF8A80)),
                                  const SizedBox(width: 3),
                                  Text(
                                    explicitTarget.name,
                                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 7.5, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Tier 2: 4 Action Buttons spanning the full width
                    Row(
                      children: [
                        Expanded(child: buildBasicButton(isNarrow: true)),
                        const SizedBox(width: 4),
                        Expanded(child: buildSignatureButton(isNarrow: true)),
                        const SizedBox(width: 4),
                        Expanded(child: buildUltimateButton(isNarrow: true)),
                        const SizedBox(width: 4),
                        Expanded(child: buildShiftButton(isNarrow: true)),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Unit Avatar & Turn Ready Indicator (Desktop)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              unit.assetPath,
                              width: isLandscapeMobile ? 28 : 38,
                              height: isLandscapeMobile ? 28 : 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFFFFD54F), size: 24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD54F),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: const Text(
                                      'TURN READY (10,000 TM)',
                                      style: TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF37474F),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: const Color(0xFF90A4AE), width: 0.5),
                                    ),
                                    child: Text(
                                      unit.archetype.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 6.5, color: Color(0xFFECEFF1), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                unit.name.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Col ${curCol + 1}, Row ${curRow == 0 ? "Front" : (curRow == 1 ? "Mid" : "Back")}',
                                style: const TextStyle(color: Colors.white54, fontSize: 8.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(child: buildBasicButton(isNarrow: false)),
                    const SizedBox(width: 6),
                    Expanded(child: buildSignatureButton(isNarrow: false)),
                    const SizedBox(width: 6),
                    Expanded(child: buildUltimateButton(isNarrow: false)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: isLandscapeMobile ? 86 : 96,
                      child: buildShiftButton(isNarrow: false),
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

  Widget _buildCombatLogConsole() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: const Color(0xFF0A0A10),
      child: ListView.builder(
        itemCount: _engine.combatLogs.length,
        itemBuilder: (context, idx) {
          final log = _engine.combatLogs[idx];
          final isCrit = log.contains('CRITICAL') || log.contains('SHATTERS');
          final isTelegraph = log.contains('TELEGRAPH') || log.contains('⚠️');

          return Text(
            log,
            style: TextStyle(
              fontSize: 8.5,
              color: isCrit
                  ? const Color(0xFFFFD54F)
                  : (isTelegraph ? const Color(0xFFFF5252) : Colors.white60),
              fontFamily: 'monospace',
            ),
          );
        },
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

  void _startForgeStrikeFinisher(CombatUnitState unit, CombatUnitState? explicitTarget) {
    if (_engine.isAutoBattleMode) {
      _engine.executeUnitAction(
        unit,
        isReposition: false,
        explicitTarget: explicitTarget,
        actionType: 'cataclysmic_pyre_crit',
      );
      return;
    }

    setState(() {
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
      _triggerScreenShake(intensity: 24.0);
    } else {
      _triggerScreenShake(intensity: 12.0);
    }

    Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _isForgeStrikeActive = false;
      });
      if (_forgeStrikeUnit != null) {
        _engine.executeUnitAction(
          _forgeStrikeUnit!,
          isReposition: false,
          explicitTarget: _forgeStrikeTarget,
          actionType: isPerfect ? 'cataclysmic_pyre_crit' : 'cataclysmic_pyre',
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

}

class IsometricDiamondTilePainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hasGlow;
  final Color glowColor;

  const IsometricDiamondTilePainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1.2,
    this.hasGlow = false,
    this.glowColor = const Color(0xFFFF1744),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Main 2:1 Isometric Diamond Face
    final diamondPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.5)
      ..close();

    // Glow effect (telegraphed zones, selected, or reachable moves)
    if (hasGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawPath(diamondPath, glowPaint);
    }

    // Translucent face fill preserving underlying scene
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, fillPaint);

    // Inner bevel highlight on upper edges
    final innerBevelPath = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5);
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(innerBevelPath, bevelPaint);

    // Diamond Perimeter Border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(diamondPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant IsometricDiamondTilePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasGlow != hasGlow ||
        oldDelegate.glowColor != glowColor;
  }
}

/// 2.5D Multi-Node Behemoth Double-Diamond Ground Plinth Painter
/// Draws a continuous combined perimeter footprint across Col 1 & Col 2 (1x2 unit)
class IsometricDoubleDiamondPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool hasGlow;
  final Color glowColor;

  const IsometricDoubleDiamondPainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 1.5,
    this.hasGlow = false,
    this.glowColor = const Color(0xFFFF1744),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Contact drop shadow below double-diamond footprint
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    final shadowPath = Path()
      ..moveTo(w * 0.25, h * 0.08)
      ..lineTo(w * 0.75, h * 0.08)
      ..lineTo(w * 0.98, h * 0.54)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(w * 0.02, h * 0.54)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    if (hasGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(shadowPath, glowPaint);
    }

    // Combined 1x2 hexagonal / double-diamond perimeter footprint
    final footPath = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor.withValues(alpha: 0.85),
          fillColor.withValues(alpha: 0.40),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(footPath, fillPaint);

    // Bevel top highlights
    final bevelPath = Path()
      ..moveTo(0, h * 0.5)
      ..lineTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5);
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bevelPath, bevelPaint);

    // Center internal junction dashed hint between the 2 tiles
    final junctionPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), junctionPaint);

    // Footprint perimeter outline
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(footPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant IsometricDoubleDiamondPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasGlow != hasGlow ||
        oldDelegate.glowColor != glowColor;
  }
}

class _IsometricCellData {
  final int gRow;
  final int col;
  final int localRow;
  final bool isClashLine;
  final bool isPlayerSquad;
  final int depth;
  final double screenX;
  final double screenY;

  const _IsometricCellData({
    required this.gRow,
    required this.col,
    required this.localRow,
    required this.isClashLine,
    required this.isPlayerSquad,
    required this.depth,
    required this.screenX,
    required this.screenY,
  });
}

/// Dynamic kinetic VFX effect rendered over the battlefield
class _CombatVfx {
  final String id;
  final Offset startOffset;
  final Offset targetOffset;
  final Color primaryColor;
  final Color secondaryColor;
  final String type; // 'slash', 'beam', 'shockwave', 'shatter'
  final int durationMs;
  final int createdMs;

  const _CombatVfx({
    required this.id,
    required this.startOffset,
    required this.targetOffset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.type,
    required this.durationMs,
    required this.createdMs,
  });
}

/// Custom painter for directional strike beams, slashes, and impact shockwaves
class _CombatVfxOverlayPainter extends CustomPainter {
  final List<_CombatVfx> effects;
  final int currentTimestampMs;

  const _CombatVfxOverlayPainter({
    required this.effects,
    required this.currentTimestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final vfx in effects) {
      final elapsed = currentTimestampMs - vfx.createdMs;
      if (elapsed < 0 || elapsed > vfx.durationMs) continue;
      final progress = (elapsed / vfx.durationMs).clamp(0.0, 1.0);

      switch (vfx.type) {
        case 'slash':
          _drawSlash(canvas, vfx, progress);
          break;
        case 'beam':
          _drawBeam(canvas, vfx, progress);
          break;
        case 'arrow':
          _drawProjectile(canvas, vfx, progress, isArrow: true);
          break;
        case 'firebolt':
          _drawProjectile(canvas, vfx, progress, isArrow: false);
          break;
        case 'shockwave':
        case 'shatter':
          _drawShockwave(canvas, vfx, progress);
          break;
        case 'bloodnova':
          _drawBloodnova(canvas, vfx, progress);
          break;
        case 'bloodsiphon':
          _drawBloodsiphon(canvas, vfx, progress);
          break;
        case 'rune_invocation':
          _drawRuneInvocation(canvas, vfx, progress);
          break;
        case 'death_bleed':
        case 'death_solar':
        case 'death_kinetic':
        case 'death_boss':
          _drawDeathBurst(canvas, vfx, progress);
          break;
      }
    }
  }

  void _drawBloodnova(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final maxRadius = 85.0;
    final currentRadius = maxRadius * progress;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Expanding blood mist wave
    final mistPaint = Paint()
      ..color = const Color(0xFFFF1744).withAlpha((alpha * 0.45).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, currentRadius * 0.7, mistPaint);

    // Jagged crimson detonation ring
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4.5 * (1.0 - progress)).clamp(1.0, 5.0);
    canvas.drawCircle(center, currentRadius, ringPaint);

    // Detonating blood spikes radiating outwards
    final spikePaint = Paint()
      ..color = const Color(0xFFFF5252).withAlpha(alpha)
      ..strokeWidth = (3.0 * (1.0 - progress)).clamp(1.0, 3.5)
      ..strokeCap = StrokeCap.round;
    const int numSpikes = 8;
    for (int i = 0; i < numSpikes; i++) {
      final angle = (i * 3.14159 * 2) / numSpikes + (progress * 0.4);
      final rInner = currentRadius * 0.5;
      final rOuter = currentRadius * (1.1 + (i % 2 == 0 ? 0.2 : 0.05));
      final p1 = Offset(center.dx + cos(angle) * rInner, center.dy + sin(angle) * rInner);
      final p2 = Offset(center.dx + cos(angle) * rOuter, center.dy + sin(angle) * rOuter);
      canvas.drawLine(p1, p2, spikePaint);
    }
  }

  void _drawBloodsiphon(Canvas canvas, _CombatVfx vfx, double progress) {
    final start = vfx.startOffset; // Caster or ally receiving heal
    final target = vfx.targetOffset; // Bleeding enemy being siphoned
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Spiral / curved crimson tendril siphoning from target to caster
    final path = Path();
    path.moveTo(target.dx, target.dy);
    final midX = (target.dx + start.dx) * 0.5 + sin(progress * 3.14159 * 2) * 35.0;
    final midY = (target.dy + start.dy) * 0.5 - 25.0;
    path.quadraticBezierTo(midX, midY, start.dx, start.dy);

    final tendrilPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.5 * (1.0 - progress)).clamp(1.2, 4.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, tendrilPaint);

    // Inner bright leech core
    final corePaint = Paint()
      ..color = Colors.white.withAlpha((alpha * 0.75).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * (1.0 - progress)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);

    // Impact blood droplet burst on target
    final burstRadius = 16.0 * progress;
    final burstPaint = Paint()
      ..color = const Color(0xFFD50000).withAlpha((alpha * 0.8).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(target, burstRadius, burstPaint);
  }

  void _drawSlash(Canvas canvas, _CombatVfx vfx, double progress) {
    final target = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final slashLen = 50.0 + progress * 20.0;

    // Glowing impact slash arc
    final paint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..strokeWidth = (4.0 * (1.0 - progress)).clamp(1.0, 4.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final p1 = Offset(target.dx - slashLen * 0.5, target.dy - slashLen * 0.4);
    final p2 = Offset(target.dx + slashLen * 0.5, target.dy + slashLen * 0.4);
    canvas.drawLine(p1, p2, paint);

    // Cross-slash spark
    final crossPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.8).round())
      ..strokeWidth = 2.0 * (1.0 - progress)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cp1 = Offset(target.dx + slashLen * 0.35, target.dy - slashLen * 0.35);
    final cp2 = Offset(target.dx - slashLen * 0.35, target.dy + slashLen * 0.35);
    canvas.drawLine(cp1, cp2, crossPaint);

    // Impact burst flash circle
    if (progress < 0.4) {
      final flashRadius = 14.0 * (progress / 0.4);
      final flashPaint = Paint()
        ..color = Colors.white.withAlpha(((1.0 - (progress / 0.4)) * 200).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, flashRadius, flashPaint);
    }
  }

  void _drawProjectile(Canvas canvas, _CombatVfx vfx, double progress, {required bool isArrow}) {
    final start = vfx.startOffset;
    final target = vfx.targetOffset;

    // Ballistic / direct projectile flight interpolation
    final double flightT = (progress / 0.82).clamp(0.0, 1.0);
    // Slight parabolic arc
    final double arcHeight = isArrow ? -28.0 : -18.0;
    final double currentX = start.dx + (target.dx - start.dx) * flightT;
    final double currentY = start.dy + (target.dy - start.dy) * flightT + sin(flightT * 3.14159) * arcHeight;
    final currentPos = Offset(currentX, currentY);

    // Calculate heading angle
    final double dx = target.dx - start.dx;
    final double dy = target.dy - start.dy + (cos(flightT * 3.14159) * arcHeight);
    final double angle = atan2(dy, dx);

    final int alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    if (flightT < 1.0) {
      if (isArrow) {
        // High-velocity arrow / bolt with tracer tail
        final double tailLength = 22.0;
        final tailPos = Offset(currentX - cos(angle) * tailLength, currentY - sin(angle) * tailLength);

        // Motion trail
        final trailPaint = Paint()
          ..color = vfx.primaryColor.withAlpha((alpha * 0.45).round())
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tailPos, currentPos, trailPaint);

        // Arrow shaft & glowing tip
        final arrowPaint = Paint()
          ..color = Colors.white.withAlpha(alpha)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tailPos, currentPos, arrowPaint);

        // Arrow head spark
        final headPaint = Paint()
          ..color = vfx.primaryColor.withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(currentPos, 3.2, headPaint);
      } else {
        // Glowing magic firebolt / orb with smoke embers
        final orbRadius = 6.5;
        // Outer fiery halo
        final haloPaint = Paint()
          ..color = vfx.primaryColor.withAlpha((alpha * 0.55).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(currentPos, orbRadius * 1.6, haloPaint);

        // Core bolt
        final corePaint = Paint()
          ..color = vfx.secondaryColor.withAlpha(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(currentPos, orbRadius, corePaint);

        // Center white-hot spark
        canvas.drawCircle(currentPos, orbRadius * 0.45, Paint()..color = Colors.white.withAlpha(alpha));

        // Trailing particles
        final trailOffset = Offset(currentX - cos(angle) * 14.0, currentY - sin(angle) * 14.0);
        canvas.drawCircle(trailOffset, orbRadius * 0.5, Paint()..color = vfx.primaryColor.withAlpha((alpha * 0.4).round()));
      }
    } else {
      // Impact burst at target location when projectile lands!
      final burstP = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      final burstRadius = (isArrow ? 18.0 : 28.0) * burstP;
      final burstAlpha = ((1.0 - burstP) * 240).round().clamp(0, 255);

      final burstPaint = Paint()
        ..color = vfx.primaryColor.withAlpha(burstAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.0 * (1.0 - burstP)).clamp(1.0, 3.5);
      canvas.drawCircle(target, burstRadius, burstPaint);

      // Core flash
      if (burstP < 0.5) {
        final coreFlashPaint = Paint()
          ..color = Colors.white.withAlpha(((1.0 - burstP / 0.5) * 220).round())
          ..style = PaintingStyle.fill;
        canvas.drawCircle(target, burstRadius * 0.6, coreFlashPaint);
      }
    }
  }

  void _drawBeam(Canvas canvas, _CombatVfx vfx, double progress) {
    final start = vfx.startOffset;
    final target = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Primary energy tracer beam
    final beamPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..strokeWidth = (5.0 * (1.0 - progress * 0.7)).clamp(1.5, 6.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, target, beamPaint);

    // Bright core line
    final corePaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..strokeWidth = 2.0 * (1.0 - progress)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, target, corePaint);

    // Target burst
    final burstRadius = 18.0 * progress;
    final burstPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.7).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(target, burstRadius, burstPaint);
  }

  void _drawShockwave(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final maxRadius = vfx.type == 'shatter' ? 65.0 : 45.0;
    final currentRadius = maxRadius * progress;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);

    // Outer shock ring
    final ringPaint = Paint()
      ..color = vfx.primaryColor.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.5 * (1.0 - progress)).clamp(0.8, 4.0);
    canvas.drawCircle(center, currentRadius, ringPaint);

    // Inner bright harmonic wave
    if (progress > 0.2) {
      final innerProgress = (progress - 0.2) / 0.8;
      final innerAlpha = ((1.0 - innerProgress) * 200).round().clamp(0, 255);
      final innerPaint = Paint()
        ..color = vfx.secondaryColor.withAlpha(innerAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius * 0.65, innerPaint);
    }

    // Shatter shards for critical armor crack
    if (vfx.type == 'shatter') {
      final shardPaint = Paint()
        ..color = const Color(0xFFFFD54F).withAlpha(alpha)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final angle = (i * 3.14159 * 2) / 6;
        final d1 = currentRadius * 0.7;
        final d2 = currentRadius * 1.15;
        final p1 = Offset(center.dx + cos(angle) * d1, center.dy + sin(angle) * d1);
        final p2 = Offset(center.dx + cos(angle) * d2, center.dy + sin(angle) * d2);
        canvas.drawLine(p1, p2, shardPaint);
      }
    }
  }

  void _drawRuneInvocation(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.startOffset; // Centered at caster plinth
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final currentRadius = 28.0 + (progress * 18.0);

    // 1. Concentric rotating invocation runic circle
    final outerRing = Paint()
      ..color = vfx.primaryColor.withAlpha((alpha * 0.85).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * (1.0 - progress * 0.5);
    canvas.drawCircle(center, currentRadius, outerRing);

    final innerRing = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.65).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, currentRadius * 0.65, innerRing);

    // 2. Rotating runic rays
    final rayPaint = Paint()
      ..color = vfx.secondaryColor.withAlpha((alpha * 0.75).round())
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const int rayCount = 6;
    final double spinAngle = progress * 3.14159;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 3.14159 * 2) / rayCount + spinAngle;
      final p1 = Offset(center.dx + cos(angle) * (currentRadius * 0.65), center.dy + sin(angle) * (currentRadius * 0.65));
      final p2 = Offset(center.dx + cos(angle) * (currentRadius * 1.15), center.dy + sin(angle) * (currentRadius * 1.15));
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 3. Central incantation flare burst
    if (progress < 0.45) {
      final burstT = progress / 0.45;
      final flarePaint = Paint()
        ..color = Colors.white.withAlpha(((1.0 - burstT) * 220).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12.0 * burstT, flarePaint);
    }
  }

  void _drawDeathBurst(Canvas canvas, _CombatVfx vfx, double progress) {
    final center = vfx.targetOffset;
    final alpha = ((1.0 - progress) * 255).round().clamp(0, 255);
    final count = vfx.type == 'death_boss' ? 24 : 14;
    final maxDist = vfx.type == 'death_boss' ? 85.0 : 55.0;

    // Expanding shock perimeter
    final shockPaint = Paint()
      ..color = vfx.primaryColor.withAlpha((alpha * 0.7).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.0 - progress) * 3.5;
    canvas.drawCircle(center, maxDist * progress, shockPaint);

    // Radiating ember/splatter particles
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * 3.14159 / count)) + (progress * 0.8);
      final dist = (maxDist * 0.3) + (maxDist * 0.7 * progress);
      final px = center.dx + (cos(angle) * dist);
      final py = center.dy + (sin(angle) * dist * 0.55); // Isometric squash
      final pRadius = (vfx.type == 'death_boss' ? 5.5 : 3.5) * (1.0 - progress);

      final pPaint = Paint()
        ..color = (i % 2 == 0 ? vfx.primaryColor : vfx.secondaryColor).withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), max(0.8, pRadius), pPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CombatVfxOverlayPainter oldDelegate) {
    return true;
  }
}

class _TrajectoryData {
  final Offset sourceOffset;
  final Offset targetOffset;
  final String skillName;
  final String targetName;
  final Color color;
  final bool isSecondary;
  final bool showLabel;
  final bool isArcPath;
  final String? labelPrefix;
  final bool isCoverCord;

  const _TrajectoryData({
    required this.sourceOffset,
    required this.targetOffset,
    required this.skillName,
    required this.targetName,
    required this.color,
    this.isSecondary = false,
    this.showLabel = true,
    this.isArcPath = false,
    this.labelPrefix,
    this.isCoverCord = false,
  });
}

class _AttackTrajectoryOverlayPainter extends CustomPainter {
  final List<_TrajectoryData> trajectories;
  final double dashPhase;

  const _AttackTrajectoryOverlayPainter({
    required this.trajectories,
    this.dashPhase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final traj in trajectories) {
      _paintSingleTrajectory(canvas, traj);
    }
  }

  void _paintSingleTrajectory(Canvas canvas, _TrajectoryData traj) {
    final sourceOffset = traj.sourceOffset;
    final targetOffset = traj.targetOffset;
    final trajectoryColor = traj.color;
    final isSecondary = traj.isSecondary;

    final dx = targetOffset.dx - sourceOffset.dx;
    final dy = targetOffset.dy - sourceOffset.dy;
    final distance = sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;

    // Slight upward isometric curve
    final controlPoint = Offset(
      (sourceOffset.dx + targetOffset.dx) * 0.5,
      (sourceOffset.dy + targetOffset.dy) * 0.5 - min(30.0, distance * 0.12),
    );

    if (traj.isCoverCord) {
      // Defensive Vanguard Cover Cord: Glowing cyan tether connecting Frontline Vanguard to Covered Ally
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      final corePaint = Paint()
        ..color = const Color(0xFF80D8FF).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final brightCorePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;

      const int numSegments = 20;
      for (int i = 0; i < numSegments; i += 2) {
        final rawT1 = (i / numSegments + dashPhase) % 1.0;
        final rawT2 = rawT1 + (1.0 / numSegments);
        final t1 = rawT1.clamp(0.0, 1.0);
        final t2 = rawT2.clamp(0.0, 1.0);
        if (t2 <= t1) continue;

        final p1 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t1);
        final p2 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t2);

        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, corePaint);
        canvas.drawLine(p1, p2, brightCorePaint);
      }

      final anchorPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(sourceOffset, 6.0, anchorPaint);
      canvas.drawCircle(targetOffset, 6.0, anchorPaint);

      final midPoint = _evaluateBezier(sourceOffset, controlPoint, targetOffset, 0.5);
      final textSpan = const TextSpan(
        text: '🛡️ COVER (-25%)',
        style: TextStyle(
          color: Color(0xFF80D8FF),
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: midPoint,
          width: textPainter.width + 10.0,
          height: 15.0,
        ),
        const Radius.circular(3.0),
      );

      canvas.drawRRect(pillRect, Paint()..color = const Color(0xEE0B1A24));
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );

      textPainter.paint(
        canvas,
        Offset(midPoint.dx - textPainter.width * 0.5, midPoint.dy - textPainter.height * 0.5),
      );
      return;
    }

    final double alphaScale = isSecondary ? 0.65 : 1.0;

    // 1. Source node ring
    if (!isSecondary) {
      final sourcePaint = Paint()
        ..color = trajectoryColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(sourceOffset, 10.0, sourcePaint);
      canvas.drawCircle(sourceOffset, 3.5, Paint()..color = trajectoryColor.withValues(alpha: 0.9));
    }

    // 2. Translucent dashed trajectory path with animated dashPhase
    final glowPaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.25 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 4.0 : 6.0
      ..strokeCap = StrokeCap.round;

    final corePaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.85 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 1.5 : 2.2
      ..strokeCap = StrokeCap.round;

    final brightCorePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 0.7 : 1.0
      ..strokeCap = StrokeCap.round;

    // Sample quadratic bezier path points for animated dashes
    const int numSegments = 24;
    for (int i = 0; i < numSegments; i += 2) {
      final rawT1 = (i / numSegments + dashPhase) % 1.0;
      final rawT2 = rawT1 + (1.0 / numSegments);
      final t1 = rawT1.clamp(0.0, 1.0);
      final t2 = rawT2.clamp(0.0, 1.0);
      if (t2 <= t1) continue;

      final p1 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t1);
      final p2 = _evaluateBezier(sourceOffset, controlPoint, targetOffset, t2);

      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, corePaint);
      canvas.drawLine(p1, p2, brightCorePaint);
    }

    // 3. Arrowhead at target
    const double tPrev = 0.90;
    final pPrev = _evaluateBezier(sourceOffset, controlPoint, targetOffset, tPrev);
    final angle = atan2(targetOffset.dy - pPrev.dy, targetOffset.dx - pPrev.dx);
    final arrowLen = isSecondary ? 9.0 : 12.0;
    const arrowAngle = pi / 5; // 36 deg

    final arrowLeft = Offset(
      targetOffset.dx - arrowLen * cos(angle - arrowAngle),
      targetOffset.dy - arrowLen * sin(angle - arrowAngle),
    );
    final arrowRight = Offset(
      targetOffset.dx - arrowLen * cos(angle + arrowAngle),
      targetOffset.dy - arrowLen * sin(angle + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(targetOffset.dx, targetOffset.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy);

    canvas.drawPath(arrowPath, glowPaint);
    canvas.drawPath(arrowPath, corePaint);

    // 4. Target reticle diamond and crosshairs
    final double r = isSecondary ? 12.0 : 16.0;
    final reticlePath = Path()
      ..moveTo(targetOffset.dx, targetOffset.dy - r)
      ..lineTo(targetOffset.dx + r * 1.5, targetOffset.dy)
      ..lineTo(targetOffset.dx, targetOffset.dy + r)
      ..lineTo(targetOffset.dx - r * 1.5, targetOffset.dy)
      ..close();

    final reticleGlow = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.28 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 3.5 : 5.0;
    final reticleCore = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.95 * alphaScale)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSecondary ? 1.3 : 1.8;

    canvas.drawPath(reticlePath, reticleGlow);
    canvas.drawPath(reticlePath, reticleCore);

    // Crosshairs
    final chPaint = Paint()
      ..color = trajectoryColor.withValues(alpha: 0.9 * alphaScale)
      ..strokeWidth = isSecondary ? 1.1 : 1.5;
    canvas.drawLine(Offset(targetOffset.dx - r * 1.8, targetOffset.dy), Offset(targetOffset.dx - r * 1.2, targetOffset.dy), chPaint);
    canvas.drawLine(Offset(targetOffset.dx + r * 1.2, targetOffset.dy), Offset(targetOffset.dx + r * 1.8, targetOffset.dy), chPaint);
    canvas.drawLine(Offset(targetOffset.dx, targetOffset.dy - r * 1.4), Offset(targetOffset.dx, targetOffset.dy - r * 0.9), chPaint);
    canvas.drawLine(Offset(targetOffset.dx, targetOffset.dy + r * 0.9), Offset(targetOffset.dx, targetOffset.dy + r * 1.4), chPaint);

    // 5. Tactical Trajectory Label Pill (drawn above the target if enabled)
    if (traj.showLabel) {
      final labelCenter = Offset(
        targetOffset.dx,
        targetOffset.dy - r - 14.0,
      );

      final String prefix = traj.labelPrefix ?? '⚔️';
      final String labelText = traj.isArcPath
          ? '$prefix ${traj.skillName} • ${traj.targetName}'
          : '$prefix ${traj.skillName} • TARGET: ${traj.targetName}';

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: trajectoryColor,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: labelCenter,
          width: textPainter.width + 14.0,
          height: 18.0,
        ),
        const Radius.circular(4.0),
      );

      // Pill background & border
      canvas.drawRRect(pillRect, Paint()..color = const Color(0xEE0B0F19));
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = trajectoryColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      textPainter.paint(
        canvas,
        Offset(labelCenter.dx - textPainter.width * 0.5, labelCenter.dy - textPainter.height * 0.5),
      );
    }
  }

  static Offset _evaluateBezier(Offset p0, Offset p1, Offset p2, double t) {
    final double u = 1.0 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double ut2 = 2.0 * u * t;

    return Offset(
      uu * p0.dx + ut2 * p1.dx + tt * p2.dx,
      uu * p0.dy + ut2 * p1.dy + tt * p2.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _AttackTrajectoryOverlayPainter oldDelegate) {
    return oldDelegate.dashPhase != dashPhase ||
        oldDelegate.trajectories.length != trajectories.length ||
        true;
  }
}

/// Floating combat text with typography, color coding, and float animation
class _FloatingCombatText {
  final String id;
  final String unitId;
  final String text;
  final Color color;
  final Color borderColor;
  final double fontSize;
  final bool isCrit;
  final int createdMs;
  final int durationMs;
  final double horizontalDrift;

  const _FloatingCombatText({
    required this.id,
    required this.unitId,
    required this.text,
    required this.color,
    required this.borderColor,
    this.fontSize = 11.0,
    this.isCrit = false,
    required this.createdMs,
    this.durationMs = 1750,
    this.horizontalDrift = 0.0,
  });

  double get progress {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - createdMs;
    return (elapsed / durationMs).clamp(0.0, 1.0);
  }

  bool get isExpired => progress >= 1.0;
}

/// Dynamic ground ripple shockwave originating from high-impact strikes
class _ActiveCombatSpriteVfx {
  final String id;
  final Offset position;
  final String assetPath;
  final int columns;
  final int rows;
  final int totalFrames;
  final int durationMs;
  final double width;
  final double height;
  final BlendMode? blendMode;

  const _ActiveCombatSpriteVfx({
    required this.id,
    required this.position,
    required this.assetPath,
    required this.columns,
    required this.rows,
    required this.totalFrames,
    required this.durationMs,
    required this.width,
    required this.height,
    this.blendMode,
  });
}

class _GroundShockwaveRipple {
  final String id;
  final Offset origin;
  final Color color;
  final double maxRadius;
  final int createdMs;
  final int durationMs;

  const _GroundShockwaveRipple({
    required this.id,
    required this.origin,
    required this.color,
    this.maxRadius = 120.0,
    required this.createdMs,
    this.durationMs = 600,
  });

  double get progress {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - createdMs;
    return (elapsed / durationMs).clamp(0.0, 1.0);
  }

  bool get isExpired => progress >= 1.0;
}

/// Painter for 2.5D concentric ground shockwave ripples on the isometric grid
class _GroundShockwaveRipplePainter extends CustomPainter {
  final List<_GroundShockwaveRipple> ripples;
  final int currentTimestampMs;

  const _GroundShockwaveRipplePainter({
    required this.ripples,
    required this.currentTimestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final elapsed = currentTimestampMs - ripple.createdMs;
      if (elapsed < 0 || elapsed > ripple.durationMs) continue;

      final double p = (elapsed / ripple.durationMs).clamp(0.0, 1.0);
      final double radiusX = ripple.maxRadius * p;
      final double radiusY = radiusX * 0.50; // 2:1 isometric ground perspective flattening
      final int alpha = ((1.0 - p) * 230).round().clamp(0, 255);

      // Primary expanding ground shock ellipse
      final ellipseRect = Rect.fromCenter(
        center: ripple.origin,
        width: radiusX * 2,
        height: radiusY * 2,
      );

      final shockPaint = Paint()
        ..color = ripple.color.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.5 * (1.0 - p)).clamp(1.0, 4.0);
      canvas.drawOval(ellipseRect, shockPaint);

      // Inner high-energy accent ring
      if (p > 0.15) {
        final double innerP = (p - 0.15) / 0.85;
        final double innerRadiusX = ripple.maxRadius * innerP * 0.70;
        final double innerRadiusY = innerRadiusX * 0.50;
        final int innerAlpha = ((1.0 - innerP) * 180).round().clamp(0, 255);

        final innerRect = Rect.fromCenter(
          center: ripple.origin,
          width: innerRadiusX * 2,
          height: innerRadiusY * 2,
        );
        final innerPaint = Paint()
          ..color = Colors.white.withAlpha(innerAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawOval(innerRect, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GroundShockwaveRipplePainter oldDelegate) {
    return true;
  }

}

/// Custom painter rendering drifting, smoldering ash embers over downed units
class _AshEmbersDissolvePainter extends CustomPainter {
  final int timestampMs;

  const _AshEmbersDissolvePainter({
    required this.timestampMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Fixed pseudo-random ember particle seeds
    const int particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      // Individual cyclic phase offset (cycle = 1800ms)
      final double seed = (i * 137.5) % 1.0;
      final double cyclePhase = ((timestampMs + (i * 220)) % 1800) / 1800.0;

      // Particle rises upward from base to top
      final double x = (w * 0.15) + (w * 0.70 * ((seed + cyclePhase * 0.2) % 1.0)) + (sin(cyclePhase * 3.14159 * 2 + i) * 6.0);
      final double y = h * (1.0 - cyclePhase * 0.95);

      // Fade in at bottom, fade out near top
      final double opacity = cyclePhase < 0.2
          ? (cyclePhase / 0.2)
          : (cyclePhase > 0.7 ? (1.0 - (cyclePhase - 0.7) / 0.3) : 1.0);
      final int alpha = (opacity * 210).round().clamp(0, 255);

      final double radius = 1.0 + (i % 3) * 0.7;

      // Smoldering embers gradient (radiant ash gold & crimson)
      final Color emberColor = (i % 2 == 0) ? const Color(0xFFFF9100) : const Color(0xFFFF5252);
      final paint = Paint()
        ..color = emberColor.withAlpha(alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), radius, paint);

      // Core ember spark glow
      if (radius > 1.5) {
        final corePaint = Paint()
          ..color = const Color(0xFFFFE082).withAlpha((alpha * 0.85).round())
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), radius * 0.5, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AshEmbersDissolvePainter oldDelegate) {
    return true;
  }
}

class SculptorDisciplineVisuals {
  final String title;
  final Color primaryColor;
  final String s1Title;
  final String s1Sub;
  final IconData s1Icon;
  final Color s1Color;
  final Color s1Border;
  final String s1Action;
  final String s1Tooltip;

  final String s2Title;
  final String s2Sub;
  final IconData s2Icon;
  final Color s2Color;
  final Color s2Border;
  final String s2Action;
  final String s2Tooltip;

  final String s3Title;
  final String s3Sub;
  final IconData s3Icon;
  final Color s3Color;
  final Color s3Border;
  final String s3Action;
  final String s3Tooltip;

  final String s4Title;
  final String s4Sub;
  final IconData s4Icon;
  final Color s4Color;
  final Color s4Border;
  final String s4Action;
  final String s4Tooltip;

  const SculptorDisciplineVisuals({
    required this.title,
    required this.primaryColor,
    required this.s1Title,
    required this.s1Sub,
    required this.s1Icon,
    required this.s1Color,
    required this.s1Border,
    required this.s1Action,
    required this.s1Tooltip,
    required this.s2Title,
    required this.s2Sub,
    required this.s2Icon,
    required this.s2Color,
    required this.s2Border,
    required this.s2Action,
    required this.s2Tooltip,
    required this.s3Title,
    required this.s3Sub,
    required this.s3Icon,
    required this.s3Color,
    required this.s3Border,
    required this.s3Action,
    required this.s3Tooltip,
    required this.s4Title,
    required this.s4Sub,
    required this.s4Icon,
    required this.s4Color,
    required this.s4Border,
    required this.s4Action,
    required this.s4Tooltip,
  });

  factory SculptorDisciplineVisuals.forGeneral(GeneralType general) {
    switch (general) {
      case GeneralType.valeria:
        return const SculptorDisciplineVisuals(
          title: 'THE IRON SCULPTOR',
          primaryColor: Color(0xFFFFD54F),
          s1Title: 'IRON SLAM',
          s1Sub: '15 Cinders',
          s1Icon: Icons.shield,
          s1Color: Color(0xFF5D4037),
          s1Border: Color(0xFFFFD54F),
          s1Action: 'cold_iron_slam',
          s1Tooltip: 'Cold Iron Slam: Consumes 15 Cinders. 130% ATK, shreds 20 Armor, staggers -1,500 AP.',
          s2Title: 'JUDGMENT',
          s2Sub: '30 Cinders',
          s2Icon: Icons.wb_sunny,
          s2Color: Color(0xFFF57F17),
          s2Border: Color(0xFFFFD54F),
          s2Action: 'sundering_judgment',
          s2Tooltip: 'Sundering Judgment: Consumes 30 Cinders. 180% Holy DMG, shreds 30% Armor & inflicts 3s Vulnerable.',
          s3Title: 'BULWARK',
          s3Sub: '25 Cinders',
          s3Icon: Icons.security,
          s3Color: Color(0xFF37474F),
          s3Border: Color(0xFF81D4FA),
          s3Action: 'iron_bulwark',
          s3Tooltip: 'Iron Bulwark: Consumes 25 Cinders. +35 Armor & cleanses all debuffs across squad.',
          s4Title: 'WRATH APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.flash_on,
          s4Color: Color(0xFFFFB300),
          s4Border: Color(0xFFFFF176),
          s4Action: 'wrath_of_the_dawnbound',
          s4Tooltip: 'Wrath of the Dawnbound: APEX! 280% (380% Perfect Forge Crit) Radiant Nova across all foes!',
        );
      case GeneralType.vladislav:
        return const SculptorDisciplineVisuals(
          title: 'THE SANGUINE SCULPTOR',
          primaryColor: Color(0xFFFF1744),
          s1Title: 'SIPHON REND',
          s1Sub: '15 Cinders',
          s1Icon: Icons.bloodtype,
          s1Color: Color(0xFF880E4F),
          s1Border: Color(0xFFFF5252),
          s1Action: 'siphon_rend',
          s1Tooltip: 'Siphon Rend: Consumes 15 Cinders. 135% ATK, leeches 40% DMG dealt as HP.',
          s2Title: 'CRIMSON BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.whatshot,
          s2Color: Color(0xFFC2185B),
          s2Border: Color(0xFFFF4081),
          s2Action: 'crimson_brand',
          s2Tooltip: 'Crimson Brand: Consumes 30 Cinders. 165% ATK + 3 Bleeds, detonates active bleeds for 2x DMG.',
          s3Title: 'VEIN TETHER',
          s3Sub: '25 Cinders',
          s3Icon: Icons.all_inclusive,
          s3Color: Color(0xFF4A148C),
          s3Border: Color(0xFFEA80FC),
          s3Action: 'vein_tether',
          s3Tooltip: 'Vein Tether: Consumes 25 Cinders. +2,500 AP haste & +25 Aegis to all allies.',
          s4Title: 'EXSANGUINATION',
          s4Sub: '80 Cinders',
          s4Icon: Icons.storm,
          s4Color: Color(0xFFB71C1C),
          s4Border: Color(0xFFFF1744),
          s4Action: 'exsanguination_apex',
          s4Tooltip: 'Exsanguination Apex: APEX! 260% (360% Forge Crit) Blood Tempest, executes targets below 25% HP!',
        );
      case GeneralType.morrigan:
        return const SculptorDisciplineVisuals(
          title: 'THE MIRE SCULPTOR',
          primaryColor: Color(0xFF00E676),
          s1Title: 'CORROSIVE TOUCH',
          s1Sub: '15 Cinders',
          s1Icon: Icons.coronavirus,
          s1Color: Color(0xFF1B5E20),
          s1Border: Color(0xFF69F0AE),
          s1Action: 'corrosive_touch',
          s1Tooltip: 'Corrosive Touch: Consumes 15 Cinders. 130% ATK, 2 Poison, -1,000 AP stagger.',
          s2Title: 'MIASMIC BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.bubble_chart,
          s2Color: Color(0xFF2E7D32),
          s2Border: Color(0xFF00E676),
          s2Action: 'miasmic_brand',
          s2Tooltip: 'Miasmic Brand: Consumes 30 Cinders. 160% ATK, plagues target column with 3 Poison & Vulnerable.',
          s3Title: 'BONE WARD',
          s3Sub: '25 Cinders',
          s3Icon: Icons.healing,
          s3Color: Color(0xFF004D40),
          s3Border: Color(0xFF64FFDA),
          s3Action: 'bone_ward',
          s3Tooltip: 'Bone Ward: Consumes 25 Cinders. 30% max HP ossuary shields to all living allies.',
          s4Title: 'SPORE APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.eco,
          s4Color: Color(0xFF00C853),
          s4Border: Color(0xFFB9F6CA),
          s4Action: 'cataclysmic_spore',
          s4Tooltip: 'Cataclysmic Spore: APEX! 240% (340% Forge Crit) Nature eruption, deals bonus damage to poisoned foes!',
        );
      case GeneralType.malakor:
        return const SculptorDisciplineVisuals(
          title: 'THE ASH SCULPTOR',
          primaryColor: Color(0xFFFF6D00),
          s1Title: 'CLEAVE',
          s1Sub: '15 Cinders',
          s1Icon: Icons.sports_mma,
          s1Color: Color(0xFFB3261E),
          s1Border: Color(0xFFFF8A80),
          s1Action: 'forge_cleave',
          s1Tooltip: 'Forge Cleave: Consumes 15 Cinders. 140% ATK heavy strike (+1 Bleed).',
          s2Title: 'BRAND',
          s2Sub: '30 Cinders',
          s2Icon: Icons.local_fire_department,
          s2Color: Color(0xFFC2185B),
          s2Border: Color(0xFFFF4081),
          s2Action: 'sundering_brand',
          s2Tooltip: 'Sundering Brand: Consumes 30 Cinders. 175% ATK, shatters 50% Armor & triggers Crypt Stalker ambush!',
          s3Title: 'BASTION',
          s3Sub: '25 Cinders',
          s3Icon: Icons.shield,
          s3Color: Color(0xFF00695C),
          s3Border: Color(0xFF00BFA5),
          s3Action: 'obsidian_bastion',
          s3Tooltip: 'Obsidian Bastion: Consumes 25 Cinders. Shields Sculptor and retinue with Aegis barriers.',
          s4Title: 'PYRE APEX',
          s4Sub: '80 Cinders',
          s4Icon: Icons.bolt,
          s4Color: Color(0xFFFF6D00),
          s4Border: Color(0xFFFFD54F),
          s4Action: 'cataclysmic_pyre',
          s4Tooltip: 'Cataclysmic Pyre: APEX! 250% (350% Perfect Forge Crit) Fire Nova across all enemy ranks!',
        );
    }
  }
}
