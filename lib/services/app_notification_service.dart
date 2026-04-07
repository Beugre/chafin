import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Service de gestion des notifications dans l'application
class AppNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _notificationsCollection = 'notifications';

  /// Crée une nouvelle notification dans Firestore
  static Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: _firestore.collection(_notificationsCollection).doc().id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        data: data,
      );

      await _firestore
          .collection(_notificationsCollection)
          .doc(notification.id)
          .set({
            'id': notification.id,
            'userId': notification.userId,
            'title': notification.title,
            'body': notification.body,
            'type': _getTypeValue(notification.type),
            'createdAt': Timestamp.fromDate(notification.createdAt),
            'isRead': notification.isRead,
            'data': notification.data,
          });

      debugPrint('Notification créée: ${notification.id}');
    } catch (e) {
      debugPrint('Erreur création notification: $e');
    }
  }

  /// Récupère les notifications d'un utilisateur
  static Stream<List<NotificationModel>> getUserNotifications(String userId) {
    print('🔍 [NOTIF DEBUG] Recherche notifications pour userId: $userId');
    return _firestore
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          print(
            '🔍 [NOTIF DEBUG] Notifications trouvées: ${snapshot.docs.length}',
          );
          for (var doc in snapshot.docs) {
            final data = doc.data();
            print(
              '🔍 [NOTIF DEBUG] Notification: ${data['title']} pour userId: ${data['userId']}',
            );
          }
          // Convertir les documents en modèles et trier côté client
          final notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return NotificationModel(
              id: data['id'] ?? doc.id,
              userId: data['userId'] ?? '',
              title: data['title'] ?? '',
              body: data['body'] ?? '',
              type: _parseNotificationType(data['type']),
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isRead: data['isRead'] ?? false,
              data: data['data'] != null
                  ? Map<String, dynamic>.from(data['data'])
                  : null,
            );
          }).toList();

          // Trier par date de création (plus récent en premier)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  /// Convertit un type de notification en sa valeur string pour Firestore
  static String _getTypeValue(NotificationType type) {
    switch (type) {
      case NotificationType.loanRequested:
        return 'loanRequested';
      case NotificationType.loanApproved:
        return 'loanApproved';
      case NotificationType.loanRejected:
        return 'loanRejected';
      case NotificationType.paymentDue:
        return 'paymentDue';
      case NotificationType.paymentOverdue:
        return 'paymentOverdue';
      case NotificationType.paymentReceived:
        return 'paymentReceived';
      case NotificationType.loanCompleted:
        return 'loanCompleted';
      case NotificationType.system:
        return 'system';
      case NotificationType.general:
        return 'general';
      case NotificationType.rateChange:
        return 'rateChange';
    }
  }

  /// Parse le type de notification depuis une string
  static NotificationType _parseNotificationType(String? typeString) {
    switch (typeString) {
      case 'loanRequested':
        return NotificationType.loanRequested;
      case 'loanApproved':
        return NotificationType.loanApproved;
      case 'loanRejected':
        return NotificationType.loanRejected;
      case 'paymentDue':
        return NotificationType.paymentDue;
      case 'paymentOverdue':
        return NotificationType.paymentOverdue;
      case 'paymentReceived':
        return NotificationType.paymentReceived;
      case 'loanCompleted':
        return NotificationType.loanCompleted;
      case 'system':
        return NotificationType.system;
      case 'general':
        return NotificationType.general;
      case 'rateChange':
        return NotificationType.rateChange;
      default:
        return NotificationType.general;
    }
  }

  /// Marque une notification comme lue
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});

      debugPrint('Notification marquée comme lue: $notificationId');
    } catch (e) {
      debugPrint('Erreur marquer notification comme lue: $e');
    }
  }

  /// Marque toutes les notifications d'un utilisateur comme lues
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection(_notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('Toutes les notifications marquées comme lues pour $userId');
    } catch (e) {
      debugPrint('Erreur marquer toutes notifications comme lues: $e');
    }
  }

  /// Supprime une notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();

      debugPrint('Notification supprimée: $notificationId');
    } catch (e) {
      debugPrint('Erreur suppression notification: $e');
    }
  }

  /// Compte les notifications non lues
  static Stream<int> getUnreadNotificationsCount(String userId) {
    return _firestore
        .collection(_notificationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Envoie une notification complète (push + email + stockage)
  static Future<void> sendCompleteNotification({
    required String userId,
    required String userEmail,
    required String userName,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? userFcmToken,
  }) async {
    // 1. Créer la notification dans Firestore
    await createNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
    );

    // 2. Envoyer la notification push si on a le token
    if (userFcmToken != null) {
      await NotificationService.sendNotificationToUser(
        userToken: userFcmToken,
        title: title,
        body: body,
        data: data,
      );
    }

    // ⚠️ PAS d'envoi d'email ici.
    // TOUS les emails sont gérés par Cloud Functions (dailyPaymentReminders)
    // ou directement par EmailService dans loan_service.dart / admin_service.dart
    // pour les événements de cycle de vie (approbation, rejet, décaissement, etc.)
  }

  /// Fonctions spécialisées pour les différents types de notifications

  /// Notification de nouvelle demande de prêt
  static Future<void> notifyLoanRequested({
    required String userId,
    required String userEmail,
    required String userName,
    required String loanId,
    required double amount,
    required int duration,
    required double rate,
    String? userFcmToken,
  }) async {
    await sendCompleteNotification(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      title: 'Demande de prêt soumise',
      body:
          'Votre demande de ${amount.toStringAsFixed(0)}€ est en cours de traitement',
      type: NotificationType.loanRequested,
      data: {
        'loanId': loanId,
        'amount': amount,
        'duration': duration,
        'rate': rate,
      },
      userFcmToken: userFcmToken,
    );
  }

  /// Notification d'approbation de prêt
  static Future<void> notifyLoanApproved({
    required String userId,
    required String userEmail,
    required String userName,
    required String loanId,
    required double amount,
    required int duration,
    required double rate,
    required String firstPaymentDate,
    String? userFcmToken,
  }) async {
    await sendCompleteNotification(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      title: 'Prêt approuvé !',
      body:
          'Félicitations ! Votre prêt de ${amount.toStringAsFixed(0)}€ a été approuvé',
      type: NotificationType.loanApproved,
      data: {
        'loanId': loanId,
        'amount': amount,
        'duration': duration,
        'rate': rate,
        'firstPayment': firstPaymentDate,
      },
      userFcmToken: userFcmToken,
    );
  }

  /// Notification de rejet de prêt
  static Future<void> notifyLoanRejected({
    required String userId,
    required String userEmail,
    required String userName,
    required String loanId,
    required String reason,
    String? userFcmToken,
  }) async {
    await sendCompleteNotification(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      title: 'Demande de prêt refusée',
      body: 'Votre demande de prêt n\'a pas pu être approuvée',
      type: NotificationType.loanRejected,
      data: {'loanId': loanId, 'reason': reason},
      userFcmToken: userFcmToken,
    );
  }

  // ⚠️ notifyPaymentDue et notifyPaymentOverdue ont été SUPPRIMÉS.
  // Les rappels d'échéance et retard sont gérés EXCLUSIVEMENT par
  // Cloud Functions (dailyPaymentReminders cron à 9h Europe/Paris).

  /// Notification de fin de prêt
  static Future<void> notifyLoanCompleted({
    required String userId,
    required String userEmail,
    required String userName,
    required String loanId,
    required double totalAmount,
    required String completionDate,
    required int duration,
    String? userFcmToken,
  }) async {
    await sendCompleteNotification(
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      title: 'Prêt remboursé !',
      body: 'Félicitations ! Votre prêt a été entièrement remboursé',
      type: NotificationType.loanCompleted,
      data: {
        'loanId': loanId,
        'totalAmount': totalAmount,
        'completionDate': completionDate,
        'duration': duration,
      },
      userFcmToken: userFcmToken,
    );
  }
}
