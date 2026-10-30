import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../core/combat_math.dart';
import '../../shared/utils/platform_fullscreen.dart';
import '../settings/settings_service.dart';
import '../relics/relic_service.dart';
import '../generals/general_command_service.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';
import 'rank_and_rite_2d_battlefield.dart';
import '../../shared/widgets/sprite_sheet_animation.dart';

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
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> {
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
  String? _attackingUnitId;
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

  // Ambient Dark Fantasy Combat Audio
  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
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
      _sfxPlayer = AudioPlayer();
      
      // Stop loop event spam on Windows native backend
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      final bgmVol = _isMuted ? 0.0 : (settings.bgmVolume * 0.45);
      await _bgmPlayer!.setVolume(bgmVol);
      await _sfxPlayer!.setVolume(settings.sfxVolume * 0.70);
      if (settings.bgmEnabled) {
        await _bgmPlayer!.play(AssetSource('audio/combat_bgm_ambient.mp3'));
      }
    } catch (e) {
      debugPrint('Error starting combat audio: $e');
    }
  }

  void _playSfx(String sfxName) {
    final settings = SettingsService();
    if (_isMuted || !settings.sfxEnabled || _sfxPlayer == null) return;
    try {
      _sfxPlayer!.play(AssetSource('audio/$sfxName')).catchError((e) {
        debugPrint('Error playing SFX $sfxName: $e');
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

    // Check if a new combat action event was dispatched
    final event = _engine.activeActionEvent;
    if (event != null && event.id != _lastHandledEventId) {
      _lastHandledEventId = event.id;
      _triggerVisualCombatSequence(event);
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

  void _triggerVisualCombatSequence(SpatialActionEvent event) {
    // Locate caster and target units to calculate real isometric trajectory points
    final allUnits = [..._engine.playerUnits, ..._engine.enemyUnits];
    final caster = allUnits.where((u) => u.id == event.attackerId).firstOrNull;
    final target = allUnits.where((u) => u.id == event.targetId).firstOrNull;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final targetOffset = target != null ? _getUnitCenterIsometricOffset(target) : const Offset(280, 200);
    final casterOffset = caster != null ? _getUnitCenterIsometricOffset(caster) : Offset(targetOffset.dx, targetOffset.dy + 80);

    // Determine VFX visual flavor based on attack type & crit
    String vfxType = 'slash';
    Color primaryColor = const Color(0xFFFF5252);
    Color secondaryColor = const Color(0xFFFF8A80);
    int durationMs = 650;

    if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova') || event.skillName.contains('Evisceration') || event.skillName.contains('Crimson Dread')) {
      vfxType = 'bloodnova';
      primaryColor = const Color(0xFFFF1744);
      secondaryColor = const Color(0xFFD50000);
      durationMs = 850;
      _playSfx('sfx_slash.wav'); // High-impact blood cleave
    } else if (event.skillName.contains('Sovereign Cleave') || event.skillName.contains('Vanguard Cleave')) {
      vfxType = 'slash';
      primaryColor = const Color(0xFFFFD54F);
      secondaryColor = const Color(0xFFFF1744);
      durationMs = 750;
      _playSfx('sfx_slash.wav');
    } else if (event.skillName.contains('Deadeye Execution') || event.skillName.contains('Siege-Breaker') || event.skillName.contains('Phantom Riposte')) {
      vfxType = 'slash';
      primaryColor = const Color(0xFF00E5FF);
      secondaryColor = const Color(0xFFFF1744);
      durationMs = 700;
      _playSfx('sfx_slash.wav');
    } else if (event.skillName.contains('Celestial Surge')) {
      vfxType = 'shockwave';
      primaryColor = const Color(0xFF00E5FF);
      secondaryColor = const Color(0xFFFFD54F);
      durationMs = 800;
      _playSfx('sfx_spell.wav');
    } else if (event.skillName.contains('Sanguine Siphon') || event.skillName.contains('Flensing') || event.bleedStacks > 0) {
      vfxType = 'bloodsiphon';
      primaryColor = const Color(0xFFFF5252);
      secondaryColor = const Color(0xFF880E4F);
      durationMs = 700;
      _playSfx('sfx_spell.wav'); // Dark blood drain surge
    } else if (event.skillName.contains('Smite') || event.skillName.contains('SHATTERS')) {
      vfxType = 'shatter';
      primaryColor = const Color(0xFFFFD54F);
      secondaryColor = const Color(0xFF00E5FF);
      durationMs = 800;
      _playSfx('sfx_block.wav'); // Heavy armor crack / shield shatter
    } else if (event.skillName.contains('Sun') || event.skillName.contains('Orb') || event.skillName.contains('Cinder') || event.skillName.contains('Bolt')) {
      vfxType = 'beam';
      primaryColor = event.isPlayerAttacker ? const Color(0xFFFFD54F) : const Color(0xFFFF7043);
      secondaryColor = const Color(0xFFFFEB3B);
      durationMs = 600;
      _playSfx('sfx_spell.wav'); // Magic surge
    } else if (event.isHeal || event.skillName.contains('Phalanx')) {
      vfxType = 'shockwave';
      primaryColor = const Color(0xFF00E5FF);
      secondaryColor = const Color(0xFF80D8FF);
      durationMs = 700;
      _playSfx('sfx_block.wav'); // Defensive barrier
    } else if (event.isCrit) {
      vfxType = 'slash';
      primaryColor = const Color(0xFFFF1744);
      secondaryColor = const Color(0xFFFFD54F);
      durationMs = 750;
      _playSfx('sfx_slash.wav'); // Lethal blade critical
    } else {
      _playSfx('sfx_hit.wav'); // Standard melee impact
    }

    final newVfx = _CombatVfx(
      id: 'vfx_${event.id}_$nowMs',
      startOffset: casterOffset,
      targetOffset: targetOffset,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      type: vfxType,
      durationMs: durationMs,
      createdMs: nowMs,
    );

    // Spawn secondary target impact flashes/shockwaves for AOE / Cleave hits
    final List<_CombatVfx> secondaryVfxList = [];
    if (event.secondaryTargetHits.isNotEmpty) {
      event.secondaryTargetHits.forEach((secId, secDmg) {
        final secUnit = allUnits.where((u) => u.id == secId).firstOrNull;
        if (secUnit != null) {
          final secOffset = _getUnitCenterIsometricOffset(secUnit);
          secondaryVfxList.add(_CombatVfx(
            id: 'vfx_${event.id}_sec_${secId}_$nowMs',
            startOffset: targetOffset,
            targetOffset: secOffset,
            primaryColor: primaryColor.withValues(alpha: 0.9),
            secondaryColor: secondaryColor.withValues(alpha: 0.8),
            type: vfxType == 'beam' ? 'shockwave' : vfxType,
            durationMs: (durationMs * 0.85).round(),
            createdMs: nowMs,
          ));
        }
      });
    }

    // Check if event is a player Ultimate Burst or Signature Skill
    final bool isUltimate = event.id.startsWith('ult_');
    if (isUltimate && caster != null && caster.isPlayer) {
      _activeUltimateUnit = caster;
      _playSfx('sfx_spell.wav');
    } else if (event.isSignatureSkill && caster != null) {
      _activeSignatureUnit = caster;
      _playSfx('sfx_spell.wav');
    }

    // Camera Hit-Shake & Ground Ripple Shockwaves for heavy hits, boss strikes, crits, and bloodnovas
    final bool isBossStrike = event.attackerId == 'gorgoroth_boss';
    final bool isBloodnova = event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova');
    final bool isHeavyImpact = event.isCrit || isBossStrike || isUltimate || isBloodnova || event.skillName.contains('Smite') || event.skillName.contains('Cataclysm') || event.secondaryTargetHits.length >= 2;

    // Note: Keep the battlefield camera stationary; individual units lunge and shake on impact
    if (isHeavyImpact) {
      _groundRipples.add(_GroundShockwaveRipple(
        id: 'ripple_${event.id}_$nowMs',
        origin: targetOffset,
        color: (isBossStrike || isBloodnova)
            ? const Color(0xFFFF1744)
            : (event.isCrit ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF)),
        maxRadius: isUltimate ? 160.0 : (isBossStrike ? 140.0 : (isBloodnova ? 130.0 : 100.0)),
        createdMs: nowMs,
        durationMs: 650,
      ));
    }

    // Spawn invocation rune at caster's plinth for active skill cast
    final casterRuneVfx = _CombatVfx(
      id: 'vfx_${event.id}_rune_$nowMs',
      startOffset: casterOffset,
      targetOffset: casterOffset,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      type: 'rune_invocation',
      durationMs: 700,
      createdMs: nowMs,
    );

    setState(() {
      _activeVfx.add(newVfx);
      _activeVfx.add(casterRuneVfx);
      _activeVfx.addAll(secondaryVfxList);
      _attackingUnitId = event.attackerId;
      _damagedUnitId = event.targetId;
      _damagedUnitIds.clear();
      _damagedUnitIds.add(event.targetId);
      if (event.secondaryTargetHits.isNotEmpty) {
        _damagedUnitIds.addAll(event.secondaryTargetHits.keys);
      }
      _activeSkillName = event.skillName;
      _activeSkillCasterName = event.attackerName;
      _activeSkillCaster = caster;
      _isPlayerSkillBanner = event.isPlayerAttacker;

      // Construct distinct styled floating pop
      String popText;
      Color popColor;
      Color popBorder;
      double popSize = 11.0;
      bool isCrit = event.isCrit;

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
        } else if (event.isCrit) {
          popText = '💥 -${event.damage} CRIT!';
          popColor = const Color(0xFFFFD54F);
          popBorder = const Color(0xFFFF1744);
          popSize = 13.5;
        } else if (event.bleedStacks > 0) {
          popText = '-${event.damage} (🩸+${event.bleedStacks})';
          popColor = const Color(0xFFFF5252);
          popBorder = const Color(0xFFB71C1C);
        } else {
          popText = '-${event.damage}';
          popColor = const Color(0xFFFF8A80);
          popBorder = const Color(0xFFD50000);
        }
      }

      _unitFloatingPops[event.targetId] = popText;

      // Clean up previous floating pop for this unit and push new animated item
      _floatingPops.removeWhere((p) => p.unitId == event.targetId || p.isExpired);
      _floatingPops.add(_FloatingCombatText(
        id: 'pop_${event.id}_$nowMs',
        unitId: event.targetId,
        text: popText,
        color: popColor,
        borderColor: popBorder,
        fontSize: popSize,
        isCrit: isCrit,
        createdMs: nowMs,
        durationMs: isCrit ? 1200 : 900,
      ));

      // If attacker procced a Crucible Grafted Trait, display a glowing purple/gold floating proc callout on the attacker!
      if (event.graftedTraitProc != null && event.attackerId != event.targetId) {
        final graftText = '🧬 ${event.graftedTraitProc}';
        _unitFloatingPops[event.attackerId] = graftText;
        _floatingPops.removeWhere((p) => p.unitId == event.attackerId);
        _floatingPops.add(_FloatingCombatText(
          id: 'pop_graft_${event.id}_$nowMs',
          unitId: event.attackerId,
          text: graftText,
          color: const Color(0xFFEA80FC),
          borderColor: const Color(0xFFD500F9),
          fontSize: 10.5,
          isCrit: false,
          createdMs: nowMs,
          durationMs: 1100,
        ));
      }

      // Push floating popups for all secondary targets hit by multi-target / AOE spells
      if (event.secondaryTargetHits.isNotEmpty) {
        event.secondaryTargetHits.forEach((secId, secDmg) {
          final isSecBlood = event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova');
          final secText = isSecBlood ? '🩸 -$secDmg SPLASH' : '-$secDmg CLEAVE';
          _unitFloatingPops[secId] = secText;
          _floatingPops.removeWhere((p) => p.unitId == secId);
          _floatingPops.add(_FloatingCombatText(
            id: 'pop_${event.id}_${secId}_$nowMs',
            unitId: secId,
            text: secText,
            color: isSecBlood ? const Color(0xFFFF5252) : const Color(0xFFFF8A80),
            borderColor: isSecBlood ? const Color(0xFF880E4F) : const Color(0xFFD50000),
            fontSize: 11.5,
            isCrit: false,
            createdMs: nowMs,
            durationMs: 950,
          ));
        });
      }
    });

    // Clean up VFX after its duration
    final tVfx = Timer(Duration(milliseconds: durationMs + 50), () {
      if (mounted) {
        setState(() {
          _activeVfx.removeWhere((v) => v.id == newVfx.id || v.id == casterRuneVfx.id || secondaryVfxList.any((s) => s.id == v.id));
          _floatingPops.removeWhere((p) => p.isExpired);
          _groundRipples.removeWhere((r) => r.isExpired);
        });
      }
    });
    _animTimers.add(tVfx);

    // Reset visual lunge & floating pops after 1100ms
    final t1 = Timer(const Duration(milliseconds: 1600), () {
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

    // Dismiss banner & resume combat ticks after 1800ms for Signature/Ultimate, or 1400ms for basic attacks
    final int pauseWindowMs = (isUltimate || event.isSignatureSkill) ? 1900 : 1400;
    final t2 = Timer(Duration(milliseconds: pauseWindowMs), () {
      if (mounted) {
        setState(() {
          _activeSkillName = null;
          _activeSkillCaster = null;
          _activeUltimateUnit = null;
          _activeSignatureUnit = null;
        });
        _engine.clearActiveAction();
      }
    });
    _animTimers.add(t2);
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
        if (_engine.isActionPauseEnabled && _engine.activeActionEvent != null) {
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
    _loopTimer?.cancel();
    for (final t in _animTimers) {
      t.cancel();
    }
    _animTimers.clear();
    _engine.removeListener(_onEngineUpdate);
    final bgm = _bgmPlayer;
    final sfx = _sfxPlayer;
    _bgmPlayer = null;
    _sfxPlayer = null;
    try {
      bgm?.stop().then((_) => bgm.dispose()).catchError((_) {});
      sfx?.stop().then((_) => sfx.dispose()).catchError((_) {});
    } catch (_) {}
    super.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141E),
        elevation: 0,
        toolbarHeight: isLandscapeMobile ? 42 : null,
        leading: widget.onBackToStandardCombat != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD54F)),
                onPressed: widget.onBackToStandardCombat,
                tooltip: 'Return to Standard Arena',
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFB3261E).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFB3261E)),
              ),
              child: const Text(
                'EXPERIMENTAL v3.2',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8A80),
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.encounterTitle?.toUpperCase() ?? _engine.encounterTitle.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
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
                        // Layer 3: Foreground Battlefield Field, Trenches & Debris
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

                      // Dynamically calculate optimal tile dimensions to fill large PC screens
                      // and scale down gracefully on mobile/tablet screens.
                      // 2D board has 6 ranks + clash buffer (approx 6.5 tile widths + padding)
                      // and 5 lane rows (5 tile heights + padding).
                      final double target2DWidth = (availW / 7.8).clamp(68.0, 150.0);
                      final double target2DHeight = (availH / 6.2).clamp(52.0, 115.0);

                      final bool isDesktop = availW >= 700;
                      final double tileWidth = isDesktop ? 170.0 : 118.0;
                      final double tileHeight = isDesktop ? 85.0 : 59.0;

                      final double tile2DWidth = target2DWidth;
                      final double tile2DHeight = target2DHeight;

                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20.0 : 8.0,
                              vertical: isDesktop ? 12.0 : 6.0,
                            ),
                            child: _is2DGridView
                                ? RankAndRite2DBattlefield(
                                    engine: _engine,
                                    selectedUnitId: _selectedUnitId,
                                    selectedEnemyUnitId: _selectedEnemyUnitId,
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

                  // Floating Tactical Prompt & Unit Combat Triad Overlays (Non-shifting Stack overlays!)
                  if (!_isZenMode &&
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

                  if (!_isZenMode &&
                      (_draggedUnitId != null || _selectedUnitId != null || _selectedEnemyUnitId != null))
                    Positioned(
                      top: 38,
                      left: 12,
                      right: 12,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _buildUnitCombatTriadStrip(),
                        ),
                      ),
                    ),

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

                  // In-Combat Ultimate Burst or Signature Skill Dramatic Cut-In Overlay
                  if (_activeUltimateUnit != null)
                    _buildUltimateCinematicOverlay(_activeUltimateUnit!),
                  if (_activeSignatureUnit != null && _activeUltimateUnit == null)
                    _buildSignatureSkillCinematicBanner(_activeSignatureUnit!, _activeSkillName ?? _activeSignatureUnit!.signatureSkillName),

                  // Pulled-Up Spell Card Inspector & Cast HUD (Floating just above the dock)
                  if (_selectedCardId != null || _hoveredCardId != null)
                    _buildPulledUpCardOverlay(isLandscapeMobile: isLandscapeMobile),

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
                                          if (_engine.rewardBossReagent != null)
                                            const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.whatshot, color: Color(0xFFFF9100), size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Brim-Slag Core',
                                                  style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold),
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
                                                    const Text('BLEED BURSTS', style: TextStyle(color: Colors.white54, fontSize: 7.5, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      '${_engine.bleedDetonationsCount}',
                                                      style: const TextStyle(color: Color(0xFFFF1744), fontSize: 11, fontWeight: FontWeight.w900),
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
                ],
              ),
            ),

            // Pre-Battle Staging Reserve Dock (Deployment Phase) vs Live Combat Docks (Ultimates & Grimoire Hand)
            if (_engine.isPreBattlePhase)
              _buildPreBattleStagingDock(isLandscapeMobile: isLandscapeMobile)
            else ...[
              // Rank & Rite Spec Sec 2: Turn Action Decision Tray (When Turn Meter reaches 10,000 TM)
              if (_engine.isTurnExecutionPaused && _engine.activeActingUnit != null && !_engine.isAutoBattleMode)
                _buildTurnActionDecisionTray(_engine.activeActingUnit!, isLandscapeMobile: isLandscapeMobile),

              // Ultimate Burst Pop-Out Mini-Slate Dock (Player-Initiated Drag)
              _buildUltimatePopOutDock(isLandscapeMobile: isLandscapeMobile),

              // Tactical Card Hand & Burn Pit (Sculptor Tray)
              _buildTacticalHandDock(isLandscapeMobile: isLandscapeMobile),
            ],

            // Live 30 Hz Combat Event Log (Hidden in Zen Mode and Mobile Landscape)
            if (!_isZenMode && !isLandscapeMobile)
              _buildCombatLogConsole(),
          ],
        ),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLandscapeMobile ? 2 : 5),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(bottom: BorderSide(color: Color(0xFF282838), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Commander Focus Crystal Bank with dynamic charge pips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'TEAM VITAE ${_engine.teamVitae}/${_engine.maxFocus}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Visual Crystal Pips (Filled vs Empty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_engine.maxFocus, (index) {
                          final isFilled = index < _engine.focus;
                          final isCharging = index == _engine.focus;
                          return Container(
                            width: 8,
                            height: 12,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: isFilled
                                  ? const Color(0xFF00E5FF)
                                  : (isCharging
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                                      : Colors.white10),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: isFilled ? const Color(0xFF80D8FF) : Colors.white24,
                                width: 0.8,
                              ),
                              boxShadow: isFilled
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isCharging
                                ? FractionallySizedBox(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: focusProgress,
                                    child: Container(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 1b. Rank & Rite Turn Mode Toggle: TACTICAL TURN PAUSE vs AUTO BATTLE
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _engine.toggleAutoBattleMode();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _engine.isAutoBattleMode
                          ? const Color(0xFFEF6C00).withValues(alpha: 0.3)
                          : const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _engine.isAutoBattleMode ? const Color(0xFFFF9800) : const Color(0xFF00E5FF),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _engine.isAutoBattleMode ? Icons.auto_mode : Icons.touch_app,
                          color: _engine.isAutoBattleMode ? const Color(0xFFFFB74D) : const Color(0xFF80D8FF),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _engine.isAutoBattleMode ? 'AUTO-BATTLE' : 'TACTICAL TURNS',
                          style: TextStyle(
                            color: _engine.isAutoBattleMode ? const Color(0xFFFFB74D) : const Color(0xFF80D8FF),
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

                // 2. Simulation Speed & Bullet-Time Toggle
                GestureDetector(
                  onTap: () {
                    _engine.setBulletTime(!_engine.isBulletTime);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _engine.isBulletTime ? const Color(0xFFFF9100).withValues(alpha: 0.3) : const Color(0xFF282836),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _engine.isBulletTime ? Icons.slow_motion_video : Icons.speed,
                          color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _engine.isBulletTime ? '30% BULLET-TIME' : '1.0X REALTIME',
                          style: TextStyle(
                            color: _engine.isBulletTime ? const Color(0xFFFF9100) : Colors.white70,
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

          // 4. Live Initiative Action Timeline (ATB Sequence Preview)
          Container(
            height: isLandscapeMobile ? 26 : 30,
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
                                    isAlly ? Icons.shield : Icons.dangerous,
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

        // Adaptive Posture Color & Damage Estimate
        Color trajColor = const Color(0xFF00E5FF);
        double mult = 1.0;
        if (unit.archetype == UnitArchetype.vanguardMelee && srcLocalRow == 1) {
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
        final skillDesc = '${_getUnitBasicAttackDescription(unit, srcCol, srcLocalRow)} [~$estDmg DMG]';

        trajectories.add(_TrajectoryData(
          sourceOffset: sourceOffset,
          targetOffset: targetOffset,
          skillName: skillDesc,
          targetName: target.name,
          color: trajColor,
          showLabel: isPrimaryInspected,
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

    if (_showAllTrajectories) {
      for (final u in _engine.playerUnits.where((u) => u.isAlive)) {
        addPlayerUnitTrajectory(u, isPrimaryInspected: u.id == inspectedUnitId);
      }
    } else if (inspectedUnitId != null) {
      final unit = _engine.playerUnits.where((u) => u.id == inspectedUnitId && u.isAlive).firstOrNull;
      if (unit != null) {
        addPlayerUnitTrajectory(unit, isPrimaryInspected: true);
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

        final bool hasGlow = isSpellAoeAffected || isTelegraphed || isSelected || isDropCandidate || isReachable || isSwappable;
        final Color glowColor = isSpellAoeAffected
            ? const Color(0xFFFFD54F)
            : (isTelegraphed
                ? const Color(0xFFFF1744)
                : (isReachable
                    ? const Color(0xFF00E676)
                    : (isDropCandidate || isSwappable ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F))));

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
            const SizedBox(width: 10),

            // 1. Basic Action (Automated)
            const Icon(Icons.gps_fixed, size: 12, color: Color(0xFF00E5FF)),
            const SizedBox(width: 4),
            Text(
              'BASIC: $basicDesc',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),

            // 1b. Distinct Unit Signature Skill (Every 3rd Action Cycle)
            Icon(
              Icons.stars_rounded,
              size: 13,
              color: unit.isSignatureReady ? const Color(0xFFFFD54F) : const Color(0xFFFFB74D),
            ),
            const SizedBox(width: 4),
            Text(
              unit.isSignatureReady
                  ? '★ SKILL READY: ${unit.signatureSkillName}'
                  : 'SKILL: ${unit.signatureSkillName} (${unit.signatureCooldown} turns)',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: unit.isSignatureReady ? const Color(0xFFFFD54F) : const Color(0xFFFFCC80),
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
                    _isPlayerSkillBanner ? Icons.shield : Icons.dangerous,
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

    // Lunge forward across clash line during attack
        final double lungeY = _is2DGridView ? 0.0 : (isAttacking ? (unit.isPlayer ? -14.0 : 14.0) : 0.0);
    final double lungeX = _is2DGridView && isAttacking ? (unit.isPlayer ? 16.0 : -16.0) : 0.0;
    final double hitShakeX = isDamaged ? 4.0 : 0.0;

    // Normalization multipliers:
    // Valeria's sprite fills 100% of her canvas, whereas Footman, Ghoul, Sanguine Blade have
    // transparent padding. We scale Valeria to 0.88 so her physical figure matches the 1:1 footprint of the others!
    double unitScaleMultiplier = 1.0;
    final path = unit.assetPath.toLowerCase();
    if (unit.id == 'lady_valeria' || path.contains('valeria')) {
      unitScaleMultiplier = 0.88; // Full-bleed canvas normalization for 1:1 tile footprint
    } else if (path.contains('ghoul')) {
      unitScaleMultiplier = 1.45; // Ghoul crouches low; scale up plinth & figure
    } else if (path.contains('sentinel') || path.contains('juggernaut')) {
      unitScaleMultiplier = 1.35; // Bulky armored frontline
    } else if (path.contains('crimson_inquisitor') || path.contains('inquisitor') || path.contains('footman')) {
      unitScaleMultiplier = 1.35; // Tabletop knight plinths
    } else if (path.contains('sanguine_flayer') || path.contains('blade') || path.contains('scourge')) {
      unitScaleMultiplier = 1.35;
    } else if (path.contains('sun_smith') || path.contains('alchemist') || path.contains('scribe') || path.contains('priestess')) {
      unitScaleMultiplier = 1.25;
    } else if (path.contains('cinder_witch') || path.contains('blood_initiate') || path.contains('sorcerer') || path.contains('archon') || path.contains('matron')) {
      unitScaleMultiplier = 1.30; // Tall casters
    } else if (path.contains('warhound') || path.contains('golem')) {
      unitScaleMultiplier = 1.30;
    }

    final double bossSpanWidth = isBoss ? (tileWidth * 2.2) : tileWidth;
    final double baseWidth = isBoss ? bossSpanWidth * 0.70 : (tileWidth - 12) * unitScaleMultiplier;
    final double baseHeight = isBoss ? 44 : (16 * unitScaleMultiplier);
    // Units scale dynamically with tile size for commanding visual presence
    final double modelWidth = (isBoss ? bossSpanWidth * 1.15 : tileWidth * 1.05 * unitScaleMultiplier).clamp(80.0, 320.0);
    final double modelHeight = (isBoss
        ? (tileHeight * 3.8).clamp(200.0, 320.0)
        : (tileHeight * 2.3 * unitScaleMultiplier).clamp(110.0, 220.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(hitShakeX + lungeX, lungeY, 0),
      child: SizedBox(
        width: isBoss ? bossSpanWidth : tileWidth,
        height: isBoss ? (tileHeight * 2.0) : tileHeight,
        child: Stack(
          alignment: Alignment.center,
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
                  ],
                ),
              ),
            ),

            // 1b. Stance Mastery Runic Plinth Aura (Tabletop visual condition cue)
            if (!unit.isDowned && (unit.hasStanceBonusReady || (unit.activeStance == StanceType.holdTheLine && unit.consecutiveTurnsStationary >= 1)))
              Positioned(
                bottom: 3,
                child: Container(
                  width: baseWidth + 6,
                  height: baseHeight + 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical((baseWidth + 6) / 2, (baseHeight + 4) / 2)),
                    border: Border.all(
                      color: unit.activeStance == StanceType.holdTheLine
                          ? const Color(0xFFFFD54F) // Amber/Gold rune ring for Hold the Line
                          : (unit.activeStance == StanceType.flankingMomentum
                              ? const Color(0xFFFF1744) // Crimson trail for Flanking Momentum
                              : const Color(0xFF00E5FF)), // Cyan star for Aetheric Alignment
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: unit.activeStance == StanceType.holdTheLine
                            ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
                            : (unit.activeStance == StanceType.flankingMomentum
                                ? const Color(0xFFFF1744).withValues(alpha: 0.65)
                                : const Color(0xFF00E5FF).withValues(alpha: 0.65)),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Character Model Miniature Cutout (Stands proudly upright on diamond plinth)
            Positioned(
              bottom: unit.isDowned ? 2 : 6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: unit.isDowned ? 0.68 : 1.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 500),
                  scale: unit.isDowned ? 0.94 : 1.0,
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: modelWidth,
                    height: modelHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Main Character Sprite (with Stone Petrification / Hit-Flash color filter)
                        ColorFiltered(
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
                                          ? const Color(0x99FFFFFF)
                                          : const Color(0x66FF1744), // Translucent crimson flash so miniature artwork remains clear
                                      BlendMode.srcATop,
                                    )
                                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst)),
                          child: (isAttacking && (unit.id == 'lady_valeria' || unit.assetPath.toLowerCase().contains('valeria')))
                              ? SpriteSheetAnimation(
                                  assetPath: 'assets/animations/valeria_slash_sheet.png',
                                  columns: 3,
                                  rows: 2,
                                  totalFrames: 6,
                                  duration: const Duration(milliseconds: 1400),
                                  loop: false,
                                  fit: BoxFit.contain,
                                )
                              : Image.asset(
                                  unit.assetPath,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    unit.isPlayer ? Icons.shield : Icons.dangerous,
                                    color: factionColor,
                                    size: isBoss ? 48 : 36,
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

            // 3. Status Badges & Selected Unit Indicator
            Positioned(
              top: isBoss ? -22 : -16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unit.isInvulnerable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF00E5FF), blurRadius: 4),
                        ],
                      ),
                      child: const Text(
                        '✨AWAKENING',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  if (unit.isSlagCarapaceActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221115),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.6),
                      ),
                      child: const Text(
                        'CARAPACE',
                        style: TextStyle(
                          fontSize: 6.5,
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  // Compact Horizontal Status Badges Cluster
                  Builder(
                    builder: (context) {
                      final List<Widget> statusBadges = [];

                      if (unit.isInvulnerable) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [BoxShadow(color: Color(0xFF00E5FF), blurRadius: 4)],
                          ),
                          child: const Text('✨AWAKEN', style: TextStyle(fontSize: 6.0, color: Colors.black, fontWeight: FontWeight.w900)),
                        ));
                      }
                      if (unit.isSlagCarapaceActive) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF221115),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFFFD54F), width: 0.6),
                          ),
                          child: const Text('CARAPACE', style: TextStyle(fontSize: 6.0, color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.isPetrifiedPlinth) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF263238),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                          ),
                          child: Text('🪨PLINTH (${unit.plinthDurability}/3)', style: const TextStyle(fontSize: 5.5, color: Color(0xFFFFCC80), fontWeight: FontWeight.w900)),
                        ));
                      } else if (unit.isDowned) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF263238),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF90A4AE), width: 0.8),
                          ),
                          child: const Text('🪨DOWN', style: TextStyle(fontSize: 6.0, color: Color(0xFFCFD8DC), fontWeight: FontWeight.w900)),
                        ));
                      }
                      if (unit.isAlive && _engine.isCoveredByVanguard(unit, trajectory: AttackTrajectory.directPhysical)) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF81C784), width: 0.6),
                          ),
                          child: const Text('🛡️COVER -25%', style: TextStyle(fontSize: 5.5, color: Color(0xFFA5D6A7), fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.reviveCount > 0) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A148C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('💀-${unit.reviveCount * 20}%', style: const TextStyle(fontSize: 5.5, color: Color(0xFFE1BEE7), fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.bleedStacks > 0) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('🩸${unit.bleedStacks}', style: const TextStyle(fontSize: 6.0, color: Colors.white, fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.poisonStacks > 0) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF66BB6A), width: 0.5),
                          ),
                          child: Text('🧪${unit.poisonStacks}', style: const TextStyle(fontSize: 6.0, color: Color(0xFFC8E6C9), fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.burnDuration > 0) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text('🔥', style: TextStyle(fontSize: 6.0)),
                        ));
                      }
                      if (unit.isFrozen) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0288D1),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF81D4FA), width: 0.5),
                          ),
                          child: const Text('❄️', style: TextStyle(fontSize: 6.0)),
                        ));
                      }
                      if (unit.isStunned) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBC02D),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text('⚡', style: TextStyle(fontSize: 6.0)),
                        ));
                      }
                      if (unit.isVulnerable) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A1B9A),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFCE93D8), width: 0.5),
                          ),
                          child: const Text('💔+25%', style: TextStyle(fontSize: 5.5, color: Color(0xFFF3E5F5), fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.isHasted) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B0FF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text('⚡+35%', style: TextStyle(fontSize: 5.5, color: Colors.black, fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.aegisShield > 0) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B0FF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('🛡️${unit.aegisShield}', style: const TextStyle(fontSize: 6.0, color: Colors.black, fontWeight: FontWeight.bold)),
                        ));
                      }
                      if (unit.isAlive && unit.isSignatureReady) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [BoxShadow(color: Color(0xFFFFD54F), blurRadius: 4)],
                          ),
                          child: const Text('★SKILL', style: TextStyle(fontSize: 5.5, color: Colors.black, fontWeight: FontWeight.w900)),
                        ));
                      }
                      if (unit.isAlive && unit.graftedTraitId != null && unit.graftedTraitId!.isNotEmpty) {
                        statusBadges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A148C),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFFEA80FC), width: 0.5),
                          ),
                          child: const Text('🧬GRAFT', style: TextStyle(fontSize: 5.5, color: Color(0xFFF3E5F5), fontWeight: FontWeight.bold)),
                        ));
                      }

                      if (statusBadges.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 1.5,
                          alignment: WrapAlignment.center,
                          children: statusBadges,
                        ),
                      );
                    },
                  ),

                  // Posture indicator: Show when unit is selected to prevent grid clutter
                  if (isSelected && unit.isAlive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: unit.archetype == UnitArchetype.vanguardMelee
                            ? (unit.currentDepth == RowDepth.front
                                ? const Color(0xFFC62828).withValues(alpha: 0.9)
                                : (unit.currentDepth == RowDepth.mid
                                    ? const Color(0xFFEF6C00).withValues(alpha: 0.9)
                                    : const Color(0xFF1565C0).withValues(alpha: 0.9)))
                            : const Color(0xFF263238).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: unit.currentDepth == RowDepth.front
                              ? const Color(0xFFFF5252)
                              : (unit.currentDepth == RowDepth.mid ? const Color(0xFFFFB74D) : const Color(0xFF4FC3F7)),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        unit.archetype == UnitArchetype.vanguardMelee
                            ? (unit.currentDepth == RowDepth.front ? 'BRAWL' : (unit.currentDepth == RowDepth.mid ? 'ADVANCE' : 'BRACED'))
                            : (unit.currentDepth == RowDepth.front ? 'POINT-BLANK' : 'CASTING'),
                        style: const TextStyle(
                          fontSize: 6.0,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                  // Unit name label: Only shown when selected
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                      ),
                      child: Text(
                        unit.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD54F),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),

            // 4. Floating Damage / Effect Pop Text (Live execution with animated rise & fade)
            if (_floatingPops.any((p) => p.unitId == unit.id && !p.isExpired)) ...[
              () {
                final pop = _floatingPops.firstWhere((p) => p.unitId == unit.id && !p.isExpired);
                final t = pop.progress;
                // Vertical rise: floats upward by up to 26 pixels
                final double riseY = (t * 26.0);
                // Opacity curve: solid for first 65%, then fades out to 0
                final double opacity = (1.0 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0);
                // Scale bounce on entry
                final double scale = pop.isCrit
                    ? (t < 0.2 ? 1.0 + (t / 0.2) * 0.35 : 1.35 - ((t - 0.2) * 0.35))
                    : 1.0;

                return Positioned(
                  top: (isBoss ? -34 : -26) - riseY,
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
              }(),
            ] else if (floatingPop != null)
              Positioned(
                top: isBoss ? -34 : -26,
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
                top: isBoss ? -38 : -30,
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
                          // Proportional White/Cyan Shield Overlay
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

            // 6. Active Ability Hit Sprite Sheet VFX (e.g. Fire / Sun Magic Circle Hit)
            if (isDamaged && (floatingPop == null || !floatingPop.contains('+')))
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: isBoss ? bossSpanWidth * 1.3 : tileWidth * 1.5,
                      height: isBoss ? (tileHeight * 2.6) : (tileHeight * 2.2),
                      child: SpriteSheetAnimation(
                        assetPath: 'assets/animations/vfx/sun_burst_circle_sheet.png',
                        columns: 8,
                        rows: 5,
                        totalFrames: 40,
                        duration: const Duration(milliseconds: 800),
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

  Widget _buildPreBattleStagingDock({bool isLandscapeMobile = false}) {
    final livingAllies = _engine.playerUnits.where((u) => u.isAlive).toList();
    final int deployedCount = livingAllies.where((u) => u.occupiedNodes.isNotEmpty).length;
    final int totalCount = livingAllies.length;
    final double dockHeight = isLandscapeMobile ? 62.0 : 78.0;

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
              const SizedBox(height: 5),

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
                width: isLandscapeMobile ? 32 : 40,
                height: isLandscapeMobile ? 44 : 56,
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
        child: Transform.scale(
          scale: 1.15,
          child: Opacity(opacity: 0.90, child: cardWidget),
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
        child: cardWidget,
      ),
    );
  }

  /// Ultimate Burst Pop-Out Mini-Slate Dock (HUD pull-out tray)
  Widget _buildUltimatePopOutDock({bool isLandscapeMobile = false}) {
    final livingAllies = _engine.playerUnits.where((u) => u.isAlive).toList();
    if (livingAllies.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: isLandscapeMobile ? 2 : 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(top: BorderSide(color: Color(0xFF222230), width: 1.0)),
      ),
      child: Row(
        children: [
          // Crest & Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 14),
              const SizedBox(width: 4),
              Text(
                'ULTIMATES',
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: isLandscapeMobile ? 36 : 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: livingAllies.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final unit = livingAllies[index];
                  return _buildUltimateMiniSlate(unit);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltimateMiniSlate(CombatUnitState unit) {
    final isReady = unit.isUltimateReady;
    final double gaugePct = (unit.ultimateGauge / 100.0).clamp(0.0, 1.0);
    final isSelected = _selectedUltimateUnitId == unit.id;

    final Widget slateWidget = Container(
      width: 105,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isReady
            ? const Color(0xFF261C0E).withValues(alpha: 0.95)
            : const Color(0xFF14141E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isReady
              ? const Color(0xFFFFD54F)
              : (isSelected ? const Color(0xFF00E5FF) : Colors.white12),
          width: isReady ? 1.6 : 0.8,
        ),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Unit Portrait in Gothic Frame
          Container(
            width: 28,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isReady ? const Color(0xFFFFD54F) : Colors.white24,
                width: 0.8,
              ),
              color: Colors.black45,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.asset(
                unit.assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, color: Colors.white38, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Info & Meter
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.name.split(' ').first.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                          color: isReady ? const Color(0xFFFFE082) : Colors.white70,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Lv.${unit.level}',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFD54F),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  isReady ? 'READY! ⚡' : '${unit.ultimateGauge}%',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: isReady ? const Color(0xFFFFD54F) : Colors.white38,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                // Progress Bar
                Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: gaugePct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isReady ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!isReady) {
      return slateWidget;
    }

    // When charged, unit portrait can be dragged onto the battlefield with 30% tactical bullet-time
    return Draggable<String>(
      data: 'ultimate:${unit.id}',
      onDragStarted: () {
        setState(() {
          _draggedUltimateUnitId = unit.id;
          _selectedUltimateUnitId = null;
          _selectedCardId = null;
          _selectedUnitId = null;
        });
        _engine.setBulletTime(true);
      },
      onDragEnd: (_) {
        setState(() {
          _draggedUltimateUnitId = null;
          _hoveredTileGRow = null;
          _hoveredTileCol = null;
        });
        _engine.setBulletTime(false);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.15,
          child: slateWidget,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          // If clicked, cast on default primary target
          _engine.castUltimate(unit.id);
        },
        child: slateWidget,
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

  /// Rank & Rite Spec Sec 2: Turn Action Decision Tray
  /// Triggered whenever an ally reaches 10,000 TM. Execution pauses so player can:
  /// 1. Cast 1 Tuning Slip from Sculptor Tray (Vitae pool <= 7).
  /// 2. Attack / Cast Signature Skill (100% TM cost -> 0 TM).
  /// 3. Reposition (1-tile shift, 25% TM cost -> 7,500 TM retained).
  Widget _buildTurnActionDecisionTray(CombatUnitState unit, {bool isLandscapeMobile = false}) {
    final double trayHeight = isLandscapeMobile ? 64.0 : 86.0;
    final int curCol = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.column : 0;
    final int curRow = unit.occupiedNodes.isNotEmpty ? unit.occupiedNodes.first.row : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      child: Row(
        children: [
          // Unit Avatar & Turn Ready Indicator
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
                        if (_engine.hasCastTuningSlipThisTurn) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'SLIP CAST',
                              style: TextStyle(fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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

          // Action 1: ATTACK / SKILL (100% TM Cost -> 0 TM)
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(unit.isSignatureReady ? Icons.auto_awesome : Icons.sports_mma, size: 16),
              label: Text(
                unit.isSignatureReady
                    ? 'SIGNATURE SKILL\n(0 TM / 100% Cost)'
                    : 'ATTACK & ABILITY\n(0 TM / 100% Cost)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, height: 1.15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: unit.isSignatureReady ? const Color(0xFF7B1FA2) : const Color(0xFFB3261E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: unit.isSignatureReady ? const Color(0xFFEA80FC) : const Color(0xFFFF8A80),
                    width: 1.2,
                  ),
                ),
              ),
              onPressed: () {
                setState(() {
                  _engine.executeUnitAction(unit, isReposition: false);
                });
              },
            ),
          ),
          const SizedBox(width: 8),

          // Action 2: REPOSITION / SHIFT (25% TM Cost -> 7,500 TM retained)
          Expanded(
            child: PopupMenuButton<String>(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF006064),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz, color: Color(0xFFE0F7FA), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'TACTICAL SHIFT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFE0F7FA)),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '(7,500 TM / 25% Cost)',
                      style: TextStyle(fontSize: 8.5, color: Color(0xFF80DEEA), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
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
}

/// 2.5D Isometric Diamond Tile Plinth Painter
/// Inspired by the tactical tabletop grid presentation in The Banner Saga & Dragonheir: Silent Gods.
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

  const _FloatingCombatText({
    required this.id,
    required this.unitId,
    required this.text,
    required this.color,
    required this.borderColor,
    this.fontSize = 11.0,
    this.isCrit = false,
    required this.createdMs,
    this.durationMs = 950,
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

