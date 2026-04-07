import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/app_notification_service.dart';
import '../services/debug_service.dart';
import '../providers/auth_provider.dart';

/// Écran d'affichage des notifications
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Veuillez vous connecter pour voir vos notifications'),
        ),
      );
    }

    // Debug: Afficher l'ID utilisateur
    print('🔍 [NOTIF SCREEN] ID utilisateur connecté: ${currentUser.id}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Marquer tout comme lu',
            onPressed: () {
              _markAllAsRead(currentUser.id);
            },
          ),
          // Bouton de nettoyage pour les admins ou en mode debug
          if (authProvider.isAdmin ||
              authProvider.currentUser?.email == 'admin@chafin.com')
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clear_test':
                    _clearTestNotifications();
                    break;
                  case 'clear_user':
                    _clearUserNotifications(currentUser.id);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_test',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, size: 16),
                      SizedBox(width: 8),
                      Text('Nettoyer notifications test'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_user',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 16),
                      SizedBox(width: 8),
                      Text('Vider mes notifications'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: AppNotificationService.getUserNotifications(currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vous recevrez ici toutes vos notifications importantes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationTile(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    final isUnread = !notification.isRead;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isUnread ? 2 : 0,
      color: isUnread ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(notification.type),
          child: Text(
            notification.type.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'read':
                _markAsRead(notification);
                break;
              case 'delete':
                _deleteNotification(notification);
                break;
            }
          },
          itemBuilder: (context) => [
            if (isUnread)
              const PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 16),
                    SizedBox(width: 8),
                    Text('Marquer comme lu'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (isUnread) {
            _markAsRead(notification);
          }
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    final colorHex = type.colorHex;
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _markAsRead(NotificationModel notification) {
    AppNotificationService.markNotificationAsRead(notification.id);
  }

  void _markAllAsRead(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer tout comme lu'),
        content: const Text(
          'Voulez-vous marquer toutes vos notifications comme lues ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppNotificationService.markAllNotificationsAsRead(userId);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _deleteNotification(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la notification'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette notification ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              AppNotificationService.deleteNotification(notification.id);
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Navigation selon le type de notification
    switch (notification.type) {
      case NotificationType.loanRequested:
      case NotificationType.loanApproved:
      case NotificationType.loanRejected:
      case NotificationType.loanCompleted:
        if (notification.data?['loanId'] != null) {
          // Navigator.pushNamed(context, '/loan-details', arguments: notification.data?['loanId']);
          _showLoanDetails(notification.data?['loanId']);
        }
        break;
      case NotificationType.paymentDue:
      case NotificationType.paymentOverdue:
        if (notification.data?['loanId'] != null) {
          // Navigator.pushNamed(context, '/payment', arguments: notification.data?['loanId']);
          _showPaymentInfo(notification.data?['loanId']);
        }
        break;
      default:
        // Notification générale, pas d'action spécifique
        break;
    }
  }

  void _showLoanDetails(String loanId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Affichage des détails du prêt $loanId'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _showPaymentInfo(String loanId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Informations de paiement pour le prêt $loanId'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  /// Nettoie toutes les notifications de test
  Future<void> _clearTestNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les notifications de test'),
        content: const Text(
          'Cette action supprimera toutes les notifications de test/démo de tous les utilisateurs. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Afficher un indicateur de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Nettoyage en cours...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );

        await DebugService.clearAllTestNotifications();

        // Fermer le snackbar de chargement
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notifications de test supprimées'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Nettoie toutes les notifications de l'utilisateur actuel
  Future<void> _clearUserNotifications(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider mes notifications'),
        content: const Text(
          'Cette action supprimera toutes vos notifications. Cette action est irréversible. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Suppression en cours...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );

        await DebugService.clearUserNotifications(userId);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Toutes vos notifications ont été supprimées'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
