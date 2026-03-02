import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/game_state.dart';
import '../models/record_data.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/tap_button.dart';
import 'result_screen.dart';

/// ゲーム画面
///
/// - スタート合図シーケンス（"On your mark" → "Set" → "Go!!"）
/// - フライング検出とペナルティ表示
/// - 2本モード: 左右ボタン配置、交互タップ検出
/// - 1本モード: 中央ボタン配置、連打検出
/// - タイマー/カウンター表示
/// - ボタン位置調整: readyフェーズで直接ドラッグ（2本指同時対応）、位置はSharedPreferencesに保存
class GameScreen extends StatefulWidget {
  final int fingerMode;
  final bool isTimeAttack;

  const GameScreen({
    super.key,
    required this.fingerMode,
    required this.isTimeAttack,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameState _gameState;
  bool _leftTapped = false;
  bool _rightTapped = false;
  bool _centerTapped = false;

  // ボタン位置（正規化: 0.0〜1.0 / MediaQuery.of(context).size 基準）
  Offset _leftNorm = const Offset(0.25, 0.82);
  Offset _rightNorm = const Offset(0.75, 0.82);
  Offset _centerNorm = const Offset(0.5, 0.82);

  // スタートボタンの位置取得用
  final GlobalKey _startButtonKey = GlobalKey();

  // ポインター→ボタンマッピング（readyフェーズの2本指ドラッグ）
  final Map<int, String> _pointerToButton = {};
  final Set<String> _draggingKeys = {};
  Size _screenSize = Size.zero;
  double _buttonSize = 0;

  // "Go!!" バウンス
  bool _goAnimTriggered = false;
  late AnimationController _goAnimController;
  late Animation<double> _goScaleAnim;

  // "Set" パルス
  late AnimationController _setPulseController;
  late Animation<double> _setPulseAnim;

  @override
  void initState() {
    super.initState();
    _gameState = GameState(
      fingerMode: widget.fingerMode,
      isTimeAttack: widget.isTimeAttack,
    );
    _gameState.addListener(_onGameStateChanged);
    WidgetsBinding.instance.addObserver(this);

    // "Go!!" バウンス: 大→通常サイズ（elasticOut でバネ感）
    _goAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _goScaleAnim = Tween<double>(begin: 1.8, end: 1.0).animate(
      CurvedAnimation(parent: _goAnimController, curve: Curves.elasticOut),
    );

    // "Set" パルス: 微妙な拡縮を繰り返して緊張感を演出
    _setPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _setPulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _setPulseController, curve: Curves.easeInOut),
    );

    _loadButtonPositions();
  }

  Future<void> _loadButtonPositions() async {
    final left = await StorageService.getButtonPos(
        StorageService.posKeyLeft, const Offset(0.25, 0.82));
    final right = await StorageService.getButtonPos(
        StorageService.posKeyRight, const Offset(0.75, 0.82));
    final center = await StorageService.getButtonPos(
        StorageService.posKeyCenter, const Offset(0.5, 0.82));
    if (mounted) {
      setState(() {
        _leftNorm = left;
        _rightNorm = right;
        _centerNorm = center;
      });
    }
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});

    // "Go!!" バウンスをゲーム開始時に一度だけ起動
    if (_gameState.phase == GamePhase.playing && !_goAnimTriggered) {
      _goAnimTriggered = true;
      _goAnimController.forward(from: 0);
      AudioService().playStart();
    }

    // "Set" 中はパルスを繰り返す、それ以外は止める
    if (_gameState.phase == GamePhase.set) {
      if (!_setPulseController.isAnimating) {
        _setPulseController.repeat(reverse: true);
      }
    } else if (_setPulseController.isAnimating) {
      _setPulseController.stop();
      _setPulseController.value = 0;
    }

    // プレイ中はスリープ防止、終了時は解除
    if (_gameState.phase == GamePhase.playing) {
      WakelockPlus.enable();
    } else if (_gameState.phase == GamePhase.finished) {
      WakelockPlus.disable();
    }

    if (_gameState.phase == GamePhase.finished && !_navigatedToResult) {
      _navigatedToResult = true;
      AudioService().playGoal();
      _navigateToResult();
    }
  }

  bool _navigatedToResult = false;

  Future<void> _navigateToResult() async {
    final record = RecordData(
      value: widget.isTimeAttack
          ? _gameState.elapsedMilliseconds / 1000.0
          : _gameState.tapCount.toDouble(),
      date: DateTime.now(),
      hadFalseStart: _gameState.hadFalseStart,
      usedTicket: false,
      fingerMode: widget.fingerMode,
    );

    if (!mounted) return;
    final retry = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          record: record,
          isTimeAttack: widget.isTimeAttack,
        ),
      ),
    );

    if (mounted && retry == true) {
      _resetGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    _goAnimController.dispose();
    _setPulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final phase = _gameState.phase;
      if (phase == GamePhase.playing ||
          phase == GamePhase.onYourMark ||
          phase == GamePhase.set) {
        _gameState.reset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  void _handleTap({TapSide? side}) {
    final isValid = _gameState.handleTap(side: side);
    if (isValid) {
      HapticFeedback.lightImpact();
      AudioService().playTap();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _resetGame() {
    _navigatedToResult = false;
    _goAnimTriggered = false;
    _goAnimController.reset();
    _setPulseController.stop();
    _setPulseController.value = 0;
    _pointerToButton.clear();
    _draggingKeys.clear();
    _gameState.reset();
  }

  void _clearTapState() {
    setState(() {
      _leftTapped = false;
      _rightTapped = false;
      _centerTapped = false;
    });
  }

  void _handleGameTap(Offset globalPos, Size size, double buttonSize) {
    // 将来の2人プレイ: globalPos.dy < size.height / 2 でP1(上), >= でP2(下) を判定可能
    if (widget.fingerMode == 2) {
      final leftPx = Offset(_leftNorm.dx * size.width, _leftNorm.dy * size.height);
      final rightPx = Offset(_rightNorm.dx * size.width, _rightNorm.dy * size.height);
      if (_isWithinTapRadius(globalPos, leftPx, buttonSize)) {
        setState(() => _leftTapped = true);
        _handleTap(side: TapSide.left);
      } else if (_isWithinTapRadius(globalPos, rightPx, buttonSize)) {
        setState(() => _rightTapped = true);
        _handleTap(side: TapSide.right);
      }
    } else {
      final centerPx = Offset(_centerNorm.dx * size.width, _centerNorm.dy * size.height);
      if (_isWithinTapRadius(globalPos, centerPx, buttonSize)) {
        setState(() => _centerTapped = true);
        _handleTap();
      }
    }
  }

  /// タップがボタン中心から有効半径内かどうか判定
  bool _isWithinTapRadius(Offset tapPosition, Offset center, double buttonSize) {
    // ボタン半径 + 20px の余裕
    final tapRadius = buttonSize / 2 + 20;
    return (tapPosition - center).distance <= tapRadius;
  }

  void _onReadyPointerDown(PointerDownEvent event) {
    final keys = widget.fingerMode == 2 ? ['left', 'right'] : ['center'];
    for (final key in keys) {
      if (_pointerToButton.containsValue(key)) continue;
      final norm = key == 'left'
          ? _leftNorm
          : key == 'right'
              ? _rightNorm
              : _centerNorm;
      final px = Offset(norm.dx * _screenSize.width, norm.dy * _screenSize.height);
      if ((event.position - px).distance <= _buttonSize / 2 + 30) {
        setState(() {
          _pointerToButton[event.pointer] = key;
          _draggingKeys.add(key);
        });
        return;
      }
    }
  }

  void _onReadyPointerMove(PointerMoveEvent event) {
    final key = _pointerToButton[event.pointer];
    if (key == null) return;
    final raw = Offset(
      event.position.dx / _screenSize.width,
      event.position.dy / _screenSize.height,
    );
    final constrained = _applyConstraints(key, raw, _screenSize, _buttonSize);
    setState(() {
      if (key == 'left') _leftNorm = constrained;
      else if (key == 'right') _rightNorm = constrained;
      else _centerNorm = constrained;
    });
  }

  void _onReadyPointerUp(PointerUpEvent event) {
    final key = _pointerToButton[event.pointer];
    if (key == null) return;
    setState(() {
      _pointerToButton.remove(event.pointer);
      _draggingKeys.remove(key);
    });
    final norm = key == 'left'
        ? _leftNorm
        : key == 'right'
            ? _rightNorm
            : _centerNorm;
    StorageService.saveButtonPos(
      key == 'left'
          ? StorageService.posKeyLeft
          : key == 'right'
              ? StorageService.posKeyRight
              : StorageService.posKeyCenter,
      norm,
    );
  }

  void _onReadyPointerCancel(PointerCancelEvent event) {
    final key = _pointerToButton[event.pointer];
    if (key == null) return;
    setState(() {
      _pointerToButton.remove(event.pointer);
      _draggingKeys.remove(key);
    });
  }

  Offset _applyConstraints(String key, Offset norm, Size size, double buttonSize) {
    // 1. 画面内クランプ（下半分 Y >= 0.5 に制約 & ボタン半径マージン）
    // Y >= 0.5 制約: 将来の2人プレイで上半分をP1、下半分をP2に使うため
    // これによりスタートボタン（Y≈0.35）との重なりも物理的に排除される
    final hx = (buttonSize / 2) / size.width;
    final hy = (buttonSize / 2) / size.height;
    final x = norm.dx.clamp(hx, 1.0 - hx).toDouble();
    final y = norm.dy.clamp(math.max(hy, 0.5), 1.0 - hy).toDouble();
    var result = Offset(x, y);

    // 2. 2本モード: x方向制約（right.x >= left.x）
    if (widget.fingerMode == 2) {
      if (key == 'right') {
        result = Offset(math.max(result.dx, _leftNorm.dx), result.dy);
      } else if (key == 'left') {
        result = Offset(math.min(result.dx, _rightNorm.dx), result.dy);
      }
    }

    // 4. 2本モード: 重なり禁止
    if (widget.fingerMode == 2) {
      final otherNorm = key == 'left' ? _rightNorm : _leftNorm;
      final resPx = Offset(result.dx * size.width, result.dy * size.height);
      final othPx = Offset(otherNorm.dx * size.width, otherNorm.dy * size.height);
      if ((resPx - othPx).distance < buttonSize) {
        return key == 'left' ? _leftNorm : _rightNorm;
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isTappable = _gameState.phase == GamePhase.set ||
        _gameState.phase == GamePhase.playing;
    final isReady = _gameState.phase == GamePhase.ready;
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    final buttonSize = widget.fingerMode == 2
        ? shortestSide * 0.20
        : shortestSide * 0.25;
    _screenSize = size;
    _buttonSize = buttonSize;

    return Scaffold(
      body: Stack(
        children: [
          // 通常UI（ヘッダー・中央エリア・タップエリア枠線）
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildCenterArea(context)),
                _buildTapAreaGuide(),
              ],
            ),
          ),
          // ゲームタップ検出（set/playingのみ。translucent で他UIを妨げない）
          if (isTappable)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) =>
                    _handleGameTap(details.globalPosition, size, buttonSize),
                onTapUp: (_) => _clearTapState(),
                onTapCancel: _clearTapState,
              ),
            ),
          // ボタンオーバーレイ（常に描画）
          _buildButtonOverlay(isReady, size, buttonSize),
          // 画面端グロー
          IgnorePointer(child: _buildScreenGlow()),
        ],
      ),
    );
  }

  Widget _buildScreenGlow() {
    return AnimatedOpacity(
      opacity: _gameState.phase == GamePhase.playing && _gameState.effectLevel >= 4
          ? 1.0
          : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.transparent,
              Colors.lightBlueAccent.withValues(
                alpha: _gameState.effectLevel >= 5 ? 0.18 : 0.10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// タップエリアのガイド枠（ボタンはオーバーレイに移動）
  Widget _buildTapAreaGuide() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonOverlay(bool isReady, Size size, double buttonSize) {
    final stack = Stack(
      children: [
        if (widget.fingerMode == 2) ...[
          _buildPositionedButton('left', isReady, size, buttonSize),
          _buildPositionedButton('right', isReady, size, buttonSize),
        ] else ...[
          _buildPositionedButton('center', isReady, size, buttonSize),
        ],
        // readyフェーズのみ: 操作ヒント
        if (isReady)
          Align(
            alignment: const Alignment(0, 0.6),
            child: Text(
              'ドラッグでボタンを移動',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
      ],
    );
    return Positioned.fill(
      child: isReady
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onReadyPointerDown,
              onPointerMove: _onReadyPointerMove,
              onPointerUp: _onReadyPointerUp,
              onPointerCancel: _onReadyPointerCancel,
              child: stack,
            )
          : stack,
    );
  }

  Widget _buildPositionedButton(
      String key, bool isReady, Size size, double buttonSize) {
    final norm = key == 'left'
        ? _leftNorm
        : key == 'right'
            ? _rightNorm
            : _centerNorm;
    final px = Offset(norm.dx * size.width, norm.dy * size.height);
    final button = _buildTapButtonWidget(key, buttonSize);

    return Positioned(
      left: px.dx - buttonSize / 2,
      top: px.dy - buttonSize / 2,
      width: buttonSize,
      height: buttonSize,
      child: isReady
          ? AnimatedScale(
              scale: _draggingKeys.contains(key) ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Opacity(
                opacity: _draggingKeys.contains(key) ? 0.8 : 1.0,
                child: button,
              ),
            )
          : IgnorePointer(child: button),
    );
  }

  Widget _buildTapButtonWidget(String key, double buttonSize) {
    final isActive = _gameState.phase == GamePhase.set ||
        _gameState.phase == GamePhase.playing;
    if (key == 'left') {
      return TapButton(
        label: 'L',
        isTapped: _leftTapped,
        isInvalid: _gameState.invalidTapSide == TapSide.left,
        isActive: isActive,
        size: buttonSize,
        effectLevel: _gameState.effectLevel,
      );
    } else if (key == 'right') {
      return TapButton(
        label: 'R',
        isTapped: _rightTapped,
        isInvalid: _gameState.invalidTapSide == TapSide.right,
        isActive: isActive,
        size: buttonSize,
        effectLevel: _gameState.effectLevel,
      );
    } else {
      return TapButton(
        label: 'TAP',
        isTapped: _centerTapped,
        isActive: isActive,
        size: buttonSize,
        effectLevel: _gameState.effectLevel,
      );
    }
  }

  /// ヘッダー: モード名と戻るボタン
  Widget _buildHeader(BuildContext context) {
    final modeName = widget.fingerMode == 2 ? '2 Fingers' : '1 Finger';
    final gameMode = widget.isTimeAttack ? 'Time Attack 100 taps' : 'Tap Challenge 10 sec';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gameMode,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                modeName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 中央エリア: フェーズに応じた表示切り替え
  ///
  /// onYourMark と set は 'preparation' という同じキーでグループ化し、
  /// 外側のスケールアニメーションを起こさない。
  /// 代わりに内部で穏やかなフェードのみで切り替える。
  Widget _buildCenterArea(BuildContext context) {
    String outerKey;
    Widget child;

    switch (_gameState.phase) {
      case GamePhase.ready:
        outerKey = 'ready';
        child = _buildReadyView(context);
      case GamePhase.onYourMark:
      case GamePhase.set:
        outerKey = 'preparation';
        child = _buildPreparationView(context);
      case GamePhase.playing:
        outerKey = 'playing';
        child = _buildPlayingView(context);
      case GamePhase.finished:
        outerKey = 'finished';
        child = _buildFinishedView(context);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(outerKey),
        child: child,
      ),
    );
  }

  /// "Ready" / 無音待機フェーズ
  ///
  /// "Ready" 表示後テキストが消え、ランダム待機後 "Go!" が出る。
  Widget _buildPreparationView(BuildContext context) {
    final isReady = _gameState.phase == GamePhase.onYourMark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Center(
        key: ValueKey(isReady),
        child: isReady
            ? Text(
                'Ready',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// スタートボタン表示
  Widget _buildReadyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '準備はいい？',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            key: _startButtonKey,
            width: 200,
            height: 60,
            child: ElevatedButton(
              onPressed: _gameState.startSequence,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }

  /// プレイ中の表示
  Widget _buildPlayingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // フライング警告
          if (_gameState.hadFalseStart) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _gameState.isInPenalty
                        ? (widget.isTimeAttack
                            ? 'False Start! Penalty: ${_gameState.penaltyTapsRemaining} taps left'
                            : 'False Start! Penalty: ${_gameState.penaltyRemainingSeconds.toStringAsFixed(1)}s left')
                        : 'False Start! (penalty applied)',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // "Go!!" 表示（開始直後）: バウンスで登場
          if (_gameState.elapsedMilliseconds < 800)
            AnimatedBuilder(
              animation: _goScaleAnim,
              builder: (context, child) => Transform.scale(
                scale: _goScaleAnim.value,
                child: child,
              ),
              child: Text(
                'Go!!',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 64,
                    ),
              ),
            )
          else
            Text(
              'プレイ中',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          const SizedBox(height: 24),
          // メイン数値
          _buildMainValue(context),
          const SizedBox(height: 8),
          // サブ情報
          _buildSubInfo(context),
        ],
      ),
    );
  }

  /// 完了画面（リザルト画面への遷移待ち）
  Widget _buildFinishedView(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildMainValue(BuildContext context) {
    String value;
    String label;

    if (widget.isTimeAttack) {
      value = _gameState.elapsedFormatted;
      label = '秒';
    } else {
      value = _gameState.tapCount.toString();
      label = '回';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 72,
                color: _gameState.isInPenalty ? Colors.red.withValues(alpha: 0.5) : null,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget _buildSubInfo(BuildContext context) {
    if (widget.isTimeAttack) {
      return Text(
        '${_gameState.tapCount} / ${GameState.timeAttackTarget} タップ',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
      );
    } else {
      return Text(
        _gameState.phase == GamePhase.finished
            ? '10.00 秒経過'
            : '残り ${_gameState.remainingFormatted} 秒',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _gameState.remainingSeconds < 3.0 && _gameState.phase == GamePhase.playing
                  ? Colors.red
                  : Colors.grey,
            ),
      );
    }
  }
}
