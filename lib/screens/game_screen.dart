import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../widgets/tap_button.dart';

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

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  bool _leftTapped = false;
  bool _rightTapped = false;
  bool _centerTapped = false;

  @override
  void initState() {
    super.initState();
    _gameState = GameState(
      fingerMode: widget.fingerMode,
      isTimeAttack: widget.isTimeAttack,
    );
    _gameState.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _handleTap({TapSide? side}) {
    _gameState.handleTap(side: side);
  }

  void _resetGame() {
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
  Widget _buildCenterArea(BuildContext context) {
    switch (_gameState.phase) {
      case GamePhase.ready:
        return _buildReadyView(context);
      case GamePhase.onYourMark:
        return _buildStartSequenceView(context, 'On your mark', Colors.amber);
      case GamePhase.set:
        return _buildStartSequenceView(context, 'Set', Colors.orange);
      case GamePhase.playing:
        return _buildPlayingView(context);
      case GamePhase.finished:
        return _buildFinishedView(context);
    }
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

  /// スタート合図シーケンス表示（"On your mark" / "Set"）
  Widget _buildStartSequenceView(BuildContext context, String text, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_gameState.phase == GamePhase.set) ...[
            const SizedBox(height: 16),
            Text(
              '待て...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
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
          // "Go!!" 表示（開始直後）
          if (_gameState.elapsedMilliseconds < 800)
            Text(
              'Go!!',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 64,
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

  /// 完了画面
  Widget _buildFinishedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '完了！',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          _buildMainValue(context),
          const SizedBox(height: 8),
          _buildSubInfo(context),
          // フライング情報
          if (_gameState.hadFalseStart) ...[
            const SizedBox(height: 12),
            Text(
              'フライングペナルティあり',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.replay),
                label: const Text('もう一度'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home),
                label: const Text('メニュー'),
              ),
            ],
          ),
        ],
      ),
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
            ),
          ),
        );
      },
    );
  }
}
