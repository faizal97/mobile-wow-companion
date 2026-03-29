import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/effect_types.dart';
import '../data/td_sfx_registry.dart';

/// Audio service for the tower defense module.
///
/// Uses a pool of [AudioPlayer] instances for concurrent SFX playback.
/// Volume is persisted via [SharedPreferences].
class TdAudioService {
  static const String _volumeKey = 'td_sfx_volume';
  static const double defaultVolume = 0.7;
  static const int _poolSize = 8;

  final TdSfxRegistry _registry;
  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;
  double _volume = defaultVolume;
  bool _initialized = false;

  double get volume => _volume;

  TdAudioService(this._registry);

  /// Initialize the audio pool and load saved volume.
  Future<void> init() async {
    if (_initialized) return;

    for (var i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      _pool.add(player);
    }

    // Load saved volume
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_volumeKey) ?? defaultVolume;
    } catch (_) {
      _volume = defaultVolume;
    }

    _initialized = true;
  }

  /// Set the volume (0.0 to 1.0) and persist it.
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, _volume);
    } catch (_) {
      // Ignore persistence errors
    }
  }

  /// Play a sound from an asset path (e.g. "td/sfx/class/warrior_hit.mp3").
  void playAsset(String? assetPath) {
    if (!_initialized || assetPath == null || _volume <= 0) return;

    final player = _pool[_poolIndex % _poolSize];
    _poolIndex++;

    player
      ..setVolume(_volume)
      ..play(AssetSource(assetPath));
  }

  /// Play a [TdSfxEvent] by resolving it through the registry.
  void playEvent(TdSfxEvent event) {
    final path = _registry.resolveEvent(event);
    playAsset(path);
  }

  /// Play multiple [TdSfxEvent]s, deduplicating by type to avoid stacking
  /// identical sounds in the same frame.
  void playEvents(List<TdSfxEvent> events) {
    final seen = <TdSfxEventType>{};
    for (final event in events) {
      if (seen.add(event.type)) {
        playEvent(event);
      }
    }
  }

  /// Dispose all audio players.
  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _pool.clear();
    _initialized = false;
  }
}
