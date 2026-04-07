import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service de notifications sécurisé avec gestion d'erreur robuste
/// Conçu pour éviter les crashes lors de l'initialisation APNS
class SafeNotificationService {
  static FirebaseMessaging? _messaging;
  static String? _fcmToken;
  static bool _isInitialized = false;

  // Timeout pour l'initialisation
  static const Duration _timeout = Duration(seconds: 30);

  /// Initialise le service de notifications de manière sécurisée
  /// Retourne true si succès, false si fallback
  static Future<bool> initialize() async {
    print('🔔 SafeNotificationService: Début initialisation...');

    try {
      // Timeout global pour éviter les blocages
      return await _initializeWithTimeout();
    } catch (e, stackTrace) {
      print('❌ SafeNotificationService: Erreur critique - $e');
      print('📍 StackTrace: $stackTrace');
      return false; // Fallback gracieux
    }
  }

  /// Initialisation avec timeout
  static Future<bool> _initializeWithTimeout() async {
    return await _initializeCore().timeout(
      _timeout,
      onTimeout: () {
        print(
          '⏰ SafeNotificationService: Timeout après ${_timeout.inSeconds}s',
        );
        return false;
      },
    );
  }

  /// Logique d'initialisation principale
  static Future<bool> _initializeCore() async {
    try {
      // Seulement sur mobile et si Firebase est disponible
      if (Platform.isIOS || Platform.isAndroid) {
        print('📱 Plateforme mobile détectée, initialisation Firebase...');
        return await _initializeFirebaseMessaging();
      } else {
        print('💻 Plateforme desktop/web, notifications Firebase ignorées');
        _isInitialized = true;
        return true;
      }
    } catch (e) {
      print('❌ Erreur dans _initializeCore: $e');
      return false;
    }
  }

  /// Initialise Firebase Messaging avec gestion d'erreur APNS
  static Future<bool> _initializeFirebaseMessaging() async {
    try {
      print('🔥 Initialisation Firebase Messaging...');
      _messaging = FirebaseMessaging.instance;

      // Demander les permissions d'abord
      print('🔐 Demande des permissions...');
      final settings = await _requestPermissions();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('⚠️ Permissions notifications refusées');
        return false;
      }
      print('✅ Permissions accordées');

      // Configurer les gestionnaires de messages
      print('📨 Configuration des gestionnaires de messages...');
      await _setupMessageHandlers();
      print('✅ Gestionnaires configurés');

      // Tenter d'obtenir le token APNS avec retry
      print('🔑 Récupération du token APNS...');
      final tokenSuccess = await _setupAPNSToken();
      if (!tokenSuccess) {
        print('⚠️ Token APNS non disponible (mode dégradé)');
        // Continue quand même, le token peut être obtenu plus tard
      }

      _isInitialized = true;
      print('✅ Firebase Messaging initialisé avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur Firebase Messaging: $e');
      // Ne pas lever l'exception, retourner false pour fallback
      return false;
    }
  }

  /// Demande les permissions de notifications
  static Future<NotificationSettings> _requestPermissions() async {
    if (_messaging == null) {
      throw Exception('Firebase Messaging non initialisé');
    }

    return await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  /// Configure les gestionnaires de messages
  static Future<void> _setupMessageHandlers() async {
    if (_messaging == null) return;

    // Message en avant-plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Message reçu en avant-plan: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Message ouvre l'app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 App ouverte via notification: ${message.messageId}');
      _handleMessageOpenedApp(message);
    });
  }

  /// Récupère le token APNS avec retry
  static Future<bool> _setupAPNSToken() async {
    if (_messaging == null) return false;

    // Retry avec backoff exponentiel
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('🔑 Tentative $attempt/3 récupération token...');

        // iOS: Obtenir le token APNS d'abord
        if (Platform.isIOS) {
          final apnsToken = await _messaging!.getAPNSToken();
          if (apnsToken != null) {
            print('✅ Token APNS obtenu: ${apnsToken.substring(0, 8)}...');
          } else {
            print('⚠️ Token APNS non disponible (tentative $attempt)');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2));
              continue;
            }
          }
        }

        // Obtenir le token FCM
        _fcmToken = await _messaging!.getToken();
        if (_fcmToken != null) {
          print('✅ Token FCM obtenu: ${_fcmToken!.substring(0, 8)}...');
          return true;
        } else {
          print('⚠️ Token FCM non disponible (tentative $attempt)');
        }
      } catch (e) {
        print('❌ Erreur tentative $attempt: $e');
      }

      // Attendre avant retry
      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    print('❌ Impossible d\'obtenir le token après 3 tentatives');
    return false;
  }

  /// Gère les messages en avant-plan
  static void _handleForegroundMessage(RemoteMessage message) {
    print(
      '📨 Message en avant-plan: ${message.notification?.title ?? 'Sans titre'}',
    );
    // Les notifications seront gérées par le système iOS/Android
  }

  /// Gère l'ouverture de l'app via notification
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('🚀 App ouverte via notification: ${message.data}');
    // TODO: Navigation vers l'écran approprié
  }

  /// Getters publics
  static bool get isInitialized => _isInitialized;
  static String? get fcmToken => _fcmToken;

  /// Obtient le token actuel (peut être null)
  static Future<String?> getCurrentToken() async {
    if (_messaging == null || !_isInitialized) {
      print('⚠️ Service non initialisé, tentative de récupération du token...');
      return null;
    }

    try {
      return await _messaging!.getToken();
    } catch (e) {
      print('❌ Erreur récupération token: $e');
      return null;
    }
  }

  /// Force le rafraîchissement du token
  static Future<String?> refreshToken() async {
    if (_messaging == null) return null;

    try {
      await _messaging!.deleteToken();
      _fcmToken = await _messaging!.getToken();
      return _fcmToken;
    } catch (e) {
      print('❌ Erreur rafraîchissement token: $e');
      return null;
    }
  }
}
