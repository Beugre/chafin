import 'package:flutter/foundation.dart';
import '../services/notification_badge_service.dart';

/// Utilitaires pour intégrer automatiquement les badges avec les événements système
class BadgeIntegrationHelper {
  /// Ajouter une notification lors d'une nouvelle demande de prêt
  static Future<void> onNewLoanRequest(String adminUserId) async {
    try {
      await NotificationBadgeService.addNotification(
        adminUserId,
        BadgeType.loanRequests,
      );
      debugPrint('Badge ajouté pour nouvelle demande de prêt');
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du badge de demande de prêt: $e');
    }
  }

  /// Ajouter une notification lors d'un rappel de paiement envoyé
  static Future<void> onPaymentReminderSent(String userId) async {
    try {
      await NotificationBadgeService.addNotification(
        userId,
        BadgeType.paymentReminders,
      );
      debugPrint('Badge ajouté pour rappel de paiement');
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du badge de rappel: $e');
    }
  }

  /// Ajouter une notification pour un nouveau message
  static Future<void> onNewMessage(String userId) async {
    try {
      await NotificationBadgeService.addNotification(
        userId,
        BadgeType.messages,
      );
      debugPrint('Badge ajouté pour nouveau message');
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du badge de message: $e');
    }
  }

  /// Ajouter une notification système
  static Future<void> onSystemNotice(String userId) async {
    try {
      await NotificationBadgeService.addNotification(
        userId,
        BadgeType.systemNotices,
      );
      debugPrint('Badge ajouté pour notification système');
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du badge système: $e');
    }
  }

  /// Marquer comme lue lors de la consultation d'une demande de prêt
  static Future<void> onLoanRequestViewed(String adminUserId) async {
    try {
      await NotificationBadgeService.markNotificationAsRead(
        adminUserId,
        BadgeType.loanRequests,
      );
      debugPrint('Badge marqué comme lu pour demande de prêt');
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marquer comme lue lors de la consultation d'un rappel
  static Future<void> onPaymentReminderViewed(String userId) async {
    try {
      await NotificationBadgeService.markNotificationAsRead(
        userId,
        BadgeType.paymentReminders,
      );
      debugPrint('Badge marqué comme lu pour rappel de paiement');
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marquer comme lu lors de la consultation d'un message
  static Future<void> onMessageViewed(String userId) async {
    try {
      await NotificationBadgeService.markNotificationAsRead(
        userId,
        BadgeType.messages,
      );
      debugPrint('Badge marqué comme lu pour message');
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marquer comme lue lors de la consultation d'une notification système
  static Future<void> onSystemNoticeViewed(String userId) async {
    try {
      await NotificationBadgeService.markNotificationAsRead(
        userId,
        BadgeType.systemNotices,
      );
      debugPrint('Badge marqué comme lu pour notification système');
    } catch (e) {
      debugPrint('Erreur lors du marquage comme lu: $e');
    }
  }

  /// Marquer plusieurs notifications comme lues
  static Future<void> markMultipleAsRead(
    String userId,
    BadgeType type,
    int count,
  ) async {
    try {
      await NotificationBadgeService.markMultipleNotificationsAsRead(
        userId,
        type,
        count,
      );
      debugPrint('$count badges marqués comme lus pour $type');
    } catch (e) {
      debugPrint('Erreur lors du marquage multiple: $e');
    }
  }

  /// Réinitialiser tous les badges pour un utilisateur
  static Future<void> clearAllBadgesForUser(String userId) async {
    try {
      await NotificationBadgeService.clearBadge(userId, BadgeType.all);
      debugPrint('Tous les badges réinitialisés pour utilisateur $userId');
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation: $e');
    }
  }

  /// Obtenir le nombre total de notifications pour un utilisateur
  static Future<int> getTotalNotificationsCount(String userId) async {
    try {
      return await NotificationBadgeService.getUnreadCount(
        userId,
        BadgeType.all,
      );
    } catch (e) {
      debugPrint('Erreur lors de la récupération du total: $e');
      return 0;
    }
  }

  /// Vérifier si un utilisateur a des notifications non lues
  static Future<bool> hasUnreadNotifications(String userId) async {
    try {
      final count = await getTotalNotificationsCount(userId);
      return count > 0;
    } catch (e) {
      debugPrint('Erreur lors de la vérification: $e');
      return false;
    }
  }
}
