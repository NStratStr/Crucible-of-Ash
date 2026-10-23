import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../features/settings/settings_service.dart';

/// Centralized Global Audio Management Service
/// Provides:
/// - Continuous background music (BGM) across screen transitions without cutting or restarting from second 0
/// - Smooth cross-fade volume ramping when entering/exiting combat or toggling screens
/// - Instant mute/unmute reaction synced with SettingsService
/// - Clean SFX playback pooling without blocking Windows Media Player threads
class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;
  Timer? _fadeTimer;
  String? _currentBgmAsset;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      _bgmPlayer = AudioPlayer();
      _sfxPlayer = AudioPlayer();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);

      final settings = SettingsService();
      settings.addListener(_onSettingsChanged);
      _applySettings();
    } catch (e) {
      debugPrint('GlobalAudioService init error: $e');
    }
  }

  void _onSettingsChanged() {
    _applySettings();
  }

  void _applySettings() {
    final settings = SettingsService();
    if (_bgmPlayer == null) return;

    if (!settings.bgmEnabled) {
      _bgmPlayer!.setVolume(0.0);
      _bgmPlayer!.pause();
    } else {
      final targetVol = settings.bgmVolume * 0.45;
      _bgmPlayer!.setVolume(targetVol);
      if (_currentBgmAsset != null && _bgmPlayer!.state != PlayerState.playing) {
        _bgmPlayer!.resume();
      }
    }
  }

  /// Plays or transitions to a BGM asset.
  /// If the requested asset is ALREADY playing, it smoothly adjusts volume without restarting!
  Future<void> playBgm(String assetPath, {bool fadeIn = true}) async {
    final settings = SettingsService();
    final targetVol = settings.bgmEnabled ? (settings.bgmVolume * 0.45) : 0.0;

    if (_bgmPlayer == null) {
      await init();
    }

    if (_currentBgmAsset == assetPath && _bgmPlayer?.state == PlayerState.playing) {
      // Already running: smoothly ensure target volume without restarting track
      if (settings.bgmEnabled) {
        await _bgmPlayer?.setVolume(targetVol);
      }
      return;
    }

    _currentBgmAsset = assetPath;
    if (!settings.bgmEnabled) return;

    try {
      if (fadeIn) {
        await _bgmPlayer!.setVolume(0.0);
        await _bgmPlayer!.play(AssetSource(assetPath));
        _rampVolume(0.0, targetVol, const Duration(milliseconds: 600));
      } else {
        await _bgmPlayer!.setVolume(targetVol);
        await _bgmPlayer!.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('Error playing BGM $assetPath: $e');
    }
  }

  /// Smoothly ramps volume between start and target
  void _rampVolume(double from, double to, Duration duration) {
    _fadeTimer?.cancel();
    const steps = 12;
    final stepDuration = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    int currentStep = 0;

    _fadeTimer = Timer.periodic(stepDuration, (t) {
      currentStep++;
      final factor = (currentStep / steps).clamp(0.0, 1.0);
      final currentVol = from + (to - from) * factor;
      _bgmPlayer?.setVolume(currentVol).catchError((_) {});
      if (currentStep >= steps) {
        t.cancel();
      }
    });
  }

  /// Pauses BGM with an optional fade out
  Future<void> pauseBgm({bool fadeOut = true}) async {
    if (_bgmPlayer == null) return;
    final settings = SettingsService();
    final currentVol = settings.bgmVolume * 0.45;

    if (fadeOut) {
      _rampVolume(currentVol, 0.0, const Duration(milliseconds: 400));
      Future.delayed(const Duration(milliseconds: 450), () {
        _bgmPlayer?.pause();
      });
    } else {
      await _bgmPlayer?.setVolume(0.0);
      await _bgmPlayer?.pause();
    }
  }

  /// Resumes BGM
  Future<void> resumeBgm() async {
    final settings = SettingsService();
    if (!settings.bgmEnabled || _bgmPlayer == null) return;
    final targetVol = settings.bgmVolume * 0.45;
    await _bgmPlayer?.setVolume(targetVol);
    await _bgmPlayer?.resume();
  }

  /// Plays a short one-shot sound effect safely
  void playSfx(String sfxName, {double volumeMultiplier = 0.70}) {
    final settings = SettingsService();
    if (!settings.sfxEnabled || _sfxPlayer == null) return;

    try {
      final vol = (settings.sfxVolume * volumeMultiplier).clamp(0.0, 1.0);
      _sfxPlayer!.setVolume(vol).then((_) {
        _sfxPlayer!.play(AssetSource('audio/$sfxName'));
      }).catchError((e) {
        debugPrint('Error playing SFX $sfxName: $e');
      });
    } catch (e) {
      debugPrint('Error playing SFX $sfxName: $e');
    }
  }
}
