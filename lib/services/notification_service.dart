import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service de gestion des notifications push Firebase
class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Initialise le service de notifications
  static Future<void> initialize() async {
    // Demander les permissions pour les notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permissions de notification accordées');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('Permissions de notification provisoires accordées');
    } else {
      debugPrint('Permissions de notification refusées');
    }

    // Obtenir le token FCM
    _fcmToken = await _firebaseMessaging.getToken();
    debugPrint('Token FCM: $_fcmToken');

    // Configurer les handlers de messages
    _setupMessageHandlers();
  }

  /// Configure les handlers pour les différents types de messages
  static void _setupMessageHandlers() {
    // Messages reçus quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'Message reçu au premier plan: ${message.notification?.title}',
      );
      _showLocalNotification(message);
    });

    // Messages reçus quand l'app est en arrière-plan mais pas fermée
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        'Message ouvert depuis l\'arrière-plan: ${message.notification?.title}',
      );
      _handleNotificationTap(message);
    });
  }

  /// Affiche une notification locale quand l'app est au premier plan
  static void _showLocalNotification(RemoteMessage message) {
    // Pour l'instant, on utilise un SnackBar simple
    // Dans une vraie app, on utiliserait flutter_local_notifications
    debugPrint('Affichage notification: ${message.notification?.title}');
  }

  /// Gère le tap sur une notification
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapée: ${message.data}');
    // Navigation vers l'écran approprié selon le type de notification
  }

  /// Obtient le token FCM actuel
  static String? get fcmToken => _fcmToken;

  /// Met à jour le token FCM pour un utilisateur
  static Future<void> updateUserToken(String userId) async {
    if (_fcmToken != null) {
      // Ici on sauvegarderait le token en base pour l'utilisateur
      debugPrint(
        'Token FCM mis à jour pour l\'utilisateur $userId: $_fcmToken',
      );
    }
  }

  /// Envoie une notification à un utilisateur spécifique
  static Future<void> sendNotificationToUser({
    required String userToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Cette fonction nécessiterait un backend ou Cloud Functions
    // pour envoyer les notifications via l'API Firebase
    debugPrint('Envoi notification à $userToken: $title - $body');
  }

  /// Types de notifications pour Chafin Loans
  static Future<void> sendLoanNotification({
    required String userToken,
    required LoanNotificationType type,
    required String loanId,
    Map<String, dynamic>? extraData,
  }) async {
    String title = '';
    String body = '';

    switch (type) {
      case LoanNotificationType.loanRequested:
        title = 'Nouvelle demande de prêt';
        body = 'Une nouvelle demande de prêt a été soumise';
        break;
      case LoanNotificationType.loanApproved:
        title = 'Prêt approuvé';
        body = 'Votre demande de prêt a été approuvée';
        break;
      case LoanNotificationType.loanRejected:
        title = 'Prêt refusé';
        body = 'Votre demande de prêt a été refusée';
        break;
      case LoanNotificationType.paymentDue:
        title = 'Échéance de paiement';
        body = 'Vous avez une échéance à venir';
        break;
      case LoanNotificationType.paymentOverdue:
        title = 'Paiement en retard';
        body = 'Votre paiement est en retard';
        break;
      case LoanNotificationType.loanCompleted:
        title = 'Prêt remboursé';
        body = 'Félicitations ! Votre prêt a été entièrement remboursé';
        break;
    }

    await sendNotificationToUser(
      userToken: userToken,
      title: title,
      body: body,
      data: {'type': type.name, 'loanId': loanId, ...?extraData},
    );
  }
}

/// Types de notifications pour les prêts
enum LoanNotificationType {
  loanRequested,
  loanApproved,
  loanRejected,
  paymentDue,
  paymentOverdue,
  loanCompleted,
}
