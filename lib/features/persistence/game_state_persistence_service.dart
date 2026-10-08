import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/combat_math.dart';
import '../../shared/models/relic_entity.dart';
import '../../shared/models/unit_entity.dart';
import '../campaign/endgame_gauntlet_dialog.dart';
import '../generals/general_command_service.dart';

class GameSaveData {
  final int totalIchor;
  final int cursedOre;
  final int bloodlineSigils;
  final GeneralType activeGeneralType;
  final Map<GeneralType, int> phylacteryRanks;
  final int currentChapter;
  final int maxUnlockedChapter;
  final List<UnitEntity> allies;
  final List<UnitEntity> reserveInventory;
  final List<RelicEntity> relics;
  final Set<EndgameTrialType> clearedGauntletTrials;
  final int lastSavedTimestamp;

  const GameSaveData({
    required this.totalIchor,
    required this.cursedOre,
    required this.bloodlineSigils,
    required this.activeGeneralType,
    required this.phylacteryRanks,
    required this.currentChapter,
    required this.maxUnlockedChapter,
    required this.allies,
    required this.reserveInventory,
    required this.relics,
    required this.clearedGauntletTrials,
    required this.lastSavedTimestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'totalIchor': totalIchor,
      'cursedOre': cursedOre,
      'bloodlineSigils': bloodlineSigils,
      'activeGeneralType': activeGeneralType.name,
      'phylacteryRanks': phylacteryRanks.map((k, v) => MapEntry(k.name, v)),
      'currentChapter': currentChapter,
      'maxUnlockedChapter': maxUnlockedChapter,
      'allies': allies.map((u) => u.toJson()).toList(),
      'reserveInventory': reserveInventory.map((u) => u.toJson()).toList(),
      'relics': relics.map((r) => r.toJson()).toList(),
      'clearedGauntletTrials': clearedGauntletTrials.map((t) => t.name).toList(),
      'lastSavedTimestamp': lastSavedTimestamp,
    };
  }

  factory GameSaveData.fromJson(Map<String, dynamic> json) {
    final rawGeneral = json['activeGeneralType'] as String?;
    final generalType = GeneralType.values.firstWhere(
      (g) => g.name == rawGeneral,
      orElse: () => GeneralType.vladislav,
    );

    final rawRanks = json['phylacteryRanks'] as Map<String, dynamic>? ?? {};
    final ranks = <GeneralType, int>{};
    for (final g in GeneralType.values) {
      ranks[g] = (rawRanks[g.name] as num?)?.toInt() ?? 1;
    }

    final rawAllies = json['allies'] as List<dynamic>? ?? [];
    final allies = rawAllies
        .map((e) => UnitEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawInventory = json['reserveInventory'] as List<dynamic>? ?? [];
    final reserveInventory = rawInventory
        .map((e) => UnitEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawRelics = json['relics'] as List<dynamic>? ?? [];
    final relics = rawRelics
        .map((e) => RelicEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawTrials = json['clearedGauntletTrials'] as List<dynamic>? ?? [];
    final clearedTrials = <EndgameTrialType>{};
    for (final tStr in rawTrials) {
      final match = EndgameTrialType.values.where((t) => t.name == tStr).firstOrNull;
      if (match != null) {
        clearedTrials.add(match);
      }
    }

    return GameSaveData(
      totalIchor: (json['totalIchor'] as num?)?.toInt() ?? 450,
      cursedOre: (json['cursedOre'] as num?)?.toInt() ?? 75,
      bloodlineSigils: (json['bloodlineSigils'] as num?)?.toInt() ?? 2,
      activeGeneralType: generalType,
      phylacteryRanks: ranks,
      currentChapter: (json['currentChapter'] as num?)?.toInt() ?? 1,
      maxUnlockedChapter: (json['maxUnlockedChapter'] as num?)?.toInt() ?? 1,
      allies: allies,
      reserveInventory: reserveInventory,
      relics: relics,
      clearedGauntletTrials: clearedTrials,
      lastSavedTimestamp: (json['lastSavedTimestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class GameStatePersistenceService {
  static const String _storageKey = 'ashen_crucible_save_v1';
  static SharedPreferences? _prefsInstance;
  static GameSaveData? _inMemoryFallback;

  static Future<SharedPreferences?> _getPrefs() async {
    try {
      _prefsInstance ??= await SharedPreferences.getInstance();
      return _prefsInstance;
    } catch (_) {
      // Fallback gracefully if SharedPreferences channels are not registered
      return null;
    }
  }

  /// Saves the complete game progression state to persistent storage.
  static Future<bool> save(GameSaveData data) async {
    _inMemoryFallback = data;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final serialized = jsonEncode(data.toJson());
        return await prefs.setString(_storageKey, serialized);
      }
    } catch (e) {
      debugPrint('GameStatePersistenceService.save error: $e');
    }
    return true;
  }

  /// Loads the persisted game state if it exists.
  static Future<GameSaveData?> load() async {
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final raw = prefs.getString(_storageKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final parsed = GameSaveData.fromJson(decoded);
          _inMemoryFallback = parsed;
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('GameStatePersistenceService.load error: $e');
    }
    return _inMemoryFallback;
  }

  /// Whether a saved game state exists in persistent storage.
  static Future<bool> hasSave() async {
    if (_inMemoryFallback != null) return true;
    try {
      final prefs = await _getPrefs();
      return prefs?.containsKey(_storageKey) ?? false;
    } catch (_) {
      return _inMemoryFallback != null;
    }
  }

  /// Erases the saved state (for new game / reset).
  static Future<void> clear() async {
    _inMemoryFallback = null;
    try {
      final prefs = await _getPrefs();
      await prefs?.remove(_storageKey);
    } catch (_) {}
  }
}
