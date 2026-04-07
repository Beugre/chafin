import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_badge_provider.dart';
import '../services/notification_badge_service.dart';
import '../widgets/notification_badge.dart';

/// Widget pour intégrer les badges dans la navigation principale
class AdminNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final BadgeType? badgeType;
  final bool isActive;

  const AdminNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.badgeType,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      icon,
      color: isActive ? Colors.indigo : Colors.grey,
      size: 24,
    );

    // Ajouter un badge si un type est spécifié
    if (badgeType != null) {
      iconWidget = Consumer<NotificationBadgeProvider>(
        builder: (context, badgeProvider, child) {
          final count = badgeProvider.getBadgeCount(badgeType!);
          return NavigationBadge(count: count, child: iconWidget);
        },
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.indigo : Colors.grey.shade700,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour la barre d'application avec badge total
class AdminAppBarWithBadge extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showTotalBadge;

  const AdminAppBarWithBadge({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showTotalBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [];

    if (showTotalBadge) {
      appBarActions.add(
        Consumer<NotificationBadgeProvider>(
          builder: (context, badgeProvider, child) {
            return NotificationBadge(
              count: badgeProvider.totalBadgeCount,
              child: IconButton(
                onPressed: () {
                  // Navigation vers l'écran de gestion des notifications
                  Navigator.pushNamed(context, '/admin/notifications');
                },
                icon: const Icon(Icons.notifications),
                tooltip: 'Notifications',
              ),
            );
          },
        ),
      );
    }

    if (actions != null) {
      appBarActions.addAll(actions!);
    }

    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: leading,
      actions: appBarActions.isNotEmpty ? appBarActions : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Widget pour afficher un résumé des badges
class BadgesSummaryCard extends StatelessWidget {
  const BadgesSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationBadgeProvider>(
      builder: (context, badgeProvider, child) {
        if (badgeProvider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (!badgeProvider.hasAnyBadge) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text(
                    'Aucune notification en attente',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NotificationBadge(
                      count: badgeProvider.totalBadgeCount,
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${badgeProvider.totalBadgeCount} notification(s) en attente',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: BadgeType.values
                      .where((type) => type != BadgeType.all)
                      .where((type) => badgeProvider.hasBadge(type))
                      .map((type) {
                        final count = badgeProvider.getBadgeCount(type);
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: Text(
                            NotificationBadgeService.getBadgeLabel(type),
                          ),
                          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
