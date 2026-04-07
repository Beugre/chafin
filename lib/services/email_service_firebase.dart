import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service d'email utilisant Firebase Cloud Functions
/// Compatible avec Flutter Web et les applications mobiles
class EmailService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configuration de l'application
  static const String _appUrl = 'https://chafin-loans.web.app';

  /// Envoie un email via Firebase Cloud Functions
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? toName,
    bool isHtml = true,
  }) async {
    try {
      // Enregistrer la tentative d'envoi
      await _logEmailAttempt(to, 'generic', {'subject': subject});

      final callable = _functions.httpsCallable('sendEmail');
      final result = await callable.call({
        'to': to,
        'toName': toName,
        'subject': subject,
        'body': body,
        'isHtml': isHtml,
      });

      final success = result.data['success'] as bool? ?? false;

      if (success) {
        await _logEmailSuccess(to, 'generic');
        debugPrint('✅ Email envoyé avec succès à $to');
      } else {
        final error = result.data['error'] as String? ?? 'Erreur inconnue';
        await _logEmailFailure(to, 'generic', error);
        debugPrint('❌ Échec envoi email à $to: $error');
      }

      return success;
    } catch (e) {
      await _logEmailFailure(to, 'generic', e.toString());
      debugPrint('❌ Erreur envoi email à $to: $e');
      return false;
    }
  }

  /// Envoie un email de notification de prêt
  static Future<bool> sendLoanNotificationEmail({
    required String to,
    required String userName,
    required LoanEmailType type,
    required Map<String, dynamic> loanData,
  }) async {
    try {
      // Enregistrer la tentative d'envoi
      await _logEmailAttempt(to, type.toString(), loanData);

      final callable = _functions.httpsCallable('sendLoanEmail');
      final result = await callable.call({
        'to': to,
        'userName': userName,
        'type': type.toString(),
        'loanData': loanData,
      });

      final success = result.data['success'] as bool? ?? false;

      if (success) {
        await _logEmailSuccess(to, type.toString());
        debugPrint(
          '✅ Email de prêt envoyé avec succès à $to (type: ${type.toString()})',
        );
      } else {
        final error = result.data['error'] as String? ?? 'Erreur inconnue';
        await _logEmailFailure(to, type.toString(), error);
        debugPrint('❌ Échec envoi email de prêt à $to: $error');
      }

      return success;
    } catch (e) {
      await _logEmailFailure(to, type.toString(), e.toString());
      debugPrint('❌ Erreur envoi email de prêt à $to: $e');
      return false;
    }
  }

  /// Envoie un email de bienvenue
  static Future<bool> sendWelcomeEmail({
    required String to,
    required String userName,
  }) async {
    return await sendLoanNotificationEmail(
      to: to,
      userName: userName,
      type: LoanEmailType.welcome,
      loanData: {'userName': userName},
    );
  }

  /// Envoie un email à tous les administrateurs
  static Future<List<String>> sendEmailToAllAdmins({
    required LoanEmailType type,
    required Map<String, dynamic> loanData,
  }) async {
    final adminEmails = await _getAdminEmails();
    final successfulEmails = <String>[];

    for (final email in adminEmails) {
      final success = await sendLoanNotificationEmail(
        to: email,
        userName: 'Administrateur',
        type: type,
        loanData: loanData,
      );
      if (success) {
        successfulEmails.add(email);
      }
    }

    debugPrint(
      '✅ Emails envoyés à ${successfulEmails.length}/${adminEmails.length} admins',
    );
    return successfulEmails;
  }

  /// Récupère les emails de tous les administrateurs
  static Future<List<String>> _getAdminEmails() async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      return adminQuery.docs
          .map((doc) => doc.data()['email'] as String?)
          .where((email) => email != null)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des emails admin: $e');
      return [];
    }
  }

  /// Enregistre une tentative d'envoi d'email
  static Future<void> _logEmailAttempt(
    String email,
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'attempted',
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    } catch (e) {
      debugPrint('❌ Erreur log email: $e');
    }
  }

  /// Enregistre un succès d'envoi
  static Future<void> _logEmailSuccess(String email, String type) async {
    try {
      await _firestore.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    } catch (e) {
      debugPrint('❌ Erreur log success: $e');
    }
  }

  /// Enregistre un échec d'envoi
  static Future<void> _logEmailFailure(
    String email,
    String type,
    String error,
  ) async {
    try {
      await _firestore.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'failed',
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
    } catch (e) {
      debugPrint('❌ Erreur log failure: $e');
    }
  }

  /// Teste la connexion aux Cloud Functions
  static Future<bool> testEmailService() async {
    try {
      final callable = _functions.httpsCallable('testEmail');
      final result = await callable.call({'test': true});

      final success = result.data['success'] as bool? ?? false;
      if (success) {
        debugPrint('✅ Service email opérationnel');
      } else {
        debugPrint('❌ Service email non disponible');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Erreur test service email: $e');
      return false;
    }
  }

  /// Obtient les statistiques d'envoi d'emails
  static Future<Map<String, dynamic>> getEmailStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _firestore
          .collection('email_logs')
          .orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final logs = await query.limit(1000).get();

      int total = logs.docs.length;
      int sent = logs.docs
          .where((doc) => doc.data()['status'] == 'sent')
          .length;
      int failed = logs.docs
          .where((doc) => doc.data()['status'] == 'failed')
          .length;
      int attempted = logs.docs
          .where((doc) => doc.data()['status'] == 'attempted')
          .length;

      // Compter par type d'email
      Map<String, int> typeStats = {};
      for (final doc in logs.docs) {
        final type = doc.data()['type'] as String? ?? 'unknown';
        typeStats[type] = (typeStats[type] ?? 0) + 1;
      }

      return {
        'total': total,
        'sent': sent,
        'failed': failed,
        'attempted': attempted,
        'success_rate': total > 0 ? (sent / total * 100).round() : 0,
        'type_breakdown': typeStats,
        'period': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des statistiques: $e');
      return {
        'total': 0,
        'sent': 0,
        'failed': 0,
        'attempted': 0,
        'success_rate': 0,
        'type_breakdown': {},
        'error': e.toString(),
      };
    }
  }
}

/// Types d'emails pour les prêts
enum LoanEmailType {
  welcome,
  loanRequested,
  loanApproved,
  loanRejected,
  paymentReminder,
  paymentOverdue,
  loanCompleted,
  rateChanged,
  loanDisbursed,
  paymentReceived,
  adminLoanRequest,
}

/// Extensions pour le service EmailService
extension EmailServiceExtensions on EmailService {
  /// Envoie un rappel de paiement manuel (fonction administrative)
  static Future<bool> sendManualPaymentReminder({
    required String loanId,
    required String adminMessage,
  }) async {
    try {
      // Récupérer les détails du prêt
      final loanDoc = await FirebaseFirestore.instance
          .collection('loans')
          .doc(loanId)
          .get();

      if (!loanDoc.exists) {
        throw Exception('Prêt non trouvé');
      }

      final loanData = loanDoc.data()!;

      // Récupérer les infos de l'emprunteur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(loanData['userId'])
          .get();

      if (!userDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }

      final userData = userDoc.data()!;
      final userEmail = userData['email'] as String?;
      final userName = userData['nom'] as String? ?? 'Cher client';

      if (userEmail == null) {
        throw Exception('Email utilisateur non trouvé');
      }

      // Trouver la prochaine échéance impayée
      final scheduleQuery = await FirebaseFirestore.instance
          .collection('schedules')
          .where('loanId', isEqualTo: loanId)
          .where('isPaid', isEqualTo: false)
          .orderBy('numero')
          .limit(1)
          .get();

      if (scheduleQuery.docs.isEmpty) {
        throw Exception('Aucune échéance impayée trouvée');
      }

      final nextSchedule = scheduleQuery.docs.first.data();
      final amount = nextSchedule['total'] as double;
      final dueDate = (nextSchedule['dueDate'] as Timestamp).toDate();

      return await EmailService.sendLoanNotificationEmail(
        to: userEmail,
        userName: userName,
        type: LoanEmailType.paymentReminder,
        loanData: {
          'amount': amount.toStringAsFixed(0),
          'dueDate': _formatDate(dueDate),
          'loanId': loanId,
          'adminMessage': adminMessage,
        },
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi du rappel manuel: $e');
      return false;
    }
  }

  /// Formate une date pour l'affichage
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
