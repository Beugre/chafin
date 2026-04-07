import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/emailjs_config.dart';

/// Service de gestion des emails avec EmailJS (VRAIS emails)
class EmailService {
  static const String _emailJsUrl =
      'https://api.emailjs.com/api/v1.0/email/send';

  // Configuration de l'application
  static const String _appUrl = 'https://chafin-loans.web.app';

  /// Envoie un email via une API REST (compatible Flutter Web)
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? toName,
    bool isHtml = true,
  }) async {
    // Envoyer de VRAIS emails via EmailJS
    return await _sendEmailViaEmailJS(
      to: to,
      subject: subject,
      body: body,
      toName: toName,
      isHtml: isHtml,
    );
  }

  /// Envoie un email de bienvenue
  static Future<bool> sendWelcomeEmail({
    required String to,
    required String userName,
  }) async {
    const subject = 'Bienvenue sur Chafin Loans !';
    final body =
        '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Bienvenue sur Chafin Loans</title>
    </head>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #2196F3; margin: 0;">Chafin Loans</h1>
            </div>
            
            <h2 style="color: #333;">Bienvenue $userName !</h2>
            
            <p style="color: #666; line-height: 1.6;">
                Nous sommes ravis de vous accueillir sur Chafin Loans, votre plateforme de prêts entre particuliers.
            </p>
            
            <p style="color: #666; line-height: 1.6;">
                Avec Chafin Loans, vous pouvez :
            </p>
            
            <ul style="color: #666; line-height: 1.6;">
                <li>Demander des prêts rapidement et facilement</li>
                <li>Suivre vos remboursements</li>
                <li>Gérer vos échéances</li>
                <li>Accéder à vos contrats</li>
            </ul>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="#" style="background-color: #2196F3; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
                    Commencer maintenant
                </a>
            </div>
            
            <p style="color: #999; font-size: 12px; text-align: center; margin-top: 30px;">
                Cet email a été envoyé par Chafin Loans. Si vous avez des questions, contactez-nous.
            </p>
        </div>
    </body>
    </html>
    ''';

    return await sendEmail(
      to: to,
      subject: subject,
      body: body,
      toName: userName,
    );
  }

  /// Envoie un email de notification de prêt
  ///
  /// ⛔ KILL SWITCH : paymentReminder et paymentOverdue sont BLOQUÉS ici.
  /// Les emails de rappel/retard sont gérés UNIQUEMENT par Cloud Functions.
  static Future<bool> sendLoanNotificationEmail({
    required String to,
    required String userName,
    required LoanEmailType type,
    required Map<String, dynamic> loanData,
  }) async {
    // ⛔ KILL SWITCH : BLOQUER les emails de rappel/retard côté Flutter
    // Ces emails sont gérés EXCLUSIVEMENT par Cloud Functions (dailyPaymentReminders)
    if (type == LoanEmailType.paymentReminder ||
        type == LoanEmailType.paymentOverdue) {
      debugPrint('⛔ [KILL SWITCH] Email $type BLOQUÉ côté Flutter pour $to');
      debugPrint(
        '⛔ Les rappels/retards sont gérés par Cloud Functions UNIQUEMENT',
      );
      return false;
    }

    String subject = '';
    String body = '';

    switch (type) {
      case LoanEmailType.loanRequested:
        subject = 'Demande de prêt soumise';
        body = _buildLoanRequestedEmail(userName, loanData);
        break;
      case LoanEmailType.loanApproved:
        subject = 'Prêt approuvé !';
        body = _buildLoanApprovedEmail(userName, loanData);
        break;
      case LoanEmailType.loanRejected:
        subject = 'Demande de prêt refusée';
        body = _buildLoanRejectedEmail(userName, loanData);
        break;
      case LoanEmailType.paymentReminder:
        subject = 'Rappel d\'échéance';
        body = _buildPaymentReminderEmail(userName, loanData);
        break;
      case LoanEmailType.paymentOverdue:
        subject = 'Paiement en retard';
        body = _buildPaymentOverdueEmail(userName, loanData);
        break;
      case LoanEmailType.loanCompleted:
        subject = 'Prêt remboursé avec succès';
        body = _buildLoanCompletedEmail(userName, loanData);
        break;
      case LoanEmailType.rateChanged:
        subject = 'Modification du taux d\'intérêt';
        body = _buildRateChangedEmail(userName, loanData);
        break;
      case LoanEmailType.loanDisbursed:
        subject = 'Décaissement effectué';
        body = _buildLoanDisbursedEmail(userName, loanData);
        break;
      case LoanEmailType.paymentReceived:
        subject = 'Paiement reçu';
        body = _buildPaymentReceivedEmail(userName, loanData);
        break;
      case LoanEmailType.adminLoanRequest:
        subject = '🔔 Nouvelle demande de prêt - Action requise';
        body = _buildAdminLoanRequestEmail(userName, loanData);
        break;
    }

    // Enregistrer la tentative d'envoi
    await _logEmailAttempt(to, type.toString(), loanData);

    final success = await sendEmail(
      to: to,
      subject: subject,
      body: body,
      toName: userName,
    );

    // Enregistrer le résultat
    if (success) {
      await _logEmailSuccess(to, type.toString());
    } else {
      await _logEmailFailure(to, type.toString(), 'Send failed');
    }

    return success;
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
      final adminQuery = await FirebaseFirestore.instance
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
      await FirebaseFirestore.instance.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'attempted',
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Erreur log email: $e');
    }
  }

  /// Enregistre un succès d'envoi
  static Future<void> _logEmailSuccess(String email, String type) async {
    try {
      await FirebaseFirestore.instance.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
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
      await FirebaseFirestore.instance.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'failed',
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Erreur log failure: $e');
    }
  }

  /// Envoie un VRAI email via EmailJS
  ///
  /// ⛔ PROTECTION FIRESTORE : Vérifie le document config/emailKillSwitch
  /// avant tout envoi. Si le document a enabled=false, AUCUN email ne part.
  /// Ceci protège même contre du code caché dans les service workers.
  static Future<bool> _sendEmailViaEmailJS({
    required String to,
    required String subject,
    required String body,
    String? toName,
    bool isHtml = true,
  }) async {
    // ⛔ KILL SWITCH FIRESTORE GLOBAL — Vérifié AVANT tout envoi
    // Même l'ancien code caché dans les service workers passera par ici
    try {
      final killSwitchDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('emailKillSwitch')
          .get();
      if (killSwitchDoc.exists) {
        final data = killSwitchDoc.data();
        if (data != null && data['enabled'] == false) {
          debugPrint(
            '⛔ [FIRESTORE KILL SWITCH] Emails GLOBALEMENT DÉSACTIVÉS — $subject vers $to BLOQUÉ',
          );
          return false;
        }
      }
    } catch (e) {
      // En cas d'erreur de lecture, BLOQUER par sécurité
      debugPrint(
        '⛔ [FIRESTORE KILL SWITCH] Erreur lecture config → BLOQUÉ par sécurité: $e',
      );
      return false;
    }

    // Vérifier si EmailJS est configuré
    if (!EmailJSConfig.isConfigured) {
      debugPrint('⚠️ EmailJS non configuré ! Mode simulation activé.');
      debugPrint(EmailJSConfig.configurationHelp);

      // Mode simulation quand EmailJS n'est pas configuré
      await _logEmailAttempt(to, 'simulation', {'subject': subject});
      await _logEmailSuccess(to, 'simulation');
      return true;
    }

    try {
      await _logEmailAttempt(to, 'emailjs', {'subject': subject});

      // Paramètres correspondant exactement à votre template EmailJS
      final templateParams = {
        'email': to, // {{email}} dans votre template
        'name': toName ?? 'Cher client', // {{name}} dans votre template
        'subject': subject, // {{subject}} dans votre template
        'message': body, // {{message}} dans votre template
        'from_name': 'Chafin Loans', // {{from_name}} dans votre template
      };
      debugPrint('📧 EmailJS Request: to=$to, subject=$subject');
      debugPrint('📧 Template params keys: ${templateParams.keys.toList()}');

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': EmailJSConfig.serviceId,
          'template_id': EmailJSConfig.templateId,
          'user_id': EmailJSConfig.publicKey,
          'template_params': templateParams,
        }),
      );

      debugPrint('📧 EmailJS Response: ${response.statusCode}');
      debugPrint('📧 EmailJS Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ VRAI email envoyé à $to: $subject');
        await _logEmailSuccess(to, 'emailjs');
        return true;
      } else {
        final error = 'HTTP ${response.statusCode}: ${response.body}';
        debugPrint('❌ Échec EmailJS: $error');

        // Suggestions basées sur le code d'erreur
        if (response.statusCode == 422) {
          debugPrint(
            '💡 Erreur 422: Vérifiez que votre template EmailJS utilise les bonnes variables',
          );
          debugPrint(
            '💡 Variables communes: {{to_email}}, {{email}}, {{user_email}}',
          );
        }

        await _logEmailFailure(to, 'emailjs', error);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur EmailJS: $e');
      await _logEmailFailure(to, 'emailjs', e.toString());
      return false;
    }
  }

  static String _buildLoanRequestedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #333;">Demande de prêt soumise</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Votre demande de prêt a bien été soumise avec les détails suivants :</p>
            
            <div style="background-color: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant :</strong> ${loanData['amount']}€</p>
                <p><strong>Durée :</strong> ${loanData['duration']} mois</p>
                <p><strong>Taux :</strong> ${loanData['rate']}%</p>
            </div>
            
            <p>Votre demande est en cours de traitement. Vous recevrez une notification dès qu'une décision sera prise.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildLoanApprovedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #4CAF50;">🎉 Prêt Approuvé !</h2>
            
            <p>Félicitations $userName,</p>
            
            <p>Votre demande de prêt a été <strong>approuvée</strong> !</p>
            
            <div style="background-color: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant approuvé :</strong> ${loanData['amount']}€</p>
                <p><strong>Durée :</strong> ${loanData['duration']} mois</p>
                <p><strong>Taux :</strong> ${loanData['rate']}%</p>
                <p><strong>Première échéance :</strong> ${loanData['firstPayment']}</p>
            </div>
            
            <p>Vous pouvez maintenant consulter votre contrat et l'échéancier dans l'application.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildLoanRejectedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #f44336;">Demande de prêt refusée</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Nous regrettons de vous informer que votre demande de prêt n'a pas pu être approuvée cette fois-ci.</p>
            
            <p><strong>Raison :</strong> ${loanData['reason'] ?? 'Critères d\'éligibilité non remplis'}</p>
            
            <p>N'hésitez pas à soumettre une nouvelle demande ultérieurement.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildPaymentReminderEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #FF9800;">Rappel d'échéance</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Nous vous rappelons qu'une échéance de remboursement arrive bientôt :</p>
            
            <div style="background-color: #fff3e0; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant :</strong> ${loanData['amount']}€</p>
                <p><strong>Date d'échéance :</strong> ${loanData['dueDate']}</p>
                <p><strong>Prêt ID :</strong> ${loanData['loanId']}</p>
            </div>
            
            <p>Pensez à effectuer votre paiement avant la date d'échéance pour éviter les frais de retard.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildPaymentOverdueEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #f44336;">⚠️ Paiement en retard</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Votre paiement est maintenant en retard :</p>
            
            <div style="background-color: #ffebee; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant dû :</strong> ${loanData['amount']}€</p>
                <p><strong>Date d'échéance passée :</strong> ${loanData['dueDate']}</p>
                <p><strong>Jours de retard :</strong> ${loanData['daysOverdue']}</p>
                <p><strong>Frais de retard :</strong> ${loanData['lateFee']}€</p>
            </div>
            
            <p>Veuillez régulariser votre situation dans les plus brefs délais.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildLoanCompletedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #4CAF50;">🎉 Prêt Remboursé !</h2>
            
            <p>Félicitations $userName,</p>
            
            <p>Votre prêt a été entièrement remboursé avec succès !</p>
            
            <div style="background-color: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant total remboursé :</strong> ${loanData['totalAmount']}€</p>
                <p><strong>Date de fin :</strong> ${loanData['completionDate']}</p>
                <p><strong>Durée totale :</strong> ${loanData['duration']} mois</p>
            </div>
            
            <p>Merci de votre confiance. N'hésitez pas à revenir vers nous pour vos futurs besoins de financement.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildRateChangedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #00BCD4;">📊 Modification du taux d'intérêt</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Nous vous informons qu'une modification a été apportée au taux d'intérêt de votre prêt :</p>
            
            <div style="background-color: #e0f8ff; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Prêt ID :</strong> ${loanData['loanId']}</p>
                <p><strong>Ancien taux :</strong> ${loanData['oldRate']}%</p>
                <p><strong>Nouveau taux :</strong> ${loanData['newRate']}%</p>
                <p><strong>Nouvelle mensualité :</strong> ${loanData['newMonthlyPayment']}€</p>
                <p><strong>Nouveau coût total :</strong> ${loanData['newTotalCost']}€</p>
            </div>
            
            <p>Cette modification prend effet immédiatement. Vous pouvez consulter votre nouvel échéancier dans l'application.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildLoanDisbursedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #009688;">💰 Décaissement effectué</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Excellente nouvelle ! Le décaissement de votre prêt a été effectué avec succès.</p>
            
            <div style="background-color: #e0f2f1; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant décaissé :</strong> ${loanData['amount']}€</p>
                <p><strong>Date de décaissement :</strong> ${loanData['disbursementDate']}</p>
                <p><strong>Référence :</strong> ${loanData['reference']}</p>
                <p><strong>Première échéance :</strong> ${loanData['firstPaymentDate']}</p>
            </div>
            
            <p>Les fonds ont été transférés selon les modalités convenues. Votre échéancier de remboursement est maintenant actif.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildPaymentReceivedEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #4CAF50;">✅ Paiement reçu</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Nous confirmons la réception de votre paiement :</p>
            
            <div style="background-color: #e8f5e8; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Montant reçu :</strong> ${loanData['amount']}€</p>
                <p><strong>Date de réception :</strong> ${loanData['paymentDate']}</p>
                <p><strong>Échéance n° :</strong> ${loanData['scheduleNumber']}</p>
                <p><strong>Prêt ID :</strong> ${loanData['loanId']}</p>
            </div>
            
            <p>Merci pour votre paiement. Votre échéancier a été mis à jour.</p>
            
            <p>Cordialement,<br>L'équipe Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildAdminLoanRequestEmail(
    String userName,
    Map<String, dynamic> loanData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
            <h1 style="color: #2196F3; text-align: center;">Chafin Loans</h1>
            <h2 style="color: #FF5722;">🔔 Nouvelle demande de prêt</h2>
            
            <p>Bonjour $userName,</p>
            
            <p>Une nouvelle demande de prêt vient d'être soumise et nécessite votre attention :</p>
            
            <div style="background-color: #fff3e0; padding: 20px; border-radius: 5px; margin: 20px 0;">
                <p><strong>Emprunteur :</strong> ${loanData['borrowerName']}</p>
                <p><strong>Montant demandé :</strong> ${loanData['amount']}€</p>
                <p><strong>Durée :</strong> ${loanData['duration']} mois</p>
                <p><strong>Taux calculé :</strong> ${loanData['rate']}%</p>
                <p><strong>ID de la demande :</strong> ${loanData['loanId']}</p>
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="$_appUrl/admin/loans/${loanData['loanId']}" 
                   style="background-color: #2196F3; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">
                    Examiner la demande
                </a>
            </div>
            
            <p>Merci de traiter cette demande dans les plus brefs délais.</p>
            
            <p>Cordialement,<br>Système automatique Chafin Loans</p>
        </div>
    </body>
    </html>
    ''';
  }
}

/// Types d'emails pour les prêts
enum LoanEmailType {
  loanRequested, // ✅ Demande soumise par l'emprunteur
  loanApproved, // ✅ Prêt approuvé par admin
  loanRejected, // ✅ Prêt refusé par admin
  loanDisbursed, // ✅ Prêt décaissé (fonds virés)
  paymentReminder, // ✅ Rappel de paiement
  paymentOverdue, // ⚠️ Paiement en retard
  paymentReceived, // ✅ Paiement reçu
  loanCompleted, // ✅ Prêt entièrement remboursé
  rateChanged, // 📊 Taux d'intérêt modifié
  adminLoanRequest, // 👨‍💼 Nouvelle demande pour admin
}

/// Extensions pour le service EmailService
extension EmailServiceExtensions on EmailService {
  /// Formate une date pour l'affichage
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

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
          'dueDate': EmailServiceExtensions.formatDate(dueDate),
          'loanId': loanId,
          'adminMessage': adminMessage,
        },
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi du rappel manuel: $e');
      return false;
    }
  }

  /// Teste l'envoi d'email (à utiliser pour vérifier la configuration)
  static Future<bool> testEmailSending(String testEmail) async {
    debugPrint('🧪 Test d\'envoi d\'email à $testEmail');

    const testSubject = '🧪 Test Chafin Loans - Configuration EmailJS';
    final testBody =
        '''🎉 EmailJS fonctionne !

Si vous recevez cet email, la configuration EmailJS est correcte.

Service: Chafin Loans
Date: ${DateTime.now()}
Status: ✅ Configuration réussie

---
Ceci est un email de test automatique.''';

    return await EmailService.sendEmail(
      to: testEmail,
      subject: testSubject,
      body: testBody,
      toName: 'Testeur',
    );
  }

  /// Affiche le statut de la configuration EmailJS
  static void showConfigurationStatus() {
    if (EmailJSConfig.isConfigured) {
      debugPrint('✅ EmailJS configuré - Vrais emails activés');
    } else {
      debugPrint('⚠️ EmailJS non configuré - Mode simulation');
      debugPrint(EmailJSConfig.configurationHelp);
    }
  }
}
