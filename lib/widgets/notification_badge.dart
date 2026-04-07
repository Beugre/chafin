import 'package:flutter/material.dart';

/// Widget pour afficher un badge de notification avec un compteur
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;
  final Color? textColor;
  final double? fontSize;
  final bool showZero;
  final double? right;
  final double? top;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
    this.textColor,
    this.fontSize,
    this.showZero = false,
    this.right,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0 || showZero)
          Positioned(
            right: right ?? 0,
            top: top ?? 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _formatCount(count),
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: fontSize ?? 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 100) {
      return count.toString();
    } else if (count < 1000) {
      return '99+';
    } else {
      return '1k+';
    }
  }
}

/// Widget spécialisé pour les badges de navigation
class NavigationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color? badgeColor;

  const NavigationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationBadge(
      count: count,
      badgeColor: badgeColor ?? Colors.red,
      fontSize: 9,
      right: -2,
      top: -2,
      child: child,
    );
  }
}

/// Widget pour afficher un badge avec un point (sans nombre)
class DotBadge extends StatelessWidget {
  final Widget child;
  final bool show;
  final Color? dotColor;
  final double? size;
  final double? right;
  final double? top;

  const DotBadge({
    super.key,
    required this.child,
    required this.show,
    this.dotColor,
    this.size,
    this.right,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (show)
          Positioned(
            right: right ?? 2,
            top: top ?? 2,
            child: Container(
              width: size ?? 8,
              height: size ?? 8,
              decoration: BoxDecoration(
                color: dotColor ?? Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
    );
  }
}
