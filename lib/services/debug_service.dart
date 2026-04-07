import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service de debug pour nettoyer les données de test
class DebugService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Supprime toutes les notifications de test/démo
  static Future<void> clearAllTestNotifications() async {
    try {
      debugPrint('🧹 Nettoyage des notifications de test...');

      // Récupérer toutes les notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (final doc in notificationsSnapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String? ?? '';
        final body = data['body'] as String? ?? '';

        // Identifier les notifications de test par leur contenu
        if (_isTestNotification(title, body)) {
          batch.delete(doc.reference);
          count++;
          debugPrint('Suppression notification test: $title');
        }
      }

      if (count > 0) {
        await batch.commit();
        debugPrint('✅ $count notifications de test supprimées');
      } else {
        debugPrint('ℹ️ Aucune notification de test trouvée');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage des notifications: $e');
      rethrow;
    }
  }

  /// Détermine si une notification est une notification de test
  static bool _isTestNotification(String title, String body) {
    final testKeywords = [
      'prêt approuvé',
      'échéance prochaine',
      'document requis',
      'demande de prêt soumise',
      'félicitations',
      '5 000€',
      '248€',
      'justificatif de revenus',
      'dans 3 jours',
    ];

    final titleLower = title.toLowerCase();
    final bodyLower = body.toLowerCase();

    return testKeywords.any(
      (keyword) =>
          titleLower.contains(keyword.toLowerCase()) ||
          bodyLower.contains(keyword.toLowerCase()),
    );
  }

  /// Supprime toutes les notifications d'un utilisateur spécifique
  static Future<void> clearUserNotifications(String userId) async {
    try {
      debugPrint(
        '🧹 Nettoyage des notifications pour l\'utilisateur $userId...',
      );

      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
        '✅ ${notificationsSnapshot.docs.length} notifications supprimées pour $userId',
      );
    } catch (e) {
      debugPrint(
        '❌ Erreur lors du nettoyage des notifications utilisateur: $e',
      );
      rethrow;
    }
  }

  /// Ajoute des notifications de test pour un utilisateur (pour les tests)
  static Future<void> addTestNotificationsForUser(String userId) async {
    try {
      debugPrint('🧪 Ajout de notifications de test pour $userId...');

      final notifications = [
        {
          'title': 'Bienvenue !',
          'body': 'Bienvenue dans l\'application Chafin Loans',
          'type': 'general',
        },
        {
          'title': 'Fonctionnalité disponible',
          'body': 'Vous pouvez maintenant faire une demande de prêt',
          'type': 'system',
        },
      ];

      final batch = _firestore.batch();

      for (final notificationData in notifications) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'id': docRef.id,
          'userId': userId,
          'title': notificationData['title'],
          'body': notificationData['body'],
          'type': notificationData['type'],
          'createdAt': Timestamp.now(),
          'isRead': false,
          'data': null,
        });
      }

      await batch.commit();
      debugPrint('✅ ${notifications.length} notifications de test ajoutées');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ajout des notifications de test: $e');
      rethrow;
    }
  }

  /// Nettoie toutes les données de test de l'application
  static Future<void> cleanAllTestData() async {
    try {
      debugPrint('🧹 Nettoyage complet des données de test...');

      // Supprimer les notifications de test
      await clearAllTestNotifications();

      // Autres nettoyages pourraient être ajoutés ici
      // await clearTestLoans();
      // await clearTestUsers();

      debugPrint('✅ Nettoyage complet terminé');
    } catch (e) {
      debugPrint('❌ Erreur lors du nettoyage complet: $e');
      rethrow;
    }
  }
}
