import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/trait_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/widgets/gothic_card_frame_widget.dart';
import '../../shared/widgets/living_atmosphere_background.dart';
import 'crucible_service.dart';

class CrucibleScreen extends StatefulWidget {
  final List<UnitEntity> availableInventory;
  final ValueChanged<UnitEntity> onFusionComplete;
  final int totalIchor;
  final int bloodlineSigils;
  final ValueChanged<int>? onIchorChanged;
  final ValueChanged<int>? onSigilsChanged;
  final void Function(UnitEntity child, List<String> sacrificedParentIds)? onFusionExecuted;
  final void Function(UnitEntity updatedUnit, int ichorCost)? onUnitLeveled;

  const CrucibleScreen({
    super.key,
    required this.availableInventory,
    required this.onFusionComplete,
    this.totalIchor = 9999,
    this.bloodlineSigils = 99,
    this.onIchorChanged,
    this.onSigilsChanged,
    this.onFusionExecuted,
    this.onUnitLeveled,
  });

  @override
  State<CrucibleScreen> createState() => _CrucibleScreenState();
}

class _CrucibleScreenState extends State<CrucibleScreen>
    with SingleTickerProviderStateMixin {
  UnitEntity? _progenitorA;
  UnitEntity? _progenitorB;
  String? _selectedGraftTraitId;
  bool _isPerformingRitual = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // Pre-slot available matching pair if nothing selected
    _autoSlotFirstCompatiblePair();
  }

  void _autoSlotFirstCompatiblePair() {
    final list = widget.availableInventory;
    for (int i = 0; i < list.length; i++) {
      for (int j = i + 1; j < list.length; j++) {
        if (list[i].speciesId == list[j].speciesId) {
          _progenitorA = list[i];
          _progenitorB = list[j];
          _selectedGraftTraitId = list[i].nativeTraitId;
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String _selectedSpeciesFilter = 'ALL';
  int? _selectedGenFilter;

  int get _requiredIchorCost {
    if (_progenitorA == null || _progenitorB == null) return 0;
    final nextGen = (max(_progenitorA!.generation, _progenitorB!.generation) + 1).clamp(1, 4);
    switch (nextGen) {
      case 2:
        return 150;
      case 3:
        return 300;
      case 4:
        return 500;
      default:
        return 150;
    }
  }

  int get _requiredSigilsCost {
    if (_progenitorA == null || _progenitorB == null) return 0;
    final nextGen = (max(_progenitorA!.generation, _progenitorB!.generation) + 1).clamp(1, 4);
    return nextGen >= 4 ? 1 : 0;
  }

  bool get _hasSufficientIchor => widget.totalIchor >= _requiredIchorCost;
  bool get _hasSufficientSigils => widget.bloodlineSigils >= _requiredSigilsCost;
  bool get _hasSufficientResources => _hasSufficientIchor && _hasSufficientSigils;

  bool get _canFuse =>
      _progenitorA != null &&
      _progenitorB != null &&
      _progenitorA!.speciesId == _progenitorB!.speciesId &&
      _selectedGraftTraitId != null &&
      _hasSufficientResources &&
      !_isPerformingRitual;

  void _selectUnit(UnitEntity unit) {
    setState(() {
      if (_progenitorA == null) {
        _progenitorA = unit;
        if (_progenitorB != null && _progenitorB!.speciesId != unit.speciesId) {
          _progenitorB = null;
        }
      } else if (_progenitorA!.id == unit.id) {
        _progenitorA = null;
      } else if (_progenitorB == null) {
        if (unit.speciesId == _progenitorA!.speciesId) {
          _progenitorB = unit;
        } else {
          // Switch Progenitor A to new species
          _progenitorA = unit;
        }
      } else if (_progenitorB!.id == unit.id) {
        _progenitorB = null;
      } else {
        // Replace B if matching species, or reset A
        if (unit.speciesId == _progenitorA!.speciesId) {
          _progenitorB = unit;
        } else {
          _progenitorA = unit;
          _progenitorB = null;
        }
      }
      _updateDefaultGraft();
    });
  }

  void _updateDefaultGraft() {
    final candidateTraits = <String>[
      if (_progenitorA != null) ...[
        _progenitorA!.nativeTraitId,
        if (_progenitorA!.graftedTraitId != null) _progenitorA!.graftedTraitId!,
      ],
      if (_progenitorB != null) ...[
        _progenitorB!.nativeTraitId,
        if (_progenitorB!.graftedTraitId != null) _progenitorB!.graftedTraitId!,
      ],
    ];
    if (candidateTraits.isNotEmpty) {
      if (_selectedGraftTraitId == null || !candidateTraits.contains(_selectedGraftTraitId)) {
        _selectedGraftTraitId = candidateTraits.first;
      }
    } else {
      _selectedGraftTraitId = null;
    }
  }

  Future<void> _executeFusionRitual() async {
    if (!_canFuse) return;

    final ichorCost = _requiredIchorCost;
    final sigilCost = _requiredSigilsCost;
    final parentAId = _progenitorA!.id;
    final parentBId = _progenitorB!.id;

    setState(() => _isPerformingRitual = true);
    await _shakeController.forward(from: 0.0);

    final nextGen = (max(_progenitorA!.generation, _progenitorB!.generation) + 1).clamp(1, 4);
    final isHoundLineage = _progenitorA!.speciesId.contains('hound');
    final String childName = nextGen >= 4
        ? (isHoundLineage ? 'Pureblood Cerberus Sovereign' : '${_progenitorA!.name} Pureblood Sovereign')
        : (isHoundLineage
            ? 'Cerberus Progenitor G$nextGen'
            : '${_progenitorA!.name} Descendant G$nextGen');
    final String childSpeciesId = isHoundLineage
        ? 'cerberus_hound'
        : _progenitorA!.speciesId;

    final UnitEntity child = CrucibleService.fuseUnits(
      parentA: _progenitorA!,
      parentB: _progenitorB!,
      childSpeciesId: childSpeciesId,
      childName: childName,
      childArchetype: _progenitorA!.archetype,
      assignedSlot: _progenitorA!.slot,
      speciesBaseHp: 800,
      speciesBaseAtk: 150,
      speciesBaseDef: 100,
      speciesBaseSpd: 100,
      childNativeTraitId: _progenitorA!.nativeTraitId,
      selectedGraftTraitId: _selectedGraftTraitId!,
    );

    // Deduct currencies
    if (widget.onIchorChanged != null && ichorCost > 0) {
      widget.onIchorChanged!(widget.totalIchor - ichorCost);
    }
    if (widget.onSigilsChanged != null && sigilCost > 0) {
      widget.onSigilsChanged!(widget.bloodlineSigils - sigilCost);
    }

    if (widget.onFusionExecuted != null) {
      widget.onFusionExecuted!(child, [parentAId, parentBId]);
    } else {
      widget.onFusionComplete(child);
    }

    if (mounted) {
      setState(() {
        _isPerformingRitual = false;
        _progenitorA = null;
        _progenitorB = null;
        _selectedGraftTraitId = null;
      });

      _showFusionSuccessModal(child);
    }
  }

  void _showFusionSuccessModal(UnitEntity child) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: child.isPureblood ? const Color(0xFFFFD700) : const Color(0xFFB3261E),
              width: child.isPureblood ? 2.5 : 2,
            ),
          ),
          title: Text(
            child.isPureblood ? '👑 PUREBLOOD SOVEREIGN ASCENDED' : 'LINEAGE DESCENDANT AWAKENED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: child.isPureblood ? const Color(0xFFFFD700) : const Color(0xFFE5A93C),
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GothicCardFrameWidget(
                  unit: child,
                  width: 170,
                  height: 230,
                  showStats: false,
                ),
                const SizedBox(height: 12),
                if (child.isPureblood)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E0A0A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
                    ),
                    child: const Text(
                      '⚡ PUREBLOOD RESONANCE (+15% STATS & LV. 50 CAP)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  )
                else
                  Text(
                    'Generation ${child.generation} • Chimeric Lineage',
                    style: const TextStyle(
                      color: Color(0xFFE5A93C),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 10),
                _buildStatMetricRow('MAX HP', child.maxHp.toString()),
                _buildStatMetricRow('ATTACK', child.attack.toString()),
                _buildStatMetricRow('DEFENSE', child.defense.toString()),
                _buildStatMetricRow('SPEED', child.speed.toString()),
                _buildStatMetricRow('MAX LEVEL', 'Lv. ${child.maxLevel}'),
                _buildStatMetricRow('GRAFTED TRAIT', child.graftedTraitId?.replaceAll('_', ' ').toUpperCase() ?? 'None'),
              ],
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('CLAIM VESSEL', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111114),
        appBar: AppBar(
          backgroundColor: const Color(0xFF181820),
          title: const Text(
            'THE CRUCIBLE OF BLOOD',
            style: TextStyle(
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: LivingAtmosphereBackground(
          imageAsset: 'assets/images/crucible_ritual_chamber.jpg',
          enableBreathing: true,
          enableFlicker: true,
          flickerColor: const Color(0xFFFF3D00),
          flickerCenter: const Alignment(0.0, -0.2),
          particleColor: const Color(0xFFFF5252),
          particleCount: 26,
          vignetteOpacity: 0.78,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tri-Currency Status Bar
                _buildCurrencyStatusBar(),

                // Altar Slots
                _buildProgenitorSelectionAltar(),
                const SizedBox(height: 16),

                // Trait, Cost, & Projected Potency (if both slotted)
                if (_progenitorA != null && _progenitorB != null) ...[
                  _buildTraitGraftSelector(),
                  const SizedBox(height: 14),
                  _buildInheritancePreviewCard(),
                  const SizedBox(height: 14),
                  _buildResourceCostCard(),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _canFuse ? _executeFusionRitual : null,
                    icon: const Icon(Icons.fireplace, color: Colors.white),
                    label: Text(
                      _isPerformingRitual
                          ? 'TRANSMUTING SOULS...'
                          : (!_hasSufficientResources
                              ? 'INSUFFICIENT RESOURCES'
                              : (_requiredSigilsCost > 0
                                  ? '👑 CONSECRATE PUREBLOOD SOVEREIGN'
                                  : 'IGNITE CRUCIBLE OF BLOOD')),
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _requiredSigilsCost > 0
                          ? const Color(0xFFC67C00)
                          : const Color(0xFFB3261E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A2A38),
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Visible Roster Section
                _buildVisibleRosterSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TRI-CURRENCY & TRANSMUTATION COSTS
  // ===========================================================================

  Widget _buildCurrencyStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B2B36)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFFE5A93C), size: 16),
              const SizedBox(width: 6),
              const Text(
                'ICHOR: ',
                style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.totalIchor}',
                style: const TextStyle(color: Color(0xFFE5A93C), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Container(width: 1, height: 18, color: const Color(0xFF2B2B36)),
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 6),
              const Text(
                'BLOODLINE SIGILS: ',
                style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.bloodlineSigils}',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCostCard() {
    final nextGen = (max(_progenitorA!.generation, _progenitorB!.generation) + 1).clamp(1, 4);
    final isPureblood = nextGen >= 4;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPureblood
            ? const Color(0xFF261808)
            : const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !_hasSufficientResources
              ? const Color(0xFFE53935)
              : (isPureblood ? const Color(0xFFFFD700) : const Color(0xFFE5A93C)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPureblood ? Icons.auto_awesome : Icons.local_fire_department,
                color: isPureblood ? const Color(0xFFFFD700) : const Color(0xFFE5A93C),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isPureblood
                    ? 'PUREBLOOD CONSECRATION COST'
                    : 'TRANSMUTATION RITUAL COST (GEN $nextGen)',
                style: TextStyle(
                  color: isPureblood ? const Color(0xFFFFD700) : const Color(0xFFE5A93C),
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Ichor Cost
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasSufficientIchor
                      ? const Color(0xFFE5A93C).withValues(alpha: 0.15)
                      : const Color(0xFFB3261E).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _hasSufficientIchor
                        ? const Color(0xFFE5A93C)
                        : const Color(0xFFE53935),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: Color(0xFFE5A93C), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$_requiredIchorCost Ichor',
                      style: TextStyle(
                        color: _hasSufficientIchor ? Colors.white : const Color(0xFFEF9A9A),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (_requiredSigilsCost > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hasSufficientSigils
                        ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                        : const Color(0xFFB3261E).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _hasSufficientSigils
                          ? const Color(0xFFFFD700)
                          : const Color(0xFFE53935),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '$_requiredSigilsCost Bloodline Sigil',
                        style: TextStyle(
                          color: _hasSufficientSigils ? const Color(0xFFFFD700) : const Color(0xFFEF9A9A),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!_hasSufficientResources) ...[
            const SizedBox(height: 6),
            Text(
              !_hasSufficientIchor
                  ? '⚠ INSUFFICIENT ICHOR: Requires $_requiredIchorCost (have ${widget.totalIchor})'
                  : '⚠ INSUFFICIENT BLOODLINE SIGILS: Requires 1 (have ${widget.bloodlineSigils})',
              style: const TextStyle(color: Color(0xFFEF5350), fontSize: 9.5, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // PROGENITOR ALTAR (SLOT A & SLOT B)
  // ===========================================================================

  Widget _buildProgenitorSelectionAltar() {
    return Row(
      children: [
        Expanded(
          child: _buildProgenitorSlot(
            label: 'PROGENITOR ALPHA',
            unit: _progenitorA,
            onClear: () => setState(() {
              _progenitorA = null;
              _updateDefaultGraft();
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _canFuse ? const Color(0xFFFF5252) : const Color(0xFF4A4A58),
                width: 1.5,
              ),
              boxShadow: _canFuse
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/crucible_aperture.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.compare_arrows, color: Color(0xFFB3261E), size: 26),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildProgenitorSlot(
            label: 'PROGENITOR BETA',
            unit: _progenitorB,
            onClear: () => setState(() {
              _progenitorB = null;
              _updateDefaultGraft();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProgenitorSlot({
    required String label,
    required UnitEntity? unit,
    required VoidCallback onClear,
  }) {
    return Container(
      height: 172,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: unit != null ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
          width: 1.5,
        ),
      ),
      child: unit == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFF8E8EA0), size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8E8EA0),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Select below',
                    style: TextStyle(color: Colors.white30, fontSize: 9)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GEN ${unit.generation}',
                        style: const TextStyle(
                            color: Color(0xFFE5A93C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClear,
                    ),
                  ],
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                      bottom: Radius.circular(4),
                    ),
                    border: Border.all(
                      color: unit.isPureblood ? const Color(0xFFFF5252) : const Color(0xFFE5A93C),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (unit.isPureblood)
                        BoxShadow(
                          color: const Color(0xFFFF1744).withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                      bottom: Radius.circular(3),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            unit.effectiveAvatarAsset,
                            fit: unit.isFigurineCutout ? BoxFit.contain : BoxFit.cover,
                            alignment: unit.isFigurineCutout ? Alignment.bottomCenter : Alignment.topCenter,
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.7, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  unit.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Text(
                  'Lv. ${unit.level}/${unit.maxLevel}',
                  style: TextStyle(
                    color: unit.level >= unit.maxLevel
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF8E8EA0),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit.level < unit.maxLevel && widget.onUnitLeveled != null)
                  InkWell(
                    onTap: () => _handleProgenitorInfuse(unit),
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E).withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE57373), width: 0.8),
                      ),
                      child: Text(
                        'INFUSE (Lv.${unit.level + 1})',
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _handleProgenitorInfuse(UnitEntity unit) {
    final cost = unit.xpNeededForNextLevel;
    if (widget.totalIchor < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient Ichor! Requires $cost Ichor to infuse ${unit.name}.'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    final leveled = unit.levelUp(levels: 1);
    setState(() {
      if (_progenitorA?.id == unit.id) {
        _progenitorA = leveled;
      }
      if (_progenitorB?.id == unit.id) {
        _progenitorB = leveled;
      }
    });

    widget.onUnitLeveled?.call(leveled, cost);
  }

  // ===========================================================================
  // VISIBLE ROSTER & BRIGADE SECTION
  // ===========================================================================

  Widget _buildVisibleRosterSection() {
    final filteredList = widget.availableInventory.where((u) {
      if (_selectedGenFilter != null && u.generation != _selectedGenFilter) {
        return false;
      }
      if (_selectedSpeciesFilter == 'HOUND') {
        return u.speciesId.contains('hound') || u.speciesId.contains('cerberus');
      } else if (_selectedSpeciesFilter == 'GHOUL') {
        return u.speciesId.contains('ghoul') || u.speciesId.contains('lich') || u.speciesId.contains('crypt');
      } else if (_selectedSpeciesFilter == 'VANGUARD') {
        return u.speciesId.contains('vanguard') || u.archetype == Archetype.juggernaut;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'YOUR BRIGADE & THRALL ROSTER',
              style: TextStyle(
                color: Color(0xFFE5A93C),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.flash_on, size: 14, color: Color(0xFFE5A93C)),
                  label: const Text('AUTO-PAIR', style: TextStyle(color: Color(0xFFE5A93C), fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: _autoSlotFirstCompatiblePair,
                ),
                const SizedBox(width: 8),
                Text(
                  '${filteredList.length} / ${widget.availableInventory.length} VESSELS',
                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap any vessel below to slot it into the Crucible Altar. Matching species can be fused.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 8),

        // Filter chips bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', _selectedSpeciesFilter == 'ALL', () {
                setState(() => _selectedSpeciesFilter = 'ALL');
              }),
              const SizedBox(width: 6),
              _buildFilterChip('HOUNDS', _selectedSpeciesFilter == 'HOUND', () {
                setState(() => _selectedSpeciesFilter = 'HOUND');
              }),
              const SizedBox(width: 6),
              _buildFilterChip('GHOULS', _selectedSpeciesFilter == 'GHOUL', () {
                setState(() => _selectedSpeciesFilter = 'GHOUL');
              }),
              const SizedBox(width: 6),
              _buildFilterChip('VANGUARDS', _selectedSpeciesFilter == 'VANGUARD', () {
                setState(() => _selectedSpeciesFilter = 'VANGUARD');
              }),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: const Color(0xFF2B2B36)),
              const SizedBox(width: 10),
              _buildFilterChip('GEN I', _selectedGenFilter == 1, () {
                setState(() => _selectedGenFilter = _selectedGenFilter == 1 ? null : 1);
              }),
              const SizedBox(width: 6),
              _buildFilterChip('GEN II', _selectedGenFilter == 2, () {
                setState(() => _selectedGenFilter = _selectedGenFilter == 2 ? null : 2);
              }),
              const SizedBox(width: 6),
              _buildFilterChip('GEN III', _selectedGenFilter == 3, () {
                setState(() => _selectedGenFilter = _selectedGenFilter == 3 ? null : 3);
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final unit = filteredList[index];
            final bool isSlottedA = _progenitorA?.id == unit.id;
            final bool isSlottedB = _progenitorB?.id == unit.id;
            final bool isSlotted = isSlottedA || isSlottedB;
            final bool isMaxLevel = unit.level >= unit.maxLevel;
            final bool isCompatibleWithA = _progenitorA != null &&
                _progenitorA!.id != unit.id &&
                _progenitorA!.speciesId == unit.speciesId;

            return GestureDetector(
              onTap: () => _selectUnit(unit),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSlotted ? const Color(0xFF261C1C) : const Color(0xFF181820),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSlotted
                        ? const Color(0xFFB3261E)
                        : (isCompatibleWithA
                            ? const Color(0xFFE5A93C)
                            : const Color(0xFF2B2B36)),
                    width: isSlotted || isCompatibleWithA ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(3),
                            ),
                            border: Border.all(
                              color: isSlotted
                                  ? const Color(0xFFB3261E)
                                  : (isCompatibleWithA
                                      ? const Color(0xFFE5A93C)
                                      : const Color(0xFF2B2B36)),
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7),
                              bottom: Radius.circular(2),
                            ),
                            child: Image.asset(
                              unit.effectiveAvatarAsset,
                              fit: unit.isFigurineCutout
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                              alignment: unit.isFigurineCutout
                                  ? Alignment.bottomCenter
                                  : Alignment.topCenter,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'G${unit.generation}',
                            style: const TextStyle(
                              color: Color(0xFFE5A93C),
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isCompatibleWithA)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('COMPATIBLE MATE',
                                      style: TextStyle(
                                          color: Color(0xFFE5A93C),
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Lv. ${unit.level}/${unit.maxLevel} • ATK ${unit.attack} • DEF ${unit.defense} • HP ${unit.maxHp}',
                            style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10),
                          ),
                          Text(
                            'Native: ${unit.nativeTraitId.replaceAll('_', ' ').toUpperCase()}',
                            style: const TextStyle(color: Color(0xFF616161), fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isSlotted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB3261E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isSlottedA ? 'SLOT A' : 'SLOT B',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              side: const BorderSide(color: Color(0xFF2B2B36)),
                            ),
                            onPressed: () => _selectUnit(unit),
                            child: const Text('SLOT', style: TextStyle(fontSize: 10)),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          isMaxLevel ? '10% YIELD' : '5% YIELD',
                          style: TextStyle(
                            color: isMaxLevel ? const Color(0xFF4CAF50) : const Color(0xFF8E8EA0),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // TRAIT GRAFT SELECTOR
  // ===========================================================================

  Widget _buildTraitGraftSelector() {
    final traits = <String>{
      if (_progenitorA != null) ...[
        _progenitorA!.nativeTraitId,
        if (_progenitorA!.graftedTraitId != null) _progenitorA!.graftedTraitId!,
      ],
      if (_progenitorB != null) ...[
        _progenitorB!.nativeTraitId,
        if (_progenitorB!.graftedTraitId != null) _progenitorB!.graftedTraitId!,
      ],
    }.toList();

    final selectedTrait = _selectedGraftTraitId != null ? TraitEntity.getTrait(_selectedGraftTraitId!) : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2B2B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT TRAIT TO GRAFT TO DESCENDANT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: traits.map((trait) {
              final traitEntity = TraitEntity.getTrait(trait);
              final isSelected = _selectedGraftTraitId == trait;
              return ChoiceChip(
                avatar: Icon(traitEntity.icon, size: 14, color: isSelected ? Colors.white : traitEntity.themeColor),
                label: Text(traitEntity.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                selected: isSelected,
                selectedColor: const Color(0xFFB3261E),
                backgroundColor: const Color(0xFF2B2B36),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedGraftTraitId = trait);
                },
              );
            }).toList(),
          ),
          if (selectedTrait != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedTrait.themeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selectedTrait.themeColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(selectedTrait.icon, size: 16, color: selectedTrait.themeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedTrait.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // INHERITANCE PREVIEW CARD
  // ===========================================================================

  Widget _buildInheritancePreviewCard() {
    final double ratioA = (_progenitorA!.level >= _progenitorA!.maxLevel) ? 0.10 : 0.05;
    final double ratioB = (_progenitorB!.level >= _progenitorB!.maxLevel) ? 0.10 : 0.05;

    final int bonusHp = ((_progenitorA!.maxHp * ratioA) + (_progenitorB!.maxHp * ratioB)).round();
    final int bonusAtk = ((_progenitorA!.attack * ratioA) + (_progenitorB!.attack * ratioB)).round();
    final int bonusDef = ((_progenitorA!.defense * ratioA) + (_progenitorB!.defense * ratioB)).round();
    final int bonusSpd = ((_progenitorA!.speed * ratioA) + (_progenitorB!.speed * ratioB)).round();

    final int nextGen = (_progenitorA!.generation >= _progenitorB!.generation
            ? _progenitorA!.generation
            : _progenitorB!.generation) +
        1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5A93C), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROJECTED BLOODLINE POTENCY',
                style: TextStyle(
                  color: Color(0xFFE5A93C),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'GEN $nextGen',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatMetricRow('MAX HP (Base 800)', '800 + $bonusHp = ${800 + bonusHp}'),
          _buildStatMetricRow('ATTACK (Base 150)', '150 + $bonusAtk = ${150 + bonusAtk}'),
          _buildStatMetricRow('DEFENSE (Base 100)', '100 + $bonusDef = ${100 + bonusDef}'),
          _buildStatMetricRow('SPEED (Base 100)', '100 + $bonusSpd = ${100 + bonusSpd}'),
          const Divider(color: Color(0xFF2B2B36), height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inheritance Potency: A(${(ratioA * 100).toInt()}%) + B(${(ratioB * 100).toInt()}%)',
                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9)),
              Text(
                ratioA == 0.10 && ratioB == 0.10 ? 'PUREBLOOD RITE' : 'IMPURE TRANSFER',
                style: TextStyle(
                  color: ratioA == 0.10 && ratioB == 0.10 ? const Color(0xFF4CAF50) : const Color(0xFFE5A93C),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB3261E).withValues(alpha: 0.3) : const Color(0xFF181820),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFB3261E) : const Color(0xFF2B2B36),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFE5A93C) : const Color(0xFF8E8EA0),
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
