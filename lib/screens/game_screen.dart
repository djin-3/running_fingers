import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/record_data.dart';
import '../widgets/tap_button.dart';
import 'result_screen.dart';

/// ゲーム画面
///
/// - スタート合図シーケンス（"On your mark" → "Set" → "Go!!"）
/// - フライング検出とペナルティ表示
/// - 2本モード: 左右ボタン配置、交互タップ検出
/// - 1本モード: 中央ボタン配置、連打検出
/// - タイマー/カウンター表示
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState _gameState;
  bool _leftTapped = false;
  bool _rightTapped = false;
  bool _centerTapped = false;

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
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});

    // "Go!!" バウンスをゲーム開始時に一度だけ起動
    if (_gameState.phase == GamePhase.playing && !_goAnimTriggered) {
      _goAnimTriggered = true;
      _goAnimController.forward(from: 0);
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

    if (_gameState.phase == GamePhase.finished && !_navigatedToResult) {
      _navigatedToResult = true;
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
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    _goAnimController.dispose();
    _setPulseController.dispose();
    super.dispose();
  }

  void _handleTap({TapSide? side}) {
    final isValid = _gameState.handleTap(side: side);
    if (isValid) {
      HapticFeedback.lightImpact();
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
    _gameState.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildCenterArea(context)),
            _buildTapArea(context),
          ],
        ),
      ),
    );
  }

  /// ヘッダー: モード名と戻るボタン
  Widget _buildHeader(BuildContext context) {
    final modeName = widget.fingerMode == 2 ? '2本モード' : '1本モード';
    final gameMode = widget.isTimeAttack ? 'タイムアタック 100回' : 'タップチャレンジ 10秒';

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

  /// "On your mark" / "Set" 準備フェーズ
  ///
  /// フェードのみで穏やかに切り替え（スケールなし）。
  Widget _buildPreparationView(BuildContext context) {
    final isOnYourMark = _gameState.phase == GamePhase.onYourMark;
    final text = isOnYourMark ? 'On your mark' : 'Set';
    final color = isOnYourMark ? Colors.amber : Colors.orange;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        // フェードのみ: スケールなしで穏やかに切り替え
        return FadeTransition(opacity: animation, child: child);
      },
      child: Center(
        key: ValueKey(text),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // "Set" はパルスで緊張感、"On your mark" は静的表示
            if (!isOnYourMark)
              AnimatedBuilder(
                animation: _setPulseAnim,
                builder: (context, child) => Transform.scale(
                  scale: _setPulseAnim.value,
                  child: child,
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              )
            else
              Text(
                text,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
          ],
        ),
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
              child: const Text('スタート'),
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
                        ? 'フライング！ペナルティ中 ${_gameState.penaltyRemainingSeconds.toStringAsFixed(1)}秒'
                        : 'フライング！ペナルティ適用済み',
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

  /// タップエリア: ボタン配置
  Widget _buildTapArea(BuildContext context) {
    // スタートシーケンス中とプレイ中のみタップ受付
    final isTappable = _gameState.phase == GamePhase.set ||
        _gameState.phase == GamePhase.playing;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: widget.fingerMode == 2
          ? _buildTwoFingerLayout(isTappable)
          : _buildOneFingerLayout(isTappable),
    );
  }

  /// タップがボタン中心から有効半径内かどうか判定
  bool _isWithinTapRadius(Offset tapPosition, Offset center, double buttonSize) {
    // ボタン半径 + 20px の余裕
    final tapRadius = buttonSize / 2 + 20;
    return (tapPosition - center).distance <= tapRadius;
  }

  /// 2本モード: 左右ボタン配置
  Widget _buildTwoFingerLayout(bool isActive) {
    const buttonSize = 80.0;

    return Row(
      children: [
        // 左半分
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: isActive ? (details) {
                  if (_isWithinTapRadius(details.localPosition, center, buttonSize)) {
                    setState(() => _leftTapped = true);
                    _handleTap(side: TapSide.left);
                  }
                } : null,
                onTapUp: isActive ? (_) {
                  setState(() => _leftTapped = false);
                } : null,
                onTapCancel: isActive ? () {
                  setState(() => _leftTapped = false);
                } : null,
                child: Center(
                  child: TapButton(
                    label: 'L',
                    isTapped: _leftTapped,
                    isInvalid: _gameState.invalidTapSide == TapSide.left,
                    isActive: isActive,
                    tapSpeed: _gameState.tapSpeed,
                  ),
                ),
              );
            },
          ),
        ),
        // 区切り線
        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        // 右半分
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: isActive ? (details) {
                  if (_isWithinTapRadius(details.localPosition, center, buttonSize)) {
                    setState(() => _rightTapped = true);
                    _handleTap(side: TapSide.right);
                  }
                } : null,
                onTapUp: isActive ? (_) {
                  setState(() => _rightTapped = false);
                } : null,
                onTapCancel: isActive ? () {
                  setState(() => _rightTapped = false);
                } : null,
                child: Center(
                  child: TapButton(
                    label: 'R',
                    isTapped: _rightTapped,
                    isInvalid: _gameState.invalidTapSide == TapSide.right,
                    isActive: isActive,
                    tapSpeed: _gameState.tapSpeed,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 1本モード: 中央ボタン配置
  Widget _buildOneFingerLayout(bool isActive) {
    const buttonSize = 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: isActive ? (details) {
            if (_isWithinTapRadius(details.localPosition, center, buttonSize)) {
              setState(() => _centerTapped = true);
              _handleTap();
            }
          } : null,
          onTapUp: isActive ? (_) {
            setState(() => _centerTapped = false);
          } : null,
          onTapCancel: isActive ? () {
            setState(() => _centerTapped = false);
          } : null,
          child: Center(
            child: TapButton(
              label: 'TAP',
              isTapped: _centerTapped,
              isActive: isActive,
              size: buttonSize,
              tapSpeed: _gameState.tapSpeed,
            ),
          ),
        );
      },
    );
  }
}

