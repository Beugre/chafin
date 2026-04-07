import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan_model.dart';
import '../../config/app_theme.dart';

class BorrowerDashboardScreen extends StatefulWidget {
  const BorrowerDashboardScreen({super.key});

  @override
  State<BorrowerDashboardScreen> createState() =>
      _BorrowerDashboardScreenState();
}

class _BorrowerDashboardScreenState extends State<BorrowerDashboardScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserLoans());
  }

  void _loadUserLoans() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loans = Provider.of<LoanProvider>(context, listen: false);
    if (auth.currentUser != null) {
      loans.loadUserLoans(auth.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer2<AuthProvider, LoanProvider>(
          builder: (context, authProvider, loanProvider, _) {
            final user = authProvider.currentUser;
            if (authProvider.isLoading && user == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            if (user == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            final loans = loanProvider.userLoans;
            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async => _loadUserLoans(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(user, context)),
                  if ((user.niveauConfiance ?? 5.0) < 2.0)
                    SliverToBoxAdapter(child: _buildRiskBanner()),
                  SliverToBoxAdapter(child: _buildBalanceCard(loans, context)),
                  SliverToBoxAdapter(child: _buildQuickActions(context)),
                  SliverToBoxAdapter(child: _buildRecentSection(loans)),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header Revolut ──────────────────────────────
  Widget _buildHeader(dynamic user, BuildContext context) {
    final name = (user.prenom?.isNotEmpty == true ? user.prenom : user.nom) ?? 'Utilisateur';
    final initial = name.substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, $name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  _getDayGreeting(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimaryColor,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonne matinée';
    if (h < 18) return 'Bon après-midi';
    return 'Bonne soirée';
  }

  // ── Balance Card (hero style Revolut) ───────────
  Widget _buildBalanceCard(List<LoanModel> loans, BuildContext context) {
    final activeLoans = loans.where((l) => l.isActive).toList();
    final pendingCount = loans.where((l) => l.isPending).length;
    final totalOutstanding = activeLoans.fold(0.0, (s, l) => s + l.montant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.elevatedShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encours total',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _currencyFmt.format(totalOutstanding),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildBalancePill(
                  '${activeLoans.length} actif${activeLoans.length > 1 ? "s" : ""}',
                  AppTheme.successColor,
                ),
                const SizedBox(width: 8),
                if (pendingCount > 0)
                  _buildBalancePill('$pendingCount en attente', AppTheme.warningColor),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/loan-request'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('+ Demande'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions (Revolut style) ────────────────
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _ActionItem(Icons.add_circle_outline, 'Demande', AppTheme.primaryColor, '/loan-request'),
      _ActionItem(Icons.account_balance_wallet_outlined, 'Mes prêts', AppTheme.secondaryColor, '/my-loans'),
      _ActionItem(Icons.person_outline, 'Profil', AppTheme.warningColor, '/profile'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = actions[i];
              return GestureDetector(
                onTap: () => context.go(a.route),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(a.icon, color: a.color, size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Recent Loans (transactions style) ────────────
  Widget _buildRecentSection(List<LoanModel> loans) {
    if (loans.isEmpty) return const SizedBox.shrink();
    final recent = loans.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prêts récents',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/my-loans'),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              for (int i = 0; i < recent.length; i++) ...[
                _buildLoanTile(recent[i]),
                if (i < recent.length - 1)
                  const Divider(height: 1, indent: 70),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanTile(LoanModel loan) {
    final color = _statusColor(loan.statut);
    final label = _statusLabel(loan.statut);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/loan-details/${loan.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.euro_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFmt.format(loan.montant),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loan.dureeMois} mois · ${loan.tauxAnnuel.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Risk Banner ──────────────────────────────────
  Widget _buildRiskBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Niveau de risque élevé — Régularisez vos paiements pour améliorer votre profil.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────
  Color _statusColor(LoanStatus s) {
    switch (s) {
      case LoanStatus.soumis:
      case LoanStatus.enRevue:
        return AppTheme.warningColor;
      case LoanStatus.approuve:
      case LoanStatus.solde:
        return AppTheme.successColor;
      case LoanStatus.enCours:
      case LoanStatus.decaissementEffectue:
        return AppTheme.primaryColor;
      default:
        return AppTheme.errorColor;
    }
  }

  String _statusLabel(LoanStatus s) {
    switch (s) {
      case LoanStatus.soumis:
        return 'Envoyé';
      case LoanStatus.enRevue:
        return 'En revue';
      case LoanStatus.approuve:
        return 'Approuvé';
      case LoanStatus.enCours:
      case LoanStatus.decaissementEffectue:
        return 'Actif';
      case LoanStatus.solde:
        return 'Terminé';
      case LoanStatus.refuse:
        return 'Refusé';
      case LoanStatus.annule:
        return 'Annulé';
      case LoanStatus.enRetard:
        return 'En retard';
      default:
        return 'Brouillon';
    }
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _ActionItem(this.icon, this.label, this.color, this.route);
}
