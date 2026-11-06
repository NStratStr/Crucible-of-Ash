import 'package:flutter/foundation.dart';
import 'plinth_models.dart';

/// Service managing carved battle plinths, socketed Titan Boss Cores, and shard economy
class PlinthService extends ChangeNotifier {
  int _petrifiedPlinths;
  String _activeMasterPlinthId;
  final Map<String, int> _plinthTiers;
  final Map<String, String?> _socketedCores;
  final Set<String> _unlockedCores;

  PlinthService({
    int petrifiedPlinths = 8,
    String activeMasterPlinthId = 'obsidian_bulwark',
    Map<String, int>? plinthTiers,
    Map<String, String?>? socketedCores,
    Set<String>? unlockedCores,
  })  : _petrifiedPlinths = petrifiedPlinths,
        _activeMasterPlinthId = activeMasterPlinthId,
        _plinthTiers = plinthTiers ?? {
          'obsidian_bulwark': 1,
          'cinder_spire': 1,
          'strigoi_runestone': 1,
          'titans_foundation': 1,
        },
        _socketedCores = socketedCores ?? {
          'obsidian_bulwark': 'gorgoroth_core',
          'cinder_spire': null,
          'strigoi_runestone': null,
          'titans_foundation': null,
        },
        _unlockedCores = unlockedCores ?? {
          'gorgoroth_core',
          'malakor_core',
          'morvath_core',
        };

  int get petrifiedPlinths => _petrifiedPlinths;
  String get activeMasterPlinthId => _activeMasterPlinthId;
  Map<String, int> get plinthTiers => Map.unmodifiable(_plinthTiers);
  Map<String, String?> get socketedCores => Map.unmodifiable(_socketedCores);
  Set<String> get unlockedCores => Set.unmodifiable(_unlockedCores);

  PlinthDefinition get activeMasterPlinth {
    return PlinthDefinition.allPlinths.firstWhere(
      (p) => p.id == _activeMasterPlinthId,
      orElse: () => PlinthDefinition.allPlinths.first,
    );
  }

  TitanBossCore? get activeSocketedCore {
    final coreId = _socketedCores[_activeMasterPlinthId];
    if (coreId == null) return null;
    return TitanBossCore.allCores.where((c) => c.id == coreId).firstOrNull;
  }

  int getTier(String plinthId) => _plinthTiers[plinthId] ?? 1;

  String? getSocketedCoreId(String plinthId) => _socketedCores[plinthId];

  TitanBossCore? getSocketedCore(String plinthId) {
    final coreId = _socketedCores[plinthId];
    if (coreId == null) return null;
    return TitanBossCore.allCores.where((c) => c.id == coreId).firstOrNull;
  }

  int getUpgradeShardCost(String plinthId) {
    final tier = getTier(plinthId);
    if (tier >= 3) return 0;
    return tier == 1 ? 4 : 8;
  }

  int getUpgradeIchorCost(String plinthId) {
    final tier = getTier(plinthId);
    if (tier >= 3) return 0;
    return tier == 1 ? 150 : 350;
  }

  bool canUpgrade(String plinthId, int availableIchor) {
    final tier = getTier(plinthId);
    if (tier >= 3) return false;
    final shardCost = getUpgradeShardCost(plinthId);
    final ichorCost = getUpgradeIchorCost(plinthId);
    return _petrifiedPlinths >= shardCost && availableIchor >= ichorCost;
  }

  bool upgradePlinth(String plinthId, {required int availableIchor, required void Function(int ichorCost) onDeductIchor}) {
    if (!canUpgrade(plinthId, availableIchor)) return false;
    final shardCost = getUpgradeShardCost(plinthId);
    final ichorCost = getUpgradeIchorCost(plinthId);

    _petrifiedPlinths -= shardCost;
    onDeductIchor(ichorCost);
    _plinthTiers[plinthId] = (_plinthTiers[plinthId] ?? 1) + 1;
    notifyListeners();
    return true;
  }

  void setActiveMasterPlinth(String plinthId) {
    if (_activeMasterPlinthId != plinthId) {
      _activeMasterPlinthId = plinthId;
      notifyListeners();
    }
  }

  void socketCore(String plinthId, String? coreId) {
    _socketedCores[plinthId] = coreId;
    notifyListeners();
  }

  void unlockCore(String coreId) {
    if (!_unlockedCores.contains(coreId)) {
      _unlockedCores.add(coreId);
      notifyListeners();
    }
  }

  void addPlinthShards(int count) {
    _petrifiedPlinths += count;
    notifyListeners();
  }

  void addShards(int count) => addPlinthShards(count);
}
