import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan_model.dart';
import '../../config/app_theme.dart';

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header moderne style Revolut
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mes Prêts',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => context.go('/loan-request'),
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<LoanProvider>(
                    builder: (context, loanProvider, child) {
                      final totalAmount = loanProvider.userLoans
                          .where((loan) => loan.isActive || loan.isCompleted)
                          .fold(0.0, (sum, loan) => sum + loan.montant);

                      return Text(
                        'Total emprunté: ${NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0).format(totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Onglets modernes
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: AppTheme.primaryGradient,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondaryColor,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Actifs'),
                  Tab(text: 'En attente'),
                  Tab(text: 'Terminés'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Contenu des onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoansTab(LoanFilterType.active),
                  _buildLoansTab(LoanFilterType.pending),
                  _buildLoansTab(LoanFilterType.completed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoansTab(LoanFilterType filterType) {
    return Consumer<LoanProvider>(
      builder: (context, loanProvider, child) {
        List<LoanModel> filteredLoans;
        String emptyMessage;
        IconData emptyIcon;

        switch (filterType) {
          case LoanFilterType.active:
            filteredLoans = loanProvider.userLoans
                .where((loan) => loan.isActive)
                .toList();
            emptyMessage = 'Aucun prêt actif';
            emptyIcon = Icons.trending_up_outlined;
            break;
          case LoanFilterType.pending:
            filteredLoans = loanProvider.userLoans
                .where((loan) => loan.isPending)
                .toList();
            emptyMessage = 'Aucune demande en attente';
            emptyIcon = Icons.hourglass_empty_outlined;
            break;
          case LoanFilterType.completed:
            filteredLoans = loanProvider.userLoans
                .where((loan) => loan.isCompleted)
                .toList();
            emptyMessage = 'Aucun prêt terminé';
            emptyIcon = Icons.task_alt_outlined;
            break;
        }

        if (filteredLoans.isEmpty) {
          return _buildEmptyState(emptyMessage, emptyIcon);
        }

        return RefreshIndicator(
          onRefresh: () async {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.currentUser != null) {
              await loanProvider.loadUserLoans(authProvider.currentUser!.id);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filteredLoans.length,
            itemBuilder: (context, index) {
              return _buildModernLoanCard(filteredLoans[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tirez vers le bas pour actualiser',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoanCard(LoanModel loan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.go('/loan-details/${loan.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec montant et statut
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'fr_FR',
                        symbol: '€',
                        decimalDigits: 0,
                      ).format(loan.montant),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    _buildStatusChip(loan.statut),
                  ],
                ),
                const SizedBox(height: 12),

                // Informations détaillées
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                          'Durée',
                          '${loan.dureeMois} mois',
                          Icons.schedule,
                          Colors.blue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildInfoColumn(
                          'Taux',
                          '${loan.tauxAnnuel.toStringAsFixed(2)}%',
                          Icons.percent,
                          Colors.green,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      Expanded(
                        child: _buildInfoColumn(
                          'Mensualité',
                          '${loan.mensualite.toStringAsFixed(0)}€',
                          Icons.payment,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Date et action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Créé le ${DateFormat('dd/MM/yyyy').format(loan.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(LoanStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case LoanStatus.soumis:
      case LoanStatus.enRevue:
        color = Colors.orange;
        label = 'En attente';
        icon = Icons.hourglass_empty;
        break;
      case LoanStatus.approuve:
        color = Colors.green;
        label = 'Approuvé';
        icon = Icons.check_circle;
        break;
      case LoanStatus.enCours:
        color = Colors.blue;
        label = 'Actif';
        icon = Icons.trending_up;
        break;
      case LoanStatus.solde:
        color = Colors.green.shade700;
        label = 'Terminé';
        icon = Icons.task_alt;
        break;
      case LoanStatus.refuse:
      case LoanStatus.annule:
        color = Colors.red;
        label = 'Rejeté';
        icon = Icons.cancel;
        break;
      case LoanStatus.enRetard:
        color = Colors.red.shade700;
        label = 'En retard';
        icon = Icons.warning;
        break;
      default:
        color = Colors.grey;
        label = 'Brouillon';
        icon = Icons.edit;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum LoanFilterType { active, pending, completed }
