import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/loan_model.dart';
import '../../models/user_model.dart';
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
            _buildLoanTrendChart(adminProvider),
            const SizedBox(height: 24),

            // 📊 KPIs Avancés
            _buildAdvancedKPIs(adminProvider),
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

  // 📊 Section des KPIs avancés
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

                // Taux de défaut
                _buildAdvancedKPICard(
                  title: 'Taux de défaut',
                  mainValue:
                      '${(stats['tauxDefaut'] as double).toStringAsFixed(1)}%',
                  subtitle: 'Prêts refusés',
                  icon: Icons.trending_down,
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
              trend: '+12%',
            ),
            _buildModernStatCard(
              title: 'En attente',
              value: stats['pendingLoans'].toString(),
              icon: Icons.hourglass_empty,
              color: const Color(0xFFF59E0B),
              trend: '-5%',
            ),
            _buildModernStatCard(
              title: 'Utilisateurs',
              value: stats['totalUsers'].toString(),
              icon: Icons.people,
              color: const Color(0xFF00D4FF),
              trend: '+8%',
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

  Widget _buildLoanTrendChart(AdminProvider adminProvider) {
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
                      horizontalInterval: 10000,
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
                          getTitlesWidget: (double value, TitleMeta meta) {
                            const months = [
                              'Jan',
                              'Fév',
                              'Mar',
                              'Avr',
                              'Mai',
                              'Jun',
                            ];
                            if (value.toInt() < months.length) {
                              return Text(
                                months[value.toInt()],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
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
                    maxX: 5,
                    minY: 0,
                    maxY: 50000,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _generateTrendData(adminProvider),
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
                'Volume total',
                _currencyFormat.format(stats['totalAmount']),
              ),
              _buildStatRow(
                'Montant approuvé',
                _currencyFormat.format(stats['approvedAmount']),
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

    // Statistiques des prêts
    final totalLoans = allLoans.length;
    final pendingLoans = allLoans
        .where((l) => l.statut == LoanStatus.soumis)
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

    // Statistiques financières
    final totalAmount = allLoans.fold<double>(
      0,
      (sum, loan) => sum + loan.montant,
    );
    final approvedAmount = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.approuve ||
              l.statut == LoanStatus.enCours ||
              l.statut == LoanStatus.ferme ||
              l.statut == LoanStatus.solde ||
              l.statut == LoanStatus.decaissementEffectue,
        )
        .fold<double>(0, (sum, loan) => sum + loan.montant);
    final activeAmount = allLoans
        .where((l) => l.statut == LoanStatus.enCours)
        .fold<double>(0, (sum, loan) => sum + loan.montant);

    final averageAmount = totalLoans > 0 ? totalAmount / totalLoans : 0.0;
    final maxAmount = allLoans.isNotEmpty
        ? allLoans.map((l) => l.montant).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final minAmount = allLoans.isNotEmpty
        ? allLoans.map((l) => l.montant).reduce((a, b) => a < b ? a : b)
        : 0.0;

    // 💰 NOUVELLES STATISTIQUES FINANCIÈRES

    // Prêts ayant généré ou générant des intérêts (approuvés, en cours, terminés)
    final profitableLoans = allLoans
        .where(
          (l) =>
              l.statut == LoanStatus.approuve ||
              l.statut == LoanStatus.enCours ||
              l.statut == LoanStatus.solde ||
              l.statut == LoanStatus.ferme ||
              l.statut == LoanStatus.decaissementEffectue,
        )
        .toList();

    // Capital total réellement prêté
    final capitalPrete = profitableLoans.fold<double>(
      0,
      (sum, loan) => sum + loan.montant,
    );

    // Gains totaux attendus (somme des intérêts de tous les prêts profitables)
    final gainsTotauxAttendus = profitableLoans.fold<double>(
      0,
      (sum, loan) => sum + loan.coutTotalEstime,
    );

    // ✅ NOUVEAU : Calcul des sommes réellement recouvrées
    final allSchedules = adminProvider.allSchedules;

    // Sommes totales recouvrées (échéances payées)
    final sommesRecouvertes = allSchedules
        .where((schedule) => schedule.isPaid)
        .fold<double>(0, (sum, schedule) => sum + schedule.total);

    // Capital recouvré (sommes principales payées)
    final capitalRecouvre = allSchedules
        .where((schedule) => schedule.isPaid)
        .fold<double>(0, (sum, schedule) => sum + schedule.principal);

    // Intérêts recouvrés (sommes d'intérêts payées)
    final interetsRecouvres = allSchedules
        .where((schedule) => schedule.isPaid)
        .fold<double>(0, (sum, schedule) => sum + schedule.interet);

    // Taux de recouvrement (% du capital prêté qui a été récupéré)
    final tauxRecouvrement = capitalPrete > 0
        ? (capitalRecouvre / capitalPrete) * 100
        : 0.0;

    // Rendement total attendu (%)
    final rendementTotal = capitalPrete > 0
        ? (gainsTotauxAttendus / capitalPrete) * 100
        : 0.0;

    // Taux moyen pondéré par montant
    double tauxMoyenPondere = 0.0;
    if (profitableLoans.isNotEmpty && capitalPrete > 0) {
      final sommePonderee = profitableLoans.fold<double>(
        0,
        (sum, loan) => sum + (loan.tauxAnnuel * loan.montant),
      );
      tauxMoyenPondere = sommePonderee / capitalPrete;
    }

    // Statistiques des utilisateurs
    final totalUsers = allUsers.length;
    final borrowers = allUsers.where((u) => u.role == UserRole.borrower).length;
    final admins = allUsers.where((u) => u.role == UserRole.admin).length;
    final superAdmins = allUsers
        .where((u) => u.role == UserRole.superAdmin)
        .length;

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final newUsersThisMonth = allUsers
        .where((u) => u.createdAt.isAfter(thisMonth))
        .length;

    // Utilisateurs ayant au moins un prêt
    final activeUsers = allUsers
        .where((u) => allLoans.any((l) => l.userId == u.id))
        .length;

    // 📊 NOUVEAUX KPIs AVANCÉS

    // 1. Plus gros créancier (emprunteur avec le plus gros montant total)
    // ✅ CORRECTION : Ne compter que les prêts approuvés/actifs/terminés
    String plusGrosCreancier = 'Aucun';
    double plusGrosMontant = 0;

    if (allUsers.isNotEmpty && allLoans.isNotEmpty) {
      final montantsParUtilisateur = <String, double>{};

      // Filtrer uniquement les prêts valides (pas les brouillons ni refusés)
      final loansValides = allLoans
          .where(
            (loan) =>
                loan.statut == LoanStatus.approuve ||
                loan.statut == LoanStatus.enCours ||
                loan.statut == LoanStatus.solde ||
                loan.statut == LoanStatus.decaissementEffectue,
          )
          .toList();

      for (final loan in loansValides) {
        final user = allUsers.where((u) => u.id == loan.userId).firstOrNull;
        if (user != null) {
          final key = '${user.prenom} ${user.nom}';
          montantsParUtilisateur[key] =
              (montantsParUtilisateur[key] ?? 0) + loan.montant;
        }
      }

      if (montantsParUtilisateur.isNotEmpty) {
        final maxEntry = montantsParUtilisateur.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        plusGrosCreancier = maxEntry.key;
        plusGrosMontant = maxEntry.value;
      }
    }

    // 2. État des paiements (VRAIES DONNÉES Firebase)
    // Note: allSchedules déjà récupéré plus haut pour calcul des recouvrements

    // Compter les échéances totales et celles en retard
    int totalEcheances = 0;
    int echeancesEnRetard = 0;

    for (final schedule in allSchedules) {
      // Échéance non payée avec date d'échéance dépassée = en retard
      if (!schedule.isPaid && schedule.dueDate.isBefore(now)) {
        echeancesEnRetard++;
      }
      // Compter toutes les échéances dues (passées ou actuelles)
      if (schedule.dueDate.isBefore(now) ||
          schedule.dueDate.isAtSameMomentAs(now)) {
        totalEcheances++;
      }
    }

    final pourcentageDansLesTemps = totalEcheances > 0
        ? ((totalEcheances - echeancesEnRetard) / totalEcheances * 100)
        : 100.0;
    final pourcentageEnRetard = totalEcheances > 0
        ? (echeancesEnRetard / totalEcheances * 100)
        : 0.0; // 3. Taux de défaut (prêts refusés sur total des demandes)
    final tauxDefaut = totalLoans > 0
        ? (rejectedLoans / totalLoans * 100)
        : 0.0;

    // 4. Durée moyenne des prêts (en mois)
    final dureeMoyenne = allLoans.isNotEmpty
        ? allLoans.fold<double>(0, (sum, loan) => sum + loan.dureeMois) /
              allLoans.length
        : 0.0;

    // 5. Montant moyen par utilisateur actif
    final montantMoyenParUtilisateur = activeUsers > 0
        ? totalAmount / activeUsers
        : 0.0;

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
      // 💰 Nouvelles statistiques financières
      'capitalPrete': capitalPrete,
      'gainsTotauxAttendus': gainsTotauxAttendus,
      'rendementTotal': rendementTotal,
      'tauxMoyenPondere': tauxMoyenPondere,
      // 📊 Nouveaux KPIs avancés
      'plusGrosCreancier': plusGrosCreancier,
      'plusGrosMontant': plusGrosMontant,
      'pourcentageDansLesTemps': pourcentageDansLesTemps,
      'pourcentageEnRetard': pourcentageEnRetard,
      'tauxDefaut': tauxDefaut,
      'dureeMoyenne': dureeMoyenne,
      'montantMoyenParUtilisateur': montantMoyenParUtilisateur,
      // 💵 Statistiques de recouvrement
      'sommesRecouvertes': sommesRecouvertes,
      'capitalRecouvre': capitalRecouvre,
      'interetsRecouvres': interetsRecouvres,
      'tauxRecouvrement': tauxRecouvrement,
    };
  }

  List<FlSpot> _generateTrendData(AdminProvider adminProvider) {
    // Générer des données de tendance basées sur les vrais prêts
    // Pour l'exemple, nous utiliserons des données simulées mais vous pouvez
    // les remplacer par de vraies données groupées par mois
    final now = DateTime.now();
    final data = <FlSpot>[];

    for (int i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - (5 - i));
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
