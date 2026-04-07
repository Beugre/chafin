import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/notification_badge_service.dart';

/// Provider pour gérer l'état des badges de notification
class NotificationBadgeProvider extends ChangeNotifier {
  final String userId;
  StreamSubscription<Map<BadgeType, int>>? _badgeSubscription;

  Map<BadgeType, int> _badgeCounts = {};
  bool _isLoading = true;

  NotificationBadgeProvider({required this.userId}) {
    _initializeBadges();
  }

  /// Getters pour accéder aux compteurs
  Map<BadgeType, int> get badgeCounts => Map.unmodifiable(_badgeCounts);
  bool get isLoading => _isLoading;

  /// Obtenir le compteur pour un type spécifique
  int getBadgeCount(BadgeType type) {
    return _badgeCounts[type] ?? 0;
  }

  /// Obtenir le compteur total
  int get totalBadgeCount => getBadgeCount(BadgeType.all);

  /// Vérifier si un type a des notifications non lues
  bool hasBadge(BadgeType type) => getBadgeCount(type) > 0;

  /// Vérifier s'il y a des notifications non lues
  bool get hasAnyBadge => totalBadgeCount > 0;

  /// Initialiser les badges et écouter les changements
  void _initializeBadges() {
    // Écouter les changements en temps réel
    _badgeSubscription = NotificationBadgeService.getBadgeCountsStream(userId)
        .listen(
          (counts) {
            _badgeCounts = counts;
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Erreur lors de l\'écoute des badges: $error');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Ajouter une notification (incrémente le badge)
  Future<void> addNotification(BadgeType type) async {
    try {
      await NotificationBadgeService.addNotification(userId, type);
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout de notification: $e');
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(BadgeType type) async {
    try {
      await NotificationBadgeService.markNotificationAsRead(userId, type);
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marquer plusieurs notifications comme lues
  Future<void> markMultipleAsRead(BadgeType type, int count) async {
    try {
      await NotificationBadgeService.markMultipleNotificationsAsRead(
        userId,
        type,
        count,
      );
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors du marquage multiple comme lu: $e');
    }
  }

  /// Réinitialiser un badge
  Future<void> clearBadge(BadgeType type) async {
    try {
      await NotificationBadgeService.clearBadge(userId, type);
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du badge: $e');
    }
  }

  /// Incrémenter manuellement un badge (pour tests ou cas spéciaux)
  Future<void> incrementBadge(BadgeType type, {int increment = 1}) async {
    try {
      await NotificationBadgeService.incrementBadge(
        userId,
        type,
        increment: increment,
      );
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors de l\'incrémentation du badge: $e');
    }
  }

  /// Décrémenter manuellement un badge
  Future<void> decrementBadge(BadgeType type, {int decrement = 1}) async {
    try {
      await NotificationBadgeService.decrementBadge(
        userId,
        type,
        decrement: decrement,
      );
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors de la décrémentation du badge: $e');
    }
  }

  /// Obtenir les statistiques détaillées des badges
  Future<Map<String, dynamic>> getBadgeStatistics() async {
    return {
      'current_counts': _badgeCounts,
      'total_notifications': totalBadgeCount,
      'has_unread': hasAnyBadge,
      'last_updated': DateTime.now().toIso8601String(),
      'user_id': userId,
      'types_with_badges': _badgeCounts.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key.name)
          .toList(),
    };
  }

  /// Réinitialiser tous les badges
  Future<void> clearAllBadges() async {
    try {
      await NotificationBadgeService.clearBadge(userId, BadgeType.all);
      // Le stream se chargera automatiquement de la mise à jour
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation de tous les badges: $e');
    }
  }

  @override
  void dispose() {
    _badgeSubscription?.cancel();
    super.dispose();
  }
}
