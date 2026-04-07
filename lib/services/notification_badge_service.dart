import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Types de notifications pouvant avoir des badges
enum BadgeType {
  loanRequests, // Nouvelles demandes de prêt
  paymentReminders, // Rappels de paiement
  messages, // Messages/discussions
  systemNotices, // Notifications système
  all, // Total de toutes les notifications
}

/// Service pour gérer les badges de notification et les compteurs non lus
class NotificationBadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection pour stocker les compteurs de notification par utilisateur
  static const String _badgeCollection = 'notification_badges';

  /// Modèle pour les données de badge
  static const Map<BadgeType, String> badgeKeys = {
    BadgeType.loanRequests: 'loan_requests',
    BadgeType.paymentReminders: 'payment_reminders',
    BadgeType.messages: 'messages',
    BadgeType.systemNotices: 'system_notices',
    BadgeType.all: 'all',
  };

  /// Obtenir le nombre de notifications non lues pour un utilisateur et un type
  static Future<int> getUnreadCount(String userId, BadgeType type) async {
    try {
      final docRef = _firestore.collection(_badgeCollection).doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return 0;
      }

      final data = doc.data() as Map<String, dynamic>;
      final key = badgeKeys[type]!;

      return data[key] ?? 0;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du compteur de badge: $e');
      return 0;
    }
  }

  /// Obtenir tous les compteurs de badges pour un utilisateur
  static Future<Map<BadgeType, int>> getAllBadgeCounts(String userId) async {
    try {
      final docRef = _firestore.collection(_badgeCollection).doc(userId);
      final doc = await docRef.get();

      Map<BadgeType, int> counts = {};

      if (!doc.exists) {
        // Initialiser tous les compteurs à 0
        for (BadgeType type in BadgeType.values) {
          counts[type] = 0;
        }
        return counts;
      }

      final data = doc.data() as Map<String, dynamic>;

      for (BadgeType type in BadgeType.values) {
        final key = badgeKeys[type]!;
        counts[type] = data[key] ?? 0;
      }

      return counts;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des compteurs de badges: $e');

      // Retourner des compteurs vides en cas d'erreur
      Map<BadgeType, int> emptyCounts = {};
      for (BadgeType type in BadgeType.values) {
        emptyCounts[type] = 0;
      }
      return emptyCounts;
    }
  }

  /// Incrémenter le compteur d'un type de badge
  static Future<void> incrementBadge(
    String userId,
    BadgeType type, {
    int increment = 1,
  }) async {
    try {
      final docRef = _firestore.collection(_badgeCollection).doc(userId);
      final key = badgeKeys[type]!;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        Map<String, dynamic> data = {};
        if (doc.exists) {
          data = doc.data() as Map<String, dynamic>;
        }

        // Incrémenter le compteur spécifique
        data[key] = (data[key] ?? 0) + increment;

        // Incrémenter aussi le compteur total si ce n'est pas déjà le type 'all'
        if (type != BadgeType.all) {
          final allKey = badgeKeys[BadgeType.all]!;
          data[allKey] = (data[allKey] ?? 0) + increment;
        }

        // Ajouter les métadonnées
        data['lastUpdatedAt'] = FieldValue.serverTimestamp();

        transaction.set(docRef, data, SetOptions(merge: true));
      });

      debugPrint(
        'Badge incrémenté: $type (+$increment) pour utilisateur $userId',
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'incrémentation du badge: $e');
      rethrow;
    }
  }

  /// Décrémenter le compteur d'un type de badge
  static Future<void> decrementBadge(
    String userId,
    BadgeType type, {
    int decrement = 1,
  }) async {
    try {
      final docRef = _firestore.collection(_badgeCollection).doc(userId);
      final key = badgeKeys[type]!;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) return;

        final data = doc.data() as Map<String, dynamic>;

        // Décrémenter le compteur spécifique (ne pas descendre en dessous de 0)
        int currentCount = data[key] ?? 0;
        data[key] = (currentCount - decrement)
            .clamp(0, double.infinity)
            .toInt();

        // Décrémenter aussi le compteur total si ce n'est pas déjà le type 'all'
        if (type != BadgeType.all) {
          final allKey = badgeKeys[BadgeType.all]!;
          int currentAllCount = data[allKey] ?? 0;
          data[allKey] = (currentAllCount - decrement)
              .clamp(0, double.infinity)
              .toInt();
        }

        // Ajouter les métadonnées
        data['lastUpdatedAt'] = FieldValue.serverTimestamp();

        transaction.set(docRef, data, SetOptions(merge: true));
      });

      debugPrint(
        'Badge décrémenté: $type (-$decrement) pour utilisateur $userId',
      );
    } catch (e) {
      debugPrint('Erreur lors de la décrémentation du badge: $e');
      rethrow;
    }
  }

  /// Réinitialiser le compteur d'un type de badge à zéro
  static Future<void> clearBadge(String userId, BadgeType type) async {
    try {
      final docRef = _firestore.collection(_badgeCollection).doc(userId);
      final key = badgeKeys[type]!;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) return;

        final data = doc.data() as Map<String, dynamic>;
        int previousCount = data[key] ?? 0;

        // Réinitialiser le compteur spécifique
        data[key] = 0;

        // Ajuster le compteur total si ce n'est pas déjà le type 'all'
        if (type != BadgeType.all && previousCount > 0) {
          final allKey = badgeKeys[BadgeType.all]!;
          int currentAllCount = data[allKey] ?? 0;
          data[allKey] = (currentAllCount - previousCount)
              .clamp(0, double.infinity)
              .toInt();
        }

        // Si on réinitialise 'all', réinitialiser tous les compteurs
        if (type == BadgeType.all) {
          for (BadgeType badgeType in BadgeType.values) {
            if (badgeType != BadgeType.all) {
              final typeKey = badgeKeys[badgeType]!;
              data[typeKey] = 0;
            }
          }
        }

        // Ajouter les métadonnées
        data['lastUpdatedAt'] = FieldValue.serverTimestamp();

        transaction.set(docRef, data, SetOptions(merge: true));
      });

      debugPrint('Badge réinitialisé: $type pour utilisateur $userId');
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du badge: $e');
      rethrow;
    }
  }

  /// Obtenir un stream des compteurs de badges en temps réel
  static Stream<Map<BadgeType, int>> getBadgeCountsStream(String userId) {
    return _firestore.collection(_badgeCollection).doc(userId).snapshots().map((
      doc,
    ) {
      Map<BadgeType, int> counts = {};

      if (!doc.exists) {
        // Initialiser tous les compteurs à 0
        for (BadgeType type in BadgeType.values) {
          counts[type] = 0;
        }
        return counts;
      }

      final data = doc.data() as Map<String, dynamic>;

      for (BadgeType type in BadgeType.values) {
        final key = badgeKeys[type]!;
        counts[type] = data[key] ?? 0;
      }

      return counts;
    });
  }

  /// Marquer une notification comme lue (décrémente le badge correspondant)
  static Future<void> markNotificationAsRead(
    String userId,
    BadgeType type,
  ) async {
    await decrementBadge(userId, type);
  }

  /// Marquer plusieurs notifications comme lues
  static Future<void> markMultipleNotificationsAsRead(
    String userId,
    BadgeType type,
    int count,
  ) async {
    if (count > 0) {
      await decrementBadge(userId, type, decrement: count);
    }
  }

  /// Ajouter une nouvelle notification (incrémente le badge correspondant)
  static Future<void> addNotification(String userId, BadgeType type) async {
    await incrementBadge(userId, type);
  }

  /// Obtenir le libellé d'un type de badge
  static String getBadgeLabel(BadgeType type) {
    switch (type) {
      case BadgeType.loanRequests:
        return 'Demandes de prêt';
      case BadgeType.paymentReminders:
        return 'Rappels de paiement';
      case BadgeType.messages:
        return 'Messages';
      case BadgeType.systemNotices:
        return 'Notifications système';
      case BadgeType.all:
        return 'Toutes les notifications';
    }
  }

  /// Obtenir l'icône d'un type de badge
  static String getBadgeIcon(BadgeType type) {
    switch (type) {
      case BadgeType.loanRequests:
        return 'request_quote';
      case BadgeType.paymentReminders:
        return 'payment';
      case BadgeType.messages:
        return 'message';
      case BadgeType.systemNotices:
        return 'notifications';
      case BadgeType.all:
        return 'notifications_active';
    }
  }
}
