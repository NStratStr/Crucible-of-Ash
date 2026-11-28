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

  /// Standard ambient BGM tracks bundled in pubspec.yaml
  static const String bgmSanctuary = 'audio/combat_bgm_ambient.mp3';
  static const String bgmCombat = 'audio/combat_bgm_ambient.mp3';

  /// Resolves any SFX identifier or raw GDC filename to mastered 44.1kHz 16-bit dark-fantasy WAVs in pubspec.yaml
  static String resolveSfxAsset(String sfxName) {
    final lower = sfxName.toLowerCase();
    const bundled = {
      'sfx_arrow.wav',
      'sfx_block.wav',
      'sfx_blood.wav',
      'sfx_card.wav',
      'sfx_crit.wav',
      'sfx_enrage.wav',
      'sfx_forge.wav',
      'sfx_hammer.wav',
      'sfx_hit.wav',
      'sfx_shatter.wav',
      'sfx_slash.wav',
      'sfx_spell.wav',
      'sfx_summon.wav',
      'sfx_victory.wav',
    };
    if (bundled.contains(lower)) return lower;
    if (lower.contains('victory')) return 'sfx_victory.wav';
    if (lower.contains('growl') || lower.contains('enrage')) return 'sfx_enrage.wav';
    if (lower.contains('gorebone') || lower.contains('heavy body crunch') || lower.contains('crit')) {
      return 'sfx_crit.wav';
    }
    if (lower.contains('goresplt') || lower.contains('blood') || lower.contains('siphon')) {
      return 'sfx_blood.wav';
    }
    if (lower.contains('hammer') || lower.contains('stone_impact') || lower.contains('smite')) {
      return 'sfx_hammer.wav';
    }
    if (lower.contains('woodcrsh') || lower.contains('shatter') || lower.contains('debris') || lower.contains('glasbrk')) {
      return 'sfx_shatter.wav';
    }
    if (lower.contains('axe_whoosh') || lower.contains('arrow') || lower.contains('bolt')) {
      return 'sfx_arrow.wav';
    }
    if (lower.contains('chain') || lower.contains('summon') || lower.contains('glasmisc')) {
      return 'sfx_summon.wav';
    }
    if (lower.contains('metlimpt') || lower.contains('forge') || lower.contains('upgrade')) {
      return 'sfx_forge.wav';
    }
    if (lower.contains('shield') || lower.contains('armr') || lower.contains('block') || lower.contains('equip')) {
      return 'sfx_block.wav';
    }
    if (lower.contains('slash') || lower.contains('swrd')) {
      return 'sfx_slash.wav';
    }
    if (lower.contains('fire') ||
        lower.contains('magic') ||
        lower.contains('spell') ||
        lower.contains('ritual') ||
        lower.contains('fusion') ||
        lower.contains('thun') ||
        lower.contains('defeat')) {
      return 'sfx_spell.wav';
    }
    if (lower.contains('card') || lower.contains('swing') || lower.contains('whoosh') || lower.contains('tab') || lower.contains('click')) {
      return 'sfx_card.wav';
    }
    return 'sfx_hit.wav';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      AudioLogger.logLevel = AudioLogLevel.none;
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
      _bgmPlayer!.setVolume(0.0).catchError((_) {});
      _bgmPlayer!.pause().catchError((_) {});
    } else {
      final targetVol = settings.bgmVolume * 0.45;
      _bgmPlayer!.setVolume(targetVol).catchError((_) {});
      if (_currentBgmAsset != null && _bgmPlayer!.state != PlayerState.playing) {
        _bgmPlayer!.resume().catchError((_) {});
      }
    }
    if (!settings.sfxEnabled) {
      for (final p in _sfxPlayers) {
        p.setVolume(0.0).catchError((_) {});
        p.stop().catchError((_) {});
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
      player
          .setVolume(vol)
          .then((_) => player.play(AssetSource('audio/$resolved')))
          .catchError((_) {});
    } catch (_) {
      // Silently ignore unsupported audio sources
    }
  }
}
