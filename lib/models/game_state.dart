import 'dart:async';
import 'package:flutter/foundation.dart';

/// タップの側（2本モード用）
enum TapSide { left, right }

/// ゲームの進行状態
enum GamePhase {
  /// 開始待ち
  ready,

  /// プレイ中
  playing,

  /// 完了
  finished,
}

/// ゲームの状態管理
///
/// Phase 1 プロトタイプ:
/// - 左右交互タップの検出
/// - 同じ側連続タップの無効化
/// - 基本的なカウント機能
/// - タイマー計測
class GameState extends ChangeNotifier {
  final int fingerMode; // 1 or 2
  final bool isTimeAttack;

  GameState({
    required this.fingerMode,
    required this.isTimeAttack,
  });

  GamePhase _phase = GamePhase.ready;
  GamePhase get phase => _phase;

  /// 有効タップ数
  int _tapCount = 0;
  int get tapCount => _tapCount;

  /// 無効タップ数（同じ側連続タップ）
  int _invalidTapCount = 0;
  int get invalidTapCount => _invalidTapCount;

  /// 最後にタップした側（2本モード用）
  TapSide? _lastTapSide;
  TapSide? get lastTapSide => _lastTapSide;

  /// 最後のタップが無効だったか（UI フィードバック用）
  bool _lastTapWasInvalid = false;
  bool get lastTapWasInvalid => _lastTapWasInvalid;

  /// 無効タップがあった側（UI フィードバック用）
  TapSide? _invalidTapSide;
  TapSide? get invalidTapSide => _invalidTapSide;

  /// タイマー関連
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  /// 経過時間（ミリ秒）
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  /// 経過時間（秒、小数点2桁）
  String get elapsedFormatted {
    final ms = _stopwatch.elapsedMilliseconds;
    final seconds = ms / 1000;
    return seconds.toStringAsFixed(2);
  }

  /// タップチャレンジの残り時間（秒）
  double get remainingSeconds {
    if (!isTimeAttack) {
      final elapsed = _stopwatch.elapsedMilliseconds / 1000;
      return (10.0 - elapsed).clamp(0.0, 10.0);
    }
    return 0;
  }

  String get remainingFormatted {
    return remainingSeconds.toStringAsFixed(2);
  }

  /// タイムアタックの目標タップ数
  static const int timeAttackTarget = 100;

  /// タップチャレンジの制限時間（秒）
  static const double tapChallengeLimit = 10.0;

  /// タップを処理する
  ///
  /// [side] は2本モードの場合にどちら側がタップされたかを示す。
  /// 1本モードの場合は null。
  ///
  /// 戻り値: タップが有効だったかどうか
  bool handleTap({TapSide? side}) {
    // ゲーム終了後はタップを無視
    if (_phase == GamePhase.finished) return false;

    // 最初のタップでゲーム開始
    if (_phase == GamePhase.ready) {
      _startGame();
    }

    // 2本モード: 同じ側の連続タップを無効化
    if (fingerMode == 2 && side != null && side == _lastTapSide) {
      _invalidTapCount++;
      _lastTapWasInvalid = true;
      _invalidTapSide = side;
      notifyListeners();

      // 少し遅延してフィードバックをリセット
      Future.delayed(const Duration(milliseconds: 200), () {
        _lastTapWasInvalid = false;
        _invalidTapSide = null;
        notifyListeners();
      });

      return false;
    }

    // 有効なタップ
    _tapCount++;
    _lastTapSide = side;
    _lastTapWasInvalid = false;
    _invalidTapSide = null;

    // タイムアタック: 目標タップ数に到達したら終了
    if (isTimeAttack && _tapCount >= timeAttackTarget) {
      _finishGame();
    }

    notifyListeners();
    return true;
  }

  void _startGame() {
    _phase = GamePhase.playing;
    _stopwatch = Stopwatch()..start();

    // タップチャレンジ: タイマーで制限時間を監視
    if (!isTimeAttack) {
      _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        if (_stopwatch.elapsedMilliseconds >= (tapChallengeLimit * 1000).toInt()) {
          _finishGame();
        }
        notifyListeners();
      });
    } else {
      // タイムアタック: 表示更新用タイマー
      _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        notifyListeners();
      });
    }
  }

  void _finishGame() {
    _phase = GamePhase.finished;
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// ゲームをリセット
  void reset() {
    _phase = GamePhase.ready;
    _tapCount = 0;
    _invalidTapCount = 0;
    _lastTapSide = null;
    _lastTapWasInvalid = false;
    _invalidTapSide = null;
    _stopwatch = Stopwatch();
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
