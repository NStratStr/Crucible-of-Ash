import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/utils/platform_fullscreen.dart';
import '../settings/settings_service.dart';
import '../relics/relic_service.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

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
  final String? encounterTitle;
  final String? backdropAsset;
  final bool isBossEncounter;
  final RelicService? relicService;

  const SpatialBattleScreen({
    super.key,
    this.onBackToStandardCombat,
    this.onVictory,
    this.onDefeat,
    this.initialPlayerUnits,
    this.initialEnemyUnits,
    this.encounterTitle,
    this.backdropAsset,
    this.isBossEncounter = false,
    this.relicService,
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> {
  late final SpatialCombatEngine _engine;
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
  double _tickAccumulator = 0.0;
  double _dashPhase = 0.0;

  // Visual Combat Feedback & VFX State
  String? _lastHandledEventId;
  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _activeSkillName;
  String? _activeSkillCasterName;
  bool _isPlayerSkillBanner = false;
  CombatUnitState? _activeUltimateUnit; // Active Ultimate Burst Cinematic Cut-in
  final Map<String, String> _unitFloatingPops = {};
  final List<_FloatingCombatText> _floatingPops = [];
  final List<Timer> _animTimers = [];
  final List<_CombatVfx> _activeVfx = [];
  final List<_GroundShockwaveRipple> _groundRipples = [];
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

    _engine = SpatialCombatEngine(
      initialPlayerEntities: players,
      initialEnemyEntities: enemies,
      title: widget.encounterTitle,
      isBossEncounter: widget.isBossEncounter,
      relicService: widget.relicService,
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
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      final bgmVol = _isMuted ? 0.0 : (settings.bgmVolume * 0.45);
      await _bgmPlayer!.setVolume(bgmVol);
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
      _sfxPlayer!.stop();
      _sfxPlayer!.setVolume(settings.sfxVolume * 0.70);
      _sfxPlayer!.play(AssetSource('audio/$sfxName'));
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
    final anchor = unit.occupiedNodes.first;
    final int col = anchor.column;
    final int localRow = anchor.row;
    final int gRow = unit.isPlayer ? (localRow + 4) : (2 - localRow);

    const int numGRows = 7;
    final double originX = (numGRows - 1) * (tileWidth * 0.5);
    final double originY = 0.0;

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

    if (event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova') || event.skillName.contains('Evisceration')) {
      vfxType = 'bloodnova';
      primaryColor = const Color(0xFFFF1744);
      secondaryColor = const Color(0xFFD50000);
      durationMs = 850;
      _playSfx('sfx_slash.wav'); // High-impact blood cleave
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

    // Check if event is a player Ultimate Burst
    final bool isUltimate = event.id.startsWith('ult_');
    if (isUltimate && caster != null && caster.isPlayer) {
      _activeUltimateUnit = caster;
      _playSfx('sfx_spell.wav');
    }

    // Camera Hit-Shake & Ground Ripple Shockwaves for heavy hits, boss strikes, crits, and bloodnovas
    final bool isBossStrike = event.attackerId == 'gorgoroth_boss';
    final bool isBloodnova = event.skillName.contains('Vitae Eruption') || event.skillName.contains('Bloodnova');
    final bool isHeavyImpact = event.isCrit || isBossStrike || isUltimate || isBloodnova || event.skillName.contains('Smite') || event.skillName.contains('Cataclysm');

    if (isHeavyImpact) {
      final double shakePower = isUltimate ? 8.5 : (isBossStrike ? 7.0 : (isBloodnova ? 6.5 : (event.isCrit ? 5.5 : 4.0)));
      _triggerScreenShake(intensity: shakePower);
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

    setState(() {
      _activeVfx.add(newVfx);
      _attackingUnitId = event.attackerId;
      _damagedUnitId = event.targetId;
      _activeSkillName = event.skillName;
      _activeSkillCasterName = event.attackerName;
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

      // Push floating popups for all secondary targets hit by multi-target / AOE spells
      if (event.secondaryTargetHits.isNotEmpty) {
        event.secondaryTargetHits.forEach((secId, secDmg) {
          final secText = '-$secDmg';
          _unitFloatingPops[secId] = secText;
          _floatingPops.removeWhere((p) => p.unitId == secId);
          _floatingPops.add(_FloatingCombatText(
            id: 'pop_${event.id}_${secId}_$nowMs',
            unitId: secId,
            text: secText,
            color: const Color(0xFFFF8A80),
            borderColor: const Color(0xFFD50000),
            fontSize: 11.0,
            isCrit: false,
            createdMs: nowMs,
            durationMs: 900,
          ));
        });
      }
    });

    // Clean up VFX after its duration
    final tVfx = Timer(Duration(milliseconds: durationMs + 50), () {
      if (mounted) {
        setState(() {
          _activeVfx.removeWhere((v) => v.id == newVfx.id);
          _floatingPops.removeWhere((p) => p.isExpired);
        });
      }
    });
    _animTimers.add(tVfx);

    // Reset visual lunge & floating pops after 1100ms
    final t1 = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _attackingUnitId = null;
          _damagedUnitId = null;
          _unitFloatingPops.remove(event.targetId);
        });
      }
    });
    _animTimers.add(t1);

    // Dismiss banner & resume combat ticks after 1600ms
    final t2 = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _activeSkillName = null;
          _activeUltimateUnit = null;
        });
        _engine.clearActiveAction();
      }
    });
    _animTimers.add(t2);
  }

  void _startLoop() {
    _loopTimer?.cancel();
    // Paced loop: ~50ms per tick (~20 ticks/sec default), scaled genuinely by simulationSpeed (0.3x in bullet-time)
    const baseIntervalMs = 50;
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
        _tickAccumulator += _engine.simulationSpeed;
        while (_tickAccumulator >= 1.0) {
          _tickAccumulator -= 1.0;
          _engine.stepTick();
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
    _bgmPlayer?.stop();
    _bgmPlayer?.dispose();
    _sfxPlayer?.stop();
    _sfxPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gorgoroth = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss').firstOrNull;
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

            // Persistent Action & Tactical Instruction Banner (when NOT in landscape mobile or zen mode)
            if (!_isZenMode &&
                !isLandscapeMobile &&
                (_engine.lastBannerMessage != null ||
                    _selectedCardId != null ||
                    _selectedUnitId != null ||
                    _selectedEnemyUnitId != null ||
                    _engine.isPreBattlePhase))
              _buildTacticalPromptBanner(),

            // Selected / Dragged Unit Combat Triad Inspector Strip (when NOT in landscape mobile or zen mode)
            if (!_isZenMode &&
                !isLandscapeMobile &&
                (_draggedUnitId != null || _selectedUnitId != null || _selectedEnemyUnitId != null))
              _buildUnitCombatTriadStrip(),

            // Live Skill Invocation Banner
            if (_activeSkillName != null)
              _buildSkillCutInBanner(),

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Atmospheric Battlefield Arena Backdrop
                  Positioned.fill(
                    child: Image.asset(
                      widget.backdropAsset ?? 'assets/images/volcanic_chasm_battlefield.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF0D0D14),
                      ),
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

                  // Interactive 2.5D Battlefield Arena Plane (Unified Isometric Board)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth >= 700;
                      // Substantially scaled grid size so tiles and units fill the scene proudly with tactile presence
                      final double tileWidth = isDesktop ? 190.0 : 130.0;
                      final double tileHeight = isDesktop ? 95.0 : 65.0;

                      return InteractiveViewer(
                        boundaryMargin: const EdgeInsets.all(180),
                        minScale: 0.4,
                        maxScale: 2.2,
                        clipBehavior: Clip.none,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 28.0 : 12.0,
                              vertical: isDesktop ? 16.0 : 8.0,
                            ),
                            child: Transform.translate(
                              offset: _screenShakeOffset,
                              child: _buildUnifiedIsometricBattlefield(
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // In-Combat Ultimate Burst Dramatic Cut-In Overlay
                  if (_activeUltimateUnit != null)
                    _buildUltimateCinematicOverlay(_activeUltimateUnit!),

                  // Mobile Landscape Floating Tactical Overlay (Top-Left corner)
                  if (!_isZenMode && isLandscapeMobile && (_draggedUnitId != null || _selectedUnitId != null || _selectedEnemyUnitId != null))
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 550),
                          child: _buildUnitCombatTriadStrip(),
                        ),
                      ),
                    ),

                  // Mobile Landscape Floating Prompt (Top Center)
                  if (!_isZenMode && isLandscapeMobile && (_selectedCardId != null || _engine.isPreBattlePhase))
                    Positioned(
                      top: (_draggedUnitId != null || _selectedUnitId != null || _selectedEnemyUnitId != null) ? 44 : 8,
                      left: 12,
                      right: 12,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 550),
                          child: _buildTacticalPromptBanner(),
                        ),
                      ),
                    ),

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

            // Ultimate Burst Pop-Out Mini-Slate Dock (Player-Initiated Drag)
            _buildUltimatePopOutDock(isLandscapeMobile: isLandscapeMobile),

            // Tactical Card Hand & Burn Pit
            _buildTacticalHandDock(isLandscapeMobile: isLandscapeMobile),

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
                        'FOCUS ${_engine.focus}/${_engine.maxFocus}',
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

                // 2b. Lady Valeria Commander Stance Badge (GDD 4.2)
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
                        _engine.isValeriaInFrontline ? 'BASTION (+25 ARMOR)' : 'REARGUARD (+20% WARD)',
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

                // Pre-Battle Deployment Start Button
                if (_engine.isPreBattlePhase)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _engine.startBattle();
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 16),
                    label: const Text(
                      'ENGAGE BATTLE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 4,
                      shadowColor: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                    ),
                  ),

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
      if (!unit.isAlive || unit.occupiedNodes.isEmpty) return;
      final bool isHoveringPlayerCell = (isPrimaryInspected &&
          _draggedUnitId == unit.id &&
          _hoveredTileCol != null &&
          _hoveredTileGRow != null &&
          _hoveredTileGRow! > 3);

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
        final bool isTargetBoss = target.footprint == UnitFootprint.quadColossus2x2 || target.footprint == UnitFootprint.horizontal1x2;
        final double tgtX;
        final double tgtY;
        if (isTargetBoss) {
          // Point directly to Gorgoroth's centered colossus coordinate (midCol 1.5, midGRow 1.5)
          tgtX = originX + (1.5 - 1.5) * (tileWidth * 0.5) + (tileWidth * 0.5);
          tgtY = originY + (1.5 + 1.5) * (tileHeight * 0.5) + (tileHeight * 0.5);
        } else {
          final targetNode = target.occupiedNodes.first;
          final int tgtCol = targetNode.column;
          final int tgtGRow = 2 - targetNode.row;
          tgtX = originX + (tgtCol - tgtGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
          tgtY = originY + (tgtCol + tgtGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
        }
        final Offset targetOffset = Offset(tgtX, tgtY);

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
            trajectories.add(_TrajectoryData(
              sourceOffset: sourceOffset,
              targetOffset: Offset(secX, secY),
              skillName: 'SPLASH / PIERCE',
              targetName: sec.name,
              color: trajColor,
              isSecondary: true,
              showLabel: false,
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
        final bool isEnemyBoss = enemy.footprint == UnitFootprint.quadColossus2x2 || enemy.footprint == UnitFootprint.horizontal1x2;
        final double srcX;
        final double srcY;
        if (isEnemyBoss) {
          srcX = originX + (1.5 - 1.5) * (tileWidth * 0.5) + (tileWidth * 0.5);
          srcY = originY + (1.5 + 1.5) * (tileHeight * 0.5) + (tileHeight * 0.5);
        } else {
          final eNode = enemy.occupiedNodes.first;
          final int eGRow = 2 - eNode.row;
          srcX = originX + (eNode.column - eGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
          srcY = originY + (eNode.column + eGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
        }

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
      final bool isEnemyBoss = enemy.footprint == UnitFootprint.quadColossus2x2 || enemy.footprint == UnitFootprint.horizontal1x2;
      final double srcX;
      final double srcY;
      if (isEnemyBoss) {
        srcX = originX + (1.5 - 1.5) * (tileWidth * 0.5) + (tileWidth * 0.5);
        srcY = originY + (1.5 + 1.5) * (tileHeight * 0.5) + (tileHeight * 0.5);
      } else {
        final eNode = enemy.occupiedNodes.first;
        final int eGRow = 2 - eNode.row;
        srcX = originX + (eNode.column - eGRow) * (tileWidth * 0.5) + (tileWidth * 0.5);
        srcY = originY + (eNode.column + eGRow) * (tileHeight * 0.5) + (tileHeight * 0.40);
      }
      final Offset sourceOffset = Offset(srcX, srcY);

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

          // Centered Behemoth Boss Layer (Gorgoroth 2x2 Colossus)
          // Positions the colossus at the exact geometric midpoint of his 4 occupied nodes
          // (Cols 1-2, Enemy Rows 0-1 / gRows 1-2), creating a symmetrical, epic tabletop presence.
          ..._engine.enemyUnits.where((u) => u.isAlive && (u.footprint == UnitFootprint.quadColossus2x2 || u.footprint == UnitFootprint.horizontal1x2)).map((boss) {
            final double bossSpanWidth = tileWidth * 2.2;
            final double bossSpanHeight = tileHeight * 2.0;

            // Gorgoroth 4-tile cluster: Cols 1-2, Enemy Rows 0-1 (gRows 1-2).
            // Midpoint of Col 1 & 2: midCol = 1.5.
            final double bossMidX = originX + (1.5 - 1.5) * (tileWidth * 0.5) + (tileWidth * 0.5);

            // In isometric projection:
            // The bottom-most diamond vertex of the 2x2 cluster is Col 2, gRow 2 (Enemy Front Col 3).
            // Its center point on screen is:
            // Y = originY + (2.0 + 2.0) * (tileHeight * 0.5) + (tileHeight * 0.5) = originY + 2.5 * tileHeight.
            // (Alternatively, the bottom vertex of the entire 4-tile zone is at Y = originY + 3.0 * tileHeight).
            // To seat Gorgoroth's base firmly in the lower half of his 4 tiles so his base plinth rests
            // on the bottom grid center (Y = originY + 2.5 * tileHeight):
            final double bottomGridCenterY = originY + (2.0 + 2.0) * (tileHeight * 0.5) + (tileHeight * 0.5);

            final double bossScreenLeft = bossMidX - (bossSpanWidth * 0.5);
            // The miniature base plinth is located at bottom: 4 inside bossSpanHeight.
            // Placing bossScreenTop so that (bossScreenTop + bossSpanHeight - 4) == bottomGridCenterY:
            final double bossScreenTop = bottomGridCenterY - bossSpanHeight + 4.0;

            final bool isSelected = _selectedEnemyUnitId == boss.id;

            return Positioned(
              left: bossScreenLeft,
              top: bossScreenTop,
              width: bossSpanWidth,
              height: bossSpanHeight,
              child: IgnorePointer(
                ignoring: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_draggedCard != null) {
                      _engine.castCard(_draggedCard!.id, targetUnit: boss);
                      setState(() => _draggedCard = null);
                    } else if (_selectedCardId != null) {
                      final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                      if (card != null) {
                        _engine.castCard(card.id, targetUnit: boss, targetCol: 1, targetRow: 0);
                        setState(() {
                          _selectedCardId = null;
                          _hoveredTileGRow = null;
                          _hoveredTileCol = null;
                        });
                      }
                    } else {
                      setState(() {
                        _selectedEnemyUnitId = (_selectedEnemyUnitId == boss.id) ? null : boss.id;
                        _selectedUnitId = null;
                        _selectedCardId = null;
                      });
                    }
                  },
                  child: Center(
                    child: _buildUnitMiniatureWidget(
                      boss,
                      tileWidth: tileWidth,
                      tileHeight: tileHeight,
                      colGap: 0.0,
                      isSelected: isSelected,
                    ),
                  ),
                ),
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
    switch (unitId) {
      case 'lady_valeria':
        // Wrath of Dawnbound: Entire enemy column (gRow 0, 1, 2 at targetCol)
        for (int gr = 0; gr <= 2; gr++) {
          cells.add((gRow: gr, col: targetCol));
        }
        break;

      case 'iron_footman':
        // Unbreakable Phalanx: All Frontline ally nodes (gRow 4, all 5 cols)
        for (int gc = 0; gc < 5; gc++) {
          cells.add((gRow: 4, col: gc));
        }
        break;

      case 'sanguine_blade':
        // Crimson Evisceration: Single enemy node
        cells.add((gRow: targetGRow, col: targetCol));
        break;

      case 'sun_smith':
        // Solar Crucible Ignition: Cross / 2x2 target pattern
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
    if (unit.id == 'sun_smith') {
      return simulatedRow == 2 ? 'Aetheric Piercing Beam (+1 Focus)' : 'Sun-Bolt Volley';
    }
    if (unit.archetype == UnitArchetype.vanguardMelee) {
      if (simulatedRow == 0) {
        return unit.id == 'lady_valeria' ? 'Sunbrand Slash (100% Impact)' : 'Shield Bash (100% + Stun)';
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
          if (unitId == 'iron_footman') return isPlayerSquad;
          return !isPlayerSquad; // Valeria, Sanguine, Sun-Smith target enemy grid/units
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
                if (occupant != null && isAnchorCell && occupant.footprint != UnitFootprint.quadColossus2x2 && occupant.footprint != UnitFootprint.horizontal1x2)
                  Builder(
                    builder: (context) {
                      final activeCard = _draggedCard ?? (_selectedCardId != null ? _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull : null);
                      final String? phantomEffect = (activeCard != null && (_hoveredTileGRow != null || _selectedCardId != null))
                          ? _getPhantomUnitEffect(occupant, activeCard, _hoveredTileGRow ?? gRow, _hoveredTileCol ?? col)
                          : null;

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
      if (_selectedUnitId != null) {
        final unit = _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull;
        if (unit != null) {
          message = '🎯 PRE-BATTLE: Drag or click any glowing tile to deploy or [⇄ SWAP] ${unit.name.toUpperCase()} • Translucent line shows basic attack target!';
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
        message = '🛡️ PRE-BATTLE DEPLOYMENT: Click or pick up any unit to inspect basic attack trajectories & freely arrange your squad!';
        themeColor = const Color(0xFFFFD54F);
        icon = Icons.touch_app;
      }
    } else if (_selectedCardId != null) {
      final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
      if (card != null) {
        message = '✨ ${card.name.toUpperCase()} ARMED: Click a target node or enemy on the grid to cast!';
        themeColor = const Color(0xFF00E5FF);
        icon = Icons.auto_awesome;
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _isPlayerSkillBanner
                ? 'assets/images/Spells/Support_spell_magic_circle.png'
                : 'assets/images/Spells/Attack_spell_magic_circle.png',
            width: 20,
            height: 20,
            errorBuilder: (_, __, ___) => Icon(
              _isPlayerSkillBanner ? Icons.auto_awesome : Icons.warning_rounded,
              color: themeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _activeSkillCasterName?.toUpperCase() ?? 'CONSTRUCT',
            style: TextStyle(
              color: themeColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          const Text('•', style: TextStyle(color: Colors.white38)),
          const SizedBox(width: 6),
          Text(
            _activeSkillName?.toUpperCase() ?? 'ATTACK',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
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

  Widget _buildUnitMiniatureWidget(
    CombatUnitState unit, {
    required double tileWidth,
    required double tileHeight,
    required double colGap,
    bool isDragging = false,
    bool isSelected = false,
    String? phantomEffect,
  }) {
    final bool isBoss = unit.footprint == UnitFootprint.quadColossus2x2 || unit.footprint == UnitFootprint.horizontal1x2;
    final double hpRatio = unit.maxHp > 0 ? (unit.hp / unit.maxHp).clamp(0.0, 1.0) : 0.0;
    final double apRatio = (unit.currentAp / SpatialCombatEngine.tickThreshold).clamp(0.0, 1.0);
    final Color factionColor = unit.isPlayer ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);

    final bool isAttacking = _attackingUnitId == unit.id;
    final bool isDamaged = _damagedUnitId == unit.id;
    final String? floatingPop = _unitFloatingPops[unit.id];

    // Lunge forward across clash line during attack
    final double lungeY = isAttacking ? (unit.isPlayer ? -14.0 : 14.0) : 0.0;
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
      transform: Matrix4.translationValues(hitShakeX, lungeY, 0),
      child: SizedBox(
        width: isBoss ? bossSpanWidth : tileWidth,
        height: isBoss ? (tileHeight * 2.0) : tileHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Tabletop 2.5D Contact Drop Shadow & Soft Ground Glow
            Positioned(
              bottom: 4,
              child: Container(
                width: baseWidth,
                height: baseHeight,
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
                                  ? const ColorFilter.mode(Color(0xFFFF1744), BlendMode.srcATop)
                                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst)),
                          child: Image.asset(
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
                      if (unit.isDowned) {
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
                          // Base HP
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hpRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: unit.isPlayer ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
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
          ],
        ),
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

  const _TrajectoryData({
    required this.sourceOffset,
    required this.targetOffset,
    required this.skillName,
    required this.targetName,
    required this.color,
    this.isSecondary = false,
    this.showLabel = true,
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

      final textSpan = TextSpan(
        text: '⚔️ ${traj.skillName} • TARGET: ${traj.targetName}',
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

