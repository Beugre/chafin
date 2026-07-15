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
  final _currencyFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 0,
  );
  final _currencyFmtDecimal = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );

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
      body: Consumer2<AuthProvider, LoanProvider>(
        builder: (context, authProvider, loanProvider, _) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }
          final loans = loanProvider.userLoans;
          final activeLoans = loans
              .where((l) => l.isActive || l.statut == LoanStatus.enRetard)
              .toList();
          final pendingLoans = loans
              .where(
                (l) =>
                    l.isPending ||
                    l.statut == LoanStatus.approuve ||
                    l.statut == LoanStatus.brouillon ||
                    l.statut == LoanStatus.decaissementEffectue,
              )
              .toList();
          final completedLoans = loans.where((l) => l.isCompleted).toList();
          final totalOutstanding = activeLoans.fold(
            0.0,
            (s, l) => s + l.montant,
          );
          final totalInterests = activeLoans.fold(
            0.0,
            (s, l) => s + (l.coutTotalEstime - l.montant),
          );
          final monthlyPayment = activeLoans.fold(
            0.0,
            (s, l) => s + l.mensualite,
          );
          // KPIs globaux (tous prêts confondus)
          final totalBorrowed = loans.fold(0.0, (s, l) => s + l.montant);
          final totalCost = loans.fold(0.0, (s, l) => s + l.coutTotalEstime);
          final loanCount = loans.length;
          final name =
              (user.prenom?.isNotEmpty == true ? user.prenom : user.nom) ??
              'Utilisateur';

          // Calculer la prochaine échéance parmi les prêts actifs
          DateTime? nextDueDate;
          double nextDueAmount = 0;
          for (final l in activeLoans) {
            if (l.disbursedAt != null) {
              final monthsElapsed =
                  DateTime.now().difference(l.disbursedAt!).inDays ~/ 30;
              final nextMonth = DateTime(
                l.disbursedAt!.year,
                l.disbursedAt!.month + monthsElapsed + 1,
                l.disbursedAt!.day,
              );
              if (nextDueDate == null || nextMonth.isBefore(nextDueDate)) {
                nextDueDate = nextMonth;
                nextDueAmount = l.mensualite;
              }
            }
          }

          // Progression globale
          double globalProgress = 0;
          if (activeLoans.isNotEmpty) {
            double totalProgress = 0;
            for (final l in activeLoans) {
              if (l.disbursedAt != null) {
                final elapsed =
                    DateTime.now().difference(l.disbursedAt!).inDays / 30.44;
                totalProgress += (elapsed / l.dureeMois).clamp(0.0, 1.0);
              }
            }
            globalProgress = totalProgress / activeLoans.length;
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async => _loadUserLoans(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Hero dark header ──
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF0F1629),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top bar
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Bonjour, $name',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/notifications'),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            // Balance
                            const Text(
                              'Encours total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFmt.format(totalOutstanding),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Pills
                            Row(
                              children: [
                                _buildDarkPill(
                                  '${activeLoans.length} actif${activeLoans.length > 1 ? "s" : ""}',
                                  AppTheme.successColor,
                                ),
                                if (pendingLoans.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _buildDarkPill(
                                    '${pendingLoans.length} en attente',
                                    AppTheme.warningColor,
                                  ),
                                ],
                                if (completedLoans.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _buildDarkPill(
                                    '${completedLoans.length} soldé${completedLoans.length > 1 ? "s" : ""}',
                                    AppTheme.textHintColor,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if ((user.niveauConfiance ?? 5.0) < 2.0)
                  SliverToBoxAdapter(child: _buildRiskBanner()),

                // ── KPIs Row 1 ──
                if (loans.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              'Mensualité',
                              _currencyFmtDecimal.format(monthlyPayment),
                              Icons.calendar_today_rounded,
                              AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              'Intérêts',
                              _currencyFmt.format(totalInterests),
                              Icons.trending_up_rounded,
                              AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              'Remboursé',
                              activeLoans.isNotEmpty
                                  ? '${(globalProgress * 100).toInt()}%'
                                  : '—',
                              Icons.pie_chart_rounded,
                              AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── KPIs Row 2 ──
                if (loans.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              'Total emprunté',
                              _currencyFmt.format(totalBorrowed),
                              Icons.account_balance_wallet_rounded,
                              const Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              'Coût total',
                              _currencyFmt.format(totalCost),
                              Icons.receipt_long_rounded,
                              const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildKpiCard(
                              'Nb prêts',
                              '$loanCount',
                              Icons.format_list_numbered_rounded,
                              const Color(0xFF14B8A6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Prochaine échéance ──
                if (nextDueDate != null && activeLoans.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildNextPaymentCard(nextDueDate, nextDueAmount),
                  ),

                // ── Progression globale ──
                if (activeLoans.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildProgressSection(activeLoans, globalProgress),
                  ),

                // ── CTA Nouvelle demande ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: GestureDetector(
                      onTap: () => context.go('/loan-request'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEAECF0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nouvelle demande',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Faire une demande de prêt',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textHintColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Prêts récents ──
                SliverToBoxAdapter(child: _buildRecentSection(loans)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── KPI Card ──
  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Next Payment Card ──
  Widget _buildNextPaymentCard(DateTime dueDate, double amount) {
    final now = DateTime.now();
    final daysUntil = dueDate.difference(now).inDays;
    final isUrgent = daysUntil <= 5;
    final dateFmt = DateFormat('d MMM', 'fr_FR');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUrgent
              ? AppTheme.errorColor.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent
                ? AppTheme.errorColor.withOpacity(0.2)
                : const Color(0xFFEAECF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isUrgent
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUrgent ? Icons.warning_rounded : Icons.event_rounded,
                color: isUrgent ? AppTheme.errorColor : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prochaine échéance',
                    style: TextStyle(
                      fontSize: 12,
                      color: isUrgent
                          ? AppTheme.errorColor
                          : AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFmt.format(dueDate)} · ${daysUntil > 0 ? 'dans $daysUntil j' : "aujourd'hui"}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isUrgent
                          ? AppTheme.errorColor
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _currencyFmtDecimal.format(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isUrgent
                    ? AppTheme.errorColor
                    : AppTheme.textPrimaryColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress Section ──
  Widget _buildProgressSection(
    List<LoanModel> activeLoans,
    double globalProgress,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progression',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  '${(globalProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: globalProgress,
                backgroundColor: const Color(0xFFF0F1F5),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            // Per-loan mini breakdown
            for (final l in activeLoans) ...[_buildLoanProgressRow(l)],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanProgressRow(LoanModel loan) {
    double progress = 0;
    int monthsRemaining = loan.dureeMois;
    if (loan.disbursedAt != null) {
      final elapsed =
          DateTime.now().difference(loan.disbursedAt!).inDays / 30.44;
      progress = (elapsed / loan.dureeMois).clamp(0.0, 1.0);
      monthsRemaining = (loan.dureeMois - elapsed.floor()).clamp(
        0,
        loan.dureeMois,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _currencyFmt.format(loan.montant),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF0F1F5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  loan.statut == LoanStatus.enRetard
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              '${monthsRemaining}m',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkPill(String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Loans ─────────────────────────────────
  Widget _buildRecentSection(List<LoanModel> loans) {
    if (loans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppTheme.textHintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun prêt pour le moment',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/my-loans'),
                child: const Text(
                  'Tout voir',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAECF0)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < recent.length; i++) ...[
                _buildLoanTile(recent[i]),
                if (i < recent.length - 1)
                  const Divider(height: 1, indent: 64, endIndent: 16),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.euro_rounded,
                  color: AppTheme.textSecondaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFmt.format(loan.montant),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
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
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.errorColor,
            size: 22,
          ),
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
