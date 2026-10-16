import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Settings Service managing Audio, Graphics, Simulation, and Telco/Network preferences.
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Audio Settings
  bool _bgmEnabled = true;
  double _bgmVolume = 0.70;
  bool _sfxEnabled = true;
  double _sfxVolume = 0.85;

  // Visual & Presentation Settings
  bool _screenShakeEnabled = true;
  bool _damageNumbersEnabled = true;
  bool _highContrastHpBars = true;
  bool _particleFXEnabled = true;

  // Telco & Connectivity Settings
  bool _lowDataMode = false;
  bool _offlineCacheMode = true;
  bool _analyticsTelemetry = true;
  String _networkProfile = 'Auto (Adaptive 4G/5G)';

  // Simulation & Combat Pacing
  double _defaultCombatSpeed = 1.0;
  bool _autoPauseOnBossTelegraph = true;

  // Getters
  bool get bgmEnabled => _bgmEnabled;
  double get bgmVolume => _bgmVolume;
  bool get sfxEnabled => _sfxEnabled;
  double get sfxVolume => _sfxVolume;

  bool get screenShakeEnabled => _screenShakeEnabled;
  bool get damageNumbersEnabled => _damageNumbersEnabled;
  bool get highContrastHpBars => _highContrastHpBars;
  bool get particleFXEnabled => _particleFXEnabled;

  bool get lowDataMode => _lowDataMode;
  bool get offlineCacheMode => _offlineCacheMode;
  bool get analyticsTelemetry => _analyticsTelemetry;
  String get networkProfile => _networkProfile;

  double get defaultCombatSpeed => _defaultCombatSpeed;
  bool get autoPauseOnBossTelegraph => _autoPauseOnBossTelegraph;

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bgmEnabled = prefs.getBool('settings_bgm_enabled') ?? true;
      _bgmVolume = prefs.getDouble('settings_bgm_volume') ?? 0.70;
      _sfxEnabled = prefs.getBool('settings_sfx_enabled') ?? true;
      _sfxVolume = prefs.getDouble('settings_sfx_volume') ?? 0.85;

      _screenShakeEnabled = prefs.getBool('settings_screen_shake') ?? true;
      _damageNumbersEnabled = prefs.getBool('settings_damage_numbers') ?? true;
      _highContrastHpBars = prefs.getBool('settings_high_contrast') ?? true;
      _particleFXEnabled = prefs.getBool('settings_particle_fx') ?? true;

      _lowDataMode = prefs.getBool('settings_low_data') ?? false;
      _offlineCacheMode = prefs.getBool('settings_offline_cache') ?? true;
      _analyticsTelemetry = prefs.getBool('settings_analytics') ?? true;
      _networkProfile = prefs.getString('settings_network_profile') ?? 'Auto (Adaptive 4G/5G)';

      _defaultCombatSpeed = prefs.getDouble('settings_combat_speed') ?? 1.0;
      _autoPauseOnBossTelegraph = prefs.getBool('settings_auto_pause_telegraph') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    notifyListeners();
    _saveBool('settings_bgm_enabled', enabled);
  }

  Future<void> setBgmVolume(double vol) async {
    _bgmVolume = vol.clamp(0.0, 1.0);
    notifyListeners();
    _saveDouble('settings_bgm_volume', _bgmVolume);
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    notifyListeners();
    _saveBool('settings_sfx_enabled', enabled);
  }

  Future<void> setSfxVolume(double vol) async {
    _sfxVolume = vol.clamp(0.0, 1.0);
    notifyListeners();
    _saveDouble('settings_sfx_volume', _sfxVolume);
  }

  Future<void> setScreenShakeEnabled(bool enabled) async {
    _screenShakeEnabled = enabled;
    notifyListeners();
    _saveBool('settings_screen_shake', enabled);
  }

  Future<void> setDamageNumbersEnabled(bool enabled) async {
    _damageNumbersEnabled = enabled;
    notifyListeners();
    _saveBool('settings_damage_numbers', enabled);
  }

  Future<void> setHighContrastHpBars(bool enabled) async {
    _highContrastHpBars = enabled;
    notifyListeners();
    _saveBool('settings_high_contrast', enabled);
  }

  Future<void> setParticleFXEnabled(bool enabled) async {
    _particleFXEnabled = enabled;
    notifyListeners();
    _saveBool('settings_particle_fx', enabled);
  }

  Future<void> setLowDataMode(bool enabled) async {
    _lowDataMode = enabled;
    notifyListeners();
    _saveBool('settings_low_data', enabled);
  }

  Future<void> setOfflineCacheMode(bool enabled) async {
    _offlineCacheMode = enabled;
    notifyListeners();
    _saveBool('settings_offline_cache', enabled);
  }

  Future<void> setAnalyticsTelemetry(bool enabled) async {
    _analyticsTelemetry = enabled;
    notifyListeners();
    _saveBool('settings_analytics', enabled);
  }

  Future<void> setNetworkProfile(String profile) async {
    _networkProfile = profile;
    notifyListeners();
    _saveString('settings_network_profile', profile);
  }

  Future<void> setDefaultCombatSpeed(double speed) async {
    _defaultCombatSpeed = speed;
    notifyListeners();
    _saveDouble('settings_combat_speed', speed);
  }

  Future<void> setAutoPauseOnBossTelegraph(bool enabled) async {
    _autoPauseOnBossTelegraph = enabled;
    notifyListeners();
    _saveBool('settings_auto_pause_telegraph', enabled);
  }

  void _saveBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  void _saveDouble(String key, double val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, val);
    } catch (_) {}
  }

  void _saveString(String key, String val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, val);
    } catch (_) {}
  }
}
