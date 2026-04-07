import 'package:flutter/material.dart';
import '../../services/email_service.dart';
import '../../config/emailjs_config.dart';

/// Écran de test et configuration EmailJS
class EmailJSTestScreen extends StatefulWidget {
  const EmailJSTestScreen({super.key});

  @override
  State<EmailJSTestScreen> createState() => _EmailJSTestScreenState();
}

class _EmailJSTestScreenState extends State<EmailJSTestScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    // Vérifier le statut de la configuration
    if (EmailJSConfig.isConfigured) {
      debugPrint('✅ EmailJS configuré - Vrais emails activés');
    } else {
      debugPrint('⚠️ EmailJS non configuré - Mode simulation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Test EmailJS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            if (!EmailJSConfig.isConfigured) ...[
              _buildConfigurationCard(),
              const SizedBox(height: 24),
            ],
            _buildTestCard(),
            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isConfigured = EmailJSConfig.isConfigured;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfigured ? Icons.check_circle : Icons.warning,
                  color: isConfigured ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isConfigured ? 'EmailJS Configuré' : 'Configuration Requise',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isConfigured ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isConfigured
                  ? 'EmailJS est configuré et prêt à envoyer de vrais emails.'
                  : 'EmailJS n\'est pas encore configuré. Les emails seront simulés.',
              style: const TextStyle(fontSize: 16),
            ),
            if (isConfigured) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Configuration active:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Service ID: ${EmailJSConfig.serviceId}'),
                    const Text('Template ID: ${EmailJSConfig.templateId}'),
                    Text(
                      'Public Key: ${EmailJSConfig.publicKey.substring(0, 8)}...',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Configuration EmailJS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                EmailJSConfig.configurationHelp,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Ouvrir les instructions dans un dialog
                _showConfigurationDialog();
              },
              icon: const Icon(Icons.launch),
              label: const Text('Ouvrir EmailJS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.email, color: Colors.indigo, size: 28),
                SizedBox(width: 12),
                Text(
                  'Test d\'envoi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Entrez votre email pour tester l\'envoi:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Votre email de test',
                hintText: 'exemple@gmail.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendTestEmail,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isLoading ? 'Envoi en cours...' : 'Envoyer email de test',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final isSuccess = _lastResult!.contains('✅');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isSuccess ? 'Succès !' : 'Erreur',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isSuccess ? Colors.green : Colors.red).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_lastResult!, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestEmail() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      // Test d'envoi d'email
      const testSubject = '🧪 Test Chafin Loans - Configuration EmailJS';
      const testBody = '''
      <!DOCTYPE html>
      <html>
      <body style="font-family: Arial, sans-serif; padding: 20px;">
          <h2 style="color: #2196F3;">🎉 EmailJS fonctionne !</h2>
          <p>Si vous recevez cet email, la configuration EmailJS est correcte.</p>
          <p><strong>Service:</strong> Chafin Loans</p>
          <p><strong>Status:</strong> ✅ Configuration réussie</p>
      </body>
      </html>
      ''';

      final success = await EmailService.sendEmail(
        to: _emailController.text.trim(),
        subject: testSubject,
        body: testBody,
        toName: 'Testeur',
      );

      setState(() {
        _lastResult = success
            ? '✅ Email de test envoyé avec succès !\n\nVérifiez votre boîte de réception (et les spams).'
            : '❌ Échec de l\'envoi.\n\nVérifiez votre configuration EmailJS et votre connexion internet.';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Email envoyé !' : 'Échec d\'envoi'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Erreur technique:\n\n$e';
        _isLoading = false;
      });
    }
  }

  void _showConfigurationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration EmailJS'),
        content: SingleChildScrollView(
          child: Text(EmailJSConfig.configurationHelp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
