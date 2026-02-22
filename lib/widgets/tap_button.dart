import 'dart:math' as math;
import 'package:flutter/material.dart';

/// タップボタンウィジェット
///
/// 小さめのタップ範囲で、有効/無効タップの視覚フィードバックを提供する。
/// タップ検出は親ウィジェットが行い、isTappedプロパティで視覚状態を制御する。
class TapButton extends StatefulWidget {
  final String label;
  final bool isTapped;
  final bool isInvalid;
  final bool isActive;
  final double size;
  final double tapSpeed;

  const TapButton({
    super.key,
    required this.label,
    this.isTapped = false,
    this.isInvalid = false,
    this.isActive = true,
    this.size = 80,
    this.tapSpeed = 0.0,
  });

  @override
  State<TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<TapButton> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _shakeController;
  late AnimationController _rippleController;
  late Animation<double> _rippleRadius;
  late Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // 波紋: ボタンの0.5倍から2.0倍に拡大しながらフェードアウト
    _rippleRadius = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(TapButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTapped && !oldWidget.isTapped) {
      _scaleController.forward();
      // 有効タップのみ波紋を出す
      if (!widget.isInvalid) {
        _rippleController.forward(from: 0);
      }
    } else if (!widget.isTapped && oldWidget.isTapped) {
      _scaleController.reverse();
    }
    if (widget.isInvalid && !oldWidget.isInvalid) {
      _scaleController.forward().then((_) => _scaleController.reverse());
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shakeController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  /// タップ速度に応じたレベル（0〜3）
  ///
  /// - Level 0: 4 taps/sec 未満（通常）
  /// - Level 1: 4〜7 taps/sec（少し速い）
  /// - Level 2: 7〜10 taps/sec（かなり速い）
  /// - Level 3: 10 taps/sec 以上（最速）
  int get _speedLevel {
    if (widget.tapSpeed >= 10.0) return 3;
    if (widget.tapSpeed >= 7.0) return 2;
    if (widget.tapSpeed >= 4.0) return 1;
    return 0;
  }

  /// レベルに応じた波紋の最大半径倍率（2.0〜3.5）
  double get _rippleMaxScale => 2.0 + _speedLevel * 0.5;

  /// レベルに応じたグロー強度
  double get _glowIntensity => 0.5 + _speedLevel * 0.2;

  /// レベルに応じたグロー半径
  double get _glowBlurRadius => 20.0 + _speedLevel * 10.0;

  /// レベルに応じたボーダー色（通常: 白30% → 最速: ゴールド）
  Color _borderColor(Color baseColor) {
    if (widget.isInvalid) return Colors.red;
    switch (_speedLevel) {
      case 3:
        return Colors.amber.withValues(alpha: 0.9);
      case 2:
        return Colors.greenAccent.withValues(alpha: 0.7);
      case 1:
        return Colors.lightBlueAccent.withValues(alpha: 0.5);
      default:
        return Colors.white.withValues(alpha: 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isInvalid
        ? Colors.red.shade700
        : widget.isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade700;

    // 波紋の最大倍率をコンボに応じて変化させる
    final rippleMaxScale = _rippleMaxScale;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shakeController, _rippleController]),
      builder: (context, _) {
        // 減衰する横揺れ: 時間が経つにつれて振幅が小さくなる
        final t = _shakeController.value;
        final shakeOffset = math.sin(t * math.pi * 5) * 10 * (1 - t);

        // 波紋半径をコンボレベルに応じてスケール
        final currentRippleScale = 0.5 + (rippleMaxScale - 0.5) * _rippleRadius.value / 2.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 波紋エフェクト（アニメーション中のみ表示）
                  if (_rippleController.isAnimating)
                    Container(
                      width: widget.size * currentRippleScale,
                      height: widget.size * currentRippleScale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _borderColor(baseColor).withValues(alpha: _rippleOpacity.value),
                          width: 2.5 + _speedLevel * 0.5,
                        ),
                      ),
                    ),
                  // ボタン本体
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.isTapped
                          ? baseColor.withValues(alpha: 0.8)
                          : baseColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _borderColor(baseColor),
                        width: widget.isInvalid ? 3 : 2 + _speedLevel * 0.5,
                      ),
                      boxShadow: [
                        if (widget.isTapped)
                          BoxShadow(
                            color: baseColor.withValues(alpha: _glowIntensity),
                            blurRadius: _glowBlurRadius,
                            spreadRadius: 4 + _speedLevel * 2.0,
                          ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
