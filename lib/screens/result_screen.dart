import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:confetti/confetti.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/record_data.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

/// リザルト画面
///
/// 今回の記録・ベストとの差分・直近履歴を表示する。
class ResultScreen extends StatefulWidget {
  final RecordData record;
  final bool isTimeAttack;

  const ResultScreen({
    super.key,
    required this.record,
    required this.isTimeAttack,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  RecordData? _best;
  List<RecordData> _history = [];
  bool _isNewBest = false;
  bool _loading = true;

  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;

  late AnimationController _countUpController;
  late Animation<double> _countUpAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late ConfettiController _confettiController;

  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeInOut),
    );

    // 記録表示を0から実際の値までカウントアップ（easeOut で最後に落ち着く）
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _countUpAnimation = Tween<double>(
      begin: 0.0,
      end: widget.record.value,
    ).animate(CurvedAnimation(parent: _countUpController, curve: Curves.easeOut));

    // カードのバウンス登場アニメーション
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));

    // 紙吹雪コントローラー
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _loadData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _countUpController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final best = await StorageService.saveRecord(
      record: widget.record,
      isTimeAttack: widget.isTimeAttack,
    );
    final history = await StorageService.getHistory(
      fingerMode: widget.record.fingerMode,
      isTimeAttack: widget.isTimeAttack,
    );

    if (mounted) {
      setState(() {
        _best = best;
        _history = history;
        _isNewBest = best?.date == widget.record.date;
        _loading = false;
      });
      _countUpController.forward();
      _scaleController.forward();
      if (_isNewBest) {
        _celebrationController.repeat(reverse: true);
        _confettiController.play();
        AudioService().playBest();
      }
    }
  }

  String _formatValue(double value) {
    if (widget.isTimeAttack) {
      return '${value.toStringAsFixed(2)}秒';
    } else {
      return '${value.toInt()}回';
    }
  }

  String _formatDiff(double current, double best) {
    final diff = widget.isTimeAttack ? current - best : current - best;
    final sign = diff > 0 ? '+' : '';
    if (widget.isTimeAttack) {
      return '$sign${diff.toStringAsFixed(2)}秒';
    } else {
      return '$sign${diff.toInt()}回';
    }
  }

  Color _diffColor(double current, double best) {
    // タイムアタック: 差がマイナス（速い）= 良い = 緑
    // タップチャレンジ: 差がプラス（多い）= 良い = 緑
    final isGood = widget.isTimeAttack ? current < best : current > best;
    if (current == best) return Colors.grey;
    return isGood ? Colors.green : Colors.red;
  }

  String _modeName() {
    final finger = widget.record.fingerMode == 2 ? '2 Fingers' : '1 Finger';
    final mode = widget.isTimeAttack ? 'Time Attack' : 'Tap Challenge';
    return '$finger $mode';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                key: _shareKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _modeName(),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: _buildResultCard(context),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Running Fingers',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_history.length > 1) _buildHistorySection(context),
                            ],
                          ),
                        ),
                      ),
                      _buildActions(context),
                    ],
                  ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.amber,
              Colors.orange,
              Colors.cyan,
              Colors.green,
              Colors.pink,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_isNewBest)
            const Icon(Icons.emoji_events, color: Colors.amber, size: 28)
          else
            const Icon(Icons.flag, color: Colors.cyan, size: 28),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNewBest ? 'New Record!' : 'Done!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isNewBest ? Colors.amber : Colors.cyan,
                    ),
              ),
              Text(
                _modeName(),
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

  Widget _buildResultCard(BuildContext context) {
    if (_isNewBest) {
      return AnimatedBuilder(
        animation: _celebrationAnimation,
        builder: (context, child) {
          final glow = _celebrationAnimation.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: glow * 0.6),
                  blurRadius: 20 + glow * 10,
                  spreadRadius: 2 + glow * 4,
                ),
              ],
            ),
            child: child,
          );
        },
        child: _buildResultCardInner(context),
      );
    }
    return _buildResultCardInner(context);
  }

  Widget _buildResultCardInner(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 今回の記録
            Text(
              'Result',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _countUpAnimation,
              builder: (context, _) => Text(
                _formatValue(_countUpAnimation.value),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
              ),
            ),
            if (widget.record.hadFalseStart) ...[
              const SizedBox(height: 4),
              Text(
                'False start penalty',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
            ],
            const Divider(height: 32),
            // ベストとの比較
            if (_best != null && !_isNewBest) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Best', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    _formatValue(_best!.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Diff', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    _formatDiff(widget.record.value, _best!.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _diffColor(widget.record.value, _best!.value),
                        ),
                  ),
                ],
              ),
            ] else if (_isNewBest) ...[
              Text(
                'New Record!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...List.generate(_history.length, (i) {
          final rec = _history[i];
          final isCurrent = i == 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatValue(rec.value),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.cyan : null,
                        ),
                  ),
                ),
                if (rec.hadFalseStart)
                  Text(
                    'False Start',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(rec.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _shareResult,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: const Text('シェア'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('もう一度'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('メニュー'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareResult() async {
    setState(() => _sharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/running_fingers_result.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${_modeName()} #RunningFingers',
      );
    } catch (_) {
      // 共有は任意操作のためサイレント失敗
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
