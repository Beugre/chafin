import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_badge_provider.dart';
import '../../services/notification_badge_service.dart';
import '../../widgets/notification_badge.dart';

/// Écran de gestion des notifications et des badges
class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends State<NotificationManagementScreen> {
  Map<String, dynamic>? _statistics;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final provider = Provider.of<NotificationBadgeProvider>(
        context,
        listen: false,
      );
      final stats = await provider.getBadgeStatistics();

      setState(() {
        _statistics = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des statistiques: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Consumer<NotificationBadgeProvider>(
        builder: (context, badgeProvider, child) {
          if (badgeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewSection(badgeProvider),
                const SizedBox(height: 24),
                _buildBadgeTypesSection(badgeProvider),
                const SizedBox(height: 24),
                _buildActionsSection(badgeProvider),
                const SizedBox(height: 24),
                _buildStatisticsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewSection(NotificationBadgeProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.indigo,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Vue d\'ensemble',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                NotificationBadge(
                  count: provider.totalBadgeCount,
                  badgeColor: Colors.red,
                  child: const Icon(Icons.notifications, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    'Total',
                    provider.totalBadgeCount.toString(),
                    Icons.notifications,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Statut',
                    provider.hasAnyBadge
                        ? '${provider.badgeCounts.values.where((count) => count > 0).length} types actifs'
                        : 'Aucune notification',
                    provider.hasAnyBadge ? Icons.circle : Icons.check_circle,
                    provider.hasAnyBadge ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTypesSection(NotificationBadgeProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Types de notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...BadgeType.values.where((type) => type != BadgeType.all).map((
              type,
            ) {
              final count = provider.getBadgeCount(type);
              return _buildBadgeTypeRow(provider, type, count);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTypeRow(
    NotificationBadgeProvider provider,
    BadgeType type,
    int count,
  ) {
    final label = NotificationBadgeService.getBadgeLabel(type);
    final hasNotifications = count > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          NotificationBadge(
            count: count,
            showZero: false,
            child: Icon(
              _getBadgeTypeIcon(type),
              color: hasNotifications ? Colors.indigo : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: hasNotifications ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
          if (hasNotifications)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _clearSpecificBadge(provider, type),
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Marquer comme lu',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _getBadgeTypeIcon(BadgeType type) {
    switch (type) {
      case BadgeType.loanRequests:
        return Icons.request_quote;
      case BadgeType.paymentReminders:
        return Icons.payment;
      case BadgeType.messages:
        return Icons.message;
      case BadgeType.systemNotices:
        return Icons.info;
      case BadgeType.all:
        return Icons.notifications_active;
    }
  }

  Widget _buildActionsSection(NotificationBadgeProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.hasAnyBadge
                        ? () => _clearAllBadges(provider)
                        : null,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Tout marquer comme lu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _refreshBadges(provider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoadingStats)
              const Center(child: CircularProgressIndicator())
            else if (_statistics != null)
              _buildStatisticsContent(_statistics!)
            else
              const Text(
                'Aucune statistique disponible',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsContent(Map<String, dynamic> stats) {
    final typesWithBadges = stats['types_with_badges'] as List<dynamic>;
    final lastUpdated = stats['last_updated'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(
          'Total des notifications',
          '${stats['total_notifications']}',
        ),
        _buildStatRow('Types actifs', '${typesWithBadges.length}'),
        _buildStatRow(
          'Statut',
          stats['has_unread'] ? 'Non lues présentes' : 'Toutes lues',
        ),
        _buildStatRow('Dernière mise à jour', _formatDateTime(lastUpdated)),
        if (typesWithBadges.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Types avec notifications:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: typesWithBadges.map((type) {
              return Chip(
                label: Text(type.toString()),
                backgroundColor: Colors.indigo.withOpacity(0.1),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else {
        return 'Il y a ${difference.inDays} jour(s)';
      }
    } catch (e) {
      return 'Inconnu';
    }
  }

  Future<void> _clearSpecificBadge(
    NotificationBadgeProvider provider,
    BadgeType type,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(
          'Marquer toutes les notifications "${NotificationBadgeService.getBadgeLabel(type)}" comme lues ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await provider.clearBadge(type);
      _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notifications "${NotificationBadgeService.getBadgeLabel(type)}" marquées comme lues',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearAllBadges(NotificationBadgeProvider provider) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Marquer toutes les notifications comme lues ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await provider.clearAllBadges();
      _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Toutes les notifications ont été marquées comme lues',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _refreshBadges(NotificationBadgeProvider provider) async {
    await _loadStatistics();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Badges actualisés'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
}
