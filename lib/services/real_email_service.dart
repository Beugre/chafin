import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service d'email utilisant EmailJS (fonctionne avec Flutter Web)
class RealEmailService {
  // Configuration EmailJS (gratuit, fonctionne avec Flutter Web)
  static const String _serviceId = 'YOUR_EMAILJS_SERVICE_ID';
  static const String _templateId = 'YOUR_EMAILJS_TEMPLATE_ID';
  static const String _publicKey = 'YOUR_EMAILJS_PUBLIC_KEY';
  static const String _emailJsUrl =
      'https://api.emailjs.com/api/v1.0/email/send';

  /// Envoie un vrai email via EmailJS
  static Future<bool> sendRealEmail({
    required String to,
    required String subject,
    required String body,
    String? toName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': to,
            'to_name': toName ?? 'Cher client',
            'subject': subject,
            'message': body,
            'from_name': 'Chafin Loans',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email réel envoyé à $to');
        await _logEmailSuccess(to, 'real_email');
        return true;
      } else {
        debugPrint('❌ Échec envoi email: ${response.statusCode}');
        await _logEmailFailure(to, 'real_email', 'HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur envoi email réel: $e');
      await _logEmailFailure(to, 'real_email', e.toString());
      return false;
    }
  }

  /// Utilise SendGrid (service professionnel)
  static Future<bool> sendWithSendGrid({
    required String to,
    required String subject,
    required String body,
    String? toName,
  }) async {
    const apiKey = 'YOUR_SENDGRID_API_KEY';

    try {
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'personalizations': [
            {
              'to': [
                {'email': to, 'name': toName ?? 'Cher client'},
              ],
              'subject': subject,
            },
          ],
          'from': {'email': 'noreply@chafin.com', 'name': 'Chafin Loans'},
          'content': [
            {'type': 'text/html', 'value': body},
          ],
        }),
      );

      if (response.statusCode == 202) {
        debugPrint('✅ Email SendGrid envoyé à $to');
        return true;
      } else {
        debugPrint('❌ Échec SendGrid: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur SendGrid: $e');
      return false;
    }
  }

  static Future<void> _logEmailSuccess(String email, String type) async {
    try {
      await FirebaseFirestore.instance.collection('email_logs').add({
        'email': email,
        'type': type,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
        'service': 'real_email',
      });
    } catch (e) {
      debugPrint('❌ Erreur log: $e');
    }
  }

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
        'service': 'real_email',
      });
    } catch (e) {
      debugPrint('❌ Erreur log: $e');
    }
  }
}
