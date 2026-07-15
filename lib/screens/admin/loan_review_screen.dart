import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../models/loan_model.dart';
import '../../models/schedule_item_model.dart';
import '../../models/user_model.dart';
import '../../widgets/edit_interest_rate_dialog.dart';
import '../../services/loan_service.dart';
import '../../services/admin_service.dart';

class LoanReviewScreen extends StatefulWidget {
  final String loanId;

  const LoanReviewScreen({super.key, required this.loanId});

  @override
  State<LoanReviewScreen> createState() => _LoanReviewScreenState();
}

class _LoanReviewScreenState extends State<LoanReviewScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

  bool _isLoading = true;
  LoanModel? _loan;
  UserModel? _borrower;
  List<ScheduleItemModel> _schedules = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    // Ensure data is loaded
    if (adminProvider.allLoans.isEmpty) {
      await adminProvider.loadAllAdminData();
    }

    final loan = adminProvider.allLoans.firstWhere(
      (l) => l.id == widget.loanId,
      orElse: () => throw Exception('Prêt non trouvé'),
    );

    final borrower = await adminProvider.getUserById(loan.userId);

    final schedules =
        adminProvider.allSchedules
            .where((s) => s.loanId == widget.loanId)
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));

    if (mounted) {
      setState(() {
        _loan = loan;
        _borrower = borrower;
        _schedules = schedules;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(
          _loan != null
              ? 'Révision — ${_loan!.nomEmprunteur}'
              : 'Révision du prêt',
        ),
        actions: [
          if (_loan != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
            )
          : _loan == null
          ? const Center(
              child: Text(
                'Prêt introuvable',
                style: TextStyle(color: Colors.white),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBanner(),
                    const SizedBox(height: 16),
                    _buildBorrowerCard(),
                    const SizedBox(height: 16),
                    _buildLoanDetailsCard(),
                    const SizedBox(height: 16),
                    if (_loan!.ribEmprunteur.isNotEmpty) ...[
                      _buildRibCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_schedules.isNotEmpty) ...[
                      _buildScheduleCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_loan!.noteAdmin != null &&
                        _loan!.noteAdmin!.isNotEmpty) ...[
                      _buildAdminNoteCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildActionsCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Status Banner ──
  Widget _buildStatusBanner() {
    final loan = _loan!;
    Color color;
    String label;
    IconData icon;

    switch (loan.statut) {
      case LoanStatus.soumis:
        color = const Color(0xFFF59E0B);
        label = 'En attente de révision';
        icon = Icons.hourglass_empty;
      case LoanStatus.enRevue:
        color = const Color(0xFFF59E0B);
        label = 'En cours de révision';
        icon = Icons.rate_review;
      case LoanStatus.approuve:
        color = const Color(0xFF10B981);
        label = 'Approuvé — en attente de décaissement';
        icon = Icons.check_circle;
      case LoanStatus.refuse:
        color = const Color(0xFFEF4444);
        label = 'Rejeté';
        icon = Icons.cancel;
      case LoanStatus.decaissementEffectue:
        color = const Color(0xFF00D4FF);
        label = 'Décaissement effectué';
        icon = Icons.account_balance;
      case LoanStatus.enCours:
        color = const Color(0xFF00D4FF);
        label = 'En cours de remboursement';
        icon = Icons.trending_up;
      case LoanStatus.enRetard:
        color = const Color(0xFFEF4444);
        label = 'En retard de paiement';
        icon = Icons.warning;
      case LoanStatus.solde:
        color = const Color(0xFF10B981);
        label = 'Soldé';
        icon = Icons.check_circle_outline;
      case LoanStatus.ferme:
        color = const Color(0xFF8B5CF6);
        label = 'Fermé';
        icon = Icons.done_all;
      default:
        color = Colors.grey;
        label = loan.statut.name;
        icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Borrower Info Card ──
  Widget _buildBorrowerCard() {
    final loan = _loan!;
    return _buildSection(
      title: 'Emprunteur',
      icon: Icons.person,
      child: Column(
        children: [
          _buildInfoRow('Nom', loan.nomEmprunteur),
          if (_borrower != null) ...[
            _buildInfoRow('Email', _borrower!.email),
            _buildInfoRow('Téléphone', _borrower!.telephone),
            _buildInfoRow('Adresse', _borrower!.adresse),
          ],
          if (loan.parrainEmail != null && loan.parrainEmail!.isNotEmpty)
            _buildInfoRow('Parrain', loan.parrainEmail!),
        ],
      ),
    );
  }

  // ── Loan Details Card ──
  Widget _buildLoanDetailsCard() {
    final loan = _loan!;
    return _buildSection(
      title: 'Détails du prêt',
      icon: Icons.description,
      child: Column(
        children: [
          _buildInfoRow('Montant', _currencyFormat.format(loan.montant)),
          _buildInfoRow('Durée', '${loan.dureeMois} mois'),
          _buildInfoRow(
            'Taux appliqué',
            '${loan.tauxAnnuel.toStringAsFixed(2)}%',
          ),
          _buildInfoRow('Mensualité', _currencyFormat.format(loan.mensualite)),
          _buildInfoRow(
            'Coût total (intérêts)',
            _currencyFormat.format(loan.coutTotalEstime),
          ),
          _buildInfoRow(
            'Total à rembourser',
            _currencyFormat.format(loan.montant + loan.coutTotalEstime),
          ),
          const Divider(color: Colors.white24, height: 16),
          _buildInfoRow(
            'Date souhaitée',
            _dateFormat.format(loan.dateSouhaitee),
          ),
          _buildInfoRow(
            '1er remboursement',
            _dateFormat.format(loan.datePremierRemboursement),
          ),
          _buildInfoRow('Demandé le', _dateFormat.format(loan.createdAt)),
          if (loan.approvedAt != null)
            _buildInfoRow('Approuvé le', _dateFormat.format(loan.approvedAt!)),
          if (loan.disbursedAt != null)
            _buildInfoRow('Décaissé le', _dateFormat.format(loan.disbursedAt!)),
          if (loan.dateVirement != null)
            _buildInfoRow(
              'Date virement',
              _dateFormat.format(loan.dateVirement!),
            ),
          if (loan.referenceDecaissement != null)
            _buildInfoRow('Réf. décaissement', loan.referenceDecaissement!),
        ],
      ),
    );
  }

  // ── RIB Card ──
  Widget _buildRibCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Color(0xFF00D4FF), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIB / IBAN à créditer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _loan!.ribEmprunteur,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule Table ──
  Widget _buildScheduleCard() {
    final now = DateTime.now();
    return _buildSection(
      title: 'Échéancier (${_schedules.length} échéances)',
      icon: Icons.calendar_month,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Capital',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Intérêt',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Payé',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(_schedules.length, (i) {
            final s = _schedules[i];
            final isOverdue = !s.isPaid && s.dueDate.isBefore(now);
            final bgColor = s.isPaid
                ? const Color(0xFF10B981).withOpacity(0.08)
                : isOverdue
                ? const Color(0xFFEF4444).withOpacity(0.08)
                : Colors.transparent;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${s.numero}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _dateFormat.format(s.dueDate),
                      style: TextStyle(
                        color: isOverdue
                            ? const Color(0xFFEF4444)
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${s.principal.toStringAsFixed(0)}€',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${s.interet.toStringAsFixed(0)}€',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${s.total.toStringAsFixed(0)}€',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Icon(
                      s.isPaid
                          ? Icons.check_circle
                          : (isOverdue
                                ? Icons.error
                                : Icons.radio_button_unchecked),
                      color: s.isPaid
                          ? const Color(0xFF10B981)
                          : (isOverdue
                                ? const Color(0xFFEF4444)
                                : Colors.white24),
                      size: 16,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Summary row
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payé: ${_schedules.where((s) => s.isPaid).length}/${_schedules.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  'Remboursé: ${_currencyFormat.format(_schedules.where((s) => s.isPaid).fold(0.0, (sum, s) => sum + s.total))}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Admin Note ──
  Widget _buildAdminNoteCard() {
    return _buildSection(
      title: 'Note admin',
      icon: Icons.note,
      child: Text(
        _loan!.noteAdmin!,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // ── Actions Card ──
  Widget _buildActionsCard() {
    final loan = _loan!;
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    return _buildSection(
      title: 'Actions',
      icon: Icons.settings,
      child: Column(
        children: [
          // Actions selon le statut
          if (loan.statut == LoanStatus.soumis ||
              loan.statut == LoanStatus.enRevue) ...[
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    'Approuver',
                    Icons.check_circle,
                    const Color(0xFF10B981),
                    () => _approveLoan(adminProvider),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionBtn(
                    'Rejeter',
                    Icons.cancel,
                    const Color(0xFFEF4444),
                    () => _rejectLoan(adminProvider),
                    isOutlined: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionBtn(
                'Modifier le taux',
                Icons.edit_outlined,
                const Color(0xFF8B5CF6),
                () => _editInterestRate(loan),
                isOutlined: true,
              ),
            ),
          ],

          if (loan.statut == LoanStatus.approuve) ...[
            SizedBox(
              width: double.infinity,
              child: _buildActionBtn(
                'Confirmer le décaissement',
                Icons.account_balance_wallet,
                const Color(0xFF00D4FF),
                () => _confirmDisbursement(adminProvider),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionBtn(
                'Modifier le taux',
                Icons.edit_outlined,
                const Color(0xFF8B5CF6),
                () => _editInterestRate(loan),
                isOutlined: true,
              ),
            ),
          ],

          if (loan.statut == LoanStatus.enCours ||
              loan.statut == LoanStatus.enRetard) ...[
            Row(
              children: [
                Expanded(
                  child: _buildActionBtn(
                    'Modifier le taux',
                    Icons.edit_outlined,
                    const Color(0xFF8B5CF6),
                    () => _editInterestRate(loan),
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionBtn(
                    'Dates échéances',
                    Icons.calendar_month,
                    const Color(0xFF00D4FF),
                    () => context.push(
                      '/admin/edit-schedule-dates/${loan.id}',
                      extra: loan,
                    ),
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ],

          // Annulation (toujours disponible sauf si déjà annulé/fermé/soldé)
          if (![
            LoanStatus.annule,
            LoanStatus.ferme,
            LoanStatus.solde,
            LoanStatus.refuse,
          ].contains(loan.statut)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _buildActionBtn(
                'Annuler le prêt',
                Icons.block,
                Colors.grey,
                () => _cancelLoan(adminProvider),
                isOutlined: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared Widgets ──

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
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

  // ── Action Methods ──

  Future<void> _approveLoan(AdminProvider adminProvider) async {
    final confirm = await _showConfirmDialog(
      'Approuver ce prêt ?',
      'Le prêt sera marqué comme approuvé et un email sera envoyé à l\'emprunteur.',
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await adminProvider.approveLoan(widget.loanId);
    if (mounted) {
      _showSnack(
        success ? 'Prêt approuvé ✅' : 'Erreur lors de l\'approbation',
        success,
      );
      await _loadData();
    }
  }

  Future<void> _rejectLoan(AdminProvider adminProvider) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await adminProvider.rejectLoan(widget.loanId, reason);
    if (mounted) {
      _showSnack(success ? 'Prêt rejeté ✅' : 'Erreur lors du rejet', success);
      await _loadData();
    }
  }

  Future<void> _confirmDisbursement(AdminProvider adminProvider) async {
    final confirm = await _showConfirmDialog(
      'Confirmer le décaissement ?',
      'L\'échéancier sera généré automatiquement et un email envoyé à l\'emprunteur.',
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await AdminService().confirmLoanDisbursement(widget.loanId);
      await adminProvider.loadAllAdminData();
      if (mounted) {
        _showSnack('Décaissement confirmé ✅', true);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Erreur: $e', false);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editInterestRate(LoanModel loan) async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => EditInterestRateDialog(loan: loan),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      final success = await LoanService().updateInterestRate(loan.id, result);
      if (mounted) {
        if (success) {
          final adminProvider = Provider.of<AdminProvider>(
            context,
            listen: false,
          );
          await adminProvider.loadAllAdminData();
          _showSnack('Taux modifié ✅', true);
        } else {
          _showSnack('Erreur modification taux', false);
        }
        await _loadData();
      }
    }
  }

  Future<void> _cancelLoan(AdminProvider adminProvider) async {
    final reason = await _showRejectDialog(
      title: 'Annuler le prêt',
      buttonLabel: 'Annuler le prêt',
      hint: 'Raison de l\'annulation...',
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await adminProvider.cancelLoanAsAdmin(
      loanId: widget.loanId,
      adminId: 'admin',
      reason: reason,
    );
    if (mounted) {
      _showSnack(
        success ? 'Prêt annulé ✅' : 'Erreur lors de l\'annulation',
        success,
      );
      await _loadData();
    }
  }

  // ── Dialogs ──

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRejectDialog({
    String title = 'Rejeter le prêt',
    String buttonLabel = 'Rejeter',
    String hint = 'Raison du rejet...',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
