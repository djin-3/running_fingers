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

  const TapButton({
    super.key,
    required this.label,
    this.isTapped = false,
    this.isInvalid = false,
    this.isActive = true,
    this.size = 80,
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

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isInvalid
        ? Colors.red.shade700
        : widget.isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade700;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shakeController, _rippleController]),
      builder: (context, _) {
        // 減衰する横揺れ: 時間が経つにつれて振幅が小さくなる
        final t = _shakeController.value;
        final shakeOffset = math.sin(t * math.pi * 5) * 10 * (1 - t);

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
                      width: widget.size * _rippleRadius.value,
                      height: widget.size * _rippleRadius.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withValues(alpha: _rippleOpacity.value),
                          width: 2.5,
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
                        color: widget.isInvalid
                            ? Colors.red
                            : Colors.white.withValues(alpha: 0.3),
                        width: widget.isInvalid ? 3 : 2,
                      ),
                      boxShadow: [
                        if (widget.isTapped)
                          BoxShadow(
                            color: baseColor.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 4,
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
