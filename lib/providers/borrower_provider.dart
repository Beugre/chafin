import '../utils/logger.dart';
import 'package:flutter/material.dart';
import '../models/loan_model.dart';
import '../models/repayment_model.dart';
import '../services/borrower_service.dart';

class BorrowerProvider with ChangeNotifier {
  final BorrowerService _borrowerService = BorrowerService();

  List<LoanModel> _userLoans = [];
  List<RepaymentModel> _userRepayments = [];
  Map<String, dynamic> _loansSummary = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LoanModel> get userLoans => _userLoans;
  List<RepaymentModel> get userRepayments => _userRepayments;
  Map<String, dynamic> get loansSummary => _loansSummary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters filtrés
  List<LoanModel> get pendingLoans =>
      _userLoans.where((loan) => loan.isPending).toList();

  List<LoanModel> get approvedLoans =>
      _userLoans.where((loan) => loan.isApproved).toList();

  List<LoanModel> get activeLoans =>
      _userLoans.where((loan) => loan.isActive).toList();

  List<LoanModel> get completedLoans =>
      _userLoans.where((loan) => loan.isCompleted).toList();

  List<RepaymentModel> get pendingRepayments =>
      _userRepayments.where((repayment) => repayment.isPending).toList();

  List<RepaymentModel> get overdueRepayments =>
      _userRepayments.where((repayment) => repayment.isOverdue).toList();

  /// Charger toutes les données de l'utilisateur
  Future<void> loadUserData(String userId) async {
    try {
      _setLoading(true);
      _error = null;

      debugLog('=== BorrowerProvider.loadUserData ===');
      debugLog('Chargement données pour user: $userId');

      // Charger en parallèle
      final futures = await Future.wait([
        _borrowerService.getUserLoans(userId),
        _borrowerService.getUserRepayments(userId),
        _borrowerService.getUserLoansSummary(userId),
      ]);

      _userLoans = futures[0] as List<LoanModel>;
      _userRepayments = futures[1] as List<RepaymentModel>;
      _loansSummary = futures[2] as Map<String, dynamic>;

      debugLog('Données chargées:');
      debugLog('- Prêts: ${_userLoans.length}');
      debugLog('- Remboursements: ${_userRepayments.length}');
      debugLog('- Résumé: $_loansSummary');

      notifyListeners();
    } catch (e) {
      debugLog('Erreur chargement données utilisateur: $e');
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiser les données
  Future<void> refreshUserData(String userId) async {
    await loadUserData(userId);
  }

  /// Récupérer les détails d'un prêt spécifique
  Future<LoanModel?> getLoanDetails(String loanId, String userId) async {
    try {
      return await _borrowerService.getLoanDetails(loanId, userId);
    } catch (e) {
      debugLog('Erreur récupération détail prêt: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Récupérer l'échéancier d'un prêt spécifique
  Future<List<RepaymentModel>> getLoanRepayments(String loanId) async {
    try {
      return await _borrowerService.getLoanRepayments(loanId);
    } catch (e) {
      debugLog('Erreur récupération échéancier prêt: $e');
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Obtenir la prochaine échéance
  RepaymentModel? get nextPayment {
    final pending = pendingRepayments;
    if (pending.isEmpty) return null;

    pending.sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    return pending.first;
  }

  /// Obtenir le montant total dû ce mois
  double get monthlyDueAmount {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    return _userRepayments
        .where(
          (repayment) =>
              repayment.isPending &&
              repayment.dateEcheance.isAfter(thisMonth) &&
              repayment.dateEcheance.isBefore(nextMonth),
        )
        .fold(0.0, (sum, repayment) => sum + repayment.montantDu);
  }

  /// Méthodes utilitaires privées
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _userLoans.clear();
    _userRepayments.clear();
    _loansSummary.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
