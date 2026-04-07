import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_notification_service.dart';
import '../providers/auth_provider.dart';

/// Widget pour afficher l'icône de notification avec badge
class NotificationIconWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? iconColor;
  final double iconSize;

  const NotificationIconWidget({
    super.key,
    this.onTap,
    this.iconColor,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return IconButton(
        icon: Icon(Icons.notifications, color: iconColor, size: iconSize),
        onPressed: onTap,
      );
    }

    return StreamBuilder<int>(
      stream: AppNotificationService.getUnreadNotificationsCount(
        currentUser.id,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: iconColor, size: iconSize),
              onPressed: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Widget pour afficher un badge de notification simple
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final Color badgeColor;
  final Color textColor;
  final double? right;
  final double? top;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.right,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (count > 0)
          Positioned(
            right: right ?? 0,
            top: top ?? 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
