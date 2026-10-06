import 'package:flutter/material.dart';
import '../../core/combat_math.dart';
import '../../shared/models/unit_entity.dart';
import 'crucible_service.dart';

class CrucibleScreen extends StatefulWidget {
  final List<UnitEntity> availableInventory;
  final ValueChanged<UnitEntity> onFusionComplete;

  const CrucibleScreen({
    super.key,
    required this.availableInventory,
    required this.onFusionComplete,
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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  bool get _canFuse =>
      _progenitorA != null &&
      _progenitorB != null &&
      _progenitorA!.speciesId == _progenitorB!.speciesId &&
      _selectedGraftTraitId != null &&
      !_isPerformingRitual;

  void _openUnitSelectionModal({required bool isSlotA}) {
    final available = widget.availableInventory.where((u) {
      if (isSlotA) {
        return u.id != _progenitorB?.id;
      } else {
        return u.id != _progenitorA?.id &&
            (_progenitorA == null || u.speciesId == _progenitorA!.speciesId);
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF2B2B36), width: 1.5),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSlotA ? 'SELECT FIRST PROGENITOR' : 'SELECT COMPATIBLE MATE',
                style: const TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: available.isEmpty
                    ? const Center(
                        child: Text(
                          'No compatible lineage vessels found in inventory.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        itemCount: available.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final unit = available[index];
                          final bool isMaxLevel = unit.level >= unit.maxLevel;

                          return ListTile(
                            tileColor: const Color(0xFF1C1C24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFF2B2B36)),
                            ),
                            leading: CircleAvatar(
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
                            title: Text(
                              unit.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Lv. ${unit.level}/${unit.maxLevel} • ATK: ${unit.attack} • HP: ${unit.maxHp}',
                              style: const TextStyle(
                                color: Color(0xFF8E8EA0),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isMaxLevel
                                ? const Chip(
                                    label: Text('MAX POTENCY (10%)',
                                        style: TextStyle(fontSize: 10)),
                                    backgroundColor: Color(0xFF1B5E20),
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                : const Chip(
                                    label: Text('UNFINISHED (5%)',
                                        style: TextStyle(fontSize: 10)),
                                    backgroundColor: Color(0xFF424242),
                                    labelStyle: TextStyle(color: Colors.white54),
                                  ),
                            onTap: () {
                              setState(() {
                                if (isSlotA) {
                                  _progenitorA = unit;
                                  if (_progenitorB != null &&
                                      _progenitorB!.speciesId != unit.speciesId) {
                                    _progenitorB = null;
                                  }
                                } else {
                                  _progenitorB = unit;
                                }
                                _updateDefaultGraft();
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateDefaultGraft() {
    if (_progenitorA != null) {
      _selectedGraftTraitId = _progenitorA!.nativeTraitId;
    } else if (_progenitorB != null) {
      _selectedGraftTraitId = _progenitorB!.nativeTraitId;
    } else {
      _selectedGraftTraitId = null;
    }
  }

  Future<void> _executeFusionRitual() async {
    if (!_canFuse) return;

    setState(() => _isPerformingRitual = true);
    await _shakeController.forward(from: 0.0);

    // Compute final descendant using CrucibleService
    final UnitEntity child = CrucibleService.fuseUnits(
      parentA: _progenitorA!,
      parentB: _progenitorB!,
      childSpeciesId: _progenitorA!.speciesId,
      childName: '${_progenitorA!.name} Descendant',
      childArchetype: _progenitorA!.archetype,
      assignedSlot: _progenitorA!.slot,
      speciesBaseHp: 800,
      speciesBaseAtk: 150,
      speciesBaseDef: 100,
      speciesBaseSpd: 100,
      childNativeTraitId: _progenitorA!.nativeTraitId,
      selectedGraftTraitId: _selectedGraftTraitId!,
    );

    widget.onFusionComplete(child);

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
            side: const BorderSide(color: Color(0xFFB3261E), width: 2),
          ),
          title: const Text(
            'LINEAGE DESCENDANT AWAKENED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE5A93C),
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Generation ${child.generation} • Pureblood Ancestry',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildStatMetricRow('MAX HP', child.maxHp.toString()),
              _buildStatMetricRow('ATTACK', child.attack.toString()),
              _buildStatMetricRow('DEFENSE', child.defense.toString()),
              _buildStatMetricRow('GRAFTED TRAIT', child.graftedTraitId ?? 'None'),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
              fontSize: 15,
            ),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgenitorSelectionAltar(),
              const SizedBox(height: 20),
              if (_progenitorA != null && _progenitorB != null) ...[
                _buildTraitGraftSelector(),
                const SizedBox(height: 20),
                _buildInheritancePreviewCard(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _canFuse ? _executeFusionRitual : null,
                  icon: const Icon(Icons.fireplace, color: Colors.white),
                  label: Text(
                    _isPerformingRitual
                        ? 'TRANSMUTING SOULS...'
                        : 'IGNITE CRUCIBLE OF BLOOD',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF2A2A38),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181820),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2B2B36)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.auto_fix_high, color: Color(0xFF8E8EA0), size: 36),
                      SizedBox(height: 12),
                      Text(
                        'Select two duplicate lineage vessels above to awaken the crucible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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
            onTap: () => _openUnitSelectionModal(isSlotA: true),
            onClear: () => setState(() {
              _progenitorA = null;
              _updateDefaultGraft();
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(Icons.add, color: Color(0xFFB3261E), size: 28),
        ),
        Expanded(
          child: _buildProgenitorSlot(
            label: 'PROGENITOR BETA',
            unit: _progenitorB,
            onTap: () => _openUnitSelectionModal(isSlotA: false),
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
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(10),
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
                  const Icon(Icons.add_circle_outline, color: Color(0xFF8E8EA0), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8E8EA0),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Tap to bind',
                      style: TextStyle(color: Colors.white30, fontSize: 10)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('G${unit.generation}',
                          style: const TextStyle(
                              color: Color(0xFFE5A93C),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onClear,
                      ),
                    ],
                  ),
                  const Icon(Icons.shield, color: Colors.white70, size: 28),
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
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ATK ${unit.attack} • HP ${unit.maxHp}',
                    style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 9),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // TRAIT GRAFT SELECTOR
  // ===========================================================================

  Widget _buildTraitGraftSelector() {
    final traits = <String>{
      if (_progenitorA != null) _progenitorA!.nativeTraitId,
      if (_progenitorB != null) _progenitorB!.nativeTraitId,
    }.toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B2B36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT TRAIT TO GRAFT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: traits.map((trait) {
              final isSelected = _selectedGraftTraitId == trait;
              return ChoiceChip(
                label: Text(trait.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(8),
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
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'GEN $nextGen',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatMetricRow('MAX HP (Base 800)', '800 + $bonusHp = ${800 + bonusHp}'),
          _buildStatMetricRow('ATTACK (Base 150)', '150 + $bonusAtk = ${150 + bonusAtk}'),
          _buildStatMetricRow('DEFENSE (Base 100)', '100 + $bonusDef = ${100 + bonusDef}'),
          _buildStatMetricRow('SPEED (Base 100)', '100 + $bonusSpd = ${100 + bonusSpd}'),
          const Divider(color: Color(0xFF2B2B36), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inheritance Potency: A(${(ratioA * 100).toInt()}%) + B(${(ratioB * 100).toInt()}%)',
                  style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 10)),
              Text(
                ratioA == 0.10 && ratioB == 0.10 ? 'PUREBLOOD RITE' : 'IMPURE TRANSFER',
                style: TextStyle(
                  color: ratioA == 0.10 && ratioB == 0.10 ? const Color(0xFF4CAF50) : const Color(0xFFE5A93C),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
