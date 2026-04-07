import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/loan_model.dart';
import '../models/schedule_item_model.dart';
import '../services/admin_service.dart';
import '../services/loan_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  List<LoanModel> _allLoans = [];
  List<UserModel> _allUsers = [];
  List<ScheduleItemModel> _allSchedules = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LoanModel> get allLoans => _allLoans;
  List<UserModel> get allUsers => _allUsers;
  List<ScheduleItemModel> get allSchedules => _allSchedules;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters filtrés pour les prêts
  List<LoanModel> get pendingLoans =>
      _allLoans.where((loan) => loan.statut == LoanStatus.soumis).toList();

  List<LoanModel> get approvedLoans =>
      _allLoans.where((loan) => loan.statut == LoanStatus.approuve).toList();

  List<LoanModel> get rejectedLoans =>
      _allLoans.where((loan) => loan.statut == LoanStatus.refuse).toList();

  /// Créer un compte admin
  Future<UserModel?> createAdminAccount({
    required String email,
    required String password,
    required String nom,
    required String telephone,
    required String adresse,
    required UserRole role,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = await _adminService.createAdminAccount(
        email: email,
        password: password,
        nom: nom,
        telephone: telephone,
        adresse: adresse,
        role: role,
      );

      // Rafraîchir la liste des utilisateurs
      await loadAllUsers();

      return user;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Charger tous les prêts
  Future<void> loadAllLoans() async {
    try {
      _setLoading(true);
      _clearError();

      _allLoans = await _adminService.getAllLoans();

      print('=== AdminProvider.loadAllLoans ===');
      print('Prêts chargés: ${_allLoans.length}');
      for (var loan in _allLoans) {
        print('- Prêt ${loan.id}: ${loan.montant}€, ${loan.statut}');
      }

      notifyListeners();
    } catch (e) {
      print('Erreur AdminProvider.loadAllLoans: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Charger tous les utilisateurs
  Future<void> loadAllUsers() async {
    try {
      _setLoading(true);
      _clearError();

      _allUsers = await _adminService.getAllUsers();

      print('=== AdminProvider.loadAllUsers ===');
      print('Utilisateurs chargés: ${_allUsers.length}');
      for (var user in _allUsers) {
        print('- ${user.nom} (${user.email}): ${user.role}');
      }

      notifyListeners();
    } catch (e) {
      print('Erreur AdminProvider.loadAllUsers: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Charger tous les échéanciers
  Future<void> loadAllSchedules() async {
    try {
      _setLoading(true);
      _clearError();

      _allSchedules = await _adminService.getAllSchedules();

      print('=== AdminProvider.loadAllSchedules ===');
      print('Schedules chargés: ${_allSchedules.length}');
      for (var schedule in _allSchedules) {
        print(
          '- Schedule ${schedule.id}: ${schedule.isPaid ? "payé" : "non payé"}, échéance: ${schedule.dueDate}',
        );
      }

      notifyListeners();
    } catch (e) {
      print('Erreur AdminProvider.loadAllSchedules: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Charger les statistiques
  Future<void> loadStats() async {
    try {
      _setLoading(true);
      _clearError();

      _stats = await _adminService.getGlobalStats();

      print('=== AdminProvider.loadStats ===');
      print('Statistiques: $_stats');

      notifyListeners();
    } catch (e) {
      print('Erreur AdminProvider.loadStats: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Approuver un prêt
  Future<bool> approveLoan(String loanId) async {
    try {
      _setLoading(true);
      _clearError();

      await _adminService.approveLoan(loanId);

      // Rafraîchir les données
      await loadAllLoans();
      await loadStats();

      print('Prêt $loanId approuvé avec succès');
      return true;
    } catch (e) {
      print('Erreur approbation prêt: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Rejeter un prêt
  Future<bool> rejectLoan(String loanId, String reason) async {
    try {
      _setLoading(true);
      _clearError();

      await _adminService.rejectLoan(loanId, reason);

      // Rafraîchir les données
      await loadAllLoans();
      await loadStats();

      print('Prêt $loanId rejeté avec succès');
      return true;
    } catch (e) {
      print('Erreur rejet prêt: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Charger toutes les données admin
  Future<void> loadAllAdminData() async {
    try {
      print('=== AdminProvider.loadAllAdminData ===');

      // Charger en parallèle pour optimiser les performances
      await Future.wait([
        loadAllLoans(),
        loadAllUsers(),
        loadAllSchedules(),
        loadStats(),
      ]);

      print('Toutes les données admin chargées');
    } catch (e) {
      print('Erreur chargement données admin: $e');
      _setError(e.toString());
    }
  }

  /// Récupérer un utilisateur par ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      // D'abord chercher dans le cache local
      final cachedUser = _allUsers.firstWhere(
        (user) => user.id == userId,
        orElse: () => throw Exception('Utilisateur non trouvé dans le cache'),
      );

      return cachedUser;
    } catch (e) {
      // Si pas trouvé dans le cache, récupérer depuis Firestore
      try {
        final user = await _adminService.getUserById(userId);
        if (user != null && !_allUsers.any((u) => u.id == userId)) {
          _allUsers.add(user);
          notifyListeners();
        }
        return user;
      } catch (e2) {
        print('Erreur récupération utilisateur $userId: $e2');
        return null;
      }
    }
  }

  /// Annuler un prêt (action admin uniquement)
  Future<bool> cancelLoanAsAdmin({
    required String loanId,
    required String adminId,
    String? reason,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final loanService = LoanService();
      await loanService.cancelLoan(
        loanId: loanId,
        userId: adminId,
        reason: reason,
        isAdmin: true,
      );

      // Recharger les données pour refléter le changement
      await loadAllLoans();

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Vider toutes les données (pour déconnexion)
  void clearAllData() {
    print('=== AdminProvider.clearAllData ===');
    _allLoans.clear();
    _allUsers.clear();
    _allSchedules.clear();
    _stats.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Méthodes privées
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
}
