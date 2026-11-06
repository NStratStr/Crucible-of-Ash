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
  final List<AudioPlayer> _sfxPlayers = [];
  int _sfxIndex = 0;
  static const int _maxSfxPlayers = 4;
  Timer? _fadeTimer;
  String? _currentBgmAsset;
  bool _isInitialized = false;

  /// Resolves generic/arcade SFX identifiers to visceral acoustic dark fantasy assets
  static String resolveSfxAsset(String sfxName) {
    switch (sfxName) {
      case 'sfx_block.wav':
        return 'WEAPArmr_Metal Shield Block Hits_JSE_MW.wav';
      case 'sfx_slash.wav':
        return 'SWSH_Sword Slash Impact V2 Assorted 18_DDUMAIS_NONE.wav';
      case 'sfx_hit.wav':
        return 'WEAPAxe_Long Two-Handed Axe Flesh Hit_JSE_MW.wav';
      case 'sfx_spell.wav':
        return 'Bluezone_BC0261_mountain_dweller_texture_fire_whoosh_003.wav';
      case 'sfx_card.wav':
        return 'SWSH_Swing 3 Large 03_DDUMAIS_NONE.wav';
      case 'sfx_summon.wav':
        return 'CHAINMvmt_InsJ_Chains_Metal_Movement_Distant_Moderate_02-01.wav';
      case 'sfx_crit.wav':
        return 'GOREBone_Bone Breaks Celery 01_JSE_GMP.wav';
      case 'sfx_blood.wav':
        return 'GORESplt_Gore Splatter 01_JSE_GMP.wav';
      case 'sfx_smite.wav':
      case 'sfx_hammer.wav':
        return 'Bluezone_BC0297_stone_impact_hammer_015.wav';
      case 'sfx_shatter.wav':
        return 'WOODCrsh_Designed Wood Crash And Debris 13_DDUMAIS_NONE.wav';
      case 'sfx_enrage.wav':
        return 'Dinosaur Growl 3_Mono.wav';
      default:
        return sfxName;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      _bgmPlayer = AudioPlayer();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);

      for (int i = 0; i < _maxSfxPlayers; i++) {
        _sfxPlayers.add(AudioPlayer());
      }

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

  /// Plays a short one-shot sound effect safely using the pooled SFX players
  void playSfx(String sfxName, {double volumeMultiplier = 0.70}) {
    final settings = SettingsService();
    if (!settings.sfxEnabled || _sfxPlayers.isEmpty) return;

    try {
      final resolved = resolveSfxAsset(sfxName);
      final player = _sfxPlayers[_sfxIndex];
      _sfxIndex = (_sfxIndex + 1) % _sfxPlayers.length;

      final vol = (settings.sfxVolume * volumeMultiplier).clamp(0.0, 1.0);
      player.setVolume(vol).then((_) {
        player.play(AssetSource('audio/$resolved'));
      }).catchError((e) {
        debugPrint('Error playing SFX $resolved: $e');
      });
    } catch (e) {
      debugPrint('Error playing SFX $sfxName: $e');
    }
  }
}
