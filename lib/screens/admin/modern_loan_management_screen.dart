import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/loan_model.dart';
import '../../widgets/edit_interest_rate_dialog.dart';
import '../../services/loan_service.dart';

class ModernLoanManagementScreen extends StatefulWidget {
  const ModernLoanManagementScreen({super.key});

  @override
  State<ModernLoanManagementScreen> createState() =>
      _ModernLoanManagementScreenState();
}

class _ModernLoanManagementScreenState extends State<ModernLoanManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '€',
    decimalDigits: 0,
  );

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);

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

  List<LoanModel> _filterLoans(List<LoanModel> loans) {
    if (_searchQuery.isEmpty) return loans;

    return loans
        .where(
          (loan) =>
              loan.nomEmprunteur.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              loan.montant.toString().contains(_searchQuery),
        )
        .toList();
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

          return Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoansList(adminProvider.allLoans, adminProvider),
                    _buildLoansList(adminProvider.pendingLoans, adminProvider),
                    _buildLoansList(adminProvider.approvedLoans, adminProvider),
                    _buildLoansList(
                      adminProvider.allLoans
                          .where(
                            (l) => l.statut == LoanStatus.decaissementEffectue,
                          )
                          .toList(),
                      adminProvider,
                    ),
                    _buildLoansList(
                      adminProvider.allLoans
                          .where((l) => l.statut == LoanStatus.enCours)
                          .toList(),
                      adminProvider,
                    ),
                    _buildLoansList(
                      adminProvider.allLoans
                          .where((l) => l.statut == LoanStatus.enRetard)
                          .toList(),
                      adminProvider,
                    ),
                    _buildLoansList(
                      adminProvider.allLoans
                          .where(
                            (l) =>
                                l.statut == LoanStatus.solde ||
                                l.statut == LoanStatus.ferme,
                          )
                          .toList(),
                      adminProvider,
                    ),
                  ],
                ),
              ),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Gestion des prêts',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
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
        isScrollable: true,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Tous'),
          Tab(text: 'En attente'),
          Tab(text: 'Approuvés'),
          Tab(text: 'Décaissés'),
          Tab(text: 'En cours'),
          Tab(text: 'En retard'),
          Tab(text: 'Terminés'),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher par nom ou montant...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.7),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
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
            'Chargement des prêts...',
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

  Widget _buildLoansList(List<LoanModel> loans, AdminProvider adminProvider) {
    final filteredLoans = _filterLoans(loans);

    if (filteredLoans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun prêt trouvé',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00D4FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredLoans.length,
        itemBuilder: (context, index) {
          final loan = filteredLoans[index];
          return _buildModernLoanCard(loan, adminProvider);
        },
      ),
    );
  }

  Widget _buildModernLoanCard(LoanModel loan, AdminProvider adminProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: () => context.push('/loan-details/${loan.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et statut
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.nomEmprunteur.isNotEmpty
                              ? loan.nomEmprunteur
                              : 'Emprunteur inconnu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${loan.id.substring(0, 8)}...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(loan.statut),
                ],
              ),
              const SizedBox(height: 16),

              // Montant principal
              Text(
                _currencyFormat.format(loan.montant),
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Détails du prêt
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDetailColumn(
                        'Durée',
                        '${loan.dureeMois} mois',
                        Icons.schedule,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    Expanded(
                      child: _buildDetailColumn(
                        'Taux',
                        '${loan.tauxAnnuel.toStringAsFixed(2)}%',
                        Icons.percent,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    Expanded(
                      child: _buildDetailColumn(
                        'Créé le',
                        DateFormat('dd/MM/yy').format(loan.createdAt),
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions selon le statut
              if (loan.statut == LoanStatus.soumis) ...[
                const SizedBox(height: 16),
                // Actions principales
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Approuver',
                        icon: Icons.check_circle,
                        color: const Color(0xFF10B981),
                        onPressed: () => _approveLoan(loan.id, adminProvider),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Rejeter',
                        icon: Icons.cancel,
                        color: const Color(0xFFEF4444),
                        onPressed: () => _rejectLoan(loan.id, adminProvider),
                        isOutlined: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action secondaire - Modifier le taux
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    label: 'Modifier le taux d\'intérêt',
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF8B5CF6),
                    onPressed: () => _editInterestRate(loan),
                    isOutlined: true,
                  ),
                ),
              ],

              // Actions pour prêts approuvés, en cours, décaissés, en retard ou soldés
              if (loan.statut == LoanStatus.approuve ||
                  loan.statut == LoanStatus.enCours ||
                  loan.statut == LoanStatus.decaissementEffectue ||
                  loan.statut == LoanStatus.enRetard ||
                  loan.statut == LoanStatus.solde) ...[
                const SizedBox(height: 16),

                // Banner info pour prêts approuvés
                if (loan.statut == LoanStatus.approuve) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prêt approuvé - En attente de décaissement',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: 'Modifier le taux',
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF8B5CF6),
                        onPressed: () => _editInterestRate(loan),
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Dates échéances',
                        icon: Icons.calendar_month,
                        color: const Color(0xFF00D4FF),
                        onPressed: () => context.push(
                          '/admin/edit-schedule-dates/${loan.id}',
                          extra: loan,
                        ),
                        isOutlined: true,
                      ),
                    ),
                  ],
                ),

                // ── Toggles Emails / Pénalités ──
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        icon: Icons.email_outlined,
                        label: 'Emails de relance',
                        value: !loan.emailsDisabled,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) =>
                            _toggleLoanFlag(loan.id, 'emailsDisabled', !val),
                      ),
                      Divider(color: Colors.white.withOpacity(0.1), height: 8),
                      _buildToggleRow(
                        icon: Icons.gavel_outlined,
                        label: 'Pénalités de retard',
                        value: !loan.penaltiesDisabled,
                        activeColor: const Color(0xFFF59E0B),
                        onChanged: (val) =>
                            _toggleLoanFlag(loan.id, 'penaltiesDisabled', !val),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: value ? activeColor : Colors.white.withOpacity(0.4),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: value ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            activeColor: activeColor,
            inactiveThumbColor: Colors.white.withOpacity(0.3),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLoanFlag(String loanId, String field, bool value) async {
    try {
      await LoanService().updateLoanField(loanId, field, value);

      // Refresh les données
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      await adminProvider.loadAllLoans();

      if (mounted) {
        final label = field == 'emailsDisabled'
            ? (value ? 'Emails désactivés' : 'Emails activés')
            : (value ? 'Pénalités désactivées' : 'Pénalités activées');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $label pour ce prêt'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(LoanStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case LoanStatus.soumis:
        color = const Color(0xFFF59E0B);
        label = 'En attente';
        icon = Icons.hourglass_empty;
        break;
      case LoanStatus.approuve:
        color = const Color(0xFF10B981);
        label = 'Approuvé';
        icon = Icons.check_circle;
        break;
      case LoanStatus.refuse:
        color = const Color(0xFFEF4444);
        label = 'Refusé';
        icon = Icons.cancel;
        break;
      case LoanStatus.enCours:
        color = const Color(0xFF00D4FF);
        label = 'En cours';
        icon = Icons.trending_up;
        break;
      case LoanStatus.ferme:
        color = const Color(0xFF8B5CF6);
        label = 'Fermé';
        icon = Icons.done_all;
        break;
      case LoanStatus.solde:
        color = const Color(0xFF10B981);
        label = 'Soldé';
        icon = Icons.check_circle_outline;
        break;
      case LoanStatus.enRetard:
        color = const Color(0xFFEF4444);
        label = 'En retard';
        icon = Icons.warning;
        break;
      case LoanStatus.annule:
        color = const Color(0xFF6B7280);
        label = 'Annulé';
        icon = Icons.block;
        break;
      case LoanStatus.decaissementEffectue:
        color = const Color(0xFF00D4FF);
        label = 'Décaissé';
        icon = Icons.account_balance;
        break;
      default:
        color = Colors.grey;
        label = status.name;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
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

  Widget _buildDetailColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      height: 44,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Future<void> _approveLoan(String loanId, AdminProvider adminProvider) async {
    final success = await adminProvider.approveLoan(loanId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Prêt approuvé avec succès'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _rejectLoan(String loanId, AdminProvider adminProvider) async {
    final reason = await _showRejectDialog();
    if (reason != null && reason.isNotEmpty) {
      final success = await adminProvider.rejectLoan(loanId, reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Prêt rejeté avec succès'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rejeter le prêt',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Raison du rejet',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            hintText: 'Expliquez pourquoi ce prêt est rejeté...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00D4FF)),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  /// Ouvre le dialog pour modifier le taux d'intérêt
  Future<void> _editInterestRate(LoanModel loan) async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => EditInterestRateDialog(loan: loan),
    );

    if (result != null && mounted) {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );

      try {
        final success = await LoanService().updateInterestRate(loan.id, result);

        if (mounted) {
          Navigator.of(context).pop(); // Ferme le loading

          if (success) {
            // Refresh des données
            final adminProvider = Provider.of<AdminProvider>(
              context,
              listen: false,
            );
            await adminProvider.loadAllLoans();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Taux d\'intérêt modifié avec succès'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Erreur lors de la modification du taux'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Ferme le loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: const Color(0xFFEF4444),
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
