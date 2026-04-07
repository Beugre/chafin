import 'package:flutter/material.dart';
import '../../services/email_service.dart';

/// Écran de test pour les notifications de prêts
class LoanNotificationsTestScreen extends StatefulWidget {
  const LoanNotificationsTestScreen({super.key});

  @override
  State<LoanNotificationsTestScreen> createState() =>
      _LoanNotificationsTestScreenState();
}

class _LoanNotificationsTestScreenState
    extends State<LoanNotificationsTestScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _lastResult;

  // Données de test pour un prêt fictif
  final Map<String, dynamic> _testLoanData = {
    'amount': '5000',
    'duration': '24',
    'rate': '7.50',
    'loanId': 'LOAN_TEST_123',
    'submittedDate': '10/10/2025',
    'approvedDate': '11/10/2025',
    'rejectedDate': '11/10/2025',
    'disbursedDate': '12/10/2025',
    'firstPaymentDate': '12/11/2025',
    'monthlyPayment': '228.85',
    'reference': 'REF_CHAFIN_2025_001',
    'reason':
        'Capacité de remboursement insuffisante suite à l\'analyse de votre dossier financier.',
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _testNotification(LoanEmailType type) async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un email de test')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final success = await EmailService.sendLoanNotificationEmail(
        to: _emailController.text.trim(),
        userName: 'Test Utilisateur',
        type: type,
        loanData: _testLoanData,
      );

      setState(() {
        _lastResult = success
            ? '✅ Email ${_getEmailTypeName(type)} envoyé avec succès !'
            : '❌ Échec de l\'envoi de l\'email ${_getEmailTypeName(type)}';
      });
    } catch (e) {
      setState(() {
        _lastResult = '❌ Erreur: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getEmailTypeName(LoanEmailType type) {
    switch (type) {
      case LoanEmailType.loanRequested:
        return 'Demande soumise';
      case LoanEmailType.loanApproved:
        return 'Prêt approuvé';
      case LoanEmailType.loanRejected:
        return 'Prêt refusé';
      case LoanEmailType.loanDisbursed:
        return 'Décaissement';
      case LoanEmailType.paymentReminder:
        return 'Rappel de paiement';
      case LoanEmailType.paymentOverdue:
        return 'Paiement en retard';
      case LoanEmailType.paymentReceived:
        return 'Paiement reçu';
      case LoanEmailType.loanCompleted:
        return 'Prêt terminé';
      case LoanEmailType.rateChanged:
        return 'Taux modifié';
      case LoanEmailType.adminLoanRequest:
        return 'Nouvelle demande (Admin)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications Prêts'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📧 Configuration Email',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email de test',
                        hintText: 'votre.email@exemple.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔔 Notifications de Prêts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Données de test utilisées:'),
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Montant: ${_testLoanData['amount']}€\n'
                        'Durée: ${_testLoanData['duration']} mois\n'
                        'Taux: ${_testLoanData['rate']}%\n'
                        'Mensualité: ${_testLoanData['monthlyPayment']}€',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildTestButton(
                    'Demande soumise',
                    LoanEmailType.loanRequested,
                    Colors.blue,
                    Icons.send,
                  ),
                  _buildTestButton(
                    'Prêt approuvé',
                    LoanEmailType.loanApproved,
                    Colors.green,
                    Icons.check_circle,
                  ),
                  _buildTestButton(
                    'Prêt refusé',
                    LoanEmailType.loanRejected,
                    Colors.red,
                    Icons.cancel,
                  ),
                  _buildTestButton(
                    'Décaissement',
                    LoanEmailType.loanDisbursed,
                    Colors.purple,
                    Icons.account_balance,
                  ),
                  _buildTestButton(
                    'Rappel paiement',
                    LoanEmailType.paymentReminder,
                    Colors.orange,
                    Icons.schedule,
                  ),
                  _buildTestButton(
                    'Paiement reçu',
                    LoanEmailType.paymentReceived,
                    Colors.teal,
                    Icons.payment,
                  ),
                ],
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _lastResult!.startsWith('✅')
                    ? Colors.green[50]
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _lastResult!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _lastResult!.startsWith('✅')
                          ? Colors.green[800]
                          : Colors.red[800],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    LoanEmailType type,
    Color color,
    IconData icon,
  ) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _testNotification(type),
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(
        title,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }
}
