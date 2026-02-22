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
  final int effectLevel;

  const TapButton({
    super.key,
    required this.label,
    this.isTapped = false,
    this.isInvalid = false,
    this.isActive = true,
    this.size = 80,
    this.effectLevel = 1,
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
  late AnimationController _ripple2Controller;
  late Animation<double> _ripple2Radius;
  late Animation<double> _ripple2Opacity;
  late AnimationController _ripple3Controller;
  late Animation<double> _ripple3Radius;
  late Animation<double> _ripple3Opacity;

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
    _ripple2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ripple2Radius = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _ripple2Controller, curve: Curves.easeOut),
    );
    _ripple2Opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ripple2Controller, curve: Curves.easeOut),
    );
    _ripple3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ripple3Radius = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _ripple3Controller, curve: Curves.easeOut),
    );
    _ripple3Opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ripple3Controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(TapButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTapped && !oldWidget.isTapped) {
      _scaleController.forward();
      // 有効タップのみ波紋を出す
      if (!widget.isInvalid) {
        final duration = Duration(milliseconds: _rippleDurationMs(widget.effectLevel));
        _rippleController.duration = duration;
        _rippleController.forward(from: 0);
        if (widget.effectLevel >= 3) {
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) {
              _ripple2Controller.duration = duration;
              _ripple2Controller.forward(from: 0);
            }
          });
        }
        if (widget.effectLevel >= 4) {
          Future.delayed(const Duration(milliseconds: 160), () {
            if (mounted) {
              _ripple3Controller.duration = duration;
              _ripple3Controller.forward(from: 0);
            }
          });
        }
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
    _ripple2Controller.dispose();
    _ripple3Controller.dispose();
    super.dispose();
  }

  int _rippleDurationMs(int level) {
    switch (level) {
      case 5: return 350;
      case 4: return 400;
      case 3: return 450;
      case 2: return 480;
      default: return 500;
    }
  }

  double _glowBlurRadius(int level) {
    switch (level) {
      case 5: return 40;
      case 4: return 30;
      case 3: return 22;
      case 2: return 14;
      default: return 8;
    }
  }

  double _glowSpreadRadius(int level) {
    if (level >= 5) return 12;
    if (level >= 4) return 8;
    if (level >= 3) return 4;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isInvalid
        ? Colors.red.shade700
        : widget.isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade700;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shakeController, _rippleController, _ripple2Controller, _ripple3Controller]),
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
                  if (_ripple2Controller.isAnimating)
                    Container(
                      width: widget.size * _ripple2Radius.value,
                      height: widget.size * _ripple2Radius.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withValues(alpha: _ripple2Opacity.value),
                          width: 2.5,
                        ),
                      ),
                    ),
                  if (_ripple3Controller.isAnimating)
                    Container(
                      width: widget.size * _ripple3Radius.value,
                      height: widget.size * _ripple3Radius.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withValues(alpha: _ripple3Opacity.value),
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
                      color: widget.isTapped && widget.effectLevel == 5
                          ? Colors.white.withValues(alpha: 0.85)
                          : widget.isTapped
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
                            blurRadius: _glowBlurRadius(widget.effectLevel),
                            spreadRadius: _glowSpreadRadius(widget.effectLevel),
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
