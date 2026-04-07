import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan_model.dart';

class BorrowerDashboardScreen extends StatefulWidget {
  const BorrowerDashboardScreen({super.key});

  @override
  State<BorrowerDashboardScreen> createState() =>
      _BorrowerDashboardScreenState();
}

class _BorrowerDashboardScreenState extends State<BorrowerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserLoans();
    });
  }

  void _loadUserLoans() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);

    print('🔍 [DEBUG DASHBOARD] Tentative chargement prêts');
    print(
      '🔍 [DEBUG DASHBOARD] User connecté: ${authProvider.currentUser != null}',
    );
    if (authProvider.currentUser != null) {
      print('🔍 [DEBUG DASHBOARD] User ID: ${authProvider.currentUser!.id}');
      print(
        '🔍 [DEBUG DASHBOARD] User Email: ${authProvider.currentUser!.email}',
      );
      // Recharger les prêts depuis Firebase
      loanProvider.loadUserLoans(authProvider.currentUser!.id);
    } else {
      print('❌ [DEBUG DASHBOARD] Aucun utilisateur connecté!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Consumer2<AuthProvider, LoanProvider>(
          builder: (context, authProvider, loanProvider, child) {
            final user = authProvider.currentUser;

            // Afficher un indicateur de chargement pendant la déconnexion
            if (authProvider.isLoading && user == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00D4FF)),
                    SizedBox(height: 16),
                    Text('Déconnexion en cours...'),
                  ],
                ),
              );
            }
            final loans = loanProvider.userLoans;

            if (user == null) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header moderne avec gradient
                  _buildModernHeader(user, context),

                  // Bannière d'alerte risque si nécessaire
                  if ((user.niveauConfiance ?? 5.0) < 2.0)
                    _buildRiskWarningBanner(),

                  const SizedBox(height: 30),

                  // Statistiques modernes
                  _buildModernStatsSection(loans),

                  const SizedBox(height: 30),

                  // Actions rapides
                  _buildModernQuickActions(context),

                  const SizedBox(height: 30),

                  // Prêts récents
                  _buildRecentLoansSection(loans),

                  const SizedBox(height: 100), // Espace pour le bottom nav
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernHeader(dynamic user, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        user.nom.isNotEmpty ? user.nom[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonjour,',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        user.nom,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadUserLoans,
                  tooltip: 'Actualiser',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Gérez vos prêts facilement',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatsSection(List<LoanModel> loans) {
    final activeLoans = loans.where((l) => l.isActive).length;
    final pendingLoans = loans.where((l) => l.isPending).length;
    final totalAmount = loans
        .where((l) => l.isActive || l.isCompleted)
        .fold(0.0, (sum, loan) => sum + loan.montant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildModernStatCard(
              'Prêts Actifs',
              activeLoans.toString(),
              Icons.trending_up,
              Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildModernStatCard(
              'En Attente',
              pendingLoans.toString(),
              Icons.hourglass_empty,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildModernStatCard(
              'Total',
              '${totalAmount.toStringAsFixed(0)}€',
              Icons.euro,
              const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Niveau de risque élevé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos taux d\'intérêt sont majorés. Régularisez vos paiements pour améliorer votre profil.',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModernActionCard(
                  'Nouveau Prêt',
                  'Faire une demande',
                  Icons.add_circle,
                  const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  () => context.go('/loan-request'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModernActionCard(
                  'Mes Prêts',
                  'Voir tous mes prêts',
                  Icons.account_balance_wallet,
                  LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  () => context.go('/my-loans'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionCard(
    String title,
    String subtitle,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentLoansSection(List<LoanModel> loans) {
    final recentLoans = loans.take(3).toList();

    if (recentLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prêts récents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/my-loans'),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentLoans.map((loan) => _buildRecentLoanCard(loan)),
        ],
      ),
    );
  }

  Widget _buildRecentLoanCard(LoanModel loan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go('/loan-details/${loan.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getStatusColor(loan.statut).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.euro,
                    color: _getStatusColor(loan.statut),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loan.montant.toStringAsFixed(0)}€',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${loan.dureeMois} mois • ${loan.tauxAnnuel.toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(loan.statut).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(loan.statut),
                        style: TextStyle(
                          color: _getStatusColor(loan.statut),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
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

  Color _getStatusColor(LoanStatus status) {
    switch (status) {
      case LoanStatus.soumis:
      case LoanStatus.enRevue:
        return Colors.orange;
      case LoanStatus.approuve:
        return Colors.green;
      case LoanStatus.enCours:
        return Colors.blue;
      case LoanStatus.solde:
        return Colors.green.shade700;
      case LoanStatus.refuse:
      case LoanStatus.annule:
        return Colors.red;
      case LoanStatus.enRetard:
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(LoanStatus status) {
    switch (status) {
      case LoanStatus.soumis:
      case LoanStatus.enRevue:
        return 'En attente';
      case LoanStatus.approuve:
        return 'Approuvé';
      case LoanStatus.enCours:
        return 'Actif';
      case LoanStatus.solde:
        return 'Terminé';
      case LoanStatus.refuse:
      case LoanStatus.annule:
        return 'Rejeté';
      case LoanStatus.enRetard:
        return 'En retard';
      default:
        return 'Brouillon';
    }
  }
}
