import 'package:flutter/material.dart';

/// Instant tap target — no scale animation (snappy response).
class PressableScale extends StatelessWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.96,
    this.hapticOnTap = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// Ignored — kept for API compatibility with older call sites.
  final double scale;

  /// Ignored — haptics disabled by default for fastest response.
  final bool hapticOnTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: enabled ? onTap : null,
      child: child,
    );
  }
}
