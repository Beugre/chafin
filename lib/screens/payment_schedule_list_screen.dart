import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../models/repayment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/borrower_provider.dart';

class PaymentScheduleListScreen extends StatefulWidget {
  const PaymentScheduleListScreen({super.key});

  @override
  State<PaymentScheduleListScreen> createState() =>
      _PaymentScheduleListScreenState();
}

class _PaymentScheduleListScreenState extends State<PaymentScheduleListScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final borrowerProvider = Provider.of<BorrowerProvider>(
      context,
      listen: false,
    );
    if (authProvider.currentUser != null) {
      await borrowerProvider.loadUserData(authProvider.currentUser!.id);
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Mes échéances',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: Consumer<BorrowerProvider>(
        builder: (context, borrowerProvider, child) {
          if (borrowerProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          }

          final loans = borrowerProvider.userLoans
              .where(
                (loan) =>
                    loan.statut == LoanStatus.enCours ||
                    loan.statut == LoanStatus.decaissementEffectue,
              )
              .toList();

          if (loans.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF6366F1),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loans.length,
              itemBuilder: (context, index) {
                final loan = loans[index];
                final loanRepayments =
                    borrowerProvider.userRepayments
                        .where((rep) => rep.loanId == loan.id)
                        .toList()
                      ..sort(
                        (a, b) => a.dateEcheance.compareTo(b.dateEcheance),
                      );

                return _buildLoanSection(loan, loanRepayments, index + 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune échéance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous n\'avez aucun prêt en cours',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSection(
    LoanModel loan,
    List<RepaymentModel> repayments,
    int loanNumber,
  ) {
    // Calculer les statistiques
    final totalPaid = repayments
        .where((r) => r.statut == RepaymentStatus.paye)
        .length;
    final totalPayments = repayments.length;
    final nextPayment = repayments.firstWhere(
      (r) => r.statut != RepaymentStatus.paye,
      orElse: () => repayments.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du prêt - Style Revolut
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prêt N°$loanNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalPaid/$totalPayments',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currencyFormat.format(loan.montant),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${loan.dureeMois} mois',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${loan.tauxAnnuel.toStringAsFixed(2)}% TEG',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barre de progression
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: totalPayments > 0
                        ? totalPaid / totalPayments
                        : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Prochaine échéance
          if (nextPayment.statut != RepaymentStatus.paye) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prochaine échéance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(nextPayment.dateEcheance),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currencyFormat.format(nextPayment.montantDu),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Liste des échéances
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: repayments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final repayment = repayments[index];
              return _buildRepaymentItem(repayment, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentItem(RepaymentModel repayment, int paymentNumber) {
    final isOverdue =
        repayment.statut != RepaymentStatus.paye &&
        repayment.dateEcheance.isBefore(DateTime.now());
    final isPaid = repayment.statut == RepaymentStatus.paye;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle;
      statusText = 'Payé';
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.error;
      statusText = 'En retard';
    } else {
      statusColor = const Color(0xFF6B7280);
      statusIcon = Icons.schedule;
      statusText = 'À venir';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? const Color(0xFFBBF7D0) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Numéro de l'échéance
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$paymentNumber',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Détails de l'échéance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dateFormat.format(repayment.dateEcheance),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(repayment.montantDu),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const Spacer(),
                    if (repayment.datePaiement != null)
                      Text(
                        'Payé le ${_dateFormat.format(repayment.datePaiement!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
