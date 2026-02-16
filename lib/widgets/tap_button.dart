import 'package:flutter/material.dart';

/// タップボタンウィジェット
///
/// 小さめのタップ範囲で、有効/無効タップの視覚フィードバックを提供する。
class TapButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isInvalid;
  final bool isActive;
  final double size;

  const TapButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isInvalid = false,
    this.isActive = true,
    this.size = 80,
  });

  @override
  State<TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<TapButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(TapButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInvalid && !oldWidget.isInvalid) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isActive) return;
    setState(() => _isTapped = true);
    _animationController.forward();
    widget.onTap();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isTapped = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isTapped = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isInvalid
        ? Colors.red.shade700
        : widget.isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade700;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _isTapped ? baseColor.withValues(alpha: 0.8) : baseColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isInvalid
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.3),
              width: widget.isInvalid ? 3 : 2,
            ),
            boxShadow: [
              if (_isTapped)
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
      ),
    );
  }
}
