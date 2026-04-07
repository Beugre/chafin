import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/loan_model.dart';
import '../../services/payment_reminder_service.dart';
import 'reminder_history_screen.dart';
import 'package:intl/intl.dart';

/// Écran d'administration pour l'envoi de rappels de paiement manuels
class PaymentReminderScreen extends StatefulWidget {
  const PaymentReminderScreen({super.key});

  @override
  State<PaymentReminderScreen> createState() => _PaymentReminderScreenState();
}

class _PaymentReminderScreenState extends State<PaymentReminderScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _showOnlyOverdue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = context.read<AdminProvider>();
      adminProvider.loadAllLoans();
      adminProvider
          .loadAllUsers(); // S'assurer que les utilisateurs sont chargés
    });
  }

  /// Récupère l'email d'un utilisateur depuis AdminProvider
  Future<String> _getUserEmail(String userId) async {
    final adminProvider = context.read<AdminProvider>();

    // Chercher dans le cache local d'abord
    final user = adminProvider.allUsers
        .where((u) => u.id == userId)
        .firstOrNull;
    if (user != null) {
      return user.email;
    }

    // Si pas trouvé, récupérer depuis Firebase
    final userFromDb = await adminProvider.getUserById(userId);
    return userFromDb?.email ?? 'Email non trouvé';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rappels de Paiement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReminderHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'Historique des rappels',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, adminProvider, child) {
                if (adminProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredLoans = _getFilteredLoans(adminProvider.allLoans);

                if (filteredLoans.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLoans.length,
                  itemBuilder: (context, index) {
                    return _buildLoanCard(filteredLoans[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom d\'emprunteur...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.indigo),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Afficher seulement les prêts en retard'),
                  value: _showOnlyOverdue,
                  onChanged: (bool? value) {
                    setState(() {
                      _showOnlyOverdue = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucun prêt trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Modifiez vos critères de recherche',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(LoanModel loan) {
    final isOverdue = _isLoanOverdue(loan);
    final nextPaymentDate = _getNextPaymentDate(loan);
    final daysOverdue = _getDaysOverdue(loan);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.nomEmprunteur,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: _getUserEmail(loan.userId),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              '📧 ${snapshot.data}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return Text(
                            'Chargement email...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${loan.id.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'EN RETARD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Montant', '${loan.montant.toStringAsFixed(2)} €'),
            _buildInfoRow('Statut', _getStatusText(loan.statut)),
            if (nextPaymentDate != null)
              _buildInfoRow(
                'Prochaine échéance',
                DateFormat('dd/MM/yyyy').format(nextPaymentDate),
              ),
            if (isOverdue && daysOverdue > 0)
              _buildInfoRow(
                'Retard',
                '$daysOverdue jour(s)',
                color: Colors.red,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _sendReminderEmail(loan, false),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Rappel standard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _sendReminderEmail(loan, true),
                    icon: const Icon(Icons.warning_outlined),
                    label: const Text('Rappel urgent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOverdue ? Colors.red : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<LoanModel> _getFilteredLoans(List<LoanModel> loans) {
    return loans.where((loan) {
      // Filtre par statut (prêts actifs et en retard)
      if (loan.statut != LoanStatus.enCours &&
          loan.statut != LoanStatus.enRetard &&
          loan.statut != LoanStatus.decaissementEffectue) {
        return false;
      }

      // Filtre par recherche
      if (_searchQuery.isNotEmpty) {
        if (!loan.nomEmprunteur.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }

      // Filtre par retard
      if (_showOnlyOverdue) {
        if (!_isLoanOverdue(loan)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _isLoanOverdue(LoanModel loan) {
    final nextPayment = _getNextPaymentDate(loan);
    if (nextPayment == null) return false;

    final now = DateTime.now();
    return nextPayment.isBefore(DateTime(now.year, now.month, now.day));
  }

  DateTime? _getNextPaymentDate(LoanModel loan) {
    // Pour simplifier, nous utilisons la date de premier remboursement
    // Dans un vrai système, il faudrait calculer based sur l'échéancier
    final now = DateTime.now();
    if (loan.datePremierRemboursement.isAfter(now)) {
      return loan.datePremierRemboursement;
    }

    // Calcul approximatif de la prochaine échéance (mensuelle)
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

  int _getDaysOverdue(LoanModel loan) {
    final nextPayment = _getNextPaymentDate(loan);
    if (nextPayment == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final paymentDay = DateTime(
      nextPayment.year,
      nextPayment.month,
      nextPayment.day,
    );

    if (paymentDay.isBefore(today)) {
      return today.difference(paymentDay).inDays;
    }

    return 0;
  }

  String _getStatusText(LoanStatus status) {
    switch (status) {
      case LoanStatus.brouillon:
        return 'Brouillon';
      case LoanStatus.soumis:
        return 'Soumis';
      case LoanStatus.enRevue:
        return 'En révision';
      case LoanStatus.approuve:
        return 'Approuvé';
      case LoanStatus.refuse:
        return 'Refusé';
      case LoanStatus.decaissementEffectue:
        return 'Décaissé';
      case LoanStatus.enCours:
        return 'En cours';
      case LoanStatus.solde:
        return 'Soldé';
      case LoanStatus.enRetard:
        return 'En retard';
      case LoanStatus.annule:
        return 'Annulé';
      case LoanStatus.ferme:
        return 'Fermé';
    }
  }

  Future<void> _sendReminderEmail(LoanModel loan, bool isUrgent) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PaymentReminderService.sendManualReminder(
        loanId: loan.id,
        type: isUrgent ? ReminderType.urgent : ReminderType.standard,
        customMessage: isUrgent
            ? 'Rappel urgent de paiement - Votre échéance est en retard'
            : 'Rappel de paiement - N\'oubliez pas votre prochaine échéance',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Rappel envoyé avec succès à ${loan.nomEmprunteur}'
                  : 'Erreur lors de l\'envoi du rappel',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
