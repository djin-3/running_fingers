import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// タップの側（2本モード用）
enum TapSide { left, right }

/// ゲームの進行状態
enum GamePhase {
  /// スタートボタン待ち
  ready,

  /// "On your mark" 表示中
  onYourMark,

  /// "Set" 表示中（ランダム待機、フライング検出対象）
  set,

  /// "Go!!" プレイ中
  playing,

  /// 完了
  finished,
}

/// ゲームの状態管理
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

  /// コンボカウンター（無効タップでリセット）
  int _currentCombo = 0;
  int get currentCombo => _currentCombo;

  /// フライング関連
  bool _hadFalseStart = false;
  bool get hadFalseStart => _hadFalseStart;

  /// タイムアタック: フライングペナルティによるタップ無効期間（秒）
  static const double _falseStartPenaltySeconds = 3.0;

  /// タップチャレンジ: フライングペナルティ（マイナスカウント）
  static const int _falseStartPenaltyTaps = 10;

  /// タイムアタック: ペナルティ中か
  bool get isInPenalty {
    if (!isTimeAttack || !_hadFalseStart) return false;
    return _stopwatch.elapsedMilliseconds < (_falseStartPenaltySeconds * 1000);
  }

  /// ペナルティ残り時間（秒）
  double get penaltyRemainingSeconds {
    if (!isInPenalty) return 0;
    final elapsed = _stopwatch.elapsedMilliseconds / 1000;
    return (_falseStartPenaltySeconds - elapsed).clamp(0.0, _falseStartPenaltySeconds);
  }

  /// タイマー関連
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Timer? _startSequenceTimer;

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

  /// "On your mark" の表示時間（ミリ秒）
  static const int _onYourMarkDuration = 1500;

  /// "Set" のランダム待機時間の範囲（ミリ秒）
  static const int _setMinDuration = 1500;
  static const int _setMaxDuration = 3000;

  final Random _random = Random();

  /// スタート合図シーケンスを開始
  void startSequence() {
    if (_phase != GamePhase.ready) return;

    _phase = GamePhase.onYourMark;
    notifyListeners();

    // "On your mark" → "Set"
    _startSequenceTimer = Timer(const Duration(milliseconds: _onYourMarkDuration), () {
      _phase = GamePhase.set;
      notifyListeners();

      // "Set" → "Go!!" （ランダム待機）
      final setDuration = _setMinDuration + _random.nextInt(_setMaxDuration - _setMinDuration);
      _startSequenceTimer = Timer(Duration(milliseconds: setDuration), () {
        _startGame();
      });
    });
  }

  /// タップを処理する
  ///
  /// [side] は2本モードの場合にどちら側がタップされたかを示す。
  /// 1本モードの場合は null。
  ///
  /// 戻り値: タップが有効だったかどうか
  bool handleTap({TapSide? side}) {
    // スタート前・完了後はタップを無視
    if (_phase == GamePhase.ready || _phase == GamePhase.onYourMark || _phase == GamePhase.finished) {
      return false;
    }

    // "Set" 中のタップ = フライング
    if (_phase == GamePhase.set) {
      _handleFalseStart();
      return false;
    }

    // プレイ中: タイムアタックのペナルティ期間中はタップ無効
    if (isInPenalty) {
      return false;
    }

    // 2本モード: 同じ側の連続タップを無効化
    if (fingerMode == 2 && side != null && side == _lastTapSide) {
      _invalidTapCount++;
      _currentCombo = 0;
      _lastTapWasInvalid = true;
      _invalidTapSide = side;
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 200), () {
        _lastTapWasInvalid = false;
        _invalidTapSide = null;
        notifyListeners();
      });

      return false;
    }

    // 有効なタップ
    _tapCount++;
    _currentCombo++;
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

  /// フライング処理
  void _handleFalseStart() {
    _hadFalseStart = true;
    _startSequenceTimer?.cancel();

    // 即座にゲーム開始（ペナルティ付き）
    if (!isTimeAttack) {
      // タップチャレンジ: マイナスからカウント開始
      _tapCount = -_falseStartPenaltyTaps;
    }
    // タイムアタック: ペナルティ秒数はタイマー開始後に isInPenalty で制御

    _startGame();
  }

  void _startGame() {
    _phase = GamePhase.playing;
    _stopwatch = Stopwatch()..start();

    if (!isTimeAttack) {
      // タップチャレンジ: タイマーで制限時間を監視
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

    notifyListeners();
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
    _currentCombo = 0;
    _lastTapSide = null;
    _lastTapWasInvalid = false;
    _invalidTapSide = null;
    _hadFalseStart = false;
    _stopwatch = Stopwatch();
    _timer?.cancel();
    _timer = null;
    _startSequenceTimer?.cancel();
    _startSequenceTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startSequenceTimer?.cancel();
    super.dispose();
  }
}
