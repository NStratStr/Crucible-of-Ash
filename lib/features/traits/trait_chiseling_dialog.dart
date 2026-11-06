import 'package:flutter/material.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/models/trait_entity.dart';
import 'trait_chiseling_service.dart';

/// Modal dialog allowing players to chisel Inscribed Soul-Chisels into a miniature's
/// plinth ring sockets, perform clean extraction, or upgrade trait tiers (GDD Sec 6.1).
class TraitChiselingDialog extends StatefulWidget {
  final UnitEntity unit;
  final TraitChiselingService chiselingService;
  final int totalAsh;
  final int totalIchor;
  final ValueChanged<UnitEntity> onUnitUpdated;
  final void Function(int ashCost, int ichorCost)? onCostDeducted;

  const TraitChiselingDialog({
    super.key,
    required this.unit,
    required this.chiselingService,
    required this.totalAsh,
    required this.totalIchor,
    required this.onUnitUpdated,
    this.onCostDeducted,
  });

  static Future<UnitEntity?> show(
    BuildContext context, {
    required UnitEntity unit,
    required TraitChiselingService chiselingService,
    required int totalAsh,
    required int totalIchor,
    required ValueChanged<UnitEntity> onUnitUpdated,
    void Function(int ashCost, int ichorCost)? onCostDeducted,
  }) {
    return showDialog<UnitEntity>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TraitChiselingDialog(
        unit: unit,
        chiselingService: chiselingService,
        totalAsh: totalAsh,
        totalIchor: totalIchor,
        onUnitUpdated: onUnitUpdated,
        onCostDeducted: onCostDeducted,
      ),
    );
  }

  @override
  State<TraitChiselingDialog> createState() => _TraitChiselingDialogState();
}

class _TraitChiselingDialogState extends State<TraitChiselingDialog> {
  late UnitEntity _currentUnit;
  TraitEntity? _selectedChisel;

  TraitChiselingService get _service => widget.chiselingService;

  @override
  void initState() {
    super.initState();
    _currentUnit = widget.unit;
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _handleSocketSelectedChisel() {
    if (_selectedChisel == null) return;
    if (!_service.canSocket(_currentUnit, _selectedChisel!.id)) return;

    final updated = _service.socketTrait(
      unit: _currentUnit,
      traitId: _selectedChisel!.id,
    );

    setState(() {
      _currentUnit = updated;
      _selectedChisel = null;
    });

    widget.onUnitUpdated(updated);
    _showSnackBar('Chiseled ${_selectedChisel?.name ?? "trait"} into plinth ring!');
  }

  void _handleExtractTrait(int index) {
    const ashCost = 50;
    if (widget.totalAsh < ashCost) {
      _showSnackBar('Insufficient Raw Ash ($ashCost required for Clean Extraction solvent).');
      return;
    }

    widget.onCostDeducted?.call(ashCost, 0);

    final updated = _service.extractTrait(
      unit: _currentUnit,
      socketIndex: index,
    );

    setState(() {
      _currentUnit = updated;
    });

    widget.onUnitUpdated(updated);
    _showSnackBar('Cleanly extracted trait back into Soul-Chisel inventory!');
  }

  void _handleShredTrait(int index) {
    final updated = _currentUnit.copyWith(
      chiseledTraitIds: List<String>.from(_currentUnit.chiseledTraitIds)..removeAt(index),
    );

    setState(() {
      _currentUnit = updated;
    });

    widget.onUnitUpdated(updated);
    _showSnackBar('Cracked and removed socketed rune.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A2634),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableChisels = _service.getAvailableChisels();
    final maxSockets = _currentUnit.maxPlinthSockets;
    final chiseled = _currentUnit.chiseledTraitIds;

    return Dialog(
      backgroundColor: const Color(0xFF0C1017),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Row(
              children: [
                const Icon(Icons.foundation, color: Color(0xFF00E5FF), size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLINTH TRAIT CHISELING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${_currentUnit.name} (Gen ${_currentUnit.generation})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(_currentUnit),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),

            // Plinth Sockets Visual Representation
            _buildPlinthSocketRing(maxSockets, chiseled),

            const SizedBox(height: 16),
            const Text(
              'INSCRIBED SOUL-CHISELS IN VAULT:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF90A4AE)),
            ),
            const SizedBox(height: 8),

            // Available Chisels List
            Expanded(
              child: availableChisels.isEmpty
                  ? Center(
                      child: Text(
                        'No Soul-Chisels in vault. Forge or extract them from campaign bosses!',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: availableChisels.length,
                      itemBuilder: (ctx, idx) {
                        final chisel = availableChisels[idx];
                        final count = _service.getChiselCount(chisel.id);
                        final tier = _service.getTraitTier(chisel.id);
                        final isSelected = _selectedChisel?.id == chisel.id;
                        final alreadyHas = _currentUnit.allActiveTraitIds.contains(chisel.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF172636)
                                : const Color(0xFF101722),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00E5FF)
                                  : chisel.themeColor.withValues(alpha: 0.4),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: chisel.themeColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(chisel.icon, color: chisel.themeColor, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  chisel.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: chisel.themeColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'TIER $tier',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: chisel.themeColor),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'x$count',
                                  style: const TextStyle(color: Color(0xFF80D8FF), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              chisel.description,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
                            ),
                            trailing: alreadyHas
                                ? const Text(
                                    'EQUIPPED',
                                    style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold),
                                  )
                                : isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 20)
                                    : null,
                            onTap: alreadyHas
                                ? null
                                : () {
                                    setState(() {
                                      _selectedChisel = isSelected ? null : chisel;
                                    });
                                  },
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),
            // Bottom Action Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.carpenter, size: 18),
              label: Text(
                _selectedChisel != null
                    ? 'CHISEL ${_selectedChisel!.name.toUpperCase()} INTO PLINTH'
                    : 'SELECT AN INSCRIBED SOUL-CHISEL',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: (_selectedChisel != null && _service.canSocket(_currentUnit, _selectedChisel!.id))
                  ? _handleSocketSelectedChisel
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlinthSocketRing(int maxSockets, List<String> chiseled) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MINIATURE PLINTH RING SOCKETS:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
              ),
              Text(
                '${chiseled.length} / $maxSockets INSCRIBED',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF80D8FF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (socketIdx) {
              final isUnlocked = socketIdx < maxSockets;
              final isOccupied = socketIdx < chiseled.length;
              final traitId = isOccupied ? chiseled[socketIdx] : null;
              final trait = traitId != null ? TraitEntity.getTrait(traitId) : null;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? const Color(0xFF14202C)
                        : isUnlocked
                            ? const Color(0xFF0E1620)
                            : const Color(0xFF080B10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOccupied
                          ? (trait?.themeColor ?? const Color(0xFF00E5FF))
                          : isUnlocked
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                              : Colors.white12,
                      width: isOccupied ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isOccupied
                            ? trait?.icon ?? Icons.foundation
                            : isUnlocked
                                ? Icons.add_circle_outline
                                : Icons.lock,
                        size: 20,
                        color: isOccupied
                            ? (trait?.themeColor ?? const Color(0xFF00E5FF))
                            : isUnlocked
                                ? const Color(0xFF00E5FF)
                                : Colors.white24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOccupied
                            ? trait?.name ?? 'Unknown'
                            : isUnlocked
                                ? 'EMPTY SOCKET'
                                : socketIdx == 0
                                    ? 'GEN III'
                                    : socketIdx == 1
                                        ? 'GEN IV'
                                        : 'GEN VI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOccupied
                              ? Colors.white
                              : isUnlocked
                                  ? const Color(0xFF80D8FF)
                                  : Colors.white24,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOccupied) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => _handleExtractTrait(socketIdx),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.outbox, size: 14, color: Color(0xFF00E5FF)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _handleShredTrait(socketIdx),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.delete_outline, size: 14, color: Color(0xFFFF5252)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
