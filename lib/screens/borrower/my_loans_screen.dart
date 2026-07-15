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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLoans());
  }

  void _loadLoans() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loans = Provider.of<LoanProvider>(context, listen: false);
    if (auth.currentUser != null) {
      loans.loadUserLoans(auth.currentUser!.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanProvider = context.watch<LoanProvider>();
    final allLoans = loanProvider.userLoans;
    final isLoading = loanProvider.isLoading;

    final activeLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.enCours || l.statut == LoanStatus.enRetard,
        )
        .toList();
    final pendingLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.brouillon ||
              l.statut == LoanStatus.soumis ||
              l.statut == LoanStatus.enRevue ||
              l.statut == LoanStatus.approuve ||
              l.statut == LoanStatus.decaissementEffectue,
        )
        .toList();
    final completedLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.solde ||
              l.statut == LoanStatus.ferme ||
              l.statut == LoanStatus.refuse ||
              l.statut == LoanStatus.annule,
        )
        .toList();

    final totalAmount = allLoans
        .where((l) => l.isActive || l.isCompleted)
        .fold(0.0, (sum, l) => sum + l.montant);
    final activeCount = activeLoans.length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header dark — cohérent avec le dashboard
          Container(
            width: double.infinity,
            color: const Color(0xFF0F1629),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MES PRÊTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/loan-request'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Demande',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      NumberFormat.currency(
                        locale: 'fr_FR',
                        symbol: '€',
                        decimalDigits: 0,
                      ).format(totalAmount),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeCount == 0
                          ? 'Aucun prêt actif'
                          : '$activeCount prêt${activeCount > 1 ? 's' : ''} en cours',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Onglets — segmented control style
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.textPrimaryColor,
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
                Tab(text: 'En cours'),
                Tab(text: 'En attente'),
                Tab(text: 'Soldés'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoansTab(
                  activeLoans,
                  'Aucun prêt en cours',
                  Icons.trending_up_outlined,
                  isLoading,
                ),
                _buildLoansTab(
                  pendingLoans,
                  'Aucune demande en attente',
                  Icons.hourglass_empty_outlined,
                  isLoading,
                ),
                _buildLoansTab(
                  completedLoans,
                  'Aucun prêt terminé',
                  Icons.task_alt_outlined,
                  isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansTab(
    List<LoanModel> loans,
    String emptyMessage,
    IconData emptyIcon,
    bool isLoading,
  ) {
    if (isLoading && loans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2,
        ),
      );
    }
    if (loans.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyIcon);
    }
    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final lp = context.read<LoanProvider>();
        if (auth.currentUser != null) {
          await lp.loadUserLoans(auth.currentUser!.id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: loans.length,
        itemBuilder: (context, index) {
          return _buildModernLoanCard(loans[index]);
        },
      ),
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
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 64, color: AppTheme.textHintColor),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tirez vers le bas pour actualiser',
            style: TextStyle(fontSize: 14, color: AppTheme.textHintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoanCard(LoanModel loan) {
    double progress = 0.0;
    int monthsRemaining = loan.dureeMois;
    if (loan.isActive && loan.disbursedAt != null) {
      final monthsElapsed =
          DateTime.now().difference(loan.disbursedAt!).inDays / 30.44;
      progress = (monthsElapsed / loan.dureeMois).clamp(0.0, 1.0);
      monthsRemaining = (loan.dureeMois - monthsElapsed.floor()).clamp(
        0,
        loan.dureeMois,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go('/loan-details/${loan.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            NumberFormat.currency(
                              locale: 'fr_FR',
                              symbol: '€',
                              decimalDigits: 0,
                            ).format(loan.montant),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${loan.dureeMois} mois · ${loan.tauxAnnuel.toStringAsFixed(1)}% · ${loan.mensualite.toStringAsFixed(0)} €/mois',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(loan.statut),
                  ],
                ),
                if (loan.isActive && loan.disbursedAt != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$monthsRemaining mois restants',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}% remboursé',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFF0F1F5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy', 'fr_FR').format(loan.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHintColor,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 13,
                      color: AppTheme.textHintColor,
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

  Widget _buildStatusChip(LoanStatus status) {
    Color color;
    String label;

    switch (status) {
      case LoanStatus.soumis:
      case LoanStatus.enRevue:
        color = AppTheme.warningColor;
        label = 'En attente';
        break;
      case LoanStatus.approuve:
        color = AppTheme.successColor;
        label = 'Approuvé';
        break;
      case LoanStatus.enCours:
        color = AppTheme.primaryColor;
        label = 'Actif';
        break;
      case LoanStatus.solde:
        color = AppTheme.textHintColor;
        label = 'Soldé';
        break;
      case LoanStatus.refuse:
      case LoanStatus.annule:
        color = AppTheme.errorColor;
        label = 'Rejeté';
        break;
      case LoanStatus.enRetard:
        color = AppTheme.errorColor;
        label = 'En retard';
        break;
      default:
        color = AppTheme.textHintColor;
        label = 'Brouillon';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
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
