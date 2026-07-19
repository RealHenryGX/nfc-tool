import 'package:flutter/material.dart';

/// Soft concentric pulse behind an NFC / sensor icon.
class RadarPulse extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final bool active;

  const RadarPulse({
    super.key,
    this.icon = Icons.nfc,
    this.size = 72,
    this.color,
    this.active = true,
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant RadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final diameter = widget.size * 2.4;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _ring(
                  color: color,
                  progress: ((_c.value + i / 3) % 1.0),
                  maxSize: diameter,
                ),
              child!,
            ],
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Icon(widget.icon, size: widget.size * 0.48, color: color),
        ),
      ),
    );
  }

  Widget _ring({
    required Color color,
    required double progress,
    required double maxSize,
  }) {
    final size = widget.size + (maxSize - widget.size) * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.45;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 2),
      ),
    );
  }
}
