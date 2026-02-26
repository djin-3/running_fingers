import 'package:audioplayers/audioplayers.dart';

/// 効果音・BGMを管理するシングルトンサービス
class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sePlayer = AudioPlayer();

  bool _bgmEnabled = true;
  bool _initialized = false;

  Future<void> init({bool bgmEnabled = true}) async {
    _bgmEnabled = bgmEnabled;
    _initialized = true;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    if (_bgmEnabled) {
      await startBgm();
    }
  }

  Future<void> startBgm() async {
    if (!_initialized) return;
    try {
      await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
    } catch (_) {
      // 音声ファイル未配置の場合はサイレント失敗
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    if (enabled) {
      await startBgm();
    } else {
      await stopBgm();
    }
  }

  Future<void> playTap() async {
    try {
      await _sePlayer.play(AssetSource('sounds/tap.mp3'));
    } catch (_) {}
  }

  Future<void> playStart() async {
    try {
      await _sePlayer.stop();
      await _sePlayer.play(AssetSource('sounds/start.mp3'));
    } catch (_) {}
  }

  Future<void> playGoal() async {
    try {
      await _sePlayer.stop();
      await _sePlayer.play(AssetSource('sounds/goal.mp3'));
    } catch (_) {}
  }

  Future<void> playBest() async {
    try {
      await _sePlayer.stop();
      await _sePlayer.play(AssetSource('sounds/best.mp3'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sePlayer.dispose();
  }
}
