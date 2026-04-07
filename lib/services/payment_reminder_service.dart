import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/loan_model.dart';
import '../models/notification_model.dart';
import '../services/app_notification_service.dart';

/// Types de rappels étendus
enum ReminderType {
  standard, // Rappel standard
  urgent, // Rappel urgent
  overdue, // Rappel de retard
  finalNotice, // Dernier avis
}

/// Statut du rappel
enum ReminderStatus {
  pending, // En attente d'envoi
  sent, // Envoyé avec succès
  failed, // Échec d'envoi
  cancelled, // Annulé
}

/// Service de rappels pour les échéances de paiement
///
/// ⚠️ IMPORTANT : Les emails de rappel sont gérés UNIQUEMENT par Cloud Functions
/// (dailyPaymentReminders cron à 9h Europe/Paris).
/// Ce service ne gère que :
/// - Les rappels manuels admin (notification in-app uniquement, PAS d'email)
/// - L'historique des rappels
/// - Les statistiques
///
/// Les emails automatiques sont envoyés par Cloud Functions aux jours suivants :
/// - J-3, J-1 : rappels avant échéance
/// - J+7, J+21 : rappels de retard
/// - J+31 : pénalité consolidée
class PaymentReminderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === RAPPELS MANUELS ADMIN (notification in-app uniquement, PAS d'email) ===

  /// Envoie un rappel manuel depuis l'interface admin
  /// ⚠️ Crée UNIQUEMENT une notification in-app. Les emails sont gérés par Cloud Functions.
  static Future<bool> sendManualReminder({
    required String loanId,
    required ReminderType type,
    String? customMessage,
    String? adminId,
  }) async {
    try {
      debugPrint(
        '📧 [REMINDER] Rappel manuel (in-app only): $loanId, type: $type',
      );

      // Récupérer les détails du prêt
      final loanDoc = await _firestore.collection('loans').doc(loanId).get();
      if (!loanDoc.exists) {
        debugPrint('❌ [REMINDER] Prêt non trouvé: $loanId');
        return false;
      }

      final loan = LoanModel.fromJson(loanDoc.data()!);

      // Récupérer les détails de l'emprunteur
      final userDoc = await _firestore
          .collection('users')
          .doc(loan.userId)
          .get();
      if (!userDoc.exists) {
        debugPrint('❌ [REMINDER] Utilisateur non trouvé: ${loan.userId}');
        return false;
      }

      // Générer le message selon le type
      final message = customMessage ?? _generateReminderMessage(type, loan);

      debugPrint(
        '🔔 [REMINDER] Création notification in-app pour ${loan.userId}',
      );

      // ⚠️ UNIQUEMENT notification in-app — PAS d'email
      // Les emails sont gérés par Cloud Functions (dailyPaymentReminders)
      await AppNotificationService.createNotification(
        userId: loan.userId,
        title: _getReminderTitle(type),
        body: message,
        type: NotificationType.paymentDue,
        data: {
          'loanId': loan.id,
          'type': type.toString().split('.').last,
          'daysOverdue': _calculateDaysOverdue(loan).toString(),
          'amount': loan.mensualite.toStringAsFixed(2),
          'dueDate':
              _getNextPaymentDate(loan)?.toIso8601String().split('T')[0] ?? '',
          'source': 'admin_manual',
        },
      );

      // Enregistrer le rappel dans l'historique
      await _logManualReminder(
        loanId: loanId,
        userId: loan.userId,
        type: type,
        status: ReminderStatus.sent,
        message: message,
        adminId: adminId,
      );

      debugPrint(
        '✅ [REMINDER] Rappel manuel créé (notification in-app uniquement)',
      );
      return true;
    } catch (e) {
      debugPrint('❌ [REMINDER] Erreur lors de l\'envoi du rappel: $e');
      return false;
    }
  }

  /// Récupère l'historique des rappels pour un prêt
  static Future<List<Map<String, dynamic>>> getReminderHistory(
    String loanId,
  ) async {
    try {
      final remindersQuery = await _firestore
          .collection('payment_reminders')
          .where('loanId', isEqualTo: loanId)
          .orderBy('sentAt', descending: true)
          .get();

      return remindersQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint(
        '❌ [REMINDER] Erreur lors de la récupération de l\'historique: $e',
      );
      return [];
    }
  }

  /// Récupère les statistiques des rappels
  static Future<Map<String, dynamic>> getReminderStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('payment_reminders');

      if (startDate != null) {
        query = query.where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'sentAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final remindersQuery = await query.get();

      final stats = <String, int>{
        'total': 0,
        'sent': 0,
        'failed': 0,
        'standard': 0,
        'urgent': 0,
        'overdue': 0,
        'final_notice': 0,
      };

      for (final doc in remindersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        stats['total'] = (stats['total'] ?? 0) + 1;

        final status = data['status'] as String?;
        if (status != null) {
          stats[status] = (stats[status] ?? 0) + 1;
        }

        final type = data['type'] as String?;
        if (type != null) {
          stats[type] = (stats[type] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint(
        '❌ [REMINDER] Erreur lors de la récupération des statistiques: $e',
      );
      return {};
    }
  }

  // --- Méthodes privées pour les rappels manuels ---

  static String _generateReminderMessage(ReminderType type, LoanModel loan) {
    switch (type) {
      case ReminderType.standard:
        return 'Rappel amical : Votre prochaine échéance de remboursement approche. '
            'Montant du prêt : ${loan.montant.toStringAsFixed(2)}€';
      case ReminderType.urgent:
        return 'Rappel urgent : Votre échéance de remboursement est due demain. '
            'Merci de vous assurer que le paiement sera effectué à temps.';
      case ReminderType.overdue:
        return 'Avis de retard : Votre échéance de ${loan.mensualite.toStringAsFixed(2)}€ '
            'est en retard. Merci de régulariser votre situation rapidement.';
      case ReminderType.finalNotice:
        return 'Dernier avis : Votre prêt présente un retard important. '
            'Contactez-nous immédiatement pour éviter des mesures supplémentaires.';
    }
  }

  static String _getReminderTitle(ReminderType type) {
    switch (type) {
      case ReminderType.standard:
        return 'Rappel d\'échéance';
      case ReminderType.urgent:
        return 'Rappel urgent';
      case ReminderType.overdue:
        return 'Paiement en retard';
      case ReminderType.finalNotice:
        return 'Dernier avis';
    }
  }

  static int _calculateDaysOverdue(LoanModel loan) {
    final nextPayment = _getNextPaymentDate(loan);
    if (nextPayment == null) return 0;

    final now = DateTime.now();
    if (nextPayment.isAfter(now)) return 0;

    return now.difference(nextPayment).inDays;
  }

  static DateTime? _getNextPaymentDate(LoanModel loan) {
    // Calcul simple de la prochaine échéance
    final now = DateTime.now();
    if (loan.datePremierRemboursement.isAfter(now)) {
      return loan.datePremierRemboursement;
    }

    DateTime nextPayment = loan.datePremierRemboursement;
    while (nextPayment.isBefore(now)) {
      nextPayment = DateTime(
        nextPayment.year,
        nextPayment.month + 1,
        nextPayment.day,
      );
    }

    return nextPayment;
  }

  static Future<void> _logManualReminder({
    required String loanId,
    required String userId,
    required ReminderType type,
    required ReminderStatus status,
    required String message,
    String? adminId,
  }) async {
    try {
      await _firestore.collection('payment_reminders').add({
        'loanId': loanId,
        'userId': userId,
        'type': type.toString().split('.').last,
        'status': status.toString().split('.').last,
        'message': message,
        'adminId': adminId,
        'isManual': true,
        'sentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ [REMINDER] Erreur lors de l\'enregistrement du rappel: $e');
    }
  }
}
