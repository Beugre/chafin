import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/loan_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/csv_export_service.dart';
import 'global_summary_tab.dart';

class ModernAdminDashboardScreen extends StatefulWidget {
  const ModernAdminDashboardScreen({super.key});

  @override
  State<ModernAdminDashboardScreen> createState() =>
      _ModernAdminDashboardScreenState();
}

class _ModernAdminDashboardScreenState extends State<ModernAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '€',
    decimalDigits: 0,
  );
  String _chartPeriod = '6m'; // '3m', '6m', '1a', 'tout'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Charger les données au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadAllAdminData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    await adminProvider.loadAllAdminData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: _buildModernAppBar(),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading && adminProvider.allLoans.isEmpty) {
            return _buildLoadingState();
          }

          if (adminProvider.error != null) {
            return _buildErrorState(adminProvider.error!);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(adminProvider),
              const GlobalSummaryTab(),
              _buildStatsTab(adminProvider),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E27),
      elevation: 0,
      title: const Text(
        'Chafin Admin',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<int>(
            stream: ChatService().getTotalUnreadForAdmin(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push('/admin/chat'),
                    tooltip: 'Messagerie',
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Actualiser',
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF00D4FF),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        isScrollable: true,
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'Résumé Global'),
          Tab(text: 'Statistiques'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des données...',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erreur: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(AdminProvider adminProvider) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00D4FF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec salutation
            _buildWelcomeHeader(),
            const SizedBox(height: 24),

            // Cartes de statistiques principales
            _buildStatsCards(adminProvider),
            const SizedBox(height: 16),

            // 📈 CARTE DE RENDEMENT TOTAL
            _buildRendementCard(adminProvider),
            const SizedBox(height: 24),

            // Graphique de répartition des prêts
            _buildLoanStatusChart(adminProvider),
            const SizedBox(height: 24),

            // Évolution des prêts dans le temps
            _buildPeriodSelector(),
            const SizedBox(height: 12),
            _buildLoanTrendChart(adminProvider),
            const SizedBox(height: 24),

            // 💹 Courbe PnL mensuelle
            _buildPnLChart(adminProvider),
            const SizedBox(height: 24),

            // � Tableau de recouvrement
            _buildRecoveryTable(adminProvider),
            const SizedBox(height: 24),

            // �📊 KPIs Avancés
            _buildAdvancedKPIs(adminProvider),
            const SizedBox(height: 24),

            // 🤝 Section Parrainages
            _buildReferralSection(adminProvider),
            const SizedBox(height: 24),

            // 📥 Export CSV
            _buildExportSection(adminProvider),
            const SizedBox(height: 24),

            // Actions rapides
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ! 👋',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      'Tableau de bord administrateur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // � Tableau de recouvrement — prêts en retard groupés par ancienneté
  Widget _buildRecoveryTable(AdminProvider adminProvider) {
    final now = DateTime.now();
    final overdueLoans = adminProvider.allLoans
        .where((l) => l.statut == LoanStatus.enRetard)
        .toList();

    // Calculer les jours de retard pour chaque prêt (basé sur la plus ancienne échéance impayée)
    final rows = <Map<String, dynamic>>[];
    for (final loan in overdueLoans) {
      final schedules =
          adminProvider.allSchedules
              .where(
                (s) =>
                    s.loanId == loan.id && !s.isPaid && s.dueDate.isBefore(now),
              )
              .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (schedules.isEmpty) continue;
      final oldestDue = schedules.first.dueDate;
      final daysLate = now.difference(oldestDue).inDays;
      final unpaidTotal = schedules.fold<double>(0, (s, e) => s + e.total);
      // Find borrower name
      final user = adminProvider.allUsers.firstWhere(
        (u) => u.id == loan.userId,
        orElse: () => adminProvider.allUsers.first,
      );
      rows.add({
        'loan': loan,
        'daysLate': daysLate,
        'unpaidTotal': unpaidTotal,
        'unpaidCount': schedules.length,
        'borrowerName': loan.nomEmprunteur.isNotEmpty
            ? loan.nomEmprunteur
            : user.nom,
      });
    }
    rows.sort((a, b) => (b['daysLate'] as int).compareTo(a['daysLate'] as int));

    // Grouper par tranche
    final under30 = rows.where((r) => (r['daysLate'] as int) < 30).toList();
    final d30to60 = rows
        .where(
          (r) => (r['daysLate'] as int) >= 30 && (r['daysLate'] as int) < 60,
        )
        .toList();
    final d60to90 = rows
        .where(
          (r) => (r['daysLate'] as int) >= 60 && (r['daysLate'] as int) < 90,
        )
        .toList();
    final over90 = rows.where((r) => (r['daysLate'] as int) >= 90).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tableau de recouvrement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${overdueLoans.length} prêt(s) en retard',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRecoveryChip(
                    '<30j',
                    under30.length,
                    const Color(0xFFF59E0B),
                  ),
                  _buildRecoveryChip(
                    '30-60j',
                    d30to60.length,
                    const Color(0xFFF97316),
                  ),
                  _buildRecoveryChip(
                    '60-90j',
                    d60to90.length,
                    const Color(0xFFEF4444),
                  ),
                  _buildRecoveryChip(
                    '90j+',
                    over90.length,
                    const Color(0xFFDC2626),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun prêt en retard 🎉',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ...rows.map((r) {
                  final daysLate = r['daysLate'] as int;
                  final color = daysLate >= 90
                      ? const Color(0xFFDC2626)
                      : daysLate >= 60
                      ? const Color(0xFFEF4444)
                      : daysLate >= 30
                      ? const Color(0xFFF97316)
                      : const Color(0xFFF59E0B);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${daysLate}j',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['borrowerName'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currencyFormat.format((r['loan'] as dynamic).montant)} — ${r['unpaidCount']} éch. impayée(s)',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(r['unpaidTotal']),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecoveryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label : $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // �📊 Section des KPIs avancés
  Widget _buildAdvancedKPIs(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête de section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'KPIs Avancés',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grille des KPIs responsive
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth < 600 ? 1 : 2;
            double childAspectRatio = constraints.maxWidth < 600 ? 2.5 : 1.8;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
              children: [
                // Plus gros créancier
                _buildAdvancedKPICard(
                  title: 'Plus gros créancier',
                  mainValue: stats['plusGrosCreancier'] as String,
                  subtitle: _currencyFormat.format(stats['plusGrosMontant']),
                  icon: Icons.person_pin,
                  color: const Color(0xFF10B981),
                ),

                // État des paiements
                _buildAdvancedKPICard(
                  title: 'Paiements dans les temps',
                  mainValue:
                      '${(stats['pourcentageDansLesTemps'] as double).toStringAsFixed(1)}%',
                  subtitle:
                      '${(stats['pourcentageEnRetard'] as double).toStringAsFixed(1)}% en retard',
                  icon: Icons.schedule,
                  color: const Color(0xFF3B82F6),
                ),

                // Taux de rejet
                _buildAdvancedKPICard(
                  title: 'Taux de rejet',
                  mainValue:
                      '${(stats['tauxRejet'] as double).toStringAsFixed(1)}%',
                  subtitle: '${stats['rejectedLoans']} prêts refusés',
                  icon: Icons.block,
                  color: const Color(0xFFFF6B6B),
                ),

                // Taux de défaut
                _buildAdvancedKPICard(
                  title: 'Taux de défaut',
                  mainValue:
                      '${(stats['tauxDefaut'] as double).toStringAsFixed(1)}%',
                  subtitle: '${stats['lateLoans']} prêts en retard',
                  icon: Icons.warning_amber,
                  color: const Color(0xFFEF4444),
                ),

                // Durée moyenne
                _buildAdvancedKPICard(
                  title: 'Durée moyenne',
                  mainValue:
                      '${(stats['dureeMoyenne'] as double).toStringAsFixed(1)} mois',
                  subtitle: 'Par prêt',
                  icon: Icons.access_time,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedKPICard({
    required String title,
    required String mainValue,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // �📈 Carte spéciale pour le rendement total
  Widget _buildRendementCard(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);
    final rendementTotal = stats['rendementTotal'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RENDEMENT TOTAL',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rendementTotal.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Performance globale de vos prêts',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rendementTotal > 10
                  ? '🚀 Excellent'
                  : rendementTotal > 5
                  ? '📈 Bon'
                  : '⚡ Démarrage',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: adapter le nombre de colonnes selon la largeur
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth < 600) {
          // Mobile: 1 colonne
          crossAxisCount = 1;
          childAspectRatio = 2.5;
        } else if (constraints.maxWidth < 900) {
          // Tablette: 2 colonnes
          crossAxisCount = 2;
          childAspectRatio = 1.5;
        } else {
          // Desktop: 3 colonnes
          crossAxisCount = 3;
          childAspectRatio = 1.2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _buildModernStatCard(
              title: 'Prêts actifs',
              value: stats['activeLoans'].toString(),
              icon: Icons.trending_up,
              color: const Color(0xFF10B981),
              trend: '${stats['lateLoans']} en retard',
            ),
            _buildModernStatCard(
              title: 'En attente',
              value: stats['pendingLoans'].toString(),
              icon: Icons.hourglass_empty,
              color: const Color(0xFFF59E0B),
              trend: '',
            ),
            _buildModernStatCard(
              title: 'Utilisateurs',
              value: stats['totalUsers'].toString(),
              icon: Icons.people,
              color: const Color(0xFF00D4FF),
              trend: '${stats['newUsersThisMonth']} ce mois',
            ),
            // 💰 NOUVELLES CARTES FINANCIÈRES
            _buildModernStatCard(
              title: 'Capital prêté',
              value: _currencyFormat.format(stats['capitalPrete']),
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF8B5CF6),
              trend: '',
            ),
            _buildModernStatCard(
              title: 'Gains attendus',
              value: _currencyFormat.format(stats['gainsTotauxAttendus']),
              icon: Icons.monetization_on,
              color: const Color(0xFF10B981),
              trend: '',
            ),
            _buildModernStatCard(
              title: 'Taux moyen',
              value: '${stats['tauxMoyenPondere'].toStringAsFixed(1)}%',
              icon: Icons.percent,
              color: const Color(0xFFEF4444),
              trend: 'Pondéré',
            ),
            // 💵 STATISTIQUES DE RECOUVREMENT
            _buildModernStatCard(
              title: 'Sommes recouvrées',
              value: _currencyFormat.format(stats['sommesRecouvertes']),
              icon: Icons.paid,
              color: const Color(0xFF3B82F6),
              trend: '${stats['tauxRecouvrement'].toStringAsFixed(1)}%',
            ),
            _buildModernStatCard(
              title: 'Capital recouvré',
              value: _currencyFormat.format(stats['capitalRecouvre']),
              icon: Icons.savings,
              color: const Color(0xFF14B8A6),
              trend: 'Principal',
            ),
            _buildModernStatCard(
              title: 'Intérêts recouvrés',
              value: _currencyFormat.format(stats['interetsRecouvres']),
              icon: Icons.trending_up,
              color: const Color(0xFFF59E0B),
              trend: 'Gains réels',
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapter la taille selon la largeur disponible
        final bool isCompact = constraints.maxWidth < 250;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: isCompact ? 18 : 20),
                  ),
                  if (trend.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                          color: const Color(0xFF10B981),
                          fontSize: isCompact ? 10 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 12 : 16),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: isCompact ? 12 : 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanStatusChart(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);

    // Construire les données du chart dynamiquement avec tous les statuts
    final chartData = <Map<String, dynamic>>[
      {
        'label': 'En attente',
        'value': stats['pendingLoans'],
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Approuvés',
        'value': stats['approvedLoans'],
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Décaissés',
        'value': stats['disbursedLoans'],
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'En cours',
        'value': stats['activeLoans'],
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'En retard',
        'value': stats['lateLoans'],
        'color': const Color(0xFFEF4444),
      },
      {
        'label': 'Terminés',
        'value': stats['completedLoans'],
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'Refusés',
        'value': stats['rejectedLoans'],
        'color': const Color(0xFFFF6B6B),
      },
    ];

    // Filtrer les sections avec valeur > 0
    final activeData = chartData.where((d) => (d['value'] as int) > 0).toList();

    // Si aucune donnée, afficher un placeholder
    if (activeData.isEmpty) {
      activeData.add({'label': 'Aucun prêt', 'value': 1, 'color': Colors.grey});
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Répartition des prêts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              SizedBox(
                height: isMobile ? 200 : 200,
                child: isMobile
                    ? Column(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                sections: activeData
                                    .map(
                                      (d) => PieChartSectionData(
                                        color: d['color'] as Color,
                                        value: (d['value'] as int).toDouble(),
                                        title: '${d['value']}',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: activeData
                                .map(
                                  (d) => _buildLegendItem(
                                    '${d['label']} (${d['value']})',
                                    d['color'] as Color,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: activeData
                                    .map(
                                      (d) => PieChartSectionData(
                                        color: d['color'] as Color,
                                        value: (d['value'] as int).toDouble(),
                                        title: '${d['value']}',
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: activeData
                                  .map(
                                    (d) => _buildLegendItem(
                                      '${d['label']} (${d['value']})',
                                      d['color'] as Color,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = {
      '3m': '3 mois',
      '6m': '6 mois',
      '1a': '1 an',
      'tout': 'Tout',
    };
    return Row(
      children: [
        Icon(Icons.date_range, color: Colors.white.withOpacity(0.5), size: 18),
        const SizedBox(width: 8),
        Text(
          'Période :',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        ),
        const SizedBox(width: 8),
        ...periods.entries.map((e) {
          final selected = _chartPeriod == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                e.value,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              onSelected: (_) => setState(() => _chartPeriod = e.key),
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoanTrendChart(AdminProvider adminProvider) {
    final trendData = _generateTrendData(adminProvider);
    final months = _chartPeriodMonths;
    final maxY = trendData.isEmpty
        ? 50000.0
        : (trendData.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3)
              .clamp(1000.0, double.infinity);
    // Show every N labels to avoid overlap
    final labelInterval = months <= 6 ? 1 : (months <= 12 ? 2 : 3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Évolution des montants',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              SizedBox(
                height: isMobile ? 150 : 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY / 4).ceilToDouble().clamp(
                        1000,
                        double.infinity,
                      ),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final now = DateTime.now();
                            final idx = value.toInt();
                            if (idx >= 0 &&
                                idx < months &&
                                idx % labelInterval == 0) {
                              final month = DateTime(
                                now.year,
                                now.month - (months - 1 - idx),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  DateFormat('MMM', 'fr_FR').format(month),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: isMobile ? 9 : 12,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              '${(value / 1000).toInt()}k€',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (months - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: trendData,
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF8B5CF6)],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00D4FF).withOpacity(0.3),
                              const Color(0xFF8B5CF6).withOpacity(0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 💹 Courbe PnL (Profit & Loss) mensuelle
  Widget _buildPnLChart(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);
    final allPnlData = stats['pnlData'] as List<Map<String, dynamic>>;

    // Filtrer selon la période sélectionnée
    final months = _chartPeriodMonths;
    final pnlData = allPnlData.length > months
        ? allPnlData.sublist(allPnlData.length - months)
        : allPnlData;

    // Calculer le profit cumulé
    double cumulProfit = 0;
    final profitPoints = <FlSpot>[];
    final cumulPoints = <FlSpot>[];
    double maxVal = 0;

    for (int i = 0; i < pnlData.length; i++) {
      final profit = pnlData[i]['profit'] as double;
      cumulProfit += profit;
      profitPoints.add(FlSpot(i.toDouble(), profit));
      cumulPoints.add(FlSpot(i.toDouble(), cumulProfit));

      if (profit > maxVal) maxVal = profit;
      if (cumulProfit > maxVal) maxVal = cumulProfit;
    }

    // Marge haute
    final chartMax = maxVal > 0 ? maxVal * 1.3 : 1000.0;
    final chartMin = 0.0;

    // Capital en circulation = capital prêté - capital récupéré
    final capitalEnCirculation =
        (stats['capitalPrete'] as double) -
        (stats['capitalRecouvre'] as double);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PnL — Gains réels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildLegendItem('Mensuel', const Color(0xFF00D4FF)),
                  const SizedBox(width: 12),
                  _buildLegendItem('Cumulé', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Intérêts + pénalités encaissés (hors flux de capital)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 20),
              SizedBox(
                height: isMobile ? 200 : 240,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxVal > 0
                          ? (maxVal / 4).ceilToDouble().clamp(
                              50,
                              double.infinity,
                            )
                          : 500,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.08),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final idx = value.toInt();
                            final labelStep = pnlData.length > 12
                                ? 3
                                : (isMobile ? 2 : 1);
                            if (idx >= 0 &&
                                idx < pnlData.length &&
                                idx % labelStep == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  pnlData[idx]['label'] as String,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value < 0) return const SizedBox.shrink();
                            String label;
                            if (value >= 1000) {
                              label = '${(value / 1000).toStringAsFixed(1)}k';
                            } else {
                              label = value.toInt().toString();
                            }
                            return Text(
                              '$label€',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (pnlData.length - 1).toDouble(),
                    minY: chartMin,
                    maxY: chartMax,
                    lineBarsData: [
                      // Profit mensuel (barres via area fill)
                      LineChartBarData(
                        spots: profitPoints,
                        isCurved: false,
                        color: const Color(0xFF00D4FF),
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: spot.y > 0
                                  ? const Color(0xFF00D4FF)
                                  : const Color(0xFF475569),
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00D4FF).withOpacity(0.2),
                              const Color(0xFF00D4FF).withOpacity(0.02),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Profit cumulé
                      LineChartBarData(
                        spots: cumulPoints,
                        isCurved: true,
                        color: const Color(0xFF10B981),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.15),
                              const Color(0xFF10B981).withOpacity(0.02),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final isMonthly = spot.barIndex == 0;
                            final label = isMonthly ? 'Mois' : 'Cumulé';
                            return LineTooltipItem(
                              '$label: ${_currencyFormat.format(spot.y)}',
                              TextStyle(
                                color: isMonthly
                                    ? const Color(0xFF00D4FF)
                                    : const Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Résumé PnL — 4 indicateurs clés
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  _buildPnLSummaryChip(
                    'Intérêts encaissés',
                    _currencyFormat.format(stats['interetsRecouvres']),
                    const Color(0xFF10B981),
                  ),
                  _buildPnLSummaryChip(
                    'Pénalités perçues',
                    _currencyFormat.format(
                      adminProvider.allSchedules
                          .where((s) => s.isPaid && s.hasPenalty)
                          .fold<double>(
                            0,
                            (sum, s) => sum + (s.penaltyAmount ?? 0),
                          ),
                    ),
                    const Color(0xFFF59E0B),
                  ),
                  _buildPnLSummaryChip(
                    'Capital en circulation',
                    _currencyFormat.format(capitalEnCirculation),
                    const Color(0xFF3B82F6),
                  ),
                  _buildPnLSummaryChip(
                    'Recouvrement',
                    '${(stats['tauxRecouvrement'] as double).toStringAsFixed(1)}%',
                    const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPnLSummaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
        ),
      ],
    );
  }

  /// 🤝 Section Parrainages avec KPIs et liste des commissions à verser
  Widget _buildReferralSection(AdminProvider adminProvider) {
    final referrals = adminProvider.allReferrals;

    // Calculs KPI parrainage
    final uniqueParrains = referrals
        .map((r) => r['parrainEmail'])
        .toSet()
        .length;
    final totalBonusAVerser = referrals
        .where((r) => r['statut'] == 'pret_decaisse')
        .fold<double>(
          0,
          (sum, r) => sum + ((r['bonusParrain'] as num?)?.toDouble() ?? 0),
        );
    final totalBonusVerse = referrals
        .where((r) => r['statut'] == 'verse')
        .fold<double>(
          0,
          (sum, r) => sum + ((r['bonusParrain'] as num?)?.toDouble() ?? 0),
        );
    final referralsActifs = referrals
        .where((r) => r['statut'] != 'verse')
        .length;
    final referralsAVerser = referrals
        .where((r) => r['statut'] == 'pret_decaisse')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Color(0xFF9C27B0),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Parrainages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // KPIs parrainages
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
            double childAspectRatio = constraints.maxWidth < 600 ? 1.8 : 1.5;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildAdvancedKPICard(
                  title: 'Parrains uniques',
                  mainValue: '$uniqueParrains',
                  subtitle: '$referralsActifs actifs',
                  icon: Icons.people_outline,
                  color: const Color(0xFF9C27B0),
                ),
                _buildAdvancedKPICard(
                  title: 'À verser',
                  mainValue: '${totalBonusAVerser.toStringAsFixed(2)}€',
                  subtitle: '${referralsAVerser.length} commission(s)',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFFF9800),
                ),
                _buildAdvancedKPICard(
                  title: 'Déjà versé',
                  mainValue: '${totalBonusVerse.toStringAsFixed(2)}€',
                  subtitle: 'Total commissions',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4CAF50),
                ),
                _buildAdvancedKPICard(
                  title: 'Total parrainages',
                  mainValue: '${referrals.length}',
                  subtitle: 'Depuis le début',
                  icon: Icons.handshake_outlined,
                  color: const Color(0xFF3B82F6),
                ),
              ],
            );
          },
        ),

        // Liste des commissions à verser
        if (referralsAVerser.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Commissions à verser',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...referralsAVerser.map(
            (referral) => _buildReferralPayCard(referral, adminProvider),
          ),
        ],
      ],
    );
  }

  Widget _buildReferralPayCard(
    Map<String, dynamic> referral,
    AdminProvider adminProvider,
  ) {
    final parrainEmail = referral['parrainEmail'] ?? '';
    final filleulName = referral['filleulName'] ?? '';
    final bonus = (referral['bonusParrain'] as num?)?.toDouble() ?? 0;
    final montantPret = (referral['montantPret'] as num?)?.toDouble() ?? 0;
    final referralId = referral['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: Color(0xFF9C27B0),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parrainEmail,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Filleul: $filleulName • Prêt: ${montantPret.toStringAsFixed(0)}€',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${bonus.toStringAsFixed(2)}€',
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: adminProvider.isLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmer le versement'),
                              content: Text(
                                'Marquer la commission de ${bonus.toStringAsFixed(2)}€ pour $parrainEmail comme versée ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                  ),
                                  child: const Text('Confirmer'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final success = await adminProvider
                                .markReferralAsPaid(referralId);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Commission versée avec succès !'
                                        : 'Erreur lors du versement',
                                  ),
                                  backgroundColor: success
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Versé ✓',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection(AdminProvider adminProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.download_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Export CSV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildExportButton('Tous les prêts', Icons.assignment, () {
                CsvExportService.exportLoans(adminProvider.allLoans);
              }),
              _buildExportButton(
                'Échéancier complet',
                Icons.calendar_month,
                () {
                  CsvExportService.exportSchedules(adminProvider.allSchedules);
                },
              ),
              _buildExportButton('Recouvrement', Icons.warning_amber, () {
                CsvExportService.exportOverdue(
                  adminProvider.allLoans,
                  adminProvider.allSchedules,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF10B981),
        side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actions rapides',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              if (isMobile)
                Column(
                  children: [
                    _buildActionButton(
                      'Gérer les prêts',
                      Icons.assignment,
                      const Color(0xFF10B981),
                      () => context.push('/admin/loans'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      'Créer admin',
                      Icons.person_add,
                      const Color(0xFF00D4FF),
                      () => context.push('/admin/create-admin'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      'Rappels de paiement',
                      Icons.notification_important,
                      const Color(0xFFFF6B6B),
                      () => context.push('/admin/payment-reminders'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      'Statistiques',
                      Icons.bar_chart,
                      const Color(0xFFF59E0B),
                      () => context.push('/admin/statistics'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Gérer les prêts',
                            Icons.assignment,
                            const Color(0xFF10B981),
                            () => context.push('/admin/loans'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Créer admin',
                            Icons.person_add,
                            const Color(0xFF00D4FF),
                            () => context.push('/admin/create-admin'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Rappels de paiement',
                            Icons.notification_important,
                            const Color(0xFFFF6B6B),
                            () => context.push('/admin/payment-reminders'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Statistiques',
                            Icons.bar_chart,
                            const Color(0xFFF59E0B),
                            () => context.push('/admin/statistics'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(AdminProvider adminProvider) {
    final stats = _calculateStats(adminProvider);

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00D4FF),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistiques détaillées des prêts
            _buildDetailedStatsCard('Prêts', [
              _buildStatRow('Total des prêts', stats['totalLoans'].toString()),
              _buildStatRow('En attente', stats['pendingLoans'].toString()),
              _buildStatRow('Approuvés', stats['approvedLoans'].toString()),
              _buildStatRow('Refusés', stats['rejectedLoans'].toString()),
              _buildStatRow('En cours', stats['activeLoans'].toString()),
              _buildStatRow('Terminés', stats['completedLoans'].toString()),
            ]),
            const SizedBox(height: 20),

            // Statistiques financières
            _buildDetailedStatsCard('Finances', [
              _buildStatRow(
                'Capital décaissé',
                _currencyFormat.format(stats['capitalPrete']),
              ),
              _buildStatRow(
                'Gains attendus',
                _currencyFormat.format(stats['gainsTotauxAttendus']),
              ),
              _buildStatRow(
                'En cours',
                _currencyFormat.format(stats['activeAmount']),
              ),
              _buildStatRow(
                'Montant moyen',
                _currencyFormat.format(stats['averageAmount']),
              ),
              _buildStatRow(
                'Plus gros prêt',
                _currencyFormat.format(stats['maxAmount']),
              ),
              _buildStatRow(
                'Plus petit prêt',
                _currencyFormat.format(stats['minAmount']),
              ),
            ]),
            const SizedBox(height: 20),

            // Statistiques des utilisateurs
            _buildDetailedStatsCard('Utilisateurs', [
              _buildStatRow(
                'Total utilisateurs',
                stats['totalUsers'].toString(),
              ),
              _buildStatRow('Emprunteurs', stats['borrowers'].toString()),
              _buildStatRow('Administrateurs', stats['admins'].toString()),
              _buildStatRow('Super admins', stats['superAdmins'].toString()),
              _buildStatRow(
                'Utilisateurs actifs',
                stats['activeUsers'].toString(),
              ),
              _buildStatRow(
                'Nouveaux ce mois',
                stats['newUsersThisMonth'].toString(),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatsCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(AdminProvider adminProvider) {
    final allLoans = adminProvider.allLoans;
    final allUsers = adminProvider.allUsers;
    final allSchedules = adminProvider.allSchedules;
    final now = DateTime.now();

    // ── Compteurs par statut ──
    final pendingLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.soumis || l.statut == LoanStatus.enRevue,
        )
        .length;
    final approvedLoans = allLoans
        .where((l) => l.statut == LoanStatus.approuve)
        .length;
    final rejectedLoans = allLoans
        .where((l) => l.statut == LoanStatus.refuse)
        .length;
    final activeLoans = allLoans
        .where((l) => l.statut == LoanStatus.enCours)
        .length;
    final disbursedLoans = allLoans
        .where((l) => l.statut == LoanStatus.decaissementEffectue)
        .length;
    final lateLoans = allLoans
        .where((l) => l.statut == LoanStatus.enRetard)
        .length;
    final completedLoans = allLoans
        .where(
          (l) => l.statut == LoanStatus.ferme || l.statut == LoanStatus.solde,
        )
        .length;
    final totalLoans = allLoans.length;

    // ── Prêts effectifs (décaissés / actifs / terminés) ──
    // Exclut : brouillon, soumis, enRevue, approuvé (pas encore décaissé), refusé, annulé
    final effectiveLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.decaissementEffectue ||
              l.statut == LoanStatus.enCours ||
              l.statut == LoanStatus.enRetard ||
              l.statut == LoanStatus.solde ||
              l.statut == LoanStatus.ferme,
        )
        .toList();

    // ── Statistiques financières — sur prêts effectifs uniquement ──
    final capitalPrete = effectiveLoans.fold<double>(
      0,
      (s, l) => s + l.montant,
    );
    final gainsTotauxAttendus = effectiveLoans.fold<double>(
      0,
      (s, l) => s + l.coutTotalEstime,
    );
    final activeAmount = allLoans
        .where((l) => l.statut == LoanStatus.enCours)
        .fold<double>(0, (s, l) => s + l.montant);

    // Rendement = intérêts attendus / capital décaissé
    // NB : coutTotalEstime = intérêts seulement (pas capital + intérêts)
    final rendementTotal = capitalPrete > 0
        ? (gainsTotauxAttendus / capitalPrete) * 100
        : 0.0;

    // Taux moyen pondéré par montant (prêts effectifs)
    double tauxMoyenPondere = 0.0;
    if (effectiveLoans.isNotEmpty && capitalPrete > 0) {
      final sommePonderee = effectiveLoans.fold<double>(
        0,
        (s, l) => s + (l.tauxAnnuel * l.montant),
      );
      tauxMoyenPondere = sommePonderee / capitalPrete;
    }

    // ── Recouvrement (échéances payées) ──
    final paidSchedules = allSchedules.where((s) => s.isPaid);
    final sommesRecouvertes = paidSchedules.fold<double>(
      0,
      (s, e) => s + e.total,
    );
    final capitalRecouvre = paidSchedules.fold<double>(
      0,
      (s, e) => s + e.principal,
    );
    final interetsRecouvres = paidSchedules.fold<double>(
      0,
      (s, e) => s + e.interet,
    );
    final tauxRecouvrement = capitalPrete > 0
        ? (capitalRecouvre / capitalPrete) * 100
        : 0.0;

    // ── Onglet Statistiques — Volume total (tous prêts effectifs) ──
    final approvedAmount = effectiveLoans.fold<double>(
      0,
      (s, l) => s + l.montant,
    );
    // Pour le "Volume total" et stats de l'onglet, on garde tous les prêts en info
    final totalAmount = allLoans.fold<double>(0, (s, l) => s + l.montant);
    // Montant moyen sur prêts effectifs
    final averageAmount = effectiveLoans.isNotEmpty
        ? effectiveLoans.fold<double>(0, (s, l) => s + l.montant) /
              effectiveLoans.length
        : 0.0;
    final maxAmount = effectiveLoans.isNotEmpty
        ? effectiveLoans.map((l) => l.montant).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final minAmount = effectiveLoans.isNotEmpty
        ? effectiveLoans.map((l) => l.montant).reduce((a, b) => a < b ? a : b)
        : 0.0;

    // ── Utilisateurs ──
    final totalUsers = allUsers.length;
    final borrowers = allUsers.where((u) => u.role == UserRole.borrower).length;
    final admins = allUsers.where((u) => u.role == UserRole.admin).length;
    final superAdmins = allUsers
        .where((u) => u.role == UserRole.superAdmin)
        .length;
    final thisMonth = DateTime(now.year, now.month);
    final newUsersThisMonth = allUsers
        .where((u) => u.createdAt.isAfter(thisMonth))
        .length;
    final activeUsers = allUsers
        .where((u) => allLoans.any((l) => l.userId == u.id))
        .length;

    // ── KPI : Plus gros emprunteur (prêts effectifs uniquement) ──
    String plusGrosCreancier = 'Aucun';
    double plusGrosMontant = 0;
    if (allUsers.isNotEmpty && effectiveLoans.isNotEmpty) {
      final montantsParUser = <String, double>{};
      for (final loan in effectiveLoans) {
        final user = allUsers.where((u) => u.id == loan.userId).firstOrNull;
        if (user != null) {
          final key = '${user.prenom} ${user.nom}';
          montantsParUser[key] = (montantsParUser[key] ?? 0) + loan.montant;
        }
      }
      if (montantsParUser.isNotEmpty) {
        final maxEntry = montantsParUser.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        plusGrosCreancier = maxEntry.key;
        plusGrosMontant = maxEntry.value;
      }
    }

    // ── KPI : Paiements dans les temps ──
    int totalEcheancesDues = 0;
    int echeancesEnRetard = 0;
    for (final schedule in allSchedules) {
      if (schedule.dueDate.isBefore(now) ||
          schedule.dueDate.isAtSameMomentAs(now)) {
        totalEcheancesDues++;
        if (!schedule.isPaid) echeancesEnRetard++;
      }
    }
    final pourcentageDansLesTemps = totalEcheancesDues > 0
        ? ((totalEcheancesDues - echeancesEnRetard) / totalEcheancesDues * 100)
        : 100.0;
    final pourcentageEnRetard = totalEcheancesDues > 0
        ? (echeancesEnRetard / totalEcheancesDues * 100)
        : 0.0;

    // ── KPI : Taux de rejet (prêts refusés / total demandes) ──
    final tauxRejet = totalLoans > 0 ? (rejectedLoans / totalLoans * 100) : 0.0;

    // ── KPI : Taux de défaut (prêts en retard / prêts effectifs) ──
    final tauxDefaut = effectiveLoans.isNotEmpty
        ? (lateLoans / effectiveLoans.length * 100)
        : 0.0;

    // ── KPI : Durée moyenne (prêts effectifs uniquement) ──
    final dureeMoyenne = effectiveLoans.isNotEmpty
        ? effectiveLoans.fold<double>(0, (s, l) => s + l.dureeMois) /
              effectiveLoans.length
        : 0.0;

    // ── PnL mensuel (24 derniers mois) ──
    // PnL = profits réels = intérêts encaissés + pénalités encaissées
    // Le capital (prêté/remboursé) N'EST PAS du profit, on ne le mélange pas
    final pnlData = <Map<String, dynamic>>[];
    for (int i = 23; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final monthEnd = DateTime(now.year, now.month - i + 1);

      // Échéances payées ce mois
      final paidThisMonth = allSchedules.where((s) {
        if (!s.isPaid) return false;
        final date = s.paidAt ?? s.dueDate;
        return !date.isBefore(month) && date.isBefore(monthEnd);
      });

      // Intérêts encaissés ce mois (= le VRAI profit)
      final interetsMois = paidThisMonth.fold<double>(
        0,
        (sum, s) => sum + s.interet,
      );

      // Pénalités encaissées ce mois
      final penalitesMois = paidThisMonth.fold<double>(
        0,
        (sum, s) => sum + (s.penaltyAmount ?? 0),
      );

      // Profit du mois = intérêts + pénalités
      final profitMois = interetsMois + penalitesMois;

      pnlData.add({
        'month': month,
        'label': DateFormat('MMM yy', 'fr_FR').format(month),
        'interets': interetsMois,
        'penalites': penalitesMois,
        'profit': profitMois,
      });
    }

    return {
      'totalLoans': totalLoans,
      'pendingLoans': pendingLoans,
      'approvedLoans': approvedLoans,
      'rejectedLoans': rejectedLoans,
      'activeLoans': activeLoans,
      'disbursedLoans': disbursedLoans,
      'lateLoans': lateLoans,
      'completedLoans': completedLoans,
      'totalAmount': totalAmount,
      'approvedAmount': approvedAmount,
      'activeAmount': activeAmount,
      'averageAmount': averageAmount,
      'maxAmount': maxAmount,
      'minAmount': minAmount,
      'totalUsers': totalUsers,
      'borrowers': borrowers,
      'admins': admins,
      'superAdmins': superAdmins,
      'activeUsers': activeUsers,
      'newUsersThisMonth': newUsersThisMonth,
      'capitalPrete': capitalPrete,
      'gainsTotauxAttendus': gainsTotauxAttendus,
      'rendementTotal': rendementTotal,
      'tauxMoyenPondere': tauxMoyenPondere,
      'plusGrosCreancier': plusGrosCreancier,
      'plusGrosMontant': plusGrosMontant,
      'pourcentageDansLesTemps': pourcentageDansLesTemps,
      'pourcentageEnRetard': pourcentageEnRetard,
      'tauxRejet': tauxRejet,
      'tauxDefaut': tauxDefaut,
      'dureeMoyenne': dureeMoyenne,
      'sommesRecouvertes': sommesRecouvertes,
      'capitalRecouvre': capitalRecouvre,
      'interetsRecouvres': interetsRecouvres,
      'tauxRecouvrement': tauxRecouvrement,
      'pnlData': pnlData,
    };
  }

  int get _chartPeriodMonths {
    switch (_chartPeriod) {
      case '3m':
        return 3;
      case '6m':
        return 6;
      case '1a':
        return 12;
      case 'tout':
        return 24;
      default:
        return 6;
    }
  }

  List<FlSpot> _generateTrendData(AdminProvider adminProvider) {
    final now = DateTime.now();
    final data = <FlSpot>[];
    final months = _chartPeriodMonths;

    for (int i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - (months - 1 - i));
      final monthlyAmount = adminProvider.allLoans
          .where(
            (loan) =>
                loan.createdAt.year == month.year &&
                loan.createdAt.month == month.month &&
                (loan.statut == LoanStatus.approuve ||
                    loan.statut == LoanStatus.enCours ||
                    loan.statut == LoanStatus.ferme ||
                    loan.statut == LoanStatus.solde ||
                    loan.statut == LoanStatus.decaissementEffectue),
          )
          .fold<double>(0, (sum, loan) => sum + loan.montant);

      data.add(FlSpot(i.toDouble(), monthlyAmount));
    }

    return data;
  }

  /// Méthode de déconnexion
  Future<void> _logout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Confirmation de déconnexion
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Déconnexion',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        ),
      );

      if (shouldLogout == true && mounted) {
        await authProvider.signOut();
        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
