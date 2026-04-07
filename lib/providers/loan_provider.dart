import 'package:flutter/material.dart';
import '../models/loan_model.dart';
import '../models/schedule_item_model.dart';
import '../services/loan_service.dart';
import '../services/loan_calculation_service.dart';
import '../services/email_service.dart';

class LoanProvider with ChangeNotifier {
  final LoanService _loanService = LoanService();

  List<LoanModel> _userLoans = [];
  List<LoanModel> _allLoans = [];
  List<ScheduleItemModel> _currentSchedule = [];
  LoanModel? _currentLoan;
  bool _isLoading = false;
  String? _errorMessage;

  // Calculs en temps réel pour le formulaire
  double _montant = 0;
  int _dureeMois = 12;
  double _tauxCalcule = 0;
  double _mensualiteCalculee = 0;
  double _coutTotalCalcule = 0;
  double _montantTotalARembourser = 0;
  double _interetsTotaux = 0;

  // Getters
  List<LoanModel> get userLoans => _userLoans;
  List<LoanModel> get allLoans => _allLoans;
  List<ScheduleItemModel> get currentSchedule => _currentSchedule;
  LoanModel? get currentLoan => _currentLoan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Getters pour les calculs
  double get montant => _montant;
  int get dureeMois => _dureeMois;
  double get tauxCalcule => _tauxCalcule;
  double get mensualiteCalculee => _mensualiteCalculee;
  double get coutTotalCalcule => _coutTotalCalcule;
  double get montantTotalARembourser => _montantTotalARembourser;
  double get interetsTotaux => _interetsTotaux;

  /// Calculer en temps réel les paramètres du prêt selon les VRAIES règles métier
  void calculateLoanParameters(
    double montant,
    int dureeMois, {
    double? niveauConfiance,
  }) {
    _montant = montant;
    _dureeMois = dureeMois;

    if (montant >= 10 && dureeMois > 0) {
      // VRAIE RÈGLE : Taux selon la durée avec prise en compte du niveau de confiance
      _tauxCalcule = LoanCalculationService.calculateTauxWithRisk(
        montant,
        dureeMois,
        niveauConfiance,
      );
      _mensualiteCalculee = LoanCalculationService.calculateMensualite(
        montant,
        _tauxCalcule,
        dureeMois,
      );
      _interetsTotaux = LoanCalculationService.calculateInteretsTotaux(
        montant,
        _tauxCalcule,
        dureeMois,
      );
      _montantTotalARembourser =
          LoanCalculationService.calculateMontantTotalARembourser(
            montant,
            _tauxCalcule,
            dureeMois,
          );
      _coutTotalCalcule =
          _interetsTotaux; // Coût total = intérêts totaux uniquement
    } else {
      _tauxCalcule = 0;
      _mensualiteCalculee = 0;
      _coutTotalCalcule = 0;
      _interetsTotaux = 0;
      _montantTotalARembourser = 0;
    }
    notifyListeners();
  }

  /// Calculer uniquement les paramètres sans niveau de confiance (pour affichage générique)
  void calculateBasicLoanParameters(double montant, int dureeMois) {
    calculateLoanParameters(montant, dureeMois);
  }

  /// Créer une demande de prêt
  Future<bool> createLoanRequest({
    required String userId,
    required String nomEmprunteur,
    required String ribEmprunteur,
    required double montant,
    required int dureeMois,
    // required String objetPret, // SUPPRIMÉ
    required DateTime dateSouhaitee,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final loan = await _loanService.createLoanRequest(
        userId: userId,
        nomEmprunteur: nomEmprunteur,
        ribEmprunteur: ribEmprunteur,
        montant: montant,
        dureeMois: dureeMois,
        // objetPret: objetPret, // SUPPRIMÉ
        dateSouhaitee: dateSouhaitee,
      );

      _userLoans.insert(0, loan);

      // ✨ NOUVEAU : Notification par email aux administrateurs
      try {
        print(
          '📧 Envoi de notifications aux administrateurs pour nouvelle demande',
        );

        final tauxCalcule = LoanCalculationService.calculateTauxSelonDuree(
          dureeMois,
        );

        await EmailService.sendEmailToAllAdmins(
          type: LoanEmailType.adminLoanRequest,
          loanData: {
            'borrowerName': nomEmprunteur,
            'amount': montant.toStringAsFixed(0),
            'duration': dureeMois.toString(),
            'rate': tauxCalcule.toStringAsFixed(1),
            'loanId': loan.id,
          },
        );

        print('✅ Notifications admin envoyées avec succès');
      } catch (emailError) {
        print('❌ Erreur lors de l\'envoi des notifications admin: $emailError');
        // Ne pas faire échouer la création du prêt si l'email échoue
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Charger les prêts d'un utilisateur
  Future<void> loadUserLoans(String userId) async {
    print('🔍 [DEBUG] Début chargement prêts pour userId: $userId');
    _setLoading(true);
    _clearError();

    try {
      _userLoans = await _loanService.getUserLoans(userId);
      print('🔍 [DEBUG] Prêts chargés: ${_userLoans.length} prêt(s)');
      for (final loan in _userLoans) {
        print(
          '🔍 [DEBUG] Prêt: ${loan.id} - Montant: ${loan.montant}€ - Statut: ${loan.statut}',
        );
      }
    } catch (e) {
      print('❌ [ERROR] Erreur chargement prêts: $e');
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Charger tous les prêts (admin)
  Future<void> loadAllLoans({LoanStatus? status}) async {
    _setLoading(true);
    _clearError();

    try {
      _allLoans = await _loanService.getAllLoans(status: status);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Charger les détails d'un prêt
  Future<void> loadLoanDetails(String loanId) async {
    _setLoading(true);
    _clearError();

    try {
      _currentLoan = await _loanService.getLoanById(loanId);
      if (_currentLoan != null) {
        _currentSchedule = await _loanService.getLoanSchedule(loanId);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Approuver un prêt (admin)
  Future<bool> approveLoan(String loanId, String adminId) async {
    _setLoading(true);
    _clearError();

    try {
      await _loanService.approveLoan(loanId, adminId);

      // Mettre à jour la liste locale
      final index = _allLoans.indexWhere((loan) => loan.id == loanId);
      if (index != -1) {
        _allLoans[index] = _allLoans[index].copyWith(
          statut: LoanStatus.approuve,
          approvedAt: DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refuser un prêt (admin)
  Future<bool> rejectLoan(String loanId, String adminId, String reason) async {
    _setLoading(true);
    _clearError();

    try {
      await _loanService.rejectLoan(loanId, adminId, reason);

      // Mettre à jour la liste locale
      final index = _allLoans.indexWhere((loan) => loan.id == loanId);
      if (index != -1) {
        _allLoans[index] = _allLoans[index].copyWith(
          statut: LoanStatus.refuse,
          noteAdmin: reason,
        );
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Marquer le décaissement comme effectué (admin)
  Future<bool> markDisbursed(
    String loanId,
    String adminId,
    String reference,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      await _loanService.markDisbursed(loanId, adminId, reference);

      // Mettre à jour la liste locale
      final index = _allLoans.indexWhere((loan) => loan.id == loanId);
      if (index != -1) {
        _allLoans[index] = _allLoans[index].copyWith(
          statut: LoanStatus.enCours,
          disbursedAt: DateTime.now(),
          referenceDecaissement: reference,
        );
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Marquer un paiement comme reçu (admin)
  Future<bool> markPaymentReceived({
    required String scheduleItemId,
    required String adminId,
    required double amount,
    String? note,
  }) async {
    print('🔍 [LOAN_PROVIDER] Début markPaymentReceived');
    print('🔍 [LOAN_PROVIDER] scheduleItemId: $scheduleItemId');
    print('🔍 [LOAN_PROVIDER] adminId: $adminId');
    print('🔍 [LOAN_PROVIDER] amount: $amount');

    _setLoading(true);
    _clearError();

    try {
      print('🔍 [LOAN_PROVIDER] Appel service markPaymentReceived...');

      await _loanService.markPaymentReceived(
        scheduleItemId: scheduleItemId,
        adminId: adminId,
        amount: amount,
        note: note,
      );

      print('✅ [LOAN_PROVIDER] Service markPaymentReceived réussi');

      // Mettre à jour l'échéancier local
      final index = _currentSchedule.indexWhere(
        (item) => item.id == scheduleItemId,
      );
      if (index != -1) {
        print('✅ [LOAN_PROVIDER] Mise à jour échéancier local (index: $index)');
        _currentSchedule[index] = _currentSchedule[index].copyWith(
          isPaid: true,
          paidAt: DateTime.now(),
          paidAmount: amount,
          noteAdmin: note,
        );
      } else {
        print(
          '⚠️ [LOAN_PROVIDER] Échéance non trouvée dans l\'échéancier local',
        );
      }

      print('✅ [LOAN_PROVIDER] markPaymentReceived terminé avec succès');
      return true;
    } catch (e) {
      print('❌ [LOAN_PROVIDER] Erreur markPaymentReceived: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Statistiques pour l'admin
  Map<String, dynamic> get adminStats {
    if (_allLoans.isEmpty) return {};

    final pending = _allLoans.where((loan) => loan.isPending).length;
    final active = _allLoans.where((loan) => loan.isActive).length;
    final overdue = _allLoans.where((loan) => loan.isOverdue).length;
    final completed = _allLoans.where((loan) => loan.isCompleted).length;

    final totalAmount = _allLoans
        .where((loan) => loan.isActive || loan.isCompleted)
        .fold<double>(0, (sum, loan) => sum + loan.montant);

    return {
      'pending': pending,
      'active': active,
      'overdue': overdue,
      'completed': completed,
      'totalAmount': totalAmount,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  /// Annuler un prêt (disponible pour l'emprunteur et admin)
  Future<bool> cancelLoan(
    String loanId,
    String userId, [
    String? reason,
    bool isAdmin = false,
  ]) async {
    _setLoading(true);
    _clearError();

    try {
      await _loanService.cancelLoan(
        loanId: loanId,
        userId: userId,
        reason: reason,
        isAdmin: isAdmin,
      );

      // Recharger les prêts pour refléter le changement
      await loadUserLoans(userId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Déclencher la clôture automatique des prêts soldés (fonction admin/système)
  Future<void> triggerAutoCloseLoan() async {
    try {
      await _loanService.autoCloseCompletedLoans();
      // Recharger tous les prêts pour voir les changements
      await loadAllLoans();
    } catch (e) {
      print('Erreur clôture automatique: $e');
    }
  }

  /// Nettoie toutes les données du provider (lors de la déconnexion)
  void clearAllData() {
    _userLoans.clear();
    _allLoans.clear();
    _currentSchedule.clear();
    _currentLoan = null;
    _montant = 0;
    _dureeMois = 12;
    _tauxCalcule = 0;
    _mensualiteCalculee = 0;
    _coutTotalCalcule = 0;
    _clearError();
    notifyListeners();
  }
}
