import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Replacement for deprecated `withOpacity` to avoid precision loss.
  ///
  /// Usage: `color.withAlphaValue(0.3)` — returns the same color with adjusted alpha.
  Color withAlphaValue(double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return withAlpha(a);
  }
}
