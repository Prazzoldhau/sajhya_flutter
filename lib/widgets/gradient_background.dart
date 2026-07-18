import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The shared soft-blue page background used across the app.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool safeArea;

  const GradientBackground({
    super.key,
    required this.child,
    this.padding,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: safeArea ? SafeArea(child: content) : content,
    );
  }
}
