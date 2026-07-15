import 'package:flutter/material.dart';
import '../../services/email_service.dart';

/// Écran de test pour les notifications par email
class EmailTestScreen extends StatefulWidget {
  const EmailTestScreen({super.key});

  @override
  State<EmailTestScreen> createState() => _EmailTestScreenState();
}

class _EmailTestScreenState extends State<EmailTestScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _resultMessage;
  Color _resultColor = Colors.green;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _testEmail(LoanEmailType type) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _resultMessage = null;
    });

    try {
      final success = await EmailService.sendLoanNotificationEmail(
        to: _emailController.text.trim(),
        userName: 'Test User',
        type: type,
        loanData: _getTestDataForType(type),
      );

      setState(() {
        _resultMessage = success
            ? '✅ Email de test envoyé avec succès !'
            : '❌ Échec de l\'envoi de l\'email';
        _resultColor = success ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _resultMessage = '❌ Erreur: ${e.toString()}';
        _resultColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getTestDataForType(LoanEmailType type) {
    switch (type) {
      case LoanEmailType.loanRequested:
        return {'amount': '2000', 'duration': '12', 'rate': '20.0'};
      case LoanEmailType.loanApproved:
        return {
          'amount': '2000',
          'duration': '12',
          'rate': '20.0',
          'firstPayment': '2024-12-01',
        };
      case LoanEmailType.loanRejected:
        return {
          'amount': '2000',
          'duration': '12',
          'reason': 'Test de refus pour démonstration',
        };
      case LoanEmailType.paymentReminder:
        return {'amount': '200', 'dueDate': '2024-12-01', 'loanId': 'TEST-001'};
      case LoanEmailType.paymentOverdue:
        return {
          'amount': '200',
          'dueDate': '2024-11-01',
          'daysOverdue': '15',
          'lateFee': '10',
        };
      case LoanEmailType.loanCompleted:
        return {
          'totalAmount': '2400',
          'completionDate': '2024-11-20',
          'duration': '12',
        };
      case LoanEmailType.rateChanged:
        return {
          'loanId': 'TEST-001',
          'oldRate': '20.0',
          'newRate': '15.0',
          'newMonthlyPayment': '180',
          'newTotalCost': '2160',
        };
      case LoanEmailType.loanDisbursed:
        return {
          'amount': '2000',
          'disbursementDate': '2024-11-20',
          'reference': 'VIR-TEST-001',
          'firstPaymentDate': '2024-12-20',
        };
      case LoanEmailType.paymentReceived:
        return {
          'amount': '200',
          'paymentDate': '2024-11-20',
          'scheduleNumber': '1',
          'loanId': 'TEST-001',
        };
      case LoanEmailType.adminLoanRequest:
        return {
          'borrowerName': 'Test Emprunteur',
          'amount': '2000',
          'duration': '12',
          'rate': '20.0',
          'loanId': 'TEST-001',
        };
      case LoanEmailType.referralLoanRequested:
        return {'filleulName': 'Test Filleul', 'amount': '2000'};
      case LoanEmailType.referralLoanDisbursed:
        return {
          'filleulName': 'Test Filleul',
          'amount': '2000',
          'interets': '200',
          'commission': '40',
        };
      case LoanEmailType.referralCommissionPaid:
        return {'filleulName': 'Test Filleul', 'commission': '40'};
    }
  }

  Widget _buildTestButton(
    LoanEmailType type,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _testEmail(type),
        icon: Icon(icon, size: 20),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Test des emails'),
        backgroundColor: const Color(0xFF0A0E27),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Test des notifications par email',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Utilisez cet écran pour tester l\'envoi d\'emails pour différents types de notifications. '
                        'Entrez votre adresse email ci-dessous et cliquez sur le type d\'email à tester.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Champ email
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adresse email de test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'votre.email@exemple.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer une adresse email';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Adresse email invalide';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Types d'emails à tester
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Types d\'emails à tester',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Emails pour emprunteurs
                      const Text(
                        'Notifications emprunteur',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTestButton(
                        LoanEmailType.loanRequested,
                        'Demande soumise',
                        Icons.send,
                        Colors.blue,
                      ),
                      _buildTestButton(
                        LoanEmailType.loanApproved,
                        'Prêt approuvé',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildTestButton(
                        LoanEmailType.loanRejected,
                        'Prêt refusé',
                        Icons.cancel,
                        Colors.red,
                      ),
                      _buildTestButton(
                        LoanEmailType.loanDisbursed,
                        'Décaissement effectué',
                        Icons.payment,
                        Colors.teal,
                      ),
                      _buildTestButton(
                        LoanEmailType.paymentReminder,
                        'Rappel d\'échéance',
                        Icons.schedule,
                        Colors.orange,
                      ),
                      _buildTestButton(
                        LoanEmailType.paymentOverdue,
                        'Paiement en retard',
                        Icons.warning,
                        Colors.deepOrange,
                      ),
                      _buildTestButton(
                        LoanEmailType.paymentReceived,
                        'Paiement reçu',
                        Icons.check,
                        Colors.green.shade700,
                      ),
                      _buildTestButton(
                        LoanEmailType.rateChanged,
                        'Taux modifié',
                        Icons.trending_up,
                        Colors.cyan,
                      ),
                      _buildTestButton(
                        LoanEmailType.loanCompleted,
                        'Prêt soldé',
                        Icons.celebration,
                        Colors.purple,
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Emails pour admins
                      const Text(
                        'Notifications administrateur',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTestButton(
                        LoanEmailType.adminLoanRequest,
                        'Nouvelle demande (Admin)',
                        Icons.notifications,
                        Colors.indigo,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Résultat
              if (_resultMessage != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _resultColor == Colors.green
                              ? Icons.check_circle
                              : Icons.error,
                          color: _resultColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _resultMessage!,
                            style: TextStyle(
                              color: _resultColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Indicateur de chargement
              if (_isLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Envoi de l\'email en cours...'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
