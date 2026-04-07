/// Configuration EmailJS pour l'envoi de vrais emails
library;

/// Configuration EmailJS pour l'envoi de vrais emails
///
/// ÉTAPES POUR CONFIGURER :
/// 1. Allez sur https://www.emailjs.com/
/// 2. Créez un compte gratuit (100 emails/mois)
/// 3. Configurez votre service email : Gmail, Outlook, Yahoo, ou SMTP personnalisé (OVH)
/// 4. Créez un template d'email
/// 5. Remplacez les valeurs ci-dessous par vos vraies valeurs
/// 6. Testez !
class EmailJSConfig {
  // ⚠️ REMPLACEZ CES VALEURS PAR VOS VRAIES VALEURS EMAILJS
  static const String serviceId = 'service_s6kh76e';
  static const String templateId = 'template_byf1fdm';
  static const String publicKey = 'sUFWr-XkJM8NcZQ86';

  // Template EmailJS recommandé :
  // Subject: {{subject}}
  // To: {{to_email}}
  // From: {{from_name}} <{{reply_to}}>
  // Body: {{message}}

  /// Vérifie si EmailJS est configuré
  static bool get isConfigured {
    return serviceId != 'YOUR_SERVICE_ID' &&
        templateId != 'YOUR_TEMPLATE_ID' &&
        publicKey != 'YOUR_PUBLIC_KEY';
  }

  /// Message d'aide pour la configuration
  static String get configurationHelp => '''
📧 CONFIGURATION EMAILJS REQUISE

1. Créez un compte sur https://www.emailjs.com/
2. Configurez votre service email (Gmail, OVH, etc.)
3. Créez un template avec ces variables :
   - {{to_email}} : Email du destinataire
   - {{to_name}} : Nom du destinataire  
   - {{subject}} : Sujet de l'email
   - {{message}} : Corps de l'email (HTML)
   - {{from_name}} : Nom de l'expéditeur
   - {{reply_to}} : Email de réponse

4. Remplacez les valeurs dans EmailJSConfig :
   - serviceId: Votre Service ID
   - templateId: Votre Template ID
   - publicKey: Votre Public Key

5. Pour OVH, utilisez ces paramètres SMTP :
   - Host: ssl0.ovh.net
   - Port: 465 (SSL) ou 587 (STARTTLS)
   - Username: chafin@finimoi.com
   - Password: votre mot de passe OVH
''';
}
