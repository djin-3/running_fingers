import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../widgets/tap_button.dart';

/// ゲーム画面
///
/// Phase 1 プロトタイプ:
/// - 2本モード: 左右ボタン配置、交互タップ検出
/// - 1本モード: 中央ボタン配置、連打検出
/// - タイマー/カウンター表示
/// - 基本的なカウント機能
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
            Expanded(child: _buildInfoDisplay(context)),
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

  /// 情報表示エリア: タイマー、カウンター、ステータス
  Widget _buildInfoDisplay(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ステータス表示
          _buildStatusText(context),
          const SizedBox(height: 24),
          // メイン数値
          _buildMainValue(context),
          const SizedBox(height: 8),
          // サブ情報
          _buildSubInfo(context),
          const SizedBox(height: 24),
          // ゲーム終了時のボタン
          if (_gameState.phase == GamePhase.finished) _buildFinishButtons(context),
        ],
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    String status;
    Color color;

    switch (_gameState.phase) {
      case GamePhase.ready:
        status = 'タップして開始';
        color = Colors.amber;
      case GamePhase.playing:
        status = 'プレイ中';
        color = Colors.green;
      case GamePhase.finished:
        status = '完了！';
        color = Colors.cyan;
    }

    return Text(
      status,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildMainValue(BuildContext context) {
    String value;
    String label;

    if (widget.isTimeAttack) {
      // タイムアタック: 時間を大きく表示
      value = _gameState.elapsedFormatted;
      label = '秒';
    } else {
      // タップチャレンジ: タップ数を大きく表示
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
      // タイムアタック: タップ数 / 100 を表示
      return Text(
        '${_gameState.tapCount} / ${GameState.timeAttackTarget} タップ',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
      );
    } else {
      // タップチャレンジ: 残り時間を表示
      return Text(
        '残り ${_gameState.remainingFormatted} 秒',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _gameState.remainingSeconds < 3.0 ? Colors.red : Colors.grey,
            ),
      );
    }
  }

  Widget _buildFinishButtons(BuildContext context) {
    return Row(
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
    );
  }

  /// タップエリア: ボタン配置
  Widget _buildTapArea(BuildContext context) {
    final isActive = _gameState.phase != GamePhase.finished;

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
          ? _buildTwoFingerLayout(isActive)
          : _buildOneFingerLayout(isActive),
    );
  }

  /// 2本モード: 左右ボタン配置
  Widget _buildTwoFingerLayout(bool isActive) {
    return Row(
      children: [
        // 左半分
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _handleTap(side: TapSide.left),
            child: Center(
              child: TapButton(
                label: 'L',
                onTap: () {}, // GestureDetector が処理
                isInvalid: _gameState.invalidTapSide == TapSide.left,
                isActive: isActive,
              ),
            ),
          ),
        ),
        // 区切り線
        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        // 右半分
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _handleTap(side: TapSide.right),
            child: Center(
              child: TapButton(
                label: 'R',
                onTap: () {},
                isInvalid: _gameState.invalidTapSide == TapSide.right,
                isActive: isActive,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 1本モード: 中央ボタン配置
  Widget _buildOneFingerLayout(bool isActive) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handleTap(),
      child: Center(
        child: TapButton(
          label: 'TAP',
          onTap: () {},
          isActive: isActive,
          size: 100,
        ),
      ),
    );
  }
}
