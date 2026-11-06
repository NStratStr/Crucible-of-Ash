import 'package:flutter/foundation.dart';
import '../../shared/models/unit_entity.dart';
import '../../shared/models/trait_entity.dart';

/// Service managing Inscribed Soul-Chisels, plinth ring sockets,
/// trait refinement tiers, and clean extraction mechanics (GDD Sec 6.1).
class TraitChiselingService extends ChangeNotifier {
  final Map<String, int> _ownedChisels;
  final Map<String, int> _traitTiers;

  TraitChiselingService({
    Map<String, int>? initialChisels,
    Map<String, int>? initialTiers,
  })  : _ownedChisels = initialChisels ?? {
          'vampiric_sinew': 2,
          'iron_thorns': 2,
          'solar_resonance': 1,
          'brimstone_core': 1,
          'porous_edge': 1,
          'colossus_sinew': 1,
        },
        _traitTiers = initialTiers ?? {
          'vampiric_sinew': 1,
          'iron_thorns': 1,
          'solar_resonance': 1,
          'brimstone_core': 1,
          'porous_edge': 1,
          'colossus_sinew': 1,
          'phase_fractured_shell': 1,
        };

  Map<String, int> get ownedChisels => Map.unmodifiable(_ownedChisels);
  Map<String, int> get traitTiers => Map.unmodifiable(_traitTiers);

  int getChiselCount(String traitId) => _ownedChisels[traitId] ?? 0;
  int getTraitTier(String traitId) => _traitTiers[traitId] ?? 1;

  /// Check if a unit has an open plinth socket and does not already possess this trait
  bool canSocket(UnitEntity unit, String traitId) {
    if (unit.availablePlinthSockets <= 0) return false;
    if (getChiselCount(traitId) <= 0) return false;
    if (unit.allActiveTraitIds.contains(traitId)) return false;
    return true;
  }

  /// Socket an Inscribed Soul-Chisel onto a miniature's plinth ring (Free)
  UnitEntity socketTrait({required UnitEntity unit, required String traitId}) {
    if (!canSocket(unit, traitId)) return unit;

    _ownedChisels[traitId] = (_ownedChisels[traitId] ?? 1) - 1;
    if (_ownedChisels[traitId]! <= 0) {
      _ownedChisels.remove(traitId);
    }

    final updatedChiseled = List<String>.from(unit.chiseledTraitIds)..add(traitId);
    notifyListeners();
    return unit.copyWith(chiseledTraitIds: updatedChiseled);
  }

  /// Clean Extraction: Removes socketed trait and preserves it back into inventory.
  /// Costs alchemical fee or Unbound Ash (GDD Sec 6.1)
  UnitEntity extractTrait({
    required UnitEntity unit,
    required int socketIndex,
  }) {
    if (socketIndex < 0 || socketIndex >= unit.chiseledTraitIds.length) return unit;

    final extractedTraitId = unit.chiseledTraitIds[socketIndex];
    _ownedChisels[extractedTraitId] = (_ownedChisels[extractedTraitId] ?? 0) + 1;

    final updatedChiseled = List<String>.from(unit.chiseledTraitIds)..removeAt(socketIndex);
    notifyListeners();
    return unit.copyWith(chiseledTraitIds: updatedChiseled);
  }

  /// Free overwrite: Replaces socketed trait with a new one, destroying the old one
  UnitEntity overwriteTrait({
    required UnitEntity unit,
    required int socketIndex,
    required String newTraitId,
  }) {
    if (socketIndex < 0 || socketIndex >= unit.chiseledTraitIds.length) return unit;
    if (getChiselCount(newTraitId) <= 0) return unit;

    // Consume new chisel
    _ownedChisels[newTraitId] = (_ownedChisels[newTraitId] ?? 1) - 1;
    if (_ownedChisels[newTraitId]! <= 0) {
      _ownedChisels.remove(newTraitId);
    }

    final updatedChiseled = List<String>.from(unit.chiseledTraitIds);
    updatedChiseled[socketIndex] = newTraitId;

    notifyListeners();
    return unit.copyWith(chiseledTraitIds: updatedChiseled);
  }

  /// Craft a brand-new Inscribed Soul-Chisel using Raw Ash and Ichor
  bool craftChisel({
    required String traitId,
    required int availableAsh,
    required int availableIchor,
    int ashCost = 120,
    int ichorCost = 40,
  }) {
    if (availableAsh < ashCost || availableIchor < ichorCost) return false;

    _ownedChisels[traitId] = (_ownedChisels[traitId] ?? 0) + 1;
    notifyListeners();
    return true;
  }

  /// Upgrade a trait's permanent potency from Tier 1 -> Tier 2 -> Tier 3
  bool upgradeTraitTier({
    required String traitId,
    required int availableAsh,
    required int availableOre,
  }) {
    final currentTier = getTraitTier(traitId);
    if (currentTier >= 3) return false;

    final ashCost = currentTier == 1 ? 250 : 500;
    final oreCost = currentTier == 1 ? 50 : 120;

    if (availableAsh < ashCost || availableOre < oreCost) return false;

    _traitTiers[traitId] = currentTier + 1;
    notifyListeners();
    return true;
  }

  /// Get list of all available soul-chisels in player inventory
  List<TraitEntity> getAvailableChisels() {
    return _ownedChisels.keys
        .where((id) => (_ownedChisels[id] ?? 0) > 0)
        .map((id) => TraitEntity.getTrait(id))
        .toList();
  }
}
