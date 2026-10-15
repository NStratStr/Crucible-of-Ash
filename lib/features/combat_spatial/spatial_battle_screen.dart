import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'models/spatial_combat_models.dart';
import 'spatial_combat_engine.dart';

/// Experimental Spatial Combat Simulation Screen (GDD v3.2 Extension)
/// Features:
/// - 3-Row x 5-Column Isometric/Tactical battlefield plane
/// - Multi-Node Footprints (1x1 standard, 1x2 horizontal behemoths like Gorgoroth)
/// - Geometric Skill Vectors & Live Telegraph Shading (T-Cleaves, Crosses, Row Scythes)
/// - Tactical Plinth Triage: Drag-and-drop repositioning during 30% bullet-time
/// - Live Burn Pit Card Cycling & Sunder Mechanics
class SpatialBattleScreen extends StatefulWidget {
  final VoidCallback? onBackToStandardCombat;

  const SpatialBattleScreen({
    super.key,
    this.onBackToStandardCombat,
  });

  @override
  State<SpatialBattleScreen> createState() => _SpatialBattleScreenState();
}

class _SpatialBattleScreenState extends State<SpatialBattleScreen> {
  late final SpatialCombatEngine _engine;
  Timer? _loopTimer;
  String? _selectedUnitId;
  String? _selectedCardId;
  SpatialCombatCard? _draggedCard;
  String? _selectedUltimateUnitId;
  String? _draggedUltimateUnitId;
  int? _hoveredTileGRow;
  int? _hoveredTileCol;

  // Visual Combat Feedback & VFX State
  String? _lastHandledEventId;
  String? _attackingUnitId;
  String? _damagedUnitId;
  String? _activeSkillName;
  String? _activeSkillCasterName;
  bool _isPlayerSkillBanner = false;
  final Map<String, String> _unitFloatingPops = {};
  final List<Timer> _animTimers = [];
  final List<_CombatVfx> _activeVfx = [];

  @override
  void initState() {
    super.initState();
    _engine = SpatialCombatEngine();
    _engine.isActionPauseEnabled = true;
    _engine.addListener(_onEngineUpdate);
    _startLoop();
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

    if (event.skillName.contains('Smite') || event.skillName.contains('SHATTERS')) {
      vfxType = 'shatter';
      primaryColor = const Color(0xFFFFD54F);
      secondaryColor = const Color(0xFF00E5FF);
      durationMs = 800;
    } else if (event.skillName.contains('Sun') || event.skillName.contains('Orb') || event.skillName.contains('Cinder') || event.skillName.contains('Bolt')) {
      vfxType = 'beam';
      primaryColor = event.isPlayerAttacker ? const Color(0xFFFFD54F) : const Color(0xFFFF7043);
      secondaryColor = const Color(0xFFFFEB3B);
      durationMs = 600;
    } else if (event.isHeal || event.skillName.contains('Phalanx')) {
      vfxType = 'shockwave';
      primaryColor = const Color(0xFF00E5FF);
      secondaryColor = const Color(0xFF80D8FF);
      durationMs = 700;
    } else if (event.isCrit) {
      vfxType = 'slash';
      primaryColor = const Color(0xFFFF1744);
      secondaryColor = const Color(0xFFFFD54F);
      durationMs = 750;
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

    setState(() {
      _activeVfx.add(newVfx);
      _attackingUnitId = event.attackerId;
      _damagedUnitId = event.targetId;
      _activeSkillName = event.skillName;
      _activeSkillCasterName = event.attackerName;
      _isPlayerSkillBanner = event.isPlayerAttacker;
      if (event.isHeal) {
        if (event.skillName == 'Phalanx Intercept') {
          _unitFloatingPops[event.targetId] = '+35 🛡️ ARMOR';
        } else if (event.skillName == 'Stoke the Embers') {
          _unitFloatingPops[event.targetId] = '+2 ⚡ FOCUS';
        } else {
          _unitFloatingPops[event.targetId] = '+HEAL';
        }
      } else {
        _unitFloatingPops[event.targetId] = '-${event.damage} DMG';
        if (event.isCrit) {
          _unitFloatingPops[event.targetId] = '💥 -${event.damage} CRIT!';
        }
        if (event.bleedStacks > 0) {
          _unitFloatingPops[event.targetId] = '-${event.damage} DMG (🩸+${event.bleedStacks})';
        }
      }
    });

    // Clean up VFX after its duration
    final tVfx = Timer(Duration(milliseconds: durationMs + 50), () {
      if (mounted) {
        setState(() {
          _activeVfx.removeWhere((v) => v.id == newVfx.id);
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
        });
        _engine.clearActiveAction();
      }
    });
    _animTimers.add(t2);
  }

  void _startLoop() {
    _loopTimer?.cancel();
    // Paced loop: ~50ms per tick (~20 ticks/sec default), slowed by simulationSpeed when active
    const baseIntervalMs = 50;
    _loopTimer = Timer.periodic(const Duration(milliseconds: baseIntervalMs), (timer) {
      if (!mounted) return;
      if (_engine.isRunning) {
        _engine.stepTick();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gorgoroth = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss').firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141E),
        elevation: 0,
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
            const Expanded(
              child: Text(
                'SPATIAL NODE ARENA: THE SUNDER',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Play / Pause Simulation
          IconButton(
            icon: Icon(
              _engine.isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _engine.isRunning ? const Color(0xFFFFD54F) : const Color(0xFF81C784),
              size: 26,
            ),
            tooltip: _engine.isRunning ? 'Pause 30Hz Simulation' : 'Run 30Hz Simulation',
            onPressed: () {
              setState(() {
                _engine.isRunning = !_engine.isRunning;
              });
            },
          ),
          // Step 1 Tick Button for Testing
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white70),
            tooltip: 'Advance 1 Tick',
            onPressed: () {
              _engine.stepTick();
            },
          ),
          // Fast-Forward to Tick 135 (Telegraph moment)
          TextButton(
            onPressed: () {
              while (_engine.currentTick < 135) {
                _engine.stepTick();
              }
            },
            child: const Text('TICK 135', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11)),
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            tooltip: 'Reset Encounter',
            onPressed: () {
              _engine.setupSunderAtAshenGate();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD: Status Banner, Focus Bar & Boss Telemetry
            _buildTopStatusRibbon(gorgoroth),

            // Persistent Action & Tactical Instruction Banner
            if (_engine.lastBannerMessage != null || _selectedCardId != null || _selectedUnitId != null)
              _buildTacticalPromptBanner(),

            // Live Skill Invocation Banner
            if (_activeSkillName != null)
              _buildSkillCutInBanner(),

            // Live Tactical Battlefield (Enemy 3-Rows + Clash Line + Player 3-Rows)
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Atmospheric Volcanic Chasm Arena Backdrop
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/volcanic_chasm_battlefield.jpg',
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
                      // Substantially scaled grid size so tiles and units fill the scene proudly
                      final double tileWidth = isDesktop ? 152.0 : 96.0;
                      final double tileHeight = isDesktop ? 76.0 : 48.0;

                      return Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 24.0 : 8.0,
                                vertical: isDesktop ? 12.0 : 6.0,
                              ),
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

                  // Victory / Defeat Tactical Overlay Banner
                  if (_engine.isVictory || _engine.isDefeat)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.75),
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                  size: 40,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _engine.isVictory ? 'THE ASHEN GATE SURPASSED' : 'RESONANCE SEVERED',
                                  style: TextStyle(
                                    color: _engine.isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF5252),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _engine.isVictory
                                      ? 'Gorgoroth and the Synod cohort have crumbled into inert slag.'
                                      : 'All constructs have fallen. Your neural tether dissipates into the miasma.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),

                                // Star Rating & Instant Sweep Unlock (GDD §7.3)
                                if (_engine.isVictory) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(3, (i) {
                                      final filled = i < _engine.starRating;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: Icon(
                                          filled ? Icons.star : Icons.star_border,
                                          color: filled ? const Color(0xFFFFD54F) : Colors.white24,
                                          size: 24,
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _engine.isFlawlessClear
                                        ? '🌟 3-STAR FLAWLESS CLEAR! INSTANT EXTRACTION UNLOCKED'
                                        : '${_engine.starRating}-STAR CLEAR (${_engine.casualtiesCount} Casualties)',
                                    style: TextStyle(
                                      color: _engine.isFlawlessClear ? const Color(0xFFFFE082) : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),

                                  // Loot & Currencies Reagents (GDD §7.1)
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C0C14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Unbound Ash
                                        const Icon(Icons.blur_on, color: Color(0xFFB0BEC5), size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${_engine.rewardUnboundAsh} Ash',
                                          style: const TextStyle(color: Color(0xFFECEFF1), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 12),
                                        // Distilled Vitae
                                        const Icon(Icons.opacity, color: Color(0xFFE53935), size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${_engine.rewardDistilledVitae} Vitae',
                                          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        if (_engine.rewardBossReagent != null) ...[
                                          const SizedBox(width: 12),
                                          const Icon(Icons.whatshot, color: Color(0xFFFF9100), size: 14),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Brim-Slag Core',
                                            style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _engine.setupSunderAtAshenGate();
                                        });
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('REPLAY ENCOUNTER'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2C2216),
                                        foregroundColor: const Color(0xFFFFD54F),
                                        side: const BorderSide(color: Color(0xFFFFD54F)),
                                      ),
                                    ),
                                    if (widget.onBackToStandardCombat != null) ...[
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        onPressed: widget.onBackToStandardCombat,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: const BorderSide(color: Colors.white24),
                                        ),
                                        child: const Text('EXIT TO HUB'),
                                      ),
                                    ],
                                  ],
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

            // Ultimate Burst Pop-Out Mini-Slate Dock (Player-Initiated Drag)
            _buildUltimatePopOutDock(),

            // Tactical Card Hand & Burn Pit
            _buildTacticalHandDock(),

            // Live 30 Hz Combat Event Log
            _buildCombatLogConsole(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusRibbon(CombatUnitState? boss) {
    final double focusProgress = ((_engine.currentTick % 40) / 40.0).clamp(0.0, 1.0);

    // Collect next impending turns sorted by closeness to 10,000 AP threshold
    final allLivingUnits = [..._engine.playerUnits, ..._engine.enemyUnits].where((u) => u.isAlive).toList();
    allLivingUnits.sort((a, b) {
      final aTicksLeft = ((SpatialCombatEngine.tickThreshold - a.currentAp) / max(1, a.speed)).clamp(0.0, 999.0);
      final bTicksLeft = ((SpatialCombatEngine.tickThreshold - b.currentAp) / max(1, b.speed)).clamp(0.0, 999.0);
      return aTicksLeft.compareTo(bTicksLeft);
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(bottom: BorderSide(color: Color(0xFF282838), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
              // 2c. Ashen Reckoning Soft Enrage Status (GDD §6.3)
              if (_engine.isAshenReckoning)
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
              const Spacer(),

              // 3. Boss Telegraph Execution Warning Badge
              if (boss != null && boss.pendingIntent != null)
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
          ),

          const SizedBox(height: 4),

          // 4. Live Initiative Action Timeline (ATB Sequence Preview)
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Text(
                  'NEXT TURN ⏱️',
                  style: TextStyle(fontSize: 8.0, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allLivingUnits.take(5).length,
                    separatorBuilder: (context, _) => const Icon(Icons.chevron_right, size: 12, color: Colors.white24),
                    itemBuilder: (context, idx) {
                      final u = allLivingUnits[idx];
                      final isAlly = u.isPlayer;
                      final apPercent = ((u.currentAp / SpatialCombatEngine.tickThreshold) * 100).clamp(0, 100).toInt();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isAlly ? const Color(0xFF1B3A24) : const Color(0xFF3E1C1D),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: isAlly ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              u.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: isAlly ? const Color(0xFFA5D6A7) : const Color(0xFFFFCDD2),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$apPercent%',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontFamily: 'monospace',
                                color: isAlly ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
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

    // Multi-node behemoth anchor check: Gorgoroth occupies 2 tiles; render model only on anchor node (col 1, row 0)
    final bool isAnchorCell = occupant == null ||
        (occupant.occupiedNodes.first.column == col && occupant.occupiedNodes.first.row == row);
    final bool isBossSecondaryNode = occupant != null && !isAnchorCell;

    // Movement stat range validation for selected unit
    final selectedUnit = _selectedUnitId != null
        ? _engine.playerUnits.where((u) => u.id == _selectedUnitId && u.isAlive).firstOrNull
        : null;
    final bool isReachable = isPlayerSquad &&
        selectedUnit != null &&
        occupant == null &&
        selectedUnit.canMoveTo(col, row);

    final bool isSelected = _selectedUnitId != null && occupant?.id == _selectedUnitId;

    // Tactical Spell & Ultimate AOE Highlight Overlay calculation:
    final activeCard = _draggedCard ?? (_selectedCardId != null ? _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull : null);
    final activeUltimateUnitId = _draggedUltimateUnitId ?? _selectedUltimateUnitId;
    bool isSpellAoeAffected = false;
    if (activeUltimateUnitId != null && _hoveredTileGRow != null && _hoveredTileCol != null) {
      final affectedList = _getUltimateAffectedGridCells(activeUltimateUnitId, _hoveredTileGRow!, _hoveredTileCol!);
      isSpellAoeAffected = affectedList.any((c) => c.gRow == gRow && c.col == col);
    } else if (activeCard != null) {
      if (_hoveredTileGRow != null && _hoveredTileCol != null) {
        final affectedList = _getSpellAffectedGridCells(activeCard, _hoveredTileGRow!, _hoveredTileCol!);
        isSpellAoeAffected = affectedList.any((c) => c.gRow == gRow && c.col == col);
      } else if (_selectedCardId != null) {
        // If card is selected by click, preview AOE if this cell is targetable
        if (activeCard.id == 'sun_ashlar_wrath') {
          isSpellAoeAffected = !isPlayerSquad;
        } else if (activeCard.id == 'stoke_the_embers') {
          isSpellAoeAffected = isPlayerSquad;
        } else if (activeCard.id == 'phalanx_intercept') {
          isSpellAoeAffected = isPlayerSquad && occupant != null;
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
          // Offensive spells target living enemies
          return !isPlayerSquad && occupant != null;
        } else {
          // Unit movement triage: only allow if in player squad, unoccupied, and within unit moveRange
          final unitId = data.replaceFirst('unit:', '');
          final unit = _engine.playerUnits.where((u) => u.id == unitId && u.isAlive).firstOrNull;
          if (unit == null) return false;
          return isPlayerSquad && occupant == null && unit.canMoveTo(col, row);
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
            _selectedUnitId = null;
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
                        : (isBossSecondaryNode
                            ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                            : (isPlayerSquad
                                ? const Color(0xFF304FFE).withValues(alpha: 0.12)
                                : const Color(0xFFFF1744).withValues(alpha: 0.10))))));

        final Color borderColor = isSpellAoeAffected
            ? const Color(0xFFFFD54F).withValues(alpha: 0.95)
            : (isTelegraphed
                ? const Color(0xFFFF1744).withValues(alpha: 0.90)
                : (isDropCandidate
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.85)
                    : (isReachable
                        ? const Color(0xFF00E676).withValues(alpha: 0.85)
                        : (isSelected
                            ? const Color(0xFFFFD54F)
                            : (isBossSecondaryNode
                                ? const Color(0xFFFF8A80).withValues(alpha: 0.35)
                                : (isPlayerSquad
                                    ? const Color(0xFF82B1FF).withValues(alpha: 0.38)
                                    : const Color(0xFFFF8A80).withValues(alpha: 0.32)))))));

        final bool hasGlow = isSpellAoeAffected || isTelegraphed || isSelected || isDropCandidate || isReachable;
        final Color glowColor = isSpellAoeAffected
            ? const Color(0xFFFFD54F)
            : (isTelegraphed
                ? const Color(0xFFFF1744)
                : (isReachable
                    ? const Color(0xFF00E676)
                    : (isDropCandidate ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F))));

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
              // Reachable Movement Indicator / Move Button for Empty Cells
              if (isReachable)
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _engine.movePlayerUnit(selectedUnit.id, col, row);
                      setState(() {
                        _selectedUnitId = null;
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
                            'MOVE',
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
                        if (selectedUnit.canMoveTo(col, row)) {
                          _engine.movePlayerUnit(selectedUnit.id, col, row);
                          setState(() => _selectedUnitId = null);
                        } else {
                          setState(() {
                            _engine.lastBannerMessage =
                                '⚠️ ${selectedUnit.name} can only move ${selectedUnit.moveRange} tile(s)!';
                          });
                        }
                      } else if (_selectedCardId != null) {
                        // Cast clicked card on target tile if applicable (e.g. Stoke or Ashlar)
                        final card = _engine.hand.where((c) => c.id == _selectedCardId).firstOrNull;
                        if (card != null && (card.id == 'stoke_the_embers' || card.id == 'sun_ashlar_wrath')) {
                          _engine.castCard(card.id, targetCol: col, targetRow: row);
                          setState(() => _selectedCardId = null);
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

              // Occupant Miniature (Rendered on Anchor node)
              if (occupant != null && isAnchorCell)
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
                                _selectedCardId = null; // deselect card
                              });
                            } else {
                              // Clicked enemy unit
                              if (_draggedCard != null) {
                                _engine.castCard(_draggedCard!.id, targetUnit: occupant);
                                setState(() => _draggedCard = null);
                              }
                            }
                          },
                          child: isPlayerSquad
                              ? Draggable<String>(
                                  data: 'unit:${occupant.id}',
                                  maxSimultaneousDrags: 1,
                                  onDragStarted: () {
                                    setState(() {
                                      _selectedUnitId = occupant.id;
                                      _selectedCardId = null;
                                    });
                                    _engine.setBulletTime(true);
                                  },
                                  onDragEnd: (_) {
                                    _engine.setBulletTime(false);
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
                                  phantomEffect: phantomEffect,
                                ),
                        ),
                      ),
                    );
                  },
                ),

              // Threat Marker for Cleave telegraph
              if (isTelegraphed)
                const Positioned(
                  bottom: 2,
                  right: 3,
                  child: Icon(Icons.close, color: Color(0xFFFF5252), size: 14),
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

    if (_selectedCardId != null) {
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
          message = '⚔️ ${unit.name.toUpperCase()} [$posture] (AP: $apPct%): Click glowing [MOVE] tile (Costs 50% AP)!';
          themeColor = const Color(0xFF00E676);
          icon = Icons.directions_run;
        } else {
          message = '⚠️ ${unit.name.toUpperCase()} [$posture] (AP: $apPct%): Needs 50% AP to reposition!';
          themeColor = const Color(0xFFFF9100);
          icon = Icons.hourglass_top;
        }
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
          if (_selectedCardId != null || _selectedUnitId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCardId = null;
                  _selectedUnitId = null;
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
          Icon(
            _isPlayerSkillBanner ? Icons.auto_awesome : Icons.warning_rounded,
            color: themeColor,
            size: 18,
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
    // transparent padding. We scale them up so their physical figure matches Valeria's scale!
    double unitScaleMultiplier = 1.0;
    if (unit.id == 'pyre_zealot' || unit.templateId.contains('ghoul')) {
      unitScaleMultiplier = 1.45; // Ghoul crouches low; scale up plinth & figure
    } else if (unit.id == 'iron_footman') {
      unitScaleMultiplier = 1.25;
    } else if (unit.id == 'sanguine_blade') {
      unitScaleMultiplier = 1.35;
    } else if (unit.id == 'sun_smith') {
      unitScaleMultiplier = 1.20;
    } else if (unit.id == 'cinder_witch') {
      unitScaleMultiplier = 1.25;
    }

    final double bossSpanWidth = isBoss ? (2 * tileWidth) : tileWidth;
    final double baseWidth = isBoss ? bossSpanWidth * 0.75 : (tileWidth - 12) * unitScaleMultiplier;
    final double baseHeight = isBoss ? 28 : (14 * unitScaleMultiplier);
    // Units scale dynamically with tile size for commanding visual presence
    final double modelWidth = (isBoss ? bossSpanWidth * 1.15 : tileWidth * 0.95 * unitScaleMultiplier).clamp(60.0, 260.0);
    final double modelHeight = (isBoss
        ? (tileHeight * 3.6).clamp(160.0, 260.0)
        : (tileHeight * 2.2 * unitScaleMultiplier).clamp(80.0, 160.0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(hitShakeX, lungeY, 0),
      child: SizedBox(
        width: isBoss ? bossSpanWidth : tileWidth,
        height: tileHeight,
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
                    colors: [
                      factionColor.withValues(alpha: isSelected || isAttacking ? 0.75 : 0.35),
                      Colors.black87,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: factionColor.withValues(alpha: isSelected || isAttacking ? 0.6 : 0.2),
                      blurRadius: isSelected || isAttacking ? 8 : 4,
                    ),
                  ],
                ),
              ),
            ),

            // 1b. Stance Mastery Runic Plinth Aura (Tabletop visual condition cue)
            if (unit.hasStanceBonusReady || (unit.activeStance == StanceType.holdTheLine && unit.consecutiveTurnsStationary >= 1))
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
              bottom: 6,
              child: SizedBox(
                width: modelWidth,
                height: modelHeight,
                child: ColorFiltered(
                  colorFilter: unit.isDowned
                      ? const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.65, 0,
                        ])
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
              ),
            ),

            // 3. Status Badges & Selected Unit Indicator
            Positioned(
              top: isBoss ? -22 : -16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  if (unit.isDowned)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF37474F),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: Colors.white38, width: 0.6),
                      ),
                      child: const Text(
                        '🪨DOWNED PLINTH',
                        style: TextStyle(fontSize: 6.5, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (unit.reviveCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '💀FRACTURE x${unit.reviveCount}',
                        style: const TextStyle(fontSize: 6.0, color: Color(0xFFE1BEE7), fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (unit.bleedStacks > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '🩸${unit.bleedStacks}',
                        style: const TextStyle(fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (unit.burnDuration > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        '🔥BURNING',
                        style: TextStyle(fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (unit.isStunned)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBC02D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        '⚡STUNNED',
                        style: TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.w900),
                      ),
                    ),
                  if (unit.aegisShield > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B0FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '🛡️${unit.aegisShield}',
                        style: const TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  // Always display posture pill for active units
                  Container(
                    margin: const EdgeInsets.only(bottom: 1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: unit.archetype == UnitArchetype.vanguardMelee
                          ? (unit.currentDepth == RowDepth.front
                              ? const Color(0xFFC62828).withValues(alpha: 0.85)
                              : (unit.currentDepth == RowDepth.mid
                                  ? const Color(0xFFEF6C00).withValues(alpha: 0.85)
                                  : const Color(0xFF1565C0).withValues(alpha: 0.85)))
                          : const Color(0xFF263238).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: unit.currentDepth == RowDepth.front
                            ? const Color(0xFFFF5252)
                            : (unit.currentDepth == RowDepth.mid ? const Color(0xFFFFB74D) : const Color(0xFF4FC3F7)),
                        width: 0.5,
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
                  // Only show name when unit is selected to keep screen uncluttered
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

            // 4. Floating Damage / Effect Pop Text (Live execution)
            if (floatingPop != null)
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
  Widget _buildUltimatePopOutDock() {
    final livingAllies = _engine.playerUnits.where((u) => u.isAlive).toList();
    if (livingAllies.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              height: 44,
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
                Text(
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

  Widget _buildTacticalHandDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  width: 72,
                  height: 78,
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
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BURN PIT',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8A80),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Text(
                        '+1 FOCUS',
                        style: TextStyle(fontSize: 7.5, color: Color(0xFFFFD54F)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Cards in Hand
          Expanded(
            child: SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _engine.hand.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final card = _engine.hand[idx];
                  final canAfford = _engine.focus >= card.focusCost;

                    final isCardSelected = _selectedCardId == card.id;

                    return Draggable<String>(
                      data: 'card:${card.id}',
                      onDragStarted: () {
                        setState(() {
                          _draggedCard = card;
                          _selectedCardId = null;
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
                        child: _buildCardTile(card, canAfford, isFeedback: true),
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
                            _engine.castCard(card.id);
                            setState(() {
                              _selectedCardId = null;
                            });
                            return;
                          }

                          // If unit is already selected, cast immediately on it!
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

                          // Otherwise, toggle card selection for click-to-target
                          setState(() {
                            if (_selectedCardId == card.id) {
                              // Double tap on armed card auto-targets primary enemy / Gorgoroth!
                              final boss = _engine.enemyUnits.where((u) => u.id == 'gorgoroth_boss' && u.isAlive).firstOrNull ??
                                  _engine.enemyUnits.where((u) => u.isAlive).firstOrNull;
                              if (boss != null) {
                                _engine.castCard(card.id, targetUnit: boss);
                                _selectedCardId = null;
                                return;
                              }
                              _selectedCardId = null;
                            } else {
                              _selectedCardId = card.id;
                              _engine.lastBannerMessage = '✨ ${card.name.toUpperCase()} ARMED: Click an enemy or double-tap card to unleash!';
                            }
                          });
                        },
                        child: _buildCardTile(card, canAfford, isSelected: isCardSelected),
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
    }) {
      final Color borderColor = isSelected
          ? const Color(0xFFFFD54F)
          : (canAfford ? const Color(0xFF00E5FF) : Colors.white24);

      return Container(
        width: 110,
        height: 78,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2C2412)
              : (canAfford ? const Color(0xFF141724) : const Color(0xFF101014)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: isSelected || isFeedback ? 2.0 : 1.2,
          ),
          boxShadow: isFeedback || isSelected
              ? [
                  BoxShadow(
                    color: (isSelected ? const Color(0xFFFFD54F) : const Color(0xFF00E5FF)).withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Spell Art with soft gradient fade
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 52,
              child: Opacity(
                opacity: canAfford ? 0.35 : 0.15,
                child: Image.asset(
                  card.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Card Content Overlay
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.name,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: canAfford ? Colors.white : Colors.white38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 0.6),
                        ),
                        child: Text(
                          '${card.focusCost}F',
                          style: const TextStyle(fontSize: 8, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.description,
                    style: const TextStyle(fontSize: 7.5, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
      }
    }
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

