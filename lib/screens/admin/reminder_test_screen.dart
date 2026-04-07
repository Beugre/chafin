import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/loan_model.dart';
import '../../services/payment_reminder_service.dart';

/// Écran de test pour les rappels d'échéance
class ReminderTestScreen extends StatefulWidget {
  const ReminderTestScreen({super.key});

  @override
  State<ReminderTestScreen> createState() => _ReminderTestScreenState();
}

class _ReminderTestScreenState extends State<ReminderTestScreen> {
  String? _lastResult;
  bool _isLoading = false;
  LoanModel? _selectedLoan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAllAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Rappels d\'Échéance'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeLoans = adminProvider.allLoans
              .where((loan) => loan.statut == LoanStatus.enCours)
              .toList();

          return Padding(
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
                          'Test des Rappels d\'Échéance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Prêts actifs trouvés: ${activeLoans.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown pour sélectionner un prêt
                        DropdownButton<LoanModel>(
                          isExpanded: true,
                          hint: const Text('Sélectionner un prêt à tester'),
                          value: _selectedLoan,
                          items: activeLoans.map((loan) {
                            return DropdownMenuItem(
                              value: loan,
                              child: FutureBuilder<String>(
                                future: _getUserInfo(
                                  loan.userId,
                                  adminProvider,
                                ),
                                builder: (context, snapshot) {
                                  final userInfo =
                                      snapshot.data ?? 'Chargement...';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        loan.nomEmprunteur,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '📧 $userInfo',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        '💰 ${loan.montant.toStringAsFixed(0)}€ - ${loan.mensualite.toStringAsFixed(0)}€/mois',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          }).toList(),
                          onChanged: (loan) {
                            setState(() {
                              _selectedLoan = loan;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Boutons de test
                if (_selectedLoan != null) ...[
                  _buildTestButton(
                    'Rappel Standard',
                    ReminderType.standard,
                    Colors.blue,
                    Icons.schedule,
                  ),
                  const SizedBox(height: 8),
                  _buildTestButton(
                    'Rappel Urgent',
                    ReminderType.urgent,
                    Colors.orange,
                    Icons.warning,
                  ),
                  const SizedBox(height: 8),
                  _buildTestButton(
                    'Paiement en Retard',
                    ReminderType.overdue,
                    Colors.red,
                    Icons.error,
                  ),
                ],

                const SizedBox(height: 16),

                // Résultat du dernier test
                if (_lastResult != null)
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    ReminderType type,
    Color color,
    IconData icon,
  ) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _sendTestReminder(type),
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Future<void> _sendTestReminder(ReminderType type) async {
    if (_selectedLoan == null) return;

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final success = await PaymentReminderService.sendManualReminder(
        loanId: _selectedLoan!.id,
        type: type,
        customMessage:
            'Test de rappel ${type.toString().split('.').last} depuis l\'interface admin',
        adminId: 'TEST_ADMIN',
      );

      setState(() {
        _lastResult = success
            ? '✅ Rappel ${type.toString().split('.').last} envoyé avec succès à ${_selectedLoan!.nomEmprunteur}'
            : '❌ Échec de l\'envoi du rappel ${type.toString().split('.').last}';
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

  Future<String> _getUserInfo(
    String userId,
    AdminProvider adminProvider,
  ) async {
    final user = adminProvider.allUsers
        .where((u) => u.id == userId)
        .firstOrNull;
    if (user != null) {
      return user.email;
    }

    final userFromDb = await adminProvider.getUserById(userId);
    return userFromDb?.email ?? 'Email non trouvé';
  }
}
